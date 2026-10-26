--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/RegionDecor
-- Builders shared by the authored campaign regions (batches 16-21). Layout boxes become parts in
-- the Monastery's slate / lacquer / tile / granite vocabulary (batch 15, #32): every Kind maps to one
-- material and palette entry, no Neon or SmoothPlastic. Everything added here beyond a layout box is
-- decor (no collision, no queries), so the offline reachability suite sees every surface that can
-- stop a body or a camera.
local Kit = require(script.Parent:WaitForChild("MonasteryKit") :: ModuleScript)
local Fx = require(script.Parent:WaitForChild("MonasteryFx") :: ModuleScript)

local Decor = {}
local P = Kit.Palette
local M = Enum.Material
local rgb = Color3.fromRGB

Decor.Style = table.freeze({
	Path = { M.Slate, P.FlagDark }, Ground = { M.Ground, rgb(66, 58, 50) }, Grass = { M.Grass, rgb(70, 82, 58) },
	Rock = { M.Rock, rgb(74, 76, 80) }, Snow = { M.Snow, rgb(214, 222, 226) }, Timber = { M.Wood, P.WoodDark },
	Lacquer = { M.Wood, P.Lacquer }, Stone = { M.Slate, P.Stone }, Ash = { M.Ground, rgb(58, 54, 54) },
	Basalt = { M.Basalt, rgb(64, 60, 62) }, Crypt = { M.Slate, rgb(70, 78, 84) }, Marble = { M.Marble, rgb(196, 192, 184) },
	Bone = { M.Limestone, rgb(206, 196, 170) }, Water = { M.Glass, rgb(40, 74, 82) }, Tile = { M.Slate, rgb(86, 82, 80) },
})

-- PBR MaterialVariants shared with the lobby (and the GitHub terrain set); Color tints the colour
-- map, so these replace the flat Style tint. Kinds absent here keep their plain material.
Decor.Variant = table.freeze({
	Path = { "AsuraPaving", rgb(139, 153, 167) }, Stone = { "AsuraStone", rgb(148, 158, 170) },
	Crypt = { "AsuraStone", rgb(100, 112, 126) }, Tile = { "AsuraPaving", rgb(167, 177, 187) },
	Timber = { "AsuraTimber", rgb(255, 255, 255) }, Lacquer = { "AsuraLacquer", rgb(255, 255, 255) },
	Grass = { "AsuraGrass", rgb(255, 255, 255) }, Rock = { "AsuraCliff", rgb(226, 222, 216) },
	Ash = { "AsuraGravel", rgb(120, 116, 114) }, Basalt = { "AsuraBasalt", rgb(255, 255, 255) },
})

-- One layout box as a part. Veils collide but are invisible to eyes, cameras and queries.
function Decor.solid(parent: Instance, b: any): BasePart
	local cf = CFrame.new(b.X, b.Y, b.Z) * CFrame.Angles(0, math.rad(b.Yaw), 0)
	if b.Kind == "Veil" then
		return Kit.part(parent, "MistVeil", Vector3.new(b.SX, b.SY, b.SZ), cf, P.Mist, M.Slate, { Collide = true, Query = false, Transparency = 1, Shadow = false })
	end
	local style = Decor.Style[b.Kind]
	local p = Kit.part(parent, b.Name, Vector3.new(b.SX, b.SY, b.SZ), cf, style[2], style[1])
	if b.Kind == "Water" then
		p.Transparency, p.Reflectance = 0.15, 0.3
	end
	local variant = Decor.Variant[b.Kind]
	if variant then
		p.MaterialVariant, p.Color = variant[1], variant[2]
	end
	return p
end

-- Paper lantern head on a post (or hung from a beam): warm light, glow, never collides.
function Decor.lantern(parent: Instance, x: number, y: number, z: number, range: number?)
	local base = CFrame.new(x, y, z)
	local paper = Kit.part(parent, "LanternPaper", Vector3.new(1.4, 1.6, 1.4), base, P.Lantern, M.Glass,
		{ Collide = false, Query = false, Transparency = 0.25, Shadow = false })
	Kit.part(parent, "LanternCap", Vector3.new(2.2, 0.35, 2.2), base * CFrame.new(0, 1, 0), P.Iron, M.Metal, Kit.decor())
	Fx.glow(paper, 1.1)
	Kit.light(paper, P.Lantern, range or 20, 1.3, false)
end

-- Blender-built Bamboo Pass art (tools/blender/bamboo_karst_kit.py): Bamboo_A/B/C stalks 40 studs tall
-- and Karst_A/B/C towers ~107 studs tall, each pivoted at its foot centre. Nil when the kit is missing.
local KIT_HEIGHT = { Bamboo = 41, Karst = 107 }
function Decor.kit(kind: string, rng: Random): Model?
	local kit = game:GetService("ServerStorage"):FindFirstChild("AsuraBambooKit")
	local piece = kit and kit:FindFirstChild(kind .. "_" .. ({ "A", "B", "C" })[rng:NextInteger(1, 3)])
	return if piece and piece:IsA("Model") then piece:Clone() else nil
end

-- Places a kit clone `height` studs tall with its foot at `base`.
function Decor.placeKit(parent: Instance, model: Model, kind: string, base: CFrame, height: number)
	model:ScaleTo(height / KIT_HEIGHT[kind])
	model:PivotTo(base)
	model.Parent = parent
end

-- Uploaded Han architecture (ServerStorage.AsuraHanHD from tools/blender/han_hd.py, AsuraHanKit from
-- tools/blender/han_kit.py): a clone of `piece` scaled by `scale` with its base centre at `base`.
-- Decor only (no collision, queries or touches). Nil when the kit or piece is missing.
function Decor.han(parent: Instance, kit: string, piece: string, base: CFrame, scale: number?): Model?
	local library = game:GetService("ServerStorage"):FindFirstChild(kit)
	local template = library and library:FindFirstChild(piece)
	if not template or not template:IsA("Model") then
		return nil
	end
	local model = template:Clone()
	model:ScaleTo(scale or 1)
	model:PivotTo(base)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
			d:SetAttribute("AsuraDecorative", true)
		end
	end
	model.Parent = parent
	return model
end

-- One bamboo stalk with its leaf sprays; decor, so groves never trap bodies or cameras.
function Decor.bamboo(parent: Instance, x: number, floor: number, z: number, rng: Random)
	local height = rng:NextNumber(26, 44)
	local lean = CFrame.Angles(math.rad(rng:NextNumber(-5, 5)), 0, math.rad(rng:NextNumber(-5, 5)))
	local base = CFrame.new(x, floor, z) * lean
	local stalk = Decor.kit("Bamboo", rng)
	if stalk then
		Decor.placeKit(parent, stalk, "Bamboo", base * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0), height)
		return
	end
	local green = rgb(78, 104, 66):Lerp(rgb(132, 140, 92), rng:NextNumber())
	Kit.part(parent, "BambooStalk", Vector3.new(height, 0.9, 0.9), base * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		green, M.Wood, { Collide = false, Query = false, Shadow = true, Shape = Enum.PartType.Cylinder })
	if rng:NextNumber() < 0.6 then
		Kit.part(parent, "BambooCrown", Vector3.new(rng:NextNumber(5, 8), 2.2, rng:NextNumber(5, 8)), base * CFrame.new(0, height - 2, 0)
			* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), rgb(88, 116, 70), M.LeafyGrass, Kit.decor())
	end
end

-- Scatter `count` items over {x0, x1, z0, z1, floor, count} with `place(x, floor, z)`.
function Decor.scatter(grove: { number }, rng: Random, place: (number, number, number) -> ())
	for _ = 1, grove[6] do
		place(rng:NextNumber(grove[1], grove[2]), grove[5], rng:NextNumber(math.min(grove[3], grove[4]), math.max(grove[3], grove[4])))
	end
end

-- Curved-eave tile roof (two slopes, ridge, upturned horns), decor; `base` is the eave line centre.
function Decor.roof(parent: Instance, base: CFrame, width: number, depth: number, rise: number, color: Color3?)
	local tone = color or P.Roof
	local slope = math.atan(rise / (depth / 2))
	local length = math.sqrt((depth / 2) ^ 2 + rise ^ 2) + 1
	for _, side in { -1, 1 } do
		Kit.part(parent, "RoofSlope", Vector3.new(width, 0.6, length), base * CFrame.new(0, rise / 2, side * depth / 4) * CFrame.Angles(side * slope, 0, 0),
			tone, M.Slate, Kit.decor())
		Kit.beam(parent, "EaveHorn", (base * CFrame.new(side * width / 2, 0, 0)).Position, (base * CFrame.new(side * (width / 2 + 2), 1.6, 0)).Position, 0.5, P.Iron, M.Metal)
	end
	Kit.part(parent, "RoofRidge", Vector3.new(width + 1, 0.7, 0.7), base * CFrame.new(0, rise + 0.2, 0), P.Iron, M.Metal, Kit.decor())
end

-- Hanging banner (crimson cloth on a crossbar); decor.
function Decor.banner(parent: Instance, top: CFrame, height: number, color: Color3?)
	Kit.part(parent, "BannerBar", Vector3.new(4.4, 0.3, 0.3), top, P.Iron, M.Metal, Kit.decor())
	Kit.part(parent, "BannerCloth", Vector3.new(3.6, height, 0.12), top * CFrame.new(0, -height / 2 - 0.2, 0), color or P.Lacquer, M.Fabric, Kit.decor())
end

-- Iron brazier with fire, embers and a warm light; decor.
function Decor.brazier(parent: Instance, base: CFrame, range: number?)
	Kit.part(parent, "BrazierLeg", Vector3.new(0.6, 3, 0.6), base * CFrame.new(0, 1.5, 0), P.Iron, M.Metal, Kit.decor())
	local bowl = Kit.part(parent, "BrazierBowl", Vector3.new(2.6, 0.8, 2.6), base * CFrame.new(0, 3.2, 0), P.Iron, M.Metal, Kit.decor())
	Fx.glow(bowl, 1.8)
	Fx.embers(bowl, 6)
	Kit.light(bowl, rgb(255, 160, 90), range or 24, 1.6, false)
end

return Decor
