--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/CampaignTerrain
-- Natural layout boxes (Grass, Rock, Snow, Ash, Basalt) are drawn as smooth Terrain instead of flat
-- parts. The box part stays as the exact collider (invisible) under the voxels. Smooth terrain is
-- bumpy (about +-1 stud) and its surface sits ~2 studs above the fill top (Studio-measured), so fills
-- stop TOP_INSET under the lid, so the surface sits on or just above it (never hovering feet); carve() then clears terrain
-- off every built walkway so voxels never lift paths, stairs or floors. Terrain materials use the
-- GitHub PBR MaterialVariants (assets/GITHUB_TERRAIN.json) through base-material overrides; the lobby
-- only uses Water terrain, so the overrides reach the campaign regions and the Monastery hills.
local Workspace = game:GetService("Workspace")

local CampaignTerrain = {}
local M = Enum.Material

-- Layout kind -> terrain material. Kinds missing here stay parts.
CampaignTerrain.Kinds = table.freeze({
	Grass = M.LeafyGrass, Rock = M.Rock, Snow = M.Snow, Ash = M.Ground, Basalt = M.Basalt,
} :: { [string]: Enum.Material })

-- Base material -> uploaded variant (default.project.json MaterialService).
CampaignTerrain.Overrides = table.freeze({
	LeafyGrass = "AsuraGrass", Grass = "AsuraMeadow", Rock = "AsuraCliff", Ground = "AsuraGravel", Basalt = "AsuraBasalt",
} :: { [string]: string })

-- Terrain colour multiplies the variant's colour map; near-neutral tints keep the photo texture.
CampaignTerrain.Tints = table.freeze({
	LeafyGrass = Color3.fromRGB(176, 180, 150), Rock = Color3.fromRGB(150, 150, 152),
	Grass = Color3.fromRGB(158, 172, 133),
	Ground = Color3.fromRGB(150, 140, 128), Basalt = Color3.fromRGB(210, 205, 205),
} :: { [string]: Color3 })

local VOXEL = 4 -- a fill thinner than one voxel cannot be drawn faithfully; such boxes stay parts
local TOP_INSET = 1.5 -- fill top under the collider lid; the bumpy surface lands on or just above it
local SIDE_INSET = 0.5 -- edges stay near the collider; carve() trims any spill onto walkways
local CLEAR = 8 -- headroom carve() empties above built walkways

local function terrain(): Terrain?
	return Workspace:FindFirstChildOfClass("Terrain")
end

-- Newly filled terrain collision becomes queryable after a scheduler yield. Dressing callers use
-- this measured surface rather than the proxy lid; this preserves grounding on the voxel surface.
function CampaignTerrain.surfaceHeight(x: number, z: number, fallback: number): number
	local t = terrain()
	if not t then return fallback end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { t }
	local hit = Workspace:Raycast(Vector3.new(x, fallback + 8, z), Vector3.new(0, -16, 0), params)
	return if hit and math.abs(hit.Position.Y - fallback) < 3 then hit.Position.Y else fallback
end

function CampaignTerrain.applyOverrides()
	local service = game:GetService("MaterialService")
	local t = terrain()
	if not service or not t then
		return
	end
	for base, variant in CampaignTerrain.Overrides do
		if service:FindFirstChild(variant) then
			service:SetBaseMaterialOverride((M :: any)[base], variant)
			t:SetMaterialColor((M :: any)[base], CampaignTerrain.Tints[base])
		end
	end
end

-- True when no other layout solid lies under `box` (within `depth` below its bottom): a ground slab
-- whose fill may then reach below the collider, so thin floors still get a full voxel layer.
local function nothingBelow(box: any, solids: { any }?, depth: number): boolean
	if not solids then
		return false
	end
	local bottom = box.Y - box.SY / 2
	local r = math.max(box.SX, box.SZ) / 2 -- yaw-safe radius
	for _, o in solids do
		local otop = o.Y + o.SY / 2
		if o ~= box and o.Kind ~= "Veil" and otop <= bottom + 0.01 and otop > bottom - depth
			and math.abs(o.X - box.X) < r + math.max(o.SX, o.SZ) / 2 and math.abs(o.Z - box.Z) < r + math.max(o.SX, o.SZ) / 2 then
			return false
		end
	end
	return true
end

-- Draws one box as terrain and hides its part. Returns true when converted. `solids` (the region's
-- layout) lets a thin ground slab extend its fill below the collider when nothing is underneath.
function CampaignTerrain.convert(part: BasePart, box: any, solids: { any }?): boolean
	local t = terrain()
	local material = CampaignTerrain.Kinds[box.Kind]
	if not t or not material or math.min(box.SX, box.SZ) - SIDE_INSET * 2 < VOXEL then
		return false
	end
	local top = box.Y + box.SY / 2 - TOP_INSET
	local bottom = box.Y - box.SY / 2
	if top - bottom < VOXEL * 2 then
		if not nothingBelow(box, solids, VOXEL * 2) then
			if top - bottom < VOXEL then
				return false
			end
		else
			bottom = top - VOXEL * 2
		end
	end
	local size = Vector3.new(box.SX - SIDE_INSET * 2, top - bottom, box.SZ - SIDE_INSET * 2)
	local cf = CFrame.new(box.X, (top + bottom) / 2, box.Z) * CFrame.Angles(0, math.rad(box.Yaw), 0)
	if material == M.Snow and size.Y >= VOXEL * 2 and (box.Name == "FrostedCrest" or box.Name == "RidgeNorth") then
		-- Frost belongs on exposed tops; a solid white ridge reads as an artificial snow wall.
		-- Keep the exact fill envelope and original collider, changing only the material layers.
		t:FillBlock(cf, size, M.Rock)
		t:FillBlock(CFrame.new(box.X, top - 1, box.Z) * CFrame.Angles(0, math.rad(box.Yaw), 0),
			Vector3.new(size.X, 2, size.Z), M.Snow)
		-- Exposed stone breaks the straight snow lip. Repainting preserves voxel occupancy,
		-- the exact slab envelope and the authored route collider beneath the terrain.
		local halfX, halfZ = size.X / 2, size.Z / 2
		for x = math.floor((box.X - halfX) / VOXEL) * VOXEL, box.X + halfX, VOXEL do
			for z = math.floor((box.Z - halfZ) / VOXEL) * VOXEL, box.Z + halfZ, VOXEL do
				local inward = math.min(halfX - math.abs(x + VOXEL / 2 - box.X), halfZ - math.abs(z + VOXEL / 2 - box.Z))
				local margin = 6 + math.noise(x / 11, z / 13, 8.2) * 8
				if inward < margin then
					t:ReplaceMaterial(Region3.new(Vector3.new(x, bottom - VOXEL, z), Vector3.new(x + VOXEL, top + VOXEL, z + VOXEL)),
						VOXEL, M.Snow, M.Rock)
				end
			end
		end
	else
		t:FillBlock(cf, size, material)
	end
	part.Transparency, part.CastShadow = 1, false
	part:SetAttribute("AsuraTerrainProxy", box.Kind)
	return true
end

-- Paint small irregular openings with true Grass without changing voxel occupancy or navigation.
-- Deep shaded groves retain LeafyGrass/moss; only these suitable openings receive animated blades.
local function paintPatch(x: number, z: number, rx: number, rz: number, material: Enum.Material)
	local t = terrain()
	if not t then return end
	for gx = math.floor((x - rx) / VOXEL) * VOXEL, x + rx, VOXEL do
		for gz = math.floor((z - rz) / VOXEL) * VOXEL, z + rz, VOXEL do
			local nx, nz = (gx + 2 - x) / rx, (gz + 2 - z) / rz
			if nx * nx + nz * nz < 0.92 + math.noise(gx / 9, gz / 9, 4.7) * 0.25 then
				t:ReplaceMaterial(Region3.new(Vector3.new(gx, -12, gz), Vector3.new(gx + VOXEL, 4, gz + VOXEL)),
					VOXEL, M.LeafyGrass, material)
			end
		end
	end
end

function CampaignTerrain.grassPatch(x: number, z: number, rx: number, rz: number)
	paintPatch(x, z, rx, rz, M.Grass)
end

-- Dry mineral soil below closed bamboo carries litter, while brighter openings keep grass.
function CampaignTerrain.forestFloor(x: number, z: number, rx: number, rz: number)
	paintPatch(x, z, rx, rz, M.Ground)
end

-- Clears terrain above every built (non-proxy) colliding part in `structure`, so natural fills never
-- poke through paths, stairs or floors. A part with a proxy rising over its footprint (a cliff on a
-- gorge floor) is left alone: that terrain is the cliff itself.
-- Expose an authored floor without moving it: the voxel ground must not cover an arena's Y=0 lid.
function CampaignTerrain.exposeFloor(p: BasePart)
	local t = terrain()
	if t then
		-- The smooth surface can protrude beyond the last occupied voxel by ~0.4 stud.
		-- Undercut inside the existing solid slab so the unchanged Part lid owns contact.
		local undercut = math.min(VOXEL, p.Size.Y)
		t:FillBlock(p.CFrame * CFrame.new(0, p.Size.Y / 2 + (CLEAR - undercut) / 2, 0),
			Vector3.new(p.Size.X + 0.5, CLEAR + undercut, p.Size.Z + 0.5), M.Air)
	end
end

function CampaignTerrain.carve(structure: Instance)
	local t = terrain()
	if not t then
		return
	end
	local proxies: { BasePart } = {}
	for _, p in structure:GetChildren() do
		if p:IsA("BasePart") and p:GetAttribute("AsuraTerrainProxy") then
			table.insert(proxies, p)
		end
	end
	-- A proxy covers a floor when it rises above the floor's top and stands over part of its area
	-- (5 x 5 samples in the floor's own frame, tested in the proxy's frame: yaw-exact, unlike AABBs).
	local function covers(q: BasePart, p: BasePart, top: number): boolean
		if q.Position.Y + q.Size.Y / 2 <= top + 0.5 then
			return false
		end
		for i = -2, 2 do
			for j = -2, 2 do
				local w = p.CFrame * Vector3.new(p.Size.X * i / 5, 0, p.Size.Z * j / 5)
				local l = q.CFrame:PointToObjectSpace(w)
				if math.abs(l.X) < q.Size.X / 2 and math.abs(l.Z) < q.Size.Z / 2 then
					return true
				end
			end
		end
		return false
	end
	for _, p in structure:GetChildren() do
		if not p:IsA("BasePart") or not p.CanCollide or p.Transparency >= 1 or p:GetAttribute("AsuraTerrainProxy") then
			continue
		end
		local top = p.Position.Y + p.Size.Y / 2
		local covered = false
		for _, q in proxies do
			if covers(q, p, top) then
				covered = true
				break
			end
		end
		if not covered then
			t:FillBlock(p.CFrame * CFrame.new(0, p.Size.Y / 2 + CLEAR / 2, 0), Vector3.new(p.Size.X + 0.5, CLEAR, p.Size.Z + 0.5), M.Air)
		end
	end
end

-- Valley walls outside each region's east and west bounds, so the walkable boxes sit in a landscape
-- instead of a void. Regions chain along -Z, so only the X sides are walled; every column starts
-- MARGIN studs past the bounds, beyond the Veil fences, and is never reachable. Floor/Low/High are
-- heights above Y=0 at the inner and outer edge; Snow caps columns above that height.
CampaignTerrain.Backdrops = table.freeze({
	BambooPass = { Floor = -8, Low = 24, High = 120, Body = M.Rock, Cap = M.LeafyGrass, Snow = 96 },
	AshColosseum = { Floor = -8, Low = 18, High = 80, Body = M.Basalt, Cap = M.Ground },
	CelestialPagoda = { Floor = -40, Low = 10, High = 130, Body = M.Rock, Cap = M.LeafyGrass, Snow = 110 },
	SkyCitadel = { Floor = -200, Low = -60, High = 70, Body = M.Rock, Cap = M.Rock, Snow = 30 },
} :: { [string]: any })

local MARGIN, WIDTH, STEP, FADE = 8, 140, 8, 72

-- Fill top of one valley-wall column at (x, z); `ramp` is the smoothstepped distance out from the bounds.
local function wallTop(style: any, x: number, z: number, ramp: number, z0: number, z1: number): number
	-- Ridged noise: sharp crests and creases read as eroded karst rather than blobs.
	local ridge = 1 - math.abs(math.noise(x / 90, z / 90, 7.3))
	local detail = math.noise(x / 23, z / 23, 1.9)
	local top = style.Low + (style.High - style.Low) * ramp * (0.55 + 0.45 * ridge) + detail * 6
	-- Taper into a saddle at the region's ends, so neighbouring walls meet without a sheer face.
	local fade = math.clamp(math.min(z - z0, z1 - z) / FADE, 0, 1)
	return style.Floor + (top - style.Floor) * (0.25 + 0.75 * fade * fade * (3 - 2 * fade))
end

-- Valley-wall surface height at (x, z) (the column's fill top plus the ~2-stud smooth-terrain lift),
-- or nil outside the walls. Dressing seats models with this: terrain collision for voxels filled in
-- the same frame is not built yet, so raycasts cannot find it.
function CampaignTerrain.backdropHeight(regionId: string, bounds: any, x: number, z: number): number?
	local style = CampaignTerrain.Backdrops[regionId]
	if not style then
		return nil
	end
	local c, s = bounds.Center, bounds.Size
	local z0, z1 = c.Z - s.Z / 2, c.Z + s.Z / 2
	local out = math.abs(x - c.X) - (s.X / 2 + MARGIN)
	if out < 0 or out > WIDTH or z < z0 or z > z1 then
		return nil
	end
	local i = math.min(math.floor(out / STEP), WIDTH / STEP - 1)
	local side = if x < c.X then -1 else 1
	local cx = c.X + side * (s.X / 2 + MARGIN + (i + 0.5) * STEP)
	local cz = z0 + STEP / 2 + math.floor((z - z0) / STEP) * STEP
	local ramp = (i + 0.5) * STEP / WIDTH
	ramp = ramp * ramp * (3 - 2 * ramp)
	return wallTop(style, cx, cz, ramp, z0, z1) + 2
end

function CampaignTerrain.backdrop(regionId: string, bounds: any): { any }
	local t = terrain()
	local style = CampaignTerrain.Backdrops[regionId]
	local drawn: { any } = {}
	if not t or not style then
		return drawn
	end
	local c, s = bounds.Center, bounds.Size
	local z0, z1 = c.Z - s.Z / 2, c.Z + s.Z / 2
	for _, side in { -1, 1 } do
		local inner = c.X + side * (s.X / 2 + MARGIN)
		for i = 0, WIDTH / STEP - 1 do
			local x = inner + side * (i + 0.5) * STEP
			local ramp = (i + 0.5) * STEP / WIDTH
			ramp = ramp * ramp * (3 - 2 * ramp)
			for z = z0 + STEP / 2, z1, STEP do
				local top = wallTop(style, x, z, ramp, z0, z1)
				local height = top - style.Floor
				if height > 2 then
					local cf = CFrame.new(x, style.Floor + height / 2, z)
					t:FillBlock(cf, Vector3.new(STEP, height, STEP), style.Body)
					local cap = if style.Snow and top > style.Snow then M.Snow else style.Cap
					t:FillBlock(CFrame.new(x, top - 2, z), Vector3.new(STEP, 4, STEP), cap)
				end
			end
		end
		table.insert(drawn, { X = inner + side * WIDTH / 2, Y = 0, Z = c.Z, SX = WIDTH, SY = 600, SZ = s.Z, Yaw = 0 })
	end
	return drawn
end

-- Rock pillars that carry set pieces standing outside the walkable floor (the Pagoda's corner
-- towers): {x, z, top, radius} rising from far below, lumped with balls, flat-capped so a model's
-- base sits on the surface (which renders ~2 studs above a fill's top).
CampaignTerrain.Pillars = table.freeze({
	CelestialPagoda = { { -140, -2318, 0, 16 }, { 140, -2318, 0, 16 }, { -140, -2448, 0, 16 }, { 140, -2448, 0, 16 } },
	SkyCitadel = {
		{ -4, -2604, -98, 4 }, { 4, -2604, -98, 4 }, -- under the bridge piers (bottom -97); the chasm stays open
		{ -120, -2700, 0, 17 }, { 120, -2700, 0, 17 }, -- the bastion pagodas
		{ -70, -2580, -40, 12 }, { 70, -2600, -40, 12 }, { -150, -2860, -40, 13 }, { 150, -2900, -40, 13 }, -- ruined towers
	},
} :: { [string]: { { number } } })

-- Rock massifs under platforms that would otherwise hang in the void: {x0, x1, z0, z1, top}, filled
-- from 150 studs down to `top` (kept under the platform's own underside or floor so no walked
-- surface moves), with weathered lumps along the sides that stay below the top.
CampaignTerrain.Massifs = table.freeze({
	CelestialPagoda = {
		{ -160, 160, -2172, -2252, -33 }, -- under the gorge floor (bottom -32)
		{ -160, 96, -2252, -2292, -31 }, -- under the forecourt (bottom -30)
		{ -118, 118, -2292, -2472, -4.5 }, -- Wu's hall plateau under the arena floor (y 0; surface stays below), carrying the hall columns
		{ -36, 36, -2470, -2540, -31 }, -- under the dawn terrace (bottom -30)
	},
	SkyCitadel = { -- one peak: saddle ridge, Heaven's Stair spine, landing, bastion, summit, perch
		{ -30, 30, -2540, -2548, -31 }, -- under the saddle head (bottom -30)
		{ -12, 12, -2548, -2588, -23 }, -- the ridge under the saddle stair (steps reach -22)
		{ -12, 12, -2618, -2670, -23 }, -- Heaven's Stair spine (steps reach -22)
		{ -20, 20, -2640, -2650, -51 }, -- under the first gate landing (bottom -50)
		{ -72, 72, -2670, -2740, -51 }, -- under the last bastion (bottom -50)
		{ -96, 96, -2736, -2926, -51 }, -- under the summit plateau (bottom -50.1)
		{ -14, 14, -2926, -2966, -41 }, -- under the dragon's perch (bottom -40)
	},
} :: { [string]: { { number } } })

function CampaignTerrain.pillars(regionId: string): { any }
	local t = terrain()
	local list = CampaignTerrain.Pillars[regionId] or {}
	local drawn: { any } = {}
	if not t then
		return drawn
	end
	for i, m in CampaignTerrain.Massifs[regionId] or {} do
		local x0, x1, z0, z1, top = m[1], m[2], math.min(m[3], m[4]), math.max(m[3], m[4]), m[5]
		local bottom = top - 150
		local box = { X = (x0 + x1) / 2, Y = (top + bottom) / 2, Z = (z0 + z1) / 2, SX = x1 - x0, SY = top - bottom, SZ = z1 - z0, Yaw = 0 }
		t:FillBlock(CFrame.new(box.X, box.Y, box.Z), Vector3.new(box.SX, box.SY, box.SZ), M.Rock)
		for k = 0, 23 do -- lumps along the long sides, sunk below the top
			local side = if k % 2 == 0 then -1 else 1
			local r = 7 + (k * 37 + i * 11) % 6
			local along = x0 + (x1 - x0) * ((k * 0.618 + i * 0.3) % 1)
			local zz = if side < 0 then z0 else z1
			t:FillBall(Vector3.new(along, top - r - 4 - (k % 5) * 9, zz), r, M.Rock)
		end
		table.insert(drawn, { X = box.X, Y = box.Y, Z = box.Z, SX = box.SX + 30, SY = box.SY + 10, SZ = box.SZ + 30, Yaw = 0 })
	end
	for i, p in list do
		local x, z, top, r = p[1], p[2], p[3], p[4]
		local bottom = top - 160
		t:FillCylinder(CFrame.new(x, (top - 2 + bottom) / 2, z), top - 2 - bottom, r, M.Rock)
		for k = 1, 9 do -- weathered bulges down the shaft, never above the cap
			local a = k * 2.4 + i
			local y = top - 14 - k * 13
			t:FillBall(Vector3.new(x + math.cos(a) * r * 0.75, y, z + math.sin(a) * r * 0.75), r * (0.5 + 0.06 * (k % 4)), M.Rock)
		end
		table.insert(drawn, { X = x, Y = (top + bottom) / 2, Z = z, SX = r * 3.2, SY = top - bottom + 8, SZ = r * 3.2, Yaw = 0 })
	end
	return drawn
end

-- A level rock terrace for a set piece on a slope: surface at `top` (fill stops 2 studs under it,
-- the smooth-terrain lift) over a size x size footprint, reaching 18 studs down into the hillside.
function CampaignTerrain.pad(x: number, z: number, top: number, size: number)
	local t = terrain()
	if t then
		t:FillBlock(CFrame.new(x, top - 11, z), Vector3.new(size, 18, size), M.Rock)
	end
end

-- Clears the voxels a convert() drew (CampaignWorld.Destroy / rebuilds).
function CampaignTerrain.clear(box: any)
	local t = terrain()
	if t then
		local cf = CFrame.new(box.X, box.Y, box.Z) * CFrame.Angles(0, math.rad(box.Yaw), 0)
		t:FillBlock(cf, Vector3.new(box.SX, box.SY + VOXEL * 4, box.SZ), M.Air) -- covers deepened ground fills
	end
end

return CampaignTerrain
