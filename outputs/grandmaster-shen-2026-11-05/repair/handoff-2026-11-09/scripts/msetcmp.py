import json, glob, sys, collections
S = (__import__("os").environ.get("SHEN_SCRATCH") or ROOT + "/work/shen_repair")
tags = sys.argv[1:] or ["pre", "mot", "fin"]
def load(tag):
    out = {}
    for f in glob.glob(S + "/mset_%s_*.json" % tag):
        for k, v in json.load(open(f)).items():
            out[k.rsplit("_", 1)[0]] = v
    return out
D = {t: load(t) for t in tags}
clips = sorted(set.intersection(*[set(d) for d in D.values()]))
print("clips in common:", len(clips))
CLOTH = ("Robe", "Ribbon", "Sash", "Skirt", "Tassel", "Sleeve")
def kind(p):
    a, b = p.split(" in ")
    if any(a.startswith(c) for c in CLOTH): return "cloth"
    if a.startswith(("Right", "Left")) and "weapon" in b: return "arm-in-weapon"
    if b.startswith(("Right", "Left")) and "Arm" in b and a == "weapon": return "weapon-in-arm"
    return "other"
agg = {t: collections.defaultdict(lambda: [0, 0.0, 0.0]) for t in tags}
for t in tags:
    for c in clips:
        for p, v in D[t][c]["pairs"].items():
            k = kind(p)
            a = agg[t][k]
            if v["deepest"] >= 0.05: a[0] += 1
            a[1] += v["share"] * v["deepest"]
            a[2] = max(a[2], v["deepest"])
for k in ("cloth", "arm-in-weapon", "weapon-in-arm", "other"):
    print("%-14s " % k + " | ".join("%s: n>=.05 %3d  sum(share*deep) %.3f  max %.3f" % (t, *agg[t][k]) for t in tags))
# per-pair worst offenders in the last tag, with the others alongside
rows = []
for c in clips:
    for p, v in D[tags[-1]][c]["pairs"].items():
        if kind(p) in ("cloth", "arm-in-weapon", "weapon-in-arm") and v["deepest"] >= 0.05 and v["share"] >= 0.1:
            prev = [D[t][c]["pairs"].get(p) for t in tags[:-1]]
            rows.append((v["share"] * v["deepest"], c, p, v, prev))
rows.sort(reverse=True)
for s, c, p, v, prev in rows[:int(sys.argv[0] and 45)]:
    print("%-24s %-32s %s  %s" % (c, p, "%3.0f%% %.3f f%d" % (v["share"] * 100, v["deepest"], v["frame"]), " | ".join("%s %s" % (t, "%3.0f%% %.3f" % (q["share"] * 100, q["deepest"]) if q else "   -       ") for t, q in zip(tags[:-1], prev))))
