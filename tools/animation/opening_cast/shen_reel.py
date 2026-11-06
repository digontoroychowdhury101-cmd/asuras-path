"""Bake every Grandmaster Shen clip into review shots for a motion reel, through the game's own cloth simulation.

    python tools/animation/opening_cast/shen_reel.py [clip ...]     (needs export.py shen to have baked the clips)

Each clip is played between short idles, travelling at the game's locomotion rates, and written as
work/opening_cast_bake/shen_shots/reel_<clip>.json, plus reel_index.json (order, clip frame ranges, validator notes).
Render with tools/blender/shen_import/reel_proxy.py (any computer) or review.py (needs the skinned GLBs).
"""
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import cloth_bake as B  # noqa: E402

ROOT = HERE.parents[2]
MANIFEST = ROOT / "assets/animations/opening_cast/shen/manifest.json"
S = B.SCALE
RATES = {1: {"WalkForward": 1.98, "RunForward": 6.11, "WalkBackward": 1.48, "StrafeLeft": 1.54, "StrafeRight": 1.54},
         2: {"WalkForward": 2.40, "RunForward": 7.48, "WalkBackward": 1.80, "StrafeLeft": 1.95, "StrafeRight": 1.95}}
ORDER = ["Idle", "WalkForward", "WalkBackward", "StrafeLeft", "StrafeRight", "RunForward", "TurnLeft", "TurnRight",
         "GuardLoop", "GuardHit", "Guandao_L1", "Guandao_L2", "Guandao_L3", "Guandao_Heavy", "Guandao_Art", "Guandao_Running",
         "Strike", "Feint", "Flourish", "FlowingJian", "HesitantMoon", "WheelOfHeaven", "PrayerBeads", "AbbotSweep",
         "BloodWave", "CrimsonEmbrace", "RendingArc", "PhantomDrift", "GuandaoSkyfall",
         "HitLightFront", "HitLightBack", "HitLightLeft", "HitLightRight", "PostureBreak", "DeathblowVictim", "Death", "Transform"]
LEAD, TAIL = 0.6, 0.6
NO_TAIL = {"Death", "DeathblowVictim", "Transform"}


def plan(phase, clip, entry):
    length, loop = entry["length"], entry["loop"]
    secs = None
    opts = {}
    speed, turn = 0.0, 0.0
    rate = RATES[phase].get(clip)
    if clip == "Idle":
        secs = length
    elif loop:
        secs = max(3.0, 2 * length) if clip != "GuardLoop" else 2 * length
    if clip in ("WalkForward", "RunForward"):
        speed = lambda t, r=rate * S: r * B.ramp(0.4, t)  # noqa: E731
    elif clip == "WalkBackward":
        speed = lambda t, r=rate * S: -r * B.ramp(0.4, t)  # noqa: E731
    elif clip == "StrafeLeft":
        opts["side"] = -rate * S
    elif clip == "StrafeRight":
        opts["side"] = rate * S
    elif clip == "Guandao_Running":
        speed = lambda t, r=RATES[phase]["RunForward"] * S, n=length: r * max(1 - t / n, 0)  # noqa: E731
    elif clip in ("TurnLeft", "TurnRight"):
        turn = 220.0 if clip == "TurnLeft" else -220.0
    elif clip == "GuandaoSkyfall":
        opts["lift"] = lambda t: 28.0 * B.math.sin(B.math.pi * min(t / 1.5, 1))
    steps = [("Idle", LEAD, 0.0, 0.0), (clip, secs, speed, turn, opts)]
    if clip not in NO_TAIL:
        stop = speed if not callable(speed) else (lambda t, f=speed: f(10.0) * max(1 - t / 0.35, 0))
        steps.append(("Idle", TAIL, stop if clip in ("WalkForward", "RunForward", "WalkBackward") else 0.0, 0.0))
    clip_secs = secs if secs else length
    return steps, clip_secs


def main(names):
    manifest = json.loads(MANIFEST.read_text())["clips"]
    index = []
    for phase in (1, 2):
        for clip in ORDER:
            name = "GrandmasterShen_P%d_%s" % (phase, clip)
            if name not in manifest or (names and name not in names and clip not in names):
                continue
            entry = manifest[name]
            steps, clip_secs = plan(phase, clip, entry)
            if clip == "Idle":
                steps = [steps[1]]
            shot = "reel_" + name
            B.bake_shot(shot, phase, steps)
            n = len(json.loads((B.OUT / (shot + ".json")).read_text())["frames"])
            lead = 0 if clip == "Idle" else int(round(LEAD * B.FPS))
            index.append({"shot": shot, "phase": phase, "clip": clip, "frames": n, "clip_first": lead,
                          "clip_last": lead + int(round(clip_secs * B.FPS)) - 1, "length": entry["length"], "loop": entry["loop"],
                          "notes": entry["notes"], "problems": entry["problems"]})
    (B.OUT / "reel_index.json").write_text(json.dumps(index, indent=1))   # a named run indexes just those
    print("reel shots:", len(index), "frames:", sum(i["frames"] for i in index))


if __name__ == "__main__":
    main(sys.argv[1:])
