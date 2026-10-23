--!strict
-- LocalScript: StarterPlayer/StarterPlayerScripts/TikTokVFX_Client
-- Q = Celestial Supernova, E = Blazing Sun Awakening (keys in TikTokVFX_Config). The server owns
-- cooldowns, timing and damage; this script renders every effect locally from its phase packets.
-- Camera shots, screen grading, the manga frame and levitation run only for the caster; everyone
-- nearby sees the world-space geometry and fire. All geometry is procedural Luau (no meshes).
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage:WaitForChild("TikTokVFX_Config")) :: any
local remote = ReplicatedStorage:WaitForChild(Config.RemoteName) :: RemoteEvent
local player = Players.LocalPlayer
local P = Config.Palette

---------------------------------------------------------------------------------------------------
-- Trove (cleanup) and procedural kit
---------------------------------------------------------------------------------------------------
type Trove = { Items: { any }, Dead: boolean }

local function trove(): Trove
	return { Items = {}, Dead = false }
end

local function dispose(item: any)
	local kind = typeof(item)
	if kind == "Instance" then
		if item:IsA("Tween") then item:Cancel() end
		item:Destroy()
	elseif kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "thread" then
		if item ~= coroutine.running() then pcall(task.cancel, item) end
	elseif kind == "function" then
		item()
	end
end

local function add<T>(t: Trove, item: T): T
	if t.Dead then dispose(item) else table.insert(t.Items, item) end
	return item
end

local function clean(t: Trove)
	t.Dead = true
	local items = t.Items
	t.Items = {}
	for index = #items, 1, -1 do dispose(items[index]) end
end

local function after(t: Trove, seconds: number, callback: () -> ())
	add(t, task.delay(math.max(0, seconds), function()
		if not t.Dead then callback() end
	end))
end

local function folder(t: Trove, name: string): Folder
	local f = Instance.new("Folder")
	f.Name, f.Parent = name, Workspace
	return add(t, f)
end

local function part(parent: Instance, name: string, color: Color3, size: Vector3, cf: CFrame, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name, p.Color, p.Size, p.CFrame = name, color, size, cf
	p.Material, p.Shape = Enum.Material.Neon, shape or Enum.PartType.Block
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.Parent = parent
	return p
end

local function tween(t: Trove, instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local tw = TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	add(t, tw)
	tw:Play()
	return tw
end

-- Flat ground shockwave disc that grows and fades (Quad ease-out).
local function shockwave(t: Trove, parent: Instance, at: CFrame, color: Color3, radius: number, seconds: number, transparency: number?)
	local disc = part(parent, "Shockwave", color, Vector3.new(0.12, 1, 1), at * CFrame.Angles(0, 0, math.pi / 2), Enum.PartType.Cylinder)
	disc.Transparency = transparency or 0.2
	tween(t, disc, seconds, { Size = Vector3.new(0.05, radius * 2, radius * 2), Transparency = 1 })
end

type EmitterSpec = {
	Texture: string?, Color: ColorSequence, Size: NumberSequence, Rate: number, Lifetime: NumberRange,
	Speed: NumberRange, Spread: number?, Accel: Vector3?, Drag: number?, Spin: NumberRange?, Transparency: NumberSequence?,
}

local function emitter(parent: Instance, spec: EmitterSpec): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	local texture = spec.Texture or Config.Textures.Flame
	if texture ~= "" then e.Texture = texture end
	e.Color, e.Size, e.Rate, e.Lifetime, e.Speed = spec.Color, spec.Size, spec.Rate, spec.Lifetime, spec.Speed
	e.SpreadAngle = Vector2.new(spec.Spread or 20, spec.Spread or 20)
	e.Acceleration, e.Drag, e.LightEmission = spec.Accel or Vector3.zero, spec.Drag or 0, 1
	e.RotSpeed, e.Rotation = spec.Spin or NumberRange.new(-90, 90), NumberRange.new(0, 360)
	e.Transparency = spec.Transparency or NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.Parent = parent
	return e
end

local function light(parent: Instance, color: Color3, range: number, brightness: number): PointLight
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Shadows, l.Parent = color, range, brightness, false, parent
	return l
end

local function attach(t: Trove, parent: BasePart, offset: Vector3, name: string): Attachment
	local a = Instance.new("Attachment")
	a.Name, a.Position, a.Parent = name, offset, parent
	return add(t, a)
end

-- R15 hands, falling back to R6 arms.
local function hands(model: Model): { BasePart }
	local found: { BasePart } = {}
	for _, pair in { { "LeftHand", "Left Arm" }, { "RightHand", "Right Arm" } } do
		local p = model:FindFirstChild(pair[1]) or model:FindFirstChild(pair[2])
		if p and p:IsA("BasePart") then table.insert(found, p) end
	end
	return found
end

local function floorBelow(model: Model, from: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType, params.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, { model }
	local hit = Workspace:Raycast(from, Vector3.new(0, -60, 0), params)
	return if hit then hit.Position else from - Vector3.new(0, 3, 0)
end

local function seq(a: Color3, b: Color3): ColorSequence return ColorSequence.new(a, b) end
local function sizes(a: number, b: number): NumberSequence return NumberSequence.new(a, b) end

---------------------------------------------------------------------------------------------------
-- Cinematic camera director: Scriptable takeover with blend in/out and trauma shake
---------------------------------------------------------------------------------------------------
type Frame = { CFrame: CFrame, Fov: number }
type Shot = { Start: number, Duration: number, Frame: (number) -> Frame? }
local cinema = {
	Shot = nil :: Shot?, Last = nil :: Frame?, Weight = 0, Rate = 4, Taken = false, Home = CFrame.identity, HomeFov = 70,
	Trauma = 0, Decay = 1, Power = 2, Seed = math.random() * 100, Applied = CFrame.identity,
}

local function ownRoot(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function look(from: Vector3, at: Vector3, fov: number, dutch: number?): Frame
	return { CFrame = CFrame.lookAt(from, at) * CFrame.Angles(0, 0, math.rad(dutch or 0)), Fov = fov }
end

-- frame(t) returns the camera at t seconds into the shot; nil holds the previous frame.
local function play(frame: (number) -> Frame?, duration: number, blend: number?)
	local camera, root = Workspace.CurrentCamera, ownRoot()
	if not Config.CameraShots or not camera or not root then return end
	if not cinema.Taken then
		-- Remember where the default camera sat relative to the character, to hand back there.
		cinema.Home = root.CFrame:ToObjectSpace(camera.CFrame * cinema.Applied:Inverse())
		cinema.HomeFov, cinema.Taken = camera.FieldOfView, true
		camera.CameraType = Enum.CameraType.Scriptable
	end
	cinema.Shot = { Start = os.clock(), Duration = duration, Frame = frame }
	cinema.Rate = 1 / math.max(0.02, blend or 0.25)
end

local function releaseCamera(blend: number?)
	cinema.Shot = nil
	cinema.Rate = 1 / math.max(0.02, blend or 0.35)
end

-- Trauma 0..1 decaying by `decay` per second; shake strength = trauma ^ power.
local function shake(trauma: number, decay: number?, power: number?)
	cinema.Trauma = math.clamp(math.max(cinema.Trauma, trauma), 0, 1)
	cinema.Decay, cinema.Power = decay or 1, power or 2
end

-- Remove last frame's shake before the default camera reads its own CFrame, so shake never drifts.
RunService:BindToRenderStep("TikTokVFX_Unshake", Enum.RenderPriority.Camera.Value - 1, function()
	local camera = Workspace.CurrentCamera
	if camera and cinema.Applied ~= CFrame.identity then camera.CFrame *= cinema.Applied:Inverse() end
	cinema.Applied = CFrame.identity
end)

RunService:BindToRenderStep("TikTokVFX_Camera", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
	dt = math.min(dt, 0.1)
	local camera = Workspace.CurrentCamera
	if not camera then return end
	if cinema.Taken then
		local shot = cinema.Shot
		if shot and os.clock() - shot.Start >= shot.Duration then
			releaseCamera()
			shot = nil
		end
		cinema.Weight = math.clamp(cinema.Weight + (if shot then dt else -dt) * cinema.Rate, 0, 1)
		if shot then cinema.Last = shot.Frame(os.clock() - shot.Start) or cinema.Last end
		local root = ownRoot()
		local home = if root then root.CFrame * cinema.Home else camera.CFrame
		local w = cinema.Weight * cinema.Weight * (3 - 2 * cinema.Weight)
		local last = cinema.Last
		camera.CFrame = if last then home:Lerp(last.CFrame, w) else home
		camera.FieldOfView = if last then cinema.HomeFov + (last.Fov - cinema.HomeFov) * w else cinema.HomeFov
		if not shot and cinema.Weight <= 0 then
			camera.CameraType = Enum.CameraType.Custom
			cinema.Taken, cinema.Last = false, nil
		end
	end
	if cinema.Trauma > 0 then
		cinema.Trauma = math.max(0, cinema.Trauma - dt * cinema.Decay)
		local s = cinema.Trauma ^ cinema.Power
		local t = os.clock() * Config.Shake.Frequency
		local max = Config.Shake.MaxAngle * s
		local pitch = max * math.noise(cinema.Seed, t)
		local yaw = max * math.noise(cinema.Seed + 1, t)
		local roll = max * math.noise(cinema.Seed + 2, t)
		cinema.Applied = CFrame.Angles(pitch, yaw, roll)
		camera.CFrame *= cinema.Applied
	end
end)

---------------------------------------------------------------------------------------------------
-- Screen layer: colour-grade pulses and the 2D manga impact frame
---------------------------------------------------------------------------------------------------
local NEUTRAL = { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) }

local function grade(t: Trove): ColorCorrectionEffect
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name, cc.Parent = "TikTokVFX_Grade", Lighting
	return add(t, cc)
end

-- Snap to a grade now, hold, then ease back to neutral over `fade` seconds.
local function pulse(t: Trove, cc: ColorCorrectionEffect, goal: { [string]: any }, hold: number, fade: number)
	cc.Brightness = (goal.Brightness or 0) * Config.FlashScale
	cc.Contrast = (goal.Contrast or 0) * Config.FlashScale
	cc.Saturation, cc.TintColor = goal.Saturation or 0, goal.TintColor or NEUTRAL.TintColor
	after(t, hold, function()
		if fade <= 0 then
			for key, value in NEUTRAL do (cc :: any)[key] = value end
		else
			tween(t, cc, fade, NEUTRAL)
		end
	end)
end

local function settle(t: Trove, cc: ColorCorrectionEffect, goal: { [string]: any }, seconds: number)
	local scaled = table.clone(goal)
	if scaled.Brightness then scaled.Brightness *= Config.FlashScale end
	tween(t, cc, seconds, scaled, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
end

local function silhouette(parent: Instance, model: Model, view: CFrame, fov: number, tint: Color3, scale: number, z: number)
	local viewport = Instance.new("ViewportFrame")
	viewport.Size, viewport.AnchorPoint = UDim2.fromScale(scale, scale), Vector2.new(0.5, 0.5)
	viewport.Position, viewport.BackgroundTransparency, viewport.ZIndex = UDim2.fromScale(0.5, 0.5), 1, z
	viewport.Ambient, viewport.LightColor, viewport.ImageColor3 = Color3.new(1, 1, 1), Color3.new(1, 1, 1), tint
	local camera = Instance.new("Camera")
	camera.CFrame, camera.FieldOfView, camera.Parent = view, fov, viewport
	viewport.CurrentCamera = camera
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local was = model.Archivable
	model.Archivable = true
	local clone = model:Clone()
	model.Archivable = was
	if not clone then return end
	for _, d in clone:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("GuiBase") or d:IsA("Constraint") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	clone.Parent = world
	viewport.Parent = parent
end

-- Crimson-black character silhouette on a cadmium sunburst with flickering radial speed lines.
local function manga(t: Trove, model: Model, seconds: number)
	local camera = Workspace.CurrentCamera
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not camera or not playerGui then return end
	local gui = add(t, Instance.new("ScreenGui"))
	gui.Name, gui.IgnoreGuiInset, gui.DisplayOrder, gui.ResetOnSpawn = "TikTokVFX_ImpactFrame", true, 60, false
	local back = Instance.new("Frame")
	back.Size, back.BackgroundColor3, back.BorderSizePixel = UDim2.fromScale(1, 1), Color3.fromRGB(255, 140, 0), 0
	back.Parent = gui
	for n, ring in { { 1.9, P.CoreFlash }, { 1.15, P.Plasma }, { 0.55, P.White } } do
		local disc = Instance.new("Frame")
		disc.AnchorPoint, disc.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
		disc.Size, disc.BackgroundColor3, disc.BorderSizePixel, disc.ZIndex = UDim2.fromScale(ring[1], ring[1]), ring[2], 0, 1 + n
		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.DominantAxis, aspect.Parent = Enum.DominantAxis.Height, disc
		local corner = Instance.new("UICorner")
		corner.CornerRadius, corner.Parent = UDim.new(0.5, 0), disc
		disc.Parent = back
	end
	local size = camera.ViewportSize
	local reach = size.Magnitude * 0.5
	local lines: { Frame } = {}
	for n = 1, 40 do
		local line = Instance.new("Frame")
		line.AnchorPoint, line.BackgroundColor3, line.BorderSizePixel, line.ZIndex = Vector2.new(0.5, 0.5), P.Ink, 0, 6
		local fade = Instance.new("UIGradient")
		fade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 0.6), NumberSequenceKeypoint.new(1, 0) })
		fade.Parent = line
		line.Parent = back
		lines[n] = line
	end
	local function scatter()
		for n, line in lines do
			local angle = (n / #lines) * math.pi * 2 + (math.random() - 0.5) * 0.12
			local length = reach * (0.55 + math.random() * 0.45)
			local mid = size / 2 + Vector2.new(math.cos(angle), math.sin(angle)) * (reach - length / 2)
			line.Size = UDim2.fromOffset(length, 2 + math.random() * 7)
			line.Position, line.Rotation = UDim2.fromOffset(mid.X, mid.Y), math.deg(angle)
		end
	end
	scatter()
	silhouette(back, model, camera.CFrame, camera.FieldOfView, Color3.fromRGB(150, 12, 10), 1.025, 7)
	silhouette(back, model, camera.CFrame, camera.FieldOfView, P.Ink, 1, 8)
	gui.Parent = playerGui
	add(t, task.spawn(function()
		local stop = os.clock() + seconds
		while os.clock() < stop and gui.Parent do
			task.wait(1 / 30)
			scatter()
		end
		gui:Destroy()
	end))
end

---------------------------------------------------------------------------------------------------
-- Skill 1: Celestial Supernova
---------------------------------------------------------------------------------------------------
local S = Config.Supernova
type Ring = { Parts: { BasePart }, Radius: number, Angle: number, Spin: number, Tilt: CFrame }
type Voxel = { Part: BasePart, Base: Vector3, Lift: number, Phase: number, Spin: Vector3 }

local function spinRings(rings: { Ring }, center: Vector3, speed: number, dt: number)
	local parts, frames = {} :: { BasePart }, {} :: { CFrame }
	for _, r in rings do
		r.Angle += r.Spin * speed * dt
		local count = #r.Parts
		local chord = math.max(0.15, 2 * r.Radius * math.sin(math.pi / count) * 1.1)
		for n, p in r.Parts do
			table.insert(parts, p)
			table.insert(frames, CFrame.new(center) * r.Tilt * CFrame.Angles(0, r.Angle + (n / count) * math.pi * 2, 0) * CFrame.new(0, 0, -r.Radius))
			if math.abs(p.Size.X - chord) > 0.05 then p.Size = Vector3.new(chord, p.Size.Y, p.Size.Z) end
		end
	end
	Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
end

local function voxels(parent: Instance, floor: Vector3): { Voxel }
	local list: { Voxel } = {}
	for n = 1, S.Voxels do
		local angle = (n / S.Voxels) * math.pi * 2 + math.random() * 0.4
		local base = floor + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (4 + math.random() * 9)
		local glow = n % 4 == 0
		local p = part(parent, "VoidVoxel", if glow then P.Teal else Color3.fromRGB(46, 52, 60), Vector3.one * (0.5 + math.random()), CFrame.new(base))
		p.Material = if glow then Enum.Material.Neon else Enum.Material.Slate
		table.insert(list, { Part = p, Base = base, Lift = 2 + math.random() * 7, Phase = math.random() * 6,
			Spin = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 3 })
	end
	return list
end

-- spiral = 0 hovers the voxels in reverse gravity; > 0 (seconds since release) draws them up the beam.
local function drift(list: { Voxel }, axis: Vector3, clock: number, spiral: number)
	local parts, frames = {} :: { BasePart }, {} :: { CFrame }
	for _, v in list do
		local at: Vector3
		if spiral <= 0 then
			at = v.Base + Vector3.new(0, math.min(v.Lift, clock * 3.5) + math.sin(clock * 1.7 + v.Phase) * 0.35 + 0.5, 0)
		else
			local offset = v.Base - axis
			local angle = math.atan2(offset.Z, offset.X) + spiral * 2.2
			local r = math.max(2, Vector3.new(offset.X, 0, offset.Z).Magnitude * (1 - math.min(0.7, spiral * 0.4)))
			at = Vector3.new(axis.X + math.cos(angle) * r, v.Base.Y + v.Lift + 0.5 + spiral * spiral * 9, axis.Z + math.sin(angle) * r)
		end
		table.insert(parts, v.Part)
		table.insert(frames, CFrame.new(at) * CFrame.Angles(v.Spin.X * clock, v.Spin.Y * clock, v.Spin.Z * clock))
	end
	Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
end

local function levitate(cast: any, rise: number, seconds: number)
	local root = cast.Root
	if not cast.Own or not root then return end
	local align = cast.Bag.Align
	if not align then
		local anchor = attach(cast.Trove, root, Vector3.zero, "SupernovaLift")
		align = add(cast.Trove, Instance.new("AlignPosition"))
		align.Mode, align.Attachment0 = Enum.PositionAlignmentMode.OneAttachment, anchor
		align.MaxForce, align.MaxVelocity, align.Responsiveness = 1e6, 40, 25
		align.Position, align.Parent = root.Position, root
		cast.Bag.Align, cast.Bag.Start = align, root.Position
	end
	tween(cast.Trove, align, seconds, { Position = cast.Bag.Start + Vector3.new(0, rise, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
end

local Supernova = {}

-- 0 - 36%: levitate into the void. 36 - 84%: planet, orbital rings, voxels. 84 - 100%: implosion.
function Supernova.startup(cast: any)
	local w = cast.Windup
	local fx = folder(cast.Trove, "CelestialSupernova")
	cast.Bag.Folder = fx
	local floor = floorBelow(cast.Character, cast.Root.Position)
	levitate(cast, S.Rise, w * S.OrbAt)
	if cast.Own then
		cast.Bag.Grade = grade(cast.Trove)
		settle(cast.Trove, cast.Bag.Grade, { Brightness = -0.35, Contrast = 0.25, Saturation = -0.55, TintColor = Color3.fromRGB(150, 175, 200) }, w * S.OrbAt)
		local start = math.random() * math.pi * 2
		play(function(t: number)
			local root = cast.Root
			if not root.Parent then return nil end
			local zoom = math.clamp((t - w * S.ImplodeAt) / (w * (1 - S.ImplodeAt)), 0, 1)
			local angle = start + t * 0.4
			local eye = root.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (17 - zoom * 4) + Vector3.new(0, 3 - t * 0.3, 0)
			return look(eye, root.Position + Vector3.new(0, 1, 0), 62 - zoom * 12)
		end, w + 0.2, 0.4)
	end
	cast.Bag.Voxels = voxels(fx, floor)
	local clock = 0
	add(cast.Trove, RunService.Heartbeat:Connect(function(dt: number)
		clock += dt
		cast.Bag.Clock = clock
		local spiral = cast.Bag.Spiral or 0
		drift(cast.Bag.Voxels, cast.Bag.Axis or floor, clock, if spiral > 0 then math.max(1e-3, clock - spiral) else 0)
		local at = cast.Root.Position
		if cast.Bag.Rings then spinRings(cast.Bag.Rings, at, cast.Bag.Speed or 4, dt) end
		if cast.Bag.Orb then cast.Bag.Orb.Position, cast.Bag.Core.Position = at, at end
	end))
	after(cast.Trove, w * S.OrbAt, function()
		local at = cast.Root.Position
		local orb = part(fx, "PlanetOrb", P.Teal, Vector3.one * 0.2, CFrame.new(at), Enum.PartType.Ball)
		orb.Transparency = 0.15
		local core = part(fx, "PlanetCore", P.White, Vector3.one * 0.1, CFrame.new(at), Enum.PartType.Ball)
		light(orb, P.Teal, 22, 3)
		tween(cast.Trove, orb, 0.55, { Size = Vector3.one * S.OrbSize }, Enum.EasingStyle.Back)
		tween(cast.Trove, core, 0.55, { Size = Vector3.one * S.OrbSize * 0.43 }, Enum.EasingStyle.Back)
		cast.Bag.Orb, cast.Bag.Core = orb, core
		local rings: { Ring } = {}
		for _, spec in S.Rings do
			local parts: { BasePart } = {}
			for _ = 1, S.RingSegments do table.insert(parts, part(fx, "OrbitSegment", P[spec.Color], Vector3.new(1, 0.3, 0.3), CFrame.new(at))) end
			local tilt = CFrame.Angles(math.rad(spec.Tilt[1]), math.rad(spec.Tilt[2]), math.rad(spec.Tilt[3]))
			table.insert(rings, { Parts = parts, Radius = spec.Radius, Angle = 0, Spin = spec.Spin, Tilt = tilt })
		end
		cast.Bag.Rings = rings
	end)
	after(cast.Trove, w * S.ImplodeAt, function()
		if not cast.Bag.Rings then return end
		local implode = w * (1 - S.ImplodeAt)
		for _, r in cast.Bag.Rings do
			local from = r.Radius
			add(cast.Trove, RunService.Heartbeat:Connect(function(dt: number) r.Radius = math.max(0.3, r.Radius - dt * from / implode) end))
		end
		cast.Bag.Speed = 14
		tween(cast.Trove, cast.Bag.Orb, implode, { Size = Vector3.one * 0.5 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		tween(cast.Trove, cast.Bag.Core, implode, { Size = Vector3.one * 0.5 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		light(cast.Bag.Core, P.White, 18, 8)
	end)
end

-- Pillar erupts from the sky through the caster; shockwave discs; voxels spiral up the beam.
function Supernova.release(cast: any, _origin: Vector3, floor: Vector3)
	local fx = cast.Bag.Folder or folder(cast.Trove, "CelestialSupernova")
	cast.Bag.Folder = fx
	for _, key in { "Orb", "Core" } do
		if cast.Bag[key] then cast.Bag[key]:Destroy(); cast.Bag[key] = nil end
	end
	for _, r in cast.Bag.Rings or {} do for _, p in r.Parts do p:Destroy() end end
	cast.Bag.Rings = nil
	local up = CFrame.Angles(0, 0, math.pi / 2)
	local top = floor + Vector3.new(0, S.PillarHeight, 0)
	local pillar = {
		part(fx, "SupernovaPillar", P.Teal, Vector3.new(1, S.PillarDiameter, S.PillarDiameter), CFrame.new(top) * up, Enum.PartType.Cylinder),
		part(fx, "SupernovaCore", P.White, Vector3.new(1, S.PillarDiameter / 3, S.PillarDiameter / 3), CFrame.new(top) * up, Enum.PartType.Cylinder),
	}
	pillar[1].Transparency, pillar[2].Transparency = 0.45, 0.1
	for _, p in pillar do
		tween(cast.Trove, p, 0.22, { Size = Vector3.new(S.PillarHeight, p.Size.Y, p.Size.Z), CFrame = CFrame.new(floor + Vector3.new(0, S.PillarHeight / 2, 0)) * up },
			Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	light(pillar[2], P.Teal, 60, 6)
	cast.Bag.Pillar = pillar
	cast.Bag.Axis, cast.Bag.Spiral = floor, (cast.Bag.Clock or 0) + 1e-3
	local ground = CFrame.new(floor + Vector3.new(0, 0.2, 0))
	after(cast.Trove, 0.2, function()
		shockwave(cast.Trove, fx, ground, P.Teal, 42, 0.9)
		after(cast.Trove, 0.12, function() shockwave(cast.Trove, fx, ground, P.Gold, 28, 0.75, 0.35) end)
		if cast.Own then shake(0.55, 1.2, 2) end
	end)
	if cast.Own then
		local side = math.random() * math.pi * 2
		play(function(t: number)
			local eye = floor + Vector3.new(math.cos(side + t * 0.15), 0, math.sin(side + t * 0.15)) * 34 + Vector3.new(0, 4.5, 0)
			return look(eye, floor + Vector3.new(0, 21 + t * 4, 0), 72, -4)
		end, Config.Skills.Supernova.PulseDelay + 0.6, 0.12)
	end
	after(cast.Trove, Config.Skills.Supernova.PulseDelay + 0.8, function() Supernova.whiteout(cast) end) -- if the last pulse is lost
end

-- Whiteout flash, heavy trauma with cubic falloff, the column fades and the caster lands.
function Supernova.whiteout(cast: any)
	if cast.Bag.Done then return end
	cast.Bag.Done = true
	for _, p in cast.Bag.Pillar or {} do
		tween(cast.Trove, p, S.WhiteoutFade, { Transparency = 1, Size = Vector3.new(p.Size.X, p.Size.Y * 1.6, p.Size.Z * 1.6) })
	end
	for _, v in cast.Bag.Voxels or {} do tween(cast.Trove, v.Part, S.WhiteoutFade, { Transparency = 1 }) end
	if cast.Own then
		pulse(cast.Trove, cast.Bag.Grade or grade(cast.Trove), { Brightness = 1, Contrast = 0.4 }, 0.05, S.WhiteoutFade)
		shake(1, 0.9, 3)
		releaseCamera(0.8)
	end
	if cast.Bag.Align then levitate(cast, 0, 1.1) end
	after(cast.Trove, 1.4, function() clean(cast.Trove) end)
end

function Supernova.pulse(cast: any, n: number)
	if n >= Config.Skills.Supernova.Pulses then Supernova.whiteout(cast) end
end

---------------------------------------------------------------------------------------------------
-- Skill 2: Blazing Sun Awakening
---------------------------------------------------------------------------------------------------
local B = Config.BlazingSun

local function embers(t: Trove, hand: BasePart)
	local a = attach(t, hand, Vector3.zero, "SunEmbers")
	emitter(a, { Texture = Config.Textures.Ember, Color = seq(P.Heat, P.Amber), Size = sizes(0.18, 0.04), Rate = 16,
		Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(1, 2.5), Spread = 35, Accel = Vector3.new(0, 5, 0) })
	local l = light(a, P.Heat, 6, 0.8)
	local seed = math.random() * 50
	add(t, RunService.Heartbeat:Connect(function() l.Brightness = 0.8 + math.noise(seed, os.clock() * 9) * 0.9 end))
end

-- Core yellow-white plasma inside flickering orange-red flame spirals.
local function gauntlet(t: Trove, hand: BasePart)
	local a = attach(t, hand, Vector3.zero, "SunGauntlet")
	emitter(a, { Color = seq(P.Plasma, P.CoreFlash), Size = sizes(0.9, 0.2), Rate = 40, Lifetime = NumberRange.new(0.18, 0.3),
		Speed = NumberRange.new(0.5, 1.5), Spread = 180, Accel = Vector3.new(0, 4, 0) })
	emitter(a, { Color = seq(P.Flame, P.Coal), Size = sizes(1.5, 0.3), Rate = 55, Lifetime = NumberRange.new(0.35, 0.55),
		Speed = NumberRange.new(1, 3), Spread = 180, Accel = Vector3.new(0, 9, 0), Drag = 2, Spin = NumberRange.new(-260, 260),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(0.6, 0.5), NumberSequenceKeypoint.new(1, 1) }) })
	local l = light(a, P.Flame, 11, 2)
	local seed = math.random() * 50
	add(t, RunService.Heartbeat:Connect(function() l.Brightness = 2 + math.noise(seed, os.clock() * 7) * 1.6 end))
end

local function spikes(parent: Instance, count: number, length: number, color: Color3): Frame
	local holder = Instance.new("Frame")
	holder.Size, holder.AnchorPoint, holder.Position, holder.BackgroundTransparency = UDim2.fromScale(1, 1), Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), 1
	for n = 1, count do
		local spike = Instance.new("Frame")
		spike.AnchorPoint, spike.Position, spike.BackgroundColor3, spike.BorderSizePixel = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), color, 0
		spike.Size, spike.Rotation = UDim2.fromScale(length, 0.07), (n / count) * 180
		local fade = Instance.new("UIGradient")
		fade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) })
		fade.Parent = spike
		spike.Parent = holder
	end
	holder.Parent = parent
	return holder
end

-- 4-point and 6-point starbursts on both eyes with flame jets streaming back and micro-sparks.
local function eyes(t: Trove, head: BasePart)
	local s = head.Size
	local bursts: { Frame } = {}
	for _, side in { -1, 1 } do
		local a = attach(t, head, Vector3.new(side * s.X * 0.17, s.Y * 0.1, -s.Z * 0.5), "BlazingEye")
		local gui = add(t, Instance.new("BillboardGui"))
		gui.Adornee, gui.Size, gui.LightInfluence, gui.AlwaysOnTop = a, UDim2.fromScale(2.2, 2.2), 0, false
		table.insert(bursts, spikes(gui, 2, 1, P.Plasma))
		table.insert(bursts, spikes(gui, 3, 0.6, P.Heat))
		gui.Parent = a
		local jet = emitter(a, { Color = seq(P.CoreFlash, P.Flame), Size = sizes(0.35, 0.05), Rate = 45, Lifetime = NumberRange.new(0.2, 0.35),
			Speed = NumberRange.new(5, 8), Spread = 12, Accel = Vector3.new(0, 3, 0) })
		jet.EmissionDirection = Enum.NormalId.Back
		local sparks = emitter(a, { Texture = Config.Textures.Ember, Color = seq(P.Plasma, P.Heat), Size = sizes(0.08, 0.02), Rate = 30,
			Lifetime = NumberRange.new(0.15, 0.4), Speed = NumberRange.new(4, 9), Spread = 70 })
		sparks.EmissionDirection = Enum.NormalId.Back
		light(a, P.CoreFlash, 5, 3)
	end
	add(t, RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for n, holder in bursts do
			holder.Rotation = now * (if n % 2 == 0 then -140 else 90)
			local scale = 1 + math.noise(n * 3.1, now * 12) * 0.35
			holder.Size = UDim2.fromScale(scale, scale)
		end
	end))
end

local function fireShockwave(t: Trove, fx: Instance, floor: CFrame)
	shockwave(t, fx, floor, P.CoreFlash, 18, 0.45, 0.05)
	shockwave(t, fx, floor, P.Flame, 32, 0.8, 0.2)
	after(t, 0.1, function() shockwave(t, fx, floor, P.Coal, 24, 0.9, 0.45) end)
	local anchor = part(fx, "SunEmberBurst", P.Flame, Vector3.one * 0.2, floor)
	anchor.Transparency = 1
	emitter(anchor, { Texture = Config.Textures.Ember, Color = seq(P.Plasma, P.Flame), Size = sizes(0.3, 0.05), Rate = 0,
		Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(22, 40), Spread = 75, Accel = Vector3.new(0, -30, 0), Drag = 1.5 }):Emit(70)
end

local BlazingSun = {}

-- Low over-the-shoulder Dutch angle, trembling fists, heat embers rising off the hands.
function BlazingSun.startup(cast: any)
	local w = cast.Windup
	local tension = trove()
	cast.Bag.Tension = tension
	add(cast.Trove, function() clean(tension) end)
	for _, hand in hands(cast.Character) do embers(tension, hand) end
	if not cast.Own then return end
	cast.Bag.Grade = grade(cast.Trove)
	settle(cast.Trove, cast.Bag.Grade, { Brightness = -0.15, Contrast = 0.35, Saturation = -0.25, TintColor = Color3.fromRGB(255, 225, 200) }, w * 0.6)
	play(function(t: number)
		local root = cast.Root
		if not root.Parent then return nil end
		local cf = root.CFrame
		local eye = cf:PointToWorldSpace(Vector3.new(2.4, -1.5, 7.2 - math.min(1, t / w) * 1.6))
		return look(eye, cf:PointToWorldSpace(Vector3.new(0, 1.2, -6)), B.StanceFov, B.StanceDutch)
	end, w + B.EyeAt, 0.3)
	for n = 1, math.max(1, math.floor(w / 0.25)) do
		after(tension, n * 0.25, function() shake(0.12 + 0.2 * (n * 0.25 / w), 1.5, 2) end)
	end
end

-- Blackout -> solarized burst -> manga frame -> fire shockwave -> blazing eyes -> gauntlets.
function BlazingSun.release(cast: any, origin: Vector3, floor: Vector3)
	if cast.Bag.Tension then clean(cast.Bag.Tension) end
	local fx = folder(cast.Trove, "BlazingSunAwakening")
	cast.Bag.Folder, cast.Bag.Floor = fx, floor
	local model = cast.Character
	local ground = CFrame.new(floor + Vector3.new(0, 0.2, 0))
	if cast.Own then
		local cc = cast.Bag.Grade or grade(cast.Trove)
		cast.Bag.Grade = cc
		pulse(cast.Trove, cc, { Brightness = -1, Contrast = 0.5 }, 0.035, 0) -- A: blackout cut (2 frames)
		after(cast.Trove, 0.04, function() -- B: golden-yellow burst (1 frame)
			pulse(cast.Trove, cc, { Brightness = 0.8, Contrast = 0.6, TintColor = P.CoreFlash }, 0.02, 0.18)
		end)
		after(cast.Trove, 0.06, function() -- C: 2D manga impact frame (8 frames)
			manga(cast.Trove, model, 0.15)
			shake(0.8, 1.3, 2)
		end)
	end
	after(cast.Trove, if cast.Own then 0.21 else 0, function() fireShockwave(cast.Trove, fx, ground) end) -- D
	local head = model:FindFirstChild("Head")
	after(cast.Trove, B.EyeAt, function()
		if head and head:IsA("BasePart") then
			local flare = trove()
			add(cast.Trove, function() clean(flare) end)
			eyes(flare, head)
			after(cast.Trove, B.EyeShot + 0.4, function() clean(flare) end)
			if cast.Own and cast.Bag.Grade then
				settle(cast.Trove, cast.Bag.Grade, { Brightness = -0.3, Contrast = 0.55, Saturation = -0.4, TintColor = Color3.fromRGB(255, 205, 180) }, 0.08)
				play(function(t: number)
					if not head.Parent then return nil end
					local cf = head.CFrame
					local push = math.min(t, 1)
					return look(cf.Position + cf.LookVector * (2.6 - push * 0.6) + cf.UpVector * 0.1, cf.Position + cf.UpVector * 0.12, 30 - push * 6, -3)
				end, B.EyeShot, 0.05)
				after(cast.Trove, B.EyeShot, function()
					settle(cast.Trove, cast.Bag.Grade, NEUTRAL, 0.5)
					releaseCamera(0.5)
				end)
			end
		end
		for _, hand in hands(model) do gauntlet(cast.Trove, hand) end
	end)
	after(cast.Trove, B.Gauntlets, function() clean(cast.Trove) end)
end

-- The first pulse is the shockwave itself; later pulses ring heat around the stance.
function BlazingSun.pulse(cast: any, n: number)
	if n <= 1 or not cast.Bag.Folder then return end
	local ground = CFrame.new(cast.Bag.Floor + Vector3.new(0, 0.2, 0))
	shockwave(cast.Trove, cast.Bag.Folder, ground, P.Heat, 14, 0.8, 0.35)
	after(cast.Trove, 0.08, function() shockwave(cast.Trove, cast.Bag.Folder, ground, P.CoreFlash, 9, 0.5, 0.55) end)
end

---------------------------------------------------------------------------------------------------
-- Network routing and input
---------------------------------------------------------------------------------------------------
local SHOWS: { [string]: any } = { Supernova = Supernova, BlazingSun = BlazingSun }
local casts: { [Model]: any } = {}
local readyAt: { [string]: number } = {}
local busyUntil = 0

local function stop(character: Model)
	local cast = casts[character]
	if not cast then return end
	casts[character] = nil
	if cast.Own then releaseCamera(0.3) end
	clean(cast.Trove)
end

local function begin(character: Model, id: number, windup: number): any?
	stop(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return nil end
	local cast = { Trove = trove(), Character = character, Root = root, Own = character == player.Character, Id = id,
		Windup = math.max(0.3, windup), Bag = {} }
	casts[character] = cast
	add(cast.Trove, function() if casts[character] == cast then casts[character] = nil end end)
	add(cast.Trove, character.AncestryChanged:Connect(function() if not character.Parent then stop(character) end end))
	return cast
end

remote.OnClientEvent:Connect(function(packet: any)
	if type(packet) ~= "table" then return end
	if packet.kind == "Denied" then
		readyAt[packet.skill] = os.clock() + (tonumber(packet.remaining) or 0)
		busyUntil = 0
		return
	end
	local show = SHOWS[packet.skill]
	local character = packet.character
	if not show or typeof(character) ~= "Instance" or not character:IsA("Model") or typeof(packet.position) ~= "Vector3" then return end
	local mine = ownRoot()
	if mine and (mine.Position - packet.position).Magnitude > Config.ReplicateRange then return end
	local cast = casts[character]
	local current = cast ~= nil and cast.Id == packet.id
	if packet.kind == "Interrupt" then
		if current then stop(character) end
		if character == player.Character then busyUntil = 0 end
	elseif packet.kind == "Startup" then
		local lag = math.max(0, Workspace:GetServerTimeNow() - (tonumber(packet.t) or 0))
		cast = begin(character, packet.id, (tonumber(packet.windup) or 1) - math.min(lag, 0.5))
		if cast then show.startup(cast) end
	elseif packet.kind == "Release" and typeof(packet.ground) == "Vector3" then
		if not current then cast = begin(character, packet.id, 0.3) end
		if cast then show.release(cast, packet.position, packet.ground) end
	elseif packet.kind == "Pulse" and current then
		show.pulse(cast, tonumber(packet.n) or 1)
	end
end)

-- Client-side debounce mirrors the server cooldown so held keys never spam the remote.
UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed or UserInputService:GetFocusedTextBox() then return end
	for id, skill in Config.Skills do
		if input.KeyCode == skill.Key then
			local now = os.clock()
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if now < busyUntil or now < (readyAt[id] or 0) or not humanoid or humanoid.Health <= 0 then return end
			busyUntil = now + skill.Windup + skill.Lock
			readyAt[id] = now + skill.Cooldown
			remote:FireServer({ skill = id })
			return
		end
	end
end)
