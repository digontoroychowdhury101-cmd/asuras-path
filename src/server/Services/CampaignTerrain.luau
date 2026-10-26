--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/CampaignTerrain
-- Natural layout boxes (Grass, Rock, Snow, Ash, Basalt) are drawn as smooth Terrain instead of flat
-- parts. The box part stays as the exact collider (invisible), and the voxels are inset below its top
-- and inside its sides, so no surface the reachability suite walks moves. Terrain materials use the
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

local MIN_DIM = 4 -- one voxel; thinner boxes cannot be drawn faithfully and stay parts
local TOP_INSET = 0.6 -- terrain surface sits under the collider top, never above it
local SIDE_INSET = 0.5

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

-- Draws one box as terrain and hides its part. Returns true when converted.
function CampaignTerrain.convert(part: BasePart, box: any): boolean
	local t = terrain()
	local material = CampaignTerrain.Kinds[box.Kind]
	if not t or not material or math.min(box.SX, box.SY, box.SZ) < MIN_DIM then
		return false
	end
	local size = Vector3.new(box.SX - SIDE_INSET * 2, box.SY - TOP_INSET, box.SZ - SIDE_INSET * 2)
	local cf = CFrame.new(box.X, box.Y - TOP_INSET / 2, box.Z) * CFrame.Angles(0, math.rad(box.Yaw), 0)
	t:FillBlock(cf, size, material)
	part.Transparency, part.CastShadow = 1, false
	part:SetAttribute("AsuraTerrainProxy", box.Kind)
	return true
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

-- Clears the voxels a convert() drew (CampaignWorld.Destroy / rebuilds).
function CampaignTerrain.clear(box: any)
	local t = terrain()
	if t then
		local cf = CFrame.new(box.X, box.Y, box.Z) * CFrame.Angles(0, math.rad(box.Yaw), 0)
		t:FillBlock(cf, Vector3.new(box.SX, box.SY, box.SZ), M.Air)
	end
end

return CampaignTerrain
