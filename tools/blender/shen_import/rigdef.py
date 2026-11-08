"""Grandmaster Shen's production rigs, one per form, measured on the supplied sculpts. Clip space: HumanoidRootPart space at scale 1 (rigspace.py); a zero Transform shows the sculpt as designed.
src/shared/BossRigs.luau carries the same numbers (clips.py checks they agree). A helper bone is an invisible joint the stock rig lacks: only phase 2's floating beads, rigid props on their own orbit. Cloth, hair and beard are skinned and simulated (skin_rig.py, ClothSim), not keyed."""
import numpy as np

import landmarks as LM


def joints(J):
    return {
        "LowerTorso": ("HumanoidRootPart", J.PELVIS, "Root"), "UpperTorso": ("LowerTorso", J.WAIST, "Waist"), "Head": ("UpperTorso", J.NECK, "Neck"),
        "RightUpperArm": ("UpperTorso", J.RSH, "RightShoulder"), "RightLowerArm": ("RightUpperArm", J.REL, "RightElbow"), "RightHand": ("RightLowerArm", J.RWR, "RightWrist"),
        "LeftUpperArm": ("UpperTorso", J.LSH, "LeftShoulder"), "LeftLowerArm": ("LeftUpperArm", J.LEL, "LeftElbow"), "LeftHand": ("LeftLowerArm", J.LWR, "LeftWrist"),
        "RightUpperLeg": ("LowerTorso", J.RHIP, "RightHip"), "RightLowerLeg": ("RightUpperLeg", J.RKN, "RightKnee"), "RightFoot": ("RightLowerLeg", J.RAN, "RightAnkle"),
        "LeftUpperLeg": ("LowerTorso", J.LHIP, "LeftHip"), "LeftLowerLeg": ("LeftUpperLeg", J.LKN, "LeftKnee"), "LeftFoot": ("LeftLowerLeg", J.LAN, "LeftAnkle"),
    }


JOINT = {1: joints(LM.P1), 2: joints(LM.P2)}
HELPER = {
    1: {"Glaive": ("LowerTorso", tuple(LM.P1.RGRIP))},
    2: {"Glaive": ("LowerTorso", tuple(LM.P2.RGRIP))},
}
BONE_OF = {"Weapon": "Glaive"}   # the guandao has its own joint: both hands hold it, it can slide and roll in them and spin

def bone_of(phase, name):
    if name in BONE_OF:
        return BONE_OF[name]
    return name


def left_hand(J, points, clear=None):
    """The sculpt's open left hand, measured: (wrist, along the fingers, across the knuckles (the haft's way, thumb side +), toward the palm, knuckle distance, middle-joint distance, grip point). Both hands' grips and the finger bones work from this."""
    pts = np.asarray(points, float)
    wrist = np.array(J.LWR, float)
    along = pts[np.argsort((pts - wrist) @ (np.array(J.LHAND, float) - wrist))[-max(len(pts) // 12, 5):]].mean(0) - wrist
    along /= np.linalg.norm(along)
    q = pts - wrist
    q = q - np.outer(q @ along, along)
    centre = q.mean(0)
    u, _, _ = np.linalg.svd(np.cov((q - centre).T))
    across, palm = u[:, 0], u[:, 2]      # the hand's width, and its flat normal
    across = across - along * (across @ along)
    across /= np.linalg.norm(across)
    palm = np.cross(along, across)
    if palm[0] < 0:                      # a hanging left hand's palm faces his body
        palm = -palm
    if np.cross(across, along) @ palm < 0:   # the curl about +across carries the fingers toward the palm
        across = -across
    d = (pts - wrist) @ along
    far = float(np.percentile(d, 99.5))
    knuckle, middle = far * 0.5, far * 0.74
    grip = wrist + along * (far * 0.42) + palm * 0.13 + centre
    if clear:   # (2026-11-07) `clear` is the haft's measured radius: the wood's centre sits far enough off the palm that the palm and thumb do not sink into it
        n = palm - across * (palm @ across)
        n /= np.linalg.norm(n)
        heel = pts[d < knuckle - 0.02]
        for _ in range(40):
            q = heel - grip
            if np.percentile(np.linalg.norm(q - np.outer(q @ across, across), axis=1), 1) >= clear - 0.005:
                break
            grip = grip + n * 0.005
    return wrist, along, across, palm, knuckle, middle, grip
