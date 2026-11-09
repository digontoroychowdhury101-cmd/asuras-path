import sys, os, json, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast")
import shen_clips as SC, shen_lib as L
phase = int(sys.argv[1])
rg = [c for c in SC.build(phase) if c.name.endswith("_Idle")][0].rig
V = np.load(sys.argv[2]); ws = rg.samples["Weapon"]; ax = rg.HAFT0
print("HAFT0", ax, "|.|", np.linalg.norm(ax), "GRIP0", rg.GRIP0, "SMIN/SMAX", rg.SMIN, rg.SMAX)
s = (V - rg.GRIP0) @ ax; rad = np.linalg.norm((V - rg.GRIP0) - np.outer(s, ax), axis=1)
s2 = (ws - rg.GRIP0) @ ax; r2 = np.linalg.norm((ws - rg.GRIP0) - np.outer(s2, ax), axis=1)
s3 = rg.WCLOUD_S
print("mesh s %.2f..%.2f" % (s.min(), s.max()))
for lo in np.arange(np.floor(s.min() * 5) / 5, s.max(), 0.2):
    m = (s >= lo) & (s < lo + 0.2); m2 = (s2 >= lo) & (s2 < lo + 0.2); m3 = (s3 >= lo) & (s3 < lo + 0.2)
    print("s %+.1f: mesh %5d r50 %.3f rmax %.3f | samples %3d rmax %.3f | cloud %3d" % (lo, m.sum(), np.median(rad[m]) if m.any() else 0, rad[m].max() if m.any() else 0, m2.sum(), r2[m2].max() if m2.any() else 0, m3.sum()))
