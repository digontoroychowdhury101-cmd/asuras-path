# armsteps.py BAKEDDIR CLIP F0 F1 [SIDE] : (Windows pass 2026-11-09) per frame of a saved bake, F0..F1: one arm's (SIDE, default Right) depth in
# his torso on the frame and halfway to the next (dense, joint_mix as the game draws it), and how far the upper arm, forearm and hand turn (world,
# degrees) and the elbow and wrist move (rig units) to the next frame: shows where an arm swings through him between two clear frames.
import os, sys, pickle, numpy as np
ROOT = os.environ.get("SHEN_ROOT") or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_lib as L

bdir, name, f0, f1 = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
SIDE = sys.argv[5] if len(sys.argv) > 5 else "Right"
rg = L.Rig(int(name[1]))
out = pickle.load(open("%s/%s.pkl" % (bdir, name), "rb"))
W = [o[2] for o in out]


def ang(A, B):
    R = A[:3, :3].T @ B[:3, :3]
    return float(np.degrees(np.arccos(np.clip((np.trace(R) - 1) / 2, -1, 1))))


def pt(w, bone):
    return (w[bone] @ np.append(rg.JOINT[bone], 1))[:3]


for i in range(max(0, f0), min(len(W) - 1, f1) + 1):
    d = L.arm_torso_world(rg, W[i], dense=True)[SIDE]
    row = "f%-3d depth %.3f" % (i, d)
    if i + 1 < len(W):
        mid = L.arm_torso_world(rg, L.joint_mix(rg, W[i], W[i + 1], 0.5), dense=True)[SIDE]
        a = W[i], W[i + 1]
        row += " | mid %.3f | upper %5.1f fore %5.1f hand %5.1f deg | elbow %.3f wrist %.3f" % (
            mid, ang(a[0][SIDE + "UpperArm"], a[1][SIDE + "UpperArm"]), ang(a[0][SIDE + "LowerArm"], a[1][SIDE + "LowerArm"]),
            ang(a[0][SIDE + "Hand"], a[1][SIDE + "Hand"]), float(np.linalg.norm(pt(a[0], SIDE + "LowerArm") - pt(a[1], SIDE + "LowerArm"))),
            float(np.linalg.norm(pt(a[0], SIDE + "Hand") - pt(a[1], SIDE + "Hand"))))
    print(row, flush=True)
