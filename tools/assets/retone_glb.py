"""Re-tone embedded textures of GLBs (mesh/accessor bytes untouched).

Usage (run with python3 -I):
  retone_glb.py IN.glb OUT.glb      re-tone one file
  retone_glb.py --all               every upload group -> work/mac-resume-2026-11-18/retone2/
  retone_glb.py --selfcheck         assert-based check on Crate_B, Canopy_Tree_A, Canopy_Tree_A_Far, Cart_B
v2: Roblox builds MetalnessMap from the glTF MR blue channel and ignores metallicFactor 0, so solid-255 B of
non-metal materials is zeroed; colour lifts are gentler because surfaces now render diffuse.
Needs Pillow + numpy.
"""
import sys
sys.path.insert(0, "/Users/digonto/Library/Python/3.14/lib/python/site-packages")
import io, json, re, struct, glob, os, hashlib
import numpy as np
from PIL import Image, ImageDraw

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
UP = REPO + "/assets/source/overworld/upload/"
OUT = REPO + "/work/mac-resume-2026-11-18/retone2/"
GROUPS = "slice bellwood_built_a bellwood_built_b bellwood_veg bellwood_far hero".split()
LIFT = {"Timber": 55, "Roof": 60, "Bark": 60}          # target mean luminance (whole image)
HSV = {"Leaf": (None, .62, None), "Conifer": (120, .55, None),  # (hue deg, sat, val) lit-mean targets
       "Grass": (95, .45, None)}                          # Fern colour unchanged
ROUGH_G = 204                                           # 0.80
FAR_ROUGH_G = 230                                       # 0.90


# ---------- GLB io ----------
def read_glb(path):
    b = open(path, "rb").read()
    assert b[:4] == b"glTF"
    n = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20:20 + n])
    o, bin_ = 20 + n, b""
    while o < len(b):
        l, t = struct.unpack("<II", b[o:o + 8])
        if t == 0x004E4942:
            bin_ = b[o + 8:o + 8 + l]
        o += 8 + l
    return j, bin_


def view_bytes(j, bin_, i):
    v = j["bufferViews"][i]
    o = v.get("byteOffset", 0)
    return bin_[o:o + v["byteLength"]]


def write_glb(path, j, views):
    """views: list of bytes aligned to j['bufferViews']; offsets/lengths rewritten, 4-byte aligned."""
    out = bytearray()
    for v, d in zip(j["bufferViews"], views):
        out += b"\0" * (-len(out) % 4)
        v["byteOffset"], v["byteLength"] = len(out), len(d)
        out += d
    out += b"\0" * (-len(out) % 4)
    j["buffers"][0]["byteLength"] = len(out)
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    total = 12 + 8 + len(js) + 8 + len(out)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(b"glTF" + struct.pack("<II", 2, total))
        f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
        f.write(struct.pack("<II", len(out), 0x004E4942) + bytes(out))


def png(a):
    bio = io.BytesIO()
    Image.fromarray(np.clip(np.rint(a), 0, 255).astype(np.uint8), "RGB").save(bio, "PNG")
    return bio.getvalue()


def load_img(raw):
    return np.asarray(Image.open(io.BytesIO(raw)).convert("RGB")).astype(np.float64)


# ---------- colour maths ----------
def to_hsv(a):
    a = a / 255.0
    mx, mn = a.max(-1), a.min(-1)
    d = mx - mn
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    dd = np.where(d == 0, 1, d)
    h = np.where(mx == r, ((g - b) / dd) % 6, np.where(mx == g, (b - r) / dd + 2, (r - g) / dd + 4)) * 60
    h = np.where(d == 0, 0, h)
    return h, np.where(mx == 0, 0, d / np.where(mx == 0, 1, mx)), mx


def from_hsv(h, s, v):
    c = v * s
    hp = (h % 360) / 60
    x = c * (1 - np.abs(hp % 2 - 1))
    z = np.zeros_like(c)
    sel = np.floor(hp).astype(int) % 6
    rgb = [(c, x, z), (x, c, z), (z, c, x), (z, x, c), (x, z, c), (c, z, x)]
    out = np.stack([np.choose(sel, [t[k] for t in rgb]) for k in range(3)], -1)
    return (out + (v - c)[..., None]) * 255


def lum(a):
    return a @ np.array([.2126, .7152, .0722])


def lit_stats(a):
    """lit = max>=40. Returns (hue of lit-mean rgb, mean S, mean V, lit fraction)."""
    lit = a.max(-1) >= 40
    if not lit.any():
        return None
    h, s, v = to_hsv(a[lit].mean(0)[None])
    _, s2, v2 = to_hsv(a[lit])
    return float(h[0]), float(s2.mean()), float(v2.mean()), float(lit.mean())


# ---------- transforms ----------
def lift(a, target):
    """v' = v^g on the max channel, rgb scaled by v'/v: keeps hue/sat, never clips."""
    v = np.maximum(a.max(-1), 1e-6) / 255
    lo, hi = 0.05, 1.0
    for _ in range(40):
        g = (lo + hi) / 2
        k = (v ** g / v)[..., None]
        if lum(a * k).mean() > target:
            lo = g
        else:
            hi = g
    return np.minimum(a * k, 255)


def hsv_retone(a, hue=None, sat=None, val=None, iters=4):
    """Move lit-pixel mean toward (hue, sat, val); near-black fill fades out via weight w."""
    w = np.clip((a.max(-1) - 30) / 40, 0, 1)
    for _ in range(iters):
        st = lit_stats(a)
        if st is None:
            return a
        h0, s0, v0, _ = st
        h, s, v = to_hsv(a)
        if hue is not None:
            h = h + (hue - h0) * w
        if sat is not None:
            s = np.clip(s * (1 + (sat / s0 - 1) * w), 0, 1)
        if val is not None:
            v = np.clip(v * (1 + (val / v0 - 1) * w), 0, 1)
        a = from_hsv(h, s, v)
    return a


def roughen(a):
    a = a.copy()
    a[..., 1] = np.maximum(a[..., 1], ROUGH_G)
    return a


def classify(name):
    """-> (kind, key) or None."""
    m = re.match(r"^Bell_(Timber|Roof|Bark)_Color$", name) or re.match(r"^Bell_\w*?(Timber)_Color$", name)
    if m:
        return "lift", m.group(1)
    m = re.match(r"^Bell_(Leaf|Conifer|Grass)_Color$", name)
    if m:
        return "hsv", m.group(1)
    m = re.match(r"^Bell_(Leaf|Conifer|Grass|Fern)_Roughness$", name)
    if m:
        return "rough", m.group(1)
    if re.match(r"^Bell_Far_\w+_Color$", name):
        return "far", "Conifer" if "Conifer" in name else "Leaf"
    return None


def unmetal(a):
    """B (metalness) uniformly >=250 -> 0; varying B (real metal data) untouched."""
    if a[..., 2].min() < 250:
        return a
    a = a.copy()
    a[..., 2] = 0
    return a


def nonmetal_mr_images(j):
    """Image indices of MR maps used by materials with explicit metallicFactor 0 (bronze/gold have none)."""
    out = set()
    for m in j.get("materials", []):
        p = m.get("pbrMetallicRoughness", {})
        t = p.get("metallicRoughnessTexture")
        if t and p.get("metallicFactor") == 0:
            out.add(j["textures"][t["index"]]["source"])
    return out


def apply_near(kind, key, a):
    if kind == "lift":
        return lift(a, LIFT[key])
    if kind == "hsv":
        return hsv_retone(a, *HSV[key])
    return roughen(a)


_REF = {}


def far_reference():
    """Retoned near bark / leaf / conifer lit stats (from the slice+veg source images)."""
    if not _REF:
        for key, piece, nm, kind in (("Bark", "slice/Canopy_Tree_A", "Bell_Bark_Color", "lift"),
                                     ("Leaf", "slice/Canopy_Tree_A", "Bell_Leaf_Color", "hsv"),
                                     ("Conifer", "bellwood_veg/Conifer_Tall", "Bell_Conifer_Color", "hsv")):
            j, b = read_glb(UP + piece + ".glb")
            i = next(k for k, im in enumerate(j["images"]) if im["name"] == nm)
            _REF[key] = lit_stats(apply_near(kind, key, load_img(view_bytes(j, b, j["images"][i]["bufferView"]))))
    return _REF


def apply_far(key, a):
    """Atlas: left half bark, right half leaves/needles -> match new near means."""
    ref, half = far_reference(), a.shape[1] // 2
    out = a.copy()
    for sl, k in ((slice(0, half), "Bark"), (slice(half, None), key)):
        h, s, v, _ = ref[k]
        out[:, sl] = lift_to_hsv(a[:, sl], h, s, v)
    return out


def lift_to_hsv(a, h, s, v):
    # whole half counts as lit: bypass the 40-threshold weight by padding-free direct mapping
    h0, s0, v0, _ = lit_stats(a)
    hh, ss, vv = to_hsv(a)
    return from_hsv(hh + (h - h0), np.clip(ss * s / s0, 0, 1), np.clip(vv * v / v0, 0, 1))


# ---------- per-file driver ----------
def retone_file(src, dst=None):
    """Returns list of (image name, before ndarray, after ndarray) changed; writes dst if anything changed."""
    j, bin_ = read_glb(src)
    views = [view_bytes(j, bin_, i) for i in range(len(j["bufferViews"]))]
    changed, mr = [], nonmetal_mr_images(j)
    for ii, im in enumerate(j.get("images", [])):
        name = im.get("name") or slot_name(j, ii)
        c = classify(name)
        if not c and ii not in mr:
            continue
        a = load_img(views[im["bufferView"]])
        if not c:
            c = ("metal", "")
            b = a
        else:
            b = apply_far(c[1], a) if c[0] == "far" else apply_near(c[0], c[1], a)
        if ii in mr:
            b = unmetal(b)
        if b is a:
            continue
        views[im["bufferView"]] = png(b)
        changed.append((name, a, b, c[0]))
        if c[0] == "far":
            add_far_pbr(j, views, ii, name, a.shape)
    if changed and dst:
        write_glb(dst, j, views)
    return changed


def slot_name(j, ii):
    """Fallback for unnamed images: material name + slot (base -> _Color, mr -> _Roughness)."""
    for m in j.get("materials", []):
        p = m.get("pbrMetallicRoughness", {})
        for slot, suffix in (("baseColorTexture", "Color"), ("metallicRoughnessTexture", "Roughness")):
            t = p.get(slot)
            if t and j["textures"][t["index"]].get("source") == ii:
                return f"{m.get('name', '')}_{suffix}"
    return ""


def add_far_pbr(j, views, base_img, name, shape):
    """Flat normal (128,128,255) + MR (R0,G~0.95,B0) images, same size as the atlas."""
    h, w = shape[:2]
    mat = next(m for m in j["materials"]
               if "baseColorTexture" in m.get("pbrMetallicRoughness", {})
               and j["textures"][m["pbrMetallicRoughness"]["baseColorTexture"]["index"]]["source"] == base_img)
    if "normalTexture" in mat and "metallicRoughnessTexture" in mat["pbrMetallicRoughness"]:
        return
    sampler = j["textures"][mat["pbrMetallicRoughness"]["baseColorTexture"]["index"]].get("sampler")
    stem = name[:-len("_Color")]
    for suffix, rgb, setter in (("Normal", (128, 128, 255), "n"), ("Roughness", (0, FAR_ROUGH_G, 0), "mr")):
        views.append(png(np.broadcast_to(np.array(rgb, float), (h, w, 3))))
        j["bufferViews"].append({"buffer": 0, "byteOffset": 0, "byteLength": 0})
        j["images"].append({"name": f"{stem}_{suffix}", "mimeType": "image/png", "bufferView": len(views) - 1})
        t = {"source": len(j["images"]) - 1}
        if sampler is not None:
            t["sampler"] = sampler
        j["textures"].append(t)
        ref = {"index": len(j["textures"]) - 1}
        if setter == "n":
            mat["normalTexture"] = ref
        else:
            mat["pbrMetallicRoughness"]["metallicRoughnessTexture"] = ref


def summ(a):
    st = lit_stats(a)
    h, s, v = to_hsv(a)
    return {"mean": [round(x) for x in a.mean((0, 1))], "lum": round(float(lum(a).mean()), 1),
            "litHSV": None if st is None else [round(st[0]), round(st[1], 3), round(st[2], 3)],
            "G": round(float(a[..., 1].mean()), 1)}


# ---------- --all ----------
def registered(group):
    f = {"slice": "SLICE", "bellwood_built_a": "BELLWOOD", "bellwood_built_b": "BELLWOOD",
         "bellwood_veg": "BELLWOOD", "bellwood_far": "BELLWOOD_FAR", "hero": "HERO"}[group]
    return set(json.load(open(f"{REPO}/assets/{f}_KIT_UPLOADED.json"))["modelAssets"])


def run_all():
    report, sheet, seen = {}, [], {}
    hero_color = {}
    for g in GROUPS:
        reg = registered(g)
        report[g] = []
        for p in sorted(glob.glob(UP + g + "/*.glb")):
            piece = os.path.basename(p)[:-4]
            ch = retone_file(p, f"{OUT}{g}/{piece}.glb")
            if not ch:
                continue
            if g == "hero":
                j, b = read_glb(p)
                for im in j["images"]:
                    if im["name"].endswith("_Color"):
                        hero_color[im["name"]] = summ(load_img(view_bytes(j, b, im["bufferView"])))
            report[g].append({"piece": piece, "registered": piece in reg, "images": [c[0] for c in ch]})
            for name, a, b, kind in ch:
                key = hashlib.md5(a.tobytes()).hexdigest()
                if key not in seen:
                    seen[key] = {"name": name, "before": summ(a), "after": summ(b), "pieces": 0}
                    sheet.append((name, a, b))
                seen[key]["pieces"] += 1
    unaffected = {}
    for f, gs in (("SLICE", ["slice"]), ("BELLWOOD", ["bellwood_built_a", "bellwood_built_b", "bellwood_veg"]),
                  ("BELLWOOD_FAR", ["bellwood_far"]), ("HERO", ["hero"])):
        reg = set(json.load(open(f"{REPO}/assets/{f}_KIT_UPLOADED.json"))["modelAssets"])
        unaffected[f] = sorted(reg - {r["piece"] for g in gs for r in report[g]})
    json.dump({"groups": report, "images": list(seen.values()), "heroColor": hero_color,
               "registeredButUnaffected": unaffected}, open(OUT + "report.json", "w"), indent=1)
    contact_sheet(sheet, OUT + "contact_sheet.png")
    for g, rows in report.items():
        reg = [r for r in rows if r["registered"]]
        print(f"{g}: affected {len(rows)} (registered {len(reg)}); unregistered {[r['piece'] for r in rows if not r['registered']]}")


def contact_sheet(rows, path, sw=200):
    W, H = 2 * sw + 330, 120
    im = Image.new("RGB", (W, H * len(rows)), (40, 40, 40))
    d = ImageDraw.Draw(im)
    for i, (name, a, b) in enumerate(rows):
        y = i * H
        for k, arr in enumerate((a, b)):
            t = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB").resize((sw - 8, H - 8), Image.NEAREST)
            im.paste(t, (4 + k * sw, y + 4))
        sa, sb = summ(a), summ(b)
        d.text((2 * sw + 8, y + 8), name, fill=(255, 255, 255))
        d.text((2 * sw + 8, y + 30), f"before mean {sa['mean']} lum {sa['lum']} G {sa['G']}", fill=(200, 200, 200))
        d.text((2 * sw + 8, y + 50), f"after  mean {sb['mean']} lum {sb['lum']} G {sb['G']}", fill=(200, 255, 200))
        d.text((2 * sw + 8, y + 70), f"HSV {sa['litHSV']} -> {sb['litHSV']}", fill=(200, 200, 255))
    im.save(path)


# ---------- selfcheck ----------
def selfcheck():
    import tempfile
    tmp = tempfile.mkdtemp()
    cases = [("bellwood_built_b/Crate_B", {"Bell_Timber_Color"}, 0), ("slice/Canopy_Tree_A", None, 0), ("bellwood_built_b/Cart_B", None, 0),
             ("bellwood_far/Canopy_Tree_A_Far", {"Bell_Far_Canopy_Tree_A_Color"}, 2)]
    for piece, want, extra_imgs in cases:
        dst = f"{tmp}/{os.path.basename(piece)}.glb"
        ch = retone_file(UP + piece + ".glb", dst)
        assert ch, piece
        if want:
            assert {c[0] for c in ch} >= want, (piece, [c[0] for c in ch])
        j0, b0 = read_glb(UP + piece + ".glb")
        j1, b1 = read_glb(dst)
        assert len(j1["images"]) == len(j0["images"]) + extra_imgs
        assert len(j1["materials"]) == len(j0["materials"])
        assert j1["accessors"] == j0["accessors"] and j1["meshes"] == j0["meshes"]
        img_views = {im["bufferView"] for im in j0["images"]}
        for i in range(len(j0["bufferViews"])):
            if i not in img_views:
                assert view_bytes(j0, b0, i) == view_bytes(j1, b1, i), ("bufferView", i)
        for v in j1["bufferViews"]:
            assert v["byteOffset"] % 4 == 0
        for im in j1["images"]:
            Image.open(io.BytesIO(view_bytes(j1, b1, im["bufferView"]))).load()
        for name, a, b, kind in ch:
            if kind == "lift":
                assert abs(lum(b).mean() - LIFT[classify(name)[1]]) < 3 and lum(a).mean() < lum(b).mean(), (name, lum(a).mean(), lum(b).mean())
            if kind == "hsv" and "Leaf" in name:
                sa, sb = lit_stats(a), lit_stats(b)
                assert sb[1] < sa[1] - .05 and abs(sb[1] - .62) < .04 and abs(sb[2] - sa[2]) < .03, (sa, sb)
            if kind == "far":
                assert lum(b).mean() != lum(a).mean()
        if extra_imgs:
            m = j1["materials"][0]
            assert "normalTexture" in m and "metallicRoughnessTexture" in m["pbrMetallicRoughness"]
        for ii, im in enumerate(j0["images"]):          # metal fix: non-metal MR B -> 0, metal MR B unchanged
            if not im["name"].endswith("_Roughness"):
                continue
            a0 = load_img(view_bytes(j0, b0, im["bufferView"]))
            a1 = load_img(view_bytes(j1, b1, j1["images"][ii]["bufferView"]))
            if ii in nonmetal_mr_images(j0):
                assert a0[..., 2].min() >= 250 and a1[..., 2].max() == 0, (piece, im["name"])
            else:
                assert "Metal-" in im["name"] and (a0[..., 2] == a1[..., 2]).all() and a1[..., 2].mean() > 150, (piece, im["name"])
        if piece.endswith("Cart_B"):
            assert sum("Metal-" in im["name"] for im in j1["images"]) == 1
        if extra_imgs:
            for im in j1["images"][-2:]:
                if im["name"].endswith("_Roughness"):
                    far_mr = load_img(view_bytes(j1, b1, im["bufferView"]))
                    assert far_mr[..., 2].max() == 0 and abs(far_mr[..., 1].mean() - FAR_ROUGH_G) < 1
        if piece.endswith("Canopy_Tree_A"):
            for im in j1["images"]:
                if im["name"] == "Bell_Leaf_Roughness":
                    assert load_img(view_bytes(j1, b1, im["bufferView"]))[..., 1].mean() >= ROUGH_G - 1
        print("OK", piece, [(c[0], summ(c[1])["lum"], summ(c[2])["lum"]) for c in ch])
    print("selfcheck passed")


if __name__ == "__main__":
    a = sys.argv[1:]
    if a == ["--selfcheck"]:
        selfcheck()
    elif a == ["--all"]:
        run_all()
    elif len(a) == 2:
        print([(c[0], summ(c[1]), summ(c[2])) for c in retone_file(a[0], a[1])])
    else:
        print(__doc__)
