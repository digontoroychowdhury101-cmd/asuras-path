"""One exported frame: weapon samples (full and the pipeline's thinned cloud) inside each forearm, and forearm surface inside the weapon."""
import sys, os, json, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast")
import shen_clips as SC, shen_lib as L
phase, name, frames = int(sys.argv[1]), sys.argv[2], [int(x) for x in sys.argv[3].split(",")]
clip = [c for c in SC.build(phase) if c.name.endswith("_" + name)][0]
rg = clip.rig
data = json.load(open(ROOT + "/work/opening_cast_bake/shen/GrandmasterShen_P%d_%s.json" % (phase, name)))
w = rg.samples["Weapon"]
print("weapon samples", len(w), "cloud", len(rg.WCLOUD))
for f in frames:
    world = {k: np.array(v).reshape(4, 4) for k, v in data["frames"][f]["parts"].items()}
    G = world["Glaive"]
    full = w @ G[:3, :3].T + G[:3, 3]
    thin = rg.WCLOUD @ G[:3, :3].T + G[:3, 3] + G[:3, :3] @ rg.WGRIP
    for side in ("Right", "Left"):
        part = side + "LowerArm"
        A = (world[part] @ np.append(rg.JOINT[part], 1))[:3]
        R = world[part][:3, :3]
        df = L.part_depth(rg, part, R, A, full)
        dt = L.part_depth(rg, part, R, A, thin)
        k = int(np.argmax(df))
        rest = (full[k] - A) @ R + rg.JOINT[part]
        print("t %.3f %s: full %.3f (%d > .03) thin %.3f; deepest weapon rest %s at forearm rest %s" % (data["frames"][f]["t"], part, df.max(), (df > 0.03).sum(), dt.max(), np.round(w[k], 3), np.round(rest, 3)))
if os.environ.get("MESH"):
    V = np.load(os.environ["MESH"])
    s = (V - rg.GRIP0) @ rg.HAFT0
    print("mesh weapon verts", len(V))
    for f in frames:
        world = {k: np.array(v).reshape(4, 4) for k, v in data["frames"][f]["parts"].items()}
        G = world["Glaive"]
        P = V @ G[:3, :3].T + G[:3, 3]
        part = "RightLowerArm"
        A = (world[part] @ np.append(rg.JOINT[part], 1))[:3]
        d = L.part_depth(rg, part, world[part][:3, :3], A, P)
        hit = d > 0.03
        print("t %.3f mesh verts in %s: %d > .03, deepest %.3f; haft s %.2f..%.2f" % (data["frames"][f]["t"], part, hit.sum(), d.max(), s[hit].min() if hit.any() else 0, s[hit].max() if hit.any() else 0))
    # what this region is: radius off the haft axis vs station along it
    ax = rg.HAFT0
    rad = np.linalg.norm((V - rg.GRIP0) - np.outer(s, ax), axis=1)
    for lo in np.arange(-0.6, 0.61, 0.1):
        m = (s >= lo) & (s < lo + 0.1)
        if m.any(): print("haft s %+.1f..%+.1f: %4d verts, radius p50 %.3f max %.3f" % (lo, lo + 0.1, m.sum(), np.median(rad[m]), rad[m].max()))
    ws = rg.samples["Weapon"]; s2 = (ws - rg.GRIP0) @ ax
    for lo in np.arange(-0.6, 0.61, 0.1):
        m = (s2 >= lo) & (s2 < lo + 0.1)
        print("   samples s %+.1f: %d" % (lo, m.sum()))
