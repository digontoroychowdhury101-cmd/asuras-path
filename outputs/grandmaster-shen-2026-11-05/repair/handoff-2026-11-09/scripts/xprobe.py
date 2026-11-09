"""xprobe.py: arm-in-torso at the failing frames of baked control pickles, with the cross-body shoulder glide off and on (L.XPRO)"""
import sys, os, pickle, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
S = os.path.dirname(os.path.abspath(__file__))
cases = [("P2_Guandao_Running", "final", [5, 7, 9]), ("P2_Strike", "final", [16, 17]), ("P1_Strike", "final", [19, 23]), ("P2_Guandao_L2", "ks_P2_Guandao_L2_ah0", [4, 8]),
         ("P2_Guandao_Heavy", "final", [10, 14, 20]), ("P2_Flourish", "final", [39, 41]), ("P1_Guandao_L1", "final", [6]), ("P2_Guandao_L3", "final", [11]),
         ("P2_Feint", "final", [11, 15]), ("P2_PostureBreak", "final", [29]), ("P2_Idle", "final", [0, 20]), ("P1_Idle", "final", [0, 20])]
lib = {c.name: c for c in SC.library()}
vals = [0.0] + [float(v) for v in sys.argv[1].split(",")]
for name, src, frames in cases:
    clip = lib["GrandmasterShen_" + name]
    f = "%s/final_%s.pkl" % (S, name) if src == "final" else "%s/%s.pkl" % (S, src)
    if not os.path.exists(f):
        print(name, "no pickle"); continue
    ctrl = pickle.load(open(f, "rb")); clip._side = {}
    for fr in frames:
        row = []
        for v in vals:
            L.XPRO = v
            c = dict(ctrl[fr]); d = L.arm_torso(clip, c); g = L.held_clash(clip, dict(ctrl[fr]))
            row.append("%.2f: R%.2f/L%.2f g%.2f" % (v, d["Right"], d["Left"], g))
        print("%-20s f%-3d %s" % (name, fr, "  ".join(row)), flush=True)
