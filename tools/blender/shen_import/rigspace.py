"""Sculpt space -> rig (clip) space for Grandmaster Shen's two sculpts. Clip space: HumanoidRootPart space at scale 1, +X his right, +Y up, -Z his front.
Both forms share S and the ground, so soles, root and grip stay aligned through the transformation; the offsets centre stance and pelvis under the root axis."""
import numpy as np

GROUND = -3.1924   # stock rig sole height, as Iron Bull: Humanoid and foot code keep working
S = 3.1            # sculpt unit -> stud at scale 1
GY_MIN = {1: -0.94952, 2: -0.94526}
OFFSET = {1: (0.14, -0.826), 2: (0.165, -0.834)}   # ankle midpoint in z; x splits ankle midpoint and pelvis


def to_rig(p, phase):
    p = np.asarray(p, float)
    ox, oz = OFFSET[phase]
    return np.stack((-p[..., 0] * S + ox, (p[..., 1] - GY_MIN[phase]) * S + GROUND, -p[..., 2] * S + oz), -1)


def normal_to_rig(n):
    n = np.asarray(n, float)
    return np.stack((-n[..., 0], n[..., 1], -n[..., 2]), -1)
