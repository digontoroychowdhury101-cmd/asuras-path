"""Run Grandmaster Shen's clips through the game's own cloth simulation (src/shared/ClothSim.luau on the plain Luau CLI), with the root really travelling, so the preview shows what the game computes.

    python3 tools/animation/opening_cast/cloth_bake.py NAME            one shot from SHOTS below
Writes work/opening_cast_bake/shen_shots/<NAME>.json: per frame the root's travel and heading, and one skinning delta (rotation rows + position, rig space, relative to the root) per skeleton bone and rigid prop.
A clip follows the last with the Animator's fade; the root speed comes from Rules.Locomotion for travel, BossMotion's lunge for attacks.
"""
import json
import math
import subprocess
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[3]
import os  # noqa: E402
# SHEN_BAKE_DIR / SHEN_SHOT_SUFFIX: bake a shot from another set of clip frames (a saved earlier bake, for before/after footage) under another name
BAKE = Path(os.environ.get("SHEN_BAKE_DIR", ROOT / "work/opening_cast_bake/shen"))
OUT = ROOT / "work/opening_cast_bake/shen_shots"
SUFFIX = os.environ.get("SHEN_SHOT_SUFFIX", "")
# (2026-11-07) SHEN_CLOTH_SIM / SHEN_CLOTH_DIR: another ClothSim.luau and another folder of cloth_pN.json (an earlier version, to compare cloth on the same motion)
CLOTH_SIM = Path(os.environ.get("SHEN_CLOTH_SIM", ROOT / "src/shared/ClothSim.luau"))
CLOTH_DIR = Path(os.environ.get("SHEN_CLOTH_DIR", ROOT / "work/shen_import"))
SCALE, FPS = 1.3, 30


def load(phase, clip):
    return json.loads((BAKE / ("GrandmasterShen_P%d_%s.json" % (phase, clip))).read_text())


def lerp_pose(a, b, u):
    """A pose fade: positions and rotations mixed then squared up, as near as the Animator's fade needs."""
    out = {}
    for k in a:
        if k not in b:
            out[k] = a[k]
            continue
        M = a[k] * (1 - u) + b[k] * u
        U, _, Vt = np.linalg.svd(M[:3, :3])
        M[:3, :3] = U @ Vt
        out[k] = M
    return out


def sequence(phase, plan, fade=0.2):
    """plan: (clip, seconds or None, speed studs/s along his facing, turn deg/s, options). Returns poses and root path at 30 fps."""
    frames, roots = [], []
    x, z, yaw = 0.0, 0.0, 0.0
    last = None
    for step in plan:
        clip, seconds, speed, turn = step[:4]
        opts = step[4] if len(step) > 4 else {}
        data = load(phase, clip)
        length = data["length"]
        src = [{k: np.array(v, float).reshape(4, 4) for k, v in f["parts"].items()} for f in data["frames"]]
        total = seconds if seconds else length
        n = int(round(total * FPS))
        start = len(frames)
        for i in range(n):
            t = i / FPS
            loop = seconds is not None and seconds > length - 1e-6 or opts.get("loop")
            q = (t % length) if loop else min(t, length)
            f = q * FPS
            i0 = min(int(f), len(src) - 1)
            i1 = min(i0 + 1, len(src) - 1)
            pose = lerp_pose(src[i0], src[i1], f - int(f))
            if last is not None and t < fade:
                pose = lerp_pose(last, pose, (t / fade) ** 2 * (3 - 2 * t / fade))
            sp = speed(t) if callable(speed) else speed
            tn = turn(t) if callable(turn) else turn
            yaw += math.radians(tn) / FPS
            x += -math.sin(yaw) * sp / FPS
            z += -math.cos(yaw) * sp / FPS
            side = opts.get("side")   # strafe: studs/s to his right
            if side:
                x += math.cos(yaw) * side / FPS
                z += -math.sin(yaw) * side / FPS
            h = opts.get("lift", None)
            y = h(t) if h else 0.0
            frames.append(pose)
            roots.append((x, y, z, yaw))
        last = frames[-1]
        step_range = (start, len(frames) - 1)
    return frames, roots


def lua(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        return '"%s"' % v
    if isinstance(v, (list, tuple)):
        return "{" + ",".join(lua(x) for x in v) + "}"
    return "{" + ",".join("%s=%s" % (k, lua(x)) for k, x in v.items()) + "}"


def run_sim(phase, frames, roots, warm=1.5):
    cloth = json.loads((CLOTH_DIR / f"cloth_p{phase}.json").read_text())
    limbs = cloth["limbs"]
    rows = []
    for pose, (x, y, z, yaw) in zip(frames, roots):
        c, s = math.cos(yaw), math.sin(yaw)
        Ry = np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
        vals = []
        for n in limbs:
            M = pose[n]
            R = Ry @ M[:3, :3]
            t = Ry @ (M[:3, 3] * SCALE) + np.array([x, y, z])
            vals += [t[0], t[1], t[2]] + R.ravel().tolist()
        rows.append(" ".join("%.5f" % v for v in vals))
    src = CLOTH_SIM.read_text()
    code = ['local Sim = (function()\n', src, '\nend)()\n', 'local def = ', lua({k: cloth[k] for k in ("particles", "links", "colliders", "hits", "limbs", "sheets", "grip", "skin") if k in cloth}), '\n',
            'local s = Sim.new(def, %r)\n' % SCALE, 'local text = [==[\n', "\n".join(rows), '\n]==]\n', '''
local rows = {}
for line in string.gmatch(text, "[^\\n]+") do
    local r = {}
    for v in string.gmatch(line, "%S+") do r[#r + 1] = tonumber(v) end
    rows[#rows + 1] = r
end
local wind = Sim.DefaultWind
local h = 1 / 60
local mid = table.create(#rows[1], 0)
Sim.reset(s, rows[1])
for _ = 1, ''', str(int(warm * 60)), ''' do Sim.step(s, rows[1], h, wind, 3) end
local out = {}
for f = 1, #rows do
    local a, b = rows[math.max(f - 1, 1)], rows[f]
    for i = 1, #a do mid[i] = (a[i] + b[i]) * 0.5 end
    Sim.step(s, mid, h, wind, 3)
    Sim.step(s, b, h, wind, 3)
    local parts = table.create(#s.bones * 12)
    for k, g in s.bones do
        local o = (k - 1) * 9
        parts[#parts + 1] = string.format("%.5f %.5f %.5f", s.x[g.i], s.y[g.i], s.z[g.i])
        for q = 1, 9 do parts[#parts + 1] = string.format("%.5f", s.R[o + q]) end
    end
    print(table.concat(parts, " "))
end
''']
    path = ROOT / ("work/opening_cast_bake/_cloth_run_%d.luau" % os.getpid())     # one per process: bakes run side by side
    path.write_text("".join(code))
    res = subprocess.run([str(ROOT / "work/bin/luau/luau"), str(path)], capture_output=True, text=True)
    if res.returncode:
        raise SystemExit(res.stdout[-400:] + res.stderr[-2000:])
    path.unlink()
    lines = res.stdout.strip().split("\n")
    assert len(lines) == len(frames), (len(lines), len(frames))
    out = np.array([[float(v) for v in ln.split()] for ln in lines])
    if not np.all(np.isfinite(out)):     # (2026-11-07) a NaN bone draws nothing, which a clash check reads as clean
        raise SystemExit("cloth_bake: the simulation gave a non-finite bone (first at frame %d)" % int(np.argwhere(~np.isfinite(out))[0][0]))
    return cloth, out


def bake_shot(name, phase, plan, fade=0.2):
    frames, roots = sequence(phase, plan, fade)
    cloth, sim = run_sim(phase, frames, roots)
    bones = cloth["bones"]
    cl = [p for p in cloth["particles"] if "bone" in p]
    out = []
    for f, (pose, root) in enumerate(zip(frames, roots)):
        x, y, z, yaw = root
        c, s_ = math.cos(yaw), math.sin(yaw)
        Ry = np.array([[c, 0, s_], [0, 1, 0], [-s_, 0, c]])
        D = {}
        for b in bones[1:]:
            if "limb" in b:
                M = pose[b["limb"]]
                D[b["name"]] = M[:3, :3].ravel().tolist() + M[:3, 3].tolist()
        row = sim[f].reshape(-1, 12)
        for k, p in enumerate(cl):
            # back to root space at scale 1: the bone's world position and rotation less the root's
            world = row[k, :3] - np.array([x, y, z])
            local = Ry.T @ world / SCALE
            R = Ry.T @ row[k, 3:].reshape(3, 3) @ np.eye(3)
            R = R @ np.eye(3)
            at = np.array(p["at"])
            # the sim's R is world-from-rest; the rest frame is the sculpt's (root-aligned), so only the root's yaw comes off
            t = local - R @ at
            D[bones[p["bone"]]["name"]] = R.ravel().tolist() + t.tolist()
        props = {k: pose[k].ravel().tolist() for k in ("Glaive",) if k in pose}
        out.append({"root": [x / SCALE, y / SCALE, z / SCALE, yaw], "bones": {k: [round(v, 5) for v in vs] for k, vs in D.items()}, "props": {k: [round(v, 5) for v in vs] for k, vs in props.items()}})
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / (name + SUFFIX + ".json")).write_text(json.dumps({"phase": phase, "frames": out}))
    # how hard the cloth works: mean and peak hem travel from the sculpted pose
    print("%s: %d frames" % (name, len(out)))


def ramp(a, t):
    return min(t / a, 1.0)


WALK, RUN = 1.98 * SCALE, 6.11 * SCALE
SHOTS = {
    "walk1": (1, [("Idle", 2.0, 0.0, 0.0), ("WalkForward", 5.0, lambda t: WALK * ramp(0.5, t), 0.0), ("Idle", 2.0, lambda t: WALK * max(1 - t / 0.4, 0), 0.0)]),
    "run1": (1, [("Idle", 1.0, 0.0, 0.0), ("RunForward", 4.0, lambda t: RUN * ramp(0.4, t), lambda t: 0 if t < 2 else 80), ("Idle", 2.0, lambda t: RUN * max(1 - t / 0.35, 0), 0.0)]),
    "idle1": (1, [("Idle", 6.4, 0.0, 0.0)]),
    "melee1": (1, [("Idle", 1.0, 0.0, 0.0), ("Guandao_L1", None, 0.0, 0.0), ("Guandao_L2", None, 0.0, 0.0), ("Guandao_Heavy", None, 0.0, 0.0), ("Idle", 1.2, 0.0, 0.0)]),
    "arts1": (1, [("Idle", 0.8, 0.0, 0.0), ("FlowingJian", None, 0.0, 0.0), ("AbbotSweep", None, 0.0, 0.0), ("Guandao_Art", None, 0.0, 0.0), ("Idle", 1.0, 0.0, 0.0)]),
    "tricks1": (1, [("Idle", 0.6, 0.0, 0.0), ("Flourish", None, 0.0, 0.0), ("Feint", None, 0.0, 0.0), ("HesitantMoon", None, 0.0, 0.0), ("WheelOfHeaven", None, 0.0, 0.0), ("Idle", 0.8, 0.0, 0.0)]),
    "turn1": (1, [("Idle", 0.8, 0.0, 0.0), ("TurnLeft", 1.8, 0.0, 220.0), ("HitLightLeft", None, 0.0, 0.0), ("Idle", 0.8, 0.0, 0.0), ("TurnRight", 1.8, 0.0, -220.0), ("Idle", 1.0, 0.0, 0.0)]),
    # 2026-11-06 grip pilot: a grounded turn, a diagonal cut, the heavy, and the linked four-cut combo, on the new middle guard
    "pilot1": (1, [("Idle", 1.0, 0.0, 0.0), ("TurnLeft", 0.9, 0.0, 220.0), ("Idle", 0.4, 0.0, 0.0), ("TurnRight", 0.9, 0.0, -220.0), ("Idle", 0.6, 0.0, 0.0), ("Guandao_L1", None, 0.0, 0.0), ("Idle", 0.5, 0.0, 0.0), ("Guandao_Heavy", None, 0.0, 0.0),
                   ("Idle", 0.5, 0.0, 0.0), ("FlowingJian", None, 0.0, 0.0), ("Idle", 1.0, 0.0, 0.0)]),
    "back1": (1, [("Idle", 0.5, 0.0, 0.0), ("WalkBackward", 3.0, lambda t: -1.48 * SCALE * ramp(0.4, t), 0.0), ("StrafeLeft", 2.6, 0.0, 0.0), ("Idle", 0.8, 0.0, 0.0)]),
    "transform1": (1, [("Idle", 0.8, 0.0, 0.0), ("Transform", 0.9, 0.0, 0.0)]),
    "walk2": (2, [("Idle", 2.0, 0.0, 0.0), ("WalkForward", 4.4, lambda t: 2.40 * SCALE * ramp(0.5, t), 0.0), ("Idle", 1.5, lambda t: 2.40 * SCALE * max(1 - t / 0.4, 0), 0.0)]),
    "run2": (2, [("Idle", 1.0, 0.0, 0.0), ("RunForward", 3.7, lambda t: 7.48 * SCALE * ramp(0.4, t), lambda t: 0 if t < 2 else 90), ("Idle", 1.5, lambda t: 7.48 * SCALE * max(1 - t / 0.35, 0), 0.0)]),
    "arts2": (2, [("Transform", None, 0.0, 0.0), ("Idle", 0.8, 0.0, 0.0), ("BloodWave", None, 0.0, 0.0), ("CrimsonEmbrace", None, 0.0, 0.0), ("Idle", 0.8, 0.0, 0.0)]),
    "deaths1": (1, [("PostureBreak", None, 0.0, 0.0), ("DeathblowVictim", None, 0.0, 0.0), ("Death", None, 0.0, 0.0)]),
    "deaths2": (2, [("PostureBreak", None, 0.0, 0.0), ("DeathblowVictim", None, 0.0, 0.0), ("Death", None, 0.0, 0.0)]),
    "cuts2": (2, [("Idle", 0.8, 0.0, 0.0), ("RendingArc", None, 0.0, 0.0), ("PhantomDrift", None, 0.0, 0.0), ("Flourish", None, 0.0, 0.0), ("Idle", 0.8, 0.0, 0.0)]),
    "sky2": (2, [("Idle", 0.5, 0.0, 0.0), ("GuandaoSkyfall", None, 0.0, 0.0, {"lift": lambda t: 28.0 * math.sin(math.pi * min(t / 1.5, 1))}), ("Idle", 0.8, 0.0, 0.0)]),
}


if __name__ == "__main__":
    for name in sys.argv[1:] or SHOTS:
        if name.startswith(("c1_", "c2_")):   # (2026-11-07) one clip on its own after a short idle, for the mesh clash check (tools/blender/shen_import/mesh_clash.py)
            bake_shot(name, int(name[1]), [("Idle", 0.6, 0.0, 0.0), (name[3:], None, 0.0, 0.0)])
            continue
        phase, plan = SHOTS[name]
        bake_shot(name, phase, plan)
