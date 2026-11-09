# deathprobe.py CLIP TAG=PKL ... : per frame, thinned vs dense arm depth in the torso (the validator's measures), right and left
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
import sys, os, pickle
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name = sys.argv[1]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name); rg = clip.rig
for spec in sys.argv[2:]:
    tag, pk = spec.split("=", 1); out = pickle.load(open(pk, "rb"))
    row = []
    for f, o in enumerate(out):
        a = L.arm_torso_world(rg, o[2]); b = L.arm_torso_world(rg, o[2], dense=True)
        if max(b["Right"], b["Left"]) > 0.14:
            row.append("%d:%.2f/%.2f|%.2f/%.2f" % (f, a["Right"], b["Right"], a["Left"], b["Left"]))
    print(tag, " ".join(row))
