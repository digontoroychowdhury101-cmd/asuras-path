"""Grandmaster Shen's production rigs, one per form, measured on the supplied sculpts. Clip space: HumanoidRootPart space at scale 1 (rigspace.py); a zero Transform shows the sculpt as designed.
src/shared/BossRigs.luau carries the same numbers (clips.py checks they agree). A helper bone is an invisible joint the stock rig lacks: only phase 2's floating beads, rigid props on their own orbit. Cloth, hair and beard are skinned and simulated (skin_rig.py, ClothSim), not keyed."""
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
    1: {},
    2: {"Bead1": ("LowerTorso", (1.62, 0.30, 0.38)), "Bead2": ("LowerTorso", (1.26, -0.05, 0.23)), "Bead3": ("LowerTorso", (1.72, 0.02, 0.42))},
}
BONE_OF = {"Weapon": "RightHand"}   # the guandao is rigid in the fist that sculpted around it

def bone_of(phase, name):
    if name in BONE_OF:
        return BONE_OF[name]
    return name
