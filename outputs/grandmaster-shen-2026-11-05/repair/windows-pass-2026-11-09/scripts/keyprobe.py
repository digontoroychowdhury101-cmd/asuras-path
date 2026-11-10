# keyprobe.py CLIP F0 F1 [STAGE [CALL]] : (Windows pass 2026-11-09) stagetrace.py cut short, to compare key variants (DEV=<overlay dir with a
# patched shen_clips.py> under SHEN_SCRATCH): bake CLIP until the CALL-th (default 1st) run of STAGE (default swivel) has finished, printing after
# every stage up to it how deep each arm sits in his torso on F0..F1 (dense, each frame solved on its own, as clear_torso measures), then a
# summary: the deepest right and left arm over F0..F1 and how many frames are past the wall (ARM_TORSO_REST + TORSO_WALL). Writes nothing.
import os, sys, time
ROOT = os.environ.get("SHEN_ROOT") or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
D = os.environ.get("DEV")
if D:
    sys.path.insert(0, (os.environ.get("SHEN_SCRATCH") or ROOT + "/work/shen_repair") + "/" + D)
os.chdir(ROOT)
os.environ["SHEN_JOINT_POLISH"] = "0"
import shen_clips as SC, shen_lib as L

name, f0, f1 = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
STOP = sys.argv[4] if len(sys.argv) > 4 else "swivel"
CALL = int(sys.argv[5]) if len(sys.argv) > 5 else 1
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
rg = clip.rig
wall = L.ARM_TORSO_REST + L.TORSO_WALL
print("keyprobe %s DEV=%s stop after %s #%d" % (name, D, STOP, CALL), flush=True)


class Stop(Exception):
    pass


def depths(ctrl):
    keep = clip._side
    clip._side = {}
    out = []
    try:
        for i in range(max(0, f0), min(len(ctrl) - 1, f1) + 1):
            world = clip.solve(dict(ctrl[i]))[1]
            d = L.arm_torso_world(rg, world, dense=True)
            out.append((i, d["Right"], d["Left"]))
    finally:
        clip._side = keep
    return out


calls = {}
for st in ("organic", "spine_reach", "settle", "swivel", "wrist_yield", "clear_free_arm", "clear_torso", "slide_fist", "tilt_haft", "depop", "close_loop"):
    f = getattr(L, st)

    def wrap(*a, _f=f, _n=st, **k):
        r = _f(*a, **k)
        calls[_n] = calls.get(_n, 0) + 1
        rows = depths(a[2] if _n == "organic" else a[1])
        print("%-14s %s" % (_n, " ".join("%d:%.2f/%.2f" % row for row in rows)), flush=True)
        if _n == STOP and calls[_n] >= CALL:
            R, Lf = max(r_[1] for r_ in rows), max(r_[2] for r_ in rows)
            past = sum(1 for r_ in rows if max(r_[1], r_[2]) > wall)
            print("SUMMARY %s DEV=%s after %s#%d: right %.3f left %.3f, %d of %d frames past %.2f" % (name, D, _n, calls[_n], R, Lf, past, len(rows), wall), flush=True)
            raise Stop
        return r
    setattr(L, st, wrap)
t0 = time.time()
try:
    clip.bake()
except Stop:
    pass
print("done %.0fs" % (time.time() - t0), flush=True)
