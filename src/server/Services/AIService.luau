--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/AIService
-- PvE combat coordinator. Every agent drives the same CombatRules fighter as a player does, through
-- CharacterService intents; nothing here applies damage directly except authored boss shockwaves,
-- which are telegraphed and routed through CombatRules.applyArea.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("AsurasPath")
local World = require(Shared.Shared.WorldDefinitions)
local Settings = require(Shared.Shared.CombatSettings) :: any
local Weapons = require(Shared.Simulation.WeaponSchema) :: any
local Tempo = require(Shared.Simulation.Tempo) :: any
local Schema = require(Shared.Simulation.MoveSchema) :: any
local Combat = require(Shared.Simulation.CombatRules)
local Characters = require(script.Parent:WaitForChild("CharacterService") :: ModuleScript)
local BossTactics = require(script.Parent.BossTactics)
local BossDuo = require(script.Parent.BossDuo)
local BossAppearance = require(script.Parent.BossAppearance)
local BossMotion = require(script.Parent.BossMotion)
local BossRules = require(Shared.Shared.BossEncounterRules)
local Handoff = require(script.Parent.EncounterHandoff)
local HandoffRules = require(Shared.Shared.BossHandoff)
local Bodies = require(Shared.Shared.BossBodies)
local Zones = require(Shared.Shared.MonasteryZones)
local Campaign = require(Shared.Shared.CampaignZones)

type Entity = Characters.Entity
type MobDef = World.MobDef
type BossDef = World.BossDef
type AIProfile = World.AIProfile
type Shockwave = World.Shockwave

export type Mode = "Idle" | "Patrol" | "Alert" | "Engage" | "Combat" | "StanceBroken" | "Return" | "Cinematic" | "Dead"
export type TelegraphClass = "Light" | "Heavy" | "Perilous"
export type AgentInfo = { Kind: "Mob" | "Boss", Definition: string, SpawnId: string?, Region: string, Essence: number }

type PendingAttack = { Action: "Light" | "Heavy" | "WeaponArt", At: number }
type PendingShockwave = { At: number, Wave: Shockwave, Cancelable: boolean }

type Agent = {
	Id: number,
	Kind: "Mob" | "Boss",
	Definition: string,
	SpawnId: string?,
	Region: string,
	Essence: number,
	Home: CFrame,
	Patrol: { Vector3 },
	PatrolIndex: number,
	Profile: AIProfile,
	Rng: Random,
	Mode: Mode,
	ModeSince: number,
	Target: number,
	LastSeen: number,
	LastKnown: Vector3?,
	Suspicion: number,
	NextThink: number,
	PlannedFor: number,
	DeflectAt: number,
	GuardUntil: number,
	RecomposeUntil: number,
	Pending: PendingAttack?,
	StrafeSign: number,
	StrafeUntil: number,
	-- Boss only
	Boss: BossDef?,
	Phase: number,
	Deathblows: number,
	Allowed: { [number]: boolean }?,
	Shockwave: PendingShockwave?,
	TransitionEnd: number,
	NextSpecial: number,
	HoldUntil: number, -- encounter handoff: the boss stands until readable control returns (#16)
	Pillars: { Bodies.Pillar }?, -- arena columns a long body steers around
	Clearance: number,
	Zone: Zones.Zone?, -- Monastery spawns fight only inside their zone (batch 15, #27)
}

type Noise = { Position: Vector3, Time: number }

local AIService = {}

local PLAYER_REACTION = 0.25
local PERILOUS_LEAD = 0.45
local NOISE_LIFETIME = 1.5
local LOS_HEIGHT = Vector3.new(0, 1.5, 0)
local CLOSE_DETECT = 6

local agents: { [number]: Agent } = {}
local spawnAgents: { [string]: number } = {}
local bossAgents: { [string]: number } = {}
local noises: { Noise } = {}
local bossListeners: { (bossId: string, entityId: number) -> () } = {}
local disconnectors: { () -> () } = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local ignoreDirty = true
local running = false

-------------------------------------------------------------------------------------------------
-- Telegraphing (pure): schedules attacks so a warning always precedes impact by a fair margin.
-------------------------------------------------------------------------------------------------

local Telegraph = {}

function Telegraph.classify(move: Combat.MoveData): TelegraphClass
	if move.Unblockable then
		return "Perilous"
	elseif move.Kind == "Heavy" or move.Kind == "WeaponArt" or move.Kind == "RunningAttack" then
		return "Heavy"
	end
	return "Light"
end

function Telegraph.lead(class: TelegraphClass, reactionFloor: number): number
	if class == "Perilous" then
		return math.max(PERILOUS_LEAD, reactionFloor)
	elseif class == "Heavy" then
		return math.max(Tempo.HeavyMinSeconds, reactionFloor)
	end
	return Tempo.LightMinSeconds
end

-- Returns (attackAt, warnAt, impactAt). The warning is published at `now`; if the move's own startup
-- is shorter than the required lead the attack itself is delayed so impact - warn >= lead.
function Telegraph.plan(move: Combat.MoveData, now: number, reactionFloor: number): (number, number, number)
	local class = Telegraph.classify(move)
	local lead = Telegraph.lead(class, reactionFloor)
	local startup = move.Timing.StartupSeconds
	local attackAt = Tempo.quantizeUp(now + math.max(0, lead - startup))
	return attackAt, now, attackAt + startup
end

function Telegraph.shockwave(wave: Shockwave, now: number): (number, number)
	return now, Tempo.quantizeUp(now + math.max(wave.Windup, PERILOUS_LEAD))
end

AIService.Telegraph = table.freeze(Telegraph)

-------------------------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------------------------

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function flatUnit(v: Vector3): Vector3
	local f = flat(v)
	local m = f.Magnitude
	return if m > 1e-5 then f / m else Vector3.zero
end

-- Where a fighting AI aims (StrikeGeometry): the target's position a short beat ahead along its
-- ground velocity, so steady circling is read while a late reversal or dodge still makes it whiff.
local function leadPoint(target: Entity): Vector3
	return target.Root.Position + flat(target.Root.AssemblyLinearVelocity) * Settings.Tracking.AimLeadSeconds
end

local function toCFrame(p: World.Placement): CFrame
	return CFrame.new(p.X, p.Y, p.Z) * CFrame.Angles(0, math.rad(p.Yaw), 0)
end

local function setMode(agent: Agent, mode: Mode, now: number)
	if agent.Mode == mode then
		return
	end
	agent.Mode = mode
	agent.ModeSince = now
	local e = Characters.GetEntity(agent.Id)
	if e then
		e.Model:SetAttribute("AsuraAIMode", mode)
	end
end

local function rebuildIgnore()
	local list: { Instance } = {}
	for _, e in Characters.Entities() do
		table.insert(list, e.Model)
	end
	rayParams.FilterDescendantsInstances = list
	ignoreDirty = false
end

local function lineOfSight(from: Vector3, to: Vector3): boolean
	if ignoreDirty then
		rebuildIgnore()
	end
	local direction = to - from
	return Workspace:Raycast(from, direction, rayParams) == nil
end

local function isTargetable(agent: Agent, e: Entity): boolean
	if e.Kind ~= "Player" or e.Fighter.State == "KO" or e.Respawning or e.Duel ~= nil then
		return false
	end
	local allowed = agent.Allowed
	return allowed == nil or allowed[e.Id] == true
end

local function noisy(e: Entity): boolean
	local state = e.Fighter.State
	return e.Fighter.Sprinting or state == "Startup" or state == "Active" or state == "Dashing"
end

local function reachOf(agent: Agent, f: Combat.Fighter): number
	local weapon = Weapons.get(f.Weapon)
	return weapon.Light[1].Reach + f.ReachBonus
end

-------------------------------------------------------------------------------------------------
-- Perception
-------------------------------------------------------------------------------------------------

-- Returns the best visible target and whether any target was only heard.
local function perceive(agent: Agent, self: Entity, now: number): (Entity?, Vector3?)
	local profile = agent.Profile
	local origin = self.Root.Position
	local look = flatUnit(self.Root.CFrame.LookVector)
	local cosHalf = math.cos(math.rad(profile.FieldOfView) * 0.5)
	local best: Entity? = nil
	local bestDistance = math.huge
	local heard: Vector3? = nil
	for _, e in Characters.Entities() do
		if isTargetable(agent, e) and e.Model.Parent then
			local offset = e.Root.Position - origin
			local distance = offset.Magnitude
			if distance <= profile.SightRange then
				local inCone = profile.FieldOfView >= 360 or distance <= CLOSE_DETECT or look:Dot(flatUnit(offset)) >= cosHalf
				if inCone and distance < bestDistance and lineOfSight(origin + LOS_HEIGHT, e.Root.Position + LOS_HEIGHT) then
					best, bestDistance = e, distance
				end
			end
			if heard == nil and distance <= profile.HearingRange and noisy(e) then
				heard = e.Root.Position
			end
		end
	end
	if heard == nil then
		for _, noise in noises do
			if now - noise.Time <= NOISE_LIFETIME and (noise.Position - origin).Magnitude <= profile.HearingRange then
				heard = noise.Position
				break
			end
		end
	end
	return best, heard
end

-------------------------------------------------------------------------------------------------
-- Combat behaviour
-------------------------------------------------------------------------------------------------

local function publishTelegraph(agent: Agent, move: Combat.MoveData, class: TelegraphClass, impactAt: number)
	local e = Characters.GetEntity(agent.Id)
	if e then
		e.Model:SetAttribute("AsuraTelegraph", string.format("%s|%s|%.3f", class, move.Id, impactAt))
	end
	if class ~= "Light" then
		Characters.Cue("Telegraph", agent.Id, { class = class, move = move.Id, impact = impactAt })
	elseif agent.Boss and e and Weapons.isBossOnly(e.Fighter.Weapon) then
		-- A boss-only weapon's light swing plays its own clip slot too (BossAnimationRules.Melee); no warning UI.
		Characters.Cue("BossSwing", agent.Id, { move = move.Id, impact = impactAt })
	end
end

local function queueAttack(agent: Agent, f: Combat.Fighter, action: "Light" | "Heavy" | "WeaponArt", now: number)
	local move = Combat.selectMove(f, action, now)
	local attackAt, _, impactAt = Telegraph.plan(move, now, PLAYER_REACTION)
	publishTelegraph(agent, move, Telegraph.classify(move), impactAt)
	if attackAt <= now + 1e-6 then
		Characters.PushIntent(agent.Id, action)
	else
		agent.Pending = { Action = action, At = attackAt }
	end
end

local function react(agent: Agent, self: Entity, target: Entity, now: number)
	local f = self.Fighter
	local tf = target.Fighter
	local profile = agent.Profile
	if now >= agent.DeflectAt then
		agent.DeflectAt = math.huge
		Characters.PushIntent(agent.Id, "Deflect")
	end
	if f.GuardHeld and now >= agent.GuardUntil then
		Characters.SetGuard(agent.Id, false)
	end
	local move = tf.Move
	if tf.State ~= "Startup" or move == nil or tf.MoveStart == agent.PlannedFor then
		return
	end
	local distance = (target.Root.Position - self.Root.Position).Magnitude
	if distance > move.Reach + tf.ReachBonus + 4 then
		return
	end
	agent.PlannedFor = tf.MoveStart
	local impact = tf.MoveStart + move.Timing.StartupSeconds
	local press = impact - f.DeflectWindow * 0.5 + agent.Rng:NextNumber(-profile.TimingJitter, profile.TimingJitter)
	local readable = press >= tf.MoveStart + profile.ReactionTime
	if move.Unblockable then
		-- Perilous: deflect only (guarding is useless); otherwise evade backwards.
		if readable and agent.Rng:NextNumber() < profile.DeflectChance then
			agent.DeflectAt = math.max(press, now)
		elseif f.Stamina > Settings.Stamina.Costs.Dash then
			local away = flatUnit(self.Root.Position - target.Root.Position)
			Characters.PushIntent(agent.Id, "Dash", nil, away.X, away.Z)
		end
		return
	end
	if readable and agent.Rng:NextNumber() < profile.DeflectChance then
		agent.DeflectAt = math.max(press, now)
	elseif agent.Rng:NextNumber() < profile.GuardChance then
		agent.GuardUntil = impact + move.Timing.ActiveSeconds + 0.1
		Characters.SetGuard(agent.Id, true)
	end
end

-- Every agent walk goes through here; a long-bodied boss bends its path round the arena pillars.
local function moveTo(agent: Agent, point: Vector3)
	local pillars = agent.Pillars
	local e = if pillars and #pillars > 0 then Characters.GetEntity(agent.Id) else nil
	if pillars and e then
		local x, z = Bodies.steer(e.Root.Position.X, e.Root.Position.Z, point.X, point.Z, pillars, agent.Clearance)
		point = Vector3.new(x, point.Y, z)
	end
	Characters.MoveTo(agent.Id, point)
end

-- Engage just inside attack reach, never on the target's own root (BossBodies.closeIn).
-- A Twin flanks: it never takes the engage point its living partner already holds (Bodies.flank).
local function closeIn(agent: Agent, self: Entity, target: Entity, reach: number)
	local at, to = self.Root.Position, target.Root.Position
	local x, z = Bodies.closeIn(at.X, at.Z, to.X, to.Z, reach * 0.6)
	local encounter = self.Model:GetAttribute("AsuraEncounter")
	for _, id in if type(encounter) == "string" then BossDuo.members(encounter) else {} do
		local partner = if id ~= agent.Id then Characters.GetEntity(id) else nil
		if partner and partner.Fighter.State ~= "KO" then
			local o = partner.Root.Position
			x, z = Bodies.flank(at.X, at.Z, to.X, to.Z, reach * 0.6, o.X, o.Z, 2.5 * (self.Model:GetScale() + partner.Model:GetScale()))
		end
	end
	moveTo(agent, Vector3.new(x, to.Y, z))
end

local function strafePoint(agent: Agent, self: Entity, target: Entity, spacing: number, now: number): Vector3
	if now >= agent.StrafeUntil then
		agent.StrafeSign = if agent.Rng:NextNumber() < 0.5 then -1 else 1
		agent.StrafeUntil = now + agent.Rng:NextNumber(1.2, 2.6)
	end
	local away = flatUnit(self.Root.Position - target.Root.Position)
	if away.Magnitude == 0 then
		away = Vector3.new(0, 0, 1)
	end
	local perpendicular = Vector3.new(-away.Z, 0, away.X) * agent.StrafeSign
	return target.Root.Position + away * spacing + perpendicular * 3
end

local function decide(agent: Agent, self: Entity, target: Entity, now: number)
	local f = self.Fighter
	local tf = target.Fighter
	local profile = agent.Profile
	local phantomUntil = target.Model:GetAttribute("PhantomUntil")
	local phantom = target.Model:GetAttribute("PhantomPosition")
	if type(phantomUntil)=="number" and now < phantomUntil and typeof(phantom)=="Vector3" then
		Characters.Face(agent.Id,phantom);moveTo(agent,phantom);return
	end
	local distance = (target.Root.Position - self.Root.Position).Magnitude
	local reach = reachOf(agent, f)

	Characters.Face(agent.Id, leadPoint(target))

	if tf.State == "StanceBroken" and distance <= Settings.Deathblow.Range then
		Characters.PushIntent(agent.Id, "Heavy")
		return
	end

	-- Posture management: back off and let the bar drain before it breaks.
	local postureRatio = f.Posture / math.max(Combat.maxPosture(f), 1)
	if postureRatio >= profile.PostureGuard and now >= agent.RecomposeUntil then
		agent.RecomposeUntil = now + agent.Rng:NextNumber(1.2, 2.0)
		if f.Stamina > Settings.Stamina.Costs.Dash then
			local away = flatUnit(self.Root.Position - target.Root.Position)
			Characters.PushIntent(agent.Id, "Dash", nil, away.X, away.Z)
		end
	end
	if now < agent.RecomposeUntil then
		moveTo(agent, strafePoint(agent, self, target, reach * 1.8, now))
		return
	end

	if distance > reach * 0.95 then
		closeIn(agent, self, target, reach)
		return
	end
	-- A Twin left on top of the player or its partner (after a lunge) steps back out to its flank
	-- point before the next swing (BossRules.crowded, post-F26 Step 4).
	local partner = if agent.Boss and f.State == "Idle" and agent.Pending == nil then BossMotion.partner(self) else nil
	if partner then
		local flatTo = flat(target.Root.Position - self.Root.Position).Magnitude
		local toPartner = flat(partner.Root.Position - self.Root.Position).Magnitude
		if BossRules.crowded(flatTo, reach * 0.6, toPartner, BossMotion.duoGap(self, partner)) then
			closeIn(agent, self, target, reach)
			return
		end
	end

	if f.Stamina < profile.RetreatStamina and agent.Rng:NextNumber() < 0.3 then
		local away = flatUnit(self.Root.Position - target.Root.Position)
		Characters.PushIntent(agent.Id, "Dash", nil, away.X, away.Z)
		return
	end
	if f.GuardHeld or agent.DeflectAt < math.huge or agent.Pending ~= nil then
		Characters.StopMoving(agent.Id)
		return
	end

	local comboOpen = Combat.comboWindowOpen(f, now)
	if f.State ~= "Idle" and not comboOpen then
		return
	end
	if comboOpen then
		if agent.Rng:NextNumber() <= profile.ComboContinueChance then
			queueAttack(agent, f, "Light", now)
		end
		return
	end
	if agent.Rng:NextNumber() < profile.StrafeChance * (1 - profile.Aggression) then
		moveTo(agent, strafePoint(agent, self, target, reach * 0.8, now))
		return
	end
	Characters.StopMoving(agent.Id)
	if agent.Rng:NextNumber() > profile.Aggression then
		return
	end
	local weapon = Weapons.get(f.Weapon)
	local roll = agent.Rng:NextNumber()
	if roll < profile.ArtChance and f.Qi >= weapon.WeaponArt.QiCost then
		queueAttack(agent, f, "WeaponArt", now)
	elseif roll < profile.ArtChance + profile.HeavyChance then
		queueAttack(agent, f, "Heavy", now)
	else
		queueAttack(agent, f, "Light", now)
	end
end

-------------------------------------------------------------------------------------------------
-- Boss multi-phase manager
-------------------------------------------------------------------------------------------------

local function scheduleShockwave(agent: Agent, wave: Shockwave, now: number, cancelable: boolean, earliest: number?)
	local _, impactAt = Telegraph.shockwave(wave, now)
	impactAt = math.max(impactAt, earliest or impactAt) -- never inside an encounter handoff
	agent.Shockwave = { At = impactAt, Wave = wave, Cancelable = cancelable }
	Characters.Cue("Telegraph", agent.Id, { class = "Perilous", move = "Shockwave", impact = impactAt, radius = wave.Radius })
	local e = Characters.GetEntity(agent.Id)
	if e then
		e.Model:SetAttribute("AsuraTelegraph", string.format("Perilous|Shockwave|%.3f", impactAt))
	end
end

local function releaseShockwave(agent: Agent, self: Entity)
	local pending = agent.Shockwave
	agent.Shockwave = nil
	if not pending then
		return
	end
	local wave = pending.Wave
	local origin = self.Root.Position
	Characters.Cue("Shockwave", agent.Id, { radius = wave.Radius, x = origin.X, y = origin.Y, z = origin.Z })
	for _, e in Characters.Entities() do
		if e.Kind == "Player" and agent.Allowed and agent.Allowed[e.Id] and e.Model.Parent and e.Root.Position.Y - 3 <= 6 and (e.Root.Position - origin).Magnitude <= wave.Radius then
			Characters.ApplyArea(agent.Id, e.Id, wave.Damage, wave.Posture, wave.Unblockable)
		end
	end
end

local function applyPhase(agent: Agent, boss: BossDef, index: number, self: Entity)
	local phase = boss.Phases[index]
	agent.Phase = index
	agent.Profile = phase.AI
	agent.Deathblows = 0
	Characters.ForceWeapon(agent.Id, phase.Weapon)
	Characters.ApplyStats(agent.Id, phase.Stats, false)
	local f = self.Fighter
	f.Posture = 0
	f.KOProtected = index < #boss.Phases
	if phase.Transition then
		Characters.Tint(agent.Id, phase.Transition.BodyColor)
	end
	BossAppearance.phase(self.Model, phase.AnimationSet, index)
	self.Model:SetAttribute("AsuraBossPhases", #boss.Phases)
	self.Model:SetAttribute("AsuraBossPhase", index)
	self.Model:SetAttribute("AsuraBossPhaseName", phase.Name)
end

local function beginTransition(agent: Agent, boss: BossDef, index: number, self: Entity, now: number)
	local phase = boss.Phases[index]
	local transition = phase.Transition
	BossTactics.reset(agent.Id)
	agent.Pending = nil
	agent.DeflectAt = math.huge
	if not transition then
		applyPhase(agent, boss, index, self)
		return
	end
	setMode(agent, "Cinematic", now)
	Characters.Cinematic(agent.Id, transition.Duration)
	-- The metamorphosis takes the camera: participants are locked and protected for the shot, and
	-- the unblockable wave lands no sooner than BossHandoff.Lead after control returns.
	local participants: { number } = {}
	local allowed: { [number]: boolean } = agent.Allowed or {}
	for id in allowed do table.insert(participants, id) end
	local window = Handoff.begin(boss.Id, "Phase", participants)
	Characters.Cue("BossPhase", agent.Id, { boss = boss.Id, phase = index, name = phase.Name, duration = transition.Duration,
		shot = HandoffRules.shot("Phase"), participants = participants })
	scheduleShockwave(agent, transition.Shockwave, now, false, HandoffRules.earliest(window))
	BossAppearance.phase(self.Model, phase.AnimationSet, index) -- the body changes under the camera; the moveset at the end
	agent.TransitionEnd = now + transition.Duration
	agent.Phase = index
end

local function finishTransition(agent: Agent, boss: BossDef, self: Entity, now: number)
	applyPhase(agent, boss, agent.Phase, self)
	agent.TransitionEnd = math.huge
	local special = boss.Phases[agent.Phase].Special
	agent.NextSpecial = if special then now + agent.Rng:NextNumber(special.IntervalMin, special.IntervalMax) else math.huge
	setMode(agent, "Combat", now)
end

local function updateBoss(agent: Agent, boss: BossDef, self: Entity, now: number): boolean
	local f = self.Fighter
	if agent.TransitionEnd < math.huge then
		if agent.Shockwave and now >= agent.Shockwave.At then
			releaseShockwave(agent, self)
		end
		if now >= agent.TransitionEnd then
			finishTransition(agent, boss, self, now)
		end
		return true
	end
	if f.State ~= "DeathblowVictim" and f.State ~= "KO" then
		local fraction = f.ActiveHP / math.max(f.MaxHP, 1)
		local nextPhase = World.phaseFor(boss, agent.Phase, fraction, agent.Deathblows)
		if nextPhase > agent.Phase then
			beginTransition(agent, boss, nextPhase, self, now)
			return true
		end
	end
	local pending = agent.Shockwave
	if pending then
		if pending.Cancelable and (Schema.isStunned(f.State) or f.State == "KO") then
			agent.Shockwave = nil
		elseif now >= pending.At then
			releaseShockwave(agent, self)
		end
		return pending ~= nil and agent.Shockwave ~= nil
	end
	if now < agent.HoldUntil then
		agent.Pending = nil
		Characters.StopMoving(agent.Id)
		return true
	end
	if BossTactics.step(agent.Id, boss, agent.Phase, agent.Target, agent.Allowed, now) then
		agent.Pending = nil
		return true
	end
	local special = boss.Phases[agent.Phase].Special
	if special and now >= agent.NextSpecial and f.State == "Idle" and agent.Mode == "Combat" then
		agent.NextSpecial = now + agent.Rng:NextNumber(special.IntervalMin, special.IntervalMax)
		Characters.StopMoving(agent.Id)
		scheduleShockwave(agent, special.Shockwave, now, true)
		return true
	end
	return false
end

-------------------------------------------------------------------------------------------------
-- Agent loop
-------------------------------------------------------------------------------------------------

local function update(agent: Agent, now: number)
	local self = Characters.GetEntity(agent.Id)
	if not self then
		return
	end
	local f = self.Fighter
	if f.State == "KO" then
		setMode(agent, "Dead", now)
		return
	end

	local boss = agent.Boss
	if boss and updateBoss(agent, boss, self, now) then
		return
	end

	if f.State == "StanceBroken" or f.State == "DeathblowVictim" then
		if agent.Mode ~= "StanceBroken" then
			agent.Pending = nil
			agent.DeflectAt = math.huge
			setMode(agent, "StanceBroken", now)
		end
		return
	elseif agent.Mode == "StanceBroken" then
		setMode(agent, "Combat", now)
	end

	local pending = agent.Pending
	if pending and now >= pending.At then
		agent.Pending = nil
		Characters.PushIntent(agent.Id, pending.Action)
	end

	local target = if agent.Target ~= 0 then Characters.GetEntity(agent.Target) else nil
	if target and not isTargetable(agent, target) then
		target = nil
		agent.Target = 0
	end
	if target and (agent.Mode == "Combat" or agent.Mode == "Engage") then
		react(agent, self, target, now)
	end

	if now < agent.NextThink then
		return
	end
	local profile = agent.Profile
	agent.NextThink = now + 1 / profile.ThinkRate

	local homeDistance = (self.Root.Position - agent.Home.Position).Magnitude
	-- Zone leash: a foe whose target leaves its zone (walls, the safe landing, the far bridgehead)
	-- breaks off instead of chasing; the distance leash still applies inside it.
	local zone = agent.Zone
	local fled = false
	if zone and agent.Target ~= 0 then
		local foe = Characters.GetEntity(agent.Target)
		fled = foe ~= nil and not Zones.contains(zone, foe.Root.Position.X, foe.Root.Position.Z, Zones.Grace)
	end
	if agent.Mode ~= "Return" and (homeDistance > profile.LeashRange or fled) then
		agent.Target = 0
		Characters.SetGuard(agent.Id, false)
		Characters.SetSprint(agent.Id, false)
		setMode(agent, "Return", now)
	end

	if agent.Mode == "Return" then
		moveTo(agent, agent.Home.Position)
		if homeDistance <= 4 then
			Characters.RestoreFighter(agent.Id)
			setMode(agent, if #agent.Patrol > 0 then "Patrol" else "Idle", now)
		end
		return
	end

	local seen, heard = perceive(agent, self, now)
	if seen and zone and not Zones.contains(zone, seen.Root.Position.X, seen.Root.Position.Z, Zones.Grace) then
		seen = nil -- noticed from beyond the zone: not worth leaving it for
	end
	if seen then
		agent.LastSeen = now
		agent.LastKnown = seen.Root.Position
	end

	if agent.Mode == "Idle" or agent.Mode == "Patrol" then
		if seen then
			agent.Target = seen.Id
			local close = (seen.Root.Position - self.Root.Position).Magnitude <= CLOSE_DETECT
			agent.Suspicion = if close then 1 else 0
			setMode(agent, if close then "Engage" else "Alert", now)
		elseif heard then
			agent.LastKnown = heard
			agent.Suspicion = 0
			setMode(agent, "Alert", now)
		elseif agent.Mode == "Idle" and #agent.Patrol > 0 and now - agent.ModeSince > agent.Rng:NextNumber(1, 3) then
			setMode(agent, "Patrol", now)
		elseif agent.Mode == "Patrol" then
			local point = agent.Patrol[agent.PatrolIndex]
			if (flat(self.Root.Position - point)).Magnitude <= 2.5 then
				agent.PatrolIndex = agent.PatrolIndex % #agent.Patrol + 1
				setMode(agent, "Idle", now)
				Characters.StopMoving(agent.Id)
			else
				moveTo(agent, point)
			end
		end
		return
	end

	if agent.Mode == "Alert" then
		local known = agent.LastKnown
		if known then
			Characters.Face(agent.Id, known)
		end
		if seen then
			agent.Target = seen.Id
			agent.Suspicion += (1 / profile.ThinkRate) / math.max(profile.AlertTime, 0.05)
			if agent.Suspicion >= 1 then
				setMode(agent, "Engage", now)
			end
		elseif known then
			agent.Suspicion += (0.5 / profile.ThinkRate) / math.max(profile.AlertTime, 0.05)
			moveTo(agent, known)
		end
		if not seen and now - math.max(agent.LastSeen, agent.ModeSince) > profile.SearchTime then
			setMode(agent, "Return", now)
		end
		return
	end

	if not target then
		target = seen
		agent.Target = if seen then seen.Id else 0
	end
	if not target then
		if now - agent.LastSeen > profile.SearchTime then
			Characters.SetSprint(agent.Id, false)
			setMode(agent, "Return", now)
		elseif agent.LastKnown then
			moveTo(agent, agent.LastKnown :: Vector3)
		end
		return
	end

	local distance = (target.Root.Position - self.Root.Position).Magnitude
	local reach = reachOf(agent, f)
	if agent.Mode == "Engage" then
		Characters.Face(agent.Id, target.Root.Position)
		closeIn(agent, self, target, reach)
		Characters.SetSprint(agent.Id, distance > reach * 3 and f.Stamina > profile.RetreatStamina * 2)
		if distance <= reach * 1.1 then
			Characters.SetSprint(agent.Id, false)
			setMode(agent, "Combat", now)
		end
		return
	end

	if agent.Mode == "Combat" then
		if distance > reach * 1.8 then
			setMode(agent, "Engage", now)
			return
		end
		decide(agent, self, target, now)
	end
end

local function newAgent(entityId: number, kind: "Mob" | "Boss", definition: string, profile: AIProfile, region: string, essence: number, home: CFrame, patrol: { Vector3 }): Agent
	local agent: Agent = {
		Id = entityId,
		Kind = kind,
		Definition = definition,
		SpawnId = nil,
		Region = region,
		Essence = essence,
		Home = home,
		Patrol = patrol,
		PatrolIndex = 1,
		Profile = profile,
		Rng = Random.new(math.abs(entityId) * 7919 + os.time()),
		Mode = if #patrol > 0 then "Patrol" else "Idle",
		ModeSince = Characters.Now(),
		Target = 0,
		LastSeen = -math.huge,
		LastKnown = nil,
		Suspicion = 0,
		NextThink = Characters.Now(),
		PlannedFor = -math.huge,
		DeflectAt = math.huge,
		GuardUntil = -math.huge,
		RecomposeUntil = -math.huge,
		Pending = nil,
		StrafeSign = 1,
		StrafeUntil = -math.huge,
		Boss = nil,
		Phase = 1,
		Deathblows = 0,
		Allowed = nil,
		Shockwave = nil,
		TransitionEnd = math.huge,
		NextSpecial = math.huge,
		HoldUntil = -math.huge,
		Pillars = nil,
		Clearance = 0,
		Zone = nil,
	}
	agents[entityId] = agent
	return agent
end

-------------------------------------------------------------------------------------------------
-- Spawning
-------------------------------------------------------------------------------------------------

function AIService.SpawnMob(spawnId: string): number?
	local existing = spawnAgents[spawnId]
	if existing and agents[existing] and Characters.GetEntity(existing) then
		return existing
	end
	local entry = World.spawnById(spawnId)
	if not entry then
		warn("[AIService] Unknown spawn " .. spawnId)
		return nil
	end
	local mob = World.Mobs[entry.Mob]
	local home = toCFrame(entry.Placement)
	local id = Characters.SpawnEnemy({
		Name = mob.Name,
		Weapon = mob.Weapon,
		CFrame = home,
		Stats = mob.Stats,
		Definition = mob.Id,
		BodyColor = mob.BodyColor,
	})
	if not id then
		return nil
	end
	local patrol: { Vector3 } = {}
	for _, point in entry.Patrol do
		table.insert(patrol, Vector3.new(point.X, point.Y, point.Z))
	end
	local agent = newAgent(id, "Mob", mob.Id, mob.AI, entry.Region, mob.Essence, home, patrol)
	agent.SpawnId = spawnId
	local zoneId = Zones.Spawns[spawnId]
	-- Campaign regions (batches 17-21) leash their foes the same way, to their layout zone.
	agent.Zone = if zoneId then Zones.get(zoneId) else Campaign.zoneForSpawn(spawnId) :: any
	spawnAgents[spawnId] = id
	return id
end

function AIService.ResetMob(spawnId: string): boolean
	local id = spawnAgents[spawnId]
	local agent = if id then agents[id] else nil
	if not id or not agent or not Characters.GetEntity(id) then
		return false
	end
	Characters.SetGuard(id, false)
	Characters.Teleport(id, agent.Home)
	Characters.RestoreFighter(id)
	agent.Target = 0
	agent.Pending = nil
	agent.DeflectAt = math.huge
	agent.PatrolIndex = 1
	setMode(agent, if #agent.Patrol > 0 then "Patrol" else "Idle", Characters.Now())
	return true
end

-- Respawns every non-boss mob in a region. Engaged mobs can be left alone so another player's
-- fight is not reset underneath them.
function AIService.RespawnRegion(region: string, skipEngaged: boolean)
	for _, entry in World.Spawns do
		if entry.Region == region then
			local id = spawnAgents[entry.Id]
			local agent = if id then agents[id] else nil
			local entity = if id then Characters.GetEntity(id) else nil
			if agent and entity and entity.Fighter.State ~= "KO" then
				local engaged = agent.Mode == "Engage" or agent.Mode == "Combat" or agent.Mode == "StanceBroken"
				if not (skipEngaged and engaged) then
					AIService.ResetMob(entry.Id)
				end
			else
				if id and entity then
					Characters.DespawnEnemy(id)
				end
				spawnAgents[entry.Id] = nil
				AIService.SpawnMob(entry.Id)
			end
		end
	end
end

function AIService.SpawnBoss(bossId: string, participants: { number }?): number?
	local existing = bossAgents[bossId]
	if existing then
		local living = BossDuo.alive(bossId)
		if living then return living end
		AIService.DespawnBoss(bossId)
	end
	local boss = World.Bosses[bossId]
	if not boss then
		warn("[AIService] Unknown boss " .. bossId)
		return nil
	end
	local opening = boss.Phases[1]
	local home = toCFrame(boss.Spawn)
	local id = Characters.SpawnEnemy({
		Name = boss.Name,
		Weapon = opening.Weapon,
		CFrame = home,
		Stats = opening.Stats,
		Definition = boss.Id,
		BodyColor = boss.BodyColor,
		Boss = true,
	})
	if not id then
		return nil
	end
	local agent = newAgent(id, "Boss", boss.Id, opening.AI, boss.Region, boss.Essence, home, {})
	agent.Boss = boss
	agent.Mode = "Engage"
	agent.Pillars = Bodies.pillars(boss)
	local hull = (Bodies.Hulls :: any)[boss.Archetype]
	agent.Clearance = if hull then hull[3] * 0.5 * (boss.Scale or 1) + 0.5 else 0

	local entity = Characters.GetEntity(id)
	if entity then
		applyPhase(agent, boss, 1, entity)
		entity.Model:SetAttribute("AsuraBossTitle", boss.Title)
		entity.Model:SetAttribute("AsuraEncounter", boss.Id)
		BossAppearance.apply(entity.Model, boss.Archetype, boss.Scale)
	end
	bossAgents[bossId] = id
	local members = { id }
	local partner = boss.Partner
	if partner then
		local partnerId = Characters.SpawnEnemy({ Name = partner.Name, Weapon = partner.Weapon, CFrame = home * CFrame.new(16, 0, 0),
			Stats = partner.Stats, Definition = boss.Id, BodyColor = { 100, 88, 68 }, Boss = true })
		if not partnerId then
			agents[id] = nil; bossAgents[bossId] = nil; Characters.DespawnEnemy(id)
			return nil
		end
		local partnerBoss = table.clone(boss)
		local partnerPhase = table.clone(opening)
		partnerPhase.Weapon, partnerPhase.Stats, partnerPhase.Attacks = partner.Weapon, partner.Stats, partner.Attacks
		partnerPhase.AI = table.clone(opening.AI)
		partnerPhase.AI.Aggression, partnerPhase.AI.GuardChance, partnerPhase.AI.DeflectChance = 0.5, 0.95, 0.05
		partnerPhase.AttackInterval = 4
		partnerBoss.Phases, partnerBoss.Partner = { partnerPhase }, nil
		local ally = newAgent(partnerId, "Boss", boss.Id, partnerPhase.AI, boss.Region, 0, home * CFrame.new(16, 0, 0), {})
		ally.Boss, ally.Mode = partnerBoss, "Engage"
		local partnerEntity = Characters.GetEntity(partnerId)
		if partnerEntity then
			applyPhase(ally, partnerBoss, 1, partnerEntity)
			partnerEntity.Model:SetAttribute("AsuraEncounter", boss.Id)
			BossAppearance.apply(partnerEntity.Model, "IronBull", partner.Scale)
		end
		table.insert(members, partnerId)
	end
	BossDuo.register(boss, members)
	if participants then AIService.SetBossTargets(bossId, participants) end
	-- Entry handoff: everyone locked and protected through the framing shot and the camera's return.
	local shot = if participants and #participants > 0 then HandoffRules.shot("Intro") else nil
	if participants and shot then Handoff.begin(boss.Id, "Intro", participants, members) end
	Characters.Cue("BossIntro", id, { boss = boss.Id, title = boss.Title, phase = 1, name = opening.Name, members = members, participants = participants, shot = shot })
	return id
end

-- Holds a boss's actors still until `untilTime` (+ half the readable lead) and keeps their first
-- scheduled attack after it; EncounterHandoff calls this through SetHolder.
function AIService.Hold(bossId: string, untilTime: number)
	for _, id in BossDuo.members(bossId) do
		local agent = agents[id]
		if agent then
			agent.HoldUntil = untilTime + HandoffRules.Lead * 0.5
			BossTactics.hold(id, untilTime)
		end
	end
end
Handoff.SetHolder(AIService.Hold)

function AIService.SetBossTargets(bossId: string, participants: { number })
	for _, id in BossDuo.members(bossId) do
		local agent = agents[id]
		if not agent then continue end
		local allowed: { [number]: boolean } = {}
		for _, participant in participants do allowed[participant] = true end
		agent.Allowed = allowed
		if agent.Target ~= 0 and not allowed[agent.Target] then agent.Target = 0 end
	end
end

function AIService.DespawnBoss(bossId: string)
	local members = table.clone(BossDuo.members(bossId))
	Handoff.forget(bossId)
	BossDuo.forget(bossId)
	bossAgents[bossId] = nil
	for _, id in members do agents[id] = nil; Characters.DespawnEnemy(id) end
end

function AIService.GetBossEntity(bossId: string): number?
	return BossDuo.alive(bossId)
end

function AIService.GetAgent(entityId: number): AgentInfo?
	local agent = agents[entityId]
	if not agent then
		return nil
	end
	return { Kind = agent.Kind, Definition = agent.Definition, SpawnId = agent.SpawnId, Region = agent.Region, Essence = agent.Essence }
end

function AIService.GetMode(entityId: number): Mode?
	local agent = agents[entityId]
	return if agent then agent.Mode else nil
end

-- True while any agent is actively fighting or chasing this player (blocks resting at an altar).
function AIService.IsHunting(playerId: number): boolean
	for _, agent in agents do
		if agent.Target == playerId and (agent.Mode == "Engage" or agent.Mode == "Combat" or agent.Mode == "Cinematic") then
			return true
		end
	end
	return false
end

function AIService.OnBossDefeated(listener: (bossId: string, entityId: number) -> ()): () -> ()
	table.insert(bossListeners, listener)
	return function()
		local index = table.find(bossListeners, listener)
		if index then
			table.remove(bossListeners, index)
		end
	end
end

-------------------------------------------------------------------------------------------------
-- Lifecycle
-------------------------------------------------------------------------------------------------

local function onEvent(event: Combat.Event, point: Vector3?)
	if point and (event.Kind == "Hit" or event.Kind == "DeflectSpark" or event.Kind == "Block" or event.Kind == "CounterHit" or event.Kind == "GuardBreak") then
		table.insert(noises, { Position = point, Time = Characters.Now() })
		if #noises > 32 then
			table.remove(noises, 1)
		end
	end
	local victim = agents[event.Target]
	if not victim then
		return
	end
	if event.Kind == "Deathblow" and victim.Boss then
		victim.Deathblows += 1
		local e = Characters.GetEntity(victim.Id)
		local final = e ~= nil and e.Fighter.PendingKO
		for _, member in BossDuo.members(victim.Boss.Id) do
			local other = Characters.GetEntity(member)
			if member ~= victim.Id and other and other.Fighter.State ~= "KO" then final = false end
		end
		if final then Characters.Cue("BossFinish", victim.Id, { boss = victim.Boss.Id }) end
	elseif (event.Kind == "Hit" or event.Kind == "CounterHit") and victim.Mode ~= "Combat" and victim.Mode ~= "Cinematic" then
		local source = Characters.GetEntity(event.Source)
		if source and isTargetable(victim, source) then
			victim.Target = source.Id
			victim.LastSeen = Characters.Now()
			victim.LastKnown = source.Root.Position
			setMode(victim, "Engage", Characters.Now())
		end
	elseif event.Kind == "KO" then
		setMode(victim, "Dead", Characters.Now())
		local boss = victim.Boss
		local won, oath = false, nil
		if boss then won, oath = BossDuo.onKO(boss.Id, victim.Id) end
		if boss and oath then
			local participants: { number } = {}
			local allowed: { [number]: boolean } = victim.Allowed or {}
			for id in allowed do table.insert(participants, id) end
			Handoff.begin(boss.Id, "Enrage", participants)
		end
		if boss and won then

			for _, listener in table.clone(bossListeners) do
				local ok, problem = pcall(listener, boss.Id, victim.Id)
				if not ok then
					warn("[AIService] Boss listener failed: " .. tostring(problem))
				end
			end
		end
	end
end

local function onRemoved(id: number, _kind: Characters.EntityKind)
	ignoreDirty = true
	local agent = agents[id]
	if not agent then
		return
	end
	BossTactics.reset(id)
	agents[id] = nil
	if agent.SpawnId and spawnAgents[agent.SpawnId] == id then
		spawnAgents[agent.SpawnId] = nil
	end
	local boss = agent.Boss
	if boss and bossAgents[boss.Id] == id then
		bossAgents[boss.Id] = BossDuo.alive(boss.Id)
	end
end

local function onAdded(id: number, kind: Characters.EntityKind)
	ignoreDirty = true
	if kind ~= "Enemy" or agents[id] then
		return
	end
	-- Hand-placed tagged models carry a Definition attribute naming a mob archetype.
	task.defer(function()
		if agents[id] then
			return
		end
		local e = Characters.GetEntity(id)
		if not e then
			return
		end
		local definition = e.Definition
		local mob = if definition then World.Mobs[definition] else nil
		if not mob then
			return
		end
		Characters.ApplyStats(id, mob.Stats, true)
		local position = e.Root.Position
		local region = World.regionAt(position.X, position.Y, position.Z) or "DesecratedMonastery"
		newAgent(id, "Mob", mob.Id, mob.AI, region, mob.Essence, e.Root.CFrame, {})
	end)
end

function AIService.Start()
	assert(not running, "AIService already started")
	running = true
	table.insert(disconnectors, Characters.OnStep(function(now: number, _dt: number)
		for i = #noises, 1, -1 do
			if now - noises[i].Time > NOISE_LIFETIME then
				table.remove(noises, i)
			end
		end
		for _, agent in agents do
			update(agent, now)
		end
	end))
	table.insert(disconnectors, Characters.Subscribe(onEvent))
	table.insert(disconnectors, Characters.OnEntityRemoved(onRemoved))
	table.insert(disconnectors, Characters.OnEntityAdded(onAdded))
end

function AIService.Destroy()
	for bossId in table.clone(bossAgents) do AIService.DespawnBoss(bossId) end
	running = false
	for _, disconnect in disconnectors do
		disconnect()
	end
	table.clear(disconnectors)
	for id in agents do
		Characters.DespawnEnemy(id)
	end
	table.clear(agents)
	table.clear(spawnAgents)
	table.clear(bossAgents)
	table.clear(noises)
end

return AIService
