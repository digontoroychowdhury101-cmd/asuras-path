# rollscan.py DIR [DIR...] : (Windows pass 2026-11-11) in exported frame JSON (GrandmasterShen_P*.json), each hand's turn on the glaive frame to frame
# (the hand's rotation relative to the glaive's) and the frames where it reverses: both steps >= MIN degrees (default 15) about opposed axes, i.e. the
# fist or the lead hand rolling back and forth on the haft while the glaive barely moves. Per clip and folder, side by side: right and left counts
# and the worst such step. The solver's grip turns are 22.5 deg apart (shen_lib GRIP_TURNS), so a hand that takes a raw grip state on one frame and
# its neighbours' on the next shows 22.5 or 45 deg steps here. CLIP=<P2_GuandaoSkyfall> prints that clip's per-frame turns instead.
import json, sys, os, glob, numpy as np
MIN = float(os.environ.get("MIN", "15"))


def rotvec(R):
    a = np.arccos(np.clip((np.trace(R) - 1) / 2, -1, 1))
    if a < 1e-6:
        return np.zeros(3)
    return np.array([R[2, 1] - R[1, 2], R[0, 2] - R[2, 0], R[1, 0] - R[0, 1]]) / (2 * np.sin(a)) * a


def steps(path, side):
    fr = json.load(open(path))["frames"]
    rel = [np.array(x["parts"]["Glaive"]).reshape(4, 4)[:3, :3].T @ np.array(x["parts"][side + "Hand"]).reshape(4, 4)[:3, :3] for x in fr]
    return [rotvec(rel[i - 1].T @ rel[i]) for i in range(1, len(fr))]


def reversals(st):
    out = []
    for i in range(1, len(st)):
        a, c = st[i - 1], st[i]
        la, lc = np.degrees(np.linalg.norm(a)), np.degrees(np.linalg.norm(c))
        if min(la, lc) >= MIN and a @ c < -0.5 * np.linalg.norm(a) * np.linalg.norm(c):
            out.append((i, min(la, lc)))     # frame i: the step into it and the step out of it reverse
    return out


dirs = sys.argv[1:]
one = os.environ.get("CLIP")
if one:
    for d in dirs:
        p = os.path.join(d, "GrandmasterShen_%s.json" % one)
        for side in ("Right", "Left"):
            st = steps(p, side)
            rv = reversals(st)
            print("%-40s %s %2d reversals at %s\n   turns from f1: %s" % (d[-40:], side, len(rv), [f for f, _ in rv], " ".join("%.0f" % np.degrees(np.linalg.norm(s)) for s in st)))
    sys.exit(0)
names = sorted(os.path.basename(f) for f in glob.glob(os.path.join(dirs[0], "GrandmasterShen_P*.json")))
tot = [[0, 0] for _ in dirs]
print("%-26s %s" % ("clip", " | ".join("%-24s" % os.path.basename(os.path.normpath(d))[:24] for d in dirs)))
for nm in names:
    cells, any_ = [], False
    for k, d in enumerate(dirs):
        p = os.path.join(d, nm)
        if not os.path.exists(p):
            cells.append("%-24s" % "-")
            continue
        r = {s: reversals(steps(p, s)) for s in ("Right", "Left")}
        tot[k][0] += len(r["Right"])
        tot[k][1] += len(r["Left"])
        any_ = any_ or bool(r["Right"] or r["Left"])
        cells.append("R %2d (%2.0f) L %2d (%2.0f)    " % (len(r["Right"]), max([x for _, x in r["Right"]], default=0), len(r["Left"]), max([x for _, x in r["Left"]], default=0)))
    if any_:
        print("%-26s %s" % (nm[16:-5], " | ".join(cells)))
print("frames with a reversing hand turn (right, left): " + " | ".join("%d, %d" % tuple(t) for t in tot) + "   (both steps >= %.0f deg)" % MIN)
