"""Per-key report for the Warden's clips: arm reach excess, shaft direction, crescent position (root space).

    python tools/animation/opening_cast/probe_warden.py [Clip ...]
"""
import math
import sys

import numpy as np

import castlib as C
import warden_clips as W


def report(clip):
    print(clip.name)
    for t, c, _ in sorted(clip.keys, key=lambda k: k[0]):
        full = dict(clip.base)
        full.update(c)
        if "rh" not in c:
            continue
        _, world, diag = clip.solve(full)
        g, d = W.axis(world, "RightHand", W.GRIP)
        cr = C.visible(world, "RightHand", W.WARDEN, W.CRESCENT[1])
        print("  t %.3f  R %.2f L %.2f  legs %.2f/%.2f  shaft %s  crescent %s fwd %.2f yaw %.0f" % (
            t, diag["right_excess"], diag["left_excess"], diag["left_leg_excess"], diag["right_leg_excess"],
            np.round(d, 2), np.round(cr, 2), -cr[2], math.degrees(math.atan2(cr[0], -cr[2]))))


T = C.timing()
names = sys.argv[1:]
for clip in W.library():
    if not names or clip.name in names:
        report(clip)
