--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/BiomeDressingService
-- Header (new-file rule). Supersedes: nothing. Searched src/ for *BiomeDressing* (only shared/BiomeDressing.luau, the data this raises) and the
-- outputs ledger for BiomeDressingService (only the planned D4 rows); SliceDressingService is the Bellwood slice's builder and stays as is.
-- Linked from LEDGER.md (row "D4 biome builder", workers/22c-biome-builder.md). Why a new file: the slice builder raises one forest cell grid
-- once, eagerly; the four other biomes need a region-lazy, distance-thinned, budgeted builder that SliceDressingService cannot be stretched to be.
-- Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.
--
-- Raises Map_Overworld/BiomeDressing/<Region>/{Cells/Cell_<i>_<j>, Landmarks/<Id>} from BiomeDressing.plan(region) for GoldenRavine, AridBasin,
-- Snowfields and MountainAscent.
-- Lazy per region: a region is planned (time-sliced) only once a player is within ACTIVATE studs of its box, and unloaded after UNLOAD_AFTER
-- seconds with nobody near. Its plan is memoised, so coming back costs no recomputation.
-- Distance thinning: every SWEEP seconds each cell near a player builds the placements BiomeDressing.visibleAt(pl, d) allows (nearest cell
-- first) and drops those that fell behind by more than HYSTERESIS; far scatter thins, structures hold to their tier's Reach, landmarks stay.
-- Budget: live placeholder parts per region never pass BiomeDressing.PartBudget (a piece that would pass it is refused and counted).
-- Frame cost: all work goes through pace(), which yields (task.wait) after SLICE seconds, so the server heartbeat stays at or above 45 Hz.
-- Readiness: a cell builds when every OverworldTerrain tile it needs is written; a set piece at an altar also waits for OverworldService.Ready(altarId).
-- Resolution (makePiece): ServerStorage/BiomeKit/<Piece> template, else the registry (per sub-mesh MeshPart + SurfaceAppearance), else a registered
-- asset fit (BiomeDressing.Assets, ids from assets/*_UPLOADED.json), else the placeholder built from the piece's Silhouette data. Ids are never written here.
-- Ground: a raycast down onto Terrain, falling back to heightAt + 2 (written voxels surface about 2 studs above heightAt).
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("AsurasPath")
local Overworld = require(Shared.Shared.Overworld) :: any
local Biome = require(Shared.Shared.BiomeDressing) :: any
local Slice = require(Shared.Shared.SliceDressing) :: any
local Terrain = require(script.Parent:WaitForChild("OverworldTerrain") :: ModuleScript) :: any
local OverworldWorld = require(script.Parent:WaitForChild("OverworldService") :: ModuleScript) :: any

local BiomeDressingService = {}

local VOXEL_LIFT = 2 -- written terrain voxels surface this far above heightAt (Overworld.luau Rings note)
local SLICE = 0.0025 -- seconds of work before yielding: about 15% of a 60 Hz frame
local SWEEP = 0.5 -- seconds between passes over the cells near a player
local ACTIVATE = 1000 -- studs from a region's box at which it is planned and raised (the largest tier Reach is 900)
local UNLOAD_AFTER = 60 -- seconds with no player within ACTIVATE before a region's instances are removed
local HYSTERESIS = 1.15 -- a piece is dropped only once it would also be hidden at distance / HYSTERESIS
local FOLIAGE_TAG = "AsuraFoliageShadow" -- LandscapeBudget turns these parts' shadows off beyond AsuraShadowDistance
local KIT_FOLDER = "BiomeKit"

local running = false
local root: Folder? = nil
local regions: { [string]: any } = {}
local meshCache: { [string]: Instance | boolean } = {}

local sliceStart = os.clock()
-- Yield once SLICE seconds have passed since the last yield; unwinds a stopped service out of whatever it was doing.
local function pace()
	if os.clock() - sliceStart >= SLICE then
		task.wait()
		sliceStart = os.clock()
		if not running then
			error("BiomeDressingService stopped")
		end
	end
end

-- Replaceable for a Studio capture that wants flat ground: (x, z, heightAt) -> surface Y.
BiomeDressingService.Ground = nil :: ((number, number, number) -> number)?

local function ground(x: number, z: number, surface: number): number
	if BiomeDressingService.Ground then
		return BiomeDressingService.Ground(x, z, surface)
	end
	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { terrain }
		local hit = Workspace:Raycast(Vector3.new(x, surface + 60, z), Vector3.new(0, -120, 0), params)
		if hit then
			return hit.Position.Y
		end
	end
	return surface + VOXEL_LIFT
end

-------------------------------------------------------------------------------------------------
-- Piece -> Instance (the one swap point)
-------------------------------------------------------------------------------------------------

local function tagPart(p: BasePart, sub: any, def: any, collide: boolean)
	p.Anchored = true
	p.CanCollide = collide
	p.CanTouch = false
	p.CanQuery = collide
	p.CastShadow = def.Size[2] > 5 -- ferns and grass are too small to shade anything
	p:SetAttribute("BiomeSub", sub.Name)
	if sub.Lod then
		p:SetAttribute("LodDetail", true) -- the client may drop these beyond ~150 studs
	end
	if sub.Material == "Grass" then
		CollectionService:AddTag(p, FOLIAGE_TAG)
		p:SetAttribute("AsuraShadowDistance", 120)
	end
end

local function newPart(parent: Instance, name: string, shape: string, size: Vector3, cf: CFrame, sub: any, def: any): BasePart
	local p: BasePart = if shape == "Wedge" then Instance.new("WedgePart") else Instance.new("Part")
	if shape == "Cylinder" then
		(p :: Part).Shape = Enum.PartType.Cylinder
	end
	p.Name = name
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = (Enum.Material :: any)[sub.Material]
	p.Color = Color3.fromRGB(sub.Color[1], sub.Color[2], sub.Color[3])
	p.Size = size
	p.CFrame = cf
	tagPart(p, sub, def, sub.Collide)
	p.Parent = parent
	return p
end

-- Placeholder: the piece's Silhouette primitives (fractions of its box, scaled by the placement) or its step blocks. Data only: a mesh swap
-- never touches this function.
local function placeholder(pl: any, frame: CFrame, def: any): Instance
	local X, Y, Z = def.Size[1] * pl.Scale, def.Size[2] * pl.Scale, def.Size[3] * pl.Scale
	local holder = Instance.new("Model")
	local name = pl.Piece .. "__Placeholder"
	if def.Arch == "Steps" then
		local sub = def.Subs[1]
		for i = 0, sub.Steps - 1 do
			local h = sub.Rise * (i + 1) * pl.Scale
			local z = Z / 2 - sub.Tread * pl.Scale * (i + 0.5) -- the low step is at +Z, the stair climbs toward -Z
			newPart(holder, name, "Block", Vector3.new(sub.Width * pl.Scale, h, sub.Tread * pl.Scale), frame * CFrame.new(0, h / 2, z), sub, def)
		end
	else
		for _, t in def.Sil do
			local sub = def.Subs[t.Sub]
			local h = (t.Y1 - t.Y0) * Y
			local cf = frame * CFrame.new(t.Cx * X, (t.Y0 + t.Y1) / 2 * Y, t.Cz * Z)
			if t.Shape == "Cylinder" then
				newPart(holder, name, "Cylinder", Vector3.new(h, t.W * X, t.D * Z), cf * CFrame.Angles(0, 0, math.rad(90)), sub, def)
			else
				newPart(holder, name, t.Shape, Vector3.new(t.W * X, h, t.D * Z), cf, sub, def)
			end
		end
	end
	local kids = holder:GetChildren()
	if #kids == 1 then -- a single primitive needs no Model: fewer instances for grass, ferns, walls
		local only = kids[1]
		only.Parent = nil
		holder:Destroy()
		return only
	end
	return holder
end

local function kitTemplate(piece: string): Model?
	local ok, storage = pcall(function() return game:GetService("ServerStorage") end)
	local kit = if ok and storage then storage:FindFirstChild(KIT_FOLDER) else nil
	local template = if kit then kit:FindFirstChild(piece) else nil
	if template and template:IsA("Model") then
		return template
	end
	return nil
end

-- One template MeshPart (with its SurfaceAppearance) per registry sub-mesh, cached; clones are cheap and share the mesh.
local function meshTemplate(key: string, entry: any): Instance?
	local hit = meshCache[key]
	if hit ~= nil then
		return if hit == false then nil else hit :: Instance
	end
	local ok, tpl = pcall(function()
		return (game:GetService("AssetService") :: any):CreateMeshPartAsync(entry.MeshId, { CollisionFidelity = Enum.CollisionFidelity.Box })
	end)
	if not ok then
		warn(string.format("[BiomeDressing] mesh %s not created: %s", tostring(entry.MeshId), tostring(tpl)))
		tpl = nil
	end
	if tpl then
		local sa = Instance.new("SurfaceAppearance")
		for _, map in { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" } do
			local id = entry[map]
			if type(id) == "string" and id ~= "" then
				(sa :: any)[map] = id
			end
		end
		sa.Parent = tpl
	end
	meshCache[key] = tpl or false
	return tpl
end

-- Registry-built piece: every sub-mesh must resolve (a half tree is worse than the placeholder). The biome registry first, then the slice one
-- (the pieces both modules share are keyed by the same names).
local function registryTry(pl: any, frame: CFrame, def: any, base: string): Instance?
	local reg: any = Biome.Registry[base] or Slice.Registry[base]
	if type(reg) ~= "table" then
		return nil
	end
	local list = {}
	for _, sb in def.Subs do
		local key = base .. "__" .. sb.Name
		local entry = reg[key]
		if type(entry) ~= "table" or type(entry.MeshId) ~= "string" or entry.MeshId == "" then
			return nil
		end
		local c = entry.center
		if c == nil and #def.Subs > 1 then
			return nil
		end
		table.insert(list, { Key = key, Sub = sb, Entry = entry, Center = if c then Vector3.new(c[1], c[2], c[3]) else Vector3.new(0, def.Size[2] / 2, 0) })
	end
	local made: { Instance } = {}
	for _, r in list do
		local tpl = meshTemplate(r.Key, r.Entry)
		if not tpl then
			for _, m in made do m:Destroy() end
			return nil
		end
		local p = tpl:Clone() :: any
		p.Name = r.Key
		p.Size = p.Size * pl.Scale
		p.CFrame = frame * CFrame.new(r.Center * pl.Scale)
		tagPart(p, r.Sub, def, def.Structure == true and not r.Sub.Lod)
		table.insert(made, p)
	end
	if #made == 1 then
		return made[1]
	end
	local holder = Instance.new("Model")
	for _, m in made do m.Parent = holder end
	return holder
end

-- A hero slot (Biome.Slots) keys its registry rows by the refined hero's name; absent that, the hero pack's own rows (keyed by the slot name, subs
-- of the slice definition) still stand in.
local function registryPiece(pl: any, frame: CFrame, def: any): Instance?
	local made = registryTry(pl, frame, def, def.Key or pl.Piece)
	local heroDef = Slice.Pieces[pl.Piece]
	if made == nil and def.Key ~= nil and heroDef ~= nil then
		return registryTry(pl, frame, heroDef, pl.Piece)
	end
	return made
end

-- Registered-asset fit (BiomeDressing.Assets): clone the ServerStorage model, keep the named MeshPart, scale it to sit inside the piece box.
local function assetPiece(pl: any, frame: CFrame, def: any): Instance?
	local a = Biome.Assets[pl.Piece]
	if not a then
		return nil
	end
	local ok, node = pcall(function() return game:GetService("ServerStorage") end)
	if not ok or not node then
		return nil
	end
	for _, name in string.split(a.Path, "/") do
		node = node:FindFirstChild(name)
		if not node then
			return nil
		end
	end
	local m = Instance.new("Model")
	for _, d in node:GetDescendants() do
		if d:IsA("MeshPart") and (a.Part == nil or d.Name == a.Part) then
			d:Clone().Parent = m
		end
	end
	if node:IsA("MeshPart") and (a.Part == nil or node.Name == a.Part) then
		node:Clone().Parent = m
	end
	if #m:GetChildren() == 0 then
		m:Destroy()
		return nil
	end
	local _, size = m:GetBoundingBox()
	local S = def.Size
	m:ScaleTo(m:GetScale() * math.min(S[1] / math.max(size.X, 0.01), S[2] / math.max(size.Y, 0.01), S[3] / math.max(size.Z, 0.01)) * pl.Scale)
	local box, fitted = m:GetBoundingBox()
	m:PivotTo(frame * CFrame.new(0, fitted.Y / 2, 0) * box:ToObjectSpace(m:GetPivot())) -- bounding-box foot centre onto the frame
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			tagPart(d, { Name = "Asset", Material = "" }, def, def.Structure == true)
		end
	end
	return m
end

-- baseY is the ground at the placement's foot; the piece sinks by its Sink so slopes show no gap.
local function makePiece(pl: any, baseY: number): Instance
	local def = Biome.Pieces[pl.Piece]
	local frame = CFrame.new(pl.X, baseY - pl.Sink * pl.Scale, pl.Z) * CFrame.Angles(0, math.rad(pl.Yaw), 0)
	local inst: Instance
	local template = kitTemplate(pl.Piece)
	if template then
		local m = template:Clone()
		if pl.Scale ~= 1 then
			m:ScaleTo(pl.Scale)
		end
		m:PivotTo(frame)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				if def.Structure ~= true then
					d.CanCollide = false
				end
			end
		end
		inst = m
		inst:SetAttribute("BiomeReal", true)
	else
		local real = registryPiece(pl, frame, def) or assetPiece(pl, frame, def)
		inst = real or placeholder(pl, frame, def)
		if real then inst:SetAttribute("BiomeReal", true) end
	end
	inst.Name = pl.Id
	inst:SetAttribute("BiomePiece", pl.Piece)
	inst:SetAttribute("BiomeClass", pl.Class)
	inst:SetAttribute("BiomeTier", pl.Tier)
	return inst
end

-------------------------------------------------------------------------------------------------
-- Regions
-------------------------------------------------------------------------------------------------

local function countParts(inst: Instance): number
	local n = if inst:IsA("BasePart") then 1 else 0
	for _, d in inst:GetDescendants() do
		n += if d:IsA("BasePart") then 1 else 0
	end
	return n
end

local function viewers(): { { X: number, Z: number } }
	local out = {}
	for _, player in Players:GetPlayers() do
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			table.insert(out, { X = hrp.Position.X, Z = hrp.Position.Z })
		end
	end
	return out
end

local function nearest(x: number, z: number, list: { any }): number
	local best = math.huge
	for _, v in list do
		best = math.min(best, (x - v.X) ^ 2 + (z - v.Z) ^ 2)
	end
	return math.sqrt(best)
end

-- Studs from a point to a region's box (0 inside).
local function boxDistance(b: any, x: number, z: number): number
	local dx = math.max(math.abs(x - b.Center.X) - b.Size.X * 0.5, 0)
	local dz = math.max(math.abs(z - b.Center.Z) - b.Size.Z * 0.5, 0)
	return math.sqrt(dx * dx + dz * dz)
end

local function newRegion(id: string): any
	return { Id = id, Plan = nil, Planning = false, RetryAt = 0, IdleSince = nil, Folder = nil, CellFolder = nil, LandmarkFolder = nil, LandmarkList = {}, Models = {}, CellCount = {}, Built = {},
		Ready = {}, Bad = {}, Parts = 0, Placements = 0, Refused = 0, Failed = 0, PlanSeconds = 0, Meta = {} }
end

local function publish(st: any)
	if st.Folder then
		st.Folder:SetAttribute("Parts", st.Parts)
		st.Folder:SetAttribute("Placements", st.Placements)
		st.Folder:SetAttribute("Refused", st.Refused)
	end
end

local function unload(st: any)
	if st.Folder then
		st.Folder:Destroy()
	end
	st.Folder, st.CellFolder, st.LandmarkFolder = nil, nil, nil
	st.Models, st.CellCount, st.Built, st.Ready, st.Bad = {}, {}, {}, {}, {}
	st.Parts, st.Placements = 0, 0
end

local function planRegion(st: any)
	local t0 = os.clock()
	local ok, result = pcall(Biome.plan, st.Id, false, pace)
	st.Planning = false
	if not running then
		return
	end
	if not ok then
		st.RetryAt = os.clock() + 30
		warn(string.format("[BiomeDressing] %s plan failed: %s", st.Id, tostring(result)))
		return
	end
	st.Plan = result
	st.PlanSeconds = os.clock() - t0
	local F = Overworld.Frame
	for key in result.Cells do
		local i, j = string.match(key, "^(%-?%d+),(%-?%d+)$")
		st.Meta[key] = { X = F.MinX + (tonumber(i) :: number + 0.5) * Biome.Cell, Z = F.MinZ + (tonumber(j) :: number + 0.5) * Biome.Cell }
	end
	st.LandmarkList = {}
	for _, pl in result.Placements do
		if pl.Landmark then table.insert(st.LandmarkList, pl) end
	end
	print(string.format("[BiomeDressing] %s planned: %d placements, %d/%d parts (%d trimmed), %d set pieces, %.1f s.", st.Id, #result.Placements, result.Parts, result.Budget, result.Trimmed, #result.Sets, st.PlanSeconds))
end

local function cellReady(st: any, key: string): boolean
	if st.Ready[key] then
		return true
	end
	for need in st.Plan.Cells[key].Needs do
		if not Terrain.Manifest[need] then
			return false
		end
	end
	st.Ready[key] = true
	return true
end

local function dropPiece(st: any, pl: any)
	local inst = st.Built[pl.Id]
	if not inst then
		return
	end
	local parts = countParts(inst)
	inst:Destroy()
	st.Built[pl.Id] = nil
	st.Parts -= parts
	st.Placements -= 1
	local n = (st.CellCount[pl.Cell] or 1) - 1
	st.CellCount[pl.Cell] = if n > 0 then n else nil
	if n <= 0 and st.Models[pl.Cell] then
		st.Models[pl.Cell]:Destroy()
		st.Models[pl.Cell] = nil
	end
end

local function buildPiece(st: any, pl: any): boolean
	if st.Parts + pl.Parts > Biome.PartBudget then
		st.Refused += 1 -- the region is full: nearer pieces already hold the budget
		return false
	end
	local ok, inst = pcall(function()
		return makePiece(pl, ground(pl.GX, pl.GZ, pl.Y))
	end)
	if not ok then
		st.Bad[pl.Id] = true
		st.Failed += 1
		warn(string.format("[BiomeDressing] %s skipped: %s", pl.Id, tostring(inst)))
		return false
	end
	local piece = inst :: Instance
	local parts = countParts(piece)
	if st.Parts + parts > Biome.PartBudget then -- a real mesh made more parts than the plan counted
		piece:Destroy()
		st.Refused += 1
		return false
	end
	if pl.Landmark then
		local holder = if piece:IsA("Model") then piece else Instance.new("Model")
		if holder ~= piece then
			piece.Parent = holder
			holder.Name = pl.Id
		end
		holder.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		holder.Parent = st.LandmarkFolder
		st.Built[pl.Id] = holder
	else
		local model = st.Models[pl.Cell]
		if not model then
			model = Instance.new("Model")
			model.Name = "Cell_" .. (string.gsub(pl.Cell, ",", "_"))
			model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
			model:SetAttribute("Cell", pl.Cell)
			model.Parent = st.CellFolder
			st.Models[pl.Cell] = model
		end
		piece.Parent = model
		st.Built[pl.Id] = piece
	end
	st.CellCount[pl.Cell] = (st.CellCount[pl.Cell] or 0) + 1
	st.Parts += parts
	st.Placements += 1
	return true
end

-- One pass over a raised region: nearest cell first, build what thinning allows, drop what fell behind, then the landmarks.
local function sweep(st: any, list: { any })
	local plan = st.Plan
	if not st.Folder then
		local f = Instance.new("Folder")
		f.Name = st.Id
		f:SetAttribute("AsuraRegion", st.Id)
		f:SetAttribute("PartBudget", Biome.PartBudget)
		st.CellFolder, st.LandmarkFolder = Instance.new("Folder"), Instance.new("Folder")
		st.CellFolder.Name, st.LandmarkFolder.Name = "Cells", "Landmarks"
		st.CellFolder.Parent, st.LandmarkFolder.Parent = f, f
		f.Parent = root
		st.Folder = f
	end
	local order: { any } = {}
	for key, meta in st.Meta do
		table.insert(order, { Key = key, D = nearest(meta.X, meta.Z, list) })
	end
	table.sort(order, function(a: any, b: any): boolean
		if a.D == b.D then return a.Key < b.Key end
		return a.D < b.D
	end)
	local cutoff = Biome.Reach.Large * HYSTERESIS + Biome.Cell
	for _, e in order do
		pace()
		local cell = plan.Cells[e.Key]
		if e.D > cutoff then
			for _, pl in cell.Placements do
				if st.Built[pl.Id] and not pl.Landmark then dropPiece(st, pl) end
			end
		elseif cellReady(st, e.Key) then
			for _, pl in cell.Placements do
				if not pl.Landmark and not st.Bad[pl.Id] then
					local d = nearest(pl.X, pl.Z, list)
					local have = st.Built[pl.Id]
					if not have and Biome.visibleAt(pl, d) then
						if not pl.SiteReady or OverworldWorld.Ready(pl.SiteReady) then
							buildPiece(st, pl)
							pace()
						end
					elseif have and not Biome.visibleAt(pl, d / HYSTERESIS) then
						dropPiece(st, pl)
					end
				end
			end
		end
	end
	for _, pl in st.LandmarkList do -- the far silhouettes: raised once their tiles are written, never thinned
		if not st.Built[pl.Id] and not st.Bad[pl.Id] and cellReady(st, pl.Cell) then
			buildPiece(st, pl)
			pace()
		end
	end
	publish(st)
end

local function run()
	local map = Workspace:WaitForChild(Overworld.Root, 60)
	if not map or not running then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "BiomeDressing"
	folder.Parent = map
	root = folder
	for _, id in Biome.Order do
		regions[id] = newRegion(id)
	end
	while running do
		local list = viewers()
		for _, id in Biome.Order do
			local st = regions[id]
			local bounds = Overworld.Regions[id].Bounds
			local near = math.huge
			for _, v in list do
				near = math.min(near, boxDistance(bounds, v.X, v.Z))
			end
			if near <= ACTIVATE then
				st.IdleSince = nil
				if not st.Plan and not st.Planning and os.clock() >= st.RetryAt then
					st.Planning = true
					task.spawn(planRegion, st)
				end
				if st.Plan then
					local ok, problem = pcall(sweep, st, list)
					if not ok and running then
						warn(string.format("[BiomeDressing] %s sweep failed: %s", id, tostring(problem)))
					end
				end
			elseif st.Folder then
				st.IdleSince = st.IdleSince or os.clock()
				if os.clock() - st.IdleSince >= UNLOAD_AFTER then
					unload(st)
				end
			end
		end
		task.wait(SWEEP)
	end
end

-------------------------------------------------------------------------------------------------
-- Lifecycle
-------------------------------------------------------------------------------------------------

-- Start after OverworldService.Start() (Map_Overworld and the terrain generator exist). Inactive overworld: does nothing.
function BiomeDressingService.Start()
	if not Overworld.Active then
		return
	end
	assert(not running, "BiomeDressingService already started")
	running = true
	task.spawn(run)
end

function BiomeDressingService.Stats(): any
	local out: { [string]: any } = { Budget = Biome.PartBudget }
	for id, st in regions do
		out[id] = { Planned = st.Plan ~= nil, Planning = st.Planning, Parts = st.Parts, Placements = st.Placements, Refused = st.Refused, Failed = st.Failed, PlanSeconds = st.PlanSeconds }
	end
	return out
end

function BiomeDressingService.Destroy()
	running = false
	if root then
		root:Destroy()
		root = nil
	end
	table.clear(regions)
	table.clear(meshCache)
end

-- Exposed for a Studio check of one piece.
BiomeDressingService.Build = { Piece = makePiece }

return BiomeDressingService
