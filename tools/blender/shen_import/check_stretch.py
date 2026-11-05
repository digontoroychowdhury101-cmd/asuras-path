"""How far a baked shot pulls the skin: per label, how much each triangle edge stretches against the sculpt. The objective half of the review; the render is the other half.

    python3 tools/blender/shen_import/check_stretch.py SHOT [every]
Prints the worst stretch per source label and per shot, and the frames where it peaks.
"""
import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "../../.."))
sys.path[:0] = [HERE, os.path.join(ROOT, "tools/blender/bull_import")]
import glb  # noqa: E402
import landmarks as LM  # noqa: E402
import rigspace as RS  # noqa: E402
import segment as Seg  # noqa: E402


def load_frame(fr, bones):
    Ms = np.tile(np.eye(4), (len(bones), 1, 1))
    for i, b in enumerate(bones):
        v = fr["bones"].get(b["name"])
        if v is not None:
            Ms[i, :3, :3] = np.array(v[:9]).reshape(3, 3)
            Ms[i, :3, 3] = v[9:12]
    return Ms


def main(shot, every=3):
    data = json.load(open(os.path.join(ROOT, "work/opening_cast_bake/shen_shots", shot + ".json")))
    phase = data["phase"]
    J = LM.PHASES[phase]
    g = glb.Glb(Seg.source(phase))
    lab = np.load(os.path.join(ROOT, f"work/shen_import/labels_p{phase}.npy"))
    skin = np.load(os.path.join(ROOT, f"work/shen_import/skin_p{phase}.npz"))
    cloth = json.load(open(os.path.join(ROOT, f"work/shen_import/cloth_p{phase}.json")))
    V = RS.to_rig(g.pos, phase)
    jt, wt = skin["joints"].astype(int), skin["weights"]
    keep = ~np.isin(lab, [J.NAMES.index(n) for n in J.NAMES if n == "Weapon" or n.startswith("Bead") and n != "Beads"])
    tri = g.idx[keep]
    tl = lab[keep]
    e = np.vstack((tri[:, [0, 1]], tri[:, [1, 2]], tri[:, [2, 0]]))
    el = np.concatenate((tl, tl, tl))
    r0 = np.linalg.norm(V[e[:, 0]] - V[e[:, 1]], axis=1)
    ok = r0 > 1e-4
    e, el, r0 = e[ok], el[ok], r0[ok]
    worst = {}
    peak = []
    for f in range(0, len(data["frames"]), every):
        Ms = load_frame(data["frames"][f], cloth["bones"])
        P = np.zeros_like(V)
        for k in range(4):
            m = Ms[jt[:, k]]
            P += wt[:, k, None] * (np.einsum("nij,nj->ni", m[:, :3, :3], V) + m[:, :3, 3])
        r = np.linalg.norm(P[e[:, 0]] - P[e[:, 1]], axis=1) / r0
        big = r[r0 > 0.004]
        peak.append((float(np.percentile(big, 99.9)), f))
        for i, n in enumerate(J.NAMES):
            m = (el == i) & (r0 > 0.004)
            if m.any():
                q = float(np.percentile(r[m], 99.5))
                worst[n] = max(worst.get(n, 0), q)
    print(shot, "99.9th percentile stretch peak %.2f at frame %d" % max(peak))
    print("  " + "  ".join("%s %.2f" % kv for kv in sorted(worst.items(), key=lambda x: -x[1])))


if __name__ == "__main__":
    main(sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 3)
