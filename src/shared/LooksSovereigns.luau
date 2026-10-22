--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/LooksSovereigns
-- Batch 13 looks. Sovereign Wu, the Starless Oracle: a tall mianliu crown with hanging jade
-- strings, a veiled face, a stiff fan collar, night robes to the floor, five star charms orbiting
-- the root and a star-headed staff (catalyst reach 8 / scale 1.2). Phase 2 (Unbound) breaks the
-- crown into a void halo and turns the stars to bloodflame. Azure Wyrm: a horned dragon around the
-- BossBodies "Dragon" capsules (head, body, tail, four legs on the ground at y = -3) with two
-- articulated wings (inner arm + membrane, tip finger + membrane riding the inner beat), barbels
-- and a finned tail; phase 2 charges the spines and tail fin with thunder. Studs at scale 1.
local Schema = require(script.Parent.CostumeSchema)
local P = Schema.P
local R = "HumanoidRootPart"

local NIGHT, GILT, JADE, STAR, BLOOD = { 24, 22, 40 }, { 196, 166, 92 }, { 150, 110, 240 }, { 190, 170, 255 }, { 230, 40, 60 }
local SCALE, BELLY, IVORY, MEMBRANE, THUNDER = { 44, 110, 180 }, { 206, 186, 126 }, { 232, 226, 204 }, { 70, 150, 215 }, { 150, 205, 255 }

local function mirror(list: { Schema.Piece }, name: string, bone: string, size: { number }, at: { number }, color: { number }, material: string, extra: { [string]: any }?)
	-- Authored for the left (-x) piece; the right mirrors position, rotation, hinges and joint side.
	for side = -1, 1, 2 do
		local e: { [string]: any } = table.clone(extra or {})
		local m = -side
		if e.Rot then e.Rot = { e.Rot[1], e.Rot[2] * m, e.Rot[3] * m } end
		for _, key in { "Pivot", "Pivot2" } do
			if e[key] then e[key] = { e[key][1] * m, e[key][2], e[key][3] } end
		end
		if e.Joint and side > 0 then e.Joint = string.gsub(e.Joint, "L$", "R") end
		table.insert(list, P(name .. (if side < 0 then "L" else "R"), bone, size, { at[1] * m, at[2], at[3] }, color, material, e))
	end
end

local function wu(): Schema.Look
	local list: { Schema.Piece } = {
		P("CrownCap", "Head", { 0.9, 0.7, 0.9 }, { 0, 0.62, 0.05 }, NIGHT, "SmoothPlastic"),
		P("CrownBoard", "Head", { 1.9, 0.12, 1.25 }, { 0, 1.02, 0 }, NIGHT, "Wood", { Phase = 1 }),
		P("CrownGilt", "Head", { 1.94, 0.05, 1.29 }, { 0, 0.94, 0 }, GILT, "Metal", { Phase = 1 }),
		P("Veil", "Head", { 1.02, 0.45, 0.06 }, { 0, -0.25, -0.62 }, { 40, 26, 60 }, "Fabric"),
		P("BackHair", "Head", { 1.15, 1.3, 0.3 }, { 0, -0.2, 0.55 }, { 18, 16, 24 }, "Fabric"),
		P("FanCollar", "UpperTorso", { 2.3, 1, 0.12 }, { 0, 1.05, 0.45 }, NIGHT, "Wood", { Rot = { 15, 0, 0 } }),
		P("CollarGilt", "UpperTorso", { 2.34, 0.08, 0.16 }, { 0, 1.55, 0.58 }, GILT, "Metal", { Rot = { 15, 0, 0 } }),
		P("OuterRobe", "UpperTorso", { 0.14, 0.06, 0.14 }, nil, NIGHT, "Fabric", { Fit = true }),
		P("StarSash", "LowerTorso", { 0.16, 0.24, 0.16 }, nil, GILT, "Fabric", { Fit = true }),
		P("RobeTrain", "LowerTorso", { 2.3, 2.75, 0.12 }, { 0, -1.55, 0.58 }, NIGHT, "Fabric", { Rot = { -4, 0, 0 } }),
		P("VoidEye", "Head", { 0.16, 0.24, 0.05 }, { 0, 0.32, -0.62 }, BLOOD, "Neon", { Phase = 2, Glow = 4 }),
		-- Staff: catalyst reach 8 at scale 1.2 -> tip ~6.7 studs from the root at scale 1.
		P("OracleStaff", "RightHand", { 0.2, 0.2, 7.2 }, { 0, -0.1, -2.9 }, { 52, 36, 30 }, "Wood", { Role = "Weapon" }),
		P("StaffRing", "RightHand", { 0.1, 1.2, 1.2 }, { 0, -0.1, -6.5 }, GILT, "Metal", { Shape = "Cylinder", Rot = { 0, 90, 0 }, Role = "Weapon" }),
		P("StaffStar", "RightHand", { 0.5, 0.5, 0.5 }, { 0, -0.1, -6.5 }, JADE, "Neon", { Shape = "Ball", Glow = 6, Role = "Weapon" }),
	}
	for k = 0, 4 do
		local x = -0.6 + k * 0.3
		table.insert(list, P("JadeString" .. k, "Head", { 0.06, 0.8, 0.06 }, { x, 0.55, -0.66 }, JADE, "Glass", { Phase = 1 }))
		local a = k / 5 * math.pi * 2
		table.insert(list, P("StarCharm" .. k, R, { 0.45, 0.45, 0.45 }, { math.cos(a) * 2.6, 1.2 + (k % 2) * 0.8, math.sin(a) * 2.6 }, STAR, "Neon",
			{ Shape = "Ball", Joint = "Orbit", Pivot = { 0, 0, 0 }, Phase = 1 }))
		table.insert(list, P("BloodStar" .. k, R, { 0.5, 0.5, 0.5 }, { math.cos(a) * 2.9, 1.4 + (k % 2) * 0.8, math.sin(a) * 2.9 }, BLOOD, "Neon",
			{ Shape = "Ball", Joint = "Orbit", Pivot = { 0, 0, 0 }, Phase = 2, Glow = if k == 0 then 8 else nil }))
	end
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		table.insert(list, P("VoidHalo" .. k, "Head", { 0.12, 0.5, 0.12 }, { math.cos(a) * 1.25, 0.35 + math.sin(a) * 1.25, 0.75 }, BLOOD, "Neon",
			{ Rot = { 0, 0, math.deg(a) + 90 }, Phase = 2, Glow = if k == 0 then 6 else nil }))
	end
	mirror(list, "Eye", "Head", { 0.18, 0.06, 0.04 }, { -0.22, 0.08, -0.615 }, JADE, "Neon", {})
	mirror(list, "Mantle", "UpperTorso", { 1.2, 0.35, 1.4 }, { -1.15, 0.78, 0 }, NIGHT, "Fabric", { Rot = { 0, 0, 18 } })
	mirror(list, "OracleSleeve", "LeftLowerArm", { 1.6, 2, 1.6 }, { 0, -0.35, 0 }, NIGHT, "Fabric", {})
	mirror(list, "SleeveGilt", "LeftLowerArm", { 1.64, 0.1, 1.64 }, { 0, -1.3, 0 }, GILT, "Metal", {})
	mirror(list, "FloorRobe", "LeftUpperLeg", { 1.05, 2.7, 0.12 }, { 0, -0.75, -0.57 }, NIGHT, "Fabric", {})
	mirror(list, "RobeStar", "LeftUpperLeg", { 0.14, 0.14, 0.04 }, { 0.1, -0.6, -0.65 }, STAR, "Neon", { Phase = 1 })
	-- mirror() only swaps the side of a position; route each right sleeve/robe piece to its own limb.
	for _, item in list do
		if string.sub(item.Name, -1) == "R" and string.find(item.Bone, "^Left") then item.Bone = "Right" .. string.sub(item.Bone, 5) end
	end
	return { Key = "SovereignWu", Rig = "Humanoid", OwnWeapon = true, Phases = 2, Pieces = list,
		Body = { { 214, 204, 222 }, NIGHT }, Body2 = { { 190, 170, 196 }, { 30, 10, 22 } } }
end

local function wyrm(): Schema.Look
	local list: { Schema.Piece } = {
		P("Chest", R, { 2.4, 2.2, 2.4 }, { 0, -0.45, -1.3 }, SCALE, "SmoothPlastic", { Shape = "Ball", Role = "Body" }),
		P("Torso", R, { 2.2, 2, 2.8 }, { 0, -0.5, 0.3 }, SCALE, "SmoothPlastic", { Role = "Body" }),
		P("Hip", R, { 2.1, 1.9, 2 }, { 0, -0.55, 1.5 }, SCALE, "SmoothPlastic", { Shape = "Ball", Role = "Body" }),
		P("BellyPlates", R, { 1.6, 0.4, 3.4 }, { 0, -1.45, -0.1 }, BELLY, "Metal", { Role = "Body" }),
		P("Neck", R, { 1, 1, 1.2 }, { 0, 0.3, -2.2 }, SCALE, "SmoothPlastic", { Rot = { -30, 0, 0 }, Joint = "Neck", Pivot = { 0, -0.1, -1.7 }, Role = "Body" }),
		P("Head", R, { 1.2, 0.95, 1.5 }, { 0, 0.85, -3 }, SCALE, "SmoothPlastic", { Joint = "Neck", Pivot = { 0, -0.1, -1.7 }, Role = "Body" }),
		P("Snout", R, { 0.9, 0.6, 0.9 }, { 0, 0.7, -3.8 }, SCALE, "SmoothPlastic", { Joint = "Neck", Pivot = { 0, -0.1, -1.7 }, Role = "Body" }),
		P("Jaw", R, { 0.85, 0.25, 1 }, { 0, 0.3, -3.65 }, BELLY, "SmoothPlastic", { Joint = "Jaw", Pivot = { 0, 0.35, -3.2 } }),
		P("NeckFin", R, { 0.1, 0.9, 1.6 }, { 0, 1.25, -2.3 }, IVORY, "Fabric", { Joint = "Neck", Pivot = { 0, -0.1, -1.7 } }),
		P("Tail1", R, { 1, 0.9, 1.4 }, { 0, -0.7, 2.8 }, SCALE, "SmoothPlastic", { Rot = { 8, 0, 0 }, Joint = "Tail1", Pivot = { 0, -0.6, 2.1 }, Role = "Body" }),
		P("Tail2", R, { 0.8, 0.7, 1.4 }, { 0, -1, 4 }, SCALE, "SmoothPlastic", { Rot = { 12, 0, 0 }, Joint = "Tail2", Pivot = { 0, -0.8, 3.3 }, Role = "Body" }),
		P("Tail3", R, { 0.6, 0.5, 1.3 }, { 0, -1.3, 5.1 }, SCALE, "SmoothPlastic", { Rot = { 12, 0, 0 }, Joint = "Tail3", Pivot = { 0, -1.1, 4.5 }, Role = "Body" }),
		P("TailFin", R, { 0.1, 1.2, 1.4 }, { 0, -1, 5.9 }, IVORY, "Fabric", { Joint = "Tail4", Pivot = { 0, -1.3, 5.6 }, Phase = 1 }),
		P("ThunderFin", R, { 0.12, 1.3, 1.5 }, { 0, -1, 5.9 }, THUNDER, "Neon", { Joint = "Tail4", Pivot = { 0, -1.3, 5.6 }, Phase = 2, Glow = 8 }),
		P("StormHeart", R, { 1, 0.08, 1.2 }, { 0, -1.66, -0.6 }, THUNDER, "Neon", { Phase = 2, Glow = 10 }),
	}
	for k = 0, 4 do
		local at = { 0, 0.7 - k * 0.05, -1.6 + k * 0.8 }
		table.insert(list, P("Spine" .. k, R, { 0.2, 0.7, 0.6 }, at, IVORY, "Marble", { Shape = "Wedge", Rot = { 0, 180, 0 }, Phase = 1 }))
		table.insert(list, P("StormSpine" .. k, R, { 0.22, 0.8, 0.6 }, at, THUNDER, "Neon", { Shape = "Wedge", Rot = { 0, 180, 0 }, Phase = 2 }))
	end
	local head = { Joint = "Neck", Pivot = { 0, -0.1, -1.7 } }
	mirror(list, "Horn", R, { 0.2, 1.4, 0.2 }, { -0.4, 1.5, -2.75 }, IVORY, "Marble", { Rot = { -50, 0, 10 }, Joint = head.Joint, Pivot = head.Pivot })
	mirror(list, "Barbel", R, { 0.06, 0.06, 1.6 }, { -0.4, 0.6, -4.1 }, GILT, "Fabric", { Rot = { 0, 30, 0 }, Joint = head.Joint, Pivot = head.Pivot })
	mirror(list, "Eye", R, { 0.05, 0.14, 0.24 }, { -0.61, 1, -3.3 }, { 255, 214, 90 }, "Neon", { Joint = head.Joint, Pivot = head.Pivot })
	mirror(list, "ForeLeg", R, { 0.7, 1.5, 0.7 }, { -0.95, -1.95, -1.3 }, SCALE, "SmoothPlastic", { Joint = "LegFL", Pivot = { -0.9, -1.2, -1.2 }, Role = "Body" })
	mirror(list, "ForeClaw", R, { 0.8, 0.3, 0.9 }, { -0.95, -2.85, -1.45 }, BELLY, "Metal", { Joint = "LegFL", Pivot = { -0.9, -1.2, -1.2 }, Role = "Foot" })
	mirror(list, "HindLeg", R, { 0.85, 1.5, 0.85 }, { -1, -1.95, 1.3 }, SCALE, "SmoothPlastic", { Joint = "LegHL", Pivot = { -0.95, -1.2, 1.2 }, Role = "Body" })
	mirror(list, "HindClaw", R, { 0.8, 0.3, 0.9 }, { -1, -2.85, 1.4 }, BELLY, "Metal", { Joint = "LegHL", Pivot = { -0.95, -1.2, 1.2 }, Role = "Foot" })
	-- Wings: inner arm + membrane hinge at the shoulder; the tip finger + membrane hinge at the wrist
	-- and ride the inner beat (Pivot2).
	mirror(list, "WingArm", R, { 3.2, 0.25, 0.3 }, { -2.6, 0.9, -0.6 }, IVORY, "Marble", { Joint = "WingL", Pivot = { -1, 0.6, -0.6 } })
	mirror(list, "WingMembrane", R, { 3.2, 0.08, 2.6 }, { -2.6, 0.85, 0.65 }, MEMBRANE, "Fabric", { Joint = "WingL", Pivot = { -1, 0.6, -0.6 }, Transparency = 0.15 })
	mirror(list, "WingFinger", R, { 2.8, 0.2, 0.25 }, { -5.6, 1.2, -0.5 }, IVORY, "Marble", { Joint = "WingTipL", Pivot = { -4.2, 1, -0.6 }, Pivot2 = { -1, 0.6, -0.6 } })
	mirror(list, "WingTipMembrane", R, { 2.8, 0.06, 2.4 }, { -5.6, 1.1, 0.7 }, MEMBRANE, "Fabric", { Joint = "WingTipL", Pivot = { -4.2, 1, -0.6 }, Pivot2 = { -1, 0.6, -0.6 }, Transparency = 0.2 })
	return { Key = "AzureWyrm", Rig = "Creature", HideBody = true, OwnWeapon = true, Phases = 2, Pieces = list }
end

return table.freeze({ SovereignWu = wu(), AzureWyrm = wyrm() })
