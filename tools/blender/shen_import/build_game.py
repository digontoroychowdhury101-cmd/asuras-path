"""Cut Shen's two supplied sculpts into the game's MeshParts with no decimation: every source triangle, split normal and UV passes through untouched.

    python3 tools/blender/shen_import/skin_rig.py [1 2]     (the skin weights this reads)
    python3 tools/blender/shen_import/build_game.py [1 2]
Writes assets/build/grandmaster_shen/Shen_P<n>_Game.glb     the skinned body and garments: one node per piece, each under PIECE_CAP triangles, all bound to one skeleton, sharing the sculpt's three 2048 maps
       assets/build/grandmaster_shen/Shen_P<n>_Props.glb    the rigid things welded to a limb: the guandao, phase 2's floating beads
       work/opening_cast_bake/shen<n>/pieces.json            bone, role and bounds of every piece, for bind_skin.py and check_skin.py
       work/shen_import/samples_p<n>.npz                     per-bone rest points for the clip validator
       assets/source/bosses/grandmaster_shen/manifest_p<n>.json   the per-chunk manifest (tracked copy: outputs/grandmaster-shen-2026-11-05/)
Trousers: skin_rig.split_trousers parts the dark trouser triangles from the robe tiers they were fused into (doubling the seam's vertices); every source triangle, normal and UV is kept.
Underlayer: a sculpt is a surface, so what the robe covers is hollow. A dark closed core under the robe and a thin thigh inside it stop a lifting hem from showing the void. They are the only added triangles and are counted separately.
"""
import json
import os
import struct
import sys
import zlib

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "../../.."))
sys.path[:0] = [HERE, os.path.join(ROOT, "tools/blender/bull_import")]
import glb  # noqa: E402
import landmarks as LM  # noqa: E402
import rigdef as RD  # noqa: E402
import rigspace as RS  # noqa: E402
import segment as Seg  # noqa: E402
import skin_rig as SR  # noqa: E402

PIECE_CAP = 18000
SUB = 2  # icosphere: 320 triangles


def icosphere(sub=SUB):
    t = (1 + 5 ** 0.5) / 2
    v = [(-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t), (0, -1, -t), (0, 1, -t), (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1)]
    f = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
    v = [tuple(float(a) for a in x) for x in v]
    for _ in range(sub):
        mid, nf = {}, []

        def m(a, b):
            k = (min(a, b), max(a, b))
            if k not in mid:
                mid[k] = len(v)
                v.append(tuple((np.array(v[a]) + np.array(v[b])) / 2))
            return mid[k]
        for a, b, c in f:
            ab, bc, ca = m(a, b), m(b, c), m(c, a)
            nf += [[a, ab, ca], [b, bc, ab], [c, ca, bc], [ab, bc, ca]]
        f = nf
    v = np.array(v)
    return v / np.linalg.norm(v, axis=1, keepdims=True), np.array(f)


def underlayer(J):
    """(carrier bone, centre, radii): only the core the robe hangs over. Skinned limbs close their own joints; these stop a robe that lifts from showing the hollow inside. fit() shrinks each one until it sits inside the sculpt's surface at rest."""
    a = np.array
    return [("LowerTorso", a(J.WAIST), (0.62, 0.42, 0.46)), ("LowerTorso", a(J.PELVIS) + (0, -0.25, 0), (0.70, 0.46, 0.50))]


def fit(c, r, surface):
    """Largest scale of the ellipsoid that keeps every surface point outside it, with a margin. A joint outside the sculpt would come back tiny, so report it."""
    s = float(np.min(np.linalg.norm((surface - c) / np.array(r), axis=1)))
    return np.array(r) * min(1.0, s * 0.94), s


def tube(a, b, rmax, surface, sides=14, rings=7):
    """A closed tapered tube along a->b (the thigh the sculpt never had), each ring shrunk to stay inside the robe. Returns positions, normals, triangles."""
    a, b = np.array(a, float), np.array(b, float)
    ax = (b - a) / np.linalg.norm(b - a)
    u = np.cross(ax, (1, 0, 0))
    u /= np.linalg.norm(u)
    v = np.cross(ax, u)
    P, N = [], []
    for i in range(rings):
        t = i / (rings - 1)
        c = a + (b - a) * t
        near = np.linalg.norm(surface - c, axis=1).min()
        r = max(min(rmax, near * 0.9), 0.1) * (0.55 if i in (0, rings - 1) else 1.0)
        for k in range(sides):
            ang = 2 * np.pi * k / sides
            d = u * np.cos(ang) + v * np.sin(ang)
            P.append(c + d * r)
            N.append(d)
    P.append(a - ax * 0.05)
    N.append(-ax)
    P.append(b + ax * 0.05)
    N.append(ax)
    T = []
    for i in range(rings - 1):
        for k in range(sides):
            p, q = i * sides + k, i * sides + (k + 1) % sides
            T += [[p, p + sides, q], [q, p + sides, q + sides]]
    s0, s1 = rings * sides, rings * sides + 1
    for k in range(sides):
        T += [[s0, k, (k + 1) % sides], [s1, (rings - 1) * sides + (k + 1) % sides, (rings - 1) * sides + k]]
    return np.array(P), np.array(N), np.array(T)


def split(centres):
    """Median cuts along the longest axis until each part is under the cap: compact parts, so each is culled on its own."""
    out = []

    def go(ix):
        count = int(np.ceil(len(ix) / PIECE_CAP))
        if count <= 1:
            out.append(ix)
            return
        c = centres[ix]
        axis = np.argmax(c.max(0) - c.min(0))
        o = ix[np.argsort(c[:, axis], kind="stable")]
        n = len(o) * (count // 2) // count
        go(o[:n])
        go(o[n:])
    go(np.arange(len(centres)))
    return out


def write_skinned(path, src, pieces, bones):
    """pieces: (name, positions, normals, uvs, indices, joints, weights). A flat skeleton: Root at the origin, every other bone translate-only under it, all rest rotations identity, Roblox's rig rules."""
    j = {"asset": {"version": "2.0", "generator": "tools/blender/shen_import"}, "scene": 0, "scenes": [{"nodes": []}], "nodes": [], "meshes": [], "skins": [],
         "accessors": [], "bufferViews": [], "buffers": [{}], "samplers": src.json.get("samplers", [{}]), "textures": src.json["textures"], "materials": src.json["materials"], "images": []}
    blob = bytearray()

    def view(data, target=None):
        while len(blob) % 4:
            blob.append(0)
        bv = {"buffer": 0, "byteOffset": len(blob), "byteLength": len(data)}
        if target:
            bv["target"] = target
        blob.extend(data)
        j["bufferViews"].append(bv)
        return len(j["bufferViews"]) - 1

    def accessor(arr, kind, typ, target=None, minmax=False):
        count = {"SCALAR": arr.size, "MAT4": len(arr)}.get(typ, len(arr))
        a = {"bufferView": view(arr.tobytes(), target), "componentType": kind, "count": count, "type": typ}
        if minmax:
            a["min"], a["max"] = arr.min(0).tolist(), arr.max(0).tolist()
        j["accessors"].append(a)
        return len(j["accessors"]) - 1
    for i, im in enumerate(src.json["images"]):
        j["images"].append({"name": im.get("name", f"image{i}"), "mimeType": im["mimeType"], "bufferView": view(src.image(i))})
    # the skeleton
    first = 0
    children = list(range(first + 1, first + len(bones)))
    for k, b in enumerate(bones):
        node = {"name": b["name"]}
        if k == 0:
            node["children"] = children
        else:
            node["translation"] = [float(x) for x in b["at"]]
        j["nodes"].append(node)
    j["scenes"][0]["nodes"].append(first)
    ibm = np.zeros((len(bones), 4, 4), np.float32)
    for k, b in enumerate(bones):
        ibm[k] = np.eye(4, dtype=np.float32)
        ibm[k, 3, :3] = [-float(x) for x in b["at"]]   # column-major: the translation is the last column
    j["skins"].append({"name": "ShenSkeleton", "joints": list(range(len(bones))), "skeleton": first, "inverseBindMatrices": accessor(ibm, 5126, "MAT4")})
    for name, p, n, u, tri, jt, wt in pieces:
        prim = {"attributes": {"POSITION": accessor(p.astype(np.float32), 5126, "VEC3", 34962, True), "NORMAL": accessor(n.astype(np.float32), 5126, "VEC3", 34962),
                               "TEXCOORD_0": accessor(u.astype(np.float32), 5126, "VEC2", 34962), "JOINTS_0": accessor(jt.astype(np.uint8), 5121, "VEC4", 34962),
                               "WEIGHTS_0": accessor(wt.astype(np.float32), 5126, "VEC4", 34962)},
                "indices": accessor(tri.astype(np.uint32).ravel(), 5125, "SCALAR", 34963), "material": 0}
        j["meshes"].append({"name": name, "primitives": [prim]})
        j["nodes"].append({"name": name, "mesh": len(j["meshes"]) - 1, "skin": 0})
        j["scenes"][0]["nodes"].append(len(j["nodes"]) - 1)
    while len(blob) % 4:
        blob.append(0)
    j["buffers"][0]["byteLength"] = len(blob)
    head = json.dumps(j, separators=(",", ":")).encode()
    head += b" " * (-len(head) % 4)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(head) + 8 + len(blob)))
        f.write(struct.pack("<II", len(head), 0x4E4F534A))
        f.write(head)
        f.write(struct.pack("<II", len(blob), 0x004E4942))
        f.write(blob)


def fissures(g, lab, J, vp, vn, cen):
    """Phase 2's glowing cracks as isolated effect geometry: a copy of the source triangles the colour map paints as hot red on his skin, lifted a hair off the surface, per bone.
    The source mesh is untouched; bind_skin.py makes these Neon, and the blade, horns, wraps and ribbons (which are red paint, not fire) stay out."""
    _, hue, sat, val = Seg.sample_colour(g, 2)
    hot = ((hue < 18) | (hue > 345)) & (sat > 0.6) & (val > 0.4)
    out = {}
    for bone in ("UpperTorso", "RightUpperArm"):   # where the sculpt's skin carries cracks; forearm wraps, sash, ribbons, horns and blade are red paint, not fire
        ix = np.nonzero(hot & (lab == J.NAMES.index(bone)))[0]
        if len(ix) < 30:
            continue
        tri = g.idx[ix]
        used, inv = np.unique(tri, return_inverse=True)
        out[bone] = (vp[used] + vn[used] * 0.006, vn[used], g.uv[used], inv.reshape(-1, 3), used)
    return out


def png_bytes(a):
    """A plain RGB PNG with no image library."""
    h, w, _ = a.shape
    raw = b"".join(b"\0" + a[y].tobytes() for y in range(h))

    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d))
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 7)) + chunk(b"IEND", b"")


def smoothstep(x, a, b):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def paint_orbs(g, tex, normal, rough):
    """The remade orbs' own patch: polished dark blood-glass with crimson veins and a lit heart, flat in the normal map and glossy in the roughness."""
    cx, cy, half = g.orb_patch
    h, w = tex.shape[:2]
    x0, x1 = int((cx - half) * w) - 2, int((cx + half) * w) + 2
    y0, y1 = int((cy - half) * h) - 2, int((cy + half) * h) + 2
    xs, ys = np.meshgrid((np.arange(x0, x1) + 0.5) / w, (np.arange(y0, y1) + 0.5) / h)
    px, py = (xs - cx) / (half * 0.9), (ys - cy) / (half * 0.9)
    r = np.clip(np.hypot(px, py), 0, 1.2)
    veins = np.sin(px * 13 + np.sin(py * 9) * 2.2) * np.sin(py * 11 + np.sin(px * 7) * 2.4)
    veins = smoothstep(np.abs(veins), 0.28, 0.0)
    heart = smoothstep(r, 0.95, 0.15)
    colour = np.array([38.0, 3.0, 7.0])[None, None] + heart[..., None] * np.array([150.0, 8.0, 12.0]) + veins[..., None] * (0.35 + 0.65 * heart[..., None]) * np.array([120.0, 22.0, 16.0])
    tex[y0:y1, x0:x1, :3] = np.clip(colour, 0, 255).astype(np.uint8)
    normal[y0:y1, x0:x1, :3] = (128, 128, 255)
    rough[y0:y1, x0:x1, :3] = (255, 38, 0)      # glTF: occlusion, roughness, metalness


def blacken_hair(g, lab, J, vp):
    """Phase 2: only his hair turns black, in this form's copy of the colour map; the source GLB and its map are never touched. It is decided texel by texel: on the scalp and the flowing hair whatever is not the red of a horn goes dark; on the face and in the beard only hair's cool silver does (his skin is warm, the hair blue-grey), so the skin, eyes, brows and horns keep their colour."""
    root = os.path.join(ROOT, "work/shen_import")
    tex = np.load(os.path.join(root, "tex_p2_color.npy"))
    normal = np.load(os.path.join(root, "tex_p2_normal.npy")).copy()
    rough = np.load(os.path.join(root, "tex_p2_orm.npy")).copy()
    h, w = tex.shape[:2]
    cen = vp[g.idx].mean(1)
    head = lab == J.NAMES.index("Head")
    frontal = head & (cen[:, 2] < -0.2) & (cen[:, 1] < 1.88)
    scalp = (lab == J.NAMES.index("HairBack")) | (lab == J.NAMES.index("Beard")) | (head & ~frontal)
    fine = frontal
    rgb = tex[..., :3].astype(np.float32)
    top = rgb.max(2)
    sat = (top - rgb.min(2)) / np.maximum(top, 1.0)
    cool = (rgb[..., 2] - rgb[..., 0]) / 255.0
    by_colour = 1.0 - smoothstep(sat, 0.28, 0.55)
    by_cool = smoothstep(cool, 0.0, 0.022)
    amount = np.zeros((h, w), np.float32)
    for wanted, rule, margin in ((scalp, by_colour, 0.3), (fine, by_cool, 0.25)):
        for tri in g.uv[g.idx[wanted]]:
            px = tri * (w, h)
            x0, y0 = np.floor(px.min(0)).astype(int) - 1
            x1, y1 = np.ceil(px.max(0)).astype(int) + 2
            x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, w), min(y1, h)
            if x1 <= x0 or y1 <= y0:
                continue
            xs, ys = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
            a, b, c = px
            d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
            if abs(d) < 1e-9:
                continue
            u = ((b[1] - c[1]) * (xs - c[0]) + (c[0] - b[0]) * (ys - c[1])) / d
            v = ((c[1] - a[1]) * (xs - c[0]) + (a[0] - c[0]) * (ys - c[1])) / d
            inside = (u > -margin) & (v > -margin) & (u + v < 1 + margin)
            slab = amount[y0:y1, x0:x1]
            slab[inside] = np.maximum(slab[inside], rule[y0:y1, x0:x1][inside])
    # hair's silver left along the seams between UV islands goes too, spreading only over cool texels so skin is never reached
    for _ in range(5):
        near = amount.copy()
        near[1:] = np.maximum(near[1:], amount[:-1])
        near[:-1] = np.maximum(near[:-1], amount[1:])
        near[:, 1:] = np.maximum(near[:, 1:], amount[:, :-1])
        near[:, :-1] = np.maximum(near[:, :-1], amount[:, 1:])
        amount = np.maximum(amount, near * by_cool)
    dark = rgb * 0.1 + np.array([7.0, 7.0, 9.0])
    out = (rgb + (dark - rgb) * amount[..., None]).clip(0, 255).astype(np.uint8)
    print(f"  P2 hair: {int(scalp.sum())} flowing and {int(fine.sum())} facial triangles, {int((amount > 0.5).sum())} texels blackened")
    paint_orbs(g, out, normal, rough)
    images = {}
    for i, im in enumerate(g.json["images"]):
        if im.get("name") == "texture_diffuse":
            images[i] = png_bytes(out)
        elif im.get("name") == "texture_normal":
            images[i] = png_bytes(normal[..., :3])
        elif im.get("name") == "texture_metallic-texture_roughness":
            images[i] = png_bytes(rough[..., :3])
    source = g.image

    def image(i):
        return images.get(i) or source(i)
    g.image = image


def build(phase):
    J = LM.PHASES[phase]
    g = glb.Glb(Seg.source(phase))
    lab = np.load(os.path.join(ROOT, f"work/shen_import/labels_p{phase}.npy"))
    lab, _ = SR.split_trousers(g, lab, phase)   # the same parting the skin weights were made on
    assert len(lab) == len(g.idx)
    vp, vn = RS.to_rig(g.pos, phase), RS.normal_to_rig(g.nrm)
    if phase == 2:
        blacken_hair(g, lab, J, vp)
    cen = vp[g.idx].mean(1)
    # one dark texel: the darkest trouser surface
    px, _, _, val = Seg.sample_colour(g, phase)
    legs = (cen[:, 1] < -1.8) & (cen[:, 1] > -2.5) & (np.abs(cen[:, 0]) < 1.4)
    tri = np.nonzero(legs)[0][np.argmin(val[legs])]
    dark = g.uv[g.idx[tri]].mean(0)
    sv, sf = icosphere()
    body = np.isin(np.arange(len(J.NAMES)), [i for i, n in enumerate(J.NAMES) if n != "Weapon" and not n.startswith("Bead")])
    surface = vp[np.unique(g.idx[body[lab]])]
    fitted = []
    for carrier, c, r in underlayer(J):
        rr, s = fit(c, r, surface)
        if s < 0.35:
            print(f"  P{phase} underlayer in {carrier} at {np.round(c, 2)} barely fits (scale {s:.2f})")
        fitted.append((carrier, c, rr))
    socks = fitted
    tubes = {}
    for side, hip, kn, an in (("Right", J.RHIP, J.RKN, J.RAN), ("Left", J.LHIP, J.LKN, J.LAN)):
        tubes[side + "UpperLeg"] = tube(hip, kn, 0.21, surface)
    joints, helpers = RD.JOINT[phase], RD.HELPER[phase]
    skin = np.load(os.path.join(ROOT, f"work/shen_import/skin_p{phase}.npz"))
    vj, vw = skin["joints"], skin["weights"]
    with open(os.path.join(ROOT, f"work/shen_import/cloth_p{phase}.json")) as f:
        cloth = json.load(f)
    bone_ix = {b["name"]: i for i, b in enumerate(cloth["bones"])}
    pieces, props, info, rng = [], [], {}, np.random.default_rng(7)
    samples = {}
    src_total, added_total = 0, 0
    for i, n in enumerate(J.NAMES):
        ix = np.nonzero(lab == i)[0]
        if not len(ix):
            raise SystemExit(f"P{phase}: {n} has no triangles")
        tri = g.idx[ix]
        used = np.unique(tri)
        samples[n] = vp[used][rng.choice(len(used), min(1500, len(used)), replace=False)].astype(np.float32)
        extras = [s for s in socks if s[0] == n]
        parts = split(cen[ix])
        for k, part in enumerate(parts):
            t = tri[part]
            used, inv = np.unique(t, return_inverse=True)
            P, N, U, T = vp[used], vn[used], g.uv[used], inv.reshape(-1, 3)
            Jt, Wt = vj[used], vw[used]
            src = len(T)
            if k == 0 and extras:
                for _, c, r in extras:
                    base = len(P)
                    P = np.vstack((P, sv * r + c))
                    nn = sv / np.array(r)
                    N = np.vstack((N, nn / np.linalg.norm(nn, axis=1, keepdims=True)))
                    U = np.vstack((U, np.tile(dark, (len(sv), 1))))
                    T = np.vstack((T, sf + base))
                    xj, xw = SR.limb_weights(J, sv * r + c, n)
                    Jt, Wt = np.vstack((Jt, xj)), np.vstack((Wt, xw))
            if k == 0 and n in tubes:
                tp, tn, tt = tubes[n]
                base = len(P)
                P, N = np.vstack((P, tp)), np.vstack((N, tn))
                U = np.vstack((U, np.tile(dark, (len(tp), 1))))    # the trouser
                T = np.vstack((T, tt + base))
                xj, xw = SR.limb_weights(J, tp, n)
                Jt, Wt = np.vstack((Jt, xj)), np.vstack((Wt, xw))
            name = f"Shen{phase}_{n}" + (f"_{k + 1}" if len(parts) > 1 else "")
            assert len(T) < 20000, f"{name}: {len(T)}"
            lo, hi = P.min(0), P.max(0)
            rigid = n in SR.RIGID
            bone = RD.bone_of(phase, n) if rigid else "HumanoidRootPart"
            info[name] = {"bone": bone, "role": "Weapon" if n == "Weapon" else None, "centre": ((lo + hi) / 2).tolist(), "size": (hi - lo).tolist(), "tris": len(T), "source_tris": src,
                          "group": n, "material": "shared 2048 colour/normal/metal-rough", "skinned": not rigid}
            if rigid:
                props.append((name, P, N, U, T))
            else:
                pieces.append((name, P, N, U, T, Jt, Wt))
            if bone in helpers:
                info[name]["joint"] = list(helpers[bone][1])
            src_total += src
            added_total += len(T) - src
    assert src_total == len(g.idx), (src_total, len(g.idx))
    glow_total = 0
    if phase == 2:
        for bone, (P, N, U, T, used) in fissures(g, lab, J, vp, vn, cen).items():
            name = f"Shen2_Fissure_{bone}"
            assert len(T) < 20000, f"{name}: {len(T)}"
            pieces.append((name, P, N, U, T, vj[used], vw[used]))
            lo, hi = P.min(0), P.max(0)
            info[name] = {"bone": "HumanoidRootPart", "skinned": True, "role": "Glow", "centre": ((lo + hi) / 2).tolist(), "size": (hi - lo).tolist(), "tris": len(T), "source_tris": 0, "group": "Fissure", "material": "Neon (isolated effect copy)"}
            glow_total += len(T)
    out = os.path.join(ROOT, "assets/build/grandmaster_shen")
    os.makedirs(out, exist_ok=True)
    write_skinned(os.path.join(out, f"Shen_P{phase}_Game.glb"), g, pieces, cloth["bones"])
    glb.write(os.path.join(out, f"Shen_P{phase}_Props.glb"), g, props)
    bake = os.path.join(ROOT, f"work/opening_cast_bake/shen{phase}")
    os.makedirs(bake, exist_ok=True)
    with open(os.path.join(bake, "pieces.json"), "w") as f:
        json.dump(info, f, indent=1)
    report = os.path.join(ROOT, "outputs/grandmaster-shen-2026-11-05")
    os.makedirs(report, exist_ok=True)
    manifest = {"phase": phase, "source_triangles": src_total + getattr(g, "orb_replaced", 0) - getattr(g, "orb_new", 0), "orbs_remade": {"source_triangles_replaced": getattr(g, "orb_replaced", 0), "sphere_triangles": getattr(g, "orb_new", 0)}, "underlayer_triangles": added_total, "fissure_glow_triangles": glow_total, "pieces": len(info), "largest_piece": max(v["tris"] for v in info.values()), "source_sha256_file": "asset-audit.json",
                "decimated": False, "transform": {"scale": RS.S, "ground": RS.GROUND, "offset_xz": RS.OFFSET[phase], "gy_min": RS.GY_MIN[phase]}, "chunks": {k: {x: v[x] for x in ("bone", "group", "role", "tris", "source_tris", "centre")} for k, v in info.items()}}
    with open(os.path.join(report, f"chunk_manifest_p{phase}.json"), "w") as f:
        json.dump(manifest, f, indent=1)
    np.savez(os.path.join(ROOT, f"work/shen_import/samples_p{phase}.npz"), **samples)
    print(f"P{phase}: {len(pieces)} pieces, source {src_total} (untouched) + underlayer {added_total} + glow {glow_total}; biggest {manifest['largest_piece']}")


if __name__ == "__main__":
    for ph in [int(x) for x in sys.argv[1:]] or [1, 2]:
        build(ph)
