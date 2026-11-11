# armjump.py DIR [DIR...] [-- CLIP...] : (Windows pass 2026-11-11) in exported Shen frame JSON (work/opening_cast_bake/shen, or a framejson.py
# dir), each upper arm's turn in his chest's frame from one frame to the next (deg), per clip and folder side by side: the largest step and the
# frames whose step is over LIM (default 30). An elbow that swings from one half turn to the other in a frame and stays there passes popjson.py's
# out-and-back test; this shows it. Also each clip's first frame against Idle 0.6 s in (where the game's fade in starts): f0 (deg).
import json, sys, os, glob, numpy as np
LIM = float(os.environ.get("LIM", "30"))
args = sys.argv[1:]
clips = None
if "--" in args:
    i = args.index("--"); clips, args = args[i + 1:], args[:i]
dirs = args
def rel(x, a, b):
    return np.array(x["parts"][a]).reshape(4, 4)[:3, :3].T @ np.array(x["parts"][b]).reshape(4, 4)[:3, :3]
def ang(R):
    return float(np.degrees(np.arccos(np.clip((np.trace(R) - 1) / 2, -1, 1))))
names = clips or sorted(os.path.basename(f)[16:-5] for f in glob.glob(os.path.join(dirs[0], "GrandmasterShen_P*.json")))
idle = {}
tot = [0] * len(dirs)
for nm in names:
    cells, show = [], False
    for k, d in enumerate(dirs):
        p = os.path.join(d, "GrandmasterShen_%s.json" % nm)
        if not os.path.exists(p):
            cells.append("%-46s" % "-"); continue
        fr = json.load(open(p))["frames"]
        key = (d, nm[1])
        if key not in idle:
            ip = os.path.join(d, "GrandmasterShen_P%s_Idle.json" % nm[1])
            ifr = json.load(open(ip))["frames"] if os.path.exists(ip) else None
            idle[key] = ifr[min(len(ifr) - 1, 18)] if ifr else None
        txt = []
        for s in ("Right", "Left"):
            st = [ang(rel(fr[i - 1], "UpperTorso", s + "UpperArm").T @ rel(fr[i], "UpperTorso", s + "UpperArm")) for i in range(1, len(fr))]
            big = [(i + 1, a) for i, a in enumerate(st) if a > LIM]
            tot[k] += len(big)
            show = show or bool(big)
            f0 = ang(rel(idle[key], "UpperTorso", s + "UpperArm").T @ rel(fr[0], "UpperTorso", s + "UpperArm")) if idle[key] else float("nan")
            txt.append("%s max %3.0f f0 %3.0f %s" % (s[0], max(st), f0, ",".join("f%d:%.0f" % b for b in big[:3]) + ("+" if len(big) > 3 else "")))
        cells.append("%-46s" % " ".join(txt))
    if show or clips:
        print("%-22s %s" % (nm, " | ".join(cells)))
print("upper-arm steps over %.0f deg in a frame: %s" % (LIM, " | ".join("%s %d" % (os.path.basename(os.path.normpath(d)), t) for d, t in zip(dirs, tot))))
