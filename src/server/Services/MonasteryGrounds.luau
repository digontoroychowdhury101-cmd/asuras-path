--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/MonasteryGrounds
-- The ground of the Desecrated Monastery: laid flagstone courtyards over the MonasteryTerrain valley
-- (mud, moss, cliffs of dark rock and a misted ravine), and the stone bridge across the ravine.
-- Every walkable top sits at Kit.GROUND so WorldDefinitions placements (Y = 3) drop onto stone.
local Kit = require(script.Parent:WaitForChild("MonasteryKit") :: ModuleScript)
local Terrain = require(script.Parent:WaitForChild("MonasteryTerrain") :: ModuleScript)

local Grounds = {}

local P = Kit.Palette
local G = Kit.GROUND

Grounds.RAVINE_Z = Terrain.RAVINE_Z
Grounds.BRIDGE = { Z0 = -932, Z1 = -988, Half = 10 }
Grounds.VALLEY_HALF, Grounds.PLATEAU, Grounds.EAST_PASS = Terrain.VALLEY_HALF, Terrain.PLATEAU, Terrain.EAST_PASS

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

-- A stone beam bridge with ruined balustrades; the Cursed Swordsman guards its crown.
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
	-- Batch 15 (#32): a wuxia granite beam bridge. Three stringers rest on two trestle piers with
	-- boat-prow cutwaters facing up and down the ravine, in place of the semicircular voussoir ring
	-- on square piers that read as a Roman aqueduct. Everything sits under the deck surface.
	for _, x in { -6.5, 0, 6.5 } do
		Kit.part(group, "Stringer", Vector3.new(2.4, 1.6, length + 6), CFrame.new(x, G - 2.4, mid), P.StoneDark, Enum.Material.Slate, Kit.decor())
	end
	for _, z in { mid + 14, mid - 14 } do
		Kit.part(group, "PierCap", Vector3.new(b.Half * 2 + 1, 1.2, 5.4), CFrame.new(0, G - 3.8, z), P.Stone:Lerp(P.StoneDark, 0.4), Enum.Material.Slate)
		Kit.part(group, "Trestle", Vector3.new(b.Half * 2 - 3, 12, 4), CFrame.new(0, G - 10.4, z), P.StoneDark:Lerp(P.Moss, 0.15), Enum.Material.Slate)
		for side = -1, 1, 2 do -- the prow: a square column turned 45 degrees at each end of the pier
			Kit.part(group, "Cutwater", Vector3.new(2.8, 12, 2.8), CFrame.new(side * (b.Half - 1.5), G - 10.4, z) * CFrame.Angles(0, math.rad(45), 0),
				P.StoneDark, Enum.Material.Slate)
		end
	end
	for side = -1, 1, 2 do
		for k = 0, math.floor(length / 4) do
			local z = b.Z0 - k * 4
			local broken = (side == -1 and z < -940 and z > -950) or (side == 1 and z < -972 and z > -982)
			if not broken then
				Kit.part(group, "Post", Vector3.new(0.9, 3.4, 0.9), CFrame.new(side * (b.Half - 0.45), G + 1.7, z), P.Stone, Enum.Material.Slate)
				Kit.part(group, "LotusCap", Vector3.new(1.15, 1.15, 1.15), CFrame.new(side * (b.Half - 0.45), G + 3.75, z), P.Stone:Lerp(P.Moss, 0.2), Enum.Material.Slate,
					{ Shape = Enum.PartType.Ball, Collide = false, Query = false })
				if k < math.floor(length / 4) then
					Kit.part(group, "Rail", Vector3.new(0.6, 0.6, 4), CFrame.new(side * (b.Half - 0.45), G + 2.9, z - 2), P.StoneDark, Enum.Material.Slate)
				end
			else
				-- Post-F26 Step 5: the broken bays still stop bodies. Studio: a deflect-recoiled swordsman
				-- left the deck through the west gap and stood under the bridge in Engage, out of reach.
				Kit.part(group, "RailGap", Vector3.new(0.6, 4, 4), CFrame.new(side * (b.Half - 0.45), G + 2, z - 2), P.StoneDark, Enum.Material.Slate,
					{ Transparency = 1, Query = false, Shadow = false })
				if rng:NextNumber() < 0.6 then
					Kit.part(group, "FallenRail", Vector3.new(0.6, 0.6, 3.6), CFrame.new(side * (b.Half - 1.6), G + 0.3, z - 1) *
						CFrame.Angles(0, math.rad(rng:NextNumber(-30, 30)), 0), P.StoneDark, Enum.Material.Slate, Kit.decor())
				end
			end
		end
	end
end

Grounds.Extent, Grounds.Clear = Terrain.Extent, Terrain.Clear

function Grounds.Build(parent: Instance, rng: Random)
	Terrain.Build(rng)
	local floor = Kit.folder("Flagstones", parent)
	for _, spec in Grounds.Paving do
		pave(floor, spec, rng)
	end
	bridge(parent, rng)
end

return Grounds
