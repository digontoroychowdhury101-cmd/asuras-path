# glaiveturn.py DIR [DIR2] [-- CLIP...] : (Windows pass 2026-11-11) the glaive's turn from frame to frame in exported Shen clips (frame JSON:
# work/opening_cast_bake/shen, or a framejson.py dir): every frame where it turns more than 60 deg, split into the haft's swing and the blade's
# roll about the haft, with the right hand's own turn and its turn on the glaive; then out-and-back flips (two such frames within 3, the glaive
# back within 45 deg of where it started). The pop checks (validator POP_LIMIT, popjson.py) look at positions out and back on adjacent frames,
# so a glaive that turns over in one frame and stays, or comes back two frames later, passes them. With DIR2: both dirs, clip by clip.
import glob, json, math, os, sys
import numpy as np

args = sys.argv[1:]
only = args[args.index("--") + 1:] if "--" in args else []
dirs = args[:args.index("--")] if "--" in args else args
# the glaive mesh's haft and blade edge in its own part frame: measured against the solver's haft (whaft) and edge over P1 Idle (within 0.03)
VH = np.array([-0.152, -0.988, -0.026])
VH /= np.linalg.norm(VH)
VF = np.array([-0.36, 0.031, 0.933])
VF -= VH * float(VF @ VH)
VF /= np.linalg.norm(VF)


def ang(A, B):
    return math.degrees(math.acos(max(-1.0, min(1.0, (float(np.trace(A.T @ B)) - 1) / 2))))


def least(a, b):
    v = np.cross(a, b)
    s = float(np.linalg.norm(v))
    if s < 1e-9:
        return np.eye(3)
    k, th = v / s, math.atan2(s, float(a @ b))
    K = np.array([[0, -k[2], k[1]], [k[2], 0, -k[0]], [-k[1], k[0], 0]])
    return np.eye(3) + math.sin(th) * K + (1 - math.cos(th)) * K @ K


def scan(path):
    fr = json.load(open(path))["frames"]
    if "Glaive" not in fr[0]["parts"]:
        return None
    G = [np.array(f["parts"]["Glaive"]).reshape(4, 4)[:3, :3] for f in fr]
    Hd = [np.array(f["parts"]["RightHand"]).reshape(4, 4)[:3, :3] for f in fr]
    st = [0.0] + [ang(G[i - 1], G[i]) for i in range(1, len(G))]
    big = []
    for i in range(1, len(G)):
        if st[i] <= 60:
            continue
        a, b = G[i - 1] @ VH, G[i] @ VH
        e0, e1 = least(a, b) @ (G[i - 1] @ VF), G[i] @ VF
        big.append("f%d %.0f (swing %.0f, roll %+.0f; hand %.0f, on glaive %.0f)" % (
            i, st[i], math.degrees(math.acos(max(-1.0, min(1.0, float(a @ b))))),
            math.degrees(math.atan2(float(np.cross(e0, e1) @ b), float(e0 @ e1))), ang(Hd[i - 1], Hd[i]),
            ang(G[i - 1].T @ Hd[i - 1], G[i].T @ Hd[i])))
    flips = ["f%d-f%d" % (i, j) for i in range(1, len(G)) if st[i] > 90 for j in range(i + 1, min(i + 4, len(G)))
             if st[j] > 90 and ang(G[i - 1], G[j]) < 45]
    return len(G), max(st), big, flips


names = sorted({os.path.basename(p)[len("GrandmasterShen_"):-5] for d in dirs for p in glob.glob(os.path.join(d, "GrandmasterShen_*.json"))})
tot = [0] * len(dirs)
for n in names:
    if only and n not in only:
        continue
    rows = []
    for k, d in enumerate(dirs):
        p = os.path.join(d, "GrandmasterShen_%s.json" % n)
        r = scan(p) if os.path.isfile(p) else None
        if r is None:
            continue
        tot[k] += len(r[2])
        rows.append("  %-28s largest %3.0f/frame; over 60: %s%s" % (os.path.basename(os.path.normpath(d)), r[1], "; ".join(r[2]) or "none",
                                                                 ("  | out and back: " + ", ".join(r[3])) if r[3] else ""))
    if len(rows) and any("over 60: none" not in x for x in rows):
        print(n)
        print("\n".join(rows))
print("frames over 60 deg:", ", ".join("%s %d" % (os.path.basename(os.path.normpath(d)), t) for d, t in zip(dirs, tot)))
