"""Keep src/shared/VesperholdLayout.luau Layout.Piece equal to the generator manifests' bounding boxes.
python3 tools/assets/vesperhold_layout_sizes.py          # list drift (exit 1 if any)
python3 tools/assets/vesperhold_layout_sizes.py --write  # rewrite Layout.Piece from assets/source/vesperhold/{kit,props,trees}/manifest.json
Layout.Piece is { width = x, height = z, depth = y } of size_studs_xyz (Blender z-up); tree pieces average their _A/_B variants;
Flying_Buttress_40 is { y, z, x } because the layout runs it along Z and the kit along X. Pieces with no manifest entry are left alone."""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LAYOUT = ROOT / "src/shared/VesperholdLayout.luau"
TOL = 0.15
ENTRY = re.compile(r"(\w+) = \{ ([\d.]+), ([\d.]+), ([\d.]+) \}")


def manifest_sizes():
    out = {}
    for pack in ("kit", "props", "trees"):
        for name, v in json.loads((ROOT / f"assets/source/vesperhold/{pack}/manifest.json").read_text())["pieces"].items():
            out[name] = v["size_studs_xyz"]
    return out


def wanted(name, man):
    s = man.get(name)
    if s is not None:
        return [s[1], s[2], s[0]] if name == "Flying_Buttress_40" else [s[0], s[2], s[1]]
    a, b = man.get(name + "_A"), man.get(name + "_B")
    return [(a[0] + b[0]) / 2, (a[2] + b[2]) / 2, (a[1] + b[1]) / 2] if a and b else None


def block(src):
    i = src.index("Layout.Piece = {")
    return i, src.index("\n}\n", i)


def drift(src=None):
    src = src or LAYOUT.read_text()
    i, j = block(src)
    man, bad, compared = manifest_sizes(), [], 0
    for m in ENTRY.finditer(src[i:j]):
        want = wanted(m[1], man)
        if want:
            compared += 1
            have = [float(m[k]) for k in (2, 3, 4)]
            if any(abs(h - w) > TOL for h, w in zip(have, want)):
                bad.append(f"{m[1]}: layout {have} manifest {[round(w, 1) for w in want]}")
    return bad, compared


def write():
    src = LAYOUT.read_text()
    i, j = block(src)
    man = manifest_sizes()

    def rep(m):
        w = wanted(m[1], man)
        return m[0] if not w else f"{m[1]} = {{ {', '.join('%g' % round(n, 1) for n in w)} }}"

    LAYOUT.write_text(src[:i] + ENTRY.sub(rep, src[i:j]) + src[j:])


if __name__ == "__main__":
    if "--write" in sys.argv:
        write()
    bad, n = drift()
    print("\n".join(bad) or f"OK: {n} pieces match their manifests")
    sys.exit(1 if bad else 0)
