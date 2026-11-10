# kneeprobe.py BAKEDDIR CLIP DEG [F0 F1 F2 F3] : (Windows pass 2026-11-11) what turning one knee out does to a saved bake, without re-baking.
# The right knee's pole (KNEE=lknee: the left's) turned DEG degrees about his vertical (+ = out to that side), eased in over frames F0..F1 and out
# over F2..F3 (default 44 47 56 60). The feet stay where they are: the knee swings about the hip-ankle line. Only the legs are re-solved (the
# solver's own leg step, Clip.solve, from the saved controls; the pelvis is unchanged, so the unchanged pole reproduces the saved legs exactly);
# every other part keeps its saved frame. So this shows the leg room a knee turn gives with the arms and glaive as exported; a real bake also
# re-places the glaive (Clip.clear_surface keeps it out of the leg solids) and the arms with it. Prints the weapon in his legs per frame
# (thighdir.py's measure, every weapon sample) and the validator's verdict (validate as export runs it) for both. OUT=<dir> writes the changed
# bake as OUT/<CLIP>.pkl for the other probes. Diagnostics only.
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
import sys, os, pickle, math, copy
import numpy as np
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
import shen_lib as L
import shen_clips as SC, castlib as C

D, name, deg = sys.argv[1], sys.argv[2], float(sys.argv[3])
f0, f1, f2, f3 = [int(v) for v in sys.argv[4:8]] if len(sys.argv) >= 8 else (44, 47, 56, 60)
KNEE = os.environ.get("KNEE", "rknee")
LEGS = [s + p for s in ("Right", "Left") for p in ("UpperLeg", "LowerLeg", "Foot")]
val = getattr(SC, "validate", C.validate)
clip = {c.name: c for c in SC.library()}["GrandmasterShen_" + name]
baked = pickle.load(open("%s/%s.pkl" % (D, name), "rb"))
rg = clip.rig


def ease(f):
    if f <= f0 or f >= f3:
        return 0.0
    if f < f1:
        u = (f - f0) / (f1 - f0)
    elif f > f2:
        u = (f3 - f) / (f3 - f2)
    else:
        return 1.0
    return u * u * (3 - 2 * u)


def turned(c, f):
    c = copy.deepcopy(c)
    w = ease(f)
    if w > 0:
        a = math.radians((1.0 if KNEE == "rknee" else -1.0) * deg * w)
        x, y, z = [float(v) for v in c[KNEE]]
        c[KNEE] = (x * math.cos(a) - z * math.sin(a), y, x * math.sin(a) + z * math.cos(a))     # + turns the forward pole toward his right
    return c


def relegged(turn):
    out = []
    clip._side = {}
    for f, (t, local, world, diag, c) in enumerate(baked):
        c2 = turned(c, f) if turn else copy.deepcopy(c)
        l2, w2, _ = clip.solve(c2)
        local, world = dict(local), dict(world)
        for k in LEGS:
            local[k], world[k] = l2[k], w2[k]
        out.append([t, local, world, diag, c2 if turn else c])
    clip._side = None
    return out


def legs(out, fa=40, fb=78):
    rows = []
    for f in range(fa, min(fb, len(out) - 1) + 1):
        world = out[f][2]
        P = L.place(rg, world, "Weapon")
        best = (None, 0.0)
        for part in L.LEG_SOLIDS:
            W = world[part]
            d = L.part_depth(rg, part, W[:3, :3], (W @ np.append(rg.JOINT[part], 1))[:3], P)
            if d.max() > best[1]:
                best = (part, float(d.max()))
        if best[0]:
            rows.append("f%d %s %.3f" % (f, best[0].replace("UpperLeg", "Thigh").replace("LowerLeg", "Shin"), best[1]))
    return ", ".join(rows) or "clear"


def verdict(out):
    s, p = val(clip, out)
    return "R %.3f L %.3f between R %s L %s | %s" % (s.get("arm_in_torso_right", 0), s.get("arm_in_torso_left", 0), s.get("arm_in_torso_between_right"),
                                                   s.get("arm_in_torso_between_left"), p)


out0 = relegged(False)
err = max(float(np.abs(out0[f][2][k] - baked[f][2][k]).max()) for f in range(len(baked)) for k in LEGS)
print("legs re-solved from the saved controls: largest difference from the saved legs %.2g" % err)
print("saved     : legs %s" % legs(baked))
print("            %s" % verdict(baked))
out1 = relegged(True)
knee = max(float(np.linalg.norm(out1[f][2][s + "LowerLeg"][:3, 3] - baked[f][2][s + "LowerLeg"][:3, 3])) for f in range(len(baked)) for s in ("Right", "Left"))
print("%s %+.0f deg over f%d-%d-%d-%d: legs %s" % (KNEE, deg, f0, f1, f2, f3, legs(out1)))
print("            %s" % verdict(out1))
print("            the knee moved up to %.3f" % knee)
if os.environ.get("OUT"):
    os.makedirs(os.environ["OUT"], exist_ok=True)
    pickle.dump(out1, open(os.path.join(os.environ["OUT"], name + ".pkl"), "wb"))
