--!strict
-- Fighter animation playback for players and ordinary enemies (bosses keep BossAnimations, creatures
-- CreatureMotion). Every frame each fighter's replicated combat state (the AsuraState snapshot) picks
-- an AnimationCatalog slot: the weapon's ready stance or arms-only carry underneath, and on top its
-- attacks, guard, deflect, dodges, hit reactions, posture break and recovery. Cosmetic only: damage
-- and timing stay on the server and no animation marker reports contact.
-- Attacks are phase-locked to the server's move clock (state elapsed + snapshot age), so the authored
-- contact lands inside the authoritative active frames; drift is corrected, hit-stop is respected.
-- Only authored slots play (a Custom id, or in Studio a review override set as the LocalPlayer
-- attribute AsuraAnimReview_<slot name>); stock stand-ins stay off, so a slot without an authored clip
-- looks exactly as before. Ownership: a character's own client animates it and the tracks replicate
-- through its Animator, so this client animates its own character and server-owned NPCs only.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage").AsurasPath
local Catalog = require(Shared.Shared.AnimationCatalog)
local Weapons = require(Shared.Simulation.WeaponSchema)

local Animations = {}
Animations.__index = Animations

local DRIFT = 0.06 -- seconds an attack may stray from the server's move clock before it is re-seated
local FADE_IN, FADE_OUT = 0.06, 0.12
local MOVING_SPEED = 2 -- studs/s of horizontal root speed that swaps the ready stance for the carry
local ATTACK = { Startup = true, Active = true, Recovery = true }
local BROKEN = { GuardBroken = true, StaminaBroken = true, StanceBroken = true }
local SILENT = { KO = true, DeathblowAttacker = true, DeathblowVictim = true, RestingAtShrine = true }

-- Move id -> (weapon slot key, built move with its tempo-scaled Timing).
local MOVES: { [string]: { Key: string, Move: any } } = {}
for _, spec in Weapons.Weapons :: { [string]: any } do
	for index, move in spec.Light do
		MOVES[move.Id] = { Key = "Light" .. math.min(index, 4), Move = move }
	end
	MOVES[spec.Heavy.Id] = { Key = "Heavy", Move = spec.Heavy }
	MOVES[spec.RunningAttack.Id] = { Key = "Running", Move = spec.RunningAttack }
	MOVES[spec.WeaponArt.Id] = { Key = "WeaponArt", Move = spec.WeaponArt }
end

type Actor = {
	Model: Model,
	Animator: Animator,
	Root: BasePart,
	Tracks: { [string]: AnimationTrack },
	Base: AnimationTrack?,
	Action: AnimationTrack?,
	ActionKey: string?,
	Attack: boolean,
	Finished: string?,
	Serial: number,
	AttackSerial: number,
	AttackMove: string?,
	LastState: string?,
	Weapon: string?,
}

local function review(slot: Catalog.Slot): string?
	if slot.Custom then
		return slot.Custom
	end
	if RunService:IsStudio() then
		local id = Players.LocalPlayer:GetAttribute("AsuraAnimReview_" .. slot.Name)
		return if type(id) == "string" and id ~= "" then id else nil
	end
	return nil
end

local function track(actor: Actor, slot: Catalog.Slot?): AnimationTrack?
	if not slot then
		return nil
	end
	local id = review(slot)
	if not id then
		return nil
	end
	local cached = actor.Tracks[id]
	if cached then
		return cached
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, loaded = pcall(function()
		return actor.Animator:LoadAnimation(animation)
	end)
	animation:Destroy()
	if not ok then
		return nil
	end
	loaded.Priority = (Enum.AnimationPriority :: any)[slot.Priority]
	loaded.Looped = slot.Looped
	actor.Tracks[id] = loaded
	return loaded
end

local function stopAction(actor: Actor, fade: number?)
	if actor.Action and actor.Action.IsPlaying then
		actor.Action:Stop(fade or FADE_OUT)
	end
	actor.Action, actor.ActionKey, actor.Attack = nil, nil, false
end

-- Starts (or keeps) the action layer. `key` identifies one occurrence, so a repeat of the same clip
-- (a second heavy, another hit) restarts it while the same occurrence is only kept in sync.
local function action(actor: Actor, key: string, slot: Catalog.Slot?, position: number?, attack: boolean)
	if actor.Finished == key then
		return -- this occurrence already played out; the server state just outlasted the clip
	end
	if actor.ActionKey == key then
		local current = actor.Action
		if current and position and current.IsPlaying and current.Speed > 0 and math.abs(current.TimePosition - position) > DRIFT then
			current.TimePosition = math.min(position, math.max(current.Length - 1 / 60, 0))
		end
		return
	end
	local nextTrack = track(actor, slot)
	if actor.Action and actor.Action ~= nextTrack and actor.Action.IsPlaying then
		actor.Action:Stop(FADE_IN)
	end
	actor.Action, actor.ActionKey, actor.Attack, actor.Finished = nextTrack, key, attack, nil
	if nextTrack then
		nextTrack:Play(FADE_IN, 1, 1)
		if position then
			nextTrack.TimePosition = math.clamp(position, 0, math.max(nextTrack.Length - 1 / 60, 0))
		end
	end
end

local function base(actor: Actor, slot: Catalog.Slot?)
	local nextTrack = track(actor, slot)
	if actor.Base == nextTrack then
		if nextTrack and not nextTrack.IsPlaying then
			nextTrack:Play(0.2)
		end
		return
	end
	if actor.Base and actor.Base.IsPlaying then
		actor.Base:Stop(0.2)
	end
	actor.Base = nextTrack
	if nextTrack then
		nextTrack:Play(0.2)
	end
end

local function release(actor: Actor)
	for _, playing in actor.Tracks do
		if playing.IsPlaying then
			playing:Stop(0.2)
		end
		playing:Destroy()
	end
	table.clear(actor.Tracks)
end

-- Loads every authored track a fighter with this weapon can need, so the first swing already knows its
-- length and is seated on the server's clock (a never-loaded track reports Length 0 and would start late).
local function warm(actor: Actor, weapon: string)
	for _, key in Catalog.WeaponKeys do
		track(actor, Catalog.weapon(weapon, key))
	end
	for _, key in Catalog.UniversalKeys do
		track(actor, Catalog.universal(key))
	end
end

function Animations.new(state: any): any
	task.spawn(function()
		local animations = {}
		for _, id in Catalog.allIds("R15") do
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			table.insert(animations, animation)
		end
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync(animations)
		end)
	end)
	return setmetatable({ State = state, Actors = {} :: { [Model]: Actor } }, Animations)
end

local function eligible(entity: any): boolean
	local model = entity.Model :: Model
	if not model.Parent or entity.Boss or not entity.Snapshot or not entity.Root then
		return false
	end
	if model:GetAttribute("AsuraRig") == "Creature" or model:GetAttribute("AsuraAnimationPlaying") ~= nil then
		return false
	end
	local owner = Players:GetPlayerFromCharacter(model)
	return owner == nil or owner == Players.LocalPlayer
end

function Animations.Step(self: any, entity: any, actor: Actor)
	local s = entity.Snapshot
	local state: string = s.State
	local weapon: string = s.Weapon
	local elapsed = s.StateElapsed + math.max(0, os.clock() - entity.UpdatedAt)
	local entered = actor.LastState ~= state
	if entered then
		actor.Serial += 1
	end
	if actor.Weapon ~= weapon then
		local first = actor.Weapon == nil
		actor.Weapon = weapon
		warm(actor, weapon)
		if not first and state == "Idle" then
			action(actor, "Equip" .. actor.Serial, Catalog.weapon(weapon, "Equip"), 0, false)
		end
	end
	if SILENT[state] then
		stopAction(actor, 0.2)
		base(actor, nil)
		actor.LastState = state
		return
	end
	-- Underneath: the full-body ready stance while standing, the arms-only carry while moving.
	local velocity = actor.Root.AssemblyLinearVelocity
	local moving = Vector3.new(velocity.X, 0, velocity.Z).Magnitude > MOVING_SPEED
	base(actor, Catalog.weapon(weapon, if moving then "Move" else "Idle"))
	if ATTACK[state] and s.Move and MOVES[s.Move] then
		local entry = MOVES[s.Move]
		local timing = entry.Move.Timing
		local into = elapsed
		if state == "Active" then
			into += timing.StartupSeconds
		elseif state == "Recovery" then
			into += timing.StartupSeconds + timing.ActiveSeconds
		end
		-- One swing keeps one key from Startup through Recovery; a new Startup (a second heavy) restarts.
		if actor.AttackMove ~= s.Move or (state == "Startup" and entered) then
			actor.AttackSerial += 1
			actor.AttackMove = s.Move
		end
		action(actor, s.Move .. "#" .. actor.AttackSerial, Catalog.weapon(weapon, entry.Key :: any), into, true)
	elseif state == "Blocking" then
		if not (actor.Action and actor.ActionKey and string.sub(actor.ActionKey, 1, 11) == "GuardImpact" and actor.Action.IsPlaying) then
			action(actor, "Guard", Catalog.weapon(weapon, "Guard"), nil, false)
		end
	elseif state == "Blockstun" then
		action(actor, "GuardImpact" .. actor.Serial, Catalog.weapon(weapon, "GuardImpact"), elapsed, false)
	elseif state == "Deflecting" then
		action(actor, "Deflect" .. actor.Serial, Catalog.universal("Deflect"), elapsed, false)
	elseif state == "Dashing" then
		local look = actor.Root.CFrame.LookVector
		local backward = s.DashDirX * look.X + s.DashDirZ * look.Z < -0.5
		local key = if backward then "Backdash" else "Roll"
		action(actor, key .. actor.Serial, Catalog.universal(key :: any), elapsed, false)
	elseif state == "Hitstun" then
		local key = if s.StateDuration >= 0.4 then "Hitstun_Heavy" else "Hitstun_Light"
		action(actor, key .. actor.Serial, Catalog.universal(key :: any), elapsed, false)
	elseif BROKEN[state] then
		action(actor, "StanceBroken", Catalog.universal("StanceBroken"), nil, false)
	elseif actor.LastState and BROKEN[actor.LastState] then
		action(actor, "Recover" .. actor.Serial, Catalog.universal("Recover"), 0, false)
	elseif actor.Action and (actor.Attack or actor.ActionKey == "Guard" or actor.ActionKey == "StanceBroken") then
		-- Back to neutral: an attack plays out its last recovery frames, held poses release.
		if not actor.Attack or not actor.Action.IsPlaying or actor.Action.Length - actor.Action.TimePosition > 0.15 then
			stopAction(actor)
		end
	end
	if not ATTACK[state] then
		actor.AttackMove = nil
	end
	-- A finished one-shot releases the layer and remembers its occurrence, so a clip that ends a frame
	-- before the server leaves the state (a swing's Recovery, a hitstun) is not restarted on its last frame.
	if actor.Action and not actor.Action.IsPlaying and not actor.Action.Looped then
		actor.Finished = actor.ActionKey
		actor.Action, actor.ActionKey, actor.Attack = nil, nil, false
	end
	actor.LastState = state
end

function Animations.Update(self: any, _dt: number)
	local seen: { [Model]: boolean } = {}
	for _, entity in self.State.Entities do
		if not eligible(entity) then
			continue
		end
		local model = entity.Model :: Model
		local actor = self.Actors[model]
		if not actor then
			local humanoid = entity.Humanoid or model:FindFirstChildOfClass("Humanoid")
			local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
			if not animator or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
				continue
			end
			actor = { Model = model, Animator = animator, Root = entity.Root, Tracks = {}, Base = nil, Action = nil,
				ActionKey = nil, Attack = false, Finished = nil, Serial = 0, AttackSerial = 0, AttackMove = nil, LastState = nil, Weapon = nil }
			self.Actors[model] = actor
		end
		local current = actor :: Actor
		current.Root = entity.Root
		seen[model] = true
		self:Step(entity, current)
		model:SetAttribute("AsuraFighterAnimation", current.ActionKey)
	end
	for model, actor in self.Actors do
		if not seen[model] then
			release(actor)
			self.Actors[model] = nil
		end
	end
end

function Animations.Destroy(self: any)
	for _, actor in self.Actors do
		release(actor)
	end
	table.clear(self.Actors)
end

return Animations
