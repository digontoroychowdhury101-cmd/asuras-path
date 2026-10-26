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
	LeafyGrass = "AsuraGrass", Rock = "AsuraCliff", Ground = "AsuraGravel", Basalt = "AsuraBasalt",
} :: { [string]: string })

-- Terrain colour multiplies the variant's colour map; near-neutral tints keep the photo texture.
CampaignTerrain.Tints = table.freeze({
	LeafyGrass = Color3.fromRGB(176, 180, 150), Rock = Color3.fromRGB(150, 150, 152),
	Ground = Color3.fromRGB(150, 140, 128), Basalt = Color3.fromRGB(210, 205, 205),
} :: { [string]: Color3 })

local VOXEL = 4 -- a fill thinner than one voxel cannot be drawn faithfully; such boxes stay parts
local TOP_INSET = 1.5 -- fill top under the collider lid; the bumpy surface lands on or just above it
local SIDE_INSET = 0.5 -- edges stay near the collider; carve() trims any spill onto walkways
local CLEAR = 8 -- headroom carve() empties above built walkways

local function terrain(): Terrain?
	return Workspace:FindFirstChildOfClass("Terrain")
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
	t:FillBlock(cf, size, material)
	part.Transparency, part.CastShadow = 1, false
	part:SetAttribute("AsuraTerrainProxy", box.Kind)
	return true
end

-- Clears terrain above every built (non-proxy) colliding part in `structure`, so natural fills never
-- poke through paths, stairs or floors. A part with a proxy rising over its footprint (a cliff on a
-- gorge floor) is left alone: that terrain is the cliff itself.
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
				-- Ridged noise: sharp crests and creases read as eroded karst rather than blobs.
				local ridge = 1 - math.abs(math.noise(x / 90, z / 90, 7.3))
				local detail = math.noise(x / 23, z / 23, 1.9)
				local top = style.Low + (style.High - style.Low) * ramp * (0.55 + 0.45 * ridge) + detail * 6
				-- Taper into a saddle at the region's ends, so neighbouring walls meet without a sheer face.
				local fade = math.clamp(math.min(z - z0, z1 - z) / FADE, 0, 1)
				top = style.Floor + (top - style.Floor) * (0.25 + 0.75 * fade * fade * (3 - 2 * fade))
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

-- Clears the voxels a convert() drew (CampaignWorld.Destroy / rebuilds).
function CampaignTerrain.clear(box: any)
	local t = terrain()
	if t then
		local cf = CFrame.new(box.X, box.Y, box.Z) * CFrame.Angles(0, math.rad(box.Yaw), 0)
		t:FillBlock(cf, Vector3.new(box.SX, box.SY + VOXEL * 4, box.SZ), M.Air) -- covers deepened ground fills
	end
end

return CampaignTerrain
