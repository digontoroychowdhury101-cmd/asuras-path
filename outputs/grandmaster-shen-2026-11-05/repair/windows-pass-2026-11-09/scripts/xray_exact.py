"""xray_exact.py SHOTJSON... : (Windows pass 2026-11-13) the review x-ray's number at five decimals, without Blender.
Review shot JSON (work/opening_cast_bake/shen_shots/<shot>.json, written by shots_fade.py, the bones of every review frame with the game's
cloth simulated) posed on the committed mesh data (work/shen_import/xray2_p<phase>.npz, tools/blender/shen_import/xray_dump.py --cloth)
with review.py's rules (tools/animation/opening_cast/shen_seam.py XRay(phase, cloth=True), gate 0): arm vertices past 0.03 inside
UpperTorso where the nearest torso vertex is over 0.8 on Sk_UpperTorso, not those inside in the bind pose. Prints each shot's six deepest
review frames, depth and vertex count. review.py prints the same depths to three decimals; results/xray_exact_final7.txt is this on the
seven seam clips' exported shots.
    py outputs/grandmaster-shen-2026-11-05/repair/windows-pass-2026-11-09/scripts/xray_exact.py work/opening_cast_bake/shen_shots/f2_*.json
"""
import json
import os
import sys

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, os.path.join(ROOT, "tools/animation/opening_cast"))
sys.path.insert(0, os.path.join(ROOT, "tools/animation/general_zhao"))
import shen_seam  # noqa: E402


def shot_bones(fr):
    return {k: (np.array(v[:9]).reshape(3, 3), np.array(v[9:12])) for k, v in fr["bones"].items()}


if __name__ == "__main__":
    for path in sys.argv[1:]:
        data = json.load(open(path))
        xr = shen_seam.xray(data["phase"], cloth=True)
        out = []
        for f, fr in enumerate(data["frames"]):
            if f < 17:
                continue
            d, n = xr.depth(shot_bones(fr))
            out.append((f, d, n))
        top = sorted(out, key=lambda r: -r[1])[:6]
        print(path.replace("\\", "/").split("/")[-1], "deepest", " ".join("f%d %.5f (%d)" % r for r in top), flush=True)
