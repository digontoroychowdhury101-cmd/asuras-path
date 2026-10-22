--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/MonasteryRuins
-- Masonry of the Desecrated Monastery: crumbling enclosure walls with tiled coping, the pagoda
-- roof builder shared by every building, the lacquered gatehouse the player arrives beneath, the
-- ravine parapets and the south exit gate toward the Bamboo Pass.
local Kit = require(script.Parent:WaitForChild("MonasteryKit") :: ModuleScript)
local Fx = require(script.Parent:WaitForChild("MonasteryFx") :: ModuleScript)

local Ruins = {}

local P = Kit.Palette
local G = Kit.GROUND
local SLATE, COBBLE, WOOD, METAL = Enum.Material.Slate, Enum.Material.Cobblestone, Enum.Material.Wood, Enum.Material.Metal

local function rubble(parent: Instance, at: Vector3, rng: Random, count: number)
	for _ = 1, count do
		local s = rng:NextNumber(0.8, 2.2)
		Kit.part(parent, "Rubble", Vector3.new(s * 1.4, s * 0.7, s), CFrame.new(at + Vector3.new(rng:NextNumber(-3, 3), G + s * 0.3, rng:NextNumber(-3, 3)))
			* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, math.pi), rng:NextNumber(-0.4, 0.4)), P.Stone:Lerp(P.Moss, rng:NextNumber(0, 0.4)), COBBLE)
	end
end

-- Wall from a to b (XZ plane) built in ~6-stud courses: some crumble, some are breached.
function Ruins.wall(parent: Instance, a: Vector2, b: Vector2, height: number, rng: Random, breach: number?, coping: boolean?)
	local group = Kit.folder("Wall", parent)
	local delta = b - a
	local count = math.max(1, math.round(delta.Magnitude / 6))
	local seg = delta.Magnitude / count
	local dir = Vector3.new(delta.Unit.X, 0, delta.Unit.Y)
	for k = 0, count - 1 do
		local c = Vector3.new(a.X, 0, a.Y) + dir * (k + 0.5) * seg
		local frame = CFrame.lookAt(c, c + dir)
		if rng:NextNumber() < (breach or 0.1) then
			rubble(group, c, rng, 4)
			continue
		end
		local crumbled = rng:NextNumber() < 0.35
		local h = if crumbled then height * rng:NextNumber(0.4, 0.85) else height
		Kit.part(group, "Plinth", Vector3.new(3.2, 1.4, seg + 0.05), frame * CFrame.new(0, G + 0.7, 0), P.StoneDark, SLATE)
		Kit.part(group, "Course", Vector3.new(2.4, h - 1.4, seg + 0.02), frame * CFrame.new(0, G + 1.4 + (h - 1.4) * 0.5, 0),
			P.Stone:Lerp(P.Moss, rng:NextNumber(0, 0.3)):Lerp(P.StoneDark, rng:NextNumber(0, 0.4)), COBBLE)
		if coping ~= false and not crumbled then
			Kit.part(group, "Coping", Vector3.new(4, 0.5, seg + 0.3), frame * CFrame.new(0, G + h + 0.25, 0), P.Roof, SLATE)
			Kit.part(group, "CopingRidge", Vector3.new(0.7, 0.5, seg + 0.3), frame * CFrame.new(0, G + h + 0.7, 0), P.Iron, SLATE, Kit.decor())
		elseif crumbled then
			rubble(group, c + frame.RightVector * (if rng:NextNumber() < 0.5 then 3 else -3), rng, 2)
		end
	end
	return group
end

-- Curved two-slope tiled roof. `base` sits at eave height, ridge along local Z; `broken` roofs
-- shed tile courses and show their rafters.
function Ruins.roof(parent: Instance, base: CFrame, width: number, depth: number, rng: Random, broken: boolean?)
	local group = Kit.folder("PagodaRoof", parent)
	local half, rise = width * 0.5, width * 0.22
	local function height(t: number): number
		return rise * (1 - t) ^ 1.35 + rise * 0.4 * t ^ 7
	end
	for side = -1, 1, 2 do
		for strip = 0, 5 do
			local t0, t1 = strip / 6, (strip + 1) / 6
			local x0, x1, y0, y1 = side * half * t0, side * half * t1, height(t0), height(t1)
			local frame = base * CFrame.new((x0 + x1) * 0.5, (y0 + y1) * 0.5, 0) * CFrame.Angles(0, 0, math.atan((y1 - y0) / (x1 - x0)))
			local length = math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
			if broken and strip > 0 and strip < 5 and rng:NextNumber() < 0.3 then
				for z = -depth * 0.4, depth * 0.4, depth * 0.2 do
					Kit.part(group, "Rafter", Vector3.new(length + 0.4, 0.35, 0.35), frame * CFrame.new(0, -0.2, z), P.WoodDark, WOOD, Kit.decor())
				end
			else
				Kit.part(group, "Tiles", Vector3.new(length + 0.12, 0.4, depth), frame, P.Roof:Lerp(P.StoneDark, if strip % 2 == 0 then 0.1 else 0.3), SLATE, Kit.decor())
			end
		end
		for face = -1, 1, 2 do
			Kit.beam(group, "EaveHorn", (base * CFrame.new(side * (half - 1.5), height(0.9), face * depth * 0.5)).Position,
				(base * CFrame.new(side * (half + 1.4), height(1) + 1.8, face * (depth * 0.5 + 0.6))).Position, 0.4, P.Iron, METAL)
		end
	end
	Kit.part(group, "Ridge", Vector3.new(0.7, 0.7, depth + 1.5), base * CFrame.new(0, rise + 0.3, 0), P.Iron, METAL, Kit.decor())
	return group
end

function Ruins.inscription(parent: BasePart, text: string)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(150, 128, 92)
	label.TextScaled = true
	label.Font = Enum.Font.Antique
	label.Parent = gui
	gui.Parent = parent
end

-- Three-bay lacquered gatehouse; side bays are walled up so the centre bay frames the courtyard.
local function gatehouse(parent: Instance, z: number, rng: Random)
	local g = Kit.folder("Gatehouse", parent)
	for _, x in { -19, -8, 8, 19 } do
		Kit.part(g, "PillarBase", Vector3.new(3.6, 1.2, 3.6), CFrame.new(x, G + 0.6, z), P.StoneDark, SLATE)
		Kit.part(g, "Pillar", Vector3.new(2.4, 17, 2.4), CFrame.new(x, G + 9.7, z), P.Lacquer:Lerp(P.WoodDark, 0.4), WOOD)
	end
	Kit.part(g, "Lintel", Vector3.new(46, 1.8, 2.8), CFrame.new(0, G + 18.1, z), P.WoodDark, WOOD)
	Kit.part(g, "TieBeam", Vector3.new(18, 1.2, 2.2), CFrame.new(0, G + 13.2, z), P.WoodDark, WOOD)
	local plaque = Kit.part(g, "Plaque", Vector3.new(6, 2.6, 0.4), CFrame.new(0, G + 15.6, z + 1.3) * CFrame.Angles(0, math.pi, 0), P.WoodDark, WOOD)
	Ruins.inscription(plaque, "ANCIENT TEMPLE")
	Ruins.roof(g, CFrame.new(0, G + 19, z) * CFrame.Angles(0, math.pi / 2, 0), 11, 50, rng, true)
	for side = -1, 1, 2 do
		Kit.part(g, "BayWall", Vector3.new(8.6, 7, 2.2), CFrame.new(side * 13.5, G + 3.5, z), P.Stone, COBBLE)
		Fx.lantern(g, CFrame.new(side * 5, G + 10.6, z + 1.8), true, 22)
	end
end

function Ruins.Build(parent: Instance, rng: Random)
	local walls = Kit.folder("Walls", parent)
	local function run(x0: number, z0: number, x1: number, z1: number, h: number, breach: number?, coping: boolean?)
		Ruins.wall(walls, Vector2.new(x0, z0), Vector2.new(x1, z1), h, rng, breach, coping)
	end
	-- Courtyard enclosure (north wall meets the gatehouse, south wall opens on the processional path).
	run(-82, -752, -21, -752, 12)
	run(21, -752, 82, -752, 12)
	run(-82, -752, -82, -826, 12, 0.12) -- the west postern (z -826..-834) opens on the waterfall path
	run(-82, -834, -82, -858, 12, 0.12)
	-- East wall opens (z -800..-822) on the road through the ridge pass to the Twins' side plateau.
	run(82, -752, 82, -800, 12, 0.12)
	run(82, -822, 82, -858, 12, 0.12)
	run(-82, -858, -16, -858, 8, 0.25)
	run(16, -858, 82, -858, 8, 0.25)
	run(-26, -698, -26, -748, 3.2, 0.15, false) -- arrival landing parapets
	run(26, -698, 26, -748, 3.2, 0.15, false)
	run(-26, -698, 26, -698, 3.2, 0.2, false)
	-- Ravine lips, broken where the ground slumped.
	run(-120, -937, -12, -937, 3, 0.3, false)
	run(12, -937, 124, -937, 3, 0.3, false)
	run(-120, -986, -12, -986, 3, 0.3, false)
	gatehouse(parent, -752, rng)
	-- South exit: two leaning pillars and a fallen lintel where the road leaves for the Bamboo Pass.
	local exit = Kit.folder("SouthGate", parent)
	for side = -1, 1, 2 do
		Kit.part(exit, "Pillar", Vector3.new(2.4, 14, 2.4), CFrame.new(side * 11, G + 7, -1114) * CFrame.Angles(0, 0, math.rad(side * 3)), P.Lacquer:Lerp(P.WoodDark, 0.5), WOOD)
		Fx.lantern(exit, CFrame.new(side * 15, G, -1110), false, 20)
	end
	Kit.part(exit, "FallenLintel", Vector3.new(26, 1.6, 2.4), CFrame.new(-19, G + 0.6, -1100) * CFrame.Angles(0, math.rad(84), math.rad(4)), P.WoodDark, WOOD)
end

return Ruins
