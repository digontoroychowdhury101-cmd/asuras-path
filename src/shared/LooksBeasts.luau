--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/LooksBeasts
-- Batch 12 looks. Venerable Baize: a low white frost beast (horned head, third eye, gold-white mane,
-- watchful eyes along its flanks, plumed tail) authored on the root around the BossBodies "Beast"
-- capsules, paws on the ground at y = -3; legs, jaw, mane and tail are joints CreatureMotion poses.
-- Phase 2 (Unbound) ices the mane and raises crystal spines. The Slumbering Titan: a scale-3
-- stone ancient (antlered root-bearded head, shoulder boulders, bronze gorget, slung broken haft)
-- whose lower legs stay slim so the camera keeps clear at the ankles; its glowing shackles mark the
-- ankle weak point. Phase 2 splits it with magma. Positions are studs at scale 1 (CostumeSchema).
local Schema = require(script.Parent.CostumeSchema)
local P = Schema.P
local R = "HumanoidRootPart"

local FUR, MANE, ICE, HORN, EYE = { 228, 232, 236 }, { 240, 232, 206 }, { 150, 212, 244 }, { 196, 214, 228 }, { 110, 220, 255 }
local STONE, ROCK, BRONZE, ROOT, MOSS = { 92, 90, 86 }, { 70, 66, 62 }, { 120, 92, 56 }, { 58, 44, 34 }, { 72, 88, 52 }
local EMBER, MAGMA = { 255, 170, 60 }, { 255, 96, 30 }

local function mirror(list: { Schema.Piece }, name: string, size: { number }, at: { number }, color: { number }, material: string, extra: { [string]: any }?)
	-- `at`, Rot, Pivot and Joint are authored for the left (-x) piece; the right mirrors them.
	for side = -1, 1, 2 do
		local e: { [string]: any } = table.clone(extra or {})
		local m = -side
		if e.Rot then e.Rot = { e.Rot[1], e.Rot[2] * m, e.Rot[3] * m } end
		if e.Pivot then e.Pivot = { e.Pivot[1] * m, e.Pivot[2], e.Pivot[3] } end
		if e.Joint and side > 0 then e.Joint = string.gsub(e.Joint, "L$", "R") end
		table.insert(list, P(name .. (if side < 0 then "L" else "R"), e.Bone or R, size, { at[1] * m, at[2], at[3] }, color, material, e))
	end
end

local function baize(): Schema.Look
	local list: { Schema.Piece } = {
		P("Chest", R, { 2.15, 2, 2 }, { 0, -0.35, -1.15 }, FUR, "SmoothPlastic", { Shape = "Ball", Role = "Body" }),
		P("Barrel", R, { 2, 1.85, 2.4 }, { 0, -0.5, 0.15 }, FUR, "SmoothPlastic", { Role = "Body" }),
		P("Haunch", R, { 2, 1.9, 1.9 }, { 0, -0.5, 1.3 }, FUR, "SmoothPlastic", { Shape = "Ball", Role = "Body" }),
		P("Neck", R, { 1, 1.1, 1 }, { 0, 0.05, -1.85 }, FUR, "SmoothPlastic", { Rot = { -35, 0, 0 }, Role = "Body" }),
		P("Skull", R, { 1.1, 1, 1.25 }, { 0, 0.45, -2.5 }, FUR, "SmoothPlastic", { Joint = "Neck", Pivot = { 0, 0.1, -1.9 }, Role = "Body" }),
		P("Muzzle", R, { 0.8, 0.6, 0.7 }, { 0, 0.25, -3.1 }, FUR, "SmoothPlastic", { Joint = "Neck", Pivot = { 0, 0.1, -1.9 }, Role = "Body" }),
		P("Jaw", R, { 0.74, 0.24, 0.8 }, { 0, -0.07, -2.95 }, { 200, 196, 196 }, "SmoothPlastic", { Joint = "Jaw", Pivot = { 0, -0.05, -2.5 } }),
		P("ThirdEye", R, { 0.2, 0.12, 0.05 }, { 0, 0.78, -3.15 }, EYE, "Neon", { Joint = "Neck", Pivot = { 0, 0.1, -1.9 }, Glow = 5 }),
		P("ManeCrest", R, { 1.6, 1.5, 1.2 }, { 0, 0.5, -1.7 }, MANE, "Fabric", { Joint = "Mane", Pivot = { 0, 0.2, -1.4 }, Phase = 1 }),
		P("FrostMane", R, { 1.7, 1.6, 1.25 }, { 0, 0.55, -1.7 }, ICE, "Ice", { Joint = "Mane", Pivot = { 0, 0.2, -1.4 }, Phase = 2, Glow = 7 }),
		P("Tail1", R, { 0.4, 0.4, 1 }, { 0, -0.1, 2.75 }, FUR, "SmoothPlastic", { Rot = { -30, 0, 0 }, Joint = "Tail1", Pivot = { 0, -0.35, 2.3 } }),
		P("Tail2", R, { 0.35, 0.35, 1 }, { 0, 0.4, 3.45 }, FUR, "SmoothPlastic", { Rot = { -40, 0, 0 }, Joint = "Tail2", Pivot = { 0, 0.15, 3.1 } }),
		P("TailPlume", R, { 0.8, 0.8, 1.2 }, { 0, 0.9, 4 }, MANE, "Fabric", { Rot = { -45, 0, 0 }, Joint = "Tail3", Pivot = { 0, 0.6, 3.6 } }),
	}
	mirror(list, "Horn", { 0.18, 1.2, 0.18 }, { -0.35, 1.1, -2.3 }, HORN, "Marble", { Rot = { -30, 0, 15 }, Joint = "Neck", Pivot = { 0, 0.1, -1.9 } })
	mirror(list, "Eye", { 0.18, 0.1, 0.05 }, { -0.3, 0.6, -3.15 }, EYE, "Neon", { Joint = "Neck", Pivot = { 0, 0.1, -1.9 } })
	mirror(list, "Ear", { 0.15, 0.5, 0.35 }, { -0.55, 0.85, -2.2 }, FUR, "SmoothPlastic", { Rot = { 0, 0, 30 }, Joint = "Neck", Pivot = { 0, 0.1, -1.9 } })
	mirror(list, "SideMane", { 0.35, 1.3, 1.4 }, { -0.95, 0.1, -1.65 }, MANE, "Fabric", { Rot = { 0, 0, 10 }, Phase = 1 })
	mirror(list, "IceSideMane", { 0.38, 1.4, 1.45 }, { -0.97, 0.12, -1.65 }, ICE, "Ice", { Rot = { 0, 0, 10 }, Phase = 2 })
	for k = 0, 2 do
		mirror(list, "FlankEye" .. k, { 0.06, 0.14, 0.26 }, { -1.02, -0.3, -0.5 + k * 0.55 }, EYE, "Neon", {})
		table.insert(list, P("FrostSpine" .. k, R, { 0.3, 0.9, 0.3 }, { 0, 0.55, -0.6 + k * 0.7 }, ICE, "Ice", { Rot = { 15, 0, 0 }, Phase = 2 }))
	end
	-- Legs: hinge at the shoulder/hip, paws flat on the ground (bottom at y = -3).
	mirror(list, "Foreleg", { 0.6, 1.6, 0.6 }, { -0.75, -1.85, -1.25 }, FUR, "SmoothPlastic", { Joint = "LegFL", Pivot = { -0.75, -1.05, -1.25 }, Role = "Body" })
	mirror(list, "ForePaw", { 0.75, 0.3, 0.85 }, { -0.75, -2.85, -1.4 }, HORN, "SmoothPlastic", { Joint = "LegFL", Pivot = { -0.75, -1.05, -1.25 }, Role = "Foot" })
	mirror(list, "HindThigh", { 0.75, 1, 0.9 }, { -0.8, -1.35, 1.3 }, FUR, "SmoothPlastic", { Joint = "LegHL", Pivot = { -0.8, -1, 1.3 }, Role = "Body" })
	mirror(list, "HindShank", { 0.5, 1.25, 0.5 }, { -0.8, -2.25, 1.45 }, FUR, "SmoothPlastic", { Joint = "LegHL", Pivot = { -0.8, -1, 1.3 }, Role = "Body" })
	mirror(list, "HindPaw", { 0.75, 0.3, 0.85 }, { -0.8, -2.85, 1.35 }, HORN, "SmoothPlastic", { Joint = "LegHL", Pivot = { -0.8, -1, 1.3 }, Role = "Foot" })
	return { Key = "VenerableBaize", Rig = "Creature", HideBody = true, OwnWeapon = true, Phases = 2, Pieces = list }
end

local function titan(): Schema.Look
	local list: { Schema.Piece } = {
		P("StoneHelm", "Head", { 1.5, 1.3, 1.5 }, { 0, 0.1, 0 }, STONE, "Slate"),
		P("BrowRidge", "Head", { 1.6, 0.3, 0.4 }, { 0, 0.2, -0.7 }, ROCK, "Rock"),
		P("RootBeard", "Head", { 1, 0.9, 0.3 }, { 0, -0.7, -0.6 }, ROOT, "Wood"),
		P("Carapace", "UpperTorso", { 0.6, 0.5, 0.6 }, nil, STONE, "Slate", { Fit = true }),
		P("BronzeGorget", "UpperTorso", { 2.4, 0.4, 1.4 }, { 0, 0.75, 0 }, BRONZE, "CorrodedMetal"),
		P("ChestRune", "UpperTorso", { 0.6, 0.6, 0.08 }, { 0, 0.1, -0.86 }, EMBER, "Neon", { Rot = { 0, 0, 45 }, Glow = 6, Phase = 1 }),
		P("BackMoss", "UpperTorso", { 2.2, 1, 0.3 }, { 0, 0.3, 0.86 }, MOSS, "LeafyGrass"),
		P("SlungHaft", "UpperTorso", { 0.3, 4, 0.3 }, { 0.3, 0.3, 1.05 }, ROOT, "Wood", { Rot = { 0, 0, -35 }, Role = "Trim" }),
		P("StoneBelt", "LowerTorso", { 0.5, 0.4, 0.5 }, nil, ROCK, "Rock", { Fit = true }),
		P("LoinCloth", "LowerTorso", { 1.4, 1, 0.15 }, { 0, -0.7, -0.6 }, MOSS, "Fabric"),
		-- Phase 2: the stone splits; magma shows through.
		P("MagmaCore", "UpperTorso", { 0.7, 0.7, 0.08 }, { 0, 0.1, -0.87 }, MAGMA, "Neon", { Rot = { 0, 0, 45 }, Glow = 9, Phase = 2 }),
		P("ChestFissure", "UpperTorso", { 0.15, 1.4, 0.06 }, { 0.35, 0.05, -0.87 }, MAGMA, "Neon", { Rot = { 0, 0, 20 }, Phase = 2 }),
		P("BackFissure", "UpperTorso", { 0.15, 1.5, 0.06 }, { -0.2, 0.1, 0.87 }, MAGMA, "Neon", { Rot = { 0, 0, -15 }, Phase = 2 }),
	}
	mirror(list, "Eye", { 0.25, 0.1, 0.06 }, { -0.3, 0.05, -0.78 }, EMBER, "Neon", { Bone = "Head", Phase = 1 })
	mirror(list, "MoltenEye", { 0.28, 0.12, 0.06 }, { -0.3, 0.05, -0.78 }, MAGMA, "Neon", { Bone = "Head", Phase = 2, Glow = 4 })
	mirror(list, "Antler", { 0.25, 1.8, 0.25 }, { -0.6, 1.3, 0 }, ROOT, "Wood", { Bone = "Head", Rot = { 0, 0, 25 } })
	mirror(list, "AntlerTine", { 0.2, 0.9, 0.2 }, { -1.1, 1.6, -0.2 }, ROOT, "Wood", { Bone = "Head", Rot = { 0, 0, 60 } })
	mirror(list, "ShoulderBoulder", { 1.6, 1.4, 1.6 }, { -1.2, 0.95, 0.1 }, ROCK, "Rock", { Bone = "UpperTorso", Shape = "Ball" })
	for _, side in { "Left", "Right" } do
		local function on(bone: string, name: string, size: { number }, color: { number }, material: string, extra: { [string]: any }?)
			local e = table.clone(extra or {})
			e.Fit = if e.Fit == nil then true else e.Fit
			table.insert(list, P(side .. name, side .. bone, size, e.At, color, material, e))
		end
		on("UpperArm", "ArmStone", { 0.4, 0.1, 0.4 }, ROCK, "Rock")
		on("LowerArm", "Forearm", { 0.5, 0.1, 0.5 }, STONE, "Slate")
		on("LowerArm", "Bracer", { 1.55, 0.5, 1.55 }, BRONZE, "CorrodedMetal", { Fit = false, At = { 0, -0.3, 0 } })
		on("LowerArm", "ArmFissure", { 0.12, 0.8, 0.06 }, MAGMA, "Neon", { Fit = false, At = { 0, 0.2, -0.78 }, Phase = 2 })
		on("Hand", "StoneFist", { 0.5, 0.5, 0.5 }, ROCK, "Rock", { Role = "Weapon" })
		on("UpperLeg", "ThighStone", { 0.3, 0.05, 0.3 }, ROCK, "Rock")
		on("LowerLeg", "Shin", { 0.12, 0, 0.12 }, STONE, "Slate")
		on("LowerLeg", "AnkleShackle", { 1.3, 0.35, 1.3 }, BRONZE, "CorrodedMetal", { Fit = false, At = { 0, -0.35, 0 } })
		on("LowerLeg", "ShackleGlow", { 1.33, 0.08, 1.33 }, EMBER, "Neon", { Fit = false, At = { 0, -0.35, 0 }, Glow = 6 })
		on("Foot", "StoneFoot", { 0.3, 0.1, 0.5 }, ROCK, "Rock", { At = { 0, 0.05, -0.15 }, Role = "Foot" })
	end
	return { Key = "SlumberingTitan", Rig = "Humanoid", OwnWeapon = true, Phases = 2, Pieces = list,
		Body = { STONE, ROCK }, Body2 = { { 110, 70, 58 }, ROCK } }
end

return table.freeze({ VenerableBaize = baize(), SlumberingTitan = titan() })
