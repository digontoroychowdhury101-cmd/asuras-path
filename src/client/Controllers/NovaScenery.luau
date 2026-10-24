--!strict
-- Celestial Supernova scenery around the planet: a vortex of translucent teal smoke ribbons whipping
-- round the caster, floating black rocks and glowing cubes, gold sparkles, the hollow gold stars by
-- the planet and the gold flame crescents that tear across it before the detonation.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Assets = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.PresentationAssets)
local Kit = require(script.Parent.SkillKit)
local Bb = require(script.Parent.BillboardFx)
local Shapes = require(script.Parent.BillboardShapes)
local Planet = require(script.Parent.PlanetForms)
local Scenery = {}

local rgb = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)

-- Curved smoke ribbons orbiting `center()`; returns a setter for their radius (to widen the storm).
function Scenery.vortex(trove: Kit.Trove, folder: Instance, center: () -> Vector3, count: number): (number) -> ()
	local hub = Kit.part(folder, "VortexHub", WHITE, Vector3.one * 0.1, CFrame.new(center()))
	hub.Transparency = 1
	local radius = 6
	local ribbons = {}
	for n = 1, count do
		local a0, a1 = Kit.attach(trove, hub, Vector3.zero, "RibbonA"), Kit.attach(trove, hub, Vector3.zero, "RibbonB")
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1, beam.Segments, beam.FaceCamera = a0, a1, 24, true
		beam.Texture, beam.TextureSpeed, beam.TextureLength = Assets.Textures.Smoke, 0.6, 6
		beam.Color = ColorSequence.new(if n % 3 == 0 then rgb(200, 255, 255) else rgb(70, 205, 215))
		beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.45), NumberSequenceKeypoint.new(0.7, 0.5), NumberSequenceKeypoint.new(1, 1) })
		beam.LightEmission, beam.LightInfluence, beam.Width0, beam.Width1 = 1, 0, 3 + math.random() * 4, 4 + math.random() * 6
		beam.Parent = hub
		ribbons[n] = { A = a0, B = a1, Beam = beam, Phase = math.random() * 6, Tilt = (math.random() - 0.5) * 1.6, Speed = 1.6 + math.random() * 1.8 }
	end
	-- A soft teal cloud boiling round the caster under the ribbons.
	Kit.emitter(hub, { Texture = Assets.Textures.Smoke, Color = ColorSequence.new(rgb(90, 220, 230), rgb(20, 90, 110)), Size = NumberSequence.new(5, 12),
		Rate = 7, Lifetime = NumberRange.new(2, 3), Speed = NumberRange.new(1, 3), Spread = 180, Light = 0.4, Spin = NumberRange.new(-40, 40),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.75), NumberSequenceKeypoint.new(1, 1) }) })
	local clock = 0
	Kit.add(trove, RunService.Heartbeat:Connect(function(dt: number)
		clock += dt
		hub.Position = center()
		for _, r in ribbons do
			local a = r.Phase + clock * r.Speed
			local rr = radius * (0.7 + 0.3 * math.sin(clock + r.Phase))
			local function at(off: number): Vector3
				local yaw = a + off
				return Vector3.new(math.cos(yaw) * rr, math.sin(yaw * 0.5 + r.Tilt) * rr * 0.35 + r.Tilt * 2, math.sin(yaw) * rr)
			end
			r.A.Position, r.B.Position = at(0), at(1.9)
			r.Beam.CurveSize0, r.Beam.CurveSize1 = rr * 0.9, -rr * 0.9
		end
	end))
	return function(r: number) radius = r end
end

-- Dark rocks (and a few glowing cubes) hanging in the void around `center`, tumbling slowly.
function Scenery.rocks(trove: Kit.Trove, folder: Instance, center: Vector3, count: number, spread: number)
	local parts: { BasePart } = {}
	local spins: { CFrame } = {}
	for n = 1, count do
		local cube = n % 5 == 0
		local size = if cube then Vector3.one * (0.5 + math.random() * 0.6) else Vector3.new(1 + math.random() * 2.5, 0.8 + math.random() * 2, 1 + math.random() * 2)
		local offset = Vector3.new(math.random() - 0.5, (math.random() - 0.5) * 0.6, math.random() - 0.5) * spread
		local p = Kit.part(folder, if cube then "GlowCube" else "VoidRock", if cube then Planet.Cyan else rgb(14, 18, 22), size, CFrame.new(center + offset))
		p.Material = if cube then Enum.Material.Neon else Enum.Material.Slate
		parts[n], spins[n] = p, CFrame.Angles(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
	end
	Kit.add(trove, RunService.Heartbeat:Connect(function(dt: number)
		local frames: { CFrame } = {}
		for n, p in parts do frames[n] = p.CFrame * spins[n]:Lerp(CFrame.identity, 1 - dt) + Vector3.new(0, dt * 0.6, 0) end
		Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end))
end

-- `count` gold sparkles twinkling in one by one around `at`.
function Scenery.sparkles(trove: Kit.Trove, folder: Instance, at: Vector3, count: number, spread: number, size: number, life: number)
	for n = 1, count do
		Kit.after(trove, (n - 1) * 0.12, function()
			local p = Bb.anchor(folder, at + Vector3.new(math.random() - 0.5, math.random() - 0.3, math.random() - 0.5) * spread)
			Bb.sparkle(trove, p, Planet.Gold, size * (0.6 + math.random() * 0.8), life, (math.random() - 0.5) * 20)
		end)
	end
end

-- Hollow gold stars hanging off the planet's upper shoulder on this viewer's screen.
function Scenery.stars(trove: Kit.Trove, folder: Instance, at: Vector3, radius: number, seconds: number)
	local camera = Workspace.CurrentCamera
	if not camera then return end
	local right, up = camera.CFrame.RightVector, camera.CFrame.UpVector
	for n, spot in { { -1.15, 0.7, 0.62 }, { -0.6, 1.15, 0.48 }, { 0.15, 1.3, 0.34 } } do
		Kit.after(trove, (n - 1) * 0.12, function()
			local hold = Bb.anchor(folder, at + right * radius * spot[1] + up * radius * spot[2])
			Shapes.star(trove, hold, rgb(215, 160, 70), radius * spot[3], seconds)
		end)
	end
end

-- Gold flame crescents on this viewer's side of the planet, so they tear across its face; returns
-- their anchors so the detonation can burn them out.
function Scenery.crescents(trove: Kit.Trove, folder: Instance, at: Vector3, radius: number): { BasePart }
	local camera = Workspace.CurrentCamera
	local toward = if camera then (camera.CFrame.Position - at).Unit else Vector3.zAxis
	local anchors: { BasePart } = {}
	for n = 1, 6 do
		local p = Bb.anchor(folder, at + toward * radius * 1.25 + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * radius * 1.3)
		table.insert(anchors, p)
		Bb.arc(trove, p, Planet.Gold, radius * (1.3 + math.random() * 0.9), 0.3 + math.random() * 0.2, (if n % 2 == 0 then 1 else -1) * (160 + math.random() * 120), 2.4)
	end
	return anchors
end

return table.freeze(Scenery)
