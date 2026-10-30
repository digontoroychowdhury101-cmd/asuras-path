--!strict
-- First living-grove slice: existing uploaded geometry, clustered habitats and rooted wind pivots.
-- All dressing is noncolliding/nonqueryable. The authored layout remains the sole movement surface.
local Decor = require(script.Parent.RegionDecor)
local Kit = require(script.Parent.MonasteryKit)
local Ground = require(script.Parent.CampaignTerrain)
local Storage = game:GetService("ServerStorage")
local Tags = game:GetService("CollectionService")
local Ecology = {}
local rgb = Color3.fromRGB
local styles = {
	{ Count = 4, Height = 46, Spread = 3.2, Lean = 3, Crown = 1.8 }, -- tall closed crown
	{ Count = 5, Height = 38, Spread = 4.6, Lean = 8, Crown = 2.2 }, -- broad fan
	{ Count = 3, Height = 49, Spread = 3.8, Lean = 12, Crown = 1.6 }, -- leaning curtain
	{ Count = 4, Height = 25, Spread = 2.5, Lean = 5, Crown = 1.7 }, -- younger edge growth
	{ Count = 3, Height = 41, Spread = 4.1, Lean = 6, Crown = 2.5 }, -- open asymmetric crown
}

local function wind(model: Model, base: CFrame, height: number, kind: string)
	model:SetAttribute("WindBase", base)
	model:SetAttribute("WindHeight", height)
	model:SetAttribute("WindKind", kind)
	if Tags then Tags:AddTag(model, "AsuraWindPlant") end
end

local function detail(parent: Instance, name: string, base: CFrame, scale: number, tint: Color3): Model?
	local living = Storage:FindFirstChild("AsuraLivingBamboo")
	local breakage = Storage:FindFirstChild("AsuraBambooBreakage")
	local mapped = if name == "Detail_Fern" then "Ground_Fern" else name
	local template = (living and living:FindFirstChild(mapped)) or (breakage and breakage:FindFirstChild(mapped))
	local imported = template ~= nil
	if not template then
		local lib = Storage:FindFirstChild("AsuraSanctuaryDetail")
		template = lib and lib:FindFirstChild(name)
	end
	if not template or not template:IsA("Model") then return nil end
	local model = template:Clone()
	model:ScaleTo(scale)
	model:PivotTo(base)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
			p.Color = if imported then Color3.new(1, 1, 1) else tint
			p:SetAttribute("AsuraDecorative", true)
			local surface = p:FindFirstChildOfClass("SurfaceAppearance")
			if surface then
				surface.Color = if mapped == "Ground_GrassTuft" then rgb(193, 212, 168) elseif imported then rgb(240, 245, 232) else tint
			end
		end
	end
	model.Parent = parent
	return model
end

local function clump(parent: Instance, layout: any, x: number, z: number, styleIndex: number, rng: Random, plain: boolean?)
	local style = styles[styleIndex]
	local group = Instance.new("Model")
	group.Name = "GroveClump_" .. styleIndex
	group:SetAttribute("ClumpSilhouette", styleIndex)
	local phase = rng:NextNumber(0, math.pi * 2)
	local library = Storage:FindFirstChild("AsuraLivingBamboo")
	-- `plain` keeps the compressed crown of the outer groves where a view sees many clumps at once.
	local sculptedCrown = not plain and math.abs(x) < 65 and library and library:FindFirstChild("Bamboo_LeafSpray") ~= nil
	for i = 1, style.Count do
		local angle = phase + i * 2.39996
		local radius = style.Spread * math.sqrt(i / style.Count) * rng:NextNumber(0.55, 1)
		local sx, sz = x + math.cos(angle) * radius, z + math.sin(angle) * radius
		local floor = Ground.surfaceHeight(sx, sz, Decor.layoutTop(layout, sx, sz) or -0.1)
		local height = style.Height * rng:NextNumber(0.76, 1.12)
		local lean = math.rad(style.Lean) * (i / style.Count)
		local base = CFrame.new(sx, floor - 0.18, sz) * CFrame.Angles(math.sin(angle) * lean, angle, math.cos(angle) * lean)
		local stalk = Decor.kit("Bamboo", rng)
		if stalk then
			Decor.placeKit(group, stalk, "Bamboo", base, height)
			local extra: BasePart? = nil
			for _, p in stalk:GetChildren() do
				if p:IsA("BasePart") then
					p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
					p:SetAttribute("AsuraDecorative", true)
					p:SetAttribute("WindRootLocal", p.CFrame:PointToObjectSpace(base.Position))
					p.CastShadow = p.Name:find("Culm", 1, true) ~= nil
					if p.Name:find("Leaves", 1, true) then
						-- The existing mesh is spread vertically over most of a culm. Compress that
						-- distribution into a wide drooping crown; retain its real pointed leaf geometry.
						local localFrame = base:ToObjectSpace(p.CFrame)
						local width = style.Crown * (if sculptedCrown then 0.65 else 1)
						p.Size *= Vector3.new(width, if sculptedCrown then 0.34 else 0.46, width)
						p.CFrame = base * CFrame.new(localFrame.X, height * (if sculptedCrown then 0.64 else 0.76), localFrame.Z) * localFrame.Rotation
						p:SetAttribute("WindFlutter", true)
						if i % 2 == 0 and not sculptedCrown then extra = p end
					end
				end
			end
			if sculptedCrown then
				local crown = detail(stalk, "Bamboo_LeafSpray", base * CFrame.new(0, height * 0.9, 0)
					* CFrame.Angles(0, phase, 0), height / 41 * style.Crown * 0.7, rgb(255, 255, 255))
				if crown then for _, p in crown:GetDescendants() do if p:IsA("BasePart") then p:SetAttribute("WindFlutter", true) end end end
			end
			if extra then
				local spray = extra:Clone()
				spray.Name = "BambooLowerSpray"
				spray.Size *= Vector3.new(0.78, 0.75, 0.78)
				spray.CFrame = base * CFrame.new(0, height * 0.53, 0) * CFrame.Angles(0.1, phase + 1.3, -0.12)
				spray.Parent = stalk
			end
			Decor.foliageShadows(stalk)
			wind(stalk, base, height, "Bamboo")
		else
			-- Keep the established fallback only when the uploaded library is absent.
			Decor.bamboo(group, sx, floor, sz, rng)
		end
	end
	group.Parent = parent
end

-- Cluster centres are stratified then displaced. Density varies by a shared low-frequency field;
-- companion culms grow around each centre rather than being independently spread across a rectangle.
function Ecology.Grove(parent: Instance, layout: any, grove: { number }, rng: Random)
	local x0, x1 = grove[1] + 6, grove[2] - 6
	local z0, z1 = math.min(grove[3], grove[4]) + 6, math.max(grove[3], grove[4]) - 6
	local count = math.ceil(grove[6] / 4)
	local columns = math.max(1, math.floor(math.sqrt(count * (x1 - x0) / (z1 - z0))))
	local rows = math.ceil(count / columns)
	for i = 0, count - 1 do
		local x = x0 + (i % columns + rng:NextNumber(0.12, 0.88)) / columns * (x1 - x0)
		local z = z0 + (math.floor(i / columns) + rng:NextNumber(0.12, 0.88)) / rows * (z1 - z0)
		local field = math.noise(x / 37, z / 46, 3.1)
		if field > -0.33 or i % 5 == 0 then clump(parent, layout, x, z, i % #styles + 1, rng) end
	end
end

function Ecology.Entry(map: Instance, layout: any, rng: Random)
	-- Let terrain collision cook before measuring plant contact. This is one build-time yield,
	-- not a per-plant timer or a recurring world search.
	if workspace:FindFirstChildOfClass("Terrain") then task.wait(0.05) end
	local habitat = Kit.folder("LivingBambooEntry", map)
	habitat:SetAttribute("ArtSlice", "EntryToCrest_v1")
	Ecology.Grove(habitat, layout, layout.Groves[1], rng)
	Ecology.Grove(habitat, layout, layout.Groves[4], rng)
	for _, side in { -1, 1 } do
		for i = 0, 6 do
			local z = -1142 - i * 13 + rng:NextNumber(-3, 3)
			local x = side * rng:NextNumber(24, 34)
			if i < 6 then Ground.grassPatch(side * rng:NextNumber(14, 19), z, 5.5, 9) end
			Ground.forestFloor(x, z, 9, 10)
			clump(habitat, layout, x, z, i % #styles + 1, rng)
			-- Fern colonies gather at culm feet; their roots are slightly buried, their crowns
			-- leave the path/first swordsman's central lane and the camera sweep open.
			for k = 1, 4 do
				local fx = x + rng:NextNumber(-6, 6)
				local fz = z + rng:NextNumber(-5, 5)
				local floor = Ground.surfaceHeight(fx, fz, Decor.layoutTop(layout, fx, fz) or -0.1)
				local frame = CFrame.new(fx, floor + 0.02, fz) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
				local fern = detail(habitat, "Detail_Fern", frame, rng:NextNumber(0.85, 1.7), rgb(71 + k * 5, 91 + k * 4, 49))
				if fern then wind(fern, frame, 2, "Fern") end
			end
			if i % 2 == 0 then
				local gx = side * rng:NextNumber(14, 22)
				local frame = CFrame.new(gx, Ground.surfaceHeight(gx, z + 4, -0.1), z + 4) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
				local grass = detail(habitat, "Ground_GrassTuft", frame, rng:NextNumber(0.55, 0.85), rgb(255, 255, 255))
				if grass then wind(grass, frame, 1.8, "Grass") end
				local sx = x + side * 3
				local shootFrame = CFrame.new(sx, Ground.surfaceHeight(sx, z - 4, -0.1) - 0.03, z - 4) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
				local shoots = detail(habitat, "Bamboo_YoungShoots", shootFrame, rng:NextNumber(0.6, 0.95), rgb(255, 255, 255))
				if shoots then wind(shoots, shootFrame, 4, "Shoot") end
				local bx = x + side * 5
				Decor.han(habitat, "AsuraHanKit", "BoulderSmall", CFrame.new(bx, Ground.surfaceHeight(bx, z + 4, -0.1) - 0.2, z + 4)
					* CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(6, 10))
			end
			for _ = 1, 2 do
				local lx, lz = side * rng:NextNumber(11, 27), z + rng:NextNumber(-5, 5)
				detail(habitat, "Ground_LeafLitter", CFrame.new(lx, Ground.surfaceHeight(lx, lz, -0.1) - 0.02, lz) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
					rng:NextNumber(0.7, 1.2), rgb(255, 255, 255))
			end
		end
	end
	for _, c in { { -25, -1166, 0.7 }, { 26, -1214, 0.9 } } do
		local y = Ground.surfaceHeight(c[1], c[2], -0.1)
		detail(habitat, "Bamboo_BrokenClump", CFrame.new(c[1], y, c[2]) * CFrame.Angles(0, c[3], 0), 1, rgb(255, 255, 255))
	end
	for _, c in { { -27, -1188, 1.4 }, { 25, -1206, -0.3 } } do
		local y = Ground.surfaceHeight(c[1], c[2], -0.1)
		detail(habitat, "Bamboo_FallenPole", CFrame.new(c[1], y, c[2]) * CFrame.Angles(0, c[3], 0), 1, rgb(255, 255, 255))
	end
	map:SetAttribute("BambooArtPass", "Entry slice v5; remaining pass retains baseline dressing")
	local lib = Storage:FindFirstChild("AsuraLivingBamboo")
	map:SetAttribute("BambooImportedEcologyReady", lib ~= nil and #lib:GetChildren() == 5)
end

function Ecology.Shrine(map: Instance, layout: any, rng: Random)
	local habitat = Kit.folder("LivingBambooShrine", map)
	for i, c in { { -59, -1315 }, { -60, -1334 }, { -58, -1350 }, { -15, -1349 } } do
		clump(habitat, layout, c[1], c[2], if i == 4 then 4 else i, rng)
	end
	for _, side in { -54, -18 } do
		for i = 0, 3 do
			local z = -1316 - i * 10
			local x = side + rng:NextNumber(-2, 2)
			local y = Ground.surfaceHeight(x, z, Decor.layoutTop(layout, x, z) or -0.1)
			local frame = CFrame.new(x, y + 0.02, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			local fern = detail(habitat, "Ground_Fern", frame, rng:NextNumber(0.8, 1.3), rgb(255, 255, 255))
			if fern then wind(fern, frame, 2, "Fern") end
			detail(habitat, "Ground_LeafLitter", frame * CFrame.new(-1, -0.04, 2), 0.8, rgb(255, 255, 255))
		end
	end
	Ground.forestFloor(-57, -1331, 7, 21)
	Ground.grassPatch(-17, -1349, 4, 7)
	Decor.nature(habitat, "AsuraRoots", CFrame.new(-56, Ground.surfaceHeight(-56, -1337, -0.1) - 0.05, -1337)
		* CFrame.Angles(0, 0.8, 0), 12)
	detail(habitat, "Bamboo_BrokenClump", CFrame.new(-53, Ground.surfaceHeight(-53, -1334, -0.1), -1334)
		* CFrame.Angles(0, 2.1, 0), 0.8, rgb(255, 255, 255))
	map:SetAttribute("BambooArtPass", "Living groves, breakage and shrine v8; arena/ridge/exit in review")
end

-- Moon-gate shoulders and the ash descent beyond it: the road keeps its flags clear (|x| < 14),
-- clumps stand between the flags and the veil (|x| < 30), and planting hugs the palisade feet.
-- Budgeted: these clumps are seen through the gate from Baize's arena, so they use plain crowns
-- and one fern each (sculpted crowns cost ~72k triangles at the arena camera; PERFORMANCE.md).
function Ecology.South(map: Instance, layout: any, rng: Random)
	local habitat = Kit.folder("LivingBambooSouth", map)
	for _, side in { -1, 1 } do
		for i = 0, 4 do
			local z = -1596 - i * 17 + rng:NextNumber(-3, 3)
			local x = side * rng:NextNumber(20, 25)
			Ground.forestFloor(x, z, 7, 9)
			clump(habitat, layout, x, z, (i + (if side > 0 then 2 else 0)) % #styles + 1, rng, true)
			for k = 1, 1 do
				local fx, fz = x - side * rng:NextNumber(2, 5), z + rng:NextNumber(-5, 5)
				local frame = CFrame.new(fx, Ground.surfaceHeight(fx, fz, -0.1) + 0.02, fz) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
				local fern = detail(habitat, "Ground_Fern", frame, rng:NextNumber(0.8, 1.4), rgb(255, 255, 255))
				if fern then wind(fern, frame, 2, "Fern") end
				if k == 1 then detail(habitat, "Ground_LeafLitter", frame * CFrame.new(1, -0.04, -1), 0.9, rgb(255, 255, 255)) end
			end
			if i % 2 == 1 then Ground.grassPatch(side * rng:NextNumber(15, 18), z + 6, 3.5, 7) end
		end
		-- Planted shoulders at the jamb feet, both faces of the palisade.
		for _, z in { -1569, -1585 } do
			local x = side * rng:NextNumber(21, 25)
			local y = Ground.surfaceHeight(x, z, -0.1)
			Decor.han(habitat, "AsuraHanKit", "BoulderSmall", CFrame.new(x, y - 0.25, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(7, 9))
			local frame = CFrame.new(x - side * 2.5, y + 0.02, z + 1) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
			local fern = detail(habitat, "Ground_Fern", frame, 1.1, rgb(255, 255, 255))
			if fern then wind(fern, frame, 2, "Fern") end
			local shootFrame = CFrame.new(x + side * 2, y - 0.03, z - 1.5) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
			local shoots = detail(habitat, "Bamboo_YoungShoots", shootFrame, 0.75, rgb(255, 255, 255))
			if shoots then wind(shoots, shootFrame, 4, "Shoot") end
		end
	end
	detail(habitat, "Bamboo_FallenPole", CFrame.new(-19, Ground.surfaceHeight(-19, -1640, -0.1), -1640) * CFrame.Angles(0, 0.4, 0), 1, rgb(255, 255, 255))
	map:SetAttribute("BambooArtPass", "Living groves, breakage, shrine, moon gate and ridge margins v9")
end

return Ecology
