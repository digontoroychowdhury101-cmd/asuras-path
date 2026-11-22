--!nonstrict
-- Vesperhold kit loader (mac-54): VesperholdKit placement rules on LoadModel fakes, the stand-in fallback, GothicCitadel / GothicMarch
-- swapping stand-ins for kit meshes only when the registry has the piece. (Layout.Piece vs manifest sizes: tools/test_vesperhold_layout_sizes.py.)
-- Run: python3 tools/lune_compat.py tools/test_vesperhold_loader.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox") :: any
local Vector3, CFrame, Color3, Enum, Instance = roblox.Vector3, roblox.CFrame, roblox.Color3, roblox.Enum, roblox.Instance
local O = require("../src/shared/Overworld")
local L = require("../src/shared/VesperholdLayout")

local passed, failed = 0, 0
local function check(name: string, ok: any)
	if ok then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local function near(a: number, b: number, e: number?) return math.abs(a - b) <= (e or 1e-4) end

local collisionCooks, failCook = 0, false
roblox.implementProperty("MeshPart", "CollisionFidelity", function(part)
	return rawget(part, "_fidelity") or Enum.CollisionFidelity.Default
end, function()
	error("CollisionFidelity cannot be assigned by a running server")
end)
roblox.implementMethod("MeshPart", "ApplyMesh", function(part, source)
	rawset(part, "_fidelity", source.CollisionFidelity)
	part.MeshId, part.TextureContent = source.MeshId, source.TextureContent
end)
local services = { ReplicatedStorage = { WaitForChild = function() return { Shared = { Overworld = O, VesperholdLayout = L } } end },
	CollectionService = { AddTag = function(_, inst, tag) inst:AddTag(tag) end } }
services.AssetService = {
	CreateMeshPartAsync = function(_, mesh, options)
		collisionCooks += 1
		if failCook then error("fixture collision cook failed") end
		local part = Instance.new("MeshPart")
		part.MeshId, part.TextureContent = mesh, ""
		rawset(part, "_fidelity", options.CollisionFidelity)
		return part
	end,
}
-- Build-time glass finishes (assets/models/AsuraVesperholdGlass.rbxmx): the rose has one, the fixture lancet does not.
services.ServerStorage = Instance.new("Folder")
local glassLib = Instance.new("Folder")
glassLib.Name, glassLib.Parent = "AsuraVesperholdGlass", services.ServerStorage
local roseFinish = Instance.new("SurfaceAppearance")
roseFinish.Name, roseFinish.ColorMap, roseFinish.Parent = "Rose_Window_Great__GlassR", "rbxassetid://777", glassLib
local base = { game = { GetService = function(_, n) return services[n] end }, Instance = Instance, Enum = Enum, Vector3 = Vector3, CFrame = CFrame,
	Color3 = Color3, UDim2 = roblox.UDim2, Random = roblox.Random, typeof = typeof, warn = function() end,
	NumberRange = roblox.NumberRange, NumberSequence = roblox.NumberSequence, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	ColorSequence = roblox.ColorSequence, Vector2 = roblox.Vector2,
	Content = { fromUri = function(uri) return uri end } }
local function load(path: string, env: any, name: string)
	return luau.load(fs.readFile(path), { debugName = name, environment = setmetatable(env, { __index = _G }) })()
end
local Kit = load("src/server/Services/VesperholdKit.luau", table.clone(base), "VesperholdKit")

-- Fakes -----------------------------------------------------------------------------------------------------------
local nextId = 5000
local function newId() nextId += 1; return "rbxassetid://" .. nextId end
-- subs: { { "Role", size, position }, ... }; returns the loaded wrapper (as InsertService:LoadAsset does) and the registry entries.
local function fakeAsset(piece: string, subs: { any }, assetId: string)
	local wrapper = Instance.new("Model")
	wrapper.Name = "Wrapper"
	local model = Instance.new("Model")
	model.Name = piece
	model.Parent = wrapper
	local entries = {}
	for _, sub in subs do
		local key = piece .. "__" .. sub[1]
		local m = Instance.new("MeshPart")
		m.Name, m.MeshId, m.Size, m.CFrame, m.Archivable = key, newId(), sub[2], CFrame.new(sub[3]), true
		m.TextureContent = "rbxassetid://600"
		local finish = Instance.new("SurfaceAppearance")
		finish.ColorMap = "rbxassetid://601"
		finish.Parent = m
		m.Anchored = false
		m.Parent = model
		entries[key] = { MeshId = m.MeshId, Asset = assetId }
	end
	return wrapper, entries
end
local V3 = Vector3.new
local statueSubs = { { "Robe", V3(4, 12, 4), V3(0, 6, 0) }, { "Hood", V3(3, 4, 3), V3(0, 11, 0) }, { "Arms", V3(5, 2, 2), V3(0, 7, 0) },
	{ "Plinth", V3(5, 2, 5), V3(0, 1, 0) }, { "Staff", V3(0.4, 14, 0.4), V3(2.3, 7, 0) }, { "Robe_2", V3(4, 6, 4), V3(0, 9, 0) } }
local assets, registry, loads = {}, {}, {}
local function register(piece: string, subs: { any })
	local id = newId()
	local wrapper, entries = fakeAsset(piece, subs, id)
	assets[id] = wrapper
	registry[piece] = entries
end
register("Hooded_Statue_A", statueSubs)
register("Lancet_Tall", { { "Stone", V3(8, 40, 4), V3(0, 20, 0) }, { "Glass", V3(4, 30, 1), V3(0, 22, 0) }, { "Tracery", V3(8, 6, 1), V3(0, 35, 0) } })
register("Rose_Window_Great", { { "Stone", V3(40, 40, 6), V3(0, 20, 0) }, { "GlassR", V3(30, 30, 1), V3(0, 20, 0) } })
register("Brazier_Post", { { "Iron", V3(1, 8, 1), V3(0, 4, 0) }, { "Flame", V3(2, 2, 2), V3(0, 9, 0) } })
register("Dead_Pine_Snapped_A", { { "Bark", V3(3, 60, 3), V3(0, 30, 0) } })
register("Dead_Pine_Snapped_B", { { "Bark", V3(3, 50, 3), V3(0, 25, 0) } })
register("Arcade_Bay_40", { { "Stone", V3(40, 40, 14), V3(0, 20, 0) }, { "Frost", V3(40, 1, 14), V3(0, 40.5, 0) } })
-- An incomplete piece: the registry lists a sub the uploaded model does not contain.
register("Banner_Torn_A", { { "Banner", V3(8, 30, 1), V3(0, 15, 0) } })
registry.Banner_Torn_A["Banner_Torn_A__Rope"] = { MeshId = newId(), Asset = registry.Banner_Torn_A["Banner_Torn_A__Banner"].Asset }
-- A piece whose asset does not load.
registry.Gibbet_Cage = { Gibbet_Cage__Iron = { MeshId = newId(), Asset = "rbxassetid://404" } }
-- A piece split across two model assets (over the 20 MB upload limit); each wrapper is recentred, so centers place the subs.
register("Spire_Needle_Tip", { { "Stone", V3(4, 20, 4), V3(0, 0, 0) } })
do
	local w2, e2 = fakeAsset("Spire_Needle_Tip", { { "Lead", V3(2, 6, 2), V3(7, 7, 7) } }, newId())
	local key = "Spire_Needle_Tip__Lead"
	assets[e2[key].Asset] = w2
	registry.Spire_Needle_Tip[key] = e2[key]
	registry.Spire_Needle_Tip[key].center = { 1, 23, 0 }
	registry.Spire_Needle_Tip["Spire_Needle_Tip__Stone"].center = { 0, 10, 0 }
end
register("Spire_Broken_Top", { { "Stone", V3(4, 20, 4), V3(0, 10, 0) } })
do
	local w2, e2 = fakeAsset("Spire_Broken_Top", { { "Lead", V3(2, 6, 2), V3(0, 3, 0) } }, newId())
	assets[e2["Spire_Broken_Top__Lead"].Asset] = w2
	registry.Spire_Broken_Top["Spire_Broken_Top__Lead"] = e2["Spire_Broken_Top__Lead"] -- no centers: refused
end

local function setup(reg: any)
	Kit.Reset()
	loads = {}
	collisionCooks = 0
	Kit.Registry = reg
	Kit.LoadModel = function(id: string)
		table.insert(loads, id)
		return if assets[id] then assets[id]:Clone() else nil -- Reset destroys loaded models, like a fresh LoadAsset each time
	end
end

-- 1. Empty / missing registry: nothing resolves, nothing is built ---------------------------------------------------
setup({})
check("empty registry: has() is false and place() returns nil", not Kit.has("Hooded_Statue_A") and Kit.place("Hooded_Statue_A", CFrame.new(), V3(1, 1, 1)) == nil and #loads == 0)

-- 2. Statue: Model by piece name, PrimaryPart core sub, anchored, collision by role --------------------------------------
setup(registry)
local frame = CFrame.new(100, 50, -20) * CFrame.Angles(0, math.rad(90), 0)
local statue = Kit.place("Hooded_Statue_A", frame, V3(1, 1, 1), { Group = "Statue" })
check("place() returns a Model named by the piece", statue ~= nil and statue.ClassName == "Model" and statue.Name == "Hooded_Statue_A")
local parts = {}
for _, d in statue:GetChildren() do parts[d.Name] = d end
check("every registry sub-mesh is cloned", (function() local n = 0 for _ in parts do n += 1 end return n == #statueSubs end)())
check("PrimaryPart is the core sub (Robe)", statue.PrimaryPart == parts["Hooded_Statue_A__Robe"])
local allAnchored = true
for _, p in parts do if not p.Anchored then allAnchored = false end end
check("every part is Anchored and untouchable", allAnchored and not parts["Hooded_Statue_A__Robe"].CanTouch)
check("decorative Staff: no collision, no query", not parts["Hooded_Statue_A__Staff"].CanCollide and not parts["Hooded_Statue_A__Staff"].CanQuery)
check("thin solids (Robe, Hood, Arms) collide with Box fidelity", (function()
	for _, k in { "Robe", "Robe_2", "Hood", "Arms" } do
		local p = parts["Hooded_Statue_A__" .. k]
		if not (p.CanCollide and p.CollisionFidelity == Enum.CollisionFidelity.Box) then return false end
	end
	return true
end)())
check("Plinth core collides with Hull fidelity", parts["Hooded_Statue_A__Plinth"].CanCollide and parts["Hooded_Statue_A__Plinth"].CollisionFidelity == Enum.CollisionFidelity.Hull)
local expect = frame:PointToWorldSpace(V3(0, 6, 0))
check("parts sit at the slot frame (foot centre pivot)", (parts["Hooded_Statue_A__Robe"].Position - expect).Magnitude < 1e-3)
check("mesh ids are the uploaded ones (never rewritten)", parts["Hooded_Statue_A__Robe"].MeshId == registry.Hooded_Statue_A["Hooded_Statue_A__Robe"].MeshId)
check("the runtime cook keeps the imported texture and PBR surface",
	parts["Hooded_Statue_A__Robe"].TextureContent == "rbxassetid://600"
		and parts["Hooded_Statue_A__Robe"]:FindFirstChildOfClass("SurfaceAppearance").ColorMap == "rbxassetid://601")
for _ = 1, 3 do Kit.place("Hooded_Statue_A", frame, V3(1, 1, 1), { Group = "Statue" }) end
check("the asset is loaded once and cloned per placement", #loads == 1)
check("the five colliding subs cook once each across repeated placements", collisionCooks == 5)
check("the loaded model is never parented into the world", statue.PrimaryPart.Parent == statue and statue.Parent == nil)
local walk = Kit.place("Hooded_Statue_A", frame, V3(1, 1, 1), { Group = "Statue", Walkable = true })
check("Walkable cores use PreciseConvexDecomposition", walk:FindFirstChild("Hooded_Statue_A__Plinth").CollisionFidelity == Enum.CollisionFidelity.PreciseConvexDecomposition)
local scaled = Kit.place("Hooded_Statue_A", CFrame.new(), V3(2, 3, 0.5), { Group = "Statue" })
local sp = scaled:FindFirstChild("Hooded_Statue_A__Robe")
check("per-axis scale reaches size and offset", near(sp.Size.X, 8) and near(sp.Size.Y, 36) and near(sp.Size.Z, 2) and near(sp.Position.Y, 18))
check("a bad scale is refused", Kit.place("Hooded_Statue_A", CFrame.new(), V3(0, 1, 1)) == nil and Kit.place("Hooded_Statue_A", CFrame.new(), V3(1, 0 / 0, 1)) == nil)

-- 3. Groups the player cannot touch stay non-colliding; the massing Parts own the walk route ------------------------------
local arcade = Kit.place("Arcade_Bay_40", CFrame.new(), V3(1, 1, 1), { Group = "Arcade" })
local anyHit = false
for _, p in arcade:GetChildren() do if p.CanCollide or p.CanQuery then anyHit = true end end
check("arcade (wall cladding) never collides", not anyHit and arcade.PrimaryPart.Name == "Arcade_Bay_40__Stone")
local tree = Kit.place("Dead_Pine_Snapped", CFrame.new(), V3(1, 1, 1), { Group = "Tree", Seed = 1 })
check("tree trunk (Bark) collides with Hull", tree ~= nil and tree.PrimaryPart.CanCollide and tree.PrimaryPart.CollisionFidelity == Enum.CollisionFidelity.Hull)
local beforeCook = collisionCooks
failCook = true
local parkedTree = Kit.place("Dead_Pine_Snapped", CFrame.new(), V3(1, 1, 1), { Group = "Tree", Seed = 0 })
Kit.place("Dead_Pine_Snapped", CFrame.new(), V3(1, 1, 1), { Group = "Tree", Seed = 0 })
failCook = false
check("one failed cook keeps imported collision and is cached",
	parkedTree ~= nil and parkedTree.PrimaryPart.CanCollide
		and parkedTree.PrimaryPart.CollisionFidelity == Enum.CollisionFidelity.Default and collisionCooks == beforeCook + 1)

-- 4. Variants -----------------------------------------------------------------------------------------------------------
check("_A/_B variants resolve from the layout name by seed", Kit.has("Dead_Pine_Snapped") and Kit.resolve("Dead_Pine_Snapped", 0) == "Dead_Pine_Snapped_A" and Kit.resolve("Dead_Pine_Snapped", 1) == "Dead_Pine_Snapped_B")
check("the placed Model keeps the layout name and records the variant", tree.Name == "Dead_Pine_Snapped" and tree:GetAttribute("VespKitPiece") == "Dead_Pine_Snapped_B")

-- 5. Glass and flames: Neon, warm colour, one small light, capped --------------------------------------------------------
local lancet = Kit.place("Lancet_Tall", CFrame.new(), V3(1, 1, 1), { Group = "Lancet" })
local glass = lancet:FindFirstChild("Lancet_Tall__Glass")
local light = glass:FindFirstChildOfClass("PointLight") or glass:FindFirstChild("PointLight")
check("glass is Neon amber with a small shadowless PointLight", glass.Material == Enum.Material.Neon and glass.Color.R > glass.Color.B and light ~= nil and light.Range <= 16 and light.Shadows == false)
local rose = Kit.place("Rose_Window_Great", CFrame.new(), V3(1, 1, 1), { Group = "Rose" })
local rg = rose:FindFirstChild("Rose_Window_Great__GlassR")
check("imported GlassR is Neon crimson and non-colliding",
	rg.Material == Enum.Material.Neon and rg.Color.R > 0.4 and rg.Color.G < 0.2 and not rg.CanCollide)
local rgFinish = rg:FindFirstChildOfClass("SurfaceAppearance")
check("glass with a build-time finish keeps its mosaic: the emissive template replaces the imported surface",
	rgFinish ~= nil and rgFinish.ColorMap == "rbxassetid://777" and roseFinish.Parent == glassLib)
local finishes = 0
for _, c in rg:GetChildren() do if c:IsA("SurfaceAppearance") then finishes += 1 end end
check("exactly one surface finish on the rose glass", finishes == 1)
check("glass without a finish drops its SurfaceAppearance so Neon glows; tracery and stone keep theirs", glass:FindFirstChildOfClass("SurfaceAppearance") == nil
	and lancet:FindFirstChild("Lancet_Tall__Tracery"):FindFirstChildOfClass("SurfaceAppearance") ~= nil
	and lancet:FindFirstChild("Lancet_Tall__Stone"):FindFirstChildOfClass("SurfaceAppearance") ~= nil)
check("glass never collides and non-glass subs get no light", not glass.CanCollide and lancet:FindFirstChild("Lancet_Tall__Stone"):FindFirstChild("PointLight") == nil)
local brazier = Kit.place("Brazier_Post", CFrame.new(), V3(1, 1, 1), { Group = "Brazier" })
local flame = brazier:FindFirstChild("Brazier_Post__Flame")
local fl = flame:FindFirstChild("PointLight")
check("flame is Neon orange with a warm PointLight, no collision", flame.Material == Enum.Material.Neon and flame.Color.R > flame.Color.B and fl ~= nil and fl.Brightness > 1 and not flame.CanCollide)
Kit.MaxLights = Kit.Lights()
local capped = Kit.place("Brazier_Post", CFrame.new(), V3(1, 1, 1), { Group = "Brazier" })
local cf2 = capped:FindFirstChild("Brazier_Post__Flame")
check("at the light cap the flame stays Neon but gets no new light", cf2.Material == Enum.Material.Neon and cf2:FindFirstChild("PointLight") == nil)
Kit.MaxLights = 80

-- 6. Fallback paths: any failure returns nil so the stand-in stays -------------------------------------------------------
check("a sub the model lacks makes the whole piece unavailable", Kit.place("Banner_Torn_A", CFrame.new(), V3(1, 1, 1)) == nil and not Kit.has("Banner_Torn_A"))
check("an asset that fails to load leaves no piece", Kit.place("Gibbet_Cage", CFrame.new(), V3(1, 1, 1)) == nil)
check("unknown pieces are simply absent", not Kit.has("Nope") and Kit.place("Nope", CFrame.new(), V3(1, 1, 1)) == nil)
local nloads = #loads
local split = Kit.place("Spire_Needle_Tip", CFrame.new(100, 0, 0), V3(1, 1, 1))
check("a piece split over two assets loads both and places subs by center", split ~= nil and #loads == nloads + 2
	and (split:FindFirstChild("Spire_Needle_Tip__Lead").Position - V3(101, 23, 0)).Magnitude < 1e-3
	and (split:FindFirstChild("Spire_Needle_Tip__Stone").Position - V3(100, 10, 0)).Magnitude < 1e-3)
check("a split piece without centers is refused", Kit.place("Spire_Broken_Top", CFrame.new(), V3(1, 1, 1)) == nil)

-- 7. GothicCitadel / GothicMarch with the real loader ---------------------------------------------------------------------
local g = O.Vesperhold
local origin = CFrame.new(g.X, g.Y, g.Z) * CFrame.Angles(0, math.rad(g.Yaw), 0)
local function sanctuaryKit()
	local K = {}
	function K.part(parent, name, size, cf, color, material, options)
		local o = options or {}
		local p = Instance.new(o.Class or "Part")
		p.Name, p.Anchored, p.Size, p.CFrame, p.Color, p.Material = name, true, size, cf, color, material
		p.CanCollide = if o.Collide == nil then true else o.Collide
		p.CanQuery = if o.Query == nil then p.CanCollide else o.Query
		p.Parent = parent
		return p
	end
	function K.disc(parent, name, radius, height, center, color, material, options)
		return K.part(parent, name, Vector3.new(height, radius * 2, radius * 2), center, color, material, options)
	end
	K.light = function() return {} end
	return K
end
local noop = function() end
local function buildCastle(kitRegistry: any)
	setup(kitRegistry)
	local K = sanctuaryKit()
	local stubs = { SanctuaryKit = { part = K.part, disc = K.disc, light = K.light, place = noop, slab = K.part }, SanctuaryProps = { brazier = noop, bench = noop },
		MonasteryKit = K, RegionDecor = { banner = noop, nature = noop, han = noop }, PbrAssets = { place = noop }, VesperholdKit = Kit }
	local env = table.clone(base)
	env.script = { Parent = setmetatable({ WaitForChild = function(_, n) return stubs[n] end }, { __index = stubs }) }
	env.require = function(m) return m end
	env.task = { wait = noop, spawn = noop, delay = noop }
	env.ReplicatedStorage = nil
	local Citadel = load("src/server/Services/GothicCitadel.luau", env, "GothicCitadel")
	local March = load("src/server/Services/GothicMarch.luau", env, "GothicMarch")
	local root = Instance.new("Folder")
	March.build(root, origin)
	Citadel.build(root, origin)
	return root
end
local slots = L.slots(function(x: number, z: number): number return O.heightAt(g.X - z, g.Z + x) - g.Y end)
local function count(group: string?, piece: string?)
	local n = 0
	for _, s in slots do if (not group or s.Group == group) and (not piece or s.Piece == piece) then n += 1 end end
	return n
end
local function tally(root: any)
	local t = { Stand = {}, Mesh = {}, Bays = 0, Snags = 0 }
	for _, d in root:GetDescendants() do
		local slot = d:GetAttribute("VespKitSlot")
		if slot then t.Stand[slot] = (t.Stand[slot] or 0) + 1 end
		if d:GetAttribute("VespKitPiece") then t.Mesh[d.Name] = (t.Mesh[d.Name] or 0) + 1 end
		if d.Name == "Wind-thrown beech" then t.Snags += 1 end
	end
	return t
end
local plain = tally(buildCastle({}))
check("no registry: every non-viaduct slot keeps its stand-in", plain.Stand.Hooded_Statue_A == count(nil, "Hooded_Statue_A") and next(plain.Mesh) == nil)
check("no registry: the viaduct bay stand-ins and the snag trees are still built", plain.Stand.Viaduct_Bay == count("Viaduct") + count("ViaductHigh") and plain.Snags > 0)
local kitRoot = buildCastle(registry)
local kit = tally(kitRoot)
check("registry piece: the statue meshes replace the stand-ins at every slot", kit.Mesh.Hooded_Statue_A == count(nil, "Hooded_Statue_A") and kit.Stand.Hooded_Statue_A == nil)
check("pieces missing from the registry keep their stand-ins", kit.Stand.Hooded_Statue_B == count(nil, "Hooded_Statue_B") and kit.Stand.Pedestal_Statue_Staff == count(nil, "Pedestal_Statue_Staff"))
local carriesA, carriesB = 0, 0
for _, sl in slots do
	if sl.Piece == "Statue_Plinth" then
		if sl.Carries == "Hooded_Statue_A" then carriesA += 1 else carriesB += 1 end
	end
end
check("statue meshes drop the separate plinth they carry; other plinths stay as Part stand-ins", carriesA > 0 and carriesB > 0 and kit.Stand.Statue_Plinth == carriesB and plain.Stand.Statue_Plinth == carriesA + carriesB)
local lowest = math.huge
for _, d in kitRoot:GetDescendants() do
	if d:IsA("Model") and d.Name == "Hooded_Statue_A" and d:GetAttribute("VespKitPiece") then
		local plinth = d:FindFirstChild("Hooded_Statue_A__Plinth")
		lowest = math.min(lowest, plinth.Position.Y - plinth.Size.Y / 2)
	end
end
local decks = {}
for _, sl in slots do if sl.Piece == "Hooded_Statue_A" then table.insert(decks, origin.Y + sl.Base) end end
table.sort(decks)
check("the kit statue stands on the deck (its own plinth foot at the deck top), not on a second plinth", math.abs(lowest - decks[1]) < 0.01 and decks[1] ~= nil)
check("Statue_Veiled_Scan graveyard slots exist and keep stand-ins without a registry piece", count(nil, "Statue_Veiled_Scan") == 4 and kit.Stand.Statue_Veiled_Scan == 4)
check("variant pieces (Dead_Pine_Snapped_A/B) replace the layout tree slots", kit.Mesh.Dead_Pine_Snapped == count(nil, "Dead_Pine_Snapped") and kit.Stand.Dead_Pine_Snapped == nil)
local tower = 0
for _, d in kitRoot:GetDescendants() do
	if d.Name == "Hooded_Statue_A" and d:IsA("Model") and d:GetAttribute("VespKitPiece") then
		tower += 1
		check("kit statue is anchored with a PrimaryPart", d.PrimaryPart ~= nil and d.PrimaryPart.Anchored)
		if tower > 3 then break end
	end
end
-- Far silhouette: spire, rose, lancet and portal models stay loaded (Persistent); only their silhouette subs (stone, roof,
-- iron, glass) are AsuraKeepFar, so the decorative subs (tracery, crockets, frost...) still take the client's 900-stud cut.
local far, near, keptRoles, cutRoles = {}, 0, {}, {}
for _, d in kitRoot:GetDescendants() do
	if d:IsA("Model") and d:GetAttribute("VespKitPiece") then
		local group = d:GetAttribute("VespGroup")
		if group == "Spire" or group == "Rose" or group == "Lancet" or group == "Portal" then
			far[group] = (far[group] or 0) + 1
			check("far silhouette " .. d.Name .. " is Persistent", d.ModelStreamingMode == Enum.ModelStreamingMode.Persistent)
			for _, p in d:GetChildren() do
				local role = string.match(p.Name, "__(.+)$")
				if p:GetAttribute("AsuraKeepFar") then keptRoles[role] = true else cutRoles[role] = true end
			end
		else
			if d.ModelStreamingMode == Enum.ModelStreamingMode.Persistent then near += 1 end
			for _, p in d:GetChildren() do if p:GetAttribute("AsuraKeepFar") then near += 1 end end
		end
	end
end
check("spires, the rose and lancets were checked", far.Spire and far.Rose and far.Lancet)
check("silhouette subs are AsuraKeepFar", keptRoles.Stone and keptRoles.Glass and keptRoles.GlassR)
check("decorative subs keep the 900-stud cut", cutRoles.Tracery and not keptRoles.Tracery and not keptRoles.Lead)
check("other kit pieces (statues, trees, arcades) keep default streaming and the 900-stud cut", near == 0)
local castleModel = kitRoot:FindFirstChild("Vesperhold")
check("the castle massing and pinnacle rock are Persistent; the castle itself streams by default",
	castleModel:FindFirstChild("Massing").ModelStreamingMode == Enum.ModelStreamingMode.Persistent
	and castleModel:FindFirstChild("Rock").ModelStreamingMode == Enum.ModelStreamingMode.Persistent
	and castleModel.ModelStreamingMode ~= Enum.ModelStreamingMode.Persistent)
local registryWithBay = table.clone(registry)
register("Viaduct_Bay", { { "Stone", V3(35, 120, 29), V3(0, 60, 0) } })
registryWithBay.Viaduct_Bay = registry.Viaduct_Bay
local withBay = tally(buildCastle(registryWithBay))
check("Viaduct_Bay in the registry: March builds no arch stand-ins and the castle places every bay", withBay.Stand.Viaduct_Bay == nil and withBay.Mesh.Viaduct_Bay == count("Viaduct") + count("ViaductHigh"))
register("Thorn_Twisted_A", { { "Bark", V3(10, 30, 10), V3(0, 15, 0) } })
local withThorn = tally(buildCastle(registry))
check("Thorn_Twisted in the registry: the Part snag shells are replaced", plain.Snags > 0 and withThorn.Snags == 0)
check("collision: only the statue group collides (arcade/bastion/viaduct meshes never do)", (function()
	for _, d in kitRoot:GetDescendants() do
		if d:IsA("MeshPart") and d.CanCollide and not (d.Parent and (d.Parent.Name == "Hooded_Statue_A" or d.Parent.Name == "Dead_Pine_Snapped" or d.Parent.Name == "Thorn_Twisted")) then return false end
	end
	return true
end)())

-- 9. Open-world landmarks: LandmarkKitRegistry pieces through the same loader, per-role collision, LandmarkWorld frames + carve --
do
	local function near(a: number, b: number) return math.abs(a - b) <= 1e-4 end -- section 8 reuses the name for a count
	local landmarkReg = {}
	local id = newId()
	local w, e = fakeAsset("Bellwood_GiantFace", { { "Shell", V3(90, 60, 6), V3(0, 30, 0) }, { "Shell_2", V3(90, 60, 6), V3(0, 30, 6) },
		{ "Floor", V3(18, 1, 60), V3(0, 0.5, 0) } }, id)
	assets[id] = w
	landmarkReg.Bellwood_GiantFace = e
	setup(registry)
	Kit.LandmarkRegistry = landmarkReg
	local PRECISE = Enum.CollisionFidelity.PreciseConvexDecomposition
	local face = Kit.place("Bellwood_GiantFace", CFrame.new(), V3(1, 1, 1), { Fidelity = { Shell = PRECISE } })
	check("landmark pieces resolve from LandmarkKitRegistry", face ~= nil and Kit.has("Bellwood_GiantFace"))
	local shell2, floor = face:FindFirstChild("Bellwood_GiantFace__Shell_2"), face:FindFirstChild("Bellwood_GiantFace__Floor")
	check("Fidelity: a listed role (numbered subs too) collides at that fidelity", shell2.CanCollide and shell2.CollisionFidelity == PRECISE)
	check("Fidelity: an unlisted role never collides", not floor.CanCollide and not floor.CanQuery)

	local W = load("src/server/Services/LandmarkWorld.luau", table.clone(base), "LandmarkWorld")
	local LL = require("../src/shared/LandmarkLayout")
	local bw = LL.Landmarks.Bellwood
	local fx, fz = LL.front(bw)
	local mouth = W.kitToWorld(bw, { 0, 1, 0 }) - W.kitToWorld(bw, { 0, 0, 0 })
	check("kitToWorld: kit +Y (the mouth) points along LandmarkLayout.front", near(mouth.X, fx) and near(mouth.Z, fz) and near(mouth.Y, 0))
	-- mac-86f: the crown's 108-stud Rubble strip crosses over the bore; its hull put an invisible wall in the tunnel.
	check("crown rubble never collides (its hull spans the bore)", W.Fidelity.Rubble == nil and W.Fidelity.Shell == PRECISE)
	check("kitToWorld: kit +Z is world up", near((W.kitToWorld(bw, { 0, 0, 1 }) - W.kitToWorld(bw, { 0, 0, 0 })).Y, 1))
	local boxes = W.carves(bw)
	local o = bw.Origin
	local lowest, first = math.huge, boxes[1]
	for _, b in boxes do lowest = math.min(lowest, b.CFrame.Position.Y - b.Size.Y / 2) end
	check("carve boxes reach the End floor (35 below the origin) and no deeper than 1 stud under it",
		lowest <= o.Y + bw.Tunnel.End.Z + 0.5 and lowest >= o.Y + bw.Tunnel.End.Z - 1)
	check("carve boxes are at least the walk width and height", first.Size.X >= bw.Tunnel.Width and first.Size.Y >= bw.Tunnel.Height)
	check("carve boxes are level (no tilt)", near(first.CFrame.UpVector.Y, 1))
	-- mac-87: overworld terrain is an 8-stud crust, so the descending bore ran through void (sky showed through the mesh seams).
	-- Rock packs wrap the underground run before the carve, wider and deeper than it, and never reach the written surface.
	W.Height, W.Layout = O.heightAt, LL
	local packs = W.packs(bw)
	local wraps, under = #packs > 0, true
	for _, b in packs do
		local c, h = b.CFrame, b.Size / 2
		for _, sx in { -1, 1 } do for _, sz in { -1, 1 } do
			local top = c:PointToWorldSpace(Vector3.new(sx * h.X, h.Y, sz * h.Z))
			if top.Y > O.heightAt(top.X, top.Z) - 0.5 then under = false end
		end end
		if b.Size.X < bw.Tunnel.Width + 20 or c.Position.Y - h.Y > b.Floor - 9.5 then wraps = false end
	end
	check("rock packs wrap the underground bore (12+ studs of wall, 10 under the floor)", wraps)
	check("rock packs stay under the written surface", under)
	-- mac-88: the hidden basin. Bowl air inside the ellipse up over every rim top, a mud bed at the floor, rock rim cliffs RimRise over
	-- the ground, and the lake (water to Floor + Water) inside the shore.
	local floorY, waterY = LL.basinLevels(bw)
	local fills = W.basin(bw)
	for _, f in W.lake(bw) do table.insert(fills, f) end
	local byMat, inBowl, rimOk, waterOk, bedOk, maxRim = {}, true, true, true, false, -math.huge
	local rimSpan, rimMats, capTop, caps, capOk, flanks, flankOk = {}, {}, {}, 0, true, 0, true
	local dishWater, dishAir, dishOk = 0, 0, true
	for k = 0, 63 do maxRim = math.max(maxRim, LL.rimTop(bw, k / 64 * 2 * math.pi, O.heightAt)) end
	for _, f in fills do
		local m = f.Material.Name
		byMat[m] = (byMat[m] or 0) + 1
		local c, h = f.CFrame, f.Size / 2
		if m == "Air" or m == "Water" then
			for _, sx in { -1, 1 } do for _, sz in { -1, 1 } do
				local q = c:PointToWorldSpace(Vector3.new(sx * h.X, 0, sz * h.Z))
				if LL.basinEllipse(bw, q.X, q.Z, 1) > 1 then if m == "Air" then inBowl = false else waterOk = false end end
			end end
			if m == "Air" and not f.Dish and (c.Position.Y - h.Y > floorY + 0.01 or c.Position.Y + h.Y < maxRim) then inBowl = false end
			if f.Dish then dishAir += 1; if m ~= "Air" or math.abs(c.Position.Y - h.Y - (floorY - bw.Basin.Deep)) > 0.01 then dishOk = false end end
			local bottom = c.Position.Y - h.Y
			local deep = math.abs(bottom - (floorY - bw.Basin.Deep)) < 0.01
			if deep and m == "Water" then dishWater += 1 end
			if m == "Water" and (math.abs(c.Position.Y + h.Y - waterY) > 0.01 or (math.abs(bottom - floorY) > 0.01 and not deep)) then waterOk = false end
			if (m == "Air" and f.Dish) or deep then
				for _, sx in { -1, 1 } do for _, sz in { -1, 1 } do
					local q = c:PointToWorldSpace(Vector3.new(sx * h.X, 0, sz * h.Z))
					if LL.basinEllipse(bw, q.X, q.Z, -bw.Basin.Shelf + 1) > 1 then dishOk = false end
				end end
			end
		elseif m == "Mud" then
			if math.abs(c.Position.Y + h.Y - floorY) < 0.01 then bedOk = true end
		elseif f.Rim then
			rimMats[m] = true
			local seg = rimSpan[f.Segment] or { lo = math.huge, hi = -math.huge }
			seg.lo, seg.hi = math.min(seg.lo, c.Position.Y - h.Y), math.max(seg.hi, c.Position.Y + h.Y)
			rimSpan[f.Segment] = seg
		elseif f.Cap then
			caps += 1
			local p = c.Position
			if m ~= "LeafyGrass" or p.Y + h.Y < O.heightAt(p.X, p.Z) + bw.Basin.RimRise - 8 then capOk = false end
			capTop[f.Segment] = p.Y - h.Y
		elseif f.Wedge then
			flanks += 1
			-- WedgePart convention: high edge at +Z (toward the rim), low edge at -Z (out over the forest floor)
			local hiEdge, loEdge = c:PointToWorldSpace(Vector3.new(0, h.Y, h.Z)), c:PointToWorldSpace(Vector3.new(0, -h.Y, -h.Z))
			if LL.basinEllipse(bw, hiEdge.X, hiEdge.Z, bw.Basin.Thick + 1) > 1.001 or LL.basinEllipse(bw, loEdge.X, loEdge.Z, bw.Basin.Thick) < 1
				or loEdge.Y > O.heightAt(loEdge.X, loEdge.Z) - 1 or hiEdge.Y < O.heightAt(hiEdge.X, hiEdge.Z) + bw.Basin.RimRise - 14 then flankOk = false end
		end
	end
	for k, seg in rimSpan do
		if seg.lo > floorY - 15 or not capTop[k] or math.abs(seg.hi - capTop[k]) > 0.01 then rimOk = false end
	end
	local nMats = 0
	for _ in rimMats do nMats += 1 end
	check("basin bowl: air strips inside the shore, from the floor up over every rim top", (byMat.Air or 0) >= 20 and inBowl)
	check("basin bed: a mud layer topped at the floor", bedOk)
	-- mac-89: the first rim was one dark rock wall standing on open meadow (captures/mac/bellwood_face/ingame_basin_aerial_before.jpg).
	check("basin rim: strata cliffs from under the floor up to a grass cap, in 2+ stone kinds", rimOk and nMats >= 2 and #(function() local n = {} for k in rimSpan do table.insert(n, k) end return n end)() >= 64)
	check("basin rim: a leafy grass cap on every segment, RimRise over the ground", caps >= 64 and capOk)
	check("basin rim: a grass slope from the rim top down under the forest floor outside", flanks >= 64 and flankOk)
	check("basin lake: water from the floor to Floor + Water, inside the shore", (byMat.Water or 0) >= 20 and waterOk)
	-- mac-89: a 2.5-stud lake showed the bed's voxel ridges as dark dashes. The middle deepens by Deep, Shelf studs in from the shore.
	-- water does not replace solid voxels (mac-89 Play check), so the dish is cut to air first, then filled
	local order, firstAir, firstDeep = W.lake(bw), nil, nil
	for i, f in order do
		if f.Dish and not firstAir then firstAir = i end
		if f.Material.Name == "Water" and math.abs(f.CFrame.Position.Y - f.Size.Y / 2 - (floorY - bw.Basin.Deep)) < 0.01 and not firstDeep then firstDeep = i end
	end
	check("basin lake: a deeper middle Shelf studs in from the shore, cut to air before the water, on the voxel grid",
		dishWater >= 10 and dishAir == dishWater and dishOk and firstAir ~= nil and firstDeep ~= nil and firstAir < firstDeep and (floorY - bw.Basin.Deep) % 4 == 0)
	local route = W.carves(bw)
	local far = route[#route].CFrame.Position
	check("the carve runs on through the passage into the basin", LL.basinEllipse(bw, far.X, far.Z) < 1)

	-- build(): pieces at the foot frames, carve only after the region is ready, nothing carved when no piece loads.
	local fills, readyAsked = 0, nil
	local env = table.clone(base)
	local fillOrder, wedges = {}, 0
	local ws = { Terrain = { FillBlock = function(_, _, _, m) fills += 1; table.insert(fillOrder, m.Name) end,
		FillWedge = function(_, _, _, m) fills += 1; wedges += 1; table.insert(fillOrder, m.Name) end } }
	env.game = { GetService = function(_, n) if n == "Workspace" then return ws end return services[n] end }
	env.task = { spawn = function(f) f() end }
	local W2 = load("src/server/Services/LandmarkWorld.luau", env, "LandmarkWorld")
	local placedAt = {}
	W2.Kit = { place = function(piece, frame) placedAt[piece] = frame; local m = Instance.new("Model"); m.Name = piece; return m end }
	W2.Layout = LL
	W2.Height = O.heightAt
	local forest = Instance.new("Folder")
	W2.build({ Forest = forest }, function(region) readyAsked = region; return true end)
	local lm = forest:FindFirstChild("Landmark_Bellwood")
	local footW = W2.frame(bw) * CFrame.new(bw.Pieces.Face.Foot.X, bw.Pieces.Face.Foot.Y, bw.Pieces.Face.Foot.Z)
	check("build places every piece in the region folder", lm ~= nil and lm:FindFirstChild("Bellwood_GiantFace") and lm:FindFirstChild("Bellwood_GiantCrown"))
	check("pieces sit at origin * yaw * Foot", placedAt.Bellwood_GiantFace and (placedAt.Bellwood_GiantFace.Position - footW.Position).Magnitude < 1e-3)
	-- mac-90: the Sunken Temple hall stands in the lake, its front (model +Z) toward the passage exit, in the right half of the exit view.
	local T = bw.Basin.Temple
	local hall = placedAt.Bellwood_TempleHall
	local spot = LL.templeSpot(bw)
	local exitW = W2.kitToWorld(bw, bw.Tunnel.Passage[#bw.Tunnel.Passage])
	local hallOk = hall ~= nil and lm:FindFirstChild("Bellwood_TempleHall") ~= nil
	if hall then
		local origin = hall * CFrame.new(-T.Foot.X, -T.Foot.Y, -T.Foot.Z)
		local toExit = Vector3.new(exitW.X - origin.X, 0, exitW.Z - origin.Z).Unit
		local view = Vector3.new(spot.X - exitW.X, 0, spot.Z - exitW.Z).Unit
		local c = LL.basinCentre(bw)
		local look = Vector3.new(c.X - exitW.X, 0, c.Z - exitW.Z).Unit
		local right = look:Cross(Vector3.yAxis)
		local ang = math.deg(math.acos(math.clamp(view:Dot(look), -1, 1)))
		hallOk = hallOk and (origin.Position - Vector3.new(spot.X, spot.Y, spot.Z)).Magnitude < 1e-3
			and origin.LookVector:Dot(-toExit) > 0.999 -- model +Z = -LookVector faces the exit
			and math.abs(origin.UpVector.Y - 1) < 1e-6 and view:Dot(right) > 0 and ang >= 6 and ang <= 30
	end
	check("temple hall stands at its spot facing the passage exit, right of centre in the exit view", hallOk)
	check("temple collision: stone platform precise, lacquer frame default, roofs never collide",
		W2.Fidelity.Stone == Enum.CollisionFidelity.PreciseConvexDecomposition and W2.Fidelity.Lacquer == Enum.CollisionFidelity.Default
		and W2.Fidelity.Tiles == nil and W2.Fidelity.Soffit == nil)
	-- mac-91: the gate towers stand on the left of the exit view, front (model +Z) to the basin centre, stair climbing to the shore.
	local G = bw.Basin.Gate
	local gate = placedAt.Bellwood_GateTowers
	local gspot = LL.gateSpot(bw)
	local gateOk = gate ~= nil and lm:FindFirstChild("Bellwood_GateTowers") ~= nil
	local gframe = W2.gateFrame(bw)
	if gate then
		local origin = gate * CFrame.new(-G.Foot.X, -G.Foot.Y, -G.Foot.Z)
		local c = LL.basinCentre(bw)
		local toCentre = Vector3.new(c.X - origin.X, 0, c.Z - origin.Z).Unit
		local view = Vector3.new(gspot.X - exitW.X, 0, gspot.Z - exitW.Z).Unit
		local look = Vector3.new(c.X - exitW.X, 0, c.Z - exitW.Z).Unit
		local right = look:Cross(Vector3.yAxis)
		local ang = math.deg(math.acos(math.clamp(view:Dot(look), -1, 1)))
		gateOk = gateOk and (origin.Position - Vector3.new(gspot.X, gspot.Y, gspot.Z)).Magnitude < 1e-3
			and origin.LookVector:Dot(-toCentre) > 0.999 -- model +Z = -LookVector faces the basin centre
			and math.abs(origin.UpVector.Y - 1) < 1e-6 and view:Dot(right) < 0 and ang >= 6 and ang <= 35
	end
	check("gate towers stand at their spot facing the basin centre, left of centre in the exit view", gateOk)
	check("gate collision: stone stair precise, roots hull, roofs and ribbons never collide",
		W2.Fidelity.Stone == Enum.CollisionFidelity.PreciseConvexDecomposition and W2.Fidelity.Root == Enum.CollisionFidelity.Hull
		and W2.Fidelity.Tiles == nil and W2.Fidelity.Soffit == nil and W2.Fidelity.Ribbon == nil and W2.Fidelity.Roots == nil)
	-- The landing (Landing over the pivot) meets a terrain ledge that runs back to the rim; a footing fills the deep dish under the
	-- steps and towers up to the lake bed so nothing hangs over the dish.
	local gfills = W2.gateFills(bw)
	local landingTop = gspot.Y + G.Landing
	local ledgeOk, footOk = false, false
	local function contains(f, p)
		local lp = f.CFrame:PointToObjectSpace(p)
		return math.abs(lp.X) <= f.Size.X / 2 + 1e-3 and math.abs(lp.Y) <= f.Size.Y / 2 + 1e-3 and math.abs(lp.Z) <= f.Size.Z / 2 + 1e-3
	end
	for _, f in gfills do
		local top = f.CFrame.Position.Y + f.Size.Y / 2
		local back = gframe:PointToWorldSpace(Vector3.new(0, 0, G.Back - 1))
		local behind = f.CFrame:PointToWorldSpace(Vector3.new(0, 0, f.Size.Z / 2)) -- the far end (lookAt keeps +Z backward)
		local farEnd = gframe:PointToWorldSpace(Vector3.new(0, 0, G.Back - 18))
		if math.abs(top - landingTop) <= 1.5 and contains(f, Vector3.new(back.X, top - 0.5, back.Z))
			and LL.basinEllipse(bw, farEnd.X, farEnd.Z) >= 1 and contains(f, Vector3.new(farEnd.X, top - 0.5, farEnd.Z)) then ledgeOk = true end
		local step = gframe:PointToWorldSpace(Vector3.new(0, 0, G.Steps))
		local tw = gframe:PointToWorldSpace(Vector3.new(13, 0, 0))
		if math.abs(top - floorY) < 1e-3 and f.Material.Name ~= "Air" and f.Material.Name ~= "Water"
			and contains(f, Vector3.new(step.X, floorY - bw.Basin.Deep, step.Z)) and contains(f, Vector3.new(tw.X, floorY - bw.Basin.Deep, tw.Z)) then footOk = true end
	end
	check("gate landing meets a terrain ledge (top within 1.5) that runs back into the rim", ledgeOk)
	check("gate footing fills the deep dish under the steps and towers up to the lake bed", footOk)
	local lastRock, lastAir = 0, 0
	for i = 1, #fillOrder - #gfills do local m = fillOrder[i]; if m == "Rock" then lastRock = i elseif m == "Air" then lastAir = i end end
	check("pack, basin, then the bore and passage cut through the rim, the lake, then the gate fills, after the region's terrain is ready",
		readyAsked == "Forest" and fills == #packs + #W2.basin(bw) + #boxes + #W2.lake(bw) + #gfills and #gfills > 0
		and fillOrder[1] == "Rock" and fillOrder[#fillOrder - #gfills] == "Water"
		and lastAir > lastRock and lm:GetAttribute("BoreCarved") == true and lm:GetAttribute("BasinSculpted") == true)
	local nWedge = 0
	for _, f in W2.basin(bw) do if f.Wedge then nWedge += 1 end end
	check("build fills the rim slopes as wedges", wedges == nWedge and nWedge > 0)
	-- mac-89: rain fell inside the bore (captures/mac/bellwood_face/ingame_tunnel_rain_leak.jpg). Invisible roofs tagged AsuraShelter
	-- (WeatherController casts 60 up) over the whole route; terrain cannot be tagged.
	local shelter = lm:FindFirstChild("TunnelShelter")
	local roofs, roofOk = shelter and shelter:GetChildren() or {}, shelter ~= nil
	for _, r in roofs do
		if not (r:IsA("BasePart") and r:HasTag("AsuraShelter") and r.Anchored and not r.CanCollide and not r.CanTouch and r.CanQuery
			and r.Transparency == 1 and not r.CastShadow) then roofOk = false end
	end
	local path = {}
	for _, p in bw.Tunnel.Path do table.insert(path, W2.kitToWorld(bw, p)) end
	for i = 2, #bw.Tunnel.Passage do table.insert(path, W2.kitToWorld(bw, bw.Tunnel.Passage[i])) end
	local overBowl = false
	for _, r in roofs do
		for _, sx in { -1, 1 } do for _, sz in { -1, 1 } do
			local q = r.CFrame:PointToWorldSpace(Vector3.new(sx * r.Size.X / 2, 0, sz * r.Size.Z / 2))
			if LL.basinEllipse(bw, q.X, q.Z, -2) < 1 then overBowl = true end
		end end
	end
	local covered2 = 0
	local samples2 = 0
	for i = 2, #path - 1 do
		for _, t in { 0, 0.25, 0.5, 0.75 } do
			local q = path[i]:Lerp(path[i + 1], t) - Vector3.new(0, 5, 0)
			if LL.basinEllipse(bw, q.X, q.Z) >= 1 then -- under rock: must be covered
				samples2 += 1
				for _, r in roofs do
					local lp = r.CFrame:PointToObjectSpace(q)
					if math.abs(lp.X) <= r.Size.X / 2 and math.abs(lp.Z) <= r.Size.Z / 2 and r.Position.Y > q.Y and r.Position.Y < q.Y + 60 then covered2 += 1; break end
				end
			end
		end
	end
	check(string.format("tunnel shelter roofs cover the walk under rock (%d/%d) and never hang over the open bowl", covered2, samples2),
		roofOk and covered2 == samples2 and samples2 > 10 and not overBowl)
	-- mac-87: the bore was pitch dark at noon. Each niche: an always-on shadowless ember plus a night lantern light (tagged, off until dusk).
	local niches, nicheOk = 0, true
	for _, c in lm:GetChildren() do
		if c.Name == "TunnelLantern" then
			niches += 1
			local flame = c:FindFirstChild("Flame")
			local ember, night = flame and flame:FindFirstChild("Ember"), flame and flame:FindFirstChild("LanternLight")
			if not (flame and flame.Material == Enum.Material.Neon and not flame.CanCollide and flame.Anchored
				and ember and ember.Enabled and not ember.Shadows and night and not night.Enabled and not night.Shadows
				and night:HasTag("AsuraLanternLight") and not ember:HasTag("AsuraLanternLight")) then nicheOk = false end
			local want = W2.kitToWorld(bw, bw.Tunnel.Lanterns[niches])
			if flame and (flame.Position - want).Magnitude > 1e-3 then nicheOk = false end
		end
	end
	check("tunnel lantern niches: one per layout point, ember always on, night light tagged", niches == #bw.Tunnel.Lanterns and nicheOk)
	-- Spec: dripping water and moss motes in the bore. One invisible emitter box under the roof at each inner Path point.
	local fx = lm:FindFirstChild("TunnelFx")
	local boxes, fxOk = fx and fx:GetChildren() or {}, fx ~= nil
	for i, b in boxes do
		local want = W2.kitToWorld(bw, bw.Tunnel.Path[i + 1])
		local drips, motes = b:FindFirstChild("Drips"), b:FindFirstChild("Motes")
		if not (b:IsA("BasePart") and b.Anchored and not b.CanCollide and not b.CanQuery and not b.CanTouch and b.Transparency == 1
			and math.abs(b.Position.X - want.X) < 1e-3 and math.abs(b.Position.Z - want.Z) < 1e-3
			and b.Position.Y > want.Y and b.Position.Y < want.Y + bw.Tunnel.Radius
			and drips and drips.Acceleration.Y < -20 and drips.Rate > 0 and motes and motes.Rate > 0 and motes.LightEmission > 0
			and string.match(drips.Texture, "^rbxassetid://%d+$") and string.match(motes.Texture, "^rbxassetid://%d+$")) then fxOk = false end
	end
	check("tunnel drips and moss motes: one roof box per inner path point", fxOk and #boxes == #bw.Tunnel.Path - 2)
	-- the gate GLB is not uploaded yet: build warns, places the rest, and leaves the lake without the gate's ledge
	fills = 0
	W2.Kit = { place = function(piece) if piece == "Bellwood_GateTowers" then return nil end; local m = Instance.new("Model"); m.Name = piece; return m end }
	local forest3 = Instance.new("Folder")
	local okNoGate = pcall(W2.build, { Forest = forest3 }, function() return true end)
	local lm3 = forest3:FindFirstChild("Landmark_Bellwood")
	check("gate kit missing: build still runs, places the rest, and fills no gate ledge",
		okNoGate and lm3 ~= nil and lm3:FindFirstChild("Bellwood_TempleHall") ~= nil and lm3:FindFirstChild("Bellwood_GateTowers") == nil
		and fills == #packs + #W2.basin(bw) + #W2.carves(bw) + #W2.lake(bw))
	fills = 0
	W2.Kit = { place = function() return nil end }
	local forest2 = Instance.new("Folder")
	W2.build({ Forest = forest2 }, function() return true end)
	check("no piece loaded: no hole is carved", fills == 0)
end

print(string.format("vesperhold loader: %d passed, %d failed", passed, failed))
if failed > 0 then error("vesperhold loader checks failed") end
