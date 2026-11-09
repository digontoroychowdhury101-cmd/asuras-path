import sys, os, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name = sys.argv[1]; F = [int(x) for x in sys.argv[2].split(",")]
lib = {c.name: c for c in SC.library()}
for ph in (1, 2):
    clip = lib["GrandmasterShen_P%d_%s" % (ph, name)]; rg = clip.rig
    times = clip.frames(); ctrl = [clip.controls(t) for t in times]
    L.organic(clip, times, ctrl); L.spine_reach(clip, ctrl)
    for i in F:
        c = dict(ctrl[i]); t2 = dict(c)
        clip._side = {}; _l, w, d = clip.solve(t2); clip._side = None
        sh = np.asarray(t2["rp"]) - np.asarray(c["rp"])
        ut = w["UpperTorso"]; Rc = ut[:3, :3]
        SL = (ut @ np.append(rg.JOINT["LeftUpperArm"], 1))[:3]
        lead = rg.lead_point(np.asarray(c["rp"]), np.asarray(c["haft"]), np.asarray(c["face"]), float(c["lsl"]), float(c["rsl"]))
        maxr = float(np.linalg.norm(rg.LARM_U) + np.linalg.norm(rg.LARM_L)) * 0.98 + float(np.linalg.norm(rg.PALM0 - rg.JOINT["LeftHand"])) * 0.8
        print("P%d f%d shift %.2f (chest %s) lead-need %.2f maxr %.2f lsl %.2f->%.2f lhw %.2f" % (ph, i, np.linalg.norm(sh), np.round(sh @ Rc, 2), np.linalg.norm(lead - SL), maxr, c["lsl"], t2.get("_lsl", c["lsl"]), c["lhw"]))
