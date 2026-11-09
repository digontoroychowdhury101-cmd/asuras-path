import sys, os, pickle, math, itertools, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name, pk, frame = sys.argv[1], sys.argv[2], int(sys.argv[3])
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name); rg = clip.rig
base = pickle.load(open(pk, "rb"))[frame]
clip._side = {}; _l, world, _d = clip.solve(dict(base)); clip._side = None
R = world["UpperTorso"][:3, :3]; at = (world["UpperTorso"] @ np.append(rg.JOINT["UpperTorso"], 1))[:3]
sh = (world["RightUpperArm"] @ np.append(rg.JOINT["RightUpperArm"], 1))[:3]
qs = [np.array(v) for v in itertools.product((0.3, 0.45, 0.6), (-0.1, 0.1, 0.3), (-0.45, -0.65, -0.85))]
hs = [(yaw, pit) for yaw in (25, 40, 55) for pit in (0, 12)]
res = []
for q in qs:
    for yaw, pit in hs:
        h = np.array([-math.sin(math.radians(yaw)) * math.cos(math.radians(pit)), math.sin(math.radians(pit)), -math.cos(math.radians(yaw)) * math.cos(math.radians(pit))])
        c = dict(base)
        c["rp"] = tuple(at + R @ q); c["haft"] = tuple(R @ h); c["face"] = tuple(L.orth(R @ np.array([0.3, -1.0, 0.0]), R @ h))
        c.pop("rhand", None); c.pop("lhand", None)
        lst = [dict(c) for _ in range(3)]
        L.swivel(clip, lst)
        c = lst[1]
        hc = L.held_clash(clip, c)
        clip._side = {}; loc, w2, diag = clip.solve(dict(c)); clip._side = None
        tor = L.arm_torso_world(rg, w2)
        ZR = L.ZR
        wr = float(ZR.angle_of(loc["RightHand"][:3, :3])); wl = float(ZR.angle_of(loc["LeftHand"][:3, :3]))
        score = max(hc, 0) * 10 + max(0, tor["Right"] - 0.14) * 10 + max(0, tor["Left"] - 0.14) * 10 + max(0, wr - 70) / 100 + max(0, wl - 70) / 100
        res.append((score, hc, tor["Right"], tor["Left"], wr, wl, diag.get("left_grip", 0), q, yaw, pit))
        print("q %s yaw %d pit %d | clash %.3f torso %.2f/%.2f wrist %.0f/%.0f grip %.3f" % (q, yaw, pit, hc, tor["Right"], tor["Left"], wr, wl, diag.get("left_grip", 0)), flush=True)
res.sort(key=lambda r: r[0])
print("BEST")
for r in res[:12]:
    print("q %s yaw %d pit %d | clash %.3f torso %.2f/%.2f wrist %.0f/%.0f grip %.3f" % (r[7], r[8], r[9], r[1], r[2], r[3], r[4], r[5], r[6]))
