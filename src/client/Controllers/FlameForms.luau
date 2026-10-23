--!strict
-- Procedural fire for Blazing Sun Awakening: tension embers, dual-layer flame gauntlets, blazing
-- eye starbursts with trailing jets, the ground fire shockwave and recurring heat rings.
local RunService = game:GetService("RunService")
local Assets = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.PresentationAssets)
local Kit = require(script.Parent.SkillKit)
local Flame = {}

Flame.Core = Color3.fromRGB(251, 252, 29)
Flame.Body = Color3.fromRGB(255, 69, 0)
Flame.Coal = Color3.fromRGB(225, 112, 81)
Flame.Amber = Color3.fromRGB(200, 162, 106)
Flame.Heat = Color3.fromRGB(255, 106, 0)
Flame.Plasma = Color3.fromRGB(255, 245, 157)

local function seq(a: Color3, b: Color3): ColorSequence return ColorSequence.new(a, b) end
local function sizes(a: number, b: number): NumberSequence return NumberSequence.new(a, b) end

-- Subtle heat embers rising off clenched fists during the stance.
function Flame.embers(trove: Kit.Trove, hand: BasePart)
	local a = Kit.attach(trove, hand, Vector3.zero, "SunEmbers")
	Kit.emitter(a, { Texture = Assets.Textures.Ember, Color = seq(Flame.Heat, Flame.Amber), Size = sizes(0.18, 0.04), Rate = 16,
		Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(1, 2.5), Spread = 35, Accel = Vector3.new(0, 5, 0) })
	local light = Kit.light(a, Flame.Heat, 6, 0.8)
	local seed = math.random() * 50
	Kit.add(trove, RunService.Heartbeat:Connect(function()
		light.Brightness = 0.8 + math.noise(seed, os.clock() * 9) * 0.9
	end))
end

-- Core plasma plus flickering outer flame spirals, and a breathing orange light.
function Flame.gauntlet(trove: Kit.Trove, hand: BasePart)
	local a = Kit.attach(trove, hand, Vector3.zero, "SunGauntlet")
	Kit.emitter(a, { Color = seq(Flame.Plasma, Flame.Core), Size = sizes(0.9, 0.2), Rate = 40, Lifetime = NumberRange.new(0.18, 0.3),
		Speed = NumberRange.new(0.5, 1.5), Spread = 180, Accel = Vector3.new(0, 4, 0) })
	Kit.emitter(a, { Color = seq(Flame.Body, Flame.Coal), Size = sizes(1.5, 0.3), Rate = 55, Lifetime = NumberRange.new(0.35, 0.55),
		Speed = NumberRange.new(1, 3), Spread = 180, Accel = Vector3.new(0, 9, 0), Drag = 2, Spin = NumberRange.new(-260, 260),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(0.6, 0.5), NumberSequenceKeypoint.new(1, 1) }) })
	local light = Kit.light(a, Flame.Body, 11, 2)
	local seed = math.random() * 50
	Kit.add(trove, RunService.Heartbeat:Connect(function()
		light.Brightness = 2 + math.noise(seed, os.clock() * 7) * 1.6
	end))
end

local function spikes(parent: Instance, count: number, length: number, color: Color3): Frame
	local holder = Instance.new("Frame")
	holder.Size, holder.AnchorPoint, holder.Position, holder.BackgroundTransparency = UDim2.fromScale(1, 1), Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), 1
	for n = 1, count do
		local spike = Instance.new("Frame")
		spike.AnchorPoint, spike.Position, spike.BackgroundColor3, spike.BorderSizePixel = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), color, 0
		spike.Size, spike.Rotation = UDim2.fromScale(length, 0.04), (n / count) * 180
		local fade = Instance.new("UIGradient")
		fade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) })
		fade.Parent = spike
		spike.Parent = holder
	end
	holder.Parent = parent
	return holder
end

-- Radiating 4-point and 6-point starbursts on both eyes, flame jets streaming back, micro-sparks.
function Flame.eyes(trove: Kit.Trove, head: BasePart)
	local s = head.Size
	local bursts: { Frame } = {}
	for _, side in { -1, 1 } do
		local a = Kit.attach(trove, head, Vector3.new(side * s.X * 0.17, s.Y * 0.1, -s.Z * 0.5), "BlazingEye")
		local gui = Kit.add(trove, Instance.new("BillboardGui"))
		-- Sized to the eye: the gaze shot frames the face from ~2 studs, where a 2.2-stud burst became
		-- flat panels across the whole screen.
		gui.Adornee, gui.Size, gui.LightInfluence, gui.AlwaysOnTop = a, UDim2.fromScale(0.9, 0.9), 0, false
		table.insert(bursts, spikes(gui, 2, 1, Flame.Plasma))
		table.insert(bursts, spikes(gui, 3, 0.6, Flame.Heat))
		gui.Parent = a
		local jet = Kit.emitter(a, { Color = seq(Flame.Core, Flame.Body), Size = sizes(0.35, 0.05), Rate = 45, Lifetime = NumberRange.new(0.2, 0.35),
			Speed = NumberRange.new(5, 8), Spread = 12, Accel = Vector3.new(0, 3, 0) })
		jet.EmissionDirection = Enum.NormalId.Back
		local sparks = Kit.emitter(a, { Texture = Assets.Textures.Ember, Color = seq(Flame.Plasma, Flame.Heat), Size = sizes(0.08, 0.02),
			Rate = 30, Lifetime = NumberRange.new(0.15, 0.4), Speed = NumberRange.new(4, 9), Spread = 70 })
		sparks.EmissionDirection = Enum.NormalId.Back
		Kit.light(a, Flame.Core, 5, 3)
	end
	Kit.add(trove, RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for n, holder in bursts do
			holder.Rotation = t * (if n % 2 == 0 then -140 else 90)
			local pulse = 1 + math.noise(n * 3.1, t * 12) * 0.35
			holder.Size = UDim2.fromScale(pulse, pulse)
		end
	end))
end

-- Expanding ground fire rings and a burst of flying embers.
function Flame.shockwave(trove: Kit.Trove, folder: Instance, floor: CFrame)
	Kit.shockwave(trove, folder, floor, Flame.Core, 18, 0.45, 0.05)
	Kit.shockwave(trove, folder, floor, Flame.Body, 32, 0.8, 0.2)
	Kit.after(trove, 0.1, function() Kit.shockwave(trove, folder, floor, Flame.Coal, 24, 0.9, 0.45) end)
	local anchor = Kit.part(folder, "SunEmberBurst", Flame.Body, Vector3.one * 0.2, floor)
	anchor.Transparency = 1
	local burst = Kit.emitter(anchor, { Texture = Assets.Textures.Ember, Color = seq(Flame.Plasma, Flame.Body), Size = sizes(0.3, 0.05), Rate = 0,
		Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(22, 40), Spread = 75, Accel = Vector3.new(0, -30, 0), Drag = 1.5 })
	burst:Emit(70)
end

-- Recurring heat ring while the stance burns.
function Flame.heat(trove: Kit.Trove, folder: Instance, floor: CFrame)
	Kit.shockwave(trove, folder, floor, Flame.Heat, 14, 0.8, 0.35)
	Kit.after(trove, 0.08, function() Kit.shockwave(trove, folder, floor, Flame.Core, 9, 0.5, 0.55) end)
end

return table.freeze(Flame)
