"""Lattice particle motion (not the drawn surface): per shot, the largest particle acceleration and speed, and where."""
import json, sys, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
for name in sys.argv[1:]:
    d = json.load(open(ROOT + "/work/opening_cast_bake/shen_shots/%s.json" % name)); fr = d["frames"]
    cloth = json.load(open(ROOT + "/work/shen_import/cloth_p%d.json" % d["phase"]))
    parts = cloth["particles"]
    bp = {cloth["bones"][p["bone"]]["name"]: np.array(p["at"]) for p in parts if "bone" in p and "orb" not in p and "finger" not in p}
    X = np.array([[np.array(f["bones"][b][:9]).reshape(3, 3) @ at + np.array(f["bones"][b][9:]) for b, at in bp.items()] for f in fr])
    acc = np.linalg.norm(X[2:] - 2 * X[1:-1] + X[:-2], axis=2)
    f, k = np.unravel_index(acc.argmax(), acc.shape)
    print("%-24s particle accel median-of-max %.3f  p99 %.3f  max %.3f (frame %d, %s)" % (name, np.median(acc.max(1)), np.percentile(acc.max(1), 99), acc.max(), f + 1, list(bp)[k]))
