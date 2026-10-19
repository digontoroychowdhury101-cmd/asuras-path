--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/MonasteryGrounds
-- The ground of the Desecrated Monastery: a terrain valley (mud, moss, cliffs of dark rock and a
-- misted ravine) under laid flagstone courtyards, and the stone bridge across the ravine.
-- Every walkable top sits at Kit.GROUND so WorldDefinitions placements (Y = 3) drop onto stone.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage:WaitForChild("AsurasPath").Shared.WorldDefinitions)
local Kit = require(script.Parent:WaitForChild("MonasteryKit") :: ModuleScript)

local Grounds = {}

local P = Kit.Palette
local G = Kit.GROUND
local BOUNDS = World.Regions.DesecratedMonastery.Bounds
local CENTER = Vector3.new(BOUNDS.Center.X, 0, BOUNDS.Center.Z)
local MARGIN = 80

Grounds.RAVINE_Z = -960
Grounds.BRIDGE = { Z0 = -932, Z1 = -988, Half = 10 }

-- Flagstone courtyards {x0, x1, z0, z1, tile, dark}: every spawn, patrol point and altar lies on one.
Grounds.Paving = {
	{ -26, 26, -698, -748, 7, false }, -- Gate landing
	{ -82, 82, -748, -858, 8, false }, -- Main courtyard
	{ -14, 14, -858, -932, 7, true }, -- Processional path between the halls
	{ -102, -38, -866, -934, 6, true }, -- West prayer hall
	{ 38, 118, -868, -934, 6, true }, -- East prayer hall
	{ -14, 14, -988, -1120, 7, false }, -- South road to the Bamboo Pass
	{ 14, 128, -990, -1114, 8, false }, -- Cloister garth and walks
}

-- Smooth terrain renders and collides 2 studs above a filled block's top, so fills stop at
-- TERRAIN_TOP to leave the surface just under the flagstones.
local TERRAIN_TOP = -2.2

-- Terrain extent cleared on build and teardown (region bounds plus the cliff margin).
function Grounds.Extent(): (CFrame, Vector3)
	return CFrame.new(CENTER.X, -20, CENTER.Z), Vector3.new(BOUNDS.Size.X + MARGIN * 2, 120, BOUNDS.Size.Z + MARGIN * 2)
end

function Grounds.Clear()
	local cframe, size = Grounds.Extent()
	Workspace.Terrain:FillBlock(cframe, size, Enum.Material.Air)
end

local function terrain(rng: Random)
	local t = Workspace.Terrain
	t:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(58, 50, 44))
	t:SetMaterialColor(Enum.Material.Mud, Color3.fromRGB(46, 38, 34))
	t:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(70, 68, 46))
	t:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(62, 62, 64))
	t:SetMaterialColor(Enum.Material.Slate, Color3.fromRGB(52, 54, 56))
	local sx, sz = BOUNDS.Size.X + MARGIN * 2, BOUNDS.Size.Z + MARGIN * 2
	t:FillBlock(CFrame.new(CENTER.X, (TERRAIN_TOP - 16) * 0.5, CENTER.Z), Vector3.new(sx, 16 + TERRAIN_TOP, sz), Enum.Material.Ground)
	-- Top-layer patches of mud and sour moss break up the floor between the stones.
	for _ = 1, 36 do
		local x, z = rng:NextNumber(-190, 190), CENTER.Z + rng:NextNumber(-215, 215)
		local material = if rng:NextNumber() < 0.55 then Enum.Material.Mud else Enum.Material.LeafyGrass
		t:FillBlock(CFrame.new(x, TERRAIN_TOP - 1, z), Vector3.new(rng:NextNumber(16, 40), 2, rng:NextNumber(16, 40)), material)
	end
	-- Valley walls: dark rock ridges east, west and north; the south stays open for the road.
	for z = -640, -1160, -22 do
		for side = -1, 1, 2 do
			local x = side * (180 + rng:NextNumber(-6, 12))
			t:FillBall(Vector3.new(x, rng:NextNumber(-6, 14), z), rng:NextNumber(26, 36), Enum.Material.Rock)
			t:FillBall(Vector3.new(x + side * 18, rng:NextNumber(18, 38), z), rng:NextNumber(18, 26), Enum.Material.Slate)
		end
	end
	for x = -200, 200, 22 do
		t:FillBall(Vector3.new(x, rng:NextNumber(-4, 16), -656 + rng:NextNumber(-4, 4)), rng:NextNumber(24, 32), Enum.Material.Rock)
	end
	-- The ravine: a chain of spherical cuts that taper into the cliffs at both ends.
	for x = -136, 136, 8 do
		local taper = math.clamp((math.abs(x) - 100) / 36, 0, 1)
		t:FillBall(Vector3.new(x, 14, Grounds.RAVINE_Z + rng:NextNumber(-1.5, 1.5)), 26 - taper * 11, Enum.Material.Air)
	end
	local ravine = Region3.new(Vector3.new(-140, -16, Grounds.RAVINE_Z - 28), Vector3.new(140, -2, Grounds.RAVINE_Z + 28))
	t:ReplaceMaterial(ravine:ExpandToGrid(4), 4, Enum.Material.Ground, Enum.Material.Mud)
end

local function pave(parent: Instance, spec: { any }, rng: Random)
	local x0, x1, z0, z1, tile, dark = spec[1] :: number, spec[2] :: number, spec[3] :: number, spec[4] :: number, spec[5] :: number, spec[6] :: boolean
	local light, deep = if dark then P.FlagDark else P.Flag, if dark then P.StoneDark else P.FlagDark
	local cols, rows = math.max(1, math.round((x1 - x0) / tile)), math.max(1, math.round(math.abs(z1 - z0) / tile))
	local w, d = (x1 - x0) / cols, (z1 - z0) / rows
	for i = 0, cols - 1 do
		for j = 0, rows - 1 do
			-- A few stones are missing; the mud beneath is only 0.2 lower, so it never trips.
			if rng:NextNumber() > 0.05 then
				local shade = light:Lerp(deep, rng:NextNumber() ^ 1.6):Lerp(P.Moss, if rng:NextNumber() < 0.12 then 0.35 else 0)
				local material = if rng:NextNumber() < 0.3 then Enum.Material.Cobblestone else Enum.Material.Slate
				Kit.part(parent, "Flagstone", Vector3.new(math.abs(w) - 0.18, 1.4, math.abs(d) - 0.18),
					CFrame.new(x0 + (i + 0.5) * w, G - 0.7, z0 + (j + 0.5) * d) * CFrame.Angles(0, math.rad(rng:NextNumber(-0.6, 0.6)), 0),
					shade, material)
			end
		end
	end
end

-- A single-span stone bridge with ruined balustrades; the Cursed Swordsman guards its crown.
local function bridge(parent: Instance, rng: Random)
	local b = Grounds.BRIDGE
	local group = Kit.folder("RavineBridge", parent)
	local length = math.abs(b.Z1 - b.Z0)
	local mid = (b.Z0 + b.Z1) * 0.5
	for k = 0, 6 do
		local z = b.Z0 - (k + 0.5) * length / 7
		Kit.part(group, "Deck", Vector3.new(b.Half * 2, 1.6, length / 7 - 0.15), CFrame.new(0, G - 0.8, z),
			P.Flag:Lerp(P.StoneDark, rng:NextNumber(0, 0.5)), Enum.Material.Slate)
	end
	-- Arch ring under the deck, then piers down to the ravine floor.
	for k = 1, 9 do
		local a = math.rad(k * 18)
		local at = Vector3.new(0, -9 + math.sin(a) * 7, mid + math.cos(a) * 22)
		local tangent = Vector3.new(0, math.cos(a) * 7, -math.sin(a) * 22)
		Kit.part(group, "Voussoir", Vector3.new(b.Half * 2 - 1, 2.2, 5.4), CFrame.lookAt(at, at + tangent, Vector3.xAxis),
			P.StoneDark, Enum.Material.Cobblestone, Kit.decor())
	end
	for _, z in { b.Z0 - 6, b.Z1 + 6 } do
		Kit.part(group, "Pier", Vector3.new(b.Half * 2 - 2, 14, 6), CFrame.new(0, -8, z), P.StoneDark, Enum.Material.Cobblestone)
	end
	for side = -1, 1, 2 do
		for k = 0, math.floor(length / 4) do
			local z = b.Z0 - k * 4
			local broken = (side == -1 and z < -940 and z > -950) or (side == 1 and z < -972 and z > -982)
			if not broken then
				Kit.part(group, "Post", Vector3.new(0.9, 3.4, 0.9), CFrame.new(side * (b.Half - 0.45), G + 1.7, z), P.Stone, Enum.Material.Slate)
				if k < math.floor(length / 4) then
					Kit.part(group, "Rail", Vector3.new(0.6, 0.6, 4), CFrame.new(side * (b.Half - 0.45), G + 2.9, z - 2), P.StoneDark, Enum.Material.Slate)
				end
			elseif rng:NextNumber() < 0.6 then
				Kit.part(group, "FallenRail", Vector3.new(0.6, 0.6, 3.6), CFrame.new(side * (b.Half - 1.6), G + 0.3, z - 1) *
					CFrame.Angles(0, math.rad(rng:NextNumber(-30, 30)), 0), P.StoneDark, Enum.Material.Slate, Kit.decor())
			end
		end
	end
end

function Grounds.Build(parent: Instance, rng: Random)
	terrain(rng)
	local floor = Kit.folder("Flagstones", parent)
	for _, spec in Grounds.Paving do
		pave(floor, spec, rng)
	end
	bridge(parent, rng)
end

return Grounds
