# elbowopts.py CLIP F [Right|Left]: every elbow turn swivel weighs at frame F (from the final ctrl): arm-in-torso, weapon clash, elbow in chest frame
import sys, os, pickle, math, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
if os.environ.get("SHEN_DEV"): sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) + "/dev")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
S_ = os.path.dirname(os.path.abspath(__file__))
name, i = sys.argv[1], int(sys.argv[2]); side = sys.argv[3] if len(sys.argv) > 3 else "Right"
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name); rg = clip.rig
ctrl = pickle.load(open(os.environ.get("PKL") or "%s/final_%s.pkl" % (S_, name), "rb")); clip._side = {}
t2 = dict(ctrl[i]); _l, world, _d = clip.solve(t2)
gkey, pkey = ("_rgrip", "rpole") if side == "Right" else ("_lgrip", "lpole")
S, grip, axis, core = t2[gkey]
u0, l0, pole0 = (rg.ARM_U, rg.ARM_L, rg.ELBOW0) if side == "Right" else (rg.LARM_U, rg.LARM_L, rg.LELBOW0)
axis0, v0 = (rg.HAFT0, rg.GRIP0 - rg.JOINT["RightHand"]) if side == "Right" else (rg.LAX0, rg.PALM0 - rg.JOINT["LeftHand"])
P, _ = L.weapon_cloud(rg, t2); place = L.weapon_place(rg, t2)
Rh0 = L.short_arc(L.slanted(rg, axis0, side, 0.0), axis); w0 = grip - Rh0 @ v0
d0 = L.unit(w0 - S); pole_base = L.unit(t2.get(pkey, t2["relb" if side == "Right" else "lelb"])); k0 = L.orth(pole_base, d0); s0 = np.cross(d0, k0)
Rc = world["UpperTorso"][:3, :3]; at = (world["UpperTorso"] @ np.append(rg.JOINT["UpperTorso"], 1))[:3]
cf = lambda p: np.round((p - at) @ Rc, 2)
print("shoulder", cf(S), "wrist", cf(w0))
for e, a in enumerate(L.ELBOW_TURNS):
    ar = math.radians(a)
    ru, rl, reached = L.two_bone(S, w0, u0, l0, pole0, k0 * math.cos(ar) + s0 * math.sin(ar), "x", {"x": 0.0})
    el = S + ru @ u0
    tor = L.arm_torso_pose(rg, side, {side + "UpperArm": (ru, S), side + "LowerArm": (rl, el), side + "Hand": (Rh0, w0), "UpperTorso": t2["_chest"], "LowerTorso": t2["_pelvis"]})
    cl = L.arm_clash(rg, side, S, el, reached, P, ru, rl, place, chest=t2.get("_chest"), hand_pose=(Rh0, w0))
    print("turn %5.1f elbow %s torso %.3f clash %.3f" % (a, cf(el), tor, cl))
