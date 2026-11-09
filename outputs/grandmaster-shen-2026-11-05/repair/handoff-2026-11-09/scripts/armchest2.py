"""Per shot (cloth_bake output, body bones as the GLB skins them): deepest arm skin (both upper arms, forearms) inside the torso's real surface
(UpperTorso, LowerTorso distance fields, rigid mask), counting only points >= 0.05 clear of that solid in the bind pose. Usage: armchest2.py SUFFIX [glob]"""
import sys, os, json, glob, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_lib as L
suf = sys.argv[1]; pat = sys.argv[2] if len(sys.argv) > 2 else "*"
rigs = {}
ARMS = ("LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm")
TORSO = ("UpperTorso", "LowerTorso")
for f in sorted(glob.glob(ROOT + "/work/opening_cast_bake/shen_shots/c%s_%s.json" % (pat, suf))):
    sh = json.load(open(f)); ph = sh["phase"]; name = os.path.basename(f)[:-5]
    rg = rigs.get(ph) or rigs.setdefault(ph, L.Rig(ph))
    base = {(a, t): L.sdf_depth(rg, t, rg.SKIN[a][0]) < -0.05 for a in ARMS for t in TORSO}
    worst = {}; per = []
    for i, fr in enumerate(sh["frames"]):
        Bn = {k: (np.array(v[:9]).reshape(3, 3), np.array(v[9:12])) for k, v in fr["bones"].items() if k.startswith("Sk_")}
        m = 0.0
        for a in ARMS:
            P, mix = rg.SKIN[a]
            X = np.zeros_like(P)
            for bone, w in mix:
                R, t = Bn["Sk_" + bone]
                X += (w if np.ndim(w) else np.full(len(P), w))[:, None] * (P @ R.T + t)
            for tt in TORSO:
                R, t = Bn["Sk_" + tt]
                dd = L.sdf_depth(rg, tt, (X - t) @ R)[base[(a, tt)]]
                if len(dd) and dd.max() > m and "Lower" in a: m = float(dd.max())
                if len(dd) and dd.max() > worst.get(a, (0, -1))[0]: worst[a] = (float(dd.max()), i)
        per.append(m)
    per = np.array(per)
    print("%-30s " % name + "  ".join("%s %.3f f%-3d" % ("".join(c for c in a if c.isupper()), *worst.get(a, (0, -1))) for a in ARMS) + "  forearm>.05 %3.0f%%" % (100 * (per > 0.05).mean()), flush=True)
