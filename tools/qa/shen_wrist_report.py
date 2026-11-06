"""Wrist report for Grandmaster Shen's baked clips (static review): how each hand sits on its forearm.

    python3 tools/qa/shen_wrist_report.py [clip-substring ...]

The hand's turn on the forearm (rest-relative, the joint the skin bends at) split three ways:
  twist  about the forearm's own axis (pronation/supination the forearm failed to carry)
  flex   about the across-palm line (flexion/extension)
  dev    about the palm normal (radial/ulnar deviation: a human wrist gives about 20 one way, 35 the other)
A wrist bent far past those ranges pulls the hand out of the sleeve cuff (skin_rig.py blends only +-0.07 across the wrist).
Prints max |twist|, |flex|, |dev| per clip for each hand and the fraction of frames past the cohesion limits (WRIST_LIMITS in shen_lib).
"""
import math
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/animation/opening_cast"))
import shen_clips as SC  # noqa: E402
import shen_lib as L  # noqa: E402


def parts(clip, local, side):
    return L.wrist_parts(clip.rig, local[side + "Hand"][:3, :3], side)


def main(names):
    for clip in SC.library():
        if names and not any(n in clip.name for n in names):
            continue
        baked = clip.bake()
        out = []
        for side in ("Left", "Right"):
            P = np.array([parts(clip, b[1], side) for b in baked])
            over = np.mean([L.wrist_excess(clip.rig, b[1][side + "Hand"][:3, :3], side) > 1.0 for b in baked])
            out.append("%s tw %4.0f fl %4.0f dv %4.0f over %3.0f%%" % (side[0], *np.abs(P).max(0), over * 100))
        print("%-38s %s" % (clip.name, "   ".join(out)), flush=True)


if __name__ == "__main__":
    main(sys.argv[1:])
