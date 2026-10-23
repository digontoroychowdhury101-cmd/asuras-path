--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/SanctuaryKit
-- The Shrine of the Ascendant's modular architecture kit: ServerStorage.AsuraLobbyKit
-- (assets/models/AsuraLobbyKit.rbxmx), modelled by tools/blender/lobby_kit.py and uploaded through
-- Studio's 3D Importer (IDs in assets/LOBBY_KIT_UPLOADED.json). Each piece is a Model of MeshParts
-- sitting at the origin; a piece is placed by its pivot - base centre on the floor for upright pieces,
-- eave line for roofs, top centre for hanging cliffs - and may be scaled per axis in its own frame.
-- Kit meshes never collide, touch or answer queries; builders lay simple primitive collision beside
-- them. Primitives that must match the meshes use the shared MaterialVariants (MaterialService.Asura*),
-- made from the same uploaded maps. A missing template returns nil so builders keep a fallback.
local ServerStorage = game:GetService("ServerStorage")
local Base = require(script.Parent:WaitForChild("MonasteryKit") :: ModuleScript)

local Kit = {}
Kit.part, Kit.disc, Kit.folder, Kit.decor, Kit.hidden, Kit.light, Kit.sequence =
	Base.part, Base.disc, Base.folder, Base.decor, Base.hidden, Base.light, Base.sequence

local rgb = Color3.fromRGB
local M = Enum.Material

export type Surface = { Material: Enum.Material, Variant: string, Color: Color3 }
-- Part.Color tints a MaterialVariant's colour map, so white shows the authored texture.
Kit.Surface = table.freeze({
	Paving = { Material = M.Slate, Variant = "AsuraPaving", Color = rgb(139, 153, 167) },
	PavingPath = { Material = M.Slate, Variant = "AsuraPaving", Color = rgb(167, 177, 187) },
	Stone = { Material = M.Slate, Variant = "AsuraStone", Color = rgb(148, 158, 170) },
	StoneDark = { Material = M.Slate, Variant = "AsuraStone", Color = rgb(100, 112, 126) },
	Basin = { Material = M.Slate, Variant = "AsuraStone", Color = rgb(52, 80, 76) },
	Rock = { Material = M.Rock, Variant = "AsuraRock", Color = rgb(226, 222, 216) },
	TerracePaving = { Material = M.Slate, Variant = "AsuraPaving", Color = rgb(221, 228, 235) },
	Lacquer = { Material = M.Wood, Variant = "AsuraLacquer", Color = rgb(255, 255, 255) },
	Timber = { Material = M.Wood, Variant = "AsuraTimber", Color = rgb(255, 255, 255) },
	Bronze = { Material = M.Metal, Variant = "AsuraBronze", Color = rgb(255, 255, 255) },
	RoofTile = { Material = M.Slate, Variant = "AsuraRoofTile", Color = rgb(255, 255, 255) },
} :: { [string]: Surface })

Kit.Palette = table.freeze({
	Lantern = rgb(255, 175, 95),
	Paper = rgb(225, 193, 145),
	Banner = rgb(104, 22, 24),
	BannerDark = rgb(42, 14, 16),
	Gold = rgb(214, 168, 92),
	Jade = rgb(120, 196, 176),
	Water = rgb(38, 86, 82),
	Iron = rgb(34, 32, 34),
})

local function template(name: string): Model?
	local library = ServerStorage:FindFirstChild("AsuraLobbyKit")
	local piece = library and library:FindFirstChild(name)
	if not piece then
		local vista = ServerStorage:FindFirstChild("AsuraSanctuaryVista")
		piece = vista and vista:FindFirstChild(name)
	end
	if not piece then
		local detail = ServerStorage:FindFirstChild("AsuraSanctuaryDetail")
		piece = detail and detail:FindFirstChild(name)
	end
	if not piece and name == "AsuraGuardianLion" then piece = ServerStorage:FindFirstChild(name) end
	return if piece and piece:IsA("Model") then piece else nil
end

function Kit.available(): boolean
	return template("Rail_Bay") ~= nil
end

-- Clones a piece with its pivot at `cf`. `scale` is uniform or per axis (piece frame). Every kit part
-- has an identity orientation in its template, so a per-axis scale is exact.
function Kit.place(parent: Instance, name: string, cf: CFrame, scale: (number | Vector3)?, shadow: boolean?): Model?
	local source = template(name)
	if not source then
		return nil
	end
	local s = if typeof(scale) == "Vector3" then scale elseif typeof(scale) == "number" then Vector3.one * scale else Vector3.one
	local model = Instance.new("Model")
	model.Name = name
	for _, child in source:GetChildren() do
		if child:IsA("BasePart") then
			local copy = child:Clone()
			copy.Size = child.Size * s
			copy.CFrame = cf * CFrame.new(child.Position * s)
			copy.CastShadow = shadow ~= false
			local finish = copy:FindFirstChildOfClass("SurfaceAppearance")
			if finish then
				if name:find("^Vista_") then
					-- Vista templates carry the scanned-rock tint checked in Studio.
				elseif child.Name:find("__Stone") then finish.Color = rgb(126, 141, 158)
				elseif child.Name:find("__Lacquer") then finish.Color = rgb(119, 78, 72)
				elseif child.Name:find("__Bronze") then finish.Color = rgb(178, 143, 92)
				elseif child.Name:find("__Paving") then finish.Color = rgb(156, 166, 179)
				end
			end
			copy.Parent = model
		end
	end
	model.WorldPivot = cf
	model.Parent = parent
	return model
end

-- One shared, double-sided mesh replaces two Decals per leaf plane. The saved template
-- carries its alpha SurfaceAppearance; all clones can share geometry and texture bindings.
function Kit.branchCard(parent: Instance, frame: CFrame, width: number, height: number, tint: Color3): BasePart?
	local source = template("Detail_BranchCard")
	local mesh = source and source:FindFirstChildWhichIsA("MeshPart")
	if not mesh then return nil end
	local copy = mesh:Clone()
	copy.Name, copy.Size, copy.CFrame = "CrimsonBranchSpray", Vector3.new(width, height, 0.001), frame
	copy.Color, copy.CastShadow = tint, false
	local finish = copy:FindFirstChildOfClass("SurfaceAppearance")
	if finish then finish.Color = tint end
	copy:SetAttribute("AsuraFoliage", true)
	copy.Parent = parent
	return copy
end

-- A primitive in one of the shared surfaces (collides unless told otherwise).
function Kit.slab(parent: Instance, name: string, size: Vector3, cf: CFrame, surface: string, options: Base.PartOptions?): BasePart
	local s = Kit.Surface[surface]
	local p = Base.part(parent, name, size, cf, s.Color, s.Material, options)
	p.MaterialVariant = s.Variant
	return p
end

-- Invisible movement collision between two floor points: bodies stop, cameras and queries pass.
function Kit.blocker(parent: Instance, name: string, a: Vector3, b: Vector3, height: number, thickness: number): BasePart
	local mid = (a + b) * 0.5 + Vector3.yAxis * height * 0.5
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local cf = if flat.Magnitude > 1e-3 then CFrame.lookAt(mid, mid + flat) else CFrame.new(mid)
	return Base.part(parent, name, Vector3.new(thickness, height, math.max(flat.Magnitude, 0.2)), cf, rgb(0, 0, 0), M.SmoothPlastic,
		{ Collide = true, Query = false, Transparency = 1, Shadow = false })
end

-- Frame whose X axis runs from `a` to `b` (Y up): kit pieces lie along their X.
function Kit.along(a: Vector3, b: Vector3, at: Vector3?): CFrame
	local x = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Unit
	return CFrame.fromMatrix(at or (a + b) * 0.5, x, Vector3.yAxis)
end

-- Frosted paper lantern chamber. Its shell is a separate PBR kit mesh; these thin, shaded paper
-- panes sit inside its posts. Only the tiny rounded flame emits, so the chamber never reads as an
-- unshaded neon brick. A light remains warm and local even when distant bloom catches the flame.
function Kit.glow(parent: Instance, cf: CFrame, size: Vector3, range: number, brightness: number?, sides: number?): BasePart
	local chamber = Instance.new("Model")
	chamber.Name = if size.X < 0.3 then "CandleFlame" else "FrostedLanternChamber"
	chamber.Parent = parent
	local anchor = Base.hidden(chamber, "WarmLightSource", Vector3.new(0.1, 0.1, 0.1), cf)
	local candle = size.X < 0.3
	local flameSize = if candle then size else Vector3.new(size.X * 0.22, size.Y * 0.38, size.Z * 0.22)
	local flame = Base.part(chamber, "ShelteredFlame", flameSize, cf, rgb(237, 161, 77), M.Neon,
		{ Collide = false, Query = false, Shadow = false, Shape = Enum.PartType.Ball, Transparency = if candle then 0.18 else 0.48 })
	flame.CastShadow = false
	if not candle then
		local count = sides or 4
		local apothem = math.min(size.X, size.Z) * 0.5
		local panelWidth = 2 * apothem * math.tan(math.pi / count)
		for k = 0, count - 1 do
			local angle = math.pi * 2 * k / count
			local face = cf * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -apothem)
			local paper = Base.part(chamber, "FrostedPaperPane", Vector3.new(panelWidth, size.Y, 0.028), face,
				rgb(151, 101, 58), M.Neon, Base.decor())
			paper.Transparency = 0.35 -- low-energy emissive paper, individually framed inside the housing
			-- Fine timber muntin gives the lit paper a crafted scale against the carved stone housing.
			Kit.slab(chamber, "PaperMuntin", Vector3.new(0.035, size.Y + 0.035, 0.038), face * CFrame.new(0, 0, -0.024), "Timber", Base.decor())
		end
	end
	Base.light(anchor, Kit.Palette.Lantern, if candle then range else math.clamp(range, 12, 16),
		if candle then (brightness or 0.35) else math.clamp(brightness or 1.35, 1.2, 1.5), true)
	return anchor
end

-- Complete emergency housing when a library is unavailable (never a bare glowing post).
-- Normal play uses the Blender-authored curved eaves, mouldings and timber/bronze PBR meshes.
function Kit.lanternFallback(parent: Instance, cf: CFrame, hanging: boolean)
	local shell = Instance.new("Model")
	shell.Name = if hanging then "HangingLanternHousing" else "PagodaLanternHousing"
	shell.Parent = parent
	local mid = if hanging then -1.3 else 3.35
	local half = if hanging then 0.55 else 0.66
	local surface = if hanging then "Bronze" else "Stone"
	if not hanging then
		for _, course in { { 2.0, 0.4, 0.2 }, { 1.6, 0.3, 0.55 }, { 0.9, 1.7, 1.55 }, { 1.85, 0.3, 2.55 } } do
			Kit.slab(shell, "StoneLanternCourse", Vector3.new(course[1], course[2], course[1]), cf * CFrame.new(0, course[3], 0), surface, Base.decor())
		end
	end
	for _, x in { -half, half } do
		for _, z in { -half, half } do
			Kit.slab(shell, "WindowCorner", Vector3.new(0.16, 1.32, 0.16), cf * CFrame.new(x, mid, z), surface, Base.decor())
		end
	end
	for _, y in { mid - 0.72, mid + 0.72 } do
		Kit.slab(shell, "WindowSill", Vector3.new(half * 2 + 0.35, 0.16, half * 2 + 0.35), cf * CFrame.new(0, y, 0), surface, Base.decor())
	end
	local roof = mid + 0.94
	for k = 0, 3 do
		local face = cf * CFrame.Angles(0, math.pi / 2 * k, 0)
		Kit.slab(shell, "PagodaRoofSlope", Vector3.new(1.75, 0.16, 0.92), face * CFrame.new(0, roof, 0.48) * CFrame.Angles(math.rad(23), 0, 0), surface, Base.decor())
	end
	Kit.part(shell, "LotusFinial", Vector3.new(0.35, 0.45, 0.35), cf * CFrame.new(0, roof + 0.45, 0), Kit.Surface[surface].Color, M.Slate,
		{ Collide = false, Query = false, Shadow = false, Shape = Enum.PartType.Ball })
	if hanging then
		Kit.slab(shell, "Suspension", Vector3.new(0.07, 0.33, 0.07), cf * CFrame.new(0, -0.17, 0), "Bronze", Base.decor())
	end
end

return table.freeze(Kit)
