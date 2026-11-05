"""Add Grandmaster Shen's named effect attachments to both pieces.json files (read by bind_skin.py).

    cd tools/animation/opening_cast && python3 shen_fx_points.py

BladeTip / BladeBase: the cutting edge's ends on the blade piece, from the sculpt's own weapon samples. BeadHand: the free palm. ChestCore: the burst origin.
"""
import json
from pathlib import Path

import numpy as np

import shen_lib as L

ROOT = Path(__file__).resolve().parents[3]
for phase in (1, 2):
    rig = L.Rig(phase)
    path = ROOT / ("work/opening_cast_bake/shen%d/pieces.json" % phase)
    pieces = json.loads(path.read_text())
    pieces.pop("__fx", None)
    axis = L.unit(rig.HAFT0)
    along = (rig.samples["Weapon"] - rig.GRIP0) @ axis
    tip_t = float(along.max())
    prefix = "Shen%d_" % phase
    points = {
        "BladeTip": (prefix + "Weapon_1", rig.TIP0),
        "BladeBase": (prefix + "Weapon_1", rig.GRIP0 + axis * (tip_t - 2.0)),
    }
    # the skinned body has no piece per limb: these ride the limb itself, and BossSkin parents them there
    limbs = {"BeadHand": ("LeftHand", rig.PALM0), "ChestCore": ("UpperTorso", rig.JOINT["UpperTorso"] + np.array([0, 0.5, -0.1]))}
    pieces["__fx"] = {name: {"piece": piece, "at": [round(float(x), 4) for x in at]} for name, (piece, at) in points.items()}
    pieces["__fx"].update({name: {"limb": limb, "at": [round(float(x), 4) for x in at]} for name, (limb, at) in limbs.items()})
    path.write_text(json.dumps(pieces, indent=1))
    print(phase, pieces["__fx"])
