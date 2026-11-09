# fadepair.py BAKEDDIR A B [FADE] : clip A (at several of its frames: where the game may cut it) fading into clip B with the Animator's joint
# blend (linear weight over FADE s, BossAnimations' 0.15 for a reaction), deepest arm in his torso on every skin sample per fade
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
import sys, os, pickle, numpy as np
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
import shen_lib as L, cloth_bake as CB
D, A, B = sys.argv[1:4]; FADE = float(sys.argv[4]) if len(sys.argv) > 4 else 0.15
ph = int(A[1]); rg = L.Rig(ph)
WA = [o[2] for o in pickle.load(open("%s/%s.pkl" % (D, A), "rb"))]; WB = [o[2] for o in pickle.load(open("%s/%s.pkl" % (D, B), "rb"))]
n = int(round(FADE * 30))
for fa in sorted(set([len(WA) // 3, len(WA) // 2, 2 * len(WA) // 3, len(WA) - 1])):
    row = []
    for i in range(0, n + 1):
        u = i / n
        t = L.arm_torso_world(rg, CB.fade_pose(WA[min(fa + i, len(WA) - 1)], WB[min(i, len(WB) - 1)], u, ph), dense=True)
        row.append("%.2f/%.2f" % (t["Right"], t["Left"]))
    print("%s f%d -> %s: %s" % (A, fa, B, " ".join(row)), flush=True)
