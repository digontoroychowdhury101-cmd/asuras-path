"""Bake one clip with its keys edited in-process and validate it: python3 keyscan.py CLIP TAG 'ops' where ops is ';'-separated:
  turn:t0:t1:dyaw:dchest      add yaw to pelR and chest on keys in [t0, t1] (degrees)
  shift:t0:t1:dx:dy:dz         move rp of keys in [t0, t1] by this much along his chest frame at that key (x his right, -z his front)
  wshift:t0:t1:dx:dy:dz        move rp of keys in [t0, t1] in world axes
  lsl:t0:t1:v                  set lsl on keys in [t0, t1]
  lhw:t0:t1:v                  set lhw on keys in [t0, t1] (0: let go)"""
import sys, os, time, pickle, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
os.environ["SHEN_DEBUG_FREE"] = "1"
import shen_clips as SC, shen_lib as L
S = os.path.dirname(os.path.abspath(__file__))
name, tag, ops = sys.argv[1], sys.argv[2], (sys.argv[3] if len(sys.argv) > 3 else "")
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
keys = [(t, dict(kw), e) for t, kw, e in clip.keys]
for op in [o for o in ops.split(";") if o]:
    f = op.split(":"); kind = f[0]; t0, t1 = float(f[1]), float(f[2]); v = [float(x) for x in f[3:]]
    for t, kw, e in keys:
        if not (t0 - 1e-6 <= t <= t1 + 1e-6):
            continue
        if kind == "turnn" and "neck" in kw:      # and the head turns back by most of it, eyes on the target
            kw["neck"] = tuple(np.asarray(kw["neck"], float) - (0, 0.9 * (v[0] + v[1]), 0))
        if kind in ("turn", "turnn"):
            if "pelR" in kw: kw["pelR"] = tuple(np.asarray(kw["pelR"], float) + (0, v[0], 0))
            if "chest" in kw: kw["chest"] = tuple(np.asarray(kw["chest"], float) + (0, v[1], 0))
        elif kind == "pitch":
            if "pelR" in kw: kw["pelR"] = tuple(np.asarray(kw["pelR"], float) + (v[0], 0, 0))
            if "chest" in kw: kw["chest"] = tuple(np.asarray(kw["chest"], float) + (v[1], 0, 0))
            if "neck" in kw: kw["neck"] = tuple(np.asarray(kw["neck"], float) - (0.8 * (v[0] + v[1]), 0, 0))
        elif kind in ("shift", "wshift") and "rp" in kw:
            d = np.array(v[:3])
            if kind == "shift":
                c = clip.controls(t)
                lt = clip.rig.pivoted(np.eye(4), "LowerTorso", L.homog(L.euler(c["pelR"]), np.asarray(c["pel"], float)))
                d = clip.rig.pivoted(lt, "UpperTorso", L.homog(L.euler(c["chest"])))[:3, :3] @ d
            kw["rp"] = tuple(np.asarray(kw["rp"], float) + d)
        elif kind == "lsl":
            kw["lsl"] = v[0]
        elif kind == "lhw":
            kw["lhw"] = v[0]
clip.keys = keys
t0_ = time.time()
out = clip.bake()
pickle.dump([dict(o[4]) for o in out], open("%s/ks_%s_%s.pkl" % (S, name, tag), "wb"))
w, problems = L.validate(clip, out)
per = [L.arm_torso_world(clip.rig, o[2]) for o in out]
KEYS = ("arm_in_torso_right", "arm_in_torso_left", "weapon_in_arm_right", "weapon_in_arm_left", "in_weapon_arm_right", "in_weapon_arm_left", "in_weapon_torso", "weapon_in_torso", "wrist_right", "wrist_left", "left_grip", "left_off_haft", "right_off_haft")
print("%s [%s] %.0fs" % (name, tag, time.time() - t0_), " ".join("%s=%.3f" % (k.replace("arm_in_torso", "torso").replace("in_weapon", "inW").replace("weapon_in", "Win"), w.get(k, 0)) for k in KEYS), "| strike", w.get("strike", {}).get("contact"), "| problems:", problems)
print("   per-frame R/L:", " ".join("%d:%.2f/%.2f" % (i, d["Right"], d["Left"]) for i, d in enumerate(per) if max(d.values()) > L.ARM_TORSO_REST))
