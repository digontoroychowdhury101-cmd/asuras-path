# revaltable.py BEFORE.txt AFTER.txt [CLIP ...] : (Windows pass 2026-11-10) revalidate.py lines (with entry) of two bake sets as a Markdown table:
# deepest arm in his torso on frames, between frames and fading in (each the worse of right and left; the validator flags past 0.18), and the
# problems it lists. Clips whose numbers or problems differ, or the named ones.
import re, sys

PAT = re.compile(r"^(\S+)\s+R ([\d.]+) L ([\d.]+) entry ([\d.]+)/([\d.]+) between R (\(([\d.]+), (\d+)\)|None) L (\(([\d.]+), (\d+)\)|None) \| (\[.*\])")


def load(path):
    out = {}
    for line in open(path, encoding="utf-8"):
        m = PAT.match(line)
        if not m:
            continue
        g = m.groups()
        bR = float(g[6]) if g[6] else 0.0
        bL = float(g[9]) if g[9] else 0.0
        frames = max(float(g[1]), float(g[2]))
        between = max(bR, bL)
        out[g[0]] = (frames, between, max(float(g[3]), float(g[4])), g[11])
    return out


A, B = load(sys.argv[1]), load(sys.argv[2])
names = sys.argv[3:] or [n for n in sorted(B) if n not in A or A[n] != B[n]]
print("| Clip | Before: frames / between / fade in | Before problems | After: frames / between / fade in | After problems |")
print("|---|---|---|---|---|")
for n in names:
    a, b = A.get(n), B.get(n)
    fa = "%.3f / %.3f / %.3f" % a[:3] if a else "-"
    fb = "%.3f / %.3f / %.3f" % b[:3] if b else "-"
    pa = (a[3] if a and a[3] != "[]" else "none") if a else "-"
    pb = (b[3] if b and b[3] != "[]" else "none") if b else "-"
    print("| %s | %s | %s | %s | %s |" % (n, fa, pa.replace("|", "/"), fb, pb.replace("|", "/")))
