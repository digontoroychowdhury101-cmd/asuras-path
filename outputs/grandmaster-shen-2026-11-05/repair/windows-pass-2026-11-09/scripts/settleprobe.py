# settleprobe.py CLIP CALL F0 F1 : (Windows pass 2026-11-09) bake CLIP up to its CALL-th settle; on F0..F1 print what that settle starts from:
# the fist as keyed and as the passes so far left it, the correction solve() makes to it (what settle spreads), the rear slide (rsl), how far
# the haft sits off the keyed line, the solver's reach/grip misses and haft-side memory, and the right arm's depth (thinned/dense) before and
# after the settle. Then stops. Writes nothing.
import os, sys, math, numpy as np
ROOT = os.environ.get("SHEN_ROOT") or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
D = os.environ.get("DEV")
if D:
    sys.path.insert(0, (os.environ.get("SHEN_SCRATCH") or ROOT + "/work/shen_repair") + "/" + D)
os.chdir(ROOT)
os.environ["SHEN_JOINT_POLISH"] = "0"
import shen_clips as SC, shen_lib as L

name, CALL, F0, F1 = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
rg = clip.rig
times = clip.frames()
real = L.settle
calls = [0]


class Stop(Exception):
    pass


def row(ctrl):
    clip._side = {}
    out = {}
    try:
        for i in range(len(ctrl)):
            t2 = dict(ctrl[i])
            _l, world, diag = clip.solve(t2)
            if F0 <= i <= F1:
                out[i] = (t2, world, diag)
    finally:
        clip._side = None
    return out


def probe(clip_, ctrl, *a, **k):
    calls[0] += 1
    if calls[0] < CALL:
        return real(clip_, ctrl, *a, **k)
    before = row(ctrl)
    for i in range(F0, F1 + 1):
        t2, world, diag = before[i]
        key = clip.controls(times[i])
        c = ctrl[i]
        corr = np.asarray(t2["rp"], float) - np.asarray(c["rp"], float)
        off = math.degrees(math.acos(float(np.clip(L.unit(np.asarray(key["haft"], float)) @ L.unit(np.asarray(c["haft"], float)), -1, 1))))
        d0, d1 = L.arm_torso_world(rg, world), L.arm_torso_world(rg, world, dense=True)
        print("f%d keyed rp %s now %s (moved %.2f) | solve corrects %s (%.2f) | rsl %.2f->%.2f haft off key %.0f deg | reach %.3f lgrip %.3f lreach %.3f | R %.2f/%.2f"
              % (i, np.round(key["rp"], 2), np.round(c["rp"], 2), float(np.linalg.norm(np.asarray(c["rp"], float) - np.asarray(key["rp"], float))),
                 np.round(corr, 2), float(np.linalg.norm(corr)), float(key["rsl"]), float(c["rsl"]), off, float(diag.get("arm_reach", 0.0)),
                 float(diag.get("left_grip", 0.0)), float(diag.get("left_reach", 0.0)), d0["Right"], d1["Right"]), flush=True)
    r = real(clip_, ctrl, *a, **k)
    after = row(ctrl)
    print("after this settle R thinned/dense:", " ".join("%d:%.2f/%.2f" % (i, L.arm_torso_world(rg, after[i][1])["Right"], L.arm_torso_world(rg, after[i][1], dense=True)["Right"]) for i in range(F0, F1 + 1)))
    raise Stop


L.settle = probe
try:
    clip.bake()
except Stop:
    pass
