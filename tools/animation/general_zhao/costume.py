"""General Zhao's in-game look, transcribed from src/shared/LooksDuelists.luau (zhao()) for previews and clearance checks.
Offsets are studs from the limb centre; Rot is CFrame.Angles degrees; Fit pieces wrap the limb (size is padding)."""
LACQUER, AZURE, PLUME, RED = (28, 26, 30), (52, 130, 214), (214, 170, 90), (128, 28, 28)
GOLD, STEEL, INDIGO_ROW, POLE, SKIN = (196, 160, 84), (178, 184, 190), (40, 52, 78), (70, 54, 40), (176, 140, 108)


def P(name, bone, size, at, color, material, **extra):
    return dict(name=name, bone=bone, size=size, at=at or (0, 0, 0), color=color, material=material, **extra)


def pair(out, name, boneL, boneR, size, at, color, material, **extra):
    for side in (-1, 1):
        e = dict(extra)
        m = -side
        if "rot" in e:
            r = e["rot"]
            e["rot"] = (r[0], r[1] * m, r[2] * m)
        out.append(P(name + ("L" if side < 0 else "R"), boneL if side < 0 else boneR, size,
                     (at[0] * m, at[1], at[2]), color, material, **e))


def pieces():
    out = [
        P("HelmBowl", "Head", (1.34, 0.7, 1.34), (0, 0.38, 0), LACQUER, "Metal"),
        P("HelmBrim", "Head", (0.12, 1.7, 1.7), (0, 0.1, 0), LACQUER, "Metal", shape="Cylinder", rot=(0, 0, 90)),
        P("HelmCrest", "Head", (0.42, 0.42, 0.08), (0, 0.34, -0.71), AZURE, "Neon", rot=(0, 0, 45), glow=True),
        P("Neckguard", "Head", (1.4, 0.6, 0.25), (0, -0.3, 0.62), LACQUER, "Metal"),
        P("Moustache", "Head", (0.7, 0.08, 0.08), (0, -0.2, -0.61), LACQUER, "Fabric"),
        P("Goatee", "Head", (0.2, 0.42, 0.12), (0, -0.62, -0.55), LACQUER, "Fabric"),
        P("ChestDiamond", "UpperTorso", (0.52, 0.52, 0.08), (0, 0.25, -0.64), AZURE, "Neon", rot=(0, 0, 45), glow=True),
        P("Belt", "LowerTorso", (0.12, 0.2, 0.12), None, GOLD, "Metal", fit=True),
        P("CoatBack", "LowerTorso", (2.1, 2.4, 0.1), (0, -1.4, 0.56), AZURE, "Fabric", rot=(-5, 0, 0)),
        P("CoatHem", "LowerTorso", (2.12, 0.12, 0.12), (0, -2.55, 0.66), GOLD, "Fabric", rot=(-5, 0, 0)),
        P("GuandaoHaft", "RightHand", (0.22, 0.22, 8.4), (0, -0.1, -2.9), RED, "Wood", weapon=True),
        P("GuandaoBlade", "RightHand", (0.18, 1, 2.4), (0, 0.25, -8.2), STEEL, "Metal", shape="Wedge", weapon=True),
        P("LightningEdge", "RightHand", (0.1, 0.22, 2.2), (0, 0.78, -8.2), AZURE, "Neon", glow=True, weapon=True),
        P("GuandaoTassel", "RightHand", (0.2, 0.6, 0.2), (0, -0.45, -6.9), RED, "Fabric", weapon=True),
    ]
    for row in range(4):
        out.append(P("Lamellar%d" % row, "UpperTorso", (2.14, 0.36, 1.14), (0, 0.6 - row * 0.38, 0),
                     LACQUER if row % 2 == 0 else INDIGO_ROW, "Metal"))
    pair(out, "PheasantPlume", "Head", "Head", (0.12, 3.2, 0.12), (-0.25, 2, 0.5), PLUME, "Fabric", rot=(-25, 0, 8))
    pair(out, "Pauldron", "UpperTorso", "UpperTorso", (1.1, 0.28, 1.3), (-1.3, 0.72, 0), LACQUER, "Metal", rot=(0, 0, 20))
    pair(out, "PennantPole", "UpperTorso", "UpperTorso", (0.1, 3.2, 0.1), (-0.5, 1.6, 0.62), POLE, "Wood")
    pair(out, "BackPennant", "UpperTorso", "UpperTorso", (0.08, 2.4, 1), (-0.5, 2, 1.12), AZURE, "Fabric")
    pair(out, "Sleeve", "LeftUpperArm", "RightUpperArm", (0.06, 0, 0.06), (0, 0, 0), AZURE, "Fabric", fit=True)
    pair(out, "Bracer", "LeftLowerArm", "RightLowerArm", (0.1, -0.25, 0.1), (0, 0, 0), LACQUER, "Metal", fit=True)
    pair(out, "CoatFront", "LeftUpperLeg", "RightUpperLeg", (1, 1.9, 0.1), (0, -0.5, -0.56), AZURE, "Fabric")
    pair(out, "Tasset", "LeftUpperLeg", "RightUpperLeg", (0.3, 1, 1), (-0.62, 0.1, 0), LACQUER, "Metal")
    pair(out, "Greave", "LeftLowerLeg", "RightLowerLeg", (0.08, -0.2, 0.08), (0, 0, 0), LACQUER, "Metal", fit=True)
    return out


BODY_COLOR = {"Head": SKIN, "LeftHand": SKIN, "RightHand": SKIN}
DEFAULT_BODY = LACQUER
