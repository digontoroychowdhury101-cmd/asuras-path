--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/OverworldService
-- Ticket 03 + 02. While Overworld.Active, raises Workspace.Map_Overworld: one folder per region (each carries
-- AsuraRegion), greybox blockout from Overworld.Blockout and Overworld.Landmarks, and the return gate at the
-- gateway glade. The Terrain itself is written in the background by OverworldTerrain, glade tiles first, then
-- route order; Ready("Glade" | "All" | regionId) says what has been written and WaitReady blocks (bounded).
-- Start() must run before WorldService.Start(): Map_Overworld suppresses the overworld regions' greybox floors
-- and WorldService marks its geometry. Inactive, Start does nothing and Ready is always true.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("AsurasPath")
local Overworld = require(Shared.Shared.Overworld) :: any
local World = require(Shared.Shared.WorldDefinitions) :: any
local InputMap = require(Shared.Shared.InputMap) :: any
local Characters = require(script.Parent:WaitForChild("CharacterService") :: ModuleScript) :: any
local Terrain = require(script.Parent:WaitForChild("OverworldTerrain") :: ModuleScript) :: any
local Landmarks = require(script.Parent:WaitForChild("LandmarkWorld") :: ModuleScript)

local OverworldService = {}

local FADE = 0.5
local COOLDOWN = 4
local GLADE_RADIUS = 640 -- tile centres this close to the gateway altar are written first and gate Ready("Glade")
local GUARD_PERIOD = 0.2 -- seconds between checks that every player stands on written ground (sprint 33.6 st/s = 7 studs)
local LEAD = 3 -- seconds of travel the generator writes ahead of each player
local SHELTER_TAG = "AsuraShelter"
local LANDMARK_TAG = "OverworldLandmark"

local STONE = Color3.fromRGB(112, 108, 100)
local DARK = Color3.fromRGB(62, 58, 56)
local WOOD = Color3.fromRGB(94, 68, 46)
local ROOF = Color3.fromRGB(72, 54, 46)
local BRONZE = Color3.fromRGB(150, 112, 58)
local EMBER = Color3.fromRGB(255, 150, 70)
local SEAL = Color3.fromRGB(150, 210, 255)

local running = false
local root: Folder? = nil
local folders: { [string]: Folder } = {}
local connections: { RBXScriptConnection } = {}
local transit: { [number]: number } = {}
local startedAt = 0
local failed: string? = nil
local total = 0
local done = 0
local regionTotal: { [string]: number } = {}
local regionDone: { [string]: number } = {}
local gladeTotal = 0
local gladeDone = 0
local gladeKeys: { [string]: boolean } = {}
local gladeSeconds: number? = nil
local siteLeft: { [string]: number } = {} -- arrival point (altar id or barrier node) -> tiles still unwritten
local tileSites: { [string]: { string } } = {}
local sitesLeft = 0
local sitesSeconds: number? = nil
local allSeconds: number? = nil
local rescues = 0

-------------------------------------------------------------------------------------------------
-- Geometry helpers
-------------------------------------------------------------------------------------------------

local function ground(x: number, z: number): number
	return Overworld.heightAt(x, z)
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Slate
	p.CanCollide = collide ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A box standing on the ground at (x, z): base sunk 3 studs, height h, yaw in degrees.
local function stand(parent: Instance, name: string, x: number, z: number, w: number, h: number, d: number, yaw: number, color: Color3, material: Enum.Material?, lift: number?): Part
	local y = ground(x, z) - 3 + (lift or 0)
	return part(parent, name, Vector3.new(w, h, d), CFrame.new(x, y + h / 2, z) * CFrame.Angles(0, math.rad(yaw), 0), color, material)
end

local function vec(p: any): Vector3
	return Vector3.new(p.X, p.Y, p.Z)
end

local function nodePosition(id: string): Vector3
	return vec(Overworld.Nodes[id].Position)
end

-- Local offset (lx, lz) of a yawed frame at (x, z) to world XZ.
local function rotate(x: number, z: number, yaw: number, lx: number, lz: number): (number, number)
	local c, s = math.cos(math.rad(yaw)), math.sin(math.rad(yaw))
	return x + lx * c + lz * s, z - lx * s + lz * c
end

-- A slab whose top surface runs from a to b (used by ramps, decks).
local function span(parent: Instance, name: string, a: Vector3, b: Vector3, width: number, thick: number, color: Color3, material: Enum.Material?): Part
	local mid = (a + b) / 2 - Vector3.new(0, thick / 2, 0)
	return part(parent, name, Vector3.new(width, thick, (b - a).Magnitude), CFrame.lookAt(mid, mid + (b - a)), color, material)
end

-- Two rails along a to b at +-width/2.
local function rails(parent: Instance, name: string, a: Vector3, b: Vector3, width: number, height: number, collide: boolean)
	local dir = (b - a).Unit
	local side = dir:Cross(Vector3.yAxis).Unit * (width / 2)
	for k, sign in { -1, 1 } do
		local ra, rb = a + side * sign + Vector3.new(0, height / 2, 0), b + side * sign + Vector3.new(0, height / 2, 0)
		local p = part(parent, name .. k, Vector3.new(0.6, height, (rb - ra).Magnitude), CFrame.lookAt((ra + rb) / 2, rb), WOOD, Enum.Material.Wood, collide)
		p.CanCollide = collide
	end
end

-------------------------------------------------------------------------------------------------
-- Landmark silhouettes (Persistent models; simple massing)
-------------------------------------------------------------------------------------------------

local landmarkBuilders: { [string]: (Model, number, number, number) -> () } = {
	BrokenBellTower = function(m, x, z, h)
		stand(m, "Shaft", x, z, 16, h * 0.78, 16, 0, STONE)
		local top = ground(x, z) - 3 + h * 0.78
		part(m, "BrokenA", Vector3.new(16, 10, 8), CFrame.new(x - 4, top + 5, z) * CFrame.Angles(0, 0, math.rad(8)), STONE)
		part(m, "BrokenB", Vector3.new(7, 14, 16), CFrame.new(x + 4.5, top + 7, z) * CFrame.Angles(0, 0, math.rad(-6)), STONE)
		part(m, "BellFrame", Vector3.new(22, 2, 3), CFrame.new(x, top - 12, z), WOOD, Enum.Material.Wood)
		local bell = part(m, "Bell", Vector3.new(10, 9, 9), CFrame.new(x, top - 18, z) * CFrame.Angles(0, 0, math.rad(90)), BRONZE, Enum.Material.Metal)
		bell.Shape = Enum.PartType.Cylinder
	end,
	FarSideAqueduct = function(m, x, z, h)
		for k = -3, 3 do
			stand(m, "Pier" .. k, x + k * 26, z, 6, h, 8, 0, STONE)
		end
		local top = ground(x, z) - 3 + h
		part(m, "Channel", Vector3.new(190, 5, 10), CFrame.new(x, top + 2.5, z), STONE)
		part(m, "WallN", Vector3.new(190, 4, 1.5), CFrame.new(x, top + 7, z - 4.5), STONE)
		part(m, "WallS", Vector3.new(190, 4, 1.5), CFrame.new(x, top + 7, z + 4.5), STONE)
	end,
	GateStatue = function(m, x, z, h)
		stand(m, "LegL", x - 22, z, 26, h * 0.5, 26, 0, STONE)
		stand(m, "LegR", x + 22, z, 26, h * 0.5, 26, 0, STONE)
		local y = ground(x, z) - 3 + h * 0.5
		part(m, "Hips", Vector3.new(74, h * 0.14, 34), CFrame.new(x, y + h * 0.07, z), STONE)
		part(m, "Torso", Vector3.new(56, h * 0.36, 30), CFrame.new(x, y + h * 0.14 + h * 0.18, z) * CFrame.Angles(0, 0, math.rad(4)), STONE)
		part(m, "ArmStump", Vector3.new(14, h * 0.3, 14), CFrame.new(x + 36, y + h * 0.3, z) * CFrame.Angles(0, 0, math.rad(-12)), STONE)
		stand(m, "FallenHead", x + 20, z + 52, 26, 26, 28, 20, STONE, nil, 3)
	end,
	WatchBeacon = function(m, x, z, h)
		stand(m, "Tower", x, z, 18, h * 0.8, 18, 0, STONE, Enum.Material.Concrete)
		local top = ground(x, z) - 3 + h * 0.8
		part(m, "Platform", Vector3.new(28, 3, 28), CFrame.new(x, top + 1.5, z), DARK)
		local fire = part(m, "Brazier", Vector3.new(8, 8, 8), CFrame.new(x, top + 7, z), EMBER, Enum.Material.Neon, false)
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness = EMBER, 80, 2
		light.Parent = fire
	end,
	ThousandSteps = function(m, x, z, h)
		for i = 0, 5 do
			stand(m, "Tier" .. i, x, z, 70 - 10 * i, h / 6, 70 - 10 * i, 0, STONE, nil, i * (h / 6))
		end
	end,
	SummitTemple = function(m, x, z, h)
		local roofY = 1623
		for k = 0, 4 do
			for _, sx in { -34, 34 } do
				local cz = z + 40 - k * 20
				local g = ground(x + sx, cz) - 2
				part(m, "Column", Vector3.new(5, math.max(roofY - g, 8), 5), CFrame.new(x + sx, g + math.max(roofY - g, 8) / 2, cz), STONE, Enum.Material.Marble)
			end
		end
		part(m, "RoofA", Vector3.new(92, 3, 100), CFrame.new(x, roofY + 1.5, z), ROOF)
		part(m, "RoofB", Vector3.new(70, 3, 80), CFrame.new(x, roofY + 17, z), ROOF)
		part(m, "RoofC", Vector3.new(48, 3, 60), CFrame.new(x, roofY + 32, z), ROOF)
		part(m, "Finial", Vector3.new(6, 34, 6), CFrame.new(x, roofY + 51, z), BRONZE, Enum.Material.Metal)
		for i, y in { roofY + 8, roofY + 24 } do
			part(m, "Core" .. i, Vector3.new(34 - 10 * i, 14, 40 - 10 * i), CFrame.new(x, y, z), DARK, nil, false)
		end
	end,
}

-- The Thousand Steps node sits on the road: the 70-stud stepped silhouette stands 150 studs aside (clear of every road).
local LANDMARK_SHIFT: { [string]: { number } } = { ThousandSteps = { 150, 55 } }

local function buildLandmarks()
	for id, def in Overworld.Landmarks do
		local build = landmarkBuilders[id]
		if build then
			local model = Instance.new("Model")
			model.Name = id
			model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
			model:SetAttribute("AsuraRegion", def.Region)
			local shift = LANDMARK_SHIFT[id] or { 0, 0 }
			build(model, def.Position.X + shift[1], def.Position.Z + shift[2], def.Height)
			CollectionService:AddTag(model, LANDMARK_TAG)
			model.Parent = folders[def.Region]
			-- Far silhouette: a few big boxes that still draw at low quality; LandscapeBudget shows it beyond FarBeyond only.
			if def.Silhouette then
				local far = Instance.new("Model")
				far.Name = id .. "_Far"
				far.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
				far:SetAttribute("AsuraRegion", def.Region)
				far:SetAttribute("FarBeyond", def.FarBeyond)
				local x, z = def.Position.X + shift[1], def.Position.Z + shift[2]
				local base = ground(x, z) - 3
				for i, b in def.Silhouette do
					local p = part(far, "Far" .. i, Vector3.new(b[4], b[5], b[6]), CFrame.new(x + b[1], base + b[2], z + b[3]), STONE, nil, false)
					p.CastShadow, p.CanQuery, p.CanTouch = false, false, false
				end
				CollectionService:AddTag(far, LANDMARK_TAG .. "Far")
				far.Parent = folders[def.Region]
			end
		else
			warn("[Overworld] no silhouette for landmark " .. id)
		end
	end
end

-------------------------------------------------------------------------------------------------
-- Structures
-------------------------------------------------------------------------------------------------

-- Stone viaduct (art direction d): one collidable deck slab from A to B (ends on the written surface), stone
-- parapets on both sides, tapering piers seated on the chasm floor and walls, a segmental arch of voussoirs plus
-- spandrel fill in every bay, and abutment blocks at both rims. Parts only; part count is reported by the test.
local DECK_THICK = 4
local PIER_TOP = 10 -- pier length along the deck at the springline
local FACE = 26 -- abutment mass runs from the rim to this far along the deck: it reaches onto the chasm wall
local ARCH_RING = 3
local VOUSSOIRS = 8

local function stoneBridge(def: any, parent: Instance)
	local model = Instance.new("Model")
	model.Name = def.Id
	local a, b = vec(def.A), vec(def.B)
	local aY, bY = (Overworld.surfaceAt(a.X, a.Z)), (Overworld.surfaceAt(b.X, b.Z))
	a, b = Vector3.new(a.X, aY + 1, a.Z), Vector3.new(b.X, bY + 1, b.Z)
	local w = def.Width
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local hlen, h = flat.Magnitude, flat.Unit
	local function deckY(u: number): number
		return a.Y + (b.Y - a.Y) * u / hlen
	end
	local function at(u: number, y: number): Vector3
		return Vector3.new(a.X + h.X * u, y, a.Z + h.Z * u)
	end
	local across = h:Cross(Vector3.yAxis).Unit
	local function box(name: string, u: number, y: number, sx: number, sy: number, sz: number, material: Enum.Material, tilt: number?): Part
		local p = at(u, y)
		return part(model, name, Vector3.new(sx, sy, sz), CFrame.lookAt(p, p + h) * CFrame.Angles(tilt or 0, 0, 0), STONE, material)
	end

	span(model, "Deck", a, b, w, DECK_THICK, STONE, Enum.Material.Slate)
	local mid = (a + b) / 2
	for _, sign in { -1, 1 } do
		local m = mid + across * ((w / 2 - 0.8) * sign) + Vector3.new(0, 1.75, 0)
		part(model, if sign < 0 then "ParapetL" else "ParapetR", Vector3.new(1.6, 3.5, (b - a).Magnitude), CFrame.lookAt(m, m + (b - a)), STONE, Enum.Material.Cobblestone)
	end

	-- lowest written ground under a footprint (u0..u1 along, half-width across)
	local function floorUnder(u0: number, u1: number, half: number): number
		local low = math.huge
		for i = 0, 2 do
			for _, c in { -half, 0, half } do
				local p = at(u0 + (u1 - u0) * i / 2, 0) + across * c
				low = math.min(low, ground(p.X, p.Z))
			end
		end
		return low
	end

	local bays = math.max(2, math.floor((hlen - 2 * FACE) / 58 + 0.5))
	local L = (hlen - 2 * FACE) / bays
	for k = 0, bays do
		local u = FACE + k * L
		for _, sign in { -1, 1 } do
			local p = at(u, deckY(u) + 2.5) + across * ((w / 2 - 0.8) * sign)
			part(model, "Pilaster", Vector3.new(2.4, 6, 2.4), CFrame.lookAt(p, p + h), STONE, Enum.Material.Cobblestone)
		end
		local top = deckY(u) - DECK_THICK
		if k > 0 and k < bays then
			local base = floorUnder(u - 11, u + 11, w / 2 + 3) - 4
			local H = top - base
			if H > 6 then
				local tiers = math.clamp(math.ceil(H / 60), 1, 8)
				for j = 0, tiers - 1 do
					local f = (j + 0.5) / tiers
					box("Pier", u, base + H * (j + 0.5) / tiers, w + 6 - 6 * f, H / tiers, 22 - (22 - PIER_TOP) * f, Enum.Material.Slate)
				end
			end
		end
	end
	-- abutments seated on the rims and walls at both ends
	for _, e in { { -10, FACE }, { hlen - FACE, hlen + 10 } } do
		local base = floorUnder(e[1], e[2], w / 2 + 1) - 4
		local top = deckY((e[1] + e[2]) / 2) - DECK_THICK
		if top - base > 2 then
			box("Abutment", (e[1] + e[2]) / 2, (base + top) / 2, w + 2, top - base, e[2] - e[1], Enum.Material.Slate)
		end
	end
	-- arches
	for i = 0, bays - 1 do
		local u0 = FACE + i * L + (if i == 0 then 0 else PIER_TOP / 2)
		local u1 = FACE + (i + 1) * L - (if i == bays - 1 then 0 else PIER_TOP / 2)
		local C, um = u1 - u0, (u0 + u1) / 2
		local rise = C * 0.2
		local R = (C * C / 4 + rise * rise) / (2 * rise)
		local yc = deckY(um) - DECK_THICK - 2.5 - ARCH_RING - R
		local a0 = math.asin((C / 2) / R)
		local da = 2 * a0 / VOUSSOIRS
		local Rm = R + ARCH_RING / 2
		for m = 0, VOUSSOIRS - 1 do
			local al = -a0 + (m + 0.5) * da
			box("Voussoir", um + Rm * math.sin(al), yc + Rm * math.cos(al), w, ARCH_RING, 2 * Rm * math.sin(da / 2) + 0.5, Enum.Material.Cobblestone, -al)
			local uc = u0 + (m + 0.5) * C / VOUSSOIRS
			local bottom = yc + math.sqrt(math.max((R + ARCH_RING) ^ 2 - (uc - um) ^ 2, 0)) - 1
			local topY = deckY(uc) - DECK_THICK + 0.5
			if topY - bottom > 0.3 then
				box("Spandrel", uc, (bottom + topY) / 2, w, topY - bottom, C / VOUSSOIRS + 0.2, Enum.Material.Cobblestone)
			end
		end
	end
	model.Parent = parent
end

local function ropeBridge(def: any, parent: Instance)
	local model = Instance.new("Model")
	model.Name = def.Id
	local a, b = vec(def.A), vec(def.B)
	span(model, "Planks", a, b, def.Width, 0.6, WOOD, Enum.Material.Wood)
	rails(model, "Rope", a + Vector3.new(0, 2.4, 0), b + Vector3.new(0, 2.4, 0), def.Width, 0.4, false)
	-- posts stand beside the deck ends, never on its axis
	local side = (b - a).Unit:Cross(Vector3.yAxis).Unit * (def.Width / 2 + 1.5)
	for k, p in { a, b } do
		for sign = -1, 1, 2 do
			local q = p + side * sign
			part(model, "Post" .. k, Vector3.new(2, 8, 2), CFrame.new(q.X, q.Y + 3, q.Z), WOOD, Enum.Material.Wood)
		end
	end
	model.Parent = parent
end

local function ramp(def: any, parent: Instance)
	local model = Instance.new("Model")
	model.Name = def.Id
	local a, b = vec(def.A), vec(def.B)
	span(model, "Slab", a, b, def.Width, 1.2, STONE)
	rails(model, "Rail", a, b, def.Width, 3, false)
	model.Parent = parent
end

local function shelter(def: any, parent: Instance)
	local model = Instance.new("Model")
	model.Name = def.Id
	local w, d = def.W, def.D
	local gmin, gmax = math.huge, -math.huge
	for _, lx in { -w / 2, 0, w / 2 } do
		for _, lz in { -d / 2, 0, d / 2 } do
			local px, pz = rotate(def.X, def.Z, def.Yaw, lx, lz)
			local g = ground(px, pz)
			gmin, gmax = math.min(gmin, g), math.max(gmax, g)
		end
	end
	local base = CFrame.new(def.X, 0, def.Z) * CFrame.Angles(0, math.rad(def.Yaw), 0)
	local roofY = gmax + 9
	local posts = math.max(2, math.ceil(w / 16) + 1)
	for k = 0, posts - 1 do
		local lx = -w / 2 + w * k / (posts - 1)
		for _, lz in { -d / 2, d / 2 } do
			local px, pz = rotate(def.X, def.Z, def.Yaw, lx, lz)
			local g = ground(px, pz) - 2
			part(model, "Post", Vector3.new(1.4, roofY - g, 1.4), base * CFrame.new(lx, 0, lz) + Vector3.new(0, g + (roofY - g) / 2, 0), WOOD, Enum.Material.Wood)
		end
	end
	local roof = part(model, "Roof", Vector3.new(w + 3, 1, d + 3), base + Vector3.new(0, roofY + 0.5, 0), ROOF, Enum.Material.Wood)
	roof:SetAttribute("Shelter", def.Id)
	CollectionService:AddTag(roof, SHELTER_TAG)
	-- back wall on the +Z side
	part(model, "BackWall", Vector3.new(w, roofY - gmin + 2, 1), base * CFrame.new(0, 0, d / 2) + Vector3.new(0, gmin - 2 + (roofY - gmin + 2) / 2, 0), STONE)
	model:SetAttribute("Shelter", def.Id)
	model.Parent = parent
end

local function portal(def: any, parent: Instance)
	local model = Instance.new("Model")
	model.Name = def.Id
	local y = ground(def.X, def.Z)
	local target = nodePosition(def.Faces)
	local cf = CFrame.lookAt(Vector3.new(def.X, y, def.Z), Vector3.new(target.X, y, target.Z))
	for _, sx in { -9, 9 } do
		part(model, "Jamb", Vector3.new(5, 18, 6), cf * CFrame.new(sx, 6, 0), DARK, Enum.Material.Basalt)
	end
	local lintel = part(model, "Lintel", Vector3.new(24, 5, 7), cf * CFrame.new(0, 17.5, 0), DARK, Enum.Material.Basalt)
	CollectionService:AddTag(lintel, SHELTER_TAG) -- cave-mouth ceiling: WeatherController treats it as cover
	part(model, "Dark", Vector3.new(14, 16, 2), cf * CFrame.new(0, 6, 6), Color3.fromRGB(12, 12, 14), Enum.Material.Slate)
	model.Parent = parent
end

-------------------------------------------------------------------------------------------------
-- Transit (return gate, lifts): same cinematic fade and cue as the Sanctuary portal
-------------------------------------------------------------------------------------------------

local function carry(player: Player, destination: CFrame, toId: string, toName: string)
	local userId = player.UserId
	local clock = os.clock()
	if (transit[userId] or 0) > clock then
		return
	end
	local e = Characters.GetEntity(userId)
	if not e or e.Fighter.State == "KO" or e.Respawning or Characters.IsInDuel(userId) then
		return
	end
	transit[userId] = clock + COOLDOWN
	Characters.Cinematic(userId, FADE * 2)
	Characters.Cue("PortalTransit", userId, { to = toId, name = toName, fade = FADE })
	task.delay(FADE, function()
		local current = Characters.GetEntity(userId)
		if running and current and current.Fighter.State ~= "KO" and not Characters.IsInDuel(userId) then
			Characters.Teleport(userId, destination)
		end
	end)
end

local function prompt(parent: Instance, action: string, object: string, hold: number, radius: number, onTrigger: (Player) -> ()): ProximityPrompt
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText, pp.ObjectText, pp.HoldDuration = action, object, hold
	pp.MaxActivationDistance = radius
	pp.RequiresLineOfSight = false
	InputMap.applyPrompt(pp)
	pp.Parent = parent
	table.insert(connections, pp.Triggered:Connect(onTrigger))
	return pp
end

local function returnGate(def: any, parent: Instance)
	local model = Instance.new("Model")
	model.Name = def.Id
	local y = ground(def.X, def.Z)
	local target = nodePosition(def.Faces)
	local cf = CFrame.lookAt(Vector3.new(def.X, y, def.Z), Vector3.new(target.X, y, target.Z))
	for _, sx in { -8, 8 } do
		part(model, "Pillar", Vector3.new(4, 18, 4), cf * CFrame.new(sx, 8, 0), STONE, Enum.Material.Marble)
	end
	part(model, "Lintel", Vector3.new(22, 3, 5), cf * CFrame.new(0, 17.5, 0), STONE, Enum.Material.Marble)
	local seal = part(model, "Seal", Vector3.new(14, 15, 0.6), cf * CFrame.new(0, 8, 0), SEAL, Enum.Material.Neon, false)
	seal.Transparency = 0.45
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = SEAL, 30, 1.5
	light.Parent = seal
	local home = World.startingAltar()
	local destination = CFrame.new(home.Spawn.X, home.Spawn.Y, home.Spawn.Z) * CFrame.Angles(0, math.rad(home.Spawn.Yaw), 0)
	prompt(seal, "Return to the Shrine", "Return Gate", 0.8, 14, function(player: Player)
		carry(player, destination, home.Id, home.Name)
	end)
	model:SetAttribute("Destination", home.Id)
	model.Parent = parent
end

local function lift(def: any, parent: Instance)
	local model = Instance.new("Model")
	model.Name = def.Id
	local stations: { CFrame } = {}
	local ends = { def.A, def.B }
	for k, p in ends do
		local other = ends[3 - k]
		local y = ground(p.X, p.Z)
		local here = Vector3.new(p.X, y, p.Z)
		local look = CFrame.lookAt(here, Vector3.new(other.X, y, other.Z))
		stations[k] = look
		part(model, "Platform" .. k, Vector3.new(12, 1, 12), look * CFrame.new(0, 0.5, 0), STONE)
		for _, sx in { -5, 5 } do
			part(model, "Post" .. k, Vector3.new(1.2, 12, 1.2), look * CFrame.new(sx, 6.5, -5), WOOD, Enum.Material.Wood, false)
		end
		part(model, "Beam" .. k, Vector3.new(12, 1, 1.2), look * CFrame.new(0, 12.5, -5), WOOD, Enum.Material.Wood, false)
		local anchor = part(model, "Anchor" .. k, Vector3.new(4, 4, 4), look * CFrame.new(0, 3, 0), BRONZE, nil, false)
		anchor.Transparency = 1
		model:SetAttribute("Station" .. k, here)
	end
	for k = 1, 2 do
		local from, to = model:FindFirstChild("Anchor" .. k) :: BasePart, stations[3 - k]
		prompt(from, "Ride the " .. def.Id, "Lift", 0.8, 14, function(player: Player)
			carry(player, to * CFrame.new(0, 4, 0), def.Id, def.Id)
		end)
	end
	model.Parent = parent
end

-------------------------------------------------------------------------------------------------
-- Terrain scheduling and readiness
-------------------------------------------------------------------------------------------------

-- Players inside the Frame, each as where they stand and where they will be LEAD seconds on (sprint, glide), so the
-- ground is written ahead of them.
local function focus(): { { number } }
	local F = Overworld.Frame
	local points: { { number } } = {}
	for _, player in Players:GetPlayers() do
		local e = Characters.GetEntity(player.UserId)
		local p = if e then e.Root.Position else nil
		if e and p and p.X >= F.MinX and p.X < F.MaxX and p.Z >= F.MinZ and p.Z < F.MaxZ then
			local v = e.Root.AssemblyLinearVelocity
			table.insert(points, { p.X, p.Z })
			table.insert(points, { p.X + v.X * LEAD, p.Z + v.Z * LEAD })
		end
	end
	return points
end

-- A body over unwritten ground (or fallen below a written tile's floor) goes to the nearest written altar's
-- spawn; nothing is kindled and the lobby is never the destination. Pure decisions: Terrain.Verdict / RescueAltar.
local function guard()
	for _, player in Players:GetPlayers() do
		local userId = player.UserId
		local e = Characters.GetEntity(userId)
		if e and e.Fighter.State ~= "KO" and not e.Respawning and not Characters.IsInDuel(userId) then
			local p = e.Root.Position
			local why = Terrain.Verdict(p.X, p.Y, p.Z)
			if why == "Fell" then
				local floor = Landmarks.lowerFloorAt(folders, p)
				if floor then why = Terrain.Verdict(p.X, p.Y, p.Z, floor) end
			end
			if why then
				local id = Terrain.RescueAltar(p.X, p.Z, OverworldService.Ready)
				if id then
					local s = Overworld.Altars[id].Spawn
					Characters.Teleport(userId, CFrame.new(s.X, s.Y, s.Z) * CFrame.Angles(0, math.rad(s.Yaw), 0))
					rescues += 1
					if root then root:SetAttribute("Rescues", rescues) end
					warn(string.format("[Overworld] %s %s at (%.0f, %.0f, %.0f): returned to %s.", player.Name,
						if why == "Unwritten" then "stood over unwritten ground" else "fell below the written ground", p.X, p.Y, p.Z, id))
				end
			end
		end
	end
end

local function generate()
	local order = Terrain.Priority(GLADE_RADIUS)
	local plan = Terrain.Plan()
	total = #plan
	local gate = Overworld.Altars[Overworld.Gateway].Placement
	for id, keys in Terrain.SiteTiles(plan) do
		siteLeft[id] = #keys
		sitesLeft += 1
		for _, key in keys do
			tileSites[key] = tileSites[key] or {}
			table.insert(tileSites[key], id)
		end
	end
	for _, tile in plan do
		for id in tile.Regions do
			regionTotal[id] = (regionTotal[id] or 0) + 1
		end
		local cx, cz = (tile.X0 + tile.X1) / 2, (tile.Z0 + tile.Z1) / 2
		if math.sqrt((cx - gate.X) ^ 2 + (cz - gate.Z) ^ 2) <= GLADE_RADIUS then
			gladeKeys[tile.Key] = true
			gladeTotal += 1
		end
	end
	local ok, problem = pcall(function()
		Terrain.Build(nil, function(_i: number, _n: number, tile: any)
			done += 1
			for id in tile.Regions do
				regionDone[id] = (regionDone[id] or 0) + 1
			end
			for _, id in tileSites[tile.Key] or {} do
				siteLeft[id] -= 1
				if siteLeft[id] == 0 then
					if root then root:SetAttribute("SiteReady_" .. id, true) end -- AIService waits on Spawn_<id> before a first spawn
					sitesLeft -= 1
					if sitesLeft == 0 then
						sitesSeconds = os.clock() - startedAt
						if root then root:SetAttribute("AltarsReadySeconds", sitesSeconds) end
					end
				end
			end
			if gladeKeys[tile.Key] then
				gladeDone += 1
				if gladeDone == gladeTotal then
					gladeSeconds = os.clock() - startedAt
					if root then root:SetAttribute("GladeReadySeconds", gladeSeconds) end
				end
			end
			if root and done % 100 == 0 then
				root:SetAttribute("TilesDone", done)
			end
		end, order, focus)
	end)
	if not ok then
		failed = tostring(problem)
		warn("[Overworld] terrain generation failed: " .. failed)
		return
	end
	allSeconds = os.clock() - startedAt
	if root then
		-- ownership: the bounding box of every tile written (inside Overworld.Frame by construction)
		local x0, z0, x1, z1 = math.huge, math.huge, -math.huge, -math.huge
		for _, tile in Terrain.Manifest do
			x0, z0, x1, z1 = math.min(x0, tile.X0), math.min(z0, tile.Z0), math.max(x1, tile.X1), math.max(z1, tile.Z1)
		end
		root:SetAttribute("ManifestBox", string.format("%d,%d,%d,%d", x0, z0, x1, z1))
		root:SetAttribute("TilesDone", done)
		root:SetAttribute("AllReadySeconds", allSeconds)
	end
	print(string.format("[Overworld] terrain complete: %d tiles; glade %.1f s, altars %.1f s, all %.1f s after start.", done, gladeSeconds or -1, sitesSeconds or -1, allSeconds))
end

-- Ready("Glade") (default): the gateway neighbourhood is written. Ready("Altars"): the tiles around every altar and the
-- barrier node. Ready(altarId or barrier node id), Ready("All"), or a region id.
function OverworldService.Ready(area: string?): boolean
	if not Overworld.Active then
		return true
	end
	if failed then
		return false
	end
	area = area or "Glade"
	if area == "Glade" then
		return gladeTotal > 0 and gladeDone >= gladeTotal
	elseif area == "All" then
		return total > 0 and done >= total
	elseif area == "Altars" then
		return total > 0 and sitesLeft == 0
	elseif siteLeft[area] then
		return siteLeft[area] == 0
	end
	return (regionTotal[area] or 0) > 0 and (regionDone[area] or 0) >= regionTotal[area]
end

-- Blocks (polling every 0.1 s) until Ready(area) or the timeout; false on timeout or failure.
function OverworldService.WaitReady(timeout: number, area: string?): boolean
	local deadline = os.clock() + timeout
	while not OverworldService.Ready(area) do
		if failed or os.clock() >= deadline then
			return false
		end
		task.wait(0.1)
	end
	return true
end

-- Ownership: the instances under Map_Overworld and every terrain tile box written (Terrain.Manifest).
function OverworldService.Manifest(): any
	local names = {}
	for id in folders do
		table.insert(names, id)
	end
	return { Root = root, Folders = names, TerrainTiles = Terrain.Manifest }
end

function OverworldService.Stats(): any
	return { Total = total, Done = done, GladeSeconds = gladeSeconds, AltarsSeconds = sitesSeconds, AllSeconds = allSeconds, Failed = failed, GladeTiles = gladeTotal }
end

-------------------------------------------------------------------------------------------------
-- Lifecycle
-------------------------------------------------------------------------------------------------

function OverworldService.Start()
	if not Overworld.Active then
		return
	end
	assert(not running, "OverworldService already started")
	running = true
	startedAt = os.clock()
	local existing = Workspace:FindFirstChild(Overworld.Root)
	if existing then
		existing:Destroy()
	end
	local map = Instance.new("Folder")
	map.Name = Overworld.Root
	root = map
	for _, id in Overworld.RegionIds do
		local f = Instance.new("Folder")
		f.Name = id
		f:SetAttribute("AsuraRegion", id)
		f.Parent = map
		folders[id] = f
	end
	local B = Overworld.Blockout
	local function each(list: { any }, build: (any, Instance) -> ())
		for _, def in list do
			local ok, problem = pcall(build, def, folders[def.Region])
			if not ok then
				warn(string.format("[Overworld] %s skipped: %s", tostring(def.Id), tostring(problem)))
			end
		end
	end
	buildLandmarks()
	local gate = Overworld.Vesperhold
	local gateFrame = CFrame.new(gate.X, gate.Y, gate.Z) * CFrame.Angles(0, math.rad(gate.Yaw), 0)
	require(script.Parent.GothicMarch).build(folders.Snowfields, gateFrame)
	require(script.Parent.GothicCitadel).build(folders.Snowfields, gateFrame)
	Landmarks.build(folders, function(area: string): boolean
		return OverworldService.WaitReady(900, area)
	end)
	each(B.Bridges, function(def, parent)
		if def.Kind == "stone" then stoneBridge(def, parent) else ropeBridge(def, parent) end
	end)
	each(B.Ramps, ramp)
	each(B.Lifts, lift)
	each(B.Shelters, shelter)
	each(B.Portals, portal)
	each({ B.ReturnGate }, returnGate)
	local parts = 0
	for _, d in map:GetDescendants() do
		parts += if d:IsA("BasePart") then 1 else 0
	end
	map:SetAttribute("AsuraParts", parts)
	map.Parent = Workspace
	table.insert(connections, Players.PlayerRemoving:Connect(function(player: Player)
		transit[player.UserId] = nil
	end))
	task.spawn(generate)
	task.spawn(function()
		while running do
			guard()
			task.wait(GUARD_PERIOD)
		end
	end)
	print(string.format("[Overworld] Map_Overworld raised: %d parts; terrain generating in the background.", parts))
end

-- Builders exposed for tools/test_ravine_span.luau.
OverworldService.Build = { StoneBridge = stoneBridge, Shelter = shelter, Portal = portal }

function OverworldService.Destroy()
	running = false
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	table.clear(transit)
	if root then
		root:Destroy()
		root = nil
	end
	table.clear(folders)
end

return OverworldService
