"""Convert a COLLADA (.dae) mesh to Wavefront OBJ with the Python standard library only.

Blender 5 removed its COLLADA importer; 0 A.D. ships its art as simple Blender-exported DAE files.
This reads only XML geometry (positions, normals, first UV set, node transforms) and never executes
anything from the source file. Z-up sources are rotated to Y-up. Usage:

    python -I tools/assets/dae_to_obj.py IN.dae OUT.obj
"""
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

NS = {"c": "http://www.collada.org/2005/11/COLLADASchema"}


def floats(text):
    return [float(v) for v in (text or "").split()]


def ints(text):
    return [int(v) for v in (text or "").split()]


def matmul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def node_matrices(root):
    """geometry id -> list of world matrices from the visual scene (nested nodes multiplied)."""
    out = {}

    def walk(node, parent):
        m = parent
        for child in node:
            tag = child.tag.split("}")[1]
            if tag == "matrix":
                v = floats(child.text)
                m = matmul(m, [v[0:4], v[4:8], v[8:12], v[12:16]])
            elif tag == "translate":
                x, y, z = floats(child.text)
                m = matmul(m, [[1, 0, 0, x], [0, 1, 0, y], [0, 0, 1, z], [0, 0, 0, 1]])
            elif tag == "scale":
                x, y, z = floats(child.text)
                m = matmul(m, [[x, 0, 0, 0], [0, y, 0, 0], [0, 0, z, 0], [0, 0, 0, 1]])
        for inst in node.findall("c:instance_geometry", NS):
            out.setdefault(inst.get("url", "")[1:], []).append(m)
        for sub in node.findall("c:node", NS):
            walk(sub, m)

    ident = [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]
    for scene in root.iterfind(".//c:visual_scene", NS):
        for node in scene.findall("c:node", NS):
            walk(node, ident)
    return out


def convert(src: Path, dst: Path) -> dict:
    root = ET.parse(src).getroot()
    up = (root.findtext("c:asset/c:up_axis", default="Y_UP", namespaces=NS) or "Y_UP").strip()
    mats = node_matrices(root)
    lines, vbase, tbase, nbase, tris = [f"# converted from {src.name} by dae_to_obj.py"], 1, 1, 1, 0
    for geom in root.iterfind(".//c:library_geometries/c:geometry", NS):
        mesh = geom.find("c:mesh", NS)
        if mesh is None:
            continue
        sources = {s.get("id"): (floats(s.findtext("c:float_array", namespaces=NS)),
                                 int(s.find(".//c:accessor", NS).get("stride", "1"))) for s in mesh.findall("c:source", NS)}
        verts = {v.get("id"): v.find("c:input[@semantic='POSITION']", NS).get("source")[1:] for v in mesh.findall("c:vertices", NS)}
        for matrix in mats.get(geom.get("id"), [[[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]]):
            lines.append(f"o {geom.get('name') or geom.get('id')}")
            pos_src = next(iter(verts.values()))
            pos, _ = sources[pos_src]
            for i in range(0, len(pos), 3):
                x, y, z = pos[i:i + 3]
                wx = matrix[0][0] * x + matrix[0][1] * y + matrix[0][2] * z + matrix[0][3]
                wy = matrix[1][0] * x + matrix[1][1] * y + matrix[1][2] * z + matrix[1][3]
                wz = matrix[2][0] * x + matrix[2][1] * y + matrix[2][2] * z + matrix[2][3]
                lines.append(f"v {wx:.5f} {wz:.5f} {-wy:.5f}" if up == "Z_UP" else f"v {wx:.5f} {wy:.5f} {wz:.5f}")
            npos = len(pos) // 3
            uv_count = n_count = 0
            for prim in list(mesh.findall("c:triangles", NS)) + list(mesh.findall("c:polylist", NS)):
                inputs = prim.findall("c:input", NS)
                stride = max(int(i.get("offset")) for i in inputs) + 1
                off = {}
                for i in inputs:
                    sem = i.get("semantic")
                    if sem == "TEXCOORD" and "TEXCOORD" in off:
                        continue  # first UV set only
                    off[sem] = (int(i.get("offset")), i.get("source")[1:])
                uv_base, n_base = tbase + uv_count, nbase + n_count
                if "TEXCOORD" in off:
                    uv, st = sources[off["TEXCOORD"][1]]
                    lines += [f"vt {uv[i]:.5f} {uv[i + 1]:.5f}" for i in range(0, len(uv), st)]
                    uv_count += len(uv) // st
                if "NORMAL" in off:
                    nv, _ = sources[off["NORMAL"][1]]
                    for i in range(0, len(nv), 3):
                        x, y, z = nv[i:i + 3]
                        lines.append(f"vn {x:.5f} {z:.5f} {-y:.5f}" if up == "Z_UP" else f"vn {x:.5f} {y:.5f} {z:.5f}")
                    n_count += len(nv) // 3
                p = ints(prim.findtext("c:p", namespaces=NS))
                counts = ints(prim.findtext("c:vcount", namespaces=NS)) or [3] * (len(p) // (3 * stride))
                cursor = 0
                for n in counts:
                    corner = []
                    for k in range(n):
                        base = (cursor + k) * stride
                        vi = p[base + off["VERTEX"][0]] + vbase
                        ti = p[base + off["TEXCOORD"][0]] + uv_base if "TEXCOORD" in off else None
                        ni = p[base + off["NORMAL"][0]] + n_base if "NORMAL" in off else None
                        corner.append(f"{vi}/{'' if ti is None else ti}/{'' if ni is None else ni}")
                    for k in range(1, n - 1):  # fan triangulation
                        lines.append(f"f {corner[0]} {corner[k]} {corner[k + 1]}")
                        tris += 1
                    cursor += n
            vbase += npos
            tbase += uv_count
            nbase += n_count
    dst.write_text("\n".join(lines) + "\n")
    return {"triangles": tris, "vertices": vbase - 1, "up": up}


if __name__ == "__main__":
    print(convert(Path(sys.argv[1]), Path(sys.argv[2])))
