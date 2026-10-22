--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/EnemyDissolve
-- Authored enemy death (batch 09). When the server pins a fallen enemy (AsuraDissolve attribute;
-- its parts no longer collide or answer queries and its joints stay intact), the body folds
-- forward over its feet, then burns away into drifting ash while a gold Essence wisp rises from it
-- as the reward pulse. Local presentation only; the server removes the model afterwards
-- (Settings.Respawn.EnemyCorpseTime), and plates/lock already drop because IsAlive treats a
-- dissolving body as dead.
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Assets = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.PresentationAssets)

local Dissolve = {}
Dissolve.__index = Dissolve
Dissolve.Collapse = 0.85 -- seconds to fold forward
Dissolve.Fade = 1.3 -- seconds to burn away once down
Dissolve.Pitch = math.rad(-78) -- negative pitches toward the body's LookVector
Dissolve.Sink = 0.4
Dissolve.Roll = math.rad(80)
local ASH = Color3.fromRGB(58, 40, 40)
local ESSENCE = Color3.fromRGB(244, 196, 91)

-- Pure: the root's pose `t` (0..1) into the collapse, rotating about the feet so the body falls
-- forward onto the ground instead of sinking through it. `hip` is root height above the feet.
-- Four-legged creatures (AsuraRig "Creature") topple onto their side instead of pitching forward.
function Dissolve.pose(base: CFrame, t: number, hip: number, creature: boolean?): CFrame
	local e = 1 - (1 - math.clamp(t, 0, 1)) ^ 3
	local fall = if creature then CFrame.Angles(0, 0, Dissolve.Roll * e) else CFrame.Angles(Dissolve.Pitch * e, 0, 0)
	return base * CFrame.new(0, -hip, 0) * fall * CFrame.new(0, hip * (if creature then 0.35 else 1) - Dissolve.Sink * e, 0)
end

export type Controller = typeof(setmetatable({} :: { State: any, Playing: { [Model]: { Started: number, Base: CFrame, Hip: number, Faded: boolean, Creature: boolean } } }, Dissolve))

function Dissolve.new(state: any): Controller
	return setmetatable({ State = state, Playing = {} }, Dissolve)
end

local function emitAsh(root: BasePart)
	local e = Instance.new("ParticleEmitter")
	e.Name, e.Texture, e.Rate = "DissolveAsh", if Assets.Textures.Ash ~= "" then Assets.Textures.Ash else Assets.Textures.Smoke, 0
	e.Lifetime, e.Speed, e.SpreadAngle = NumberRange.new(0.8, 1.6), NumberRange.new(1, 3), Vector2.new(180, 180)
	e.Color, e.LightEmission, e.Acceleration = ColorSequence.new(ASH, Color3.fromRGB(150, 40, 36)), 0.2, Vector3.new(0, 3, 0)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.4) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	e.Parent = root
	e:Emit(26)
end

-- The reward pulse: a small gold wisp that climbs and fades where the foe fell.
local function wisp(at: Vector3)
	local p = Instance.new("Part")
	p.Name, p.Shape, p.Size, p.Material, p.Color = "EssenceWisp", Enum.PartType.Ball, Vector3.one * 0.6, Enum.Material.Neon, ESSENCE
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Position, p.Parent = at, workspace
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Parent = ESSENCE, 10, 2, p
	TweenService:Create(p, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = at + Vector3.new(0, 5, 0), Transparency = 1, Size = Vector3.one * 0.2 }):Play()
	TweenService:Create(light, TweenInfo.new(1.1), { Brightness = 0 }):Play()
	Debris:AddItem(p, 1.2)
end

local function fade(model: Model, seconds: number)
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			TweenService:Create(d, info, { Transparency = 1 }):Play()
		elseif d:IsA("Decal") then
			TweenService:Create(d, info, { Transparency = 1 }):Play()
		elseif d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
			(d :: any).Enabled = false
		end
	end
end

function Dissolve.Update(self: Controller, _dt: number)
	local now = os.clock()
	for _, entity in self.State.Entities do
		local model, root = entity.Model, entity.Root
		if entity.Kind == "Enemy" and root and not self.Playing[model] and model.Parent and model:GetAttribute("AsuraDissolve") ~= nil then
			local humanoid = entity.Humanoid
			local hip = if humanoid then humanoid.HipHeight + root.Size.Y * 0.5 else 3
			self.Playing[model] = { Started = now, Base = root.CFrame, Hip = hip, Faded = false, Creature = model:GetAttribute("AsuraRig") == "Creature" }
			emitAsh(root)
		end
	end
	for model, play in self.Playing do
		local root = model.Parent and model:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			self.Playing[model] = nil
			continue
		end
		local t = (now - play.Started) / Dissolve.Collapse
		root.CFrame = Dissolve.pose(play.Base, t, play.Hip, play.Creature)
		if t >= 1 and not play.Faded then
			play.Faded = true
			fade(model, Dissolve.Fade)
			emitAsh(root)
			wisp(root.Position)
		end
	end
end

function Dissolve.Destroy(self: Controller)
	table.clear(self.Playing)
end

return Dissolve
