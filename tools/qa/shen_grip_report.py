"""Grip and clearance report for Grandmaster Shen's baked clips (static review; no Studio needed).

    python3 tools/qa/shen_grip_report.py [clip-substring ...]

For each clip and frame it measures, in HumanoidRootPart rig space (scale 1, +X his right, -Z his front):
  sep     distance between the right fist and the left palm along the haft (hand spacing; shoulder width is 1.44)
  lz/rz   how far in front of the hips each hand is (negative = in front)
  pitch   haft elevation in degrees (+ = blade end above the butt)
  tip_y   blade tip height relative to the hips
  off     left palm distance from the haft line (contact)
  clr     smallest weapon-to-head / weapon-to-chest proxy margin (negative = penetration)
Prints min/max per clip plus the validator's problems.
"""
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/animation/opening_cast"))
import shen_clips as SC  # noqa: E402
import shen_lib as L  # noqa: E402


def measure(clip, baked):
    rg = clip.rig
    rows = []
    for t, local, world, diag, c in baked:
        fist = (world["RightHand"] @ np.append(rg.GRIP0, 1))[:3]
        palm = (world["LeftHand"] @ np.append(rg.PALM0, 1))[:3]
        ax = L.unit(c["haft"])
        held = c["lhw"] >= 0.99 and c["lhw"] >= c["ltw"]
        d = palm - fist
        sep = float(np.dot(d, ax)) if held else float("nan")
        off = float(np.linalg.norm(d - ax * np.dot(d, ax))) if held else float("nan")
        wp = L.place(rg, world, "Weapon")
        tip = wp[int(np.argmax((wp - fist) @ ax))]
        head = (world["Head"] @ np.append(rg.JOINT["Head"] + (0, 0.5, 0), 1))[:3]
        chest = (world["UpperTorso"] @ np.append(rg.JOINT["UpperTorso"] + (0, 0.5, 0), 1))[:3]
        clr = min(float(np.linalg.norm(wp - head, axis=1).min()) - 0.42, float(np.linalg.norm(wp - chest, axis=1).min()) - 0.4)
        rows.append(dict(t=t, sep=sep, lz=float(palm[2]), rz=float(fist[2]), pitch=float(np.degrees(np.arcsin(np.clip(ax[1], -1, 1)))),
                         tip_y=float(tip[1]), off=off, clr=clr, held=held))
    return rows


def summary(clip, rows, problems):
    def rng(k):
        v = np.array([r[k] for r in rows], float)
        v = v[~np.isnan(v)]
        return "%6.2f..%5.2f" % (v.min(), v.max()) if len(v) else "   n/a     "
    held = sum(r["held"] for r in rows) / len(rows)
    return "%-38s held %3.0f%%  sep %s  lz %s  rz %s  pitch %s  tip_y %s  off %s  clr %s  %s" % (
        clip.name, held * 100, rng("sep"), rng("lz"), rng("rz"), rng("pitch"), rng("tip_y"), rng("off"), rng("clr"), "; ".join(problems) or "ok")


def main(names):
    for clip in SC.library():
        if names and not any(n in clip.name for n in names):
            continue
        baked = clip.bake()
        _, problems = SC.validate(clip, baked) if hasattr(SC, "validate") else L.validate(clip, baked)
        print(summary(clip, measure(clip, baked), problems))


if __name__ == "__main__":
    main(sys.argv[1:])
