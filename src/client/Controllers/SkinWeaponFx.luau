--!strict
-- Character VFX on a production skin's own weapon (AsuraBossSkin parts with AsuraRole=Weapon): a
-- colour-keyed blade trail that only draws while the server's committed strike (AsuraStrike) is
-- swinging, plus the look's idle curse (embers and smoke rising off the blade, a low glow) and a
-- flare as each cut lands. Purely cosmetic: the gameplay arc stays WeaponTrails' job. The blade's
-- tip is found from the part's long axis, on the side away from the hand it is bound to.
local Workspace = game:GetService("Workspace")
local Shared = game:GetService("ReplicatedStorage").AsurasPath
local Effects = require(Shared.Shared.EffectsPreference) :: any
local Strike = require(Shared.Simulation.StrikeGeometry)
local Controller = {}
Controller.__index = Controller

type Look = { Edge: Color3, Core: Color3, Ember: Color3, Smoke: Color3, Glow: Color3 }
local LOOKS: { [string]: Look } = {
	CursedSwordsman = { Edge = Color3.fromRGB(255, 70, 52), Core = Color3.fromRGB(90, 0, 12), Ember = Color3.fromRGB(255, 92, 58),
		Smoke = Color3.fromRGB(44, 8, 12), Glow = Color3.fromRGB(255, 40, 30) },
}
local RANGE = 90
local LEAD = 0.1 -- the trail opens this far ahead of the active window, catching the cut's acceleration
local LINGER = 0.08
local EMBERS = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

type Rig = { Trail: Trail, Embers: ParticleEmitter, Smoke: ParticleEmitter, Flame: ParticleEmitter, From: number, Until: number, Seen: string? }

local function blade(part: BasePart): (Vector3, Vector3)
	local size = part.Size
	local axis = if size.X >= size.Y and size.X >= size.Z then Vector3.xAxis elseif size.Y >= size.Z then Vector3.yAxis else Vector3.zAxis
	local half = size:Dot(axis) * 0.5
	local bind = part:FindFirstChild("AsuraBind")
	local hand = if bind and bind:IsA("Attachment") then bind.Position:Dot(axis) else -half
	local toward = if hand > 0 then -1 else 1
	return axis * (toward * half * 0.95), axis * (toward * half * 0.25)
end

local function dress(part: BasePart, look: Look): Rig
	local tipAt, baseAt = blade(part)
	local tip, base, mid = Instance.new("Attachment"), Instance.new("Attachment"), Instance.new("Attachment")
	tip.Name, base.Name, mid.Name = "FxTip", "FxBase", "FxMid"
	tip.Position, base.Position, mid.Position = tipAt, baseAt, (tipAt + baseAt) * 0.5
	tip.Parent, base.Parent, mid.Parent = part, part, part
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = base, tip
	trail.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, look.Edge), ColorSequenceKeypoint.new(0.5, look.Core),
		ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0)) })
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.6, 0.55),
		NumberSequenceKeypoint.new(1, 1) })
	trail.Lifetime, trail.MinLength, trail.LightEmission, trail.FaceCamera = 0.2, 0.05, 0.9, false
	trail.WidthScale = NumberSequence.new(1, 0.2)
	trail.Enabled = false
	trail.Parent = part
	local embers = Instance.new("ParticleEmitter")
	embers.Name, embers.Texture, embers.Color = "CurseEmbers", EMBERS, ColorSequence.new(look.Ember, look.Core)
	embers.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.26), NumberSequenceKeypoint.new(1, 0) })
	embers.Transparency = NumberSequence.new(0.1, 1)
	embers.Lifetime, embers.Speed, embers.SpreadAngle = NumberRange.new(0.5, 1.1), NumberRange.new(0.3, 0.9), Vector2.new(40, 40)
	embers.Acceleration, embers.Drag, embers.LightEmission, embers.Rate = Vector3.new(0, 2.2, 0), 1.5, 1, 16
	embers.Shape, embers.ShapeStyle = Enum.ParticleEmitterShape.Box, Enum.ParticleEmitterShapeStyle.Volume
	embers.Parent = mid
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name, smoke.Texture, smoke.Color = "CurseSmoke", SMOKE, ColorSequence.new(look.Smoke)
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.8) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.55), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime, smoke.Speed, smoke.Rotation = NumberRange.new(0.9, 1.6), NumberRange.new(0.2, 0.5), NumberRange.new(0, 360)
	smoke.RotSpeed, smoke.Acceleration, smoke.Rate, smoke.LightInfluence = NumberRange.new(-40, 40), Vector3.new(0, 1, 0), 7, 0.4
	smoke.Parent = mid
	-- the curse licking along the edge: short-lived flame wisps over the blade's whole volume, riding it
	local flame = Instance.new("ParticleEmitter")
	flame.Name, flame.Texture, flame.LockedToPart = "CurseFlame", SMOKE, true
	flame.Color = ColorSequence.new(look.Edge, look.Core)
	flame.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.08) })
	flame.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	flame.Lifetime, flame.Speed, flame.Rate, flame.LightEmission = NumberRange.new(0.25, 0.5), NumberRange.new(0.1, 0.4), 60, 1
	flame.Acceleration, flame.Rotation = Vector3.new(0, 1.5, 0), NumberRange.new(0, 360)
	flame.Shape, flame.ShapeStyle = Enum.ParticleEmitterShape.Box, Enum.ParticleEmitterShapeStyle.Volume
	flame.Parent = part
	local glow = Instance.new("PointLight")
	glow.Color, glow.Brightness, glow.Range, glow.Shadows = look.Glow, 1.8, 9, false
	glow.Parent = mid
	return { Trail = trail, Embers = embers, Smoke = smoke, Flame = flame, From = 0, Until = 0, Seen = nil }
end

function Controller.new(state: any): any
	return setmetatable({ State = state, Rigs = {} :: { [Instance]: Rig }, Tick = 0 }, Controller)
end

function Controller.Update(self: any, dt: number)
	self.Tick += dt
	if self.Tick < 1 / 30 then
		return
	end
	self.Tick = 0
	local own = self.State:Own()
	local now, reduced = Workspace:GetServerTimeNow(), Effects.reduced()
	for part in self.Rigs do
		if not part.Parent then
			self.Rigs[part] = nil
		end
	end
	for _, e in self.State.Entities do
		local model, root = e.Model, e.Root
		local definition = model and model:GetAttribute("AsuraDefinition")
		local look = if type(definition) == "string" then LOOKS[definition] else nil
		local skin = look and model:FindFirstChild("AsuraBossSkin")
		if not skin or not root or (own and own.Root and (own.Root.Position - root.Position).Magnitude > RANGE) then
			continue
		end
		for _, part in skin:GetChildren() do
			if not part:IsA("BasePart") or part:GetAttribute("AsuraRole") ~= "Weapon" then
				continue
			end
			local rig = self.Rigs[part]
			if not rig then
				rig = dress(part, look :: Look)
				self.Rigs[part] = rig
			end
			local record = model:GetAttribute("AsuraStrike")
			if type(record) == "string" and record ~= rig.Seen then
				rig.Seen = record
				local strike = Strike.decode(record)
				if strike and now < strike.Start + strike.Active + LINGER then
					rig.From, rig.Until = strike.Start - LEAD, strike.Start + strike.Active + LINGER
					if not reduced then
						task.delay(math.max(0, strike.Start + strike.Active * 0.5 - now), function()
							if rig.Embers.Parent then rig.Embers:Emit(14) end
						end)
					end
				end
			end
			local downed = e.Snapshot and e.Snapshot.State == "KO"
			rig.Trail.Enabled = not downed and now >= rig.From and now < rig.Until
			rig.Embers.Enabled = not downed and not reduced
			rig.Smoke.Enabled = not downed and not reduced
			rig.Flame.Enabled = not downed
		end
	end
end

function Controller.Destroy(self: any)
	for part, rig in self.Rigs do
		rig.Trail:Destroy()
		rig.Flame:Destroy()
		for _, child in part:GetChildren() do
			if child:IsA("Attachment") and string.sub(child.Name, 1, 2) == "Fx" then
				child:Destroy()
			end
		end
	end
	table.clear(self.Rigs)
end

return Controller
