--!strict
-- The Blazing Sun blast as the reference shows it: the camera is inside the explosion. Glowing flame
-- puffs and spark streaks boil up a few studs in front of the lens, flame particles roar through,
-- and a blur pass plus a hot solarized grade soften it into the smeared, blown-out look of the clip.
-- Heat starts white-hot and cools to orange and crimson; the storm thins and pales as it burns out.
-- Caster only; reduced flashes keeps the fire but drops the blow-out.
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Assets = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.PresentationAssets)
local Effects = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.EffectsPreference) :: any
local Kit = require(script.Parent.SkillKit)
local Storm = {}

local rgb = Color3.fromRGB
local HOT = { rgb(255, 252, 225), rgb(255, 240, 120), rgb(255, 214, 60) }
local BODY = { rgb(255, 160, 40), rgb(250, 115, 25), rgb(225, 70, 20), rgb(160, 30, 10), rgb(60, 12, 4) }

type Puff = { Part: BasePart, X: number, Y: number, Depth: number, Speed: number, Size: number }

local function pick(list: { Color3 }): Color3 return list[math.random(1, #list)] end

local function respawn(p: Puff, heat: number, bottom: boolean)
	p.X, p.Y = (math.random() - 0.5) * 2.2, if bottom then -1.3 - math.random() * 0.4 else (math.random() - 0.5) * 2.4
	p.Depth, p.Speed, p.Size = 4 + math.random() * 4, 1.2 + math.random() * 2.2, 1.8 + math.random() * 3.8
	p.Part.Color = if math.random() < 0.15 + heat * 0.7 then pick(HOT) else pick(BODY)
end

-- `seconds` of storm around `camera`. Returns nothing; everything leaves with `trove`.
function Storm.engulf(trove: Kit.Trove, seconds: number)
	local camera = Workspace.CurrentCamera
	if not camera then return end
	local folder = Kit.folder(trove, "BlazingSunStorm")
	local puffs: { Puff } = {}
	for n = 1, 34 do
		local part = Kit.part(folder, "FlamePuff", HOT[1], Vector3.one, CFrame.identity, Enum.PartType.Ball)
		local p: Puff = { Part = part, X = 0, Y = 0, Depth = 5, Speed = 1, Size = 1 }
		respawn(p, 1, false)
		puffs[n] = p
	end
	local sparks: { BasePart } = {}
	for n = 1, 18 do sparks[n] = Kit.part(folder, "SparkStreak", if n % 3 == 0 then HOT[1] else HOT[2], Vector3.new(0.05, 0.05, 2), CFrame.identity) end
	-- Most of the storm is soft flame-texture particles pouring up through a sheet just past the lens,
	-- over dark crimson smoke that gives the fire its holes and depth (the neon puffs only add heat).
	local roar = Kit.part(folder, "StormSheet", HOT[2], Vector3.new(18, 12, 3), CFrame.identity)
	roar.Transparency = 1
	local flames = Kit.emitter(roar, { Texture = Assets.Textures.Flame, Color = ColorSequence.new(HOT[1], HOT[3]), Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(0.4, 7), NumberSequenceKeypoint.new(1, 4) }), Rate = 260,
		Lifetime = NumberRange.new(0.35, 0.7), Speed = NumberRange.new(5, 11), Spread = 25, Accel = Vector3.new(0, 14, 0), Light = 1,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.2, 0.05), NumberSequenceKeypoint.new(1, 1) }) })
	flames.Shape, flames.EmissionDirection = Enum.ParticleEmitterShape.Box, Enum.NormalId.Top
	local smoke = Kit.emitter(roar, { Texture = Assets.Textures.Smoke, Color = ColorSequence.new(rgb(150, 34, 10), rgb(40, 8, 2)), Size = NumberSequence.new(4, 9), Rate = 30,
		Lifetime = NumberRange.new(0.6, 1.1), Speed = NumberRange.new(3, 6), Spread = 30, Accel = Vector3.new(0, 6, 0), Light = 0,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.25), NumberSequenceKeypoint.new(1, 1) }) })
	smoke.Shape, smoke.EmissionDirection = Enum.ParticleEmitterShape.Box, Enum.NormalId.Top
	local tint = 0
	local blur = Kit.add(trove, Instance.new("BlurEffect"))
	blur.Name, blur.Size, blur.Parent = "AsuraSkillStormBlur", 9, Lighting
	local grade = Kit.add(trove, Instance.new("ColorCorrectionEffect"))
	grade.Name, grade.Parent = "AsuraSkillStormGrade", Lighting
	local blowout = if Effects.reducedFlashes() then 0.15 else 0.45
	local start = os.clock()
	local name = "AsuraSkillStorm" .. math.random(1, 1e6)
	Kit.add(trove, function() RunService:UnbindFromRenderStep(name) end)
	-- After the cinema director (Camera + 5) so the storm sits on this frame's camera, never a frame late.
	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 6, function(dt: number)
		local t = os.clock() - start
		local heat = math.clamp(1 - t / (seconds * 0.55), 0, 1)
		local fade = math.clamp((t - seconds * 0.6) / (seconds * 0.4), 0, 1)
		local view = camera.CFrame
		local parts: { BasePart } = {}
		local frames: { CFrame } = {}
		for _, p in puffs do
			p.Y += p.Speed * dt
			if p.Y > 1.4 then respawn(p, heat, true) end
			local wobble = math.sin(t * 6 + p.Depth * 3) * 0.08
			local scale = p.Depth * math.tan(math.rad(camera.FieldOfView / 2))
			local size = p.Size * (0.75 + 0.25 * math.sin(t * 9 + p.X * 5))
			p.Part.Size = Vector3.new(size, size * 1.35, size * 0.6)
			p.Part.Transparency = 0.2 + fade * 0.75
			table.insert(parts, p.Part)
			table.insert(frames, view * CFrame.new((p.X + wobble) * scale * 1.7, p.Y * scale, -p.Depth))
		end
		for n, s in sparks do
			local seed = n * 13.7 + math.floor(t * 12 + n) * 0.37
			local x, y = (math.noise(seed, 1) * 2) * 3, (math.noise(seed, 2) * 2) * 2
			table.insert(parts, s)
			table.insert(frames, view * CFrame.new(x, y, -3 - (n % 4)) * CFrame.Angles(math.rad(90 + math.noise(seed, 3) * 50), 0, math.rad(math.noise(seed, 4) * 40)))
			s.Transparency = fade
		end
		table.insert(parts, roar)
		table.insert(frames, view * CFrame.new(0, -3, -6))
		tint += dt
		if tint > 0.1 then -- the particles cool with the heat and thin as the storm burns out
			tint = 0
			flames.Color = if heat > 0.5 then ColorSequence.new(HOT[1], HOT[3]) else ColorSequence.new(HOT[3], BODY[3])
			flames.Rate, smoke.Rate = 260 * (1 - fade), 30 * (1 - fade) + 10 * (1 - heat)
		end
		Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		blur.Size = 9 * (1 - fade * 0.7)
		grade.Brightness = blowout * heat
		grade.Contrast = 0.35 + 0.2 * heat
		grade.Saturation = 0.35 - fade * 0.6
		grade.TintColor = Color3.new(1, 0.9 + 0.08 * heat, 0.72 + 0.2 * heat)
	end)
	Kit.after(trove, seconds, function()
		RunService:UnbindFromRenderStep(name)
		folder:Destroy()
		blur:Destroy()
		grade:Destroy()
	end)
end

return table.freeze(Storm)
