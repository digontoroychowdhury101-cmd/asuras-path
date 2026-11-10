# fadecheck3.py BAKEDDIR [CLIP ...] : (Windows pass 2026-11-09) fadecheck2.py's game fades at each fade time BossAnimations.luau uses, linear joint
# blend, 60 fps: 0.1 s (a planned attack's Play), 0.15 s (Play, Stop) and 0.2 s (a gait's Play and Stop). In from Idle 0.6 s in, out from the
# clip's last frame held to Idle's start, as fadecheck2. For a looping gait the fade out is also checked from every frame of the loop to Idle
# at the same time (Idle keeps playing under a Movement track). Deepest arm in his torso, dense, both arms; flags past 0.18.
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
import sys, os, pickle, glob
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
import shen_lib as L
D = sys.argv[1]
names = sys.argv[2:] or sorted(os.path.basename(p)[:-4] for p in glob.glob(D + "/P*.pkl"))
GAITS = ("WalkForward", "RunForward", "WalkBackward", "StrafeLeft", "StrafeRight", "TurnLeft", "TurnRight")
rigs = {}


def W(name):
    return [o[2] for o in pickle.load(open("%s/%s.pkl" % (D, name), "rb"))]


def dep(rg, w):
    t = L.arm_torso_world(rg, w, dense=True)
    return max(t["Right"], t["Left"])


def at(rg, frames, f, loop=False):
    n = len(frames)
    i = int(f)
    if loop:
        return L.joint_mix(rg, frames[i % n], frames[(i + 1) % n], f - i)
    i = min(i, n - 1)
    return L.joint_mix(rg, frames[i], frames[min(i + 1, n - 1)], f - i)


def fade(rg, a, b, sec, a0=0.0, b0=0.0, aloop=False, bloop=False):
    n = int(round(sec * 60))
    return max(dep(rg, L.joint_mix(rg, at(rg, a, a0 + i / 2.0, aloop), at(rg, b, b0 + i / 2.0, bloop), i / n)) for i in range(1, n))


for name in names:
    if name.endswith("_Idle"):
        continue
    ph = int(name[1])
    rg = rigs.setdefault(ph, L.Rig(ph))
    idle, X = W("P%d_Idle" % ph), W(name)
    k = int(round(0.6 * 30)) - 1
    row = []
    for sec in (0.1, 0.15, 0.2):
        row.append((sec, fade(rg, idle, X, sec, a0=k, aloop=True), fade(rg, X[-1:] * 12, idle, sec, bloop=True)))
    gait = name[3:] in GAITS
    loop_out = 0.0
    if gait:     # the loop stopped anywhere: its frame f fades to Idle at f (both loops), 0.2 s
        n = len(X) - 1 if len(X) > 1 else 1
        loop_out = max(fade(rg, X, idle, 0.2, a0=f, b0=f % len(idle), aloop=True, bloop=True) for f in range(n))
    worst = max([v for r in row for v in r[1:]] + [loop_out])
    print("%-24s %s%s%s" % (name, "  ".join("%.2fs in %.3f out %.3f" % r for r in row), ("  | loop out %.3f" % loop_out) if gait else "",
                            "  <-- past 0.18" if worst > 0.18 else ""), flush=True)
