"""Per-bone rest-pose point samples of the Iron Bull sculpt, for the clip validator (reach measured on the real maul, ground and self-clearance).

    python3 tools/blender/bull_import/samples.py

Reads the local sculpt and work/bull_import/labels.npy (segment.py), writes work/bull_import/samples.npz: bone -> Nx3 clip-space points.
"""
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import glb  # noqa: E402
import rigdef as R  # noqa: E402
import segment as Seg  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "../../.."))


def main():
    src = os.path.join(ROOT, "assets/source/bosses/iron_bull/Iron-Bull-PBR.glb")
    g = glb.Glb(src)
    labels = np.load(os.path.join(ROOT, "work/bull_import/labels.npy"))
    P = R.to_rig(g.pos)
    tri = g.idx.reshape(-1, 3)
    rng = np.random.default_rng(7)
    out = {}
    print(labels.shape, tri.shape, P.shape)
    for i, name in enumerate(Seg.NAMES):
        ids = np.unique(tri[labels == i]) if labels.shape[0] == tri.shape[0] else np.where(labels == i)[0]
        pts = P[ids]
        keep = rng.choice(len(pts), min(1500, len(pts)), replace=False)
        out[name] = pts[keep].astype(np.float32)
        lo, hi = pts.min(0), pts.max(0)
        print("%-14s %6d lo %s hi %s" % (name, len(pts), np.round(lo, 2), np.round(hi, 2)))
    np.savez(os.path.join(ROOT, "work/bull_import/samples.npz"), **out)


if __name__ == "__main__":
    main()
