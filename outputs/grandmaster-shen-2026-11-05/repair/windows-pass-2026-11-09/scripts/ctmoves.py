# ctmoves.py CACHE.pkl F0 F1 : (Windows pass 2026-11-10) on controls ctcache.py saved before clear_torso, run clear_torso and print, per frame
# F0..F1, how deep each arm sits in his torso before and after (dense, each frame solved on its own, as clear_torso measures) and the fist move
# (rp, his frame: x right, y up, z forward negative) it applied. Diagnostics only:
#   UNCAP=1   lifts the TORSO_STEP / TORSO_BEND caps, to see the move clear_torso wants (as the 2026-11-08 code took it) before the caps limit it
#   OFFSET=t0,t1,t2,t3,x,y,z   first adds a carry-shaped fist offset (eased in t0-t1, held to t2, out by t3, seconds) to the cached controls
#   REST=1    then runs the remaining stages (slide_fist, tilt_haft, depop, close_loop, and joint_polish when POLISH=1), the in-order solve the
#             export makes and the repo's validate: torso, pops and problems. The earlier stages are not rerun, so a key change is only
#             approximated: a full bake (runall.py) decides.
#   LEGS=1    (2026-11-10) also print, before clear_torso and after each later stage, how deep the weapon sits in his legs on F0..F1 (every
#             weapon sample, each frame solved on its own): which stage puts the wood in his thigh
import os, sys, time, pickle, math
import numpy as np
ROOT = os.environ.get("SHEN_ROOT") or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
cache = pickle.load(open(sys.argv[1], "rb"))
D = cache["dev"]
if D:
    sys.path.insert(0, (os.environ.get("SHEN_SCRATCH") or ROOT + "/work/shen_repair") + "/" + D)
os.chdir(ROOT)
if os.environ.get("POLISH") != "1":
    os.environ["SHEN_JOINT_POLISH"] = "0"
import shen_clips as SC, shen_lib as L, castlib as C

f0, f1 = int(sys.argv[2]), int(sys.argv[3])
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + cache["clip"])
for k, v in cache["state"].items():
    setattr(clip, k, v)
rg = clip.rig
times = cache["times"]
ctrl = [dict(c) for c in cache["ctrl"]]
n = len(ctrl)


def depths(ctrl):
    keep = clip._side
    clip._side = {}
    out = {}
    try:
        for i in range(max(0, f0), min(n - 1, f1) + 1):
            d = L.arm_torso_world(rg, clip.solve(dict(ctrl[i]))[1], dense=True)
            out[i] = (d["Right"], d["Left"])
    finally:
        clip._side = keep
    return out


def legs_line(label):
    if os.environ.get("LEGS") != "1":
        return
    keep = clip._side
    clip._side = {}
    row = []
    try:
        for i in range(max(0, f0), min(n - 1, f1) + 1):
            wd = clip.solve(dict(ctrl[i]))[1]
            P = L.place(rg, wd, "Weapon")
            d = max(float(L.part_depth(rg, p, wd[p][:3, :3], (wd[p] @ np.append(rg.JOINT[p], 1))[:3], P).max()) for p in L.LEG_SOLIDS)
            if d > 0.01:
                row.append("f%d %.3f" % (i, d))
    finally:
        clip._side = keep
    print("LEGS %-14s %s" % (label, ", ".join(row) or "none"), flush=True)


off = os.environ.get("OFFSET")
if off:
    t0, t1, t2, t3, x, y, z = (float(v) for v in off.split(","))
    for i, t in enumerate(times):
        if t0 < t < t3:
            w = L.smooth01((t - t0) / max(t1 - t0, 1e-6)) if t < t1 else (1.0 if t <= t2 else L.smooth01((t3 - t) / max(t3 - t2, 1e-6)))
            ctrl[i]["rp"] = tuple(np.asarray(ctrl[i]["rp"], float) + w * np.array([x, y, z]))
if os.environ.get("UNCAP") == "1":
    L.TORSO_STEP = L.TORSO_BEND = 99.0
os.environ["SHEN_DEBUG_FREE"] = "1"
rp0 = [np.asarray(c["rp"], float) for c in ctrl]
d0 = depths(ctrl)
legs_line("cache")
t_0 = time.time()
L.clear_torso(clip, ctrl, times)
legs_line("clear_torso")
d1 = depths(ctrl)
print("ctmoves %s DEV=%s UNCAP=%s OFFSET=%s (%.0fs)" % (cache["clip"], D, os.environ.get("UNCAP"), off, time.time() - t_0))
for i in sorted(d0):
    mv = np.asarray(ctrl[i]["rp"], float) - rp0[i]
    print("f%-3d before R %.3f L %.3f  after R %.3f L %.3f  move (%+.2f %+.2f %+.2f) %.2f" % (i, d0[i][0], d0[i][1], d1[i][0], d1[i][1], mv[0], mv[1], mv[2], np.linalg.norm(mv)))
print("worst after F0..F1: R %.3f L %.3f" % (max(v[0] for v in d1.values()), max(v[1] for v in d1.values())), flush=True)
if os.environ.get("REST") == "1":
    L.slide_fist(clip, ctrl)
    legs_line("slide_fist")
    L.tilt_haft(clip, ctrl, times)
    legs_line("tilt_haft")
    L.depop(clip, ctrl, times)
    legs_line("depop")
    L.close_loop(clip, ctrl)
    legs_line("close_loop")
    L.joint_polish(clip, ctrl, times)
    legs_line("joint_polish")
    out = []
    clip._side = {}
    for t, c in zip(times, ctrl):
        local, world, diag = clip.solve(c)
        out.append([t, local, world, diag, c])
    clip._side = None
    L.derive_helpers(clip, out)
    s, p = getattr(SC, "validate", C.validate)(clip, out)
    print("REST torso R %.3f L %.3f between R %s L %s pops fist %.3f blade %.3f slide %.3f | %s" % (s.get("arm_in_torso_right", 0), s.get("arm_in_torso_left", 0),
          s.get("arm_in_torso_between_right"), s.get("arm_in_torso_between_left"), s.get("pop_fist", 0), s.get("pop_blade", 0), s.get("pop_slide", 0), p), flush=True)
    deep = []
    for i in range(max(0, f0), min(n - 1, f1) + 1):
        d = L.arm_torso_world(rg, out[i][2], dense=True)
        if max(d["Right"], d["Left"]) > L.ARM_TORSO_REST:
            deep.append("f%d %.3f/%.3f" % (i, d["Right"], d["Left"]))
    print("REST frames past %.2f (R/L, dense, as exported): %s" % (L.ARM_TORSO_REST, ", ".join(deep) or "none"), flush=True)
    # (2026-11-10) the weapon in his legs, as the validator's weapon_in_legs measures it (nothing limits it there): the carry that cleared
    # Skyfall's chest put the haft 0.12 into his right thigh at f49
    legs = []
    for i in range(n):
        wd = out[i][2]
        P = L.place(rg, wd, "Weapon")
        dl = max(float(L.part_depth(rg, part, wd[part][:3, :3], (wd[part] @ np.append(rg.JOINT[part], 1))[:3], P).max()) for part in L.LEG_SOLIDS)
        if dl > 0.01:
            legs.append("f%d %.3f" % (i, dl))
    print("REST weapon in legs: %s" % (", ".join(legs) or "none"), flush=True)
    if os.environ.get("SAVE"):
        pickle.dump(out, open(os.environ["SAVE"], "wb"))
