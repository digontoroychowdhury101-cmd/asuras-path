--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/SanctuaryApproach
-- Builds the batch 16 player-scale routes (SanctuaryRoutes) into the existing shrine without touching
-- the imported colossus, the plaza or the gate: the pilgrim walk and the Well of Descent (the Sunken
-- Crypt portal itself is BossArenas'), the cloud shards and the Reliquary isle, the loggia's service
-- ledge and lookout rails, the viewing wings and pilgrim daises, and the terrace rim parapet. Decor
-- here marks the crypt leg plainly - a moon gate, a carved sign, lanterns down the walk - and keeps
-- the story exit (the northern gate) the only lit gate on the main axis.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath").Shared
local Routes = require(Shared.SanctuaryRoutes)
local Kit = require(script.Parent:WaitForChild("MonasteryKit") :: ModuleScript)
local Decor = require(script.Parent:WaitForChild("RegionDecor") :: ModuleScript)
local Lobby = require(script.Parent:WaitForChild("SanctuaryKit") :: ModuleScript)
local Rails = require(script.Parent:WaitForChild("SanctuaryRails") :: ModuleScript)
local Frame = require(script.Parent:WaitForChild("SanctuaryFrame") :: ModuleScript)

local Approach = {}
local P = Kit.Palette
local M = Enum.Material
local rgb = Color3.fromRGB
local JADE = rgb(111, 170, 164)
-- Lobby rebuild: route walls keep their collision under a carved kit balustrade; route floors take
-- the shrine's shared stone surfaces (the boxes themselves, and so the offline suites, are unchanged).
local RAILS = { WingRail = true, PavilionRail = true, PilgrimRail = true }
local COLUMNS = { WellColumn = true } -- collision for the Well pavilion's kit columns
local SURFACES = { ViewingWing = "Paving", PilgrimWalk = "PavingPath", DescentPavilion = "Paving", ServiceLedge = "Stone",
	ReliquaryIsle = "Stone", PilgrimDais = "Stone", TerraceParapet = "StoneDark" }

local function solid(group: Instance, box: any)
	local p = Decor.solid(group, box)
	if RAILS[box.Name] and Lobby.available() then
		p.Transparency = 1
		local axis = p.CFrame.LookVector * box.SZ / 2
		local floor = Vector3.new(box.X, box.Y - box.SY / 2, box.Z)
		Rails.run(group, floor - axis, floor + axis, true, false)
		return
	end
	if COLUMNS[box.Name] and Lobby.available() then
		p.Transparency = 1
		return
	end
	local key = SURFACES[box.Name] or (if string.sub(box.Name, 1, 10) == "CloudShard" then "Stone" else nil)
	if key then
		local surface = Lobby.Surface[key]
		p.Material, p.Color, p.MaterialVariant = surface.Material, surface.Color, surface.Variant
	end
end

local function sign(parent: Instance, text: string, cf: CFrame)
	local board = Kit.part(parent, "WaySign", Vector3.new(6, 1.6, 0.3), cf, P.WoodDark, M.Wood, Kit.decor())
	local gui = Instance.new("SurfaceGui")
	gui.Face, gui.LightInfluence, gui.PixelsPerStud = Enum.NormalId.Front, 0.3, 40
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency, label.Text = UDim2.fromScale(1, 1), 1, text
	label.Font, label.TextScaled, label.TextColor3 = Enum.Font.Antique, true, rgb(226, 206, 160)
	label.Parent = gui
end

function Approach.Build(parent: Instance): Folder
	local group = Kit.folder("PilgrimRoutes", parent)
	for _, box in Routes.Solids do
		solid(group, box)
	end
	local d = Routes.Marks.CryptDescent
	-- A pyramidal pavilion over the Well; corner columns only, clear of the moon gate and the shard gap.
	Frame.pavilion(group, CFrame.new(d.X, d.Y, d.Z - 8), 20, 18, 10, { Square = true, Xs = { -10, 10 }, Rise = 0.8, Lanterns = false, Collide = false })
	-- Well of Descent: a moon gate around the portal, a sunken well below it glowing jade.
	for k = 0, 16 do
		local a = math.rad(k * 22.5)
		local p = Vector3.new(d.X + math.cos(a) * 7.5, d.Y + 6 + math.sin(a) * 7.5, d.Z + 1.4)
		if p.Y > d.Y + 0.5 then
			Kit.part(group, "MoonGate", Vector3.new(3.2, 1.6, 1.6), CFrame.new(p) * CFrame.Angles(0, 0, a + math.pi / 2), P.Stone, M.Slate, Kit.decor())
		end
	end
	local well = Kit.part(group, "WellGlow", Vector3.new(10, 0.2, 4), CFrame.new(d.X, d.Y + 0.12, d.Z + 4), JADE, M.Glass,
		{ Collide = false, Query = false, Shadow = false, Transparency = 0.35 })
	Kit.light(well, JADE, 22, 1.1, false)
	sign(group, "THE SUNKEN CRYPT  ·  OPTIONAL", CFrame.new(d.X, d.Y + 14.6, d.Z + 1.4))
	sign(group, "WELL OF DESCENT", CFrame.new(0, d.Y + 9, 972.4)) -- hung over the pavilion's entrance, facing the plaza
	for z = 952, 968, 8 do
		for _, side in { -1, 1 } do
			Decor.lantern(group, side * 6.4, 602.6, z, 14)
		end
	end
	-- Loggia lookout: brackets under the deck and a lantern on its rail.
	for _, x in { -79, -73 } do
		Kit.beam(group, "DeckBracket", Vector3.new(x, 611, 918), Vector3.new(x, 615, 926), 0.6, P.WoodDark, M.Wood)
	end
	Decor.lantern(group, -71.6, 619.4, 927.4, 16)
	-- Reveal points: a stele and a bench on each dais, lanterns on the viewing wings.
	for _, key in { "RevealDaisW", "RevealDaisE" } do
		local m = Routes.Marks[key]
		local face = CFrame.lookAt(Vector3.new(m.X, m.Y, m.Z), Vector3.new(Routes.Marks.Figure.X, m.Y, Routes.Marks.Figure.Z))
		Kit.part(group, "PilgrimBench", Vector3.new(6, 1.2, 1.6), face * CFrame.new(0, 0.6, 3.6), P.WoodDark, M.Wood, Kit.decor())
		Kit.part(group, "PilgrimStele", Vector3.new(2.2, 5, 0.8), face * CFrame.new(-4.6, 2.5, 4.6), P.Stone, M.Slate, Kit.decor())
	end
	for _, key in { "RevealWingW", "RevealWingE" } do
		local m = Routes.Marks[key]
		Decor.lantern(group, m.X + (if m.X > 0 then 4.6 else -4.6), m.Y + 3.4, m.Z + 8.6, 16)
	end
	-- Cloud shards: a soft jade underglow so the optional jumps read at dusk.
	for _, box in Routes.Solids do
		if string.sub(box.Name, 1, 10) == "CloudShard" or box.Name == "ReliquaryIsle" then
			local glow = Kit.hidden(group, "ShardGlow", Vector3.one, CFrame.new(box.X, box.Y - 2, box.Z))
			Kit.light(glow, JADE, 12, 0.7, false)
		end
	end
	return group
end

return Approach
