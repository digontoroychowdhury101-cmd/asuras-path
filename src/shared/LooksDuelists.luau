--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/LooksDuelists
-- Batch 11 looks: Grandmaster Shen (disciplined jian master -> demonic chimera with the glaive) and
-- the Twin Sentinels, built to read apart at a glance: General Zhao tall and narrow (pheasant
-- plumes, back pennants, azure lightning, ◆ crest, long guandao) and the Iron Bull broad and
-- horned (amber visor, greatshield with the ▲ sigil, long maul). Weapon lengths are authored at
-- scale 1 as server reach / boss scale, so the scaled tip lands where the authoritative strike
-- does (CharacterService weaponSegment). Offsets are studs from each limb's centre (CostumeSchema).
local Schema = require(script.Parent.CostumeSchema)
local P = Schema.P

local IVORY, INDIGO, JADE, GOLD = { 226, 220, 204 }, { 44, 52, 86 }, { 96, 200, 160 }, { 196, 160, 84 }
local WHITE, STEEL, CRIMSON, VOID = { 232, 230, 226 }, { 178, 184, 190 }, { 210, 24, 36 }, { 46, 16, 20 }
local LACQUER, AZURE, PLUME, RED = { 28, 26, 30 }, { 52, 130, 214 }, { 214, 170, 90 }, { 128, 28, 28 }
local IRON, BRONZE, HIDE, AMBER, BONE = { 74, 72, 70 }, { 150, 110, 60 }, { 92, 64, 44 }, { 255, 150, 40 }, { 220, 206, 170 }

local function pair(list: { Schema.Piece }, name: string, boneL: string, boneR: string, size: { number }, at: { number }, color: { number }, material: string, extra: { [string]: any }?)
	-- `at` and `Rot` are authored for the left piece; the right one mirrors across x.
	for side = -1, 1, 2 do
		local e: { [string]: any } = table.clone(extra or {})
		local rot, m = e.Rot, -side
		if rot then e.Rot = { rot[1], rot[2] * m, rot[3] * m } end
		table.insert(list, P(name .. (if side < 0 then "L" else "R"), if side < 0 then boneL else boneR, size, { at[1] * m, at[2], at[3] }, color, material, e))
	end
end

local function shen(): Schema.Look
	local list: { Schema.Piece } = {
		P("HairCap", "Head", { 1.28, 0.5, 1.28 }, { 0, 0.42, 0.04 }, WHITE, "Fabric"),
		P("TopknotBun", "Head", { 0.56, 0.56, 0.56 }, { 0, 0.74, 0.14 }, WHITE, "Fabric", { Shape = "Ball", Phase = 1 }),
		P("JadeHairpin", "Head", { 0.08, 0.08, 0.95 }, { 0, 0.8, 0.14 }, JADE, "Glass", { Rot = { 0, 90, 0 }, Phase = 1 }),
		P("BackHair", "Head", { 1.1, 0.95, 0.26 }, { 0, 0.02, 0.56 }, WHITE, "Fabric"),
		P("LongBeard", "Head", { 0.6, 1.25, 0.22 }, { 0, -0.86, -0.5 }, WHITE, "Fabric"),
		P("Moustache", "Head", { 0.82, 0.1, 0.1 }, { 0, -0.18, -0.62 }, WHITE, "Fabric"),
		P("Brows", "Head", { 0.92, 0.08, 0.06 }, { 0, 0.18, -0.61 }, WHITE, "Fabric"),
		P("InnerRobe", "UpperTorso", { 0.1, 0.06, 0.1 }, nil, IVORY, "Fabric", { Fit = true, Phase = 1 }),
		P("ShoulderMantle", "UpperTorso", { 2.5, 0.3, 1.3 }, { 0, 0.82, 0.02 }, INDIGO, "Fabric", { Phase = 1 }),
		P("MantleTrim", "UpperTorso", { 2.52, 0.08, 1.32 }, { 0, 0.66, 0.02 }, GOLD, "Fabric", { Phase = 1 }),
		P("CoatBack", "UpperTorso", { 2.2, 1.7, 0.14 }, { 0, 0, 0.58 }, INDIGO, "Fabric", { Phase = 1 }),
		P("Sash", "LowerTorso", { 0.14, 0.25, 0.14 }, nil, INDIGO, "Fabric", { Fit = true }),
		P("JadeBuckle", "LowerTorso", { 0.45, 0.36, 0.1 }, { 0, 0, -0.6 }, JADE, "Glass", { Phase = 1 }),
		P("SashTail", "LowerTorso", { 0.3, 1.3, 0.06 }, { -0.55, -0.75, -0.58 }, INDIGO, "Fabric"),
		P("RobeBack", "LowerTorso", { 2.1, 2.3, 0.12 }, { 0, -1.35, 0.56 }, IVORY, "Fabric", { Rot = { -6, 0, 0 }, Phase = 1 }),
		-- Phase 2: the Demonic Chimera tears through the robe.
		P("CorruptedRobe", "UpperTorso", { 0.12, 0.06, 0.12 }, nil, VOID, "Fabric", { Fit = true, Phase = 2 }),
		P("TornMantle", "UpperTorso", { 2.4, 2.1, 0.14 }, { 0, -0.2, 0.6 }, { 90, 18, 22 }, "Fabric", { Rot = { -8, 0, 0 }, Phase = 2 }),
		P("BloodSigil", "UpperTorso", { 0.5, 0.5, 0.06 }, { 0, 0.15, -0.58 }, CRIMSON, "Neon", { Rot = { 0, 0, 45 }, Phase = 2, Glow = 6 }),
		P("WildMane", "Head", { 1.55, 1.05, 1.15 }, { 0, 0.3, 0.45 }, { 236, 226, 222 }, "Fabric", { Rot = { 22, 0, 0 }, Phase = 2 }),
		P("RobeShreds", "LowerTorso", { 2.1, 1.7, 0.12 }, { 0, -1.05, 0.56 }, { 90, 18, 22 }, "Fabric", { Rot = { -10, 0, 0 }, Phase = 2 }),
		-- Phase 2 glaive: reach 11 + 2.5 bonus at scale 1.
		P("GlaiveHaft", "RightHand", { 0.26, 0.26, 11 }, { 0, -0.1, -4 }, { 48, 18, 18 }, "Wood", { Phase = 2, Role = "Weapon" }),
		P("GlaiveRing", "RightHand", { 0.5, 0.5, 0.5 }, { 0, -0.1, -9.4 }, GOLD, "Metal", { Shape = "Ball", Phase = 2, Role = "Weapon" }),
		P("GlaiveBlade", "RightHand", { 0.2, 1.1, 3.4 }, { 0, 0.3, -11 }, { 150, 140, 140 }, "Metal", { Shape = "Wedge", Phase = 2, Role = "Weapon" }),
		P("GlaiveEdge", "RightHand", { 0.12, 0.25, 3.2 }, { 0, 0.85, -11 }, CRIMSON, "Neon", { Phase = 2, Glow = 8, Role = "Weapon" }),
		-- Phase 1 jian: reach 7.5 at scale 1.
		P("JianGrip", "RightHand", { 0.16, 0.16, 1 }, { 0, -0.1, -0.55 }, { 40, 30, 26 }, "Wood", { Phase = 1, Role = "Weapon" }),
		P("JianGuard", "RightHand", { 0.9, 0.18, 0.18 }, { 0, -0.1, -1.1 }, GOLD, "Metal", { Phase = 1, Role = "Weapon" }),
		P("JianBlade", "RightHand", { 0.1, 0.28, 5.6 }, { 0, -0.1, -3.95 }, STEEL, "Metal", { Phase = 1, Role = "Weapon" }),
		P("JianTassel", "RightHand", { 0.12, 0.8, 0.12 }, { 0, -0.5, 0.05 }, CRIMSON, "Fabric", { Phase = 1 }),
	}
	pair(list, "CrossCollar", "UpperTorso", "UpperTorso", { 0.22, 1.7, 0.08 }, { -0.3, 0.05, -0.56 }, INDIGO, "Fabric", { Rot = { 0, 0, 24 }, Phase = 1 })
	pair(list, "WideSleeve", "LeftUpperArm", "RightUpperArm", { 0.18, 0.05, 0.18 }, { 0, 0, 0 }, IVORY, "Fabric", { Fit = true, Phase = 1 })
	pair(list, "SleeveFlare", "LeftLowerArm", "RightLowerArm", { 1.5, 1.4, 1.5 }, { 0, -0.15, 0 }, IVORY, "Fabric", { Phase = 1 })
	pair(list, "SleeveCuff", "LeftLowerArm", "RightLowerArm", { 1.54, 0.12, 1.54 }, { 0, -0.82, 0 }, INDIGO, "Fabric", { Phase = 1 })
	pair(list, "TornSleeve", "LeftLowerArm", "RightLowerArm", { 1.3, 1.1, 1.3 }, { 0, -0.05, 0 }, VOID, "Fabric", { Phase = 2 })
	pair(list, "ClawWrap", "LeftHand", "RightHand", { 0.12, 0.2, 0.12 }, { 0, 0, 0 }, CRIMSON, "Fabric", { Fit = true, Phase = 2 })
	pair(list, "CrimsonHorn", "Head", "Head", { 0.22, 1.4, 0.22 }, { -0.42, 0.98, -0.08 }, CRIMSON, "Neon", { Rot = { -15, 0, 25 }, Phase = 2, Glow = 5 })
	pair(list, "EmberEye", "Head", "Head", { 0.18, 0.06, 0.04 }, { -0.22, 0.08, -0.615 }, { 255, 70, 40 }, "Neon", { Phase = 2 })
	pair(list, "RobeFlap", "LeftUpperLeg", "RightUpperLeg", { 1, 2.1, 0.1 }, { 0, -0.45, -0.56 }, IVORY, "Fabric", { Rot = { 4, 0, 0 }, Phase = 1 })
	pair(list, "ShredFlap", "LeftUpperLeg", "RightUpperLeg", { 1, 1.5, 0.1 }, { 0, -0.2, -0.56 }, { 90, 18, 22 }, "Fabric", { Phase = 2 })
	pair(list, "Trouser", "LeftUpperLeg", "RightUpperLeg", { 0.06, 0, 0.06 }, { 0, 0, 0 }, INDIGO, "Fabric", { Fit = true })
	pair(list, "Puttee", "LeftLowerLeg", "RightLowerLeg", { 0.08, -0.2, 0.08 }, { 0, 0, 0 }, INDIGO, "Fabric", { Fit = true })
	pair(list, "ClothShoe", "LeftFoot", "RightFoot", { 0.06, 0.08, 0.12 }, { 0, 0, 0 }, { 30, 28, 32 }, "Fabric", { Fit = true })
	for k = 0, 2 do
		table.insert(list, P("SpinePlate" .. k, "UpperTorso", { 0.3, 0.5, 0.6 }, { 0, 0.55 - k * 0.5, 0.78 }, { 60, 20, 22 }, "Slate", { Shape = "Wedge", Rot = { 0, 180, 0 }, Phase = 2 }))
	end
	return { Key = "GrandmasterShen", Rig = "Humanoid", Phases = 2, OwnWeapon = true, Pieces = list,
		Body = { { 196, 160, 128 }, IVORY }, Body2 = { { 150, 92, 86 }, VOID } }
end

local function zhao(): Schema.Look
	local list: { Schema.Piece } = {
		P("HelmBowl", "Head", { 1.34, 0.7, 1.34 }, { 0, 0.38, 0 }, LACQUER, "Metal"),
		P("HelmBrim", "Head", { 0.12, 1.7, 1.7 }, { 0, 0.1, 0 }, LACQUER, "Metal", { Shape = "Cylinder", Rot = { 0, 0, 90 } }),
		P("HelmCrest", "Head", { 0.42, 0.42, 0.08 }, { 0, 0.34, -0.71 }, AZURE, "Neon", { Rot = { 0, 0, 45 }, Glow = 4, Role = "Sigil" }),
		P("Neckguard", "Head", { 1.4, 0.6, 0.25 }, { 0, -0.3, 0.62 }, LACQUER, "Metal"),
		P("Moustache", "Head", { 0.7, 0.08, 0.08 }, { 0, -0.2, -0.61 }, LACQUER, "Fabric"),
		P("Goatee", "Head", { 0.2, 0.42, 0.12 }, { 0, -0.62, -0.55 }, LACQUER, "Fabric"),
		P("ChestDiamond", "UpperTorso", { 0.52, 0.52, 0.08 }, { 0, 0.25, -0.64 }, AZURE, "Neon", { Rot = { 0, 0, 45 }, Glow = 5, Role = "Sigil" }),
		P("Belt", "LowerTorso", { 0.12, 0.2, 0.12 }, nil, GOLD, "Metal", { Fit = true }),
		P("CoatBack", "LowerTorso", { 2.1, 2.4, 0.1 }, { 0, -1.4, 0.56 }, AZURE, "Fabric", { Rot = { -5, 0, 0 } }),
		P("CoatHem", "LowerTorso", { 2.12, 0.12, 0.12 }, { 0, -2.55, 0.66 }, GOLD, "Fabric", { Rot = { -5, 0, 0 } }),
		P("GuandaoHaft", "RightHand", { 0.22, 0.22, 8.4 }, { 0, -0.1, -2.9 }, RED, "Wood", { Role = "Weapon" }),
		P("GuandaoBlade", "RightHand", { 0.18, 1, 2.4 }, { 0, 0.25, -8.2 }, STEEL, "Metal", { Shape = "Wedge", Role = "Weapon" }),
		P("LightningEdge", "RightHand", { 0.1, 0.22, 2.2 }, { 0, 0.78, -8.2 }, AZURE, "Neon", { Glow = 6, Role = "Weapon" }),
		P("GuandaoTassel", "RightHand", { 0.2, 0.6, 0.2 }, { 0, -0.45, -6.9 }, RED, "Fabric"),
	}
	for row = 0, 3 do
		table.insert(list, P("Lamellar" .. row, "UpperTorso", { 2.14, 0.36, 1.14 }, { 0, 0.6 - row * 0.38, 0 }, if row % 2 == 0 then LACQUER else { 40, 52, 78 }, "Metal"))
	end
	pair(list, "PheasantPlume", "Head", "Head", { 0.12, 3.2, 0.12 }, { -0.25, 2, 0.5 }, PLUME, "Fabric", { Rot = { -25, 0, 8 } })
	pair(list, "Pauldron", "UpperTorso", "UpperTorso", { 1.1, 0.28, 1.3 }, { -1.3, 0.72, 0 }, LACQUER, "Metal", { Rot = { 0, 0, 20 } })
	pair(list, "PennantPole", "UpperTorso", "UpperTorso", { 0.1, 3.2, 0.1 }, { -0.5, 1.6, 0.62 }, { 70, 54, 40 }, "Wood")
	pair(list, "BackPennant", "UpperTorso", "UpperTorso", { 0.08, 2.4, 1 }, { -0.5, 2, 1.12 }, AZURE, "Fabric")
	pair(list, "Sleeve", "LeftUpperArm", "RightUpperArm", { 0.06, 0, 0.06 }, { 0, 0, 0 }, AZURE, "Fabric", { Fit = true })
	pair(list, "Bracer", "LeftLowerArm", "RightLowerArm", { 0.1, -0.25, 0.1 }, { 0, 0, 0 }, LACQUER, "Metal", { Fit = true })
	pair(list, "CoatFront", "LeftUpperLeg", "RightUpperLeg", { 1, 1.9, 0.1 }, { 0, -0.5, -0.56 }, AZURE, "Fabric")
	pair(list, "Tasset", "LeftUpperLeg", "RightUpperLeg", { 0.3, 1, 1 }, { -0.62, 0.1, 0 }, LACQUER, "Metal")
	pair(list, "Greave", "LeftLowerLeg", "RightLowerLeg", { 0.08, -0.2, 0.08 }, { 0, 0, 0 }, LACQUER, "Metal", { Fit = true })
	return { Key = "GeneralZhao", Rig = "Humanoid", OwnWeapon = true, Pieces = list, Body = { { 176, 140, 108 }, LACQUER } }
end

local function bull(): Schema.Look
	local list: { Schema.Piece } = {
		P("BullHelm", "Head", { 1.5, 1.4, 1.5 }, { 0, 0.1, 0 }, IRON, "Metal"),
		P("VisorSlit", "Head", { 1.1, 0.1, 0.06 }, { 0, 0.1, -0.76 }, AMBER, "Neon", { Glow = 4 }),
		P("BreastPlate", "UpperTorso", { 0.3, 0.2, 0.3 }, nil, IRON, "Metal", { Fit = true }),
		P("OxHideCape", "UpperTorso", { 2.6, 3.6, 0.16 }, { 0, -0.9, 0.72 }, HIDE, "Leather", { Rot = { -6, 0, 0 } }),
		P("IronBelt", "LowerTorso", { 0.3, 0.3, 0.3 }, nil, BRONZE, "Metal", { Fit = true }),
		P("TassetFront", "LowerTorso", { 2.3, 1.4, 0.3 }, { 0, -0.8, -0.64 }, IRON, "Metal"),
		P("Greatshield", "LeftLowerArm", { 3.2, 4.6, 0.45 }, { 0.2, -0.3, -0.95 }, IRON, "Metal"),
		P("ShieldRim", "LeftLowerArm", { 3.45, 4.85, 0.3 }, { 0.2, -0.3, -0.86 }, BRONZE, "Metal"),
		P("MaulHaft", "RightHand", { 0.36, 0.36, 6 }, { 0, -0.1, -2.2 }, { 54, 40, 30 }, "Wood", { Role = "Weapon" }),
		P("MaulHead", "RightHand", { 1.3, 1.3, 1.6 }, { 0, -0.1, -5.6 }, IRON, "Metal", { Role = "Weapon" }),
		P("MaulBand", "RightHand", { 1.36, 1.36, 0.2 }, { 0, -0.1, -5.1 }, BRONZE, "Metal"),
	}
	for band = 0, 2 do
		table.insert(list, P("PlateBand" .. band, "UpperTorso", { 2.4, 0.14, 1.4 }, { 0, 0.5 - band * 0.5, 0 }, BRONZE, "Metal"))
	end
	pair(list, "HornBase", "Head", "Head", { 1, 0.42, 0.42 }, { -1.1, 0.45, 0 }, BONE, "Marble")
	pair(list, "HornTip", "Head", "Head", { 0.3, 1, 0.3 }, { -1.55, 0.95, -0.1 }, BONE, "Marble", { Rot = { 0, 0, -25 } })
	pair(list, "Pauldron", "UpperTorso", "UpperTorso", { 1.6, 0.8, 1.6 }, { -1.45, 0.75, 0 }, IRON, "Metal", { Rot = { 0, 0, 15 } })
	-- The ▲ sigil: two wedges back to back, tall edges meeting at the shield's centre line.
	for side = -1, 1, 2 do
		table.insert(list, P("ShieldSigil" .. side, "LeftLowerArm", { 0.12, 1.1, 0.55 }, { 0.2 + side * 0.275, -0.1, -1.24 }, AMBER, "Neon", { Rot = { 0, -side * 90, 0 }, Glow = if side < 0 then 4 else nil, Role = "Sigil" }))
	end
	pair(list, "ArmPlate", "LeftUpperArm", "RightUpperArm", { 0.2, -0.1, 0.2 }, { 0, 0, 0 }, IRON, "Metal", { Fit = true })
	pair(list, "Gauntlet", "LeftLowerArm", "RightLowerArm", { 0.3, 0, 0.3 }, { 0, 0, 0 }, IRON, "Metal", { Fit = true })
	pair(list, "ThighPlate", "LeftUpperLeg", "RightUpperLeg", { 0.25, -0.1, 0.25 }, { 0, 0, 0 }, IRON, "Metal", { Fit = true })
	pair(list, "Greave", "LeftLowerLeg", "RightLowerLeg", { 0.3, 0, 0.3 }, { 0, 0, 0 }, IRON, "Metal", { Fit = true })
	pair(list, "Sabaton", "LeftFoot", "RightFoot", { 0.25, 0.15, 0.3 }, { 0, 0, 0 }, IRON, "Metal", { Fit = true })
	return { Key = "IronBull", Rig = "Humanoid", OwnWeapon = true, Pieces = list, Body = { { 150, 110, 86 }, IRON } }
end

return table.freeze({ GrandmasterShen = shen(), GeneralZhao = zhao(), IronBull = bull() })
