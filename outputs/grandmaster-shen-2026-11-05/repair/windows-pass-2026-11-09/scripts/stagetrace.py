# stagetrace.py CLIP F0 F1 : (Windows pass 2026-11-09) bake CLIP with the repo code (DEV=<dir under SHEN_SCRATCH> puts a patched shen_lib first)
# and after every bake stage print, for frames F0..F1, how deep each arm sits in his torso: thinned/dense, each frame solved on its own as
# clear_torso measures it. Then the final in-order solve (as the export) on frames and halfway between them. Shows which stage undoes which.
# SHEN_JOINT_POLISH=0 skips the polish (fast). Writes nothing.
import os, sys, time
ROOT = os.environ.get("SHEN_ROOT") or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
D = os.environ.get("DEV")
if D:
    sys.path.insert(0, (os.environ.get("SHEN_SCRATCH") or ROOT + "/work/shen_repair") + "/" + D)
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L

name, f0, f1 = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
rg = clip.rig


def depths(ctrl):
    keep = clip._side
    clip._side = {}
    row = []
    try:
        for i in range(max(0, f0), min(len(ctrl) - 1, f1) + 1):
            _l, world, _d = clip.solve(dict(ctrl[i]))
            a, b = L.arm_torso_world(rg, world), L.arm_torso_world(rg, world, dense=True)
            row.append("%d:%.2f/%.2f" % (i, a["Right"], b["Right"]) + ("|L%.2f/%.2f" % (a["Left"], b["Left"]) if max(a["Left"], b["Left"]) > L.ARM_TORSO_REST else ""))
    finally:
        clip._side = keep
    return " ".join(row)


for st in ("organic", "spine_reach", "settle", "swivel", "wrist_yield", "clear_free_arm", "clear_torso", "slide_fist", "tilt_haft", "depop", "close_loop", "joint_polish"):
    f = getattr(L, st)

    def wrap(*a, _f=f, _n=st, **k):
        r = _f(*a, **k)
        print("%-14s %s" % (_n, depths(a[2] if _n == "organic" else a[1])), flush=True)
        return r
    setattr(L, st, wrap)
t0 = time.time()
out = clip.bake()
print("final in-order (frames R/L dense):", " ".join("%d:%.2f/%.2f" % (i, d["Right"], d["Left"]) for i, d in
      ((i, L.arm_torso_world(rg, out[i][2], dense=True)) for i in range(max(0, f0), min(len(out) - 1, f1) + 1))))
print("final halfway (dense, i..i+1):", " ".join("%d:%.2f" % (i, max(L.arm_torso_world(rg, L.joint_mix(rg, out[i][2], out[i + 1][2], 0.5), dense=True).values()))
      for i in range(max(0, f0), min(len(out) - 2, f1) + 1)))
w, problems = L.validate(clip, out)
print("%s %.0fs problems: %s" % (name, time.time() - t0, problems), flush=True)
