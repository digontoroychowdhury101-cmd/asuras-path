"""Where does the dao point for a pose? Solves castlib poses on the swordsman's body and prints the visible fist, the
blade direction (unit, root space: +X right, +Y up, -Z forward) and the tip.

    python tools/animation/opening_cast/probe_blade.py            # every attack key of the swordsman set
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import castlib as C  # noqa: E402
import swordsman_clips as S  # noqa: E402


def blade(clip, c):
    _, world, diag = clip.solve(c)
    f = C.visible(world, "RightHand", clip.body, S.GRIP)
    t = C.visible(world, "RightHand", clip.body, S.TIP)
    d = (t - f) / np.linalg.norm(t - f)
    return f, d, t, diag


if __name__ == "__main__":
    for clip in S.library():
        if not clip.move:
            continue
        print(clip.name)
        for kt, keys, _ in clip.keys:
            c = {n: clip.channel(n, kt) for n in clip.base}
            f, d, t, diag = blade(clip, c)
            print("  t=%.3f fist %s dir %s tip %s reach+%.2f" % (kt, np.round(f, 2), np.round(d, 2), np.round(t, 2), diag["right_excess"]))
