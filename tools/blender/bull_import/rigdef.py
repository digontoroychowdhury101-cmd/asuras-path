"""The Iron Bull's production rig, measured on the supplied sculpt (assets/source/bosses/iron_bull/Iron-Bull-PBR.glb).

Clip space: HumanoidRootPart space at scale 1, Roblox axes (+X his right, +Y up, -Z his front). The sculpt's own pose is the rest pose: a
zero Transform at every joint shows the model exactly as it was designed. Joint positions are where the sculpt's joints actually are, so BossSkin
moves this rig's attachments to them, instead of pivoting his limbs about the stock R15 points they do not share.
"""
import numpy as np

GROUND = -3.1924     # sole height, unchanged: the Humanoid and foot code keep working
S = 3.1              # sculpt unit -> rig stud; head top matches the stock rig's height
GY_MIN = -0.9485167264938354
OX, OZ = 0.03, 0.45  # puts the pelvis on the root axis


def to_rig(p):
    """glTF sculpt space to clip space: turned to face -Z, scaled, soles on the rig's ground."""
    p = np.asarray(p, float)
    return np.stack((-p[..., 0] * S + OX, (p[..., 1] - GY_MIN) * S + GROUND, -p[..., 2] * S - OZ), -1)


def normal_to_rig(n):
    n = np.asarray(n, float)
    return np.stack((-n[..., 0], n[..., 1], -n[..., 2]), -1)


# bone: (parent, joint position in clip space, Motor name)
JOINT = {
    "LowerTorso": ("HumanoidRootPart", (0.10, -0.25, 0.05), "Root"),
    "UpperTorso": ("LowerTorso", (0.10, 0.08, 0.05), "Waist"),
    "Head": ("UpperTorso", (0.16, 1.42, -0.20), "Neck"),
    "RightUpperArm": ("UpperTorso", (1.22, 0.90, 0.10), "RightShoulder"),
    "RightLowerArm": ("RightUpperArm", (1.42, 0.05, 0.12), "RightElbow"),
    "RightHand": ("RightLowerArm", (1.38, -0.58, 0.02), "RightWrist"),
    "LeftUpperArm": ("UpperTorso", (-1.10, 0.90, 0.10), "LeftShoulder"),
    "LeftLowerArm": ("LeftUpperArm", (-1.33, 0.02, 0.10), "LeftElbow"),
    "LeftHand": ("LeftLowerArm", (-1.17, -0.58, -0.02), "LeftWrist"),
    "RightUpperLeg": ("LowerTorso", (0.62, -0.80, 0.05), "RightHip"),
    "RightLowerLeg": ("RightUpperLeg", (1.00, -1.80, 0.10), "RightKnee"),
    "RightFoot": ("RightLowerLeg", (1.12, -2.75, 0.20), "RightAnkle"),
    "LeftUpperLeg": ("LowerTorso", (-0.42, -0.80, 0.05), "LeftHip"),
    "LeftLowerLeg": ("LeftUpperLeg", (-0.80, -1.80, 0.10), "LeftKnee"),
    "LeftFoot": ("LeftLowerLeg", (-1.08, -2.75, 0.20), "LeftAnkle"),
}
# Extra joints the stock rig lacks. Their poses are derived from the limbs they follow (see bull_clips): the pauldrons ride part of the way up with the
# raised arm, hinged by the neck where they meet the chest plate; the apron and cape hang from the belt and are pushed by the thighs.
HELPER = {
    "RightPauldron": ("UpperTorso", (0.86, 1.34, 0.10)),
    "LeftPauldron": ("UpperTorso", (-0.70, 1.34, 0.10)),
    "ClothFront": ("LowerTorso", (0.27, -0.55, -0.55)),
    "ClothBack": ("LowerTorso", (0.15, -0.48, 0.62)),
}
