# xraytable.py TABLE.md LOGNAME CLIP... : rewrite the x-ray table's rows for CLIP (P<n>_<name>) from the x-ray renders in work/shen_repair/rv5
# (render_cmp.py's review.py logs, front camera, arm skin inside UpperTorso): before = <shot>_pre4L, after = <shot>_fin5L, measured exactly as
# render_cmp.py's clashsum (frames lit, deepest). LOGNAME goes in the last column. Rows for other clips are kept as they are.
import os, sys
table, logname, clips = sys.argv[1], sys.argv[2], sys.argv[3:]
RV = "work/shen_repair/rv5"


def clashsum(log):
    n = lit = 0
    md = 0.0
    for line in open(log, errors="replace"):
        if "CLASH frame" in line:
            parts = line.split()
            n += 1
            c, dd = float(parts[3]), float(parts[-1])
            lit += c > 0
            md = max(md, dd)
    return md, lit, n


rows = open(table, encoding="utf-8").read().split("\n")
done = set()
for k, line in enumerate(rows):
    cells = [c.strip() for c in line.strip().strip("|").split("|")]
    if len(cells) < 5 or cells[0] not in clips:
        continue
    clip = cells[0]
    shot = "f%s_%s" % (clip[1], clip[3:])
    b = clashsum(os.path.join(RV, "%s_pre4L_UpperTorso_front.log" % shot))
    a = clashsum(os.path.join(RV, "%s_fin5L_UpperTorso_front.log" % shot))
    assert b[2] and a[2] and b[2] == a[2], (clip, b, a)
    d = a[0] - b[0]
    tag = " (rise)" if d >= 0.005 else " (lower)" if d <= -0.005 else ""
    past = " **past 0.18**" if a[0] > 0.18 else ""
    rows[k] = "| %s | %.3f / %d of %d | %.3f / %d of %d%s | %+.3f%s | pre4L/fin5L, %s |" % (clip, b[0], b[1], b[2], a[0], a[1], a[2], past, d, tag, logname)
    done.add(clip)
missing = [c for c in clips if c not in done]
assert not missing, "no row for %s" % missing
open(table, "w", encoding="utf-8", newline="\n").write("\n".join(rows))
print("rows rewritten:", len(done))
