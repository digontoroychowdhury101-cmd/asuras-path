--!nonstrict
-- Test helper (not a test): builds the Desecrated Monastery offline by running the real
-- MonasteryGrounds / Ruins / Halls / Landmarks / Pockets / Secrets / Atmosphere builders against Lune's Roblox datatypes
-- and a recording Terrain, then answers geometric questions (segment and point queries against
-- every part's oriented box). Uploaded meshes (ServerStorage.AsuraAssets) are absent, so the
-- dressing layer is skipped, and the seeded Random is a stand-in: procedural scatter positions differ
-- from Studio while every authored position (bridge, shrines, walls, colonnades) is exact.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Vector3, CFrame = roblox.Vector3, roblox.CFrame

local Scene = {}

local function fakeRandom(seed: number)
	local state = seed % 2147483647
	local r = {}
	function r:NextNumber(a: number?, b: number?): number
		state = (state * 48271) % 2147483647
		local u = state / 2147483647
		return if a then a + (b - a) * u else u
	end
	function r:NextInteger(a: number, b: number): number return math.floor(r:NextNumber(a, b + 1 - 1e-9)) end
	return r
end
Scene.Random = fakeRandom

-- Terrain calls are recorded (FillBlock / FillBall / ReplaceMaterial) for terrain assertions.
local function fakeTerrain(log)
	local t = {}
	function t:SetMaterialColor() end
	function t:FillBlock(cf, size, material) table.insert(log, { Kind = "Block", CFrame = cf, Size = size, Material = material.Name }) end
	function t:FillBall(center, radius, material) table.insert(log, { Kind = "Ball", Center = center, Radius = radius, Material = material.Name }) end
	function t:ReplaceMaterial() end
	return t
end

function Scene.build(seed: number?)
	local World = require("../src/shared/WorldDefinitions")
	local Assets = require("../src/shared/PresentationAssets")
	local Zones = require("../src/shared/MonasteryZones")
	local terrainLog = {}
	local workspace = { Terrain = fakeTerrain(terrainLog) }
	local services = {
		Workspace = workspace,
		ReplicatedStorage = { WaitForChild = function(self, name) return self[name] end, AsurasPath = { Shared = { WorldDefinitions = World, PresentationAssets = Assets, MonasteryZones = Zones } } },
		ServerStorage = { FindFirstChild = function() return nil end },
	}
	services.ReplicatedStorage.AsurasPath.WaitForChild = function(self, name) return self[name] end
	local modules = {}
	local folderProxy = { WaitForChild = function(_, name) return modules[name] end }
	local game = { GetService = function(_, name) return services[name] end }
	local env = {
		game = game, script = { Parent = folderProxy }, require = function(m) return m end, workspace = workspace,
		Instance = roblox.Instance, CFrame = CFrame, Vector3 = Vector3, Vector2 = roblox.Vector2, Color3 = roblox.Color3, Enum = roblox.Enum,
		NumberSequence = roblox.NumberSequence, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint, ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint, NumberRange = roblox.NumberRange, UDim2 = roblox.UDim2, Region3 = roblox.Region3,
		Random = { new = fakeRandom }, math = math, table = table, string = string, pcall = pcall, warn = function() end, print = print,
		typeof = typeof, type = type, tostring = tostring, next = next, os = os, assert = assert, error = error, select = select, setmetatable = setmetatable,
	}
	for _, name in { "MonasteryKit", "MonasteryFx", "MonasteryTerrain", "MonasteryGrounds", "MonasteryRuins", "MonasteryHalls", "MonasteryLandmarks", "MonasteryPockets", "MonasterySecrets", "MonasteryAtmosphere" } do
		local source = fs.readFile("src/server/Services/" .. name .. ".luau")
		modules[name] = luau.load(source, { debugName = name, environment = env })()
	end
	local map = roblox.Instance.new("Folder")
	map.Name = "Map_DesecratedMonastery"
	local rng = fakeRandom(seed or 7341)
	modules.MonasteryGrounds.Build(map, rng)
	modules.MonasteryRuins.Build(map, rng)
	modules.MonasteryHalls.Build(map, rng)
	modules.MonasteryLandmarks.Build(map, rng)
	modules.MonasteryPockets.Build(map, rng)
	modules.MonasterySecrets.Build(map, rng)
	pcall(modules.MonasteryAtmosphere.Build, map, rng)
	local parts = {}
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") then
			local path = {}
			local node = d
			while node and node ~= map do table.insert(path, 1, node.Name); node = node.Parent end
			table.insert(parts, { Part = d, CFrame = d.CFrame, Half = d.Size * 0.5, Visible = d.Transparency < 0.9, Collide = d.CanCollide,
				Name = d.Name, Path = table.concat(path, "/"), Radius = (d.Size * 0.5).Magnitude })
		end
	end
	return { Map = map, Parts = parts, Terrain = terrainLog, Modules = modules, World = World, Ground = modules.MonasteryKit.GROUND }
end

-- Slab test in the box's local space. Returns the entry fraction along a→b, or nil.
local function segmentBox(entry, a, b): number?
	local center = entry.CFrame.Position
	local mid, half = (a + b) * 0.5, (b - a).Magnitude * 0.5
	if (mid - center).Magnitude > entry.Radius + half then return nil end
	local la, lb = entry.CFrame:PointToObjectSpace(a), entry.CFrame:PointToObjectSpace(b)
	local d = lb - la
	local t0, t1 = 0, 1
	for _, axis in { "X", "Y", "Z" } do
		local o, dir, h = la[axis], d[axis], entry.Half[axis]
		if math.abs(dir) < 1e-9 then
			if o < -h or o > h then return nil end
		else
			local u, v = (-h - o) / dir, (h - o) / dir
			if u > v then u, v = v, u end
			t0, t1 = math.max(t0, u), math.min(t1, v)
			if t0 > t1 then return nil end
		end
	end
	return t0
end
Scene.segmentBox = segmentBox

-- First part hit by a→b; `filter(entry)` decides which parts count. Returns (point, entry).
function Scene.cast(scene, a, b, filter)
	local best, hit = math.huge, nil
	for _, entry in scene.Parts do
		if filter(entry) then
			local t = segmentBox(entry, a, b)
			if t and t < best then best, hit = t, entry end
		end
	end
	if hit then return a + (b - a) * best, hit end
	return nil, nil
end

function Scene.inside(entry, point): boolean
	if (point - entry.CFrame.Position).Magnitude > entry.Radius then return false end
	local l = entry.CFrame:PointToObjectSpace(point)
	return math.abs(l.X) <= entry.Half.X and math.abs(l.Y) <= entry.Half.Y and math.abs(l.Z) <= entry.Half.Z
end

-- Visible parts the camera or the eye would see (decor included: CanQuery=false does not hide it).
function Scene.visible(entry) return entry.Visible end
function Scene.solid(entry) return entry.Collide end

return Scene
