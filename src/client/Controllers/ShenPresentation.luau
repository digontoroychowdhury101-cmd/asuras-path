--!strict
-- Grandmaster Shen's authored effects and sound (cosmetic only; damage stays on the server's impact times). One session per actor owns every sound, trail,
-- bead, wave and scheduled event it makes, so a cancel, phase swap, reset, departure or streamed-out model leaves nothing behind: events live in a list this
-- module runs, never in a task.delay, so dropping the list is the whole cancellation. A cancel ends what has not left his hand (windup beads, trails, charge
-- sounds); what has (flying beads, the running wave, short-lived shards) finishes on its own bounded life unless the session is cleared.
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local Tween = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath").Shared
local Data = require(Shared.ShenPresentationData)
local Comfort = require(Shared.EffectsPreference) :: any
local Audio = require(script.Parent.SpatialAudio) :: any
local Presentation = {}

local LOOK = "GrandmasterShen"
type Event = { At: number, Run: () -> () }
type Bead = { Part: BasePart, Slot: number, Target: Vector3?, Free: boolean, Dies: number }
type Wave = { Start: number, Speed: number, Radius: number, Origin: Vector3, Parts: { BasePart }, Cframes: { CFrame }, Layers: number, Segments: number }
type Session = { Model: Model, Phase: number, Events: { Event }, Sounds: { Sound }, Trail: Trail?,
	Beads: { [number]: Bead }, Waves: { Wave }, LastThrust: number, Thrust: number, Moving: boolean }
local sessions: { [Model]: Session } = {}
local beat: RBXScriptConnection? = nil

local function now(): number return workspace:GetServerTimeNow() end

local function tier(): any
	local ok, value = pcall(function() return (UserSettings():GetService("UserGameSettings") :: any).SavedQualityLevel.Value end)
	return (Data.Tiers :: any)[Data.tier(if ok and type(value) == "number" then value else 0, Comfort.reduced())]
end

local function holder(): Instance
	local camera = workspace.CurrentCamera
	local folder = camera:FindFirstChild("ShenFx")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ShenFx"
		folder.Parent = camera
	end
	return folder :: Instance
end

local function point(s: Session, name: string): Instance?
	local skin = s.Model:FindFirstChild("AsuraBossSkin")
	local found = if name ~= "Root" and skin then skin:FindFirstChild(name, true) else nil
	if not found and name ~= "Root" then found = s.Model:FindFirstChild(name, true) end -- BeadHand, ChestCore ride the limb itself on a skinned body
	return found or s.Model:FindFirstChild("HumanoidRootPart")
end

local function worldOf(item: Instance?): Vector3?
	if not item then return nil end
	if item:IsA("Attachment") then return item.WorldPosition end
	return if item:IsA("BasePart") then item.Position else nil
end

local function bit(parent: Instance, position: Vector3, size: Vector3, color: Color3, material: Enum.Material?, transparency: number?): Part
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material, p.Color, p.Size, p.Position, p.Transparency = material or Enum.Material.Neon, color, size, position, transparency or 0.2
	p.Parent = parent
	return p
end

local function fade(p: Part, life: number, goal: { [string]: any })
	goal.Transparency = 1
	Tween:Create(p, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	Debris:AddItem(p, life + 0.05)
end

-- One manifest event: each layer on its onset, the first layer whose id exists (authored original, else the owned stand-in).
local function sound(s: Session, event: string, base: number, pitchScale: number?)
	local layers = (Data.Sfx :: any)[event]
	if not layers then return end
	local density = tier()
	for _, layer in layers do
		if density.Grit == false and layer.Priority < 2 then continue end
		table.insert(s.Events, { At = base + layer.Onset, Run = function()
			local parent = point(s, layer.Attach)
			if not parent then return end
			local key = if Audio.id(layer.Key) ~= "" then layer.Key else layer.StandIn
			local voice = Audio.play(key, parent, layer.Volume, false, layer.Pitch * (pitchScale or 1))
			if voice then
				voice.RollOffMaxDistance = layer.Rolloff
				for i = #s.Sounds, 1, -1 do if not s.Sounds[i].Parent then table.remove(s.Sounds, i) end end
				if layer.Stop == "cancel" then table.insert(s.Sounds, voice) end
			end
		end })
	end
end

local function closeTrail(s: Session)
	if s.Trail then s.Trail:Destroy() end
	s.Trail = nil
end

local function openTrail(s: Session, spec: any)
	closeTrail(s)
	local tip, base = point(s, "BladeTip"), point(s, "BladeBase")
	if not tip or not base or not tip:IsA("Attachment") or not base:IsA("Attachment") then return end -- no skin: the telegraph still warns
	local colors = (Data.Palette :: any)[s.Phase] or Data.Palette[1]
	local t = Instance.new("Trail")
	t.Name, t.Attachment0, t.Attachment1 = "ShenEdge", base, tip
	t.Color = ColorSequence.new(colors.EdgeA, colors.EdgeB)
	t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, spec.Fade), NumberSequenceKeypoint.new(1, 1) })
	t.Lifetime, t.MinLength, t.LightEmission, t.FaceCamera = 0.16, 0.05, Comfort.flash(0.7), false
	t.WidthScale = NumberSequence.new(1, spec.Width)
	t.Parent = tip.Parent
	s.Trail = t
end

local function trailWindow(s: Session, name: string, impact: number)
	local spec = (Data.Trails :: any)[name]
	table.insert(s.Events, { At = impact + spec.Open, Run = function() openTrail(s, spec) end })
	table.insert(s.Events, { At = impact + spec.Close, Run = function() closeTrail(s) end })
end

-- ------------------------------------------------------------------ prayer beads
local function gather(s: Session, impact: number)
	for slot, bead in s.Beads do bead.Part:Destroy(); s.Beads[slot] = nil end
	table.insert(s.Events, { At = impact - 0.95, Run = function()
		local folder, trails = holder(), tier().BeadTrails
		for slot = 1, Data.Limits.Beads do
			local p = bit(folder, Vector3.zero, Vector3.one * 0.42, Data.Wood, Enum.Material.Wood, 0)
			p.Shape = Enum.PartType.Ball
			if trails then
				local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
				a0.Position, a1.Position = Vector3.new(0, 0.14, 0), Vector3.new(0, -0.14, 0)
				a0.Parent, a1.Parent = p, p
				local t = Instance.new("Trail")
				t.Attachment0, t.Attachment1, t.Color, t.Lifetime, t.LightEmission = a0, a1, ColorSequence.new(Data.Jade), 0.14, Comfort.flash(0.5)
				t.Transparency = NumberSequence.new(0.45, 1)
				t.Parent = p
			end
			s.Beads[slot] = { Part = p, Slot = slot, Target = nil, Free = false, Dies = impact + 6 }
		end
	end })
end

local function stepBeads(s: Session, clock: number, dt: number)
	local hand = worldOf(point(s, "BeadHand"))
	local root = s.Model:FindFirstChild("HumanoidRootPart")
	for slot, bead in s.Beads do
		if clock >= bead.Dies then
			bead.Part:Destroy()
			s.Beads[slot] = nil
		elseif bead.Free then
			if bead.Target then bead.Part.Position = bead.Part.Position:Lerp(bead.Target, math.clamp(dt * 18, 0, 1)) end
		elseif hand and root and root:IsA("BasePart") then -- the crescent gathered before the release: seven beads on an arc at the free hand
			local angle = math.rad((slot - 4) * 17 + math.sin(clock * 3 + slot) * 2)
			local at = root.CFrame * CFrame.Angles(0, -angle, 0) * CFrame.new(0, 0, -1.6)
			bead.Part.Position = hand + (at.Position - root.Position)
		end
	end
end

-- ------------------------------------------------------------------ crescent, crown, burst
local function crescent(s: Session, aim: Vector3, radius: number)
	local root = s.Model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return end
	local colors = (Data.Palette :: any)[s.Phase] or Data.Palette[1]
	local flat = Vector3.new(aim.X - root.Position.X, 0, aim.Z - root.Position.Z)
	local forward = if flat.Magnitude > 0.5 then flat.Unit else root.CFrame.LookVector
	local floor = root.Position.Y - s.Model:GetScale() * 3 + 0.5
	local folder, density = holder(), tier()
	for i = 1, 10 do
		local yaw = math.rad((i - 5.5) * 13)
		local direction = CFrame.Angles(0, -yaw, 0):VectorToWorldSpace(forward)
		local start = Vector3.new(root.Position.X, floor, root.Position.Z) + direction * radius * 0.4
		local p = bit(folder, start, Vector3.new(radius * 0.2, 0.14, 0.34), colors.EdgeA, Enum.Material.Neon, 1 - Comfort.flash(0.55))
		p.CFrame = CFrame.lookAt(start, start + direction) * CFrame.Angles(0, math.pi / 2, 0)
		fade(p, 0.26, { Position = Vector3.new(root.Position.X, floor, root.Position.Z) + direction * radius })
		if density.Dust > 0.5 and i % 2 == 0 then
			local d = bit(folder, start, Vector3.new(1.1, 0.5, 1.1), colors.Dust, Enum.Material.SmoothPlastic, 0.55)
			fade(d, 0.5, { Position = start + direction * radius * 0.5 + Vector3.yAxis * 0.9, Size = Vector3.new(3, 1.2, 3) })
		end
	end
end

local function crown(s: Session, center: Vector3)
	local colors, density, folder = (Data.Palette :: any)[s.Phase] or Data.Palette[1], tier(), holder()
	local floor = center - Vector3.yAxis * (s.Model:GetScale() * 3 - 0.3)
	for i = 1, density.Shards do
		local a = i / density.Shards * math.pi * 2
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local p = bit(folder, floor + out * 2.2, Vector3.new(0.5, 2.4, 0.5), colors.EdgeB, Enum.Material.Slate, 0)
		p.CFrame = CFrame.lookAt(p.Position, p.Position + out) * CFrame.Angles(-0.5, 0, 0)
		fade(p, 0.55, { Position = floor + out * 4 + Vector3.yAxis * 1.2 })
	end
	for i = 1, density.Debris do
		local a = i * 2.4
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local d = bit(folder, floor + out, Vector3.one * 0.4, colors.Dust, Enum.Material.Slate, 0)
		fade(d, 0.7, { Position = floor + out * 6 + Vector3.yAxis * 2.5 })
	end
	local ring = bit(folder, floor, Vector3.new(0.2, 3, 3), colors.EdgeA, Enum.Material.Neon, 1 - Comfort.flash(0.5))
	ring.Shape, ring.CFrame = Enum.PartType.Cylinder, CFrame.new(floor) * CFrame.Angles(0, 0, math.pi / 2)
	fade(ring, 0.4, { Size = Vector3.new(0.1, 18, 18) })
end

-- The transformation's localized burst: never a damaging wave (the server's shockwave has its own warning). Cloth shreds and loose beads, bounded and gone in a second.
local function burst(s: Session)
	local center = worldOf(point(s, "ChestCore"))
	if not center then return end
	local density, folder = tier(), holder()
	local qi = bit(folder, center, Vector3.one * 2.4, (Data.Palette :: any)[2].EdgeA, Enum.Material.Neon, 1 - Comfort.flash(0.45))
	qi.Shape = Enum.PartType.Ball
	fade(qi, 0.42, { Size = Vector3.one * 10 })
	local rng = Random.new(19)
	for i = 1, math.min(density.Shreds, Data.Limits.Shreds) do
		local color = Data.Cloth[(i % #Data.Cloth) + 1]
		local out = rng:NextUnitVector()
		local p = bit(folder, center + out * 0.8, Vector3.new(0.9, 0.05, rng:NextNumber(0.5, 1.5)), color, Enum.Material.Fabric, 0)
		p.CFrame = CFrame.lookAt(p.Position, p.Position + out)
		fade(p, Data.Limits.ShredLife, { Position = center + out * rng:NextNumber(5, 9) - Vector3.yAxis * 2, Orientation = p.Orientation + Vector3.new(160, 90, 40) })
	end
	for i = 1, 7 do
		local a = i / 7 * math.pi * 2
		local out = Vector3.new(math.cos(a), 0.2, math.sin(a))
		local b = bit(folder, center + out, Vector3.one * 0.4, Data.Wood, Enum.Material.Wood, 0)
		b.Shape = Enum.PartType.Ball
		fade(b, 0.9, { Position = center + out * 6 - Vector3.yAxis * 2.5 })
	end
end

-- ------------------------------------------------------------------ the blood wave: a sheet whose leading edge is the server's own
local function startWave(s: Session, d: any)
	local density = tier()
	local start = tonumber(d.start) or now()
	local origin = Vector3.new(tonumber(d.x) or 0, tonumber(d.y) or 0.3, tonumber(d.z) or 0)
	local wave: Wave = { Start = start, Speed = tonumber(d.speed) or 38, Radius = tonumber(d.radius) or 90, Origin = origin, Parts = {}, Cframes = {}, Layers = density.WaveLayers, Segments = density.WaveSegments }
	local folder = holder()
	for layer = 1, wave.Layers do
		for _ = 1, wave.Segments do
			local color = if layer == 1 then Color3.fromRGB(232, 40, 38) else Color3.fromRGB(70, 6, 12)
			local p = bit(folder, origin, Vector3.new(1, if layer == 1 then 3.4 else 2, 0.7), color, Enum.Material.Neon, if layer == 1 then 0.08 else 0.35)
			table.insert(wave.Parts, p)
		end
	end
	table.insert(s.Waves, wave)
end

local function stepWaves(s: Session, clock: number)
	for i = #s.Waves, 1, -1 do
		local wave = s.Waves[i]
		local radius = Data.waveRadius(clock, wave.Start, wave.Speed, wave.Radius)
		if radius >= wave.Radius then
			for _, p in wave.Parts do p:Destroy() end
			table.remove(s.Waves, i)
			continue
		end
		table.clear(wave.Cframes)
		for layer = 1, wave.Layers do
			local r = math.max(radius - (layer - 1) * 2.6, 0.5)
			local y = if layer == 1 then 1.7 else 1
			for k = 1, wave.Segments do
				local a = (k - 0.5) / wave.Segments * math.pi * 2
				table.insert(wave.Cframes, CFrame.new(wave.Origin + Vector3.new(math.cos(a) * r, y, math.sin(a) * r)) * CFrame.Angles(0, -a, 0))
			end
		end
		workspace:BulkMoveTo(wave.Parts, wave.Cframes, Enum.BulkMoveMode.FireCFrameChanged)
		local arc = radius * 2 * math.pi / wave.Segments * 1.04
		if #wave.Parts > 0 and math.abs(wave.Parts[1].Size.Z - arc) > 0.8 then
			for j, p in wave.Parts do
				p.Size = Vector3.new(0.9, if j <= wave.Segments then 3.4 else 2, math.max(arc, 0.7))
			end
		end
	end
end

-- ------------------------------------------------------------------ session
local function step(dt: number)
	local clock = now()
	for model, s in sessions do
		if not model.Parent then
			Presentation.drop(model)
			continue
		end
		for i = #s.Events, 1, -1 do
			local event = s.Events[i]
			if clock >= event.At then
				table.remove(s.Events, i)
				event.Run()
			end
		end
		stepBeads(s, clock, dt)
		stepWaves(s, clock)
	end
end

local function ensureBeat()
	if beat or next(sessions) == nil then return end
	beat = RunService.Heartbeat:Connect(step)
end

local function sessionOf(model: Model): Session
	local s = sessions[model]
	if not s then
		local phase = model:GetAttribute("AsuraBossPhase")
		s = { Model = model, Phase = if type(phase) == "number" then phase else 1, Events = {}, Sounds = {}, Trail = nil,
			Beads = {}, Waves = {}, LastThrust = 0, Thrust = 0, Moving = false }
		sessions[model] = s
		ensureBeat()
	end
	return s :: Session
end

-- A cancelling state: everything not yet released stops; what has already left his hand finishes by itself.
local function cancelMove(s: Session)
	table.clear(s.Events)
	closeTrail(s)
	for _, voice in s.Sounds do if voice.Parent then voice:Stop(); voice:Destroy() end end
	table.clear(s.Sounds)
	for slot, bead in s.Beads do
		if not bead.Free then bead.Part:Destroy(); s.Beads[slot] = nil end
	end
	s.Moving = false
end

function Presentation.drop(model: Model)
	local s = sessions[model]
	if not s then return end
	cancelMove(s)
	for _, bead in s.Beads do bead.Part:Destroy() end
	for _, wave in s.Waves do for _, p in wave.Parts do p:Destroy() end end
	sessions[model] = nil
	if next(sessions) == nil then
		if beat then beat:Disconnect(); beat = nil end
		holder():ClearAllChildren() -- the short-lived shards and shreds go with the last session
	end
end

function Presentation.clear()
	for model in sessions do Presentation.drop(model) end
end

function Presentation.sync(model: Model, state: string?)
	if model:GetAttribute("AsuraLookKey") ~= LOOK then return end
	local s = sessions[model]
	if not s then return end
	local phase = model:GetAttribute("AsuraBossPhase")
	if type(phase) == "number" then s.Phase = phase end
	if state and Data.Cancels[state] and (s.Moving or #s.Events > 0) then cancelMove(s) end
end

-- A move's effects. Returns true when this module replaced the generic effect for the cue. `source`: the cue's entity.
function Presentation.cue(cue: any, source: any): boolean
	local model = source and source.Model
	if not model or model:GetAttribute("AsuraLookKey") ~= LOOK then return false end
	local d, kind = cue.Data, cue.Kind
	local s = sessionOf(model)
	local impact = tonumber(d.impact) or now()
	if kind == "Telegraph" then
		s.Moving = true
		local move = d.move
		if move == "FlowingJian" then
			s.Thrust = if impact - s.LastThrust > 1.5 then 1 else s.Thrust + 1
			s.LastThrust = impact
			sound(s, "FlowingJian_Thrust", impact, 1 + (math.min(s.Thrust, 4) - 1) * 0.07) -- the whooshes escalate across the four thrusts
			sound(s, "FlowingJian_Contact", impact)
			trailWindow(s, "FlowingJian", impact)
		elseif move == "PrayerBeads" then
			sound(s, "PrayerBeads_Gather", impact)
			sound(s, "PrayerBeads_Launch", impact)
			gather(s, impact)
		elseif move == "AbbotSweep" then
			sound(s, "AbbotSweep", impact)
			trailWindow(s, "AbbotSweep", impact)
		elseif move == "HesitantMoon" or move == "WheelOfHeaven" or move == "RendingArc" or move == "PhantomDrift" then
			sound(s, "FlowingJian_Thrust", impact)
			sound(s, "FlowingJian_Contact", impact)
			trailWindow(s, "Cut", impact)
			local aim = Vector3.new(tonumber(d.x) or 0, 0, tonumber(d.z) or 0)
			table.insert(s.Events, { At = impact, Run = function() crescent(s, aim, tonumber(d.radius) or 16) end })
		elseif move == "BloodWave" then
			sound(s, "BloodWave_Windup", impact)
			sound(s, "BloodWave_Release", impact)
			trailWindow(s, "BloodWave", impact)
		elseif move == "GuandaoSkyfall" then
			sound(s, "GuandaoSkyfall_Rise", impact)
			sound(s, "GuandaoSkyfall_Land", impact)
			trailWindow(s, "GuandaoSkyfall", impact)
			table.insert(s.Events, { At = impact, Run = function()
				local root = model:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then crown(s, root.Position) end
			end })
		elseif move == "CrimsonEmbrace" then
			sound(s, "CrimsonEmbrace", impact)
			table.insert(s.Events, { At = impact - 0.1, Run = function()
				local hand = worldOf(point(s, "BeadHand"))
				if not hand then return end
				local folder = holder()
				for i = -1, 1 do
					local p = bit(folder, hand + Vector3.new(i * 0.3, 0, 0), Vector3.new(0.09, 1.6, 0.09), Color3.fromRGB(235, 40, 36), Enum.Material.Neon, 1 - Comfort.flash(0.7))
					p.CFrame = p.CFrame * CFrame.Angles(0.4, 0, i * 0.3)
					fade(p, 0.2, {})
				end
			end })
		end
		return false -- the telegraph ring and warning stay generic on every tier
	elseif kind == "BossSwing" then
		sound(s, if s.Phase == 2 then "Melee_P2" else "Melee_P1", impact)
		trailWindow(s, "Melee", impact)
		return false
	elseif kind == "BossHazard" and d.move == "BloodWave" then
		startWave(s, d)
		return true
	elseif kind == "BossProjectile" and d.move == "PrayerBeads" then
		local slot = tonumber(d.index)
		local bead = slot and s.Beads[slot]
		if not bead and slot and slot >= 1 and slot <= Data.Limits.Beads then -- joined late, or the windup was missed: still draws what the server fires
			local p = bit(holder(), Vector3.new(d.x, d.y, d.z), Vector3.one * 0.42, Data.Wood, Enum.Material.Wood, 0)
			p.Shape = Enum.PartType.Ball
			bead = { Part = p, Slot = slot, Target = nil, Free = true, Dies = 0 }
			s.Beads[slot] = bead
		end
		if bead then
			bead.Free, bead.Target = true, Vector3.new(d.x, d.y, d.z)
			bead.Dies = now() + Data.Limits.BeadTtlPad
			s.Moving = false
			if d.state == "hit" then
				sound(s, "PrayerBeads_Impact", now())
				local puff = bit(holder(), bead.Target :: Vector3, Vector3.one * 0.8, Data.Jade, Enum.Material.Neon, 1 - Comfort.flash(0.5))
				fade(puff, 0.2, { Size = Vector3.one * 2 })
				bead.Part:Destroy()
				s.Beads[slot :: number] = nil
			end
		end
		return true
	elseif kind == "BossPhase" then
		local start = tonumber(cue.Time) or now()
		local reveal = tonumber(d.reveal) or 0.9
		cancelMove(s)
		s.Moving = true
		sound(s, "Transition_Falter", start)
		sound(s, "Transition_Inhale", start)
		sound(s, "Transition_Roar", start + (reveal - 0.9))
		table.insert(s.Events, { At = start + reveal, Run = function() burst(s) end })
		return true
	end
	return false
end

-- The next form's meshes and maps load ahead of its reveal (BossSkin.prewarm).
local replicated = game:GetService("ReplicatedStorage")
local function preload(item: Instance)
	task.spawn(function() pcall(function() ContentProvider:PreloadAsync({ item }) end) end)
end
task.spawn(function()
	local folder = replicated:WaitForChild("AsuraSkinPrewarm", math.huge) :: Instance
	for _, item in folder:GetChildren() do preload(item) end
	folder.ChildAdded:Connect(preload)
end)

return Presentation
