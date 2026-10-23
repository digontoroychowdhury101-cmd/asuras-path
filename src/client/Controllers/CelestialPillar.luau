--!strict
-- The Supernova column: a teal shell, a white-hot core and a ForceField sheath that drive down from
-- the sky, twin gold helices climbing the beam, rune rings rising through it, and the pulse flare.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Kit = require(script.Parent.SkillKit)
local Forms = require(script.Parent.CelestialForms)
local Pillar = {}

local WHITE = Color3.new(1, 1, 1)
local HEIGHT = 140
local UP = CFrame.Angles(0, 0, math.pi / 2)

export type Column = { Parts: { BasePart }, Helix: { BasePart }, Ground: Vector3, Width: number, Fading: boolean? }

local function cylinder(folder: Instance, name: string, color: Color3, width: number, transparency: number, top: Vector3): BasePart
	local p = Kit.part(folder, name, color, Vector3.new(1, width, width), CFrame.new(top) * UP, Enum.PartType.Cylinder)
	p.Transparency = transparency
	return p
end

-- Slams the column onto `ground` from the sky in 0.22 s, then keeps the helices and rune rings moving.
function Pillar.erupt(trove: Kit.Trove, folder: Instance, ground: Vector3, width: number): Column
	local top = ground + Vector3.new(0, HEIGHT, 0)
	local sheath = cylinder(folder, "SupernovaSheath", Forms.Cyan, width * 1.35, 0, top)
	sheath.Material = Enum.Material.ForceField
	local shell = cylinder(folder, "SupernovaPillar", Forms.Teal, width, 0.4, top)
	local core = cylinder(folder, "SupernovaCore", WHITE, width * 0.34, 0.05, top)
	local parts = { sheath, shell, core }
	for _, p in parts do
		Kit.tween(trove, p, 0.22, { Size = Vector3.new(HEIGHT, p.Size.Y, p.Size.Z), CFrame = CFrame.new(ground + Vector3.new(0, HEIGHT / 2 - 2.4, 0)) * UP },
			Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	Kit.light(core, Forms.Teal, 60, 8)
	-- Twin helices: 2 x 26 gold/white segments wound up the beam, unwinding as they climb.
	local helix: { BasePart } = {}
	for n = 1, 52 do
		local strand = n % 2
		local p = Kit.part(folder, "Helix", if strand == 0 then Forms.Gold else WHITE, Vector3.new(0.5, 0.5, 3.2), CFrame.new(ground))
		p.Transparency = 1
		helix[n] = p
	end
	local column: Column = { Parts = parts, Helix = helix, Ground = ground, Width = width }
	local clock = 0
	Kit.add(trove, RunService.Heartbeat:Connect(function(dt: number)
		clock += dt
		local frames: { CFrame } = {}
		for n, p in helix do
			local strand, step = n % 2, math.ceil(n / 2)
			local height = (step / 26 * HEIGHT + clock * 38) % HEIGHT
			local angle = height * 0.11 + strand * math.pi + clock * 3
			local r = width * 0.62
			local at = ground + Vector3.new(math.cos(angle) * r, height - 2.4, math.sin(angle) * r)
			local tangent = Vector3.new(-math.sin(angle), 0.35, math.cos(angle))
			frames[n] = CFrame.lookAt(at, at + tangent)
			if not column.Fading then p.Transparency = math.clamp(0.9 - math.min(clock * 3, 1) + height / HEIGHT * 0.6, 0, 1) end
		end
		Workspace:BulkMoveTo(helix, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end))
	return column
end

-- A gold rune ring rising up the column and fading at the top; one is launched every `every` s.
function Pillar.runes(trove: Kit.Trove, folder: Instance, column: Column, every: number)
	local function launch()
		local ring = Kit.ring(folder, "RisingRune", column.Width * 0.75, 0.35, Forms.Gold, 30)
		ring:PivotTo(CFrame.new(column.Ground))
		Kit.add(trove, ring)
		local height = 0
		local link: RBXScriptConnection
		link = RunService.Heartbeat:Connect(function(dt: number)
			height += dt * 45
			if height > HEIGHT then link:Disconnect(); ring:Destroy(); return end
			local s = 1 + math.sin(height * 0.08) * 0.15
			ring:PivotTo(CFrame.new(column.Ground + Vector3.new(0, height, 0)) * CFrame.Angles(0, height * 0.05, 0))
			ring:ScaleTo(s)
		end)
		Kit.add(trove, link)
	end
	launch()
	local thread = task.spawn(function()
		while true do task.wait(every); launch() end
	end)
	Kit.add(trove, thread)
end

-- A pulse: the beam swells and brightens for a beat, then settles.
function Pillar.flare(trove: Kit.Trove, column: Column, strength: number)
	for _, p in column.Parts do
		local base = p.Size
		Kit.tween(trove, p, 0.08, { Size = Vector3.new(base.X, base.Y * (1 + 0.35 * strength), base.Z * (1 + 0.35 * strength)) }, Enum.EasingStyle.Quad)
		Kit.after(trove, 0.1, function() Kit.tween(trove, p, 0.5, { Size = base }, Enum.EasingStyle.Sine) end)
	end
end

-- Final beat: the column blasts wide and dissolves upward.
function Pillar.dissolve(trove: Kit.Trove, column: Column, seconds: number)
	for _, p in column.Parts do
		Kit.tween(trove, p, seconds, { Transparency = 1, Size = Vector3.new(p.Size.X * 1.4, p.Size.Y * 2.2, p.Size.Z * 2.2) }, Enum.EasingStyle.Quart)
	end
	for _, p in column.Helix do Kit.tween(trove, p, seconds * 0.6, { Transparency = 1 }) end
end

return table.freeze(Pillar)
