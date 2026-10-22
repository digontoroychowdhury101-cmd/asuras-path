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
	TerraceRock = { Material = M.Rock, Variant = "AsuraRock", Color = rgb(170, 166, 160) },
	Lacquer = { Material = M.Wood, Variant = "AsuraLacquer", Color = rgb(255, 255, 255) },
	Timber = { Material = M.Wood, Variant = "AsuraTimber", Color = rgb(255, 255, 255) },
	Bronze = { Material = M.Metal, Variant = "AsuraBronze", Color = rgb(255, 255, 255) },
	RoofTile = { Material = M.Slate, Variant = "AsuraRoofTile", Color = rgb(255, 255, 255) },
} :: { [string]: Surface })

Kit.Palette = table.freeze({
	Lantern = rgb(255, 178, 98),
	Paper = rgb(255, 205, 140),
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

-- A glowing paper box with a warm light (lantern heads, hung lamps). Never collides.
function Kit.glow(parent: Instance, cf: CFrame, size: Vector3, range: number, brightness: number?): BasePart
	local paper = Base.part(parent, "LanternPaper", size, cf, Kit.Palette.Paper, M.Neon, Base.decor())
	paper.Transparency = 0.22
	Base.light(paper, Kit.Palette.Lantern, range, brightness or 1.15, false)
	return paper
end

return table.freeze(Kit)
