import sys, os, numpy as np, pickle
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
for ph in (1, 2):
    clip = next(c for c in SC.library() if c.name == "GrandmasterShen_P%d_DeathblowVictim" % ph)
    for fr in (2, 23, 39, 60):
        t = clip.frames()[fr]; k = clip.controls(t)
        clip._side = {}
        c = dict(k); out = clip.solve(c)
        w = out[1]
        tor = L.arm_torso_world(clip.rig, w)
        g = L.held_clash(clip, dict(k))
        print("P%d f%d chest %s pel %s | keyed-solve rp %s (moved %.2f) R %.2f L %.2f held_clash %.3f" % (ph, fr, np.round(k["chest"], 1), np.round(k["pel"], 2), np.round(c["rp"], 2), np.linalg.norm(np.asarray(c["rp"]) - np.asarray(k["rp"])), tor["Right"], tor["Left"], g))
