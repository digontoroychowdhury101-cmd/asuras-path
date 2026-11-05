--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/BambooFoundry
-- Art for the Foundry wing (route batch): the yard, casting hall, bell terrace, Bell Walk and Founders' Kiln. The Foundry kit plus existing
-- uploaded kit pieces. Everything here is decor: collision lives in BambooPassLayout, so the walk suite sees every surface that
-- can stop a body or a camera. The tower on the terrace is the wing's far goal, placed to read from the Bamboo Gate over the thicket.
local CollectionService = game:GetService("CollectionService")
local Kit = require(script.Parent:WaitForChild("MonasteryKit") :: ModuleScript)
local Fx = require(script.Parent:WaitForChild("MonasteryFx") :: ModuleScript)
local Decor = require(script.Parent:WaitForChild("RegionDecor") :: ModuleScript)
local GateArt = require(script.Parent:WaitForChild("BambooGateArt") :: ModuleScript)

local Foundry = {}
local M = Enum.Material
local rgb = Color3.fromRGB
local EMBER = rgb(255, 150, 80)
local LOBBY, HAN, FOUNDRY = "AsuraLobbyKit", "AsuraHanKit", "AsuraFoundryKit"

local function lobby(parent: Instance, piece: string, at: Vector3, yaw: number?, scale: number?): Model?
	return Decor.han(parent, LOBBY, piece, CFrame.new(at) * CFrame.Angles(0, math.rad(yaw or 0), 0), scale)
end
local function han(parent: Instance, piece: string, at: Vector3, yaw: number?, scale: number?): Model?
	return Decor.han(parent, HAN, piece, CFrame.new(at) * CFrame.Angles(0, math.rad(yaw or 0), 0), scale)
end
-- Roofs fade while they hide the player (the same tag the drum tower's loft uses).
local function fades(model: Model?)
	if model then CollectionService:AddTag(model, "AsuraCameraFade") end
end

local function column(parent: Instance, x: number, floor: number, z: number, height: number)
	lobby(parent, "Column_Base", Vector3.new(x, floor, z), 0, 1.5)
	lobby(parent, "Column_Lacquer", Vector3.new(x, floor + 0.9, z), 0, (height - 0.9) / 10)
end

-- The boxes stay the colliders; the kit piece standing on them is what is seen.
local function hideBoxes(map: Instance, names: { [string]: boolean })
	local structure = map:FindFirstChild("Structure")
	for _, p in if structure then structure:GetChildren() else {} do
		if p:IsA("BasePart") and names[p.Name] then p.Transparency, p.CastShadow = 1, false end
	end
end

local function hanging(parent: Instance, x: number, y: number, z: number, range: number?)
	lobby(parent, "Lantern_Hanging", Vector3.new(x, y, z), 0, 1.4)
	local glow = Kit.part(parent, "LanternGlow", Vector3.new(0.6, 0.6, 0.6), CFrame.new(x, y - 1.4, z), EMBER, M.Basalt, Kit.decor())
	glow.Transparency = 1
	Kit.light(glow, rgb(255, 176, 110), range or 22, 1.5, false)
end

-- A kiln's fire: a sunken glow, embers and low warm light.
local function fire(parent: Instance, at: Vector3, range: number)
	local anchor = Kit.part(parent, "KilnFire", Vector3.new(1.6, 0.4, 1.6), CFrame.new(at), EMBER, M.Basalt, Kit.decor())
	anchor.Transparency = 1
	Fx.glow(anchor, 3)
	Fx.embers(anchor, 8)
	Kit.light(anchor, EMBER, range, 2, false)
end

-- A piece of the Foundry kit (tools/blender/foundry_kit.py). Its box stays the collider; once the mesh stands, the box is hidden.
local function foundry(parent: Instance, piece: string, at: Vector3, yaw: number?, scale: number?): Model?
	return Decor.han(parent, FOUNDRY, piece, CFrame.new(at) * CFrame.Angles(0, math.rad(yaw or 0), 0), scale)
end

-- The hall's walls: one timber-framed brick bay every 10.5 studs or so, stretched a little to fit each run exactly. Doors stay where the layout cut them.
local function hallWalls(parent: Instance, map: Instance)
	local structure = map:FindFirstChild("Structure")
	for _, box in if structure then structure:GetChildren() else {} do
		if box:IsA("BasePart") and box.Name == "HallWall" then
			local length = box.Size.Z
			local bays = math.max(1, math.round(length / 10.5))
			local bay = length / bays
			local placed = false
			for i = 1, bays do
				local cf = box.CFrame * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new((i - 0.5) * bay - length / 2, 0, 0)
				local model = foundry(parent, "Foundry_HallWall", cf.Position, 0, 1)
				local mesh = model and model:FindFirstChildWhichIsA("MeshPart")
				if mesh then
					mesh.Size = Vector3.new(bay * 10.6 / 10.5, box.Size.Y, mesh.Size.Z)
					mesh.CFrame = cf
					placed = true
				end
			end
			if placed then box.Transparency, box.CastShadow = 1, false end
		end
	end
end

-- Slag heaps stand on their boxes' footprints, sized to cover them.
local function slagHeaps(parent: Instance, map: Instance)
	local structure = map:FindFirstChild("Structure")
	for _, box in if structure then structure:GetChildren() else {} do
		if box:IsA("BasePart") and box.Name == "SlagHeap" then
			local _, yaw = box.CFrame:ToOrientation()
			local at = box.Position - Vector3.new(0, box.Position.Y, 0)
			if foundry(parent, "Foundry_SlagHeap", at, math.deg(yaw), math.max(box.Size.X / 13, box.Size.Z / 7.5)) then
				box.Transparency, box.CastShadow = 1, false
			end
		end
	end
end

local function yard(parent: Instance, map: Instance)
	local group = Kit.folder("FoundryYard", parent)
	-- A broken gate at the clearing's edge announces the turn off the straight road.
	lobby(group, "Ruin_Gate", Vector3.new(-41, 0, -1178), 90, 1.25)
	lobby(group, "Banner_Cloth", Vector3.new(-42, 13, -1170), 90, 1)
	-- Yard walls follow the veil; they are the reason the veil is there.
	han(group, "HanWallLong", Vector3.new(-62, -0.4, -1158), 0, 1)
	han(group, "HanWallLong", Vector3.new(-99, -0.4, -1158), 0, 1)
	han(group, "HanWallLong", Vector3.new(-128, -0.4, -1181), 90, 1.1)
	-- The working yard: a great crucible, its fire, cold moulds and slag.
	foundry(group, "Foundry_Crucible", Vector3.new(-58, 0, -1167), 205)
	fire(group, Vector3.new(-58, 1.5, -1167), 26)
	fire(group, Vector3.new(-58, 5.8, -1167), 14)
	-- Two split bell moulds, each with its clay core lifted out in front.
	foundry(group, "Foundry_BellMould", Vector3.new(-92, 0, -1163), 8)
	foundry(group, "Foundry_BellMould", Vector3.new(-116, 0, -1200), 172)
	slagHeaps(group, map)
	hideBoxes(map, { CrucibleBody = true, MouldBody = true })
	lobby(group, "Stele_Broken", Vector3.new(-82, 0, -1200), 12, 1)
	Decor.brazier(group, CFrame.new(-118, 0, -1176), 24)
end

local function hall(parent: Instance, map: Instance)
	local group = Kit.folder("CastingHall", parent)
	hideBoxes(map, { HallColumn = true })
	for _, x in { -110, -84 } do
		for _, z in { -1219, -1238 } do
			column(group, x, 6, z, 14)
			lobby(group, "Bracket_Set", Vector3.new(x, 18.6, z), 90, 0.7)
		end
	end
	fades(lobby(group, "Roof_Hall", Vector3.new(-97, 19.6, -1228.5), 0, 2))
	-- The casting pit under the great cauldron: the room's one bright thing.
	foundry(group, "Foundry_Crucible", Vector3.new(-97, 7.2, -1228), 40)
	fire(group, Vector3.new(-97, 8.7, -1228), 18)
	fire(group, Vector3.new(-97, 13, -1228), 34)
	hallWalls(group, map)
	hanging(group, -110, 18, -1228.5, 20)
	hanging(group, -84, 18, -1228.5, 20)
	-- Door frames, so each opening reads from across the room.
	lobby(group, "Beam_Architrave", Vector3.new(-97, 18.4, -1207), 0, 2)
	lobby(group, "Beam_Architrave", Vector3.new(-124, 15, -1222), 90, 1.5)
	lobby(group, "Banner_Cloth", Vector3.new(-71.9, 18, -1219), 90, 1.1)
	lobby(group, "Banner_Cloth", Vector3.new(-71.9, 18, -1238), 90, 1.1)
	lobby(group, "Stele_Dragon", Vector3.new(-76, 6, -1248.6), 180, 0.9)
	-- The yard face: a colonnade and hangings, so the long stone wall reads as a working hall and the door as its centre.
	for _, x in { -122, -106.5, -87.5, -72 } do column(group, x, 0, -1206, 19.4) end
	for _, z in { -1215, -1228, -1241 } do column(group, -69, 0, z, 19.4) end
	lobby(group, "Banner_Cloth", Vector3.new(-114, 16, -1205.2), 0, 1.3)
	lobby(group, "Banner_Cloth", Vector3.new(-80, 16, -1205.2), 0, 1.3)
	lobby(group, "Banner_Cloth", Vector3.new(-68.2, 16, -1221.5), 90, 1.3)
	hanging(group, -97, 18, -1205, 22)
end

local function terrace(parent: Instance, map: Instance)
	local group = Kit.folder("BellTerrace", parent)
	-- The far goal: seen over the thicket from the Bamboo Gate, and lost behind the hall until its west door.
	han(group, "HanGreatTower", Vector3.new(-180, 20, -1272), 90, 1.3)
	hideBoxes(map, { BellTowerCore = true })
	-- The seventh bell, whole, in its frame.
	hideBoxes(map, { BellPost = true })
	for _, c in { { -160, -1250 }, { -150, -1250 }, { -160, -1241 }, { -150, -1241 } } do column(group, c[1], 20.2, c[2], 13.8) end
	for _, z in { -1250, -1241 } do lobby(group, "Beam_Architrave", Vector3.new(-155, 33, z), 0, 1.3) end
	lobby(group, "Beam_Architrave", Vector3.new(-155, 33.5, -1245.5), 0, 1.3)
	lobby(group, "Roof_Square", Vector3.new(-155, 35, -1245.5), 0, 1)
	foundry(group, "Foundry_Bell", Vector3.new(-155, 23.73, -1245.5), 15)
	-- Colour and scale against the cliff edge.
	lobby(group, "Tree_Maple", Vector3.new(-186, 19.8, -1212), 40, 1.1)
	lobby(group, "Tree_MapleSmall", Vector3.new(-148, 19.8, -1212), 200, 0.9)
	lobby(group, "Lantern_Stone", Vector3.new(-160, 20, -1230), 0, 1)
	lobby(group, "Lantern_Stone", Vector3.new(-178, 20, -1218), 0, 1)
	lobby(group, "Shrub_Crimson", Vector3.new(-188, 19.8, -1288), 0, 2)
	lobby(group, "Rock_Outcrop", Vector3.new(-152, 19.6, -1288), 120, 0.8)
end

local function kiln(parent: Instance, map: Instance)
	local group = Kit.folder("FoundersKiln", parent)
	han(group, "HanHouse", Vector3.new(-172, 10, -1348), 180, 1.1)
	-- The kiln: its boxes are the colliders, its mouth still burns, its flue still breathes.
	if foundry(group, "Foundry_KilnStack", Vector3.new(-148, 10, -1338), 180) then hideBoxes(map, { KilnStack = true, KilnPlinth = true }) end
	fire(group, Vector3.new(-148, 11.9, -1334), 30)
	local smoke = Kit.part(group, "FlueTop", Vector3.new(4, 0.4, 4), CFrame.new(-148, 36.2, -1338), rgb(40, 38, 36), M.Basalt, Kit.decor())
	smoke.Transparency = 1
	Fx.embers(smoke, 3)
	lobby(group, "Rock_Outcrop", Vector3.new(-186, 9.6, -1342), 40, 1)
	lobby(group, "Stele_Broken", Vector3.new(-186, 10, -1305), 75, 1)
	han(group, "CragB", Vector3.new(-143, 9.6, -1300), 10, 1.1)
end

local function walk(parent: Instance, map: Instance)
	local group = Kit.folder("BellWalk", parent)
	hideBoxes(map, { WalkRail = true })
	for _, seg in { { -122, -102 }, { -82, -62 } } do
		for x = seg[1], seg[2], 5 do
			for _, z in { -1264.6, -1279.4 } do lobby(group, "Rail_Bay", Vector3.new(x + 2.5, 20, z), 0, 1) end
		end
	end
	-- Ringers' Lookout: a roofed pier, where the crest and the mountain open up ahead.
	for _, c in { { -98.5, -1258.5 }, { -85.5, -1258.5 }, { -98.5, -1285.5 }, { -85.5, -1285.5 } } do column(group, c[1], 20, c[2], 11.5) end
	fades(lobby(group, "Roof_Square", Vector3.new(-92, 31, -1272), 0, 1.75))
	hanging(group, -92, 30.5, -1272, 26)
	lobby(group, "Banner_Cloth", Vector3.new(-99.6, 30, -1272), 90, 1.1)
	lobby(group, "Banner_Cloth", Vector3.new(-84.4, 30, -1272), 90, 1.1)
end

local function ridgeGate(parent: Instance, map: Instance)
	local group = Kit.folder("RidgeGateFrame", parent)
	local structure = map:FindFirstChild("Structure")
	for _, box in if structure then structure:GetChildren() else {} do
		if box:IsA("BasePart") and box.Name == "RidgeGateWing" then
			-- Layout.wall runs its length along local Z; panels run their width along X.
			local panel = GateArt.Panel(group, box.CFrame * CFrame.Angles(0, math.pi / 2, 0),
				Vector3.new(box.Size.Z, box.Size.Y, box.Size.X), "RidgeGateWing_Cedar")
			if panel then box.Transparency, box.CastShadow = 1, false end
		end
	end
	lobby(group, "Beam_Architrave", Vector3.new(0, 23.2, -1250.5), 0, 1.9)
	lobby(group, "Roof_Gallery", Vector3.new(-4.4, 25, -1250.5), 90, 0.9)
	lobby(group, "Roof_Gallery", Vector3.new(4.4, 25, -1250.5), 90, 0.9)
end

function Foundry.Build(map: Instance)
	local set = Kit.folder("FoundryWing", map)
	yard(set, map)
	hall(set, map)
	terrace(set, map)
	kiln(set, map)
	walk(set, map)
	ridgeGate(set, map)
end

return Foundry
