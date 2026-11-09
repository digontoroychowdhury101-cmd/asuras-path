"""P2 Transform with the roar reworked in-process: fist out past the right shoulder, blade up beside him, left hand off the haft and flung wide."""
import sys, os, time, pickle, math, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
os.environ["SHEN_DEBUG_FREE"] = "1"
import shen_clips as SC, shen_lib as L
S = os.path.dirname(os.path.abspath(__file__))
tag = sys.argv[1]
q = np.array([float(x) for x in sys.argv[2].split(",")])          # fist, chest frame
hq = L.unit(np.array([float(x) for x in sys.argv[3].split(",")]))  # haft, chest frame
lt = tuple(float(x) for x in sys.argv[4].split(","))               # free left hand, from its shoulder (world)
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_P2_Transform"); rg = clip.rig
def chest_frame(k):
    pel, pelR, chest = (np.array(k[n], float) for n in ("pel", "pelR", "chest"))
    lt_ = rg.pivoted(np.eye(4), "LowerTorso", L.homog(L.euler(pelR), pel))
    ut = rg.pivoted(lt_, "UpperTorso", L.homog(L.euler(chest)))
    return ut[:3, :3], (ut @ np.append(rg.JOINT["UpperTorso"], 1))[:3]
keys = [(t, dict(kw), e) for t, kw, e in clip.keys]
rise = next(kw for t, kw, e in keys if abs(t - 0.32) < 1e-6)
R, at = chest_frame(rise)
rp = at + R @ q; h = R @ hq
face = L.orth(R @ np.array([1.0, 0.0, -0.6]), h)
free = dict(lhw=0.0, ltw=1.0, lt=lt, lelb=(-0.2, -0.7, 0.5), lha=(0.0, 0.0, 0.0))
rise.update(rp=tuple(rp), haft=tuple(h), face=tuple(face), **free)
hold = next(kw for t, kw, e in keys if abs(t - 0.8) < 1e-6)
hold.update(rp=tuple(rp), haft=tuple(h), face=tuple(face), **free)
let_go = float(sys.argv[5]) if len(sys.argv) > 5 else 0.08
keys += [(let_go, {"lhw": 1.0, "ltw": 0.0}, "io"), (1.12, {"lhw": 0.0, "ltw": 1.0}, "io"), (1.38, {"lhw": 1.0, "ltw": 0.0}, "io")]
if len(sys.argv) > 6 and sys.argv[6] == "path":      # the fist and haft carried from the handoff to the roar in his chest's frame, not the world's
    k0 = next(kw for t, kw, e in keys if t == 0)
    R0, a0 = chest_frame(k0)
    q0, h0 = (np.array(k0["rp"], float) - a0) @ R0, L.unit(np.array(k0["haft"], float) @ R0)
    f0 = L.unit(np.array(k0["face"], float) @ R0); f1 = L.unit(R.T @ face)
    body = Clip_body = None
    for i in range(1, 10):
        t = 0.32 * i / 10
        c = clip.controls(t)
        Rt, att = chest_frame(c)
        s_ = L.smooth01(i / 10)
        hh = L.unit(h0 + (hq - h0) * s_)
        keys.append((t, {"rp": tuple(att + Rt @ (q0 + (q - q0) * s_)), "haft": tuple(Rt @ hh), "face": tuple(L.orth(Rt @ L.unit(f0 + (f1 - f0) * s_), Rt @ hh))}, "lin"))
if len(sys.argv) > 7:      # the left hand off the haft by this time, toward this spot (from its shoulder), before it flies out wide
    t_off = float(sys.argv[7]); lt_off = tuple(float(x) for x in sys.argv[8].split(","))
    keys = [k for k in keys if not (k[0] == let_go and set(k[1]) == {"lhw", "ltw"})] + [(0.0, {"lhw": 1.0, "ltw": 0.0}, "io"), (t_off, {"lhw": 0.0, "ltw": 1.0, "lt": lt_off, "lelb": (-0.5, -0.6, 0.4)}, "out")]
clip.keys = sorted(keys, key=lambda k: k[0])
t0 = time.time()
out = clip.bake()
pickle.dump([dict(o[4]) for o in out], open("%s/tr_%s.pkl" % (S, tag), "wb"))
w, problems = L.validate(clip, out)
per = [L.arm_torso_world(rg, o[2]) for o in out]
KEYS = ("arm_in_torso_right", "arm_in_torso_left", "weapon_in_arm_right", "weapon_in_arm_left", "in_weapon_arm_right", "in_weapon_arm_left", "in_weapon_torso", "weapon_in_torso", "wrist_right", "wrist_left", "left_grip", "left_off_haft", "right_off_haft")
print("Transform [%s] %.0fs" % (tag, time.time() - t0), " ".join("%s=%.3f" % (k, w.get(k, 0)) for k in KEYS), "| problems:", problems)
print("   per-frame R/L:", " ".join("%d:%.2f/%.2f" % (i, d["Right"], d["Left"]) for i, d in enumerate(per) if max(d.values()) > L.ARM_TORSO_REST))
