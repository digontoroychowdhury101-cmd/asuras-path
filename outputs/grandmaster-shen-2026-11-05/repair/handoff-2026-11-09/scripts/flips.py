import json, numpy as np, sys
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
def flips(shot, th=20):
    d = json.load(open(ROOT + "/work/opening_cast_bake/shen_shots/%s.json" % shot)); fr = d["frames"]
    out = {}
    for bn in fr[0]["bones"]:
        if not bn.startswith("Cl_"): continue
        Rs = [np.array(f["bones"][bn][:9]).reshape(3, 3) for f in fr]
        a = [np.degrees(np.arccos(np.clip((np.trace(Rs[i + 1] @ Rs[i].T) - 1) / 2, -1, 1))) for i in range(len(Rs) - 1)]
        m = max(a)
        if m > th: out[bn] = (round(m, 1), int(np.argmax(a)) + 1)
    return out
if __name__ == "__main__":
    for s in sys.argv[1:]:
        print(s, flips(s))
