--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/BossAnimationRules
-- The boss animation contract (F10): one resolver for every boss actor, phase and attack. A slot
-- key is "<LookKey>_P<phase>_<Action>" where Action is Idle, Strike (ordinary weapon moves),
-- Transform (phase change / Twins' oath) or a BossAttackCatalog move id. Each request walks
--   <Look>_P<n>_<Action>, <Look>_<Action>, then (attacks only) <Look>_P<n>_Strike, <Look>_Strike
-- and at each key takes, in order: the actor's AsuraBossAnimation_<key> attribute (copied by
-- BossAppearance from ServerStorage.AsuraAssets.AsuraBossAnimations, so it survives phase changes
-- and retries), then an authored id in `Custom` below (Shen's four legacy AnimationCatalog slots
-- count too). A Twin under the oath (AsuraBossEnraged) first tries <Look>_P<n>_Oath_<Action> and
-- <Look>_Oath_<Action>. With nothing authored a humanoid plays the stock stand-in for the move's kind and a
-- creature keeps its procedural CreatureMotion pose. Animation is cosmetic only: no gameplay
-- reads tracks or markers; damage stays on the server's impact times.
local hasScript = pcall(function() return script.Parent end)
local Catalog: any, Attacks: any
if hasScript then
	Catalog, Attacks = require(script.Parent.AnimationCatalog), require(script.Parent.BossAttackCatalog)
else
	Catalog, Attacks = require("./AnimationCatalog"), require("./BossAttackCatalog")
end

local Rules = {}

export type Source = "Override" | "Custom" | "Stock" | "Procedural" | "None"
export type Resolved = { Key: string, Id: string?, Source: Source, Speed: number, Looped: boolean, Priority: string }

-- Paste published ids here ("rbxassetid://<digits>") under the slot key, e.g.
-- ["SovereignWu_P1_SoulSpears"] = "rbxassetid://1234567890". Empty means nothing is authored yet.
Rules.Custom = table.freeze({} :: { [string]: string })

-- Move lists per look and phase (the Twins' survivor also borrows the partner's on the oath).
Rules.Moves = table.freeze({
	GrandmasterShen = { "Shen", "Chimera" }, GeneralZhao = { "Zhao" }, IronBull = { "Bull" },
	VenerableBaize = { "Baize", "Baize" }, SlumberingTitan = { "Titan", "Titan" },
	SovereignWu = { "Wu", "Wu" }, AzureWyrm = { "Wyrm", "Wyrm" },
} :: { [string]: { string } })
Rules.Oath = table.freeze({ GeneralZhao = true, IronBull = true } :: { [string]: boolean })
-- On the oath the survivor also fights with the fallen partner's set (BossDuo: Tactics.enrage).
Rules.OathMoves = table.freeze({ GeneralZhao = "Bull", IronBull = "Zhao" } :: { [string]: string })
-- Melee sets whose every swing is its own clip slot: the Bull's boss-only maul and shield (post-F26
-- step 6, D1) and Zhao's shared Guandao (phase 1 animation package). Ids are WeaponSchema moves;
-- AIService cues each light swing of a look listed here as "BossSwing".
Rules.Melee = table.freeze({
	IronBull = table.freeze({ "IronBullMaul_L1", "IronBullMaul_L2", "IronBullMaul_L3", "IronBullMaul_Heavy", "IronBullMaul_Running", "IronBullMaul_Art" }),
	GeneralZhao = table.freeze({ "Guandao_L1", "Guandao_L2", "Guandao_L3", "Guandao_Heavy", "Guandao_Running", "Guandao_Art" }),
	GrandmasterShen = table.freeze({ "Guandao_L1", "Guandao_L2", "Guandao_L3", "Guandao_Heavy", "Guandao_Running", "Guandao_Art" }),
} :: { [string]: { string } })

-- Contact times (seconds into the authored clip, at speed 1) per look and action, from the clip
-- manifest (assets/animations/general_zhao/manifest.json; the Oath_ variants share them). The client
-- phase-locks an authored attack so a contact lands on the server's impact time; markers and contacts
-- never decide damage.
Rules.Contacts = table.freeze({
	GeneralZhao = table.freeze({
		Strike = { 0.5 }, LightningSpear = { 0.8, 1.5, 2.2 }, ThunderQuickstep = { 1.0 }, IronCharge = { 1.5 }, ColossalHammer = { 1.8 },
		Guandao_L1 = { 0.15 }, Guandao_L2 = { 0.15 }, Guandao_L3 = { 0.183 }, Guandao_Heavy = { 0.383 }, Guandao_Running = { 0.217 },
		Guandao_Art = { 0.317 },
	}),
	IronBull = table.freeze({ -- assets/animations/opening_cast/bull/manifest.json: each contact is the move's first active frame
		Strike = { 0.5 }, LightningSpear = { 0.8, 1.5, 2.2 }, ThunderQuickstep = { 1.0 }, IronCharge = { 1.5 }, ColossalHammer = { 1.8 },
		IronBullMaul_L1 = { 0.217 }, IronBullMaul_L2 = { 0.167 }, IronBullMaul_L3 = { 0.317 }, IronBullMaul_Heavy = { 0.517 }, IronBullMaul_Running = { 0.283 },
		IronBullMaul_Art = { 0.433 },
	}),
	GrandmasterShen = table.freeze({ -- assets/animations/opening_cast/shen/manifest.json (both phases share the times)
		Strike = { 0.5 }, FlowingJian = { 0.8, 1.45, 2.1, 2.75 }, PrayerBeads = { 1.1 }, AbbotSweep = { 1.0 }, HesitantMoon = { 1.3 }, WheelOfHeaven = { 1.35, 1.73 },
		BloodWave = { 1.1 }, GuandaoSkyfall = { 1.5 }, CrimsonEmbrace = { 1.2 }, RendingArc = { 0.9, 1.32, 1.95 }, PhantomDrift = { 1.0 },
		Feint = { 0.52 }, Flourish = { 0.6 },
		Guandao_L1 = { 0.15 }, Guandao_L2 = { 0.15 }, Guandao_L3 = { 0.183 }, Guandao_Heavy = { 0.383 }, Guandao_Running = { 0.217 },
		Guandao_Art = { 0.317 },
	}),
} :: { [string]: { [string]: { number } } })
-- (2026-11-06) Seconds from a boss light swing's cue (BossSwing: the clip's first frame) to its impact, for looks whose lights must be readable.
-- Measured: Shen's lights land 0.15 s after the cue (Guandao startup 12 frames / tempo 1.4), under a player's ~0.25 s reaction, so the cut
-- landed before it could be read. The AI delays the swing's start (Telegraph.plan) so impact is at least this long after the cue; the client
-- plays the windup at its slowest sync rate to meet it. Move ids, frame data, contacts and parry windows are unchanged.
Rules.LightLead = table.freeze({ GrandmasterShen = 0.25 } :: { [string]: number })
-- How far a track may be sped up or slowed to make its contact; beyond that it holds or skips ahead.
Rules.SyncSpeed = table.freeze({ Min = 0.6, Max = 1.6 })

-- Server states that cancel an attack (BossAttackService.step) and the clip that answers each. A
-- reaction has no Strike or stock stand-in: unauthored, it resolves to nothing and the actor idles.
-- From which side a blow came, in his own frame (x: his right, z: forward; unit), picks the flinch. Pure.
function Rules.hitAction(x: number, z: number): string
	if math.abs(x) > math.abs(z) then return if x > 0 then "HitLightRight" else "HitLightLeft" end
	return if z > 0 then "HitLightFront" else "HitLightBack"
end
Rules.Reactions = table.freeze({ StanceBroken = "PostureBreak", GuardBroken = "PostureBreak", Hitstun = "HitLightFront",
	DeathblowVictim = "DeathblowVictim", KO = "Death" } :: { [string]: string })
local REACTION: { [string]: boolean } = {}
for _, action in Rules.Reactions do REACTION[action] = true end
REACTION.HitLightBack, REACTION.HitLightLeft, REACTION.HitLightRight = true, true, true

-- The gait layer (Movement priority, below every attack): what the body does while the server slides his root. Rates are the clip's own planted-foot
-- speed in rig studs per second at playback 1; a walking actor plays at speed / (rate x scale), so feet stay on the ground at any AI speed. Blocking replaces
-- the gait because the guard pose owns the same joints. A look listed here without an authored clip simply has no layer: nothing stands in for it.
Rules.Locomotion = table.freeze({
	IronBull = table.freeze({ WalkForward = 1.65, RunForward = 5.25, WalkBackward = 1.25, StrafeLeft = 1.33, StrafeRight = 1.33 }),
	GeneralZhao = table.freeze({ WalkForward = 2.2, RunForward = 8.0, WalkBackward = 1.9, StrafeLeft = 2.0, StrafeRight = 2.0 }),
	GrandmasterShen = table.freeze({ WalkForward = 1.98, RunForward = 6.11, WalkBackward = 1.48, StrafeLeft = 1.54, StrafeRight = 1.54 }),
	-- a form whose stride differs from the look's first: Rules.gait reads this key for that phase
	GrandmasterShen_P2 = table.freeze({ WalkForward = 2.40, RunForward = 7.48, WalkBackward = 1.80, StrafeLeft = 1.95, StrafeRight = 1.95 }),
} :: { [string]: { [string]: number } })
-- Looks whose Transform continues in the new form when the server reveals it mid-transition (Transition.Reveal): the swap resumes the
-- new phase's Transform from its handoff pose, not its idle.
Rules.RevealContinues = table.freeze({ GrandmasterShen = true } :: { [string]: boolean })
Rules.GaitRate = table.freeze({ Min = 0.45, Max = 1.9, Stand = 0.7, StandGrace = 0.35 })
local GAIT: { [string]: boolean } = { TurnLeft = true, TurnRight = true, WalkForward = true, RunForward = true, WalkBackward = true, StrafeLeft = true, StrafeRight = true, GuardLoop = true, GuardHit = true }

-- Which gait action a moving or guarding actor plays, and at what rate. speed: planted root speed in studs/s; forward, right: components of the travel
-- direction along his facing (unit); current: the action now playing, for hysteresis. Pure.
function Rules.gait(look: string, speed: number, scale: number, forward: number, right: number, state: string?, current: string?, phase: number?): (string?, number)
	if state == "Blockstun" or state == "Deflecting" then return "GuardHit", 1 end
	if state == "Blocking" then return "GuardLoop", 1 end
	local rates = (phase and Rules.Locomotion[look .. "_P" .. phase]) or Rules.Locomotion[look]
	if not rates then return nil, 1 end
	local moving = current ~= nil and current ~= "GuardLoop" and current ~= "GuardHit"
	if speed < (if moving then Rules.GaitRate.Stand - Rules.GaitRate.StandGrace else Rules.GaitRate.Stand) then return nil, 1 end
	local walk = rates.WalkForward * scale
	local action: string
	if math.abs(right) > math.abs(forward) * 1.2 then
		action = if right > 0 then "StrafeRight" else "StrafeLeft"
	elseif forward < 0 then
		action = "WalkBackward"
	else
		local running = speed > walk * (if current == "RunForward" then 1.35 else 1.6)
		action = if running then "RunForward" else "WalkForward"
	end
	return action, math.clamp(speed / (rates[action] * scale), Rules.GaitRate.Min, Rules.GaitRate.Max)
end

-- Turning on the spot: a look with turn clips steps round instead of pivoting on planted feet. yawRate: radians per second, + to his left. The server turns him at this rate (BossSkin: AsuraTurnRate).
Rules.TurnRate = 220
Rules.Turns = table.freeze({ GrandmasterShen = true } :: { [string]: boolean })
function Rules.turning(look: string, yawRate: number, current: string?): (string?, number)
	if not Rules.Turns[look] then return nil, 1 end
	local deg = math.deg(yawRate)
	local start = if current == "TurnLeft" or current == "TurnRight" then 18 else 40 -- it keeps stepping through a small tail of the turn, and does not start for a twitch
	if math.abs(deg) < start then return nil, 1 end
	return if deg > 0 then "TurnLeft" else "TurnRight", math.clamp(math.abs(deg) / Rules.TurnRate, 0.6, 1.4)
end

-- An actor with an authored Death clip (AsuraAuthoredDeath) stays on its feet for the clip instead of being folded by EnemyDissolve;
-- it burns away from this many seconds after the fall, so the fade ends before Settings.Respawn.EnemyCorpseTime removes the body.
Rules.DeathFadeAt = 2.6

-- Shen's original catalog slots (and their AsuraBossAnimation_<legacy> attributes) still count.
local LEGACY: { [string]: { Slot: string, Speed: number } } = {
	GrandmasterShen_P1_Idle = { Slot = "Shen_Phase1_Idle", Speed = 1 },
	GrandmasterShen_P2_Idle = { Slot = "Shen_Phase1_Idle", Speed = 1.4 },
	GrandmasterShen_P1_Strike = { Slot = "Shen_Phase1_SwordCombo", Speed = 1 },
	GrandmasterShen_P2_Strike = { Slot = "Shen_Phase2_GlaiveCombo", Speed = 1 },
	GrandmasterShen_P2_Transform = { Slot = "Shen_Phase2_Transform", Speed = 1 },
}

-- Stock stand-in per action/kind: { stock slot in AnimationCatalog.Enemies style, speed }.
local STOCK: { [string]: { string | number } } = {
	Idle = { "ToolHold", 1 }, Transform = { "Cheer", 0.6 }, Strike = { "ToolSlash", 1.25 },
	PerilousThrust = { "ToolLunge", 1.1 }, PerilousCut = { "ToolSlash", 1 }, PerilousGrab = { "ToolLunge", 0.9 }, ShieldCharge = { "ToolLunge", 1 },
	PerilousSweep = { "ToolSlash", 1 }, Tail = { "ToolSlash", 0.9 }, Shockwave = { "ToolSlash", 0.8 }, Leap = { "ToolSlash", 0.8 },
	Barrage = { "Cheer", 1.2 }, Gravity = { "Cheer", 0.8 }, Ritual = { "Cheer", 0.7 }, Breath = { "Cheer", 0.9 },
}
local STOCK_IDS = {
	R15 = { ToolHold = Catalog.Enemies.Shen_Phase1_Idle.Fallback, ToolSlash = Catalog.Enemies.Shen_Phase1_SwordCombo.Fallback,
		ToolLunge = Catalog.Enemies.Shen_Phase2_GlaiveCombo.Fallback, Cheer = Catalog.Enemies.Shen_Phase2_Transform.Fallback },
	R6 = { ToolHold = Catalog.Enemies.Shen_Phase1_Idle.FallbackR6, ToolSlash = Catalog.Enemies.Shen_Phase1_SwordCombo.FallbackR6,
		ToolLunge = Catalog.Enemies.Shen_Phase2_GlaiveCombo.FallbackR6, Cheer = Catalog.Enemies.Shen_Phase2_Transform.FallbackR6 },
}

function Rules.validId(id: any): boolean
	return type(id) == "string" and string.match(id, "^rbxassetid://%d+$") ~= nil
end
for key, id in Rules.Custom do assert(Rules.validId(id), "BossAnimationRules.Custom." .. key .. " must be \"rbxassetid://<digits>\"") end

-- The kind of a catalogued boss move, for stock fallbacks when a cue does not carry it.
local KINDS: { [string]: string } = {}
for _, list in Attacks do for _, move in list do KINDS[move.Id] = move.Kind end end
function Rules.kind(move: string): string? return KINDS[move] end

local function keys(look: string, phase: number, action: string, oath: boolean?): { string }
	local list = { look .. "_P" .. phase .. "_" .. action, look .. "_" .. action }
	if oath then table.insert(list, 1, look .. "_Oath_" .. action); table.insert(list, 1, look .. "_P" .. phase .. "_Oath_" .. action) end
	if action ~= "Idle" and action ~= "Transform" and action ~= "Strike" and not REACTION[action] and not GAIT[action] then
		table.insert(list, look .. "_P" .. phase .. "_Strike"); table.insert(list, look .. "_Strike")
	end
	return list
end

-- rig: "R15" | "R6" | "Creature"; attribute reads the actor (nil-safe for pure use).
function Rules.resolve(look: string, phase: number, action: string, kind: string?, rig: string, attribute: (string) -> any): Resolved
	local looped = action == "Idle" or (GAIT[action] == true and action ~= "GuardHit")
	local priority = if action == "Idle" then "Idle" elseif GAIT[action] then "Movement" elseif action == "Transform" then "Action4" elseif REACTION[action] then "Action3" else "Action"
	local oath = Rules.Oath[look] == true and attribute("AsuraBossEnraged") == true
	for _, key in keys(look, phase, action, oath) do
		local legacy = LEGACY[key]
		local override = attribute("AsuraBossAnimation_" .. key)
		if not Rules.validId(override) and legacy then override = attribute("AsuraBossAnimation_" .. legacy.Slot) end
		if Rules.validId(override) then
			return { Key = key, Id = override, Source = "Override", Speed = 1, Looped = looped, Priority = priority }
		end
		local custom = Rules.Custom[key] or (legacy and Catalog.Enemies[legacy.Slot].Custom)
		if custom then
			return { Key = key, Id = custom, Source = "Custom", Speed = if legacy and not Rules.Custom[key] then legacy.Speed else 1, Looped = looped, Priority = priority }
		end
	end
	local key = keys(look, phase, action)[1]
	if REACTION[action] or GAIT[action] then
		return { Key = key, Id = nil, Source = "None", Speed = 1, Looped = looped, Priority = priority }
	end
	if rig == "Creature" then
		return { Key = key, Id = nil, Source = "Procedural", Speed = 1, Looped = looped, Priority = priority }
	end
	local stock = STOCK[action] or STOCK[kind or Rules.kind(action) or "Strike"] or STOCK.Strike
	local legacy = LEGACY[look .. "_P" .. phase .. "_" .. action]
	local ids = if rig == "R6" then STOCK_IDS.R6 else STOCK_IDS.R15
	return { Key = key, Id = (ids :: any)[stock[1]], Source = "Stock", Speed = if legacy then legacy.Speed else stock[2] :: number,
		Looped = looped, Priority = priority }
end

-- Every slot this actor can request in a phase.
function Rules.slots(look: string, phase: number): { string }
	local list = { "Idle", "Strike" }
	if phase > 1 or Rules.Oath[look] then table.insert(list, "Transform") end
	local sets = Rules.Moves[look]
	local set = sets and Attacks[sets[math.clamp(phase, 1, #sets)]]
	for _, move in set or {} do table.insert(list, move.Id) end
	for _, id in Rules.Melee[look] or {} do table.insert(list, id) end
	for _, move in (Rules.OathMoves[look] and Attacks[Rules.OathMoves[look]]) or {} do
		if not table.find(list, move.Id) then table.insert(list, move.Id) end
	end
	return list
end

-- Phase lock (pure). A fresh authored attack: the clip position to start from, the playback speed, and
-- how long to hold the first frame, so `contact` (clip seconds) lands `untilImpact` seconds from now.
function Rules.startPlan(contact: number, untilImpact: number): (number, number, number)
	local u = math.max(untilImpact, 0)
	local speed = if u > 1e-3 then math.clamp(contact / u, Rules.SyncSpeed.Min, Rules.SyncSpeed.Max) else Rules.SyncSpeed.Max
	return math.max(0, contact - u * speed), speed, math.max(0, u - contact / speed)
end
-- Which contact a cue for an already-playing move means: the one whose spacing from the first contact
-- best matches `offset` (this cue's impact minus the move's first impact). A repeat pulse picks the
-- next thrust; a deferred first impact still picks the first.
function Rules.contactFor(contacts: { number }, offset: number): number
	local best, gap = 1, math.huge
	for i, c in contacts do
		local d = math.abs(c - contacts[1] - offset)
		if d < gap then best, gap = i, d end
	end
	return best
end
-- The speed that carries a playing track from `position` to `target` in `untilImpact` seconds; a
-- contact already passed just plays on at 1.
function Rules.retime(target: number, position: number, untilImpact: number): number
	if target <= position then return 1 end
	if untilImpact <= 1e-3 then return Rules.SyncSpeed.Max end
	return math.clamp((target - position) / untilImpact, Rules.SyncSpeed.Min, Rules.SyncSpeed.Max)
end

-- Honest one-line status for the AsuraAnimationStatus attribute.
function Rules.status(look: string, phase: number, rig: string, attribute: (string) -> any): string
	local slots = Rules.slots(look, phase)
	local authored, missing = 0, nil
	for _, action in slots do
		local r = Rules.resolve(look, phase, action, nil, rig, attribute)
		if r.Source == "Override" or r.Source == "Custom" then authored += 1 elseif not missing then missing = r.Key end
	end
	if authored == #slots then return string.format("Authored %d/%d", authored, #slots) end
	return string.format("Fallback:%s %d/%d authored (first missing %s)", if rig == "Creature" then "CreatureMotion" else "Stock",
		authored, #slots, tostring(missing))
end

return table.freeze(Rules)
