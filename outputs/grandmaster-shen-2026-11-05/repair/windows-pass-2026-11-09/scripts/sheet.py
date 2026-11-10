# sheet.py SHOT VA VB OUT.png [FRAME,...] : (Windows pass 2026-11-10) a before/after contact sheet of render_cmp.py's x-ray frames
# ($SHEN_SCRATCH/rv5/<SHOT>_<V>_UpperTorso_front/f_NNNNN.png), cropped to the body: VA on the top row, VB below, the given frames (default 8 spread
# over the shot plus each version's deepest frame from its review log), labelled with the frame and the deepest arm vertex in the torso.
import os, sys, re
from PIL import Image, ImageDraw
ROOT = os.environ.get("SHEN_ROOT") or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../../.."))
S = os.environ.get("SHEN_SCRATCH") or os.path.join(ROOT, "work", "shen_repair")
shot, va, vb, out = sys.argv[1:5]
dirs = {v: os.path.join(S, "rv5", "%s_%s_UpperTorso_%s" % (shot, v, os.environ.get("CAM", "front"))) for v in (va, vb)}
deep = {}
for v in (va, vb):
    deep[v] = {}
    for line in open(dirs[v] + ".log", errors="replace"):
        m = re.search(r"CLASH frame (\d+): (\d+) .* deepest ([0-9.]+)", line)
        if m:
            deep[v][int(m.group(1))] = float(m.group(3))
frames = sorted(int(f[2:7]) for f in os.listdir(dirs[va]) if f.endswith(".png"))
if len(sys.argv) > 5:
    pick = [int(x) for x in sys.argv[5].split(",")]
else:
    k = 8
    pick = sorted(set([frames[int(i * (len(frames) - 1) / (k - 1))] for i in range(k)] + [max(deep[v], key=deep[v].get) for v in (va, vb) if deep[v]]))
W = Hh = int(os.environ.get("SIZE", "240"))
sheet = Image.new("RGB", (W * len(pick), Hh * 2 + 20), "white")
d = ImageDraw.Draw(sheet)
for r, v in enumerate((va, vb)):
    for c, f in enumerate(pick):
        p = os.path.join(dirs[v], "f_%05d.png" % f)
        if not os.path.exists(p):
            continue
        im = Image.open(p).convert("RGB").crop((160, 40, 480, 360)).resize((W, Hh))
        sheet.paste(im, (c * W, 20 + r * Hh))
        d.text((c * W + 4, 22 + r * Hh), "%s f%d %.3f" % (v, f, deep[v].get(f, 0.0)), fill=(0, 0, 0))
d.text((4, 4), "%s x-ray (arm skin inside UpperTorso magenta); top %s, bottom %s" % (shot, va, vb), fill=(0, 0, 0))
sheet.save(out)
print(out, pick)
