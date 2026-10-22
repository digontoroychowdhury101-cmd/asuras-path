--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/LooksCast
-- Batch 14 looks for the speaking cast, each readable as a portrait subject and as a silhouette
-- across a courtyard: Lady Lin (long black hair with a sakura pin, rose outer robe over a white
-- floor-length skirt, a floating shawl and a glowing soul lantern), the Wandering Hermit (bald,
-- long white brows and beard, patched moss robe, bamboo pack with scrolls, gourd, tall knotted
-- staff) and Master Smith Gao (blindfold, grey topknot, leather apron and bracers, belt hammer;
-- built on his live rig). Studs from each limb's centre at scale 1 (CostumeSchema). `Look` is the
-- ground point a standing figure faces.
local Schema = require(script.Parent.CostumeSchema)
local P = Schema.P

local HAIR, ROSE, WHITE, CRIMSON, PINK, JADE = { 22, 18, 22 }, { 196, 150, 160 }, { 236, 230, 226 }, { 150, 36, 48 }, { 244, 168, 190 }, { 96, 200, 160 }
local MOSS, PATCH, BAMBOO, GOURD, SNOW, WOOD = { 77, 86, 70 }, { 112, 86, 58 }, { 168, 140, 84 }, { 176, 110, 50 }, { 236, 234, 228 }, { 90, 64, 40 }
local LEATHER, SOOT, GREY, IRON = { 92, 60, 40 }, { 24, 19, 18 }, { 120, 116, 110 }, { 80, 78, 76 }

local function pair(list: { Schema.Piece }, name: string, bone: string, size: { number }, at: { number }, color: { number }, material: string, extra: { [string]: any }?)
	-- Authored for the left piece; a "Left..." bone is routed to its "Right..." twin.
	for side = -1, 1, 2 do
		local e: { [string]: any } = table.clone(extra or {})
		if e.Rot then e.Rot = { e.Rot[1], -e.Rot[2] * side, -e.Rot[3] * side } end
		local limb = if side > 0 and string.sub(bone, 1, 4) == "Left" then "Right" .. string.sub(bone, 5) else bone
		table.insert(list, P(name .. (if side < 0 then "L" else "R"), limb, size, { -at[1] * side, at[2], at[3] }, color, material, e))
	end
end

local function face(list: { Schema.Piece }, eye: { number }, brow: { number })
	pair(list, "Eye", "Head", { 0.16, 0.07, 0.04 }, { -0.22, 0.06, -0.61 }, eye, "SmoothPlastic")
	pair(list, "Brow", "Head", { 0.3, 0.06, 0.04 }, { -0.22, 0.2, -0.61 }, brow, "Fabric")
end

local function lin(): Schema.Look
	local list: { Schema.Piece } = {
		P("HairCap", "Head", { 1.26, 0.55, 1.26 }, { 0, 0.38, 0.05 }, HAIR, "Fabric"),
		P("Bangs", "Head", { 1.1, 0.25, 0.15 }, { 0, 0.32, -0.58 }, HAIR, "Fabric"),
		P("LongHair", "Head", { 1.1, 2.6, 0.3 }, { 0, -0.95, 0.56 }, HAIR, "Fabric"),
		P("HairBun", "Head", { 0.6, 0.6, 0.6 }, { 0, 0.55, 0.45 }, HAIR, "Fabric", { Shape = "Ball" }),
		P("SakuraPin", "Head", { 0.28, 0.28, 0.28 }, { 0.45, 0.55, 0.3 }, PINK, "SmoothPlastic", { Shape = "Ball" }),
		P("JadeTassel", "Head", { 0.06, 0.7, 0.06 }, { 0.5, 0.1, 0.35 }, JADE, "Glass"),
		P("Lips", "Head", { 0.22, 0.05, 0.04 }, { 0, -0.3, -0.61 }, { 170, 80, 90 }, "SmoothPlastic"),
		P("ShawlBack", "UpperTorso", { 2.8, 0.12, 0.08 }, { 0, 0.9, 0.75 }, PINK, "Fabric", { Transparency = 0.25 }),
		P("Sash", "LowerTorso", { 0.14, 0.3, 0.14 }, nil, CRIMSON, "Fabric", { Fit = true }),
		P("SashBow", "LowerTorso", { 0.6, 0.4, 0.2 }, { 0, 0, 0.62 }, CRIMSON, "Fabric"),
		P("Skirt", "LowerTorso", { 2.3, 2.5, 1.4 }, { 0, -1.4, 0 }, WHITE, "Fabric"),
		P("SkirtHem", "LowerTorso", { 2.34, 0.15, 1.44 }, { 0, -2.55, 0 }, CRIMSON, "Fabric"),
		P("SoulLantern", "RightHand", { 0.5, 0.7, 0.5 }, { 0, -0.6, -0.3 }, { 240, 210, 160 }, "Neon", { Glow = 9, Transparency = 0.15 }),
	}
	face(list, { 40, 30, 36 }, HAIR)
	pair(list, "SideLock", "Head", { 0.22, 1.4, 0.25 }, { -0.58, -0.5, -0.25 }, HAIR, "Fabric")
	pair(list, "InnerCollar", "UpperTorso", { 0.2, 1.5, 0.08 }, { -0.28, 0.05, -0.55 }, WHITE, "Fabric", { Rot = { 0, 0, 22 } })
	pair(list, "ShawlFall", "UpperTorso", { 0.12, 2.6, 0.06 }, { -1.5, -0.4, 0.6 }, PINK, "Fabric", { Rot = { 0, 0, 6 }, Transparency = 0.25 })
	pair(list, "WideSleeve", "LeftUpperArm", { 0.16, 0.05, 0.16 }, { 0, 0, 0 }, ROSE, "Fabric", { Fit = true })
	pair(list, "SleeveFlare", "LeftLowerArm", { 1.4, 1.6, 1.4 }, { 0, -0.3, 0 }, ROSE, "Fabric")
	pair(list, "SleeveHem", "LeftLowerArm", { 1.44, 0.1, 1.44 }, { 0, -1.1, 0 }, WHITE, "Fabric")
	return { Key = "Lin", Rig = "Humanoid", Pieces = list, Budget = 60, Body = { { 236, 206, 190 }, ROSE }, Look = { 0, 900 } }
end

local function hermit(): Schema.Look
	local list: { Schema.Piece } = {
		P("LongBeard", "Head", { 0.7, 1.4, 0.25 }, { 0, -0.9, -0.5 }, SNOW, "Fabric"),
		P("Moustache", "Head", { 0.8, 0.12, 0.12 }, { 0, -0.2, -0.62 }, SNOW, "Fabric"),
		P("Basket", "UpperTorso", { 1.5, 1.9, 1 }, { 0, 0.15, 1.05 }, BAMBOO, "Wood"),
		P("BasketRim", "UpperTorso", { 1.6, 0.15, 1.1 }, { 0, 1.1, 1.05 }, WOOD, "Wood"),
		P("ScrollA", "UpperTorso", { 0.22, 1.3, 0.22 }, { -0.35, 1.5, 1.1 }, { 214, 196, 150 }, "Fabric", { Rot = { 0, 0, 12 } }),
		P("ScrollB", "UpperTorso", { 0.2, 1.1, 0.2 }, { 0.3, 1.4, 1.0 }, { 150, 48, 40 }, "Fabric", { Rot = { 0, 0, -10 } }),
		P("Patch", "UpperTorso", { 0.6, 0.6, 0.06 }, { 0.45, -0.2, -0.53 }, PATCH, "Fabric", { Rot = { 0, 0, 8 } }),
		P("RopeBelt", "LowerTorso", { 0.12, 0.2, 0.12 }, nil, BAMBOO, "Fabric", { Fit = true }),
		P("Gourd", "LowerTorso", { 0.6, 0.6, 0.6 }, { 1.05, -0.45, -0.1 }, GOURD, "SmoothPlastic", { Shape = "Ball" }),
		P("GourdNeck", "LowerTorso", { 0.38, 0.38, 0.38 }, { 1.05, 0.0, -0.1 }, GOURD, "SmoothPlastic", { Shape = "Ball" }),
		P("RobeSkirt", "LowerTorso", { 2.2, 1.9, 1.3 }, { 0, -1.1, 0 }, MOSS, "Fabric"),
		P("Staff", "RightHand", { 0.25, 6.2, 0.25 }, { 0, 1.6, -0.2 }, WOOD, "Wood"),
		P("StaffKnot", "RightHand", { 0.5, 0.5, 0.5 }, { 0, 4.7, -0.2 }, WOOD, "Wood", { Shape = "Ball" }),
		P("StaffBell", "RightHand", { 0.22, 0.22, 0.22 }, { 0.2, 4.3, -0.2 }, { 200, 166, 80 }, "Metal", { Shape = "Ball" }),
	}
	face(list, { 30, 28, 26 }, SNOW)
	pair(list, "DroopBrow", "Head", { 0.42, 0.08, 0.06 }, { -0.3, 0.16, -0.62 }, SNOW, "Fabric", { Rot = { 0, 0, -20 } })
	pair(list, "PackStrap", "UpperTorso", { 0.18, 1.6, 0.06 }, { -0.55, 0.05, -0.54 }, WOOD, "Leather")
	pair(list, "LegWrap", "LeftLowerLeg", { 0.08, -0.2, 0.08 }, { 0, 0, 0 }, PATCH, "Fabric", { Fit = true })
	pair(list, "Sandal", "LeftFoot", { 0.06, 0.04, 0.12 }, { 0, -0.04, 0 }, BAMBOO, "Wood", { Fit = true })
	return { Key = "Hermit", Rig = "Humanoid", Pieces = list, Budget = 60, Body = { { 178, 146, 116 }, MOSS }, Look = { -14, -700 } }
end

local function gao(): Schema.Look
	local list: { Schema.Piece } = {
		P("Blindfold", "Head", { 1.26, 0.28, 1.26 }, { 0, 0.12, 0 }, SOOT, "Fabric"),
		P("BlindfoldTail", "Head", { 0.2, 0.7, 0.06 }, { 0.2, -0.2, 0.64 }, SOOT, "Fabric"),
		P("Topknot", "Head", { 0.45, 0.45, 0.45 }, { 0, 0.66, 0.2 }, GREY, "Fabric", { Shape = "Ball" }),
		P("HairCap", "Head", { 1.24, 0.35, 1.24 }, { 0, 0.45, 0.06 }, GREY, "Fabric"),
		P("ShortBeard", "Head", { 0.9, 0.4, 0.2 }, { 0, -0.45, -0.55 }, GREY, "Fabric"),
		P("LeatherApron", "UpperTorso", { 2.1, 2.6, 0.12 }, { 0, -0.7, -0.57 }, LEATHER, "Leather"),
		P("ToolBelt", "LowerTorso", { 0.14, 0.24, 0.14 }, nil, SOOT, "Leather", { Fit = true }),
		P("BeltHammerHaft", "LowerTorso", { 0.25, 1.2, 0.25 }, { 0.9, -0.5, -0.1 }, WOOD, "Wood"),
		P("BeltHammerHead", "LowerTorso", { 0.7, 0.4, 0.4 }, { 0.9, 0.1, -0.1 }, IRON, "Metal"),
	}
	pair(list, "Brow", "Head", { 0.34, 0.08, 0.05 }, { -0.24, 0.32, -0.62 }, GREY, "Fabric")
	pair(list, "ApronStrap", "UpperTorso", { 0.2, 1, 0.08 }, { -0.6, 0.35, -0.55 }, LEATHER, "Leather")
	pair(list, "Bracer", "LeftLowerArm", { 0.12, -0.2, 0.12 }, { 0, 0, 0 }, LEATHER, "Leather", { Fit = true })
	pair(list, "Mitt", "LeftHand", { 0.14, 0.1, 0.14 }, { 0, 0, 0 }, { 120, 90, 60 }, "Leather", { Fit = true })
	pair(list, "Boot", "LeftFoot", { 0.08, 0.2, 0.12 }, { 0, 0.05, 0 }, SOOT, "Leather", { Fit = true })
	return { Key = "Gao", Rig = "Humanoid", Pieces = list, Budget = 40 }
end

return table.freeze({ Lin = lin(), Hermit = hermit(), Gao = gao() })
