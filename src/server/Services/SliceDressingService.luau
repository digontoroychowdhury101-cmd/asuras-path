--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/SliceDressingService
-- Open-world issue 12 slice (Gateway Glade -> Bell Terrace). Raises Map_Overworld/SliceDressing from SliceDressing.build():
--   SliceDressing/Cells/Cell_<i>_<j>   one Model per 128-stud terrain tile, built once the tiles it needs are written.
--   SliceDressing/Landmarks/<Id>        the pavilion and the broken tower, one Persistent Model each.
-- Streaming: a cell is ModelStreamingMode.Atomic. A cell holds at most a few hundred parts, so loading it whole costs little,
-- and Default (per-part) streaming would show a crown without its trunk or half a gate. The two landmarks are Persistent: the
-- pavilion has to read at 1000 studs (StreamingTargetRadius is 1024) and each is only a handful of parts.
-- Readiness: OverworldService.WaitReady("Glade") first (the glade tiles), then per cell the tile keys in OverworldTerrain.Manifest
-- (a cell key is the terrain tile key because Cell = tile = 128). Cells are built nearest the glade first, one per frame.
-- Geometry: PLACEHOLDER parts sized from the kit manifest. makePiece is the one place that maps piece name -> Instance; it clones
-- ServerStorage/SliceKit/<Piece> (a Model of the imported MeshParts, pivot at the foot centre) when one exists and otherwise builds
-- the placeholder. Resolution order: SliceKit template, else the slice kit REGISTRY by name (Slice.Registry, from assets/SLICE_KIT_UPLOADED.json:
-- one MeshPart per sub-mesh built with AssetService:CreateMeshPartAsync + SurfaceAppearance, foot-centre pivot), else a registered fit from
-- Slice.Assets (ServerStorage clone), else the placeholder. Ids are never written here.
-- Ground: a raycast down onto Terrain (written voxels sit about 2 studs above Overworld.heightAt), falling back to heightAt + 2.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("AsurasPath")
local Overworld = require(Shared.Shared.Overworld) :: any
local Slice = require(Shared.Shared.SliceDressing) :: any
local Terrain = require(script.Parent:WaitForChild("OverworldTerrain") :: ModuleScript) :: any
local OverworldWorld = require(script.Parent:WaitForChild("OverworldService") :: ModuleScript) :: any

local SliceDressingService = {}

local VOXEL_LIFT = 2 -- written terrain voxels surface this far above heightAt (Overworld.luau Rings note)
local POLL = 1 -- seconds between passes over the cells still waiting for terrain
local GLADE_WAIT = 120 -- seconds to wait for Ready("Glade") before building anyway
local FOLIAGE_TAG = "AsuraFoliageShadow" -- LandscapeBudget turns these parts' shadows off beyond AsuraShadowDistance
local KIT_FOLDER = "SliceKit"

local running = false
local root: Folder? = nil
local stats = { Cells = 0, Built = 0, MeshParts = 0, PlaceholderParts = 0, Real = 0, Seconds = 0, Failed = 0 }

-- Replaceable for tests (and for a Studio capture that wants flat ground): (x, z, heightAt) -> surface Y.
SliceDressingService.Ground = nil :: ((number, number, number) -> number)?
-- Replaceable for tests: the slice kit registry (default Slice.Registry) and the MeshPart factory (assetId, structure) -> MeshPart?.
SliceDressingService.Registry = nil :: any
SliceDressingService.MakeMesh = nil :: ((string, boolean) -> Instance?)?

local function ground(x: number, z: number, surface: number): number
	if SliceDressingService.Ground then
		return SliceDressingService.Ground(x, z, surface)
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

local function newPart(parent: Instance, name: string, size: Vector3, cf: CFrame, sub: any, def: any): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = sub.Collide
	p.CanTouch = false
	p.CanQuery = sub.Collide
	p.CastShadow = def.Size[2] > 5 -- ferns and grass are too small to shade anything
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = (Enum.Material :: any)[sub.Material]
	p.Color = Color3.fromRGB(sub.Color[1], sub.Color[2], sub.Color[3])
	p.Size = size
	p.CFrame = cf
	p:SetAttribute("SliceSub", sub.Name)
	if sub.Lod then
		p:SetAttribute("LodDetail", true) -- the client may drop these beyond ~150 studs (manifest "lod")
	end
	if sub.Name:find("Leaves", 1, true) or sub.Name == "Fronds" or sub.Name == "Blades" then
		CollectionService:AddTag(p, FOLIAGE_TAG)
		p:SetAttribute("AsuraShadowDistance", 120)
	end
	p.Parent = parent
	return p
end

-- Placeholder geometry: one box per entry of each sub-mesh's B list (fractions of the footprint and height), or step blocks.
local function placeholder(pl: any, frame: CFrame, def: any): Instance
	local X, Y, Z = def.Size[1] * pl.Scale, def.Size[2] * pl.Scale, def.Size[3] * pl.Scale
	local made: { Part } = {}
	local holder = Instance.new("Model")
	for _, sub in def.Subs do
		local name = pl.Piece .. "__" .. sub.Name
		if sub.Shape == "Steps" then
			for i = 0, sub.Steps - 1 do
				local h = sub.Rise * (i + 1) * pl.Scale
				local z = Z / 2 - sub.Tread * pl.Scale * (i + 0.5) -- the low step is at +Z, the stair climbs toward -Z
				table.insert(made, newPart(holder, name, Vector3.new(sub.Width * pl.Scale, h, sub.Tread * pl.Scale), frame * CFrame.new(0, h / 2, z), sub, def))
			end
		else
			for _, b in sub.B do
				local h = (b[4] - b[3]) * Y
				local cf = frame * CFrame.new(b[1] * X, (b[3] + b[4]) / 2 * Y, b[2] * Z)
				if sub.Shape == "Cylinder" then
					table.insert(made, newPart(holder, name, Vector3.new(h, b[5] * X, b[6] * Z), cf * CFrame.Angles(0, 0, math.rad(90)), sub, def))
					made[#made].Shape = Enum.PartType.Cylinder
				elseif sub.Shape == "CylinderX" then -- a log: the cylinder's own axis is X, no rotation
					table.insert(made, newPart(holder, name, Vector3.new(b[5] * X, h, b[6] * Z), cf, sub, def))
					made[#made].Shape = Enum.PartType.Cylinder
				else
					table.insert(made, newPart(holder, name, Vector3.new(b[5] * X, h, b[6] * Z), cf, sub, def))
				end
			end
		end
	end
	if #made == 1 then -- a single block needs no Model: fewer instances for grass, ferns, walls
		local only = made[1]
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

-- Real meshes ------------------------------------------------------------------------------------

local meshCache: { [string]: Instance | boolean } = {} -- sub key -> MeshPart template (false = could not be made)

local function tagSub(p: BasePart, subName: string, lod: boolean, def: any, structure: boolean)
	p.Anchored = true
	p.CanCollide = structure and not lod
	p.CanTouch = false
	p.CanQuery = p.CanCollide
	p.CastShadow = def.Size[2] > 5 -- small scatter casts none
	p:SetAttribute("SliceSub", subName)
	if lod then
		p:SetAttribute("LodDetail", true) -- the client drops these beyond ~150 studs
	end
	if subName:find("Leaves", 1, true) or subName == "Fronds" or subName == "Blades" then
		CollectionService:AddTag(p, FOLIAGE_TAG)
		p:SetAttribute("AsuraShadowDistance", 120)
	end
end

local function createMesh(assetId: string, structure: boolean): Instance?
	if SliceDressingService.MakeMesh then
		return SliceDressingService.MakeMesh(assetId, structure)
	end
	local ok, part = pcall(function()
		return (game:GetService("AssetService") :: any):CreateMeshPartAsync(assetId, { CollisionFidelity = Enum.CollisionFidelity.Box })
	end)
	if not ok then
		warn(string.format("[SliceDressing] mesh %s not created: %s", assetId, tostring(part)))
		return nil
	end
	return part
end

-- One template MeshPart (with its SurfaceAppearance) per registry sub-mesh, cached; clones are cheap and share the mesh.
local function meshTemplate(key: string, entry: any, structure: boolean): Instance?
	local hit = meshCache[key]
	if hit ~= nil then
		return if hit == false then nil else hit :: Instance
	end
	local tpl = createMesh(entry.MeshId, structure)
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

-- Registry-built piece: every sub-mesh must resolve (a half tree is worse than the placeholder). A sub-mesh's centre is registry "center"
-- (foot-centre space, from the importer) or, for a single-sub piece only, Size/2 up.
local function registryPiece(pl: any, frame: CFrame, def: any): Instance?
	local reg: any = SliceDressingService.Registry or Slice.Registry
	local entries = if reg then reg[pl.Piece] else nil
	if type(entries) ~= "table" then
		return nil
	end
	local list = {}
	for _, sb in def.Subs do
		local key = pl.Piece .. "__" .. sb.Name
		local entry = entries[key]
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
		local tpl = meshTemplate(r.Key, r.Entry, def.Structure == true)
		if not tpl then
			for _, m in made do m:Destroy() end
			return nil
		end
		local p = tpl:Clone() :: any
		p.Name = r.Key
		p.Size = p.Size * pl.Scale
		p.CFrame = frame * CFrame.new(r.Center * pl.Scale)
		tagSub(p, r.Sub.Name, r.Sub.Lod, def, def.Structure == true)
		table.insert(made, p)
	end
	if #made == 1 then
		return made[1]
	end
	local holder = Instance.new("Model")
	for _, m in made do m.Parent = holder end
	return holder
end

-- Registered-asset fit (Slice.Assets): clone the ServerStorage model, keep the named MeshPart if any, scale to sit inside the piece box.
local function assetPiece(pl: any, frame: CFrame, def: any): Instance?
	local a = Slice.Assets[pl.Piece]
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
			local c = d:Clone()
			c.Parent = m
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
			tagSub(d, "Asset", false, def, def.Structure == true)
		end
	end
	return m
end

-- baseY is the ground at the placement's foot; the piece sinks by its Sink so slopes show no gap.
local function makePiece(pl: any, baseY: number): Instance
	local def = Slice.Pieces[pl.Piece]
	local frame = CFrame.new(pl.X, baseY - pl.Sink * pl.Scale, pl.Z) * CFrame.Angles(0, math.rad(pl.Yaw), 0)
	local template = kitTemplate(pl.Piece)
	local inst: Instance
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
		m:SetAttribute("SliceReal", true)
	else
		local real = registryPiece(pl, frame, def) or assetPiece(pl, frame, def)
		inst = real or placeholder(pl, frame, def)
		if real then inst:SetAttribute("SliceReal", true) end
	end
	inst.Name = pl.Id
	inst:SetAttribute("SlicePiece", pl.Piece)
	inst:SetAttribute("SliceClass", pl.Class)
	return inst
end

-------------------------------------------------------------------------------------------------
-- Cells
-------------------------------------------------------------------------------------------------

local function countParts(inst: Instance): number
	local n = if inst:IsA("BasePart") then 1 else 0
	for _, d in inst:GetDescendants() do
		n += if d:IsA("BasePart") then 1 else 0
	end
	return n
end

-- Builds one cell: plants and ordinary structures into Cell_<i>_<j> (Atomic), landmarks into their own Persistent Models.
-- Returns the placeholder part count. cells / landmarks are the two folders.
local function buildCell(key: string, cell: any, cells: Instance, landmarks: Instance): number
	local model = Instance.new("Model")
	model.Name = "Cell_" .. (string.gsub(key, ",", "_"))
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("Cell", key)
	local parts = 0
	for _, pl in cell.Placements do
		local y = ground(pl.GX, pl.GZ, pl.Y)
		local inst = makePiece(pl, y)
		parts += if inst:GetAttribute("SliceReal") then 0 else countParts(inst) -- placeholders only; real MeshParts are counted below
		if inst:GetAttribute("SliceReal") then stats.Real += countParts(inst) end
		if pl.Landmark then
			local holder = if inst:IsA("Model") then inst else Instance.new("Model")
			if holder ~= inst then
				inst.Parent = holder
				holder.Name = pl.Id
			end
			holder.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
			holder.Parent = landmarks
		else
			inst.Parent = model
		end
	end
	model:SetAttribute("Placements", #cell.Placements)
	model:SetAttribute("Parts", parts)
	model.Parent = cells
	return parts
end

local function ready(cell: any): boolean
	for key in cell.Needs do
		if not Terrain.Manifest[key] then
			return false
		end
	end
	return true
end

local function run()
	local t0 = os.clock()
	local map = Workspace:WaitForChild(Overworld.Root, 60)
	if not map or not running then
		return
	end
	local result = Slice.build()
	local folder = Instance.new("Folder")
	folder.Name = "SliceDressing"
	folder:SetAttribute("AsuraRegion", "Forest")
	local cells, landmarks = Instance.new("Folder"), Instance.new("Folder")
	cells.Name, landmarks.Name = "Cells", "Landmarks"
	cells.Parent, landmarks.Parent = folder, folder
	folder.Parent = map
	root = folder
	stats.MeshParts, stats.PlaceholderParts, stats.Real = 0, 0, 0

	local glade = Overworld.Altars[Overworld.Gateway].Placement
	local pending: { string } = {}
	for key in result.Cells do
		table.insert(pending, key)
	end
	local function distance(key: string): number
		local p = result.Cells[key].Placements[1]
		return (p.X - glade.X) ^ 2 + (p.Z - glade.Z) ^ 2
	end
	table.sort(pending, function(a: string, b: string): boolean
		local da, db = distance(a), distance(b)
		if da == db then return a < b end
		return da < db
	end)
	stats.Cells = #pending
	folder:SetAttribute("Cells", #pending)

	if not OverworldWorld.WaitReady(GLADE_WAIT, "Glade") then
		warn("[SliceDressing] Ready(\"Glade\") not reached; building cells as their tiles appear.")
	end
	while running and #pending > 0 do
		local waiting: { string } = {}
		local built = 0
		for _, key in pending do
			local cell = result.Cells[key]
			if ready(cell) then
				local ok, parts = pcall(buildCell, key, cell, cells, landmarks)
				if ok then
					stats.Built += 1
					stats.PlaceholderParts += parts :: any
					for _, pl in cell.Placements do
						stats.MeshParts += Slice.Pieces[pl.Piece].MeshParts
					end
				else
					stats.Failed += 1
					warn(string.format("[SliceDressing] cell %s skipped: %s", key, tostring(parts)))
				end
				built += 1
				folder:SetAttribute("CellsBuilt", stats.Built)
				task.wait() -- one cell per frame
				if not running then
					return
				end
			else
				table.insert(waiting, key)
			end
		end
		pending = waiting
		if #pending > 0 then
			if built == 0 and OverworldWorld.Ready("All") then
				warn(string.format("[SliceDressing] %d cells never saw their terrain tiles written; left unbuilt.", #pending))
				break
			end
			task.wait(POLL)
		end
	end
	stats.Seconds = os.clock() - t0
	folder:SetAttribute("Parts", stats.PlaceholderParts)
	folder:SetAttribute("MeshParts", stats.MeshParts)
	print(string.format("[SliceDressing] %d/%d cells, %d placeholder parts (%d kit MeshParts when swapped), %.1f s.", stats.Built, stats.Cells, stats.PlaceholderParts, stats.MeshParts, stats.Seconds))
end

-------------------------------------------------------------------------------------------------
-- Lifecycle
-------------------------------------------------------------------------------------------------

-- Start after OverworldService.Start() (Map_Overworld and the terrain generator exist). Inactive overworld: does nothing.
function SliceDressingService.Start()
	if not Overworld.Active then
		return
	end
	assert(not running, "SliceDressingService already started")
	running = true
	task.spawn(run)
end

function SliceDressingService.Stats(): any
	return { Cells = stats.Cells, Built = stats.Built, Failed = stats.Failed, MeshParts = stats.MeshParts, PlaceholderParts = stats.PlaceholderParts, Real = stats.Real,
		Seconds = stats.Seconds, Budget = Slice.Budget }
end

function SliceDressingService.Destroy()
	running = false
	if root then
		root:Destroy()
		root = nil
	end
	stats = { Cells = 0, Built = 0, MeshParts = 0, PlaceholderParts = 0, Real = 0, Seconds = 0, Failed = 0 }
	meshCache = {}
end

-- Exposed for tools/test_slice_dressing.luau.
SliceDressingService.Build = { Piece = makePiece, Cell = buildCell }

return SliceDressingService
