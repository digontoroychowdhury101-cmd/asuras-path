--!strict
local Tween = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local WorldState = require(script.Parent.WorldStateController)
local Comfort = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.EffectsPreference) :: any
local Effects = {}
local COLORS: { [string]: Color3 } = { ["Lightning+Iron"] = Color3.fromRGB(235, 197, 95), Frost = Color3.fromRGB(115, 220, 255), Thunder = Color3.fromRGB(100, 170, 255),
	Lightning = Color3.fromRGB(220, 205, 90), Void = Color3.fromRGB(138, 65, 215), Iron = Color3.fromRGB(165, 145, 95), Blood = Color3.fromRGB(210, 24, 46) }
local function spark(position: Vector3, color: Color3, size: Vector3, duration: number): Part
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Material, p.Color, p.Size, p.Position, p.Transparency = Enum.Material.Neon, color, size, position, 0.25
	p.Parent = workspace.CurrentCamera
	Debris:AddItem(p, duration)
	return p
end
local function ring(origin: Vector3, radius: number, duration: number, color: Color3)
	for i = 1, 32 do
		local angle = i * math.pi * 2 / 32
		local p = spark(origin, color, Vector3.new(1, 0.4, 1), duration + 0.2)
		p.CFrame *= CFrame.Angles(0, -angle, 0)
		Tween:Create(p, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Position = origin + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius),
			Size = Vector3.new(1, 0.4, radius * math.pi / 16), Transparency = 0.8 }):Play()
	end
end
local function lane(origin: Vector3, aim: Vector3, color: Color3, duration: number)
	local endpoint = aim + (aim - origin) * 2
	local delta = endpoint - origin
	if delta.Magnitude < 1 then return end
	local p = spark((origin + endpoint) / 2, color, Vector3.new(28, 0.4, delta.Magnitude), duration)
	p.CFrame, p.Transparency = CFrame.lookAt(p.Position, endpoint), 0.65
end
function Effects.cue(cue: WorldState.Cue, state: WorldState.WorldState)
	local d = cue.Data
	local entity = state:Get(cue.Source)
	local origin = if type(d.x) == "number" then Vector3.new(d.x, tonumber(d.y) or 0.5, tonumber(d.z) or 0) elseif entity and entity.Root then entity.Root.Position else Vector3.zero
	local color = COLORS[tostring(d.element)] or Color3.fromRGB(220, 35, 52)
	if cue.Kind == "Telegraph" and d.kind then
		local duration = math.max(0.1, (tonumber(d.impact) or cue.Time + 1) - cue.Time)
		if d.kind == "Breath" and type(d.ox) == "number" then lane(Vector3.new(d.ox, 0.4, d.oz), origin, color, duration)
		else ring(origin, math.min(tonumber(d.radius) or 15, 30), duration, color) end
	elseif cue.Kind == "BossHazard" then
		local radius, speed = tonumber(d.radius) or 30, tonumber(d.speed) or 36
		if d.kind == "Breath" then lane(origin, Vector3.new(d.ax, origin.Y, d.az), color, tonumber(d.duration) or 3)
		elseif d.kind == "Gravity" or d.kind == "Ritual" or (d.kind == "Leap" and d.element == "Frost") then
			local center = if d.kind == "Gravity" then Vector3.new(d.ax, 0.4, d.az) else origin
			local p = spark(center, color, Vector3.new(0.4, radius * 2, radius * 2), tonumber(d.duration) or 3)
			p.Shape, p.CFrame, p.Transparency = Enum.PartType.Cylinder, CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2), 0.7
		else
			for i = 0, (tonumber(d.repeats) or 1) - 1 do
				task.delay(i * (tonumber(d.interval) or 1), function() ring(origin, radius, radius / speed, color) end)
			end
		end
	elseif cue.Kind == "BossProjectile" then
		local p = spark(origin, Color3.fromRGB(150, 110, 245), Vector3.new(0.6, 0.6, 4), 0.08)
		p.Transparency = 0.05
	elseif cue.Kind == "BossPhase" or cue.Kind == "BossEnrage" or cue.Kind == "BossTeleport" then
		-- One brief translucent bloom sized to the actor; the phase reads on the body (CostumeKit) and
		-- the perilous ring and warning stay visible through it (it used to fill 35 studs for 1.4 s).
		local span = if entity and entity.Model then math.clamp(entity.Model:GetExtentsSize().Y, 6, 24) else 8
		if cue.Kind == "BossTeleport" then
			color = COLORS.Void -- the bloom marks the server's destination; a shade fades where Wu stood
			if entity and entity.Root and (entity.Root.Position - origin).Magnitude > 3 then
				local shade = spark(entity.Root.Position, color, Vector3.new(2.4, span, 2.4), 0.6)
				shade.Transparency = 0.55
				Tween:Create(shade, TweenInfo.new(0.5), { Transparency = 1, Size = Vector3.new(0.4, span * 1.2, 0.4) }):Play()
			end
		end
		local p = spark(origin, color, Vector3.one * 2, 0.9)
		p.Shape, p.Transparency = Enum.PartType.Ball, 1 - Comfort.flash(0.4) -- reduced flashes: fainter, still marked
		Tween:Create(p, TweenInfo.new(0.8), { Size = Vector3.one * span * 1.6, Transparency = 1 }):Play()
	end
end
return Effects
