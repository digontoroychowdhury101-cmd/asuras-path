--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/MonasteryKit
-- Shared construction kit for the Desecrated Monastery map: palette, texture ids and part
-- builders. No Neon, no SmoothPlastic anywhere in the map (MonasteryFx supplies the glow).
local Kit = {}

-- Walkable flagstone top. Terrain sits flush at Y = 0 beneath, so stones always cover it.
Kit.GROUND = 0.2

Kit.Palette = {
	Flag = Color3.fromRGB(104, 100, 93),
	FlagDark = Color3.fromRGB(80, 77, 72),
	Stone = Color3.fromRGB(108, 104, 97),
	StoneDark = Color3.fromRGB(62, 61, 61),
	Moss = Color3.fromRGB(56, 62, 46),
	Iron = Color3.fromRGB(30, 29, 31),
	Rust = Color3.fromRGB(82, 48, 34),
	Wood = Color3.fromRGB(48, 36, 30),
	WoodDark = Color3.fromRGB(30, 24, 22),
	Lacquer = Color3.fromRGB(78, 24, 22),
	Roof = Color3.fromRGB(34, 36, 38),
	Root = Color3.fromRGB(198, 188, 168),
	Leaf = Color3.fromRGB(132, 22, 26),
	LeafDark = Color3.fromRGB(82, 14, 18),
	Lantern = Color3.fromRGB(240, 162, 86),
	Mist = Color3.fromRGB(196, 186, 180),
	Dawn = Color3.fromRGB(214, 176, 150),
}

Kit.Texture = {
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Sparks = "rbxasset://textures/particles/fire_sparks_main.dds",
	Mote = "rbxasset://textures/particles/sparkles_main.dds",
}

export type PartOptions = { Collide: boolean?, Query: boolean?, Transparency: number?, Shadow: boolean?, Shape: Enum.PartType?, Class: string? }

function Kit.folder(name: string, parent: Instance): Folder
	local created = Instance.new("Folder")
	created.Name = name
	created.Parent = parent
	return created
end

function Kit.part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, options: PartOptions?): BasePart
	local o: PartOptions = options or {}
	local p = Instance.new((o.Class or "Part") :: any) :: BasePart
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false
	p.CanCollide = if o.Collide == nil then true else o.Collide
	p.CanQuery = if o.Query == nil then p.CanCollide else o.Query
	p.Transparency = o.Transparency or 0
	p.CastShadow = if o.Shadow == nil then true else o.Shadow
	if o.Shape and p:IsA("Part") then
		p.Shape = o.Shape
	end
	p.Parent = parent
	return p
end

-- Upright cylinder centred on `center` (Roblox cylinders run along local X).
function Kit.disc(parent: Instance, name: string, radius: number, height: number, center: CFrame, color: Color3, material: Enum.Material, options: PartOptions?): BasePart
	local o: PartOptions = if options then table.clone(options) else {}
	o.Shape = Enum.PartType.Cylinder
	return Kit.part(parent, name, Vector3.new(height, radius * 2, radius * 2), center * CFrame.Angles(0, 0, math.rad(90)), color, material, o)
end

function Kit.decor(): PartOptions
	return { Collide = false, Query = false, Shadow = false }
end

-- Invisible emitter / anchor volume.
function Kit.hidden(parent: Instance, name: string, size: Vector3, cframe: CFrame): BasePart
	return Kit.part(parent, name, size, cframe, Kit.Palette.Stone, Enum.Material.Slate, { Collide = false, Query = false, Transparency = 1, Shadow = false })
end

function Kit.beam(parent: Instance, name: string, a: Vector3, b: Vector3, thickness: number, color: Color3, material: Enum.Material?, collide: boolean?): BasePart
	return Kit.part(parent, name, Vector3.new(thickness, thickness, (b - a).Magnitude), CFrame.lookAt((a + b) * 0.5, b), color,
		material or Enum.Material.Wood, if collide then nil else Kit.decor())
end

function Kit.sequence(points: { { number } }): NumberSequence
	local keys = {}
	for _, point in points do
		table.insert(keys, NumberSequenceKeypoint.new(point[1], point[2]))
	end
	return NumberSequence.new(keys)
end

function Kit.light(parent: BasePart, color: Color3, range: number, brightness: number, shadows: boolean): PointLight
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Shadows = color, range, brightness, shadows
	l.Parent = parent
	return l
end

return Kit
