--!strict
-- Blazing Sun pieces drawn to the reference: the ember that kindles on the chest, the jagged blazing
-- starbursts that replace the eyes (with sideways flame streaks and falling ember dashes), and the
-- fists' gauntlets of spinning gold crescents, lens-flare sparkles and small sunbursts.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Assets = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.PresentationAssets)
local Kit = require(script.Parent.SkillKit)
local Bb = require(script.Parent.BillboardFx)
local Flame = require(script.Parent.FlameForms)
local Sun = {}

local rgb = Color3.fromRGB
Sun.Burst = { rgb(235, 255, 110), rgb(255, 196, 40), rgb(255, 120, 20), rgb(255, 72, 12) }
Sun.Gold = rgb(255, 196, 70)
local WHITE = Color3.new(1, 1, 1)

local function seq(a: Color3, b: Color3): ColorSequence return ColorSequence.new(a, b) end

-- Where the chest sits relative to the root (front of the torso).
function Sun.chest(trove: Kit.Trove, root: BasePart): Attachment
	return Kit.attach(trove, root, Vector3.new(0, 0.15, -1.3), "SunChest")
end

-- A small ember on the chest that spits sparks; returns its burst board so it can be grown.
function Sun.ember(trove: Kit.Trove, chest: Attachment): BillboardGui
	local board = Bb.starburst(trove, chest, { Sun.Burst[1], Sun.Burst[2], Sun.Burst[3] }, 1.8, 10)
	Kit.emitter(chest, { Texture = Assets.Textures.Ember, Color = seq(Sun.Burst[1], Sun.Burst[3]), Size = NumberSequence.new(0.14, 0.02), Rate = 40,
		Lifetime = NumberRange.new(0.3, 0.7), Speed = NumberRange.new(4, 9), Spread = 70, Accel = Vector3.new(0, -12, 0) })
	Kit.light(chest, Sun.Burst[3], 12, 3)
	return board
end

export type Flare = { Scale: number }

-- A jagged starburst built from Neon spikes that turn to face the camera every frame. Real parts
-- (outside the character) occlude the black silhouette Highlight, which paints over billboards.
local function flare(trove: Kit.Trove, at: Attachment, studs: number, count: number): Flare
	local folder = Kit.folder(trove, "BlazingEyeFlare")
	local spikes: { BasePart } = {}
	for n = 1, count do spikes[n] = Kit.part(folder, "Spike", Sun.Burst[(n % 3) + 2], Vector3.new(0.04, 0.1, 1), CFrame.identity, Enum.PartType.Wedge) end
	local core = Kit.part(folder, "Core", Sun.Burst[1], Vector3.one * 0.3, CFrame.identity, Enum.PartType.Ball)
	table.insert(spikes, core)
	local handle: Flare = { Scale = studs }
	local base = math.random() * math.pi * 2
	Kit.add(trove, RunService.Heartbeat:Connect(function()
		local camera = Workspace.CurrentCamera
		if not camera or not at.Parent then return end
		local c, t = at.WorldPosition, os.clock()
		local face = CFrame.lookAt(c, camera.CFrame.Position)
		local frames: { CFrame } = {}
		for n = 1, count do
			local length = handle.Scale * 0.5 * (0.45 + 0.55 * (0.5 + 0.5 * math.noise(n * 1.7, t * 9)))
			local angle = base + n / count * math.pi * 2 + math.noise(n, t * 4) * 0.25
			local dir = face.RightVector * math.cos(angle) + face.UpVector * math.sin(angle)
			-- A wedge seen side-on is a triangle: its thin X axis faces the camera, its point aims outward.
			spikes[n].Size = Vector3.new(0.04, length * (0.16 + 0.06 * (n % 3)), length)
			frames[n] = CFrame.fromMatrix(c + dir * length / 2, face.LookVector, (-dir):Cross(face.LookVector))
		end
		core.Size = Vector3.one * handle.Scale * 0.14
		frames[count + 1] = CFrame.new(c)
		Workspace:BulkMoveTo(spikes, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end))
	return handle
end

-- Two giant jagged starbursts on the eyes with flame streaks and a rain of ember dashes.
function Sun.eyes(trove: Kit.Trove, head: BasePart, studs: number): { Flare }
	local s = head.Size
	local flares: { Flare } = {}
	for _, side in { -1, 1 } do
		-- Hung a little in front of the face so hair, masks and hat brims never bury the burst.
		local a = Kit.attach(trove, head, Vector3.new(side * s.X * 0.22, s.Y * 0.08, -s.Z * 0.55 - 0.3), "BlazingEye")
		table.insert(flares, flare(trove, a, studs, 12))
		local streak = Kit.emitter(a, { Color = seq(Sun.Burst[2], Sun.Burst[4]), Size = NumberSequence.new(0.5, 0.05), Rate = 30,
			Lifetime = NumberRange.new(0.15, 0.3), Speed = NumberRange.new(8, 14), Spread = 18 })
		streak.EmissionDirection = if side < 0 then Enum.NormalId.Left else Enum.NormalId.Right
		Kit.light(a, Sun.Burst[2], 6, 3)
	end
	local rain = Kit.attach(trove, head, Vector3.new(0, s.Y * 1.5, -s.Z * 0.6), "EmberRain")
	local dashes = Kit.emitter(rain, { Texture = Assets.Textures.Ember, Color = seq(Sun.Burst[2], Sun.Burst[3]), Size = NumberSequence.new(0.12), Rate = 26,
		Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(1, 3), Spread = 180, Accel = Vector3.new(0, -14, 0), Spin = NumberRange.new(0, 0),
		Transparency = NumberSequence.new(0) })
	dashes.Squash = NumberSequence.new(-2.2) -- tall thin dashes, not round sparks
	dashes.Speed = NumberRange.new(4, 9)
	return flares
end

-- Gauntlet on a fist: two counter-spinning gold crescents, a sunburst, flame and recurring sparkles.
function Sun.gauntlet(trove: Kit.Trove, hand: BasePart)
	local a = Kit.attach(trove, hand, Vector3.zero, "SunFist")
	Bb.arc(trove, a, Sun.Gold, 3.4, 0.42, 320)
	Bb.arc(trove, a, Sun.Burst[2], 2.4, 0.3, -420)
	Bb.starburst(trove, a, { Sun.Burst[1], Sun.Burst[3] }, 1.6, 8)
	Flame.gauntlet(trove, hand)
	Kit.emitter(a, { Texture = Assets.Textures.Ember, Color = seq(Sun.Burst[2], Sun.Burst[4]), Size = NumberSequence.new(0.12, 0.02), Rate = 35,
		Lifetime = NumberRange.new(0.4, 0.9), Speed = NumberRange.new(5, 10), Spread = 180, Accel = Vector3.new(0, -8, 0) })
	local function twinkle()
		local holder = Kit.attach(trove, hand, Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 3, "FistSparkle")
		Bb.sparkle(trove, holder, if math.random() < 0.5 then WHITE else Sun.Gold, 2.2, 0.5, (math.random() - 0.5) * 30)
		Kit.after(trove, 0.5, function() holder:Destroy() end)
	end
	Kit.add(trove, task.spawn(function()
		while true do twinkle(); task.wait(0.22 + math.random() * 0.2) end
	end))
end

-- A black ring of thorns (the seal that clamps the chest ember before it bursts).
function Sun.thorns(trove: Kit.Trove, adornee: Instance, studs: number): BillboardGui
	local gui = Bb.board(trove, adornee, studs)
	local ink = Color3.fromRGB(10, 4, 2)
	Bb.circle(gui, ink, 0.62, 0.06, 0, trove)
	for n = 1, 22 do
		local yaw = n / 22 * math.pi * 2
		local f = Bb.frame(gui, ink, UDim2.fromScale(0.07, 0.07), math.deg(yaw) + 45)
		f.Position = UDim2.fromScale(0.5 + math.cos(yaw) * 0.33, 0.5 + math.sin(yaw) * 0.33)
	end
	return gui
end

return table.freeze(Sun)
