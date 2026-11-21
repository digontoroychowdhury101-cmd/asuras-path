"""Split an embedded GLB into parts under the Open Cloud 20 MB file limit, copying bytes verbatim (no re-encode).

  python tools/assets/glb_split.py <in.glb> <out_dir> [--limit 19500000]
Writes <out_dir>/<stem>__p1.glb, __p2.glb ... (each holds whole sub-mesh nodes plus only the materials, textures and
images they use) and <out_dir>/<stem>.split.json: {part file: [node names]} plus per-sub foot-space centres in Roblox
axes (Roblox = glTF rotated 180 deg about Y: x -> -x, z -> -z; foot = bbox centre in X/Z, bbox minimum in Y), so the
loader can reassemble parts that come from different model assets. Exits 1 if one node alone exceeds the limit.
"""
import json
import struct
import sys
from pathlib import Path


def read(path):
    f = Path(path).read_bytes()
    n = struct.unpack("<I", f[12:16])[0]
    j = json.loads(f[20:20 + n])
    start = 20 + n + 8
    return j, f[start:start + struct.unpack("<I", f[20 + n:24 + n])[0]]


def view_bytes(j, b, i):
    v = j["bufferViews"][i]
    o = v.get("byteOffset", 0)
    return b[o:o + v["byteLength"]]


def deps(j, node):
    """Accessor, material, texture and image indices one mesh node needs."""
    acc, mats = set(), set()
    for pr in j["meshes"][j["nodes"][node]["mesh"]]["primitives"]:
        acc.update(pr["attributes"].values())
        if "indices" in pr:
            acc.add(pr["indices"])
        if "material" in pr:
            mats.add(pr["material"])
    tex = set()
    for m in mats:
        mat = j["materials"][m]
        refs = [mat.get(k) for k in ("normalTexture", "occlusionTexture", "emissiveTexture")]
        refs += [mat.get("pbrMetallicRoughness", {}).get(k) for k in ("baseColorTexture", "metallicRoughnessTexture")]
        tex.update(r["index"] for r in refs if r)
    return acc, mats, tex, {j["textures"][t]["source"] for t in tex}


def union(j, nodes):
    acc, mats, tex, imgs = set(), set(), set(), set()
    for n in nodes:
        a, m, t, i = deps(j, n)
        acc |= a; mats |= m; tex |= t; imgs |= i
    return acc, mats, tex, imgs


def size(j, nodes):
    acc, _, _, imgs = union(j, nodes)
    views = {j["accessors"][a]["bufferView"] for a in acc} | {j["images"][i]["bufferView"] for i in imgs}
    return sum(j["bufferViews"][v]["byteLength"] for v in views) + 8192


def write(j, b, nodes, dst):
    acc, mats, tex, imgs = union(j, nodes)
    remap = lambda s: {old: new for new, old in enumerate(sorted(s))}
    A, M, T, I = remap(acc), remap(mats), remap(tex), remap(imgs)
    meshes = sorted({j["nodes"][n]["mesh"] for n in nodes})
    ME = remap(meshes)
    blob, views = bytearray(), []

    def add_view(old):
        v = dict(j["bufferViews"][old])
        data = view_bytes(j, b, old)
        while len(blob) % 4:
            blob.append(0)
        v["byteOffset"], v["byteLength"], v["buffer"] = len(blob), len(data), 0
        blob.extend(data)
        views.append(v)
        return len(views) - 1

    accessors = [dict(j["accessors"][a], bufferView=add_view(j["accessors"][a]["bufferView"])) for a in sorted(acc)]
    images = [dict(j["images"][i], bufferView=add_view(j["images"][i]["bufferView"])) for i in sorted(imgs)]

    def fix_mat(m):
        m = json.loads(json.dumps(m))
        for k in ("normalTexture", "occlusionTexture", "emissiveTexture"):
            if k in m:
                m[k]["index"] = T[m[k]["index"]]
        pbr = m.get("pbrMetallicRoughness", {})
        for k in ("baseColorTexture", "metallicRoughnessTexture"):
            if k in pbr:
                pbr[k]["index"] = T[pbr[k]["index"]]
        return m

    def fix_mesh(me):
        me = json.loads(json.dumps(me))
        for pr in me["primitives"]:
            pr["attributes"] = {k: A[v] for k, v in pr["attributes"].items()}
            if "indices" in pr:
                pr["indices"] = A[pr["indices"]]
            if "material" in pr:
                pr["material"] = M[pr["material"]]
        return me

    out = {k: j[k] for k in ("asset", "samplers", "extensionsUsed", "extensionsRequired") if k in j}
    out.update(
        accessors=accessors, bufferViews=views, buffers=[{"byteLength": len(blob)}], images=images,
        materials=[fix_mat(j["materials"][m]) for m in sorted(mats)],
        textures=[dict(j["textures"][t], source=I[j["textures"][t]["source"]]) for t in sorted(tex)],
        meshes=[fix_mesh(j["meshes"][m]) for m in meshes],
        nodes=[dict(j["nodes"][n], mesh=ME[j["nodes"][n]["mesh"]]) for n in nodes],
        scenes=[{"nodes": list(range(len(nodes)))}], scene=0)
    js = json.dumps(out, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    while len(blob) % 4:
        blob.append(0)
    total = 12 + 8 + len(js) + 8 + len(blob)
    out.clear()
    Path(dst).write_bytes(struct.pack("<III", 0x46546C67, 2, total) + struct.pack("<I4s", len(js), b"JSON") + js
                          + struct.pack("<I4s", len(blob), b"BIN\x00") + bytes(blob))


def centres(j, nodes):
    box = {}
    for n in nodes:
        lo, hi = [1e18] * 3, [-1e18] * 3
        for pr in j["meshes"][j["nodes"][n]["mesh"]]["primitives"]:
            a = j["accessors"][pr["attributes"]["POSITION"]]
            lo = [min(p, q) for p, q in zip(lo, a["min"])]
            hi = [max(p, q) for p, q in zip(hi, a["max"])]
        box[j["nodes"][n]["name"]] = ([-hi[0], lo[1], -hi[2]], [-lo[0], hi[1], -lo[2]])  # glTF -> Roblox axes
    lo = [min(v[0][k] for v in box.values()) for k in range(3)]
    hi = [max(v[1][k] for v in box.values()) for k in range(3)]
    foot = [(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2]
    return {name: [round((a[k] + c[k]) / 2 - foot[k], 4) for k in range(3)] for name, (a, c) in box.items()}


def split(src, out_dir, limit=19_500_000):
    j, b = read(src)
    for n in j["nodes"]:
        assert "children" not in n and not any(k in n for k in ("translation", "rotation", "scale", "matrix")), \
            "shortcut: flat, untransformed mesh nodes only (true for the Vesperhold exports); extend if that changes"
    nodes = [i for i, n in enumerate(j["nodes"]) if "mesh" in n]
    by_mat = sorted(nodes, key=lambda n: (sorted(deps(j, n)[1]), j["nodes"][n]["name"]))
    parts = []
    for n in by_mat:
        if size(j, [n]) > limit:
            sys.exit(f"{src}: node {j['nodes'][n]['name']} alone is over {limit} bytes")
        # size() undercounts the written file by a few KB (JSON + padding): pack to a 64 KB margin, check the real file below.
        fit = next((p for p in parts if size(j, p + [n]) <= limit - 65536), None)
        fit.append(n) if fit else parts.append([n])
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    stem = Path(src).stem
    files = {}
    for k, p in enumerate(parts, 1):
        dst = out_dir / f"{stem}__p{k}.glb"
        write(j, b, p, dst)
        files[dst.name] = sorted(j["nodes"][n]["name"] for n in p)
        jj, _ = read(dst)  # self-check: the part parses, keeps its nodes, and is under the limit
        assert sorted(x["name"] for x in jj["nodes"]) == files[dst.name] and dst.stat().st_size <= limit, dst
    assert sorted(sum(files.values(), [])) == sorted(j["nodes"][n]["name"] for n in nodes)
    meta = {"source": str(src), "parts": files, "centres": centres(j, nodes)}
    (out_dir / f"{stem}.split.json").write_text(json.dumps(meta, indent=1))
    return meta


if __name__ == "__main__":
    args = [x for x in sys.argv[1:] if not x.startswith("--")]
    lim = int(sys.argv[sys.argv.index("--limit") + 1]) if "--limit" in sys.argv else 19_500_000
    if "--limit" in sys.argv:
        args.remove(str(lim))
    m = split(args[0], args[1], lim)
    print({k: len(v) for k, v in m["parts"].items()})
