# fadeweapon.py BAKEDDIR [CLIP ...] : (Windows pass 2026-11-11) the glaive inside his torso while a clip fades in from Idle and back out to Idle at
# the game's fade times, fadecheck3.py's way (linear joint blend, 60 fps; 0.1 s a planned attack's Play, 0.15 s Play/Stop, 0.2 s a gait's; in from
# Idle 0.6 s in, out from the clip's last frame held to Idle's start). Depth of every weapon sample (shen_lib.place, not thinned) in the UpperTorso
# and LowerTorso solids (shen_lib.part_depth, as validate's weapon_in_torso). Prints the clip's own deepest over its frames, then in / out per fade
# time. Measures only; flags nothing.
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
import sys, os, pickle, glob
import numpy as np
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
import shen_lib as L
D = sys.argv[1]
names = sys.argv[2:] or sorted(os.path.basename(p)[:-4] for p in glob.glob(D + "/P*.pkl"))
rigs = {}


def W(name):
    return [o[2] for o in pickle.load(open("%s/%s.pkl" % (D, name), "rb"))]


def wdep(rg, w):
    P = L.place(rg, w, "Weapon")
    m = 0.0
    for part in ("UpperTorso", "LowerTorso"):
        T = w[part]
        m = max(m, float(L.part_depth(rg, part, T[:3, :3], (T @ np.append(rg.JOINT[part], 1))[:3], P).max()))
    return max(0.0, m)


def at(rg, frames, f, loop=False):
    n = len(frames)
    i = int(f)
    if loop:
        return L.joint_mix(rg, frames[i % n], frames[(i + 1) % n], f - i)
    i = min(i, n - 1)
    return L.joint_mix(rg, frames[i], frames[min(i + 1, n - 1)], f - i)


def fade(rg, a, b, sec, a0=0.0, aloop=False, bloop=False):
    n = int(round(sec * 60))
    return max(wdep(rg, L.joint_mix(rg, at(rg, a, a0 + i / 2.0, aloop), at(rg, b, i / 2.0, bloop), i / n)) for i in range(1, n))


for name in names:
    if name.endswith("_Idle"):
        continue
    ph = int(name[1])
    rg = rigs.setdefault(ph, L.Rig(ph))
    idle, X = W("P%d_Idle" % ph), W(name)
    k = int(round(0.6 * 30)) - 1
    own = max(wdep(rg, w) for w in X)
    row = [(sec, fade(rg, idle, X, sec, a0=k, aloop=True), fade(rg, X[-1:] * 12, idle, sec, bloop=True)) for sec in (0.1, 0.15, 0.2)]
    print("%-24s clip %.3f  %s" % (name, own, "  ".join("%.2fs in %.3f out %.3f" % r for r in row)), flush=True)
