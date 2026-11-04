"""Cut the supplied Iron Bull sculpt into the game's MeshParts, with no decimation: every triangle, split normal and UV passes through untouched.

    python3 tools/blender/bull_import/build_game.py
Reads ~/Downloads/Iron-Bull-PBR.glb or assets/source/bosses/iron_bull/Iron-Bull-PBR.glb.
Writes  assets/build/opening_cast/bull/Bull_v1_Game.glb   one node per piece, each under PIECE_CAP triangles, sharing the sculpt's three maps
        work/opening_cast_bake/bull/pieces.json            piece bones, roles and bounds, for bind_skin.py and check_skin.py
Joint socks: a sculpt is a surface, so a cut limb is hollow at the joint. A dark sphere sits inside each joint on the parent's side, hidden at rest, so a
bend shows dark underlayer rather than the void.
"""
import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import glb  # noqa: E402
import rigdef as R  # noqa: E402
import segment as Seg  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
PIECE_CAP = 18000
BONE_OF = {"Weapon": ("RightHand", "Weapon"), "Shield": ("LeftLowerArm", "Shield")}
J = {k: np.array(v[1], float) for k, v in R.JOINT.items()}
# parent-side sock: (carrier, centre, radii)
SOCKS = [
    ("UpperTorso", J["Head"] + (0, -0.05, 0), (.34, .34, .34)),
    ("LowerTorso", J["UpperTorso"] + (0, 0, -0.04), (.86, .40, .60)),
    ("LowerTorso", J["RightUpperLeg"], (.40, .40, .40)), ("LowerTorso", J["LeftUpperLeg"], (.40, .40, .40)),
    ("RightUpperLeg", J["RightLowerLeg"], (.34, .34, .34)), ("LeftUpperLeg", J["LeftLowerLeg"], (.34, .34, .34)),
    ("RightLowerLeg", J["RightFoot"], (.30, .24, .30)), ("LeftLowerLeg", J["LeftFoot"], (.30, .24, .30)),
    ("UpperTorso", J["RightUpperArm"], (.40, .40, .40)), ("UpperTorso", J["LeftUpperArm"], (.40, .40, .40)),
    ("RightUpperArm", J["RightLowerArm"], (.31, .31, .31)), ("LeftUpperArm", J["LeftLowerArm"], (.30, .30, .30)),
    ("RightLowerArm", J["RightHand"], (.22, .22, .22)), ("LeftLowerArm", J["LeftHand"], (.22, .22, .22)),
]


def icosphere(sub=2):
    t = (1 + 5 ** 0.5) / 2
    v = np.array([[-1, t, 0], [1, t, 0], [-1, -t, 0], [1, -t, 0], [0, -1, t], [0, 1, t], [0, -1, -t], [0, 1, -t], [t, 0, -1], [t, 0, 1], [-t, 0, -1], [-t, 0, 1]], float)
    f = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
    v = [tuple(x) for x in v]
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


def split(tri, centres, name):
    """Median cuts along the longest axis until every part is under the cap: compact parts, so each is culled on its own."""
    out = []

    def go(ix):
        count = int(np.ceil(len(ix) / PIECE_CAP))
        if count <= 1:
            out.append(ix)
            return
        c = centres[ix]
        axis = np.argmax(c.max(0) - c.min(0))
        o = ix[np.argsort(c[:, axis], kind="stable")]
        cut = len(o) * (count // 2) // count
        go(o[:cut])
        go(o[cut:])
    go(np.arange(len(tri)))
    return out


def main():
    src = os.path.join(ROOT, "assets/source/bosses/iron_bull/Iron-Bull-PBR.glb")
    g = glb.Glb(src if os.path.exists(src) else Seg.SOURCE)
    lab, cen, _ = Seg.label(g, None)
    vp, vn = R.to_rig(g.pos), R.normal_to_rig(g.nrm)
    # one dark texel: skin on the inside of the right bicep
    skin = np.argmin(np.linalg.norm(vp - np.array([1.28, 0.32, -0.28]), axis=1))
    dark = g.uv[skin]
    sv, sf = icosphere(2)
    pieces, info = [], {}
    tris_total = 0
    for i, n in enumerate(Seg.NAMES):
        ix = np.nonzero(lab == i)[0]
        tri = g.idx[ix]
        extras = [s for s in SOCKS if s[0] == n]
        parts = split(tri, cen[ix], n)
        for k, part in enumerate(parts):
            t = tri[part]
            used, inv = np.unique(t, return_inverse=True)
            P, N, U, T = vp[used], vn[used], g.uv[used], inv.reshape(-1, 3)
            if k == 0 and extras:
                for _, c, r in extras:
                    base = len(P)
                    P = np.vstack((P, sv * r + c))
                    nn = sv / np.array(r)
                    N = np.vstack((N, nn / np.linalg.norm(nn, axis=1, keepdims=True)))
                    U = np.vstack((U, np.tile(dark, (len(sv), 1))))
                    T = np.vstack((T, sf + base))
            name = f"Bull_{n}" + (f"_{k + 1}" if len(parts) > 1 else "")
            assert len(T) <= 20000, name
            pieces.append((name, P, N, U, T))
            lo, hi = P.min(0), P.max(0)
            bone, role = BONE_OF.get(n, (n, None))
            info[name] = {"bone": bone, "role": "Weapon" if role == "Weapon" else None, "centre": ((lo + hi) / 2).tolist(), "size": (hi - lo).tolist(), "tris": len(T)}
            if bone in R.HELPER:
                info[name]["joint"] = list(R.HELPER[bone][1])
            tris_total += len(T)
    out = os.path.join(ROOT, "assets/build/opening_cast/bull")
    os.makedirs(out, exist_ok=True)
    glb.write(os.path.join(out, "Bull_v1_Game.glb"), g, pieces)
    dst = os.path.join(ROOT, "work/opening_cast_bake/bull")
    os.makedirs(dst, exist_ok=True)
    with open(os.path.join(dst, "pieces.json"), "w") as f:
        json.dump(info, f, indent=1)
    print(len(pieces), "pieces", tris_total, "tris; biggest", max(v["tris"] for v in info.values()))


if __name__ == "__main__":
    main()
