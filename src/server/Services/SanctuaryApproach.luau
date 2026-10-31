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

local ServerStorage = game:GetService("ServerStorage")

-- Cloud Reliquary art (tools/blender/reliquary_kit.py): carved stone on floating karst. Each template's
-- pivot is its walkable top centre; the route box under it stays the (now invisible) walk surface.
local function reliquary(name: string): Model?
	local kit = ServerStorage:FindFirstChild("AsuraReliquaryKit")
	local piece = kit and kit:FindFirstChild(name)
	return if piece and piece:IsA("Model") then piece else nil
end

local function reliquaryPiece(box: any): string?
	if string.sub(box.Name, 1, 10) == "CloudShard" then return "Reliquary_Shard" end
	if box.Name == "ReliquaryIsle" then return "Reliquary_Isle" end
	return nil
end

-- The loggia lookout is a timber deck: its rail walls keep their collision under an open timber
-- railing (posts, top and mid rails, balusters) rather than reading as solid black panels.
local function timberRail(group: Instance, a: Vector3, b: Vector3)
	local length = (b - a).Magnitude
	local along = CFrame.lookAt(a, b)
	local function piece(name: string, size: Vector3, offset: Vector3)
		Lobby.slab(group, name, size, along * CFrame.new(offset), "Timber", Lobby.decor())
	end
	piece("LookoutTopRail", Vector3.new(0.34, 0.26, length + 0.3), Vector3.new(0, 2.35, -length / 2))
	piece("LookoutMidRail", Vector3.new(0.22, 0.18, length), Vector3.new(0, 1.15, -length / 2))
	local posts = math.max(1, math.round(length / 2.6))
	for i = 0, posts do
		piece("LookoutPost", Vector3.new(0.42, 2.5, 0.42), Vector3.new(0, 1.25, -length * i / posts))
	end
	local balusters = math.max(2, math.floor(length / 0.65))
	for i = 1, balusters - 1 do
		piece("LookoutBaluster", Vector3.new(0.14, 2.2, 0.14), Vector3.new(0, 1.15, -length * i / balusters))
	end
end

local function solid(group: Instance, box: any)
	local p = Decor.solid(group, box)
	if box.Name == "LookoutRail" and Lobby.available() then
		p.Transparency = 1
		local axis = p.CFrame.LookVector * box.SZ / 2
		local floor = Vector3.new(box.X, box.Y - box.SY / 2, box.Z)
		timberRail(group, floor - axis, floor + axis)
		return
	end
	local art = reliquaryPiece(box)
	if art and reliquary(art) then
		p.Transparency = 1
		return
	end
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

local function stoneLantern(parent: Instance, floor: CFrame)
	if not Lobby.place(parent, "Lantern_Stone", floor) then Lobby.lanternFallback(parent, floor, false) end
	Lobby.glow(parent, floor * CFrame.new(0, 3.35, 0), Vector3.new(1.04, 1.12, 1.04), 15, 1.35)
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
			stoneLantern(group, CFrame.new(side * 13.6, 600, z))
		end
	end
	-- Loggia lookout: brackets under the deck and a lantern on its rail.
	for _, x in { -79, -73 } do
		Kit.beam(group, "DeckBracket", Vector3.new(x, 611, 918), Vector3.new(x, 615, 926), 0.6, P.WoodDark, M.Wood)
	end
	Lobby.slab(group, "LookoutLanternMast", Vector3.new(0.4, 4.8, 0.4), CFrame.new(-71.6, 618.4, 927.4), "Timber", Lobby.decor())
	Lobby.slab(group, "LookoutLanternArm", Vector3.new(1.5, 0.22, 0.25), CFrame.new(-71.1, 620.7, 927.4), "Timber", Lobby.decor())
	Frame.hanging(group, Vector3.new(-70.6, 620.7, 927.4), 15)
	-- Reveal points: a stele and a bench on each dais, lanterns on the viewing wings.
	for _, key in { "RevealDaisW", "RevealDaisE" } do
		local m = Routes.Marks[key]
		local face = CFrame.lookAt(Vector3.new(m.X, m.Y, m.Z), Vector3.new(Routes.Marks.Figure.X, m.Y, Routes.Marks.Figure.Z))
		Kit.part(group, "PilgrimBench", Vector3.new(6, 1.2, 1.6), face * CFrame.new(0, 0.6, 3.6), P.WoodDark, M.Wood, Kit.decor())
		Kit.part(group, "PilgrimStele", Vector3.new(2.2, 5, 0.8), face * CFrame.new(-4.6, 2.5, 4.6), P.Stone, M.Slate, Kit.decor())
	end
	for _, key in { "RevealWingW", "RevealWingE" } do
		local m = Routes.Marks[key]
		stoneLantern(group, CFrame.new(m.X + (if m.X > 0 then 4.6 else -4.6), m.Y, m.Z + 8.6))
	end
	-- Cloud shards: carved stones on floating karst and a soft jade underglow so the optional jumps
	-- read at dusk. Shards alternate their turn; the isle turns its shrine to the far (east) end.
	for _, box in Routes.Solids do
		local art = reliquaryPiece(box)
		if art then
			local template = reliquary(art)
			if template then
				local top = CFrame.new(box.X, box.Y + box.SY / 2, box.Z)
				local piece = template:Clone()
				piece:PivotTo(top * CFrame.Angles(0, if art == "Reliquary_Isle" or box.Name == "CloudShard2" then math.pi else 0, 0))
				piece.Parent = group
			end
			local glow = Kit.hidden(group, "ShardGlow", Vector3.one, CFrame.new(box.X, box.Y - 2, box.Z))
			Kit.light(glow, JADE, 12, 0.7, false)
		end
	end
	-- The isle's arrival (west) corners take stone lanterns, a small crimson maple shades the shrine.
	for _, box in Routes.Solids do
		if box.Name == "ReliquaryIsle" and reliquary("Reliquary_Isle") then
			local y = box.Y + box.SY / 2
			for _, dz in { -6.4, 6.4 } do
				stoneLantern(group, CFrame.new(box.X - 4.4, y, box.Z + dz))
			end
			Lobby.place(group, "Tree_MapleSmall", CFrame.new(box.X + 3.2, y, box.Z - 5.6) * CFrame.Angles(0, math.rad(35), 0), 0.48)
			-- Shelter the small stone reliquary with the shrine's existing tiled/joined kit. Posts
			-- sit behind the central cache and off the west jump landing; all pieces are decoration.
			local roof = Lobby.place(group, "Roof_Square", CFrame.new(box.X + 4.4, y + 7, box.Z), Vector3.new(0.45, 0.3, 0.45))
			if roof then
				roof.Name = "CloudReliquaryRoof"
				for _, dx in { 3, 5.5 } do
					for _, dz in { -2.7, 2.7 } do
						local foot = CFrame.new(box.X + dx, y, box.Z + dz)
						Lobby.place(group, "Column_Base", foot, 0.45)
						Lobby.place(group, "Column_Lacquer", foot * CFrame.new(0, 0.4, 0), Vector3.new(0.45, 0.64, 0.45))
					end
				end
			end
		end
	end
	return group
end

return Approach
