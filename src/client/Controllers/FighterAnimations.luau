--!strict
-- Fighter animation playback for players and ordinary enemies (bosses keep BossAnimations, creatures
-- CreatureMotion). Every frame each fighter's replicated combat state (the AsuraState snapshot) picks
-- an AnimationCatalog slot: the weapon's ready stance or arms-only carry underneath, and on top its
-- attacks, guard, deflect, dodges, hit reactions, posture break and recovery. Cosmetic only: damage
-- and timing stay on the server and no animation marker reports contact.
-- Attacks are phase-locked to the server's move clock (state elapsed + snapshot age), so the authored
-- contact lands inside the authoritative active frames; a swing seen late catches up (starts earlier in
-- the clip and plays up to CATCH_UP x fast until contact) instead of skipping its windup. Drift is
-- corrected, hit-stop is respected.
-- Only authored slots play (a Custom id, or in Studio a review override set as the LocalPlayer
-- attribute AsuraAnimReview_<slot name>); stock stand-ins stay off, so a slot without an authored clip
-- looks exactly as before. Every client animates every fighter it sees from the server state: the owner's
-- tracks reach observers by Animator replication only after the owner has seen its own state and a
-- second hop, which cut remote windups short (Studio two-client test), so on other players' characters
-- the replicated copies of authored clips are stopped locally and this client's own tracks show instead.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage").AsurasPath
local Workspace = game:GetService("Workspace")
local Catalog = require(Shared.Shared.AnimationCatalog)
local Weapons = require(Shared.Simulation.WeaponSchema)
local World = require(Shared.Shared.WorldDefinitions)

local Animations = {}
Animations.__index = Animations

local DRIFT = 0.06 -- seconds an attack may stray from the server's move clock before it is re-seated
local CATCH_UP = 2 -- fastest playback a late swing uses to reach its contact on time
local FADE_IN, FADE_OUT = 0.06, 0.12
local MOVING_SPEED = 2 -- studs/s of horizontal root speed that swaps the ready stance for the carry
local ATTACK = { Startup = true, Active = true, Recovery = true }
local BROKEN = { GuardBroken = true, StaminaBroken = true, StanceBroken = true }
local SILENT = { KO = true, DeathblowAttacker = true, DeathblowVictim = true, RestingAtShrine = true }

-- Every authored id, so replicated copies on other players' characters can be recognised.
local AUTHORED: { [string]: boolean } = {}
for _, entry in Catalog.Universal do
	if entry.Custom then
		AUTHORED[entry.Custom] = true
	end
end
for _, group in { Catalog.Weapons, Catalog.Characters } :: { any } do
	for _, set in group do
		for _, entry in set do
			if entry.Custom then
				AUTHORED[entry.Custom] = true
			end
		end
	end
end

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
	AttackSeq: number?,
	OwnLead: boolean?, -- the owner's adopted predicted swing: no drift correction toward the server clock
	LastSeq: number?,
	LastState: string?,
	Weapon: string?,
	Definition: string?, -- AsuraDefinition: a production enemy's own clips replace its weapon's
	CatchUntil: number?, -- clip time of the contact a late swing is catching up to
	Ground: Vector3, -- smoothed planar root speed measured from its replicated positions (gait playback)
	GroundPos: Vector3?,
	GroundAt: number?,
	Replicated: RBXScriptConnection?,
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

-- The fighter's own authored clip for a key when its character set has one, else the shared slot.
local function pick(actor: Actor, key: string, shared: Catalog.Slot?): Catalog.Slot?
	local own = Catalog.character(actor.Definition, key)
	return if own and review(own) then own else shared
end

local function weaponSlot(actor: Actor, weapon: string, key: Catalog.WeaponKey): Catalog.Slot?
	return pick(actor, key, Catalog.weapon(weapon, key))
end

local function universalSlot(actor: Actor, key: Catalog.UniversalKey): Catalog.Slot?
	return pick(actor, key, Catalog.universal(key))
end

local function stopAction(actor: Actor, fade: number?)
	if actor.Action and actor.Action.IsPlaying then
		actor.Action:Stop(fade or FADE_OUT)
	end
	actor.Action, actor.ActionKey, actor.Attack, actor.CatchUntil = nil, nil, false, nil
end

-- Starts (or keeps) the action layer. `key` identifies one occurrence, so a repeat of the same clip
-- (a second heavy, another hit) restarts it while the same occurrence is only kept in sync.
-- `contact` (attacks only) is the clip time of the strike: a swing first seen after it started begins
-- early enough, at up to CATCH_UP x, that the contact still lands when the server's does.
local function action(actor: Actor, key: string, slot: Catalog.Slot?, position: number?, attack: boolean, contact: number?)
	if actor.Finished == key then
		return -- this occurrence already played out; the server state just outlasted the clip
	end
	if actor.ActionKey == key then
		local current = actor.Action
		if current and not actor.CatchUntil and position and current.IsPlaying and current.Speed > 0 and math.abs(current.TimePosition - position) > DRIFT then
			current.TimePosition = math.min(position, math.max(current.Length - 1 / 60, 0))
		end
		return
	end
	local nextTrack = track(actor, slot)
	if actor.Action and actor.Action ~= nextTrack and actor.Action.IsPlaying then
		actor.Action:Stop(FADE_IN)
	end
	actor.Action, actor.ActionKey, actor.Attack, actor.Finished, actor.CatchUntil = nextTrack, key, attack, nil, nil
	if nextTrack then
		local seat, speed = position, 1
		if contact and position and position > 1 / 60 and position < contact then
			local remaining = contact - position -- server seconds until the strike lands
			seat = math.max(0, contact - remaining * CATCH_UP)
			speed = (contact - seat) / remaining
			actor.CatchUntil = contact
		end
		nextTrack:Play(FADE_IN, 1, speed)
		if seat then
			nextTrack.TimePosition = math.clamp(seat, 0, math.max(nextTrack.Length - 1 / 60, 0))
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

-- Plays the foe's walk or run cycle so its planted feet hold the ground: rate = ground speed over the speed the
-- cycle was authored for at the model's scale, reversed while it backs away. False when it has no gait.
local function gait(actor: Actor, planar: Vector3): boolean
	local speeds = if actor.Definition then Catalog.Gaits[actor.Definition] else nil
	local walk = if speeds then Catalog.character(actor.Definition, "Walk") else nil
	if not speeds or not walk or not review(walk) then
		return false
	end
	local scale = actor.Model:GetScale()
	local speed = planar.Magnitude
	local run = Catalog.character(actor.Definition, "Run")
	local running = run ~= nil and speeds.Run ~= nil and review(run) ~= nil and speed > (speeds.Walk + speeds.Run) * 0.5 * scale
	base(actor, if running then run else walk)
	local cycle = actor.Base
	if cycle then
		local look = actor.Root.CFrame.LookVector
		local along = planar.Unit:Dot(Vector3.new(look.X, 0, look.Z).Unit)
		local rate = math.clamp(speed / ((if running then speeds.Run :: number else speeds.Walk) * scale), 0.4, 2)
		rate = if along < -0.3 then -rate else rate
		if math.abs(cycle.Speed - rate) > 0.02 then
			cycle:AdjustSpeed(rate)
		end
	end
	return true
end

local function release(actor: Actor)
	if actor.Replicated then
		actor.Replicated:Disconnect()
	end
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
		track(actor, weaponSlot(actor, weapon, key))
	end
	for _, key in Catalog.UniversalKeys do
		track(actor, universalSlot(actor, key))
	end
	track(actor, Catalog.character(actor.Definition, "Death"))
	for _, key in { "Signature", "Walk", "Run" } do
		track(actor, Catalog.character(actor.Definition, key))
	end
end

-- An optional foe's signature (the Warden's Hollow Toll): while its Perilous shockwave telegraph
-- ("Perilous|Shockwave|impact") stands, the clip is seated on the server's clock so its authored
-- contact (the shockwave's Windup into the clip) lands at the impact, then plays its recovery out.
-- Returns the clip time, or nil when no signature is under way.
local function signatureTime(actor: Actor, state: string): number?
	local mob = if actor.Definition then World.Mobs[actor.Definition] else nil
	if not mob or not mob.Signature or state ~= "Idle" then
		return nil
	end
	local raw = actor.Model:GetAttribute("AsuraTelegraph")
	local impact = if type(raw) == "string" then tonumber(string.match(raw, "^Perilous|Shockwave|([%d%.]+)$")) else nil
	if not impact then
		return nil
	end
	local contact = mob.Signature.Shockwave.Windup
	local position = contact - (impact - Workspace:GetServerTimeNow())
	local loaded = track(actor, Catalog.character(actor.Definition, "Signature"))
	local length = if loaded and loaded.Length > 0 then loaded.Length else contact
	return if position < length then math.max(position, 0) else nil
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
	return model:GetAttribute("AsuraRig") ~= "Creature" and model:GetAttribute("AsuraAnimationPlaying") == nil
end

-- On another player's character, an authored clip this client did not start is the owner's replicated
-- copy, which arrives late: stop it here so only this client's state-driven track shows.
local function suppress(actor: Actor, playing: AnimationTrack)
	if not AUTHORED[playing.Animation and playing.Animation.AnimationId or ""] then
		return
	end
	for _, own in actor.Tracks do
		if own == playing then
			return
		end
	end
	playing:Stop(0)
end

function Animations.Step(self: any, entity: any, actor: Actor)
	local s = entity.Snapshot
	local state: string = s.State
	local weapon: string = s.Weapon
	local elapsed = s.StateElapsed + (entity.Age or 0) + math.max(0, os.clock() - entity.UpdatedAt)
	local move: string? = s.Move
	local actionSeq: number = s.ActionSeq
	-- The owner's unconfirmed press (LocalPrediction via WorldState.Predict) shows its windup or guard pose at
	-- once over the Idle snapshot it was predicted on. ActionSeq -1 marks it so the server's start is adopted.
	local own = entity.Id == self.State.LocalId
	local predicted = if own then self.State.Predicted else nil
	if predicted and predicted.Move and state == "Idle" and s.ActionSeq == predicted.Base then
		state, move, actionSeq, elapsed = "Startup", predicted.Move, -1, os.clock() - predicted.Started
	elseif own and state == "Idle" and self.State.GuardPredicted then
		state = "Blocking"
	end
	-- ActionSeq (codec v4) names each action, so a repeat of the same state or move between two snapshots,
	-- with the in-between update skipped, still starts a fresh occurrence.
	local entered = actor.LastState ~= state or actor.LastSeq ~= actionSeq
	actor.LastSeq = actionSeq
	if entered then
		actor.Serial += 1
	end
	if actor.Weapon ~= weapon then
		local first = actor.Weapon == nil
		actor.Weapon = weapon
		warm(actor, weapon)
		if not first and state == "Idle" then
			action(actor, "Equip" .. actor.Serial, weaponSlot(actor, weapon, "Equip"), 0, false)
		end
	end
	local death = if state == "KO" then Catalog.character(actor.Definition, "Death") else nil
	if death and review(death) then
		-- A production enemy falls with its own death and holds the last frame while the corpse dissolves.
		base(actor, nil)
		action(actor, "Death", death, nil, false)
		local dying = actor.Action
		if dying and dying.IsPlaying and dying.Length > 0 and dying.TimePosition >= dying.Length - 0.05 then
			dying:AdjustSpeed(0)
		end
		actor.LastState = state
		return
	end
	if SILENT[state] then
		stopAction(actor, 0.2)
		base(actor, nil)
		actor.LastState = state
		return
	end
	-- Underneath: the full-body ready stance while standing, the arms-only carry while moving (or a production
	-- foe's own full-body gait, which it needs because no Animate script moves its legs).
	local velocity = actor.Root.AssemblyLinearVelocity
	local moving = Vector3.new(velocity.X, 0, velocity.Z).Magnitude > MOVING_SPEED
	-- A gait follows the root's measured travel: a remote root's replicated velocity can read a stride while it is
	-- held in place, which would walk it on the spot.
	local clock, position = os.clock(), actor.Root.Position
	if actor.GroundPos and actor.GroundAt and clock > actor.GroundAt then
		local dt = clock - actor.GroundAt
		local travel = Vector3.new(position.X - actor.GroundPos.X, 0, position.Z - actor.GroundPos.Z) / dt
		if travel.Magnitude < 60 then -- a teleport or strike snap is not a stride
			actor.Ground = actor.Ground:Lerp(travel, math.clamp(dt * 8, 0, 1))
		end
	end
	actor.GroundPos, actor.GroundAt = position, clock
	local walking = actor.Ground.Magnitude > MOVING_SPEED
	if not (walking and gait(actor, actor.Ground)) then
		local paced = if actor.Definition and Catalog.Gaits[actor.Definition] then walking else moving
		base(actor, weaponSlot(actor, weapon, if paced then "Move" else "Idle"))
	end
	local signature = signatureTime(actor, state)
	if signature then
		local raw = actor.Model:GetAttribute("AsuraTelegraph")
		action(actor, "Signature" .. tostring(raw), Catalog.character(actor.Definition, "Signature"), signature, true)
	elseif ATTACK[state] and move and MOVES[move] then
		local entry = MOVES[move]
		local timing = entry.Move.Timing
		local into = elapsed
		if state == "Active" then
			into += timing.StartupSeconds
		elseif state == "Recovery" then
			into += timing.StartupSeconds + timing.ActiveSeconds
		end
		-- One swing keeps one key from Startup through Recovery; a new action (a second heavy) restarts.
		if actor.AttackMove ~= move or actor.AttackSeq ~= actionSeq then
			if actor.AttackSeq == -1 and actor.AttackMove == move and actionSeq >= 0 then
				-- The server started the predicted swing: it keeps playing on the owner's clock, a little ahead of
				-- the server's, instead of being pulled back by the drift correction.
				actor.AttackSeq, actor.OwnLead = actionSeq, true
			else
				actor.AttackSerial += 1
				actor.AttackMove, actor.AttackSeq, actor.OwnLead = move, actionSeq, false
			end
		end
		action(actor, move .. "#" .. actor.AttackSerial, weaponSlot(actor, weapon, entry.Key :: any), if actor.OwnLead then nil else into, true,
			timing.StartupSeconds + timing.ActiveSeconds * 0.5)
	elseif state == "Blocking" then
		if not (actor.Action and actor.ActionKey and string.sub(actor.ActionKey, 1, 11) == "GuardImpact" and actor.Action.IsPlaying) then
			action(actor, "Guard", weaponSlot(actor, weapon, "Guard"), nil, false)
		end
	elseif state == "Blockstun" then
		action(actor, "GuardImpact" .. actor.Serial, weaponSlot(actor, weapon, "GuardImpact"), elapsed, false)
	elseif state == "Deflecting" then
		action(actor, "Deflect" .. actor.Serial, universalSlot(actor, "Deflect"), elapsed, false)
	elseif state == "Dashing" then
		local look = actor.Root.CFrame.LookVector
		local backward = s.DashDirX * look.X + s.DashDirZ * look.Z < -0.5
		local key = if backward then "Backdash" else "Roll"
		action(actor, key .. actor.Serial, universalSlot(actor, key :: any), elapsed, false)
	elseif state == "Hitstun" then
		local key = if s.StateDuration >= 0.4 then "Hitstun_Heavy" else "Hitstun_Light"
		action(actor, key .. actor.Serial, universalSlot(actor, key :: any), elapsed, false)
	elseif BROKEN[state] then
		action(actor, "StanceBroken", universalSlot(actor, "StanceBroken"), nil, false)
	elseif actor.LastState and BROKEN[actor.LastState] then
		action(actor, "Recover" .. actor.Serial, universalSlot(actor, "Recover"), 0, false)
	elseif actor.Action and (actor.Attack or actor.ActionKey == "Guard" or actor.ActionKey == "StanceBroken") then
		-- Back to neutral: an attack plays out its last recovery frames, held poses release.
		if not actor.Attack or not actor.Action.IsPlaying or actor.Action.Length - actor.Action.TimePosition > 0.15 then
			stopAction(actor)
		end
	end
	if not ATTACK[state] then
		actor.AttackMove = nil
	end
	-- A swing catching up returns to authored speed at its contact, whatever state the server has reached.
	local catching = actor.Action
	if actor.CatchUntil and (not catching or not catching.IsPlaying or catching.TimePosition >= actor.CatchUntil - 1e-3) then
		actor.CatchUntil = nil
		if catching and catching.Speed > 0 then
			catching:AdjustSpeed(1)
		end
	end
	-- A finished one-shot releases the layer and remembers its occurrence, so a clip that ends a frame
	-- before the server leaves the state (a swing's Recovery, a hitstun) is not restarted on its last frame.
	if actor.Action and not actor.Action.IsPlaying and not actor.Action.Looped then
		actor.Finished = actor.ActionKey
		actor.Action, actor.ActionKey, actor.Attack, actor.CatchUntil = nil, nil, false, nil
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
				ActionKey = nil, Attack = false, Finished = nil, Serial = 0, AttackSerial = 0, AttackMove = nil, AttackSeq = nil, OwnLead = nil, LastSeq = nil, LastState = nil, Ground = Vector3.zero,
				Weapon = nil, Definition = nil, CatchUntil = nil, Replicated = nil }
			local owner = Players:GetPlayerFromCharacter(model)
			if owner and owner ~= Players.LocalPlayer then
				local created = actor :: Actor
				created.Replicated = animator.AnimationPlayed:Connect(function(playing: AnimationTrack)
					suppress(created, playing)
				end)
				for _, playing in animator:GetPlayingAnimationTracks() do
					suppress(created, playing)
				end
			end
			self.Actors[model] = actor
		end
		local current = actor :: Actor
		current.Root = entity.Root
		local definition = model:GetAttribute("AsuraDefinition")
		current.Definition = if type(definition) == "string" then definition else nil
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
