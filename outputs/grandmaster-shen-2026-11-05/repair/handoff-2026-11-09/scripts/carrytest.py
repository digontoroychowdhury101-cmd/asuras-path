import sys, os, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
K = float(os.environ.get("CARRY", "1.0"))
orig = L.Clip.controls
def chest(rg, c):
    lt = rg.pivoted(np.eye(4), "LowerTorso", L.homog(L.euler(c["pelR"]), c["pel"]))
    return rg.pivoted(lt, "UpperTorso", L.homog(L.euler(c["chest"])))
def controls(self, t):
    c1 = orig(self, t)
    if not self.corrupt or K == 0: return c1
    self.corrupt = False; c0 = orig(self, t); self.corrupt = True
    T = chest(self.rig, c1) @ np.linalg.inv(chest(self.rig, c0))
    R = T[:3, :3]
    if K != 1.0:
        R = L.rodrigues(L.ZR.quat(R) and None) if False else R
    rp = np.asarray(c1["rp"], float)
    c1["rp"] = tuple(rp + K * ((R @ rp + T[:3, 3]) - rp))
    c1["haft"] = tuple(L.unit(np.asarray(c1["haft"]) + K * (R @ np.asarray(c1["haft"]) - np.asarray(c1["haft"]))))
    c1["face"] = tuple(L.unit(np.asarray(c1["face"]) + K * (R @ np.asarray(c1["face"]) - np.asarray(c1["face"]))))
    return c1
L.Clip.controls = controls
sys.argv = [sys.argv[0]] + sys.argv[1:]
exec(open("%s/keytorso.py" % os.path.dirname(os.path.abspath(__file__))).read().split("want = sys.argv[1:]", 1)[1].replace("for clip in SC.library():", "want = sys.argv[1:]\nfor clip in SC.library():", 1)) if False else None
want = sys.argv[1:]
for clip in SC.library():
    nm = clip.name.replace("GrandmasterShen_", "")
    if want and nm not in want: continue
    rg = clip.rig; mr = ml = 0.0; rows = []
    for i, t in enumerate(clip.frames()):
        c = clip.controls(t)
        clip._side = {}; _l, world, _d = clip.solve(c); clip._side = None
        d = L.arm_torso_world(rg, world)
        mr, ml = max(mr, d["Right"]), max(ml, d["Left"])
        if max(d.values()) > 0.18: rows.append("f%d %.2f/%.2f" % (i, d["Right"], d["Left"]))
    print("%-26s carry %.1f keyed max R %.2f L %.2f | %s" % (nm, K, mr, ml, " ".join(rows[:10])), flush=True)
