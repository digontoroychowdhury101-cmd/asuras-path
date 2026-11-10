# ctcache.py CLIP OUT.pkl [STAGE] : (Windows pass 2026-11-10) bake CLIP with the repo code (DEV=<overlay dir under SHEN_SCRATCH> puts a patched
# shen_clips.py / shen_lib.py first) until the bake's STAGE (default clear_free_arm, the stage before clear_torso) has run, then save the frame
# controls and the clip's own bake state, so ctmoves.py can rerun the later stages on them in seconds instead of re-baking the first 35 minutes.
# The polish is off (SHEN_JOINT_POLISH=0); nothing in the repo is written.
import os, sys, time, pickle
ROOT = os.environ.get("SHEN_ROOT") or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
D = os.environ.get("DEV")
if D:
    sys.path.insert(0, (os.environ.get("SHEN_SCRATCH") or ROOT + "/work/shen_repair") + "/" + D)
os.chdir(ROOT)
os.environ["SHEN_JOINT_POLISH"] = "0"
import shen_clips as SC, shen_lib as L

name, out = sys.argv[1], sys.argv[2]
STOP = sys.argv[3] if len(sys.argv) > 3 else "clear_free_arm"
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)


class Stop(Exception):
    pass


saved = {}
_bake_times = []
f = getattr(L, STOP)


def wrap(*a, **k):
    r = f(*a, **k)
    saved["ctrl"] = [dict(c) for c in a[1]]
    raise Stop


setattr(L, STOP, wrap)
t0 = time.time()
try:
    clip.bake()
except Stop:
    pass
state, skipped = {}, []
for k, v in clip.__dict__.items():
    if k == "rig":
        continue
    try:
        pickle.dumps(v)
        state[k] = v
    except Exception:
        skipped.append(k)
pickle.dump({"clip": name, "dev": D, "stage": STOP, "times": clip.frames(), "ctrl": saved["ctrl"], "state": state}, open(out, "wb"))
print("ctcache %s DEV=%s after %s: %d frames saved to %s in %.0fs; state skipped: %s" % (name, D, STOP, len(saved["ctrl"]), out, time.time() - t0, skipped), flush=True)
