# legsall.py BEFOREDIR AFTERDIR [CLIP ...] : (Windows pass 2026-11-10) the validator's weapon-in-his-legs readings (weapon_in_legs: weapon samples
# inside a leg solid; in_weapon_legs: leg skin inside the wood), which it records but does not limit, on two sets of saved bakes side by side,
# and the deepest weapon point in a leg over every weapon sample (validate thins them to every 6th, and missed phase 2 Skyfall's haft 0.12 in his
# right thigh at f49) with its frame. Diagnostics only: the repair must not have put the glaive into his legs anywhere it was not.
import os, sys, glob, pickle
import numpy as np
ROOT = os.environ.get("SHEN_ROOT") or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L, castlib as C
val = getattr(SC, "validate", C.validate)
A, B = sys.argv[1], sys.argv[2]
names = sys.argv[3:] or sorted(os.path.basename(p)[:-4] for p in glob.glob(B + "/P*.pkl"))
lib = {c.name: c for c in SC.library()}


def legs(clip, baked):
    s, _ = val(clip, baked)
    rg = clip.rig
    worst = (0.0, -1)
    for i, (t, local, world, diag, c) in enumerate(baked):
        P = L.place(rg, world, "Weapon")     # every sample
        d = max(float(L.part_depth(rg, p, world[p][:3, :3], (world[p] @ np.append(rg.JOINT[p], 1))[:3], P).max()) for p in L.LEG_SOLIDS)
        if d > worst[0]:
            worst = (d, i)
    return s.get("weapon_in_legs", 0.0), s.get("in_weapon_legs", 0.0), worst


for name in names:
    clip = lib["GrandmasterShen_" + name]
    row = []
    for D in (A, B):
        f = "%s/%s.pkl" % (D, name)
        if os.path.exists(f):
            wl, iwl, (d, i) = legs(clip, pickle.load(open(f, "rb")))
            row.append("validate %.3f in_weapon %.3f dense %.3f (f%d)" % (wl, iwl, d, i))
        else:
            row.append("%-46s" % "-")
    print("%-24s %s | %s" % (name, row[0], row[1]), flush=True)
