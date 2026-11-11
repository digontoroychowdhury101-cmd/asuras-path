# rolltrace.py CLIP [F0 F1] : (Windows pass 2026-11-11) bake CLIP (DEV=<overlay dir in SHEN_SCRATCH>, as torsotest_patch.py) and after every
# stage print each hand's turn on the glaive frame to frame over F0..F1 (default 40 70; the solved hand relative to the solved glaive, degrees)
# and how many frames reverse it (both steps >= 15 deg, opposed axes: the fist or lead hand rolling back and forth on the haft while held).
# swivel's recheck_runs is reported too (hand, frames it replaced). Finds the stage that leaves a hand fluttering on the haft. Diagnostics only.
import sys, os, numpy as np
ROOT = os.environ.get("SHEN_ROOT") or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
D = os.environ.get("DEV")
if D:
    sys.path.insert(0, (os.environ.get("SHEN_SCRATCH") or ROOT + "/work/shen_repair") + "/" + D)
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L

name = sys.argv[1]
F0, F1 = (int(sys.argv[2]), int(sys.argv[3])) if len(sys.argv) >= 4 else (40, 70)
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)


def rotvec(R):
    a = np.arccos(np.clip((np.trace(R) - 1) / 2, -1, 1))
    if a < 1e-6:
        return np.zeros(3)
    return np.array([R[2, 1] - R[1, 2], R[0, 2] - R[2, 0], R[1, 0] - R[0, 1]]) / (2 * np.sin(a)) * a


def show(tag, ctrl):
    keep = clip._side
    clip._side = {}
    try:
        n = len(ctrl)
        fs = list(range(max(F0, 0), min(F1, n - 1) + 1))
        world = [clip.solve(dict(ctrl[f]))[1] for f in fs]
        out = []
        for side in ("Right", "Left"):
            rel = [w["Glaive"][:3, :3].T @ w[side + "Hand"][:3, :3] for w in world]
            st = [rotvec(rel[i - 1].T @ rel[i]) for i in range(1, len(rel))]
            deg = [float(np.degrees(np.linalg.norm(s))) for s in st]
            rev = [fs[i] for i in range(1, len(st)) if min(deg[i - 1], deg[i]) >= 15 and st[i - 1] @ st[i] < -0.5 * np.linalg.norm(st[i - 1]) * np.linalg.norm(st[i])]
            out.append("%s %2d rev %s turns %s" % (side[0], len(rev), rev, " ".join("%.0f" % d for d in deg)))
        print("%-15s %s" % (tag, " || ".join(out)), flush=True)
    finally:
        clip._side = keep


_rr = L.recheck_runs


def _recheck(clip_, ctrl, hand_side, *a, **k):
    r = _rr(clip_, ctrl, hand_side, *a, **k)
    print("   recheck_runs %s: %d frames replaced" % (hand_side, r), flush=True)
    return r


L.recheck_runs = _recheck
show("keyed", [clip.controls(t) for t in clip.frames()])
for _st in ("organic", "spine_reach", "settle", "swivel", "wrist_yield", "clear_free_arm", "clear_torso", "slide_fist", "tilt_haft", "depop", "close_loop", "joint_polish"):
    _f = getattr(L, _st)

    def _w(*a, _f=_f, _n=_st, **k):
        r = _f(*a, **k)
        show(_n, a[2] if _n == "organic" else a[1])
        return r
    setattr(L, _st, _w)
out = clip.bake()
show("final", [o[4] for o in out])
w, problems = L.validate(clip, out)
print("validate: R %.3f L %.3f | %s" % (w.get("arm_in_torso_right", 0), w.get("arm_in_torso_left", 0), problems), flush=True)
