"""Bake clips in-process with and without clear_torso; per-frame arm-in-torso, and the validator's key numbers side by side."""
import sys, os, time, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
os.environ["SHEN_DEBUG_FREE"] = "1"
import shen_clips as SC, shen_lib as L
mode = sys.argv[1]   # "off" or "on"
real = L.clear_torso
if mode == "off":
    L.clear_torso = lambda *a, **k: None
_cur = {}
def _pops(tag, ctrl):
    clip = _cur.get("clip")
    if clip is None: return
    p = L.bake_pops(clip, [[t, None, None, None, c] for t, c in zip(clip.frames(), ctrl)])
    print("   stage %-14s %s" % (tag, " ".join("%s %.2f@f%d" % (k, v[0], v[1]) for k, v in p.items() if v[0] > 0.6 * L.POP_LIMIT[k])), flush=True)
for _st in ("organic", "spine_reach", "settle", "swivel", "wrist_yield", "clear_free_arm", "clear_torso", "slide_fist", "tilt_haft", "depop", "close_loop"):
    _f = getattr(L, _st)
    def _w(*a, _f=_f, _n=_st, **k):
        r = _f(*a, **k)
        _pops(_n, a[2] if _n == "organic" else a[1])
        return r
    setattr(L, _st, _w)
KEYS = ("arm_in_torso_right", "arm_in_torso_left", "weapon_in_arm_right", "weapon_in_arm_left", "in_weapon_arm_right", "in_weapon_arm_left", "in_weapon_torso", "weapon_in_torso", "wrist_right", "wrist_left", "left_grip", "left_off_haft", "right_off_haft", "pop_fist", "pop_blade", "pop_slide", "pop_lead_reach")
for name in sys.argv[2:]:
    clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
    t0 = time.time()
    _cur["clip"] = clip
    out = clip.bake()
    _pops("final-solve", [o[4] for o in out])
    import pickle; pickle.dump([dict(o[4]) for o in out], open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'final_%s.pkl' % name), 'wb'))
    if os.environ.get("SHEN_SAVE_BAKED"):
        os.makedirs(os.environ["SHEN_SAVE_BAKED"], exist_ok=True); pickle.dump(out, open(os.path.join(os.environ["SHEN_SAVE_BAKED"], name + ".pkl"), "wb"))
    w, problems = L.validate(clip, out)
    per = [L.arm_torso_world(clip.rig, o[2]) for o in out]
    print("%s %s %.0fs" % (name, mode, time.time() - t0), " ".join("%s=%.3f" % (k.replace("arm_in_torso", "torso").replace("in_weapon", "inW").replace("weapon_in", "Win"), w.get(k, 0)) for k in KEYS), "| strike", w.get("strike", {}).get("contact"), "| problems:", problems)
    print("   per-frame R/L:", " ".join("%d:%.2f/%.2f" % (i, d["Right"], d["Left"]) for i, d in enumerate(per) if max(d.values()) > L.ARM_TORSO_REST))
