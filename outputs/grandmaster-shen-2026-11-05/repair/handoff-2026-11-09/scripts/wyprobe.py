# wyprobe.py CLIP F0 F1 : on entry to each wrist_yield call of the bake, every frame's own request on F0..F1 (wrist excess past the limit, the
# slide it gets, whether it asks for a tilt), whether it is at a blow, and how far its haft already sits off the keyed line; stops at clear_free_arm
import sys, os, math, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name, F0, F1 = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name); rg = clip.rig; times = clip.frames()
f0 = L.unit(rg.JOINT["RightHand"] - rg.JOINT["RightLowerArm"])
limit = math.degrees(math.acos(float(np.clip(f0 @ rg.HAFT0, -1, 1)))) + L.WRIST_BEND_MAX
arm_len = float(np.linalg.norm(rg.ARM_U) + np.linalg.norm(rg.ARM_L))
real = L.wrist_yield; calls = [0]
def probe(clip_, ctrl, *a, **k):
    calls[0] += 1; row = []
    clip._side = {}
    for i in range(F0, F1 + 1):
        c = ctrl[i]; t2 = dict(c); local, world, _ = clip.solve(t2)
        E = (world["RightLowerArm"] @ np.append(rg.JOINT["RightLowerArm"], 1))[:3]; W = (world["RightHand"] @ np.append(rg.JOINT["RightHand"], 1))[:3]
        f, h = L.unit(W - E), L.unit(t2["haft"])
        ex = math.degrees(math.acos(float(np.clip(f @ h, -1, 1)))) - limit
        off = math.degrees(math.acos(float(np.clip(L.unit(clip.controls(times[i])["haft"]) @ h, -1, 1))))
        blow = any(abs(times[i] - t) < 0.04 for t in clip.contacts)
        tilt = ""
        if ex > 0:
            S = (world["UpperTorso"] @ np.append(rg.JOINT["RightUpperArm"], 1))[:3]; rp = np.asarray(t2["rp"], float)
            room = max(0.0, float(t2.get("_lsl", c["lsl"])) - float(c["rsl"]) - L.REAR_SLIDE_GAP); d = 0.0
            bent = float(np.linalg.norm(rp - S)) < 0.8 * arm_len
            while not bent and d < min(room, L.REAR_SLIDE_MAX):
                q = rp + h * d - S
                if float(np.linalg.norm(q)) < 0.8 * arm_len or math.degrees(math.acos(float(np.clip(L.unit(q) @ h, -1, 1)))) <= limit - 10.0: break
                d += 0.05
            if bent or d >= min(room, L.REAR_SLIDE_MAX) - 1e-6: tilt = "T%.0f" % min(ex + 2, 30)
            tilt += " s%.2f" % d
        row.append("%d%s ex%.0f %s wrist%.0f off%.0f" % (i, "*" if blow else "", ex, tilt, L.ZR.angle_of(local["RightHand"][:3, :3]), off))
    clip._side = None
    print("call %d: %s" % (calls[0], " | ".join(row)), flush=True)
    return real(clip_, ctrl, *a, **k)
L.wrist_yield = probe
class Stop(Exception): pass
def stop(*a, **k): raise Stop()
L.clear_free_arm = stop
try: clip.bake()
except Stop: pass
print("WY", clip.__dict__.get("_wy_contact"))
