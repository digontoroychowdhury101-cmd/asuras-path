--!strict
-- Fighter animation playback for players and ordinary enemies (bosses keep BossAnimations, creatures
-- CreatureMotion). Every frame each fighter's replicated combat state (the AsuraState snapshot) picks
-- an AnimationCatalog slot: the weapon's ready stance or arms-only carry underneath, and on top its
-- attacks, guard, deflect, dodges, hit reactions, posture break and recovery. Cosmetic only: damage
-- and timing stay on the server and no animation marker reports contact.
-- This module is the one writer of its tracks' speed (TIMING_CONTRACT §8). An action is one occurrence, named by the
-- intent behind it where there is one, so the server's start of a press the owner already shows is adopted without a
-- restart. Attacks are phase-locked through AnimationTiming: the action's server timeline (state elapsed + snapshot
-- age, or the owner's press clock while it leads) maps to clip time by per-move phase data, and a bounded rate pulls
-- the clip toward it. Clips start without a fade: ActorPose inertializes the pose change, so the first frame already
-- moves from where the body was. Hitstop and cinematics reach a clip only through PlaybackScale; time lost to them is
-- repaid by the same correction.
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
local Prediction = require(Shared.Simulation.LocalPrediction)
local World = require(Shared.Shared.WorldDefinitions)
local Timing = require(Shared.Simulation.AnimationTiming)
local Trajectories = require(Shared.Shared.StrikeTrajectories)
local Settings = require(Shared.Shared.CombatSettings)
local Comfort = require(Shared.Shared.EffectsPreference)
local PlaybackScale = require(script.Parent.PlaybackScale)
local ActorPose = require(script.Parent.ActorPose)

local Animations = {}
Animations.__index = Animations

local FADE_IN, FADE_OUT = 0.06, 0.12 -- only for an actor without a pose writer (beyond POSE_RANGE)
local POSE_ACTORS, POSE_RANGE = 8, 70 -- the nearest fighters get transitions, planted feet and a strike step
local MOVING_SPEED = 2 -- studs/s of horizontal root speed that swaps the ready stance for the carry
local ATTACK = { Startup = true, Active = true, Recovery = true }
local BROKEN = { GuardBroken = true, StaminaBroken = true, StanceBroken = true }
local SILENT = { KO = true, DeathblowAttacker = true, DeathblowVictim = true, RestingAtShrine = true }
-- The authored clip a silent state plays, where one is published. Its keys own the whole body, feet included.
local SET_PIECE: { [string]: any } = { DeathblowAttacker = "Deathblow_Attacker", DeathblowVictim = "Deathblow_Victim", RestingAtShrine = "AltarRest" }

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
	AttackIntent: number?,
	LocalBegan: number?, -- owner's press clock of the shown action while it leads the server's (never pulled back)
	Timeline: number?, -- this frame's seconds into the action on the server's clock, nil when it has no sync
	Phases: Timing.Phases?,
	Duration: number?, -- a clip stretched evenly over its action (dodge): its phases once the clip's length is known
	Nominal: number?,
	BaseRate: number,
	Held: boolean, -- the action layer holds its last frame (a corpse)
	Pose: ActorPose.ActorPose?,
	Step: Vector3, -- this frame's presented step, whichever writer shows it
	Stepper: any?,
	LastSeq: number?,
	LastState: string?,
	Weapon: string?,
	Definition: string?, -- AsuraDefinition: a production enemy's own clips replace its weapon's
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

local dodgeKey: (actor: Actor, dirX: number, dirZ: number) -> any

local function fadeOf(actor: Actor, fade: number): number
	return if actor.Pose then 0 else fade
end

local function stopAction(actor: Actor, fade: number?)
	if actor.Action and actor.Action.IsPlaying then
		actor.Action:Stop(fadeOf(actor, fade or FADE_OUT))
		if actor.Pose then
			actor.Pose:Transition()
		end
	end
	actor.Action, actor.ActionKey, actor.Attack, actor.LocalBegan, actor.Timeline, actor.Phases, actor.Duration, actor.Nominal, actor.Held =
		nil, nil, false, nil, nil, nil, nil, nil, false
end

local function setSpeed(playing: AnimationTrack, speed: number)
	if math.abs(playing.Speed - speed) > 0.005 then
		playing:AdjustSpeed(speed)
	end
end

-- Starts (or keeps) the action layer. `key` identifies one occurrence: a repeat of the same clip (a second heavy,
-- another hit) has a new key and restarts it, while the same occurrence only updates its timeline.
-- `elapsed` is the server's seconds into the action (nil: no sync); `began` the owner's press clock when it leads.
-- A swing first seen after it started keeps as much windup as the bounded rate allows (Timing.plan).
local function action(actor: Actor, key: string, slot: Catalog.Slot?, elapsed: number?, attack: boolean, phases: Timing.Phases?, duration: number?, began: number?)
	if actor.Finished == key then
		return -- this occurrence already played out; the server state just outlasted the clip
	end
	if actor.ActionKey == key then
		-- The same occurrence goes on playing. Once its prediction is confirmed `began` is nil, and drive() follows the
		-- server's timeline from here: the clip was never restarted, and the bounded correction closes the difference.
		actor.Timeline, actor.LocalBegan = elapsed, began
		return
	end
	local nextTrack = track(actor, slot)
	if actor.Action and actor.Action ~= nextTrack and actor.Action.IsPlaying then
		actor.Action:Stop(fadeOf(actor, FADE_IN))
	end
	actor.Action, actor.ActionKey, actor.Attack, actor.Finished = nextTrack, key, attack, nil
	actor.Timeline, actor.Phases, actor.Duration, actor.LocalBegan, actor.Nominal, actor.Held = elapsed, phases, duration, began, nil, false
	if nextTrack then
		local seat = 0
		if elapsed then
			seat = if phases then (Timing.plan(phases, elapsed)) else elapsed
		end
		nextTrack:Play(fadeOf(actor, FADE_IN), 1, 1)
		if seat > 0 then
			nextTrack.TimePosition = math.clamp(seat, 0, math.max(nextTrack.Length - 1 / 60, 0))
		end
		if actor.Pose then
			actor.Pose:Transition()
		end
	end
end

-- The one write of this actor's track speeds, once a frame: the phase's rate with its correction, times the scale.
local function drive(self: any, actor: Actor, now: number, dt: number)
	local scale, body = PlaybackScale.of(actor.Model, now)
	local current = actor.Action
	if current and current.IsPlaying then
		local rate = if actor.Held then 0 else actor.Nominal or 1
		local length = current.Length
		local elapsed = if actor.LocalBegan then now - actor.LocalBegan else actor.Timeline
		if actor.Duration and not actor.Phases and length > 0 then
			actor.Phases = Timing.uniform(actor.Duration, length)
		end
		if elapsed and length > 0 and not actor.Held then
			local phases = actor.Phases
			local target = if phases then Timing.clipTime(phases, elapsed) else math.min(elapsed, length)
			local nominal = if phases then Timing.nominalRate(phases, elapsed) else 1
			actor.Nominal = nominal
			rate = nominal
			-- While slowed nothing is corrected: the time lost is the debt the correction repays afterward.
			if scale >= 1 then
				local factor, seat = Timing.correct(current.TimePosition, target, nominal, dt)
				if seat then
					current.TimePosition = math.clamp(target, 0, math.max(length - 1 / 60, 0))
					self.Stats.Seats += 1
					if actor.Pose then
						actor.Pose:Transition()
					end
				else
					rate = nominal * factor
				end
			end
		elseif elapsed and length <= 0 then
			self.Stats.Unloaded += 1 -- first use: the track reports a length once loaded, and is seated then
		end
		setSpeed(current, rate * scale)
	end
	local under = actor.Base
	if under and under.IsPlaying then
		setSpeed(under, actor.BaseRate * body)
	end
	-- The server's blade includes this step at the model's scale, so every fighter shows it, whichever writer it has.
	local stepped = Vector3.zero
	local data = actor.Attack and actor.AttackMove and Trajectories.forFighter(actor.AttackMove, actor.Definition)
	if data and current and current.IsPlaying then
		local clip = if current.Length > 0 then current.TimePosition else Timing.clipTime(data, actor.Timeline or 0)
		stepped = Vector3.new(0, 0, -Trajectories.stepAt(data, clip) * actor.Model:GetScale())
	end
	actor.Step = stepped
	if actor.Pose then
		actor.Pose:SetStep(stepped)
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
	actor.Base, actor.BaseRate = nextTrack, 1
	if nextTrack then
		nextTrack:Play(0.2)
	end
end

-- Plays the foe's walk or run cycle: rate = ground speed over the speed the cycle was authored for at the model's
-- scale. Near actors' legs come from ActorPose, whichever way they move, so the cycle only carries the upper body;
-- a far one has no pose writer and reverses its cycle while it backs away. False when it has no gait.
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
		actor.BaseRate = if along < -0.3 and not actor.Pose then -rate else rate
	end
	return true
end

local function release(actor: Actor)
	if actor.Replicated then
		actor.Replicated:Disconnect()
	end
	if actor.Pose then
		actor.Pose:Destroy()
		actor.Pose = nil
	end
	if actor.Stepper then
		actor.Stepper:Destroy()
		actor.Stepper = nil
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
	return setmetatable({ State = state, Actors = {} :: { [Model]: Actor }, Near = {}, Stats = { Seats = 0, Unloaded = 0 } }, Animations)
end

-- Which dodge clip a direction shows, relative to the fighter's facing. A direction with no authored clip of its own
-- falls back to the forward roll, or the backstep behind.
dodgeKey = function(actor: Actor, dirX: number, dirZ: number): any
	local look = actor.Root.CFrame.LookVector
	local right = actor.Root.CFrame.RightVector
	local along, across = dirX * look.X + dirZ * look.Z, dirX * right.X + dirZ * right.Z
	if along < -0.5 then
		return "Backdash"
	end
	local key = if math.abs(across) > math.abs(along) then (if across > 0 then "DashRight" else "DashLeft") else "DashForward"
	local slot = universalSlot(actor, key :: any)
	return if slot and review(slot) then key else "Roll"
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
	local presented = if own then self.State:Presented(s) else nil
	local began: number? = nil
	if presented and presented.Move then
		began = presented.Started
		state, move, actionSeq, elapsed = "Startup", presented.Move, -1, os.clock() - presented.Started
	elseif presented and presented.DashSeq then
		began = presented.Started
		state, actionSeq, elapsed = "Dashing", -1, os.clock() - presented.Started
	elseif own and state == "Idle" and self.State.GuardPredicted then
		state = "Blocking"
	end
	-- The intent behind what is shown (0: none, an NPC's or a server-side action).
	local intent: number = if presented then presented.Seq else s.IntentSeq
	-- ActionSeq (codec v4) names each action, so a repeat of the same state or move between two snapshots,
	-- with the in-between update skipped, still starts a fresh occurrence.
	local entered = actor.LastState ~= state or actor.LastSeq ~= actionSeq
	actor.LastSeq = actionSeq
	if entered then
		actor.Serial += 1
		if own then
			-- Diagnostic only: the intent behind this occurrence (the prediction's own seq while it is shown).
			Prediction.trace(intent, "Occurrence", state .. ":" .. (move or ""))
		end
	end
	if actor.Weapon ~= weapon then
		local first = actor.Weapon == nil
		actor.Weapon = weapon
		warm(actor, weapon)
		if not first and state == "Idle" then
			action(actor, "Equip" .. actor.Serial, weaponSlot(actor, weapon, "Equip"), nil, false)
		end
	end
	local death = if state == "KO" then Catalog.character(actor.Definition, "Death") else nil
	if death and review(death) then
		-- A production enemy falls with its own death and holds the last frame while the corpse dissolves.
		base(actor, nil)
		action(actor, "Death", death, nil, false)
		local dying = actor.Action
		if dying and dying.IsPlaying and dying.Length > 0 and dying.TimePosition >= dying.Length - 0.05 then
			actor.Held = true
		end
		actor.LastState = state
		return
	end
	if SILENT[state] and not (SET_PIECE[state] and universalSlot(actor, SET_PIECE[state])) then
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
		if not began then
			if state == "Active" then
				into += timing.StartupSeconds
			elseif state == "Recovery" then
				into += timing.StartupSeconds + timing.ActiveSeconds
			end
		end
		-- One swing keeps one key from Startup through Recovery. The same intent showing the same move is the same
		-- occurrence (the server's start of the owner's press, adopted on its clock); a new action restarts.
		local adopted = intent > 0 and actor.AttackIntent == intent and actor.AttackMove == move
		if adopted then
			actor.AttackSeq = actionSeq
		elseif actor.AttackMove ~= move or actor.AttackSeq ~= actionSeq then
			actor.AttackSerial += 1
			actor.AttackMove, actor.AttackSeq, actor.AttackIntent = move, actionSeq, intent
		end
		local slot = weaponSlot(actor, weapon, entry.Key :: any)
		local key = move .. "#" .. actor.AttackSerial
		local phases: Timing.Phases? = nil
		if actor.ActionKey ~= key then
			local clip = track(actor, slot)
			phases = Trajectories.phases(move, timing, if clip then clip.Length else 0)
		end
		action(actor, key, slot, into, true, phases, nil, began)
	elseif state == "Blocking" then
		if not (actor.Action and actor.ActionKey and string.sub(actor.ActionKey, 1, 11) == "GuardImpact" and actor.Action.IsPlaying) then
			action(actor, "Guard", weaponSlot(actor, weapon, "Guard"), nil, false)
		end
	elseif state == "Blockstun" then
		action(actor, "GuardImpact" .. actor.Serial, weaponSlot(actor, weapon, "GuardImpact"), elapsed, false)
	elseif state == "Deflecting" then
		action(actor, "Deflect" .. actor.Serial, universalSlot(actor, "Deflect"), elapsed, false)
	elseif state == "Dashing" then
		-- One dodge keeps one key from the owner's press through the server's grant, whatever samples arrive between.
		local key = if intent > 0 then "Dodge:i" .. intent else "Dodge#" .. actor.Serial
		local dirX: number = if presented then presented.DirX or 0 else s.DashDirX
		local dirZ: number = if presented then presented.DirZ or 0 else s.DashDirZ
		local duration: number = if not presented then s.DashDuration
			elseif presented.Kind == "Roll" then Settings.Movement.RollDuration
			else Settings.Movement.DashDuration
		local slot = if actor.ActionKey == key then nil else universalSlot(actor, dodgeKey(actor, dirX, dirZ))
		action(actor, key, slot, elapsed, false, nil, if duration > 0 then duration else nil, began)
	elseif state == "Hitstun" then
		local key = if s.StateDuration >= 0.4 then "Hitstun_Heavy" else "Hitstun_Light"
		action(actor, key .. actor.Serial, universalSlot(actor, key :: any), elapsed, false)
	elseif state == "RestingAtShrine" then
		action(actor, "AltarRest", universalSlot(actor, "AltarRest"), nil, false)
	elseif SET_PIECE[state] then
		action(actor, SET_PIECE[state] .. actor.Serial, universalSlot(actor, SET_PIECE[state]), elapsed, false)
	elseif BROKEN[state] then
		action(actor, "StanceBroken", universalSlot(actor, "StanceBroken"), nil, false)
	elseif actor.LastState and BROKEN[actor.LastState] then
		action(actor, "Recover" .. actor.Serial, universalSlot(actor, "Recover"), nil, false)
	elseif actor.Action and actor.LocalBegan and not presented and actor.ActionKey and string.sub(actor.ActionKey, 1, 7) == "Dodge:i" then
		-- A predicted dodge that never became the server's (refused, timed out, or left behind) ends now.
		stopAction(actor)
	elseif actor.Action and (actor.Attack or actor.ActionKey == "Guard" or actor.ActionKey == "StanceBroken" or actor.ActionKey == "AltarRest") then
		-- Back to neutral: an attack plays out its last recovery frames, held poses release.
		if not actor.Attack or not actor.Action.IsPlaying or actor.Action.Length - actor.Action.TimePosition > 0.15 then
			stopAction(actor)
		end
	end
	if not ATTACK[state] then
		actor.AttackMove, actor.AttackIntent = nil, nil
	end
	-- A finished one-shot releases the layer and remembers its occurrence, so a clip that ends a frame
	-- before the server leaves the state (a swing's Recovery, a hitstun) is not restarted on its last frame.
	if actor.Action and not actor.Action.IsPlaying and not actor.Action.Looped then
		actor.Finished = actor.ActionKey
		actor.Action, actor.ActionKey, actor.Attack, actor.LocalBegan, actor.Timeline, actor.Phases, actor.Duration, actor.Nominal =
			nil, nil, false, nil, nil, nil, nil, nil
	end
	actor.LastState = state
end

-- Whether this body's feet are planted by ActorPose this frame. Dodges, breaks and reactions that throw the body keep
-- their clip's legs; jumps and falls release in ActorPose when no ground is under the feet.
local PLANTED = { Idle = true, Startup = true, Active = true, Recovery = true, Blocking = true, Blockstun = true, Deflecting = true, Hitstun = true }

function Animations.Update(self: any, dt: number)
	local seen: { [Model]: boolean } = {}
	local now = os.clock()
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
				ActionKey = nil, Attack = false, Finished = nil, Serial = 0, AttackSerial = 0, AttackMove = nil, AttackSeq = nil, AttackIntent = nil,
				LocalBegan = nil, Timeline = nil, Phases = nil, Duration = nil, Nominal = nil, BaseRate = 1, Held = false, Pose = nil, Step = Vector3.zero, Stepper = nil,
				LastSeq = nil, LastState = nil, Ground = Vector3.zero, Weapon = nil, Definition = nil, Replicated = nil }
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
		drive(self, current, now, dt)
		local pose = current.Pose
		if pose then
			local state = entity.Snapshot.State
			local presented = entity.Id == self.State.LocalId and self.State:Presented(entity.Snapshot)
			pose:SetFeet(PLANTED[state] == true and not (presented and presented.DashSeq) and not Comfort.reducedMotion())
			pose:SetClipFeet(current.Attack or current.ActionKey == "Guard")
			pose:Release(SILENT[state] == true and not (SET_PIECE[state] and current.ActionKey))
		end
		model:SetAttribute("AsuraFighterAnimation", current.ActionKey)
	end
	for model, actor in self.Actors do
		if not seen[model] then
			release(actor)
			self.Actors[model] = nil
		end
	end
	self:AssignPoses()
end

-- The nearest fighters within range get a pose writer; the owner always does. A fighter leaving the set hands its
-- joints back and falls back to fades; its presented step goes on through a step writer (PostAnimate).
function Animations.AssignPoses(self: any)
	local near = self.Near
	table.clear(near)
	local own = self.State:Own()
	local origin = own and own.Root and own.Root.Position
	for model, actor in self.Actors do
		local mine = own ~= nil and own.Model == model
		local distance = if origin then (actor.Root.Position - origin).Magnitude else math.huge
		if mine or distance <= POSE_RANGE then
			table.insert(near, { Actor = actor, Distance = if mine then -1 else distance })
		end
	end
	if #near > POSE_ACTORS then
		table.sort(near, function(a: any, b: any)
			return a.Distance < b.Distance
		end)
	end
	local chosen: { [any]: boolean } = {}
	for index = 1, math.min(#near, POSE_ACTORS) do
		chosen[near[index].Actor] = true
	end
	for _, actor in self.Actors do
		if chosen[actor] and not actor.Pose then
			if actor.Stepper then
				actor.Stepper:Destroy()
				actor.Stepper = nil
			end
			actor.Pose = ActorPose.attach(actor.Model, actor.Root, own ~= nil and own.Model == actor.Model)
			if actor.Pose then
				actor.Pose:SetStep(actor.Step)
			end
		elseif actor.Pose and not chosen[actor] then
			actor.Pose:Destroy()
			actor.Pose = nil
		end
	end
end

-- The baked swing this model is showing, for its trail: the data, the clip time (frozen with the clip in hitstop),
-- and a key naming the occurrence. nil when it shows none, or its clip has no baked blade.
function Animations.Swing(self: any, model: Model): (any, number, string, string?)
	local actor = self.Actors[model]
	local playing = actor and actor.Action
	if not actor or not playing or not actor.Attack or not actor.AttackMove or not actor.ActionKey then
		return nil, 0, "", nil
	end
	return Trajectories.forFighter(actor.AttackMove, actor.Definition), playing.TimePosition, actor.ActionKey, actor.AttackMove
end

-- After the Animator wrote this frame's clip pose, before physics (Bootstrap's PreSimulation).
function Animations.PostAnimate(self: any, dt: number)
	local now = os.clock()
	for _, actor in self.Actors do
		if actor.Pose then
			actor.Pose:Apply(dt, now)
		elseif actor.Stepper or actor.Step.Magnitude > 1e-3 then
			actor.Stepper = actor.Stepper or ActorPose.stepWriter(actor.Model)
			if actor.Stepper then
				actor.Stepper:Apply(actor.Step)
			end
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
