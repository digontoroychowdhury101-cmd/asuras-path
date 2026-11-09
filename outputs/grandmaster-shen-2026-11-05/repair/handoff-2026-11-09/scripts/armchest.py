"""Per clip: deepest arm skin (upper arm, forearm, both sides) inside the torso's real surface (UpperTorso, LowerTorso SDF, rigid mask), points clear
of the torso at bind only (>= 0.05 outside). Frames from DIR (exported clip JSON). Prints worst depth, frame, share of frames past 0.05."""
import sys, os, json, glob, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_lib as L
d = sys.argv[1]; pat = sys.argv[2] if len(sys.argv) > 2 else "*"
rigs = {}
ARMS = ("LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm")
for f in sorted(glob.glob(os.path.join(d, "GrandmasterShen_%s.json" % pat))):
    name = os.path.basename(f)[16:-5]; ph = int(name[1])
    rg = rigs.get(ph) or rigs.setdefault(ph, L.Rig(ph))
    base = {(a, t): L.sdf_depth(rg, t, rg.SKIN[a][0]) < -0.05 for a in ARMS for t in ("UpperTorso", "LowerTorso")}
    F = json.load(open(f))["frames"]
    worst = (0.0, "", -1); per = []
    for i, fr in enumerate(F):
        W = {k: np.array(v, float).reshape(4, 4) for k, v in fr["parts"].items()}
        pose = L.pose_of(rg, W)
        m = 0.0
        for a in ARMS:
            Wa = W[a]
            B = L.body_points(rg, a, Wa[:3, :3], (Wa @ np.append(rg.JOINT[a], 1))[:3], pose)
            for t in ("UpperTorso", "LowerTorso"):
                Wt = W[t]
                dd = L.part_depth(rg, t, Wt[:3, :3], (Wt @ np.append(rg.JOINT[t], 1))[:3], B)
                dd = dd[base[(a, t)]]
                if len(dd) and dd.max() > m: m = float(dd.max())
                if len(dd) and dd.max() > worst[0]: worst = (float(dd.max()), a + ">" + t, i)
        per.append(m)
    per = np.array(per)
    print("%-28s worst %.3f %-26s f%-3d share>.05 %3.0f%%" % (name, worst[0], worst[1], worst[2], 100 * (per > 0.05).mean()), flush=True)
