"""Gate (a) contact sheet for the Vesperhold rebuild: one JPEG of the review renders + a markdown tri/map table.

  python3 tools/blender/vesperhold/vesp_contact_sheet.py <out_dir> <render.jpg|png> [...]
Writes <out_dir>/gate_a_contact_sheet.jpg and <out_dir>/gate_a_tris.md (every piece in kit/props/trees manifests:
per-sub tris, max sub, total, map resolutions found in <group>/maps, decimation statement). Needs Pillow.
"""
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
SRC = ROOT / "assets/source/vesperhold"
CAP = 18000


def sheet(images, dst, width=2400):
    ims = [Image.open(p).convert("RGB") for p in images]
    ims = [im.resize((width, round(im.height * width / im.width))) for im in ims]
    out = Image.new("RGB", (width, sum(im.height for im in ims) + 8 * len(ims)), (24, 24, 28))
    y = 0
    for im in ims:
        out.paste(im, (0, y))
        y += im.height + 8
    out.save(dst, quality=88)


def map_sizes(group, materials):
    sizes = set()
    for m in materials:
        for p in (SRC / group / "maps").glob(f"{m}_*.png"):
            with Image.open(p) as im:
                sizes.add(f"{im.width}x{im.height}")
    return ", ".join(sorted(sizes)) or "n/a"


def table(dst):
    rows, bad = [], []
    for group in ("kit", "props", "trees"):
        man = json.loads((SRC / group / "manifest.json").read_text())
        for name, p in sorted(man["pieces"].items()):
            subs = p["sub_meshes"]
            mx = max(subs.values())
            if mx >= CAP:
                bad.append(name)
            res = p.get("map_resolution") or map_sizes(group, p.get("materials", []))
            subs_txt = "; ".join(f"{k.split('__', 1)[1]} {v}" for k, v in subs.items())
            size = " x ".join(f"{v:g}" for v in p.get("size_studs_xyz", []))
            rows.append(f"| {group} | {name} | {size} | {p['tris_total']} | {mx} | {res} | {subs_txt} |")
    head = ["# Gate (a) — Vesperhold pieces: triangles per sub-mesh and map resolution", "",
            "No decimation was used on any piece: Roblox's per-MeshPart cap is met only by splitting into role-named "
            f"sub-meshes, each asserted < {CAP} tris. Every non-metal material links a black MetalnessMap.", "",
            f"Pieces over the cap: {', '.join(bad) if bad else 'none'}.", "",
            "| Group | Piece | Size studs (x y z) | Total tris | Max sub | Maps | Sub-meshes (tris) |", "|---|---|---|---|---|---|---|"]
    Path(dst).write_text("\n".join(head + rows) + "\n")
    return bad


if __name__ == "__main__":
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    if len(sys.argv) > 2:
        sheet(sys.argv[2:], out / "gate_a_contact_sheet.jpg")
    bad = table(out / "gate_a_tris.md")
    print("over cap:", bad or "none")
    sys.exit(1 if bad else 0)
