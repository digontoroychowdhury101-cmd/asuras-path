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

print(string.format("vesperhold loader: %d passed, %d failed", passed, failed))
if failed > 0 then error("vesperhold loader checks failed") end
