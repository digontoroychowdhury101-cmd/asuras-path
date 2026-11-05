"""Read-only survey of Grandmaster Shen's supplied sculpts: bounds, connected shells, texture headers.

    python3 tools/blender/shen_import/survey.py

Writes work/shen_import/survey_p<n>.json and work/shen_import/shells_p<n>.npy (shell id per triangle). Nothing is modified.
"""
import json
import os
import struct
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "../../.."))
sys.path.insert(0, os.path.join(ROOT, "tools/blender/bull_import"))
import glb  # noqa: E402

SRC = os.path.join(ROOT, "assets/source/bosses/grandmaster_shen")
OUT = os.path.join(ROOT, "work/shen_import")


def png_size(b):
    return struct.unpack(">II", b[16:24])


def main():
    os.makedirs(OUT, exist_ok=True)
    for phase in (1, 2):
        g = glb.Glb(os.path.join(SRC, f"Grandmaster-Shen-Phase-{phase}-PBR.glb"))
        lo, hi = g.pos.min(0), g.pos.max(0)
        ids = glb.weld(g.pos, 1e-5)
        shell = glb.shells(g.idx, ids)
        uniq, inv, cnt = np.unique(shell, return_inverse=True, return_counts=True)
        order = np.argsort(-cnt)
        cen = g.pos[g.idx].mean(1)
        rows = []
        for r in order[:60]:
            m = inv == r
            rows.append({"tris": int(cnt[r]), "lo": cen[m].min(0).round(3).tolist(), "hi": cen[m].max(0).round(3).tolist()})
        np.save(os.path.join(OUT, f"shells_p{phase}.npy"), inv.astype(np.int32))
        info = {"phase": phase, "tris": len(g.idx), "verts": len(g.pos), "welded_verts": int(ids.max() + 1), "lo": lo.round(4).tolist(), "hi": hi.round(4).tolist(),
                "size": (hi - lo).round(4).tolist(), "shells": len(uniq), "shells_over_100": int((cnt > 100).sum()), "images": [{"name": im.get("name"), "size": png_size(g.image(i))} for i, im in enumerate(g.json["images"])],
                "nodes": g.json["nodes"], "material": g.json["materials"][0], "top_shells": rows}
        with open(os.path.join(OUT, f"survey_p{phase}.json"), "w") as f:
            json.dump(info, f, indent=1)
        print("P%d tris %d verts %d welded %d shells %d (>100 tris: %d) size %s" % (phase, info["tris"], info["verts"], info["welded_verts"], info["shells"], info["shells_over_100"], info["size"]))
        print("   lo", info["lo"], "hi", info["hi"], "node", {k: v for k, v in g.json["nodes"][0].items() if k != "mesh"})
        for row in rows[:14]:
            print("  ", row)
        print("   images", info["images"])


if __name__ == "__main__":
    main()
