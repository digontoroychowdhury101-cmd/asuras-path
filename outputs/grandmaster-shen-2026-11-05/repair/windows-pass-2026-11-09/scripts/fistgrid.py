# fistgrid.py CLIP PKL F[,F...] : (Windows pass 2026-11-09) on a saved bake, each frame solved with the haft-side memory the export solve gives it,
# try moving the fist point (rp) along clear_torso's directions (ARM_TORSO_DIRS, in his chest's frame) by 0.05-0.4 and print, for the moves that
# make the deeper arm shallower, the dense torso depth (validator's measure) with the clash, reach, lead grip and wrist rows joint_polish guards.
import os, sys, pickle, numpy as np
ROOT = os.environ.get("SHEN_ROOT") or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L

name, pk = sys.argv[1], sys.argv[2]
frames = [int(v) for v in sys.argv[3].split(",")]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
rg = clip.rig
out = pickle.load(open(pk, "rb"))
ctrl = [dict(o[4]) for o in out]
sides, worlds, depth, mids, entry = L._polish_sweep(clip, ctrl)
# ARM_TORSO_DIRS in his chest's frame (front -z, his right +x, up +y); a leading "-" is the opposite way (toward his back)
NAMES = ["fwd", "fwd-up", "fwd-down", "fwd-right", "fwd-left", "right", "left", "fwd-right-up", "fwd-left-up", "fwd-right-down", "fwd-left-down"]


def meas(f, c):
    clip._side = dict(sides[f])
    local, world, diag = clip.solve(dict(c))
    clip._side = None
    t = L.arm_torso_world(rg, world, dense=True)
    return (t["Right"], t["Left"], float(L.held_clash(clip, c)), float(diag.get("arm_reach", 0.0)), float(diag.get("left_grip", 0.0)),
            float(L.ZR.angle_of(local["RightHand"][:3, :3])), float(L.ZR.angle_of(local["LeftHand"][:3, :3])))


for f in frames:
    base = meas(f, ctrl[f])
    print("f%d base R %.3f L %.3f clash %.3f reach %.3f lgrip %.3f wrist %.0f/%.0f" % ((f,) + base), flush=True)
    Rc = worlds[f]["UpperTorso"][:3, :3]
    rows = []
    for di, d in enumerate(L.ARM_TORSO_DIRS):
        # the directions as clear_torso has them, and their opposites (toward his back and up), each in his chest's frame
        for sgn in (1.0, -1.0):
            for m in (0.05, 0.1, 0.15, 0.2, 0.3, 0.4):
                c = dict(ctrl[f])
                c["rp"] = tuple(np.asarray(c["rp"], float) + Rc @ d * m * sgn)
                r = meas(f, c)
                if max(r[0], r[1]) < max(base[0], base[1]) - 0.02:
                    rows.append((max(r[0], r[1]), "%s%s %.2f" % ("" if sgn > 0 else "-", NAMES[di], m), r))
    rows.sort()
    for v, lab, r in rows[:14]:
        ok = r[2] <= max(base[2], L.CLASH_GRAZE) + 0.005 and r[3] <= max(0.02, base[3]) + 0.02 and r[4] <= max(0.05, base[4]) + 0.02
        print("   %-20s R %.3f L %.3f clash %.3f reach %.3f lgrip %.3f wrist %.0f/%.0f %s" % ((lab,) + r + ("ok" if ok else "",)), flush=True)
