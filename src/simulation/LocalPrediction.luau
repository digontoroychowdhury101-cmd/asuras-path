--!strict
-- Bounded local prediction (combat recovery Stage 2, TIMING_CONTRACT §5). Decides from the owner's last
-- authoritative snapshot whether a press may be shown before the server confirms it. Presentation and the
-- owner's own movement only: damage, i-frames, deflect/parry, posture, Qi and rewards are never predicted.
-- A prediction is made only where the server's answer is not in doubt from what the client can see (a state that
-- takes the press, stamina to spare, no injury or dash-spam scaling to guess). It is named by the intent sequence and is
-- confirmed only by a snapshot whose IntentSeq is that sequence (the server marks the action an intent
-- started), never by an unrelated action change. A non-Executed terminal record or CONFIRM_TIMEOUT without
-- an Executed record rolls it back; an Executed record followed by a later sample showing another action
-- (the server's action was already interrupted) ends it without undoing anything.
local hasScript = pcall(function()
	return script.Parent
end)
local Settings: any, Schema: any, Weapons: any
if hasScript then
	Settings = require(script.Parent.Parent.Shared.CombatSettings)
	Schema = require(script.Parent.MoveSchema)
	Weapons = require(script.Parent.WeaponSchema)
else
	Settings = require("../shared/CombatSettings")
	Schema = require("./MoveSchema")
	Weapons = require("./WeaponSchema")
end

local Prediction = {}

-- A predicted action the server has not confirmed by now is rolled back. Covers a 300 ms round trip plus
-- one 100 ms queue wait, the envelope the timing contract supports.
Prediction.CONFIRM_TIMEOUT = 0.5

-- Opt-in diagnostic trace, off in play (a Studio QA probe sets Enabled). Every record names the intent seq, so
-- a press, its prediction, the animation occurrence and the terminal outcome are matched by ID, not by time.
-- Events: Sent (detail = action), Predicted / Unpredicted, Confirmed, Ended, RolledBack, Occurrence (the
-- frame the owner's animation layer starts or adopts the action; detail = state:move).
Prediction.Trace = { Enabled = false, Records = {} :: { any } }
local TRACE_LIMIT = 4096

function Prediction.trace(seq: number, event: string, detail: string?)
	local trace = Prediction.Trace
	if trace.Enabled and #trace.Records < TRACE_LIMIT then
		table.insert(trace.Records, { seq = seq, e = event, d = detail, t = os.clock() })
	end
end

-- Every playable move by id, for the local timeline of the swing a press chains from.
local MOVES: { [string]: any } = {}
for _, weapon in Weapons.Weapons :: { [string]: any } do
	for id, move in weapon.Moves do
		MOVES[id] = move
	end
end

function Prediction.costOf(id: string): number
	local move = MOVES[id]
	return if move then move.StaminaCost else 0
end

function Prediction.timingOf(id: string?): any
	local move = if id then MOVES[id] else nil
	return if move then move.Timing else nil
end

-- Stamina kept in reserve so regen/drain between the snapshot and the server tick cannot flip the answer.
local STAMINA_MARGIN = 2

local function uninjured(s: any, group: string): boolean
	for region, tier in s.Injuries do
		if tier ~= "None" and Settings.Injury.Group[region] == group then
			return false
		end
	end
	return true
end

local function settled(s: any): boolean
	return s.State == "Idle" and s.ActiveHP > 0 and not s.DeathblowLocked and s.Posture < Settings.Posture.StanceBreakThreshold
end

-- States a Light or Heavy press starts an opener from (MoveSchema): standing, and the guard and parry answers.
local OPENS = { Idle = true, Blocking = true, Deflecting = true }

-- The move the server will start for a Light or Heavy press from this snapshot, or nil when the client
-- cannot be sure (a combo follow-up, see followUp; an injured arm, too little stamina).
function Prediction.attack(s: any, kind: string): string?
	if (kind ~= "Light" and kind ~= "Heavy") or not OPENS[s.State] or s.ActiveHP <= 0 or s.DeathblowLocked
		or s.Posture >= Settings.Posture.StanceBreakThreshold or not uninjured(s, "Arm") then
		return nil
	end
	local weapon = Weapons.Weapons[s.Weapon]
	if not weapon then
		return nil
	end
	-- A sprinting press from standing is the running attack (CharacterService.eligibleFor).
	local move = if kind == "Heavy" then Weapons.moveForKind(weapon, kind, nil)
		elseif s.Sprinting and s.State == "Idle" then Weapons.moveForKind(weapon, "RunningAttack", nil)
		else weapon.Light[1]
	if not move or move.QiCost > 0 or s.Stamina < move.StaminaCost + STAMINA_MARGIN then
		return nil
	end
	return move.Id
end

-- Kept clear of both edges of a combo link, since neither the owner's clock nor a snapshot's age is the server's.
local LINK_MARGIN = 0.03

-- States a chained press may be shown over: the swing under way, or the Idle the prediction was made on.
local CHAINS = { Idle = true, Startup = true, Active = true, Recovery = true }

-- The next light the server will start if this press reaches it during `swing` ({Move = id, Started = clock}), and
-- the local clock it starts at (the swing's Recovery at the earliest: a press up to the buffer window early waits
-- for it, as the server's receipt buffer does). nil when the press would not link: outside the window, a move that
-- does not chain, too little stamina once `spent` (the unconfirmed predictions' costs) comes off.
function Prediction.followUp(s: any, kind: string, swing: any, now: number, spent: number): (string?, number?)
	if kind ~= "Light" or not swing or not CHAINS[s.State] or s.ActiveHP <= 0 or s.DeathblowLocked
		or s.Posture >= Settings.Posture.StanceBreakThreshold or not uninjured(s, "Arm") then
		return nil, nil
	end
	local weapon = Weapons.Weapons[s.Weapon]
	local current = MOVES[swing.Move]
	if not weapon or not current or current.Kind ~= "Light" then
		return nil, nil
	end
	local timing = current.Timing
	local recovery = swing.Started + timing.StartupSeconds + timing.ActiveSeconds
	if timing.ComboWindowSeconds <= 0 or recovery - now > Settings.Input.BufferWindow - LINK_MARGIN or now > recovery + timing.ComboWindowSeconds - LINK_MARGIN then
		return nil, nil
	end
	local following = Weapons.nextLight(weapon, current)
	if following.QiCost > 0 or s.Stamina - spent < following.StaminaCost + STAMINA_MARGIN then
		return nil, nil
	end
	return following.Id, math.max(now, recovery)
end

-- A light pressed after a swing's link has closed, soon enough that the server's receipt buffer holds it until the swing
-- ends: the opener it will start, at the swing's end. Never within LINK_MARGIN of the link closing, where the server's
-- answer could be either move. A sprinting press is left to the server, whose running attack starts from Idle.
function Prediction.restart(s: any, kind: string, swing: any, now: number, spent: number): (string?, number?)
	if kind ~= "Light" or not swing or not CHAINS[s.State] or s.Sprinting or s.ActiveHP <= 0 or s.DeathblowLocked
		or s.Posture >= Settings.Posture.StanceBreakThreshold or not uninjured(s, "Arm") then
		return nil, nil
	end
	local weapon = Weapons.Weapons[s.Weapon]
	local current = MOVES[swing.Move]
	if not weapon or not current then
		return nil, nil
	end
	local timing = current.Timing
	local recovery = swing.Started + timing.StartupSeconds + timing.ActiveSeconds
	local finish = recovery + timing.RecoverySeconds
	local linkClosed = recovery + timing.ComboWindowSeconds + (if timing.ComboWindowSeconds > 0 then LINK_MARGIN else 0)
	if now < linkClosed or finish - now > Settings.Input.BufferWindow - LINK_MARGIN then
		return nil, nil
	end
	local opener = weapon.Light[1]
	if opener.QiCost > 0 or s.Stamina - spent < opener.StaminaCost + STAMINA_MARGIN then
		return nil, nil
	end
	return opener.Id, math.max(now, finish)
end

-- The displacement the server will grant for a Dash or Roll press, or nil when it cannot be known exactly:
-- `sinceLastDash` is the owner's own time since its previous dash; inside the spam window the distance and
-- i-frames decay by a chain count the client does not track, so those presses wait for the server.
function Prediction.dash(s: any, kind: string, sinceLastDash: number): (number?, number?)
	if (kind ~= "Dash" and kind ~= "Roll") or not settled(s) or not uninjured(s, "Leg") then
		return nil, nil
	end
	if sinceLastDash <= Settings.Backdash.SpamWindow + 0.05 then
		return nil, nil
	end
	if s.Stamina < Schema.staminaCost(kind, nil) + STAMINA_MARGIN then
		return nil, nil
	end
	local movement = Settings.Movement
	if kind == "Roll" then
		return movement.RollDistance, movement.RollDuration
	end
	return movement.DashDistance, movement.DashDuration
end

-- Guard is predicted as a pose only: Idle to Blocking while the key is held. Deflect timing is never shown
-- early; the server's Deflecting state replaces the pose when it arrives.
function Prediction.guard(s: any): boolean
	return settled(s)
end

-- How much of a refused dash's displacement to take back: only what its own drive produced. `driven` is the
-- distance the drive commanded (integrated each frame), `travelled` the body's actual movement along the dash
-- direction. A wall that stopped the dash leaves travelled < driven; a shove along it leaves travelled > driven; a
-- shove across it is not along the direction at all and stays. Never negative. (x, z) is the unit dash direction.
function Prediction.dashTravel(fromX: number, fromZ: number, stopX: number, stopZ: number, x: number, z: number, driven: number): number
	local travelled = (stopX - fromX) * x + (stopZ - fromZ) * z
	return math.max(0, math.min(travelled, driven))
end

-- The planar velocity left on a body once a refused dash's drive is removed: only the drive's own command comes
-- off, along its direction, so knockback or a walk across it continues. A drive that already stopped (`running`
-- false) owns none of the current velocity, which is returned untouched.
function Prediction.residualVelocity(vx: number, vz: number, commandX: number, commandZ: number, running: boolean): (number, number)
	if not running then
		return vx, vz
	end
	local speed = math.sqrt(commandX * commandX + commandZ * commandZ)
	if speed < 1e-6 then
		return vx, vz
	end
	local ux, uz = commandX / speed, commandZ / speed
	local along = vx * ux + vz * uz
	local removed = math.clamp(along, 0, speed)
	return vx - ux * removed, vz - uz * removed
end

-- The terminal status and server tick reported for `seq` in an AsuraIntent attribute value, or nil if absent.
-- Records are "seq:status:reason:tick" joined by ";" (CharacterService terminal records).
function Prediction.terminal(records: any, seq: number): (string?, number?)
	if type(records) ~= "string" then
		return nil, nil
	end
	for record in string.gmatch(records, "[^;]+") do
		local id, status, tick = string.match(record, "^(%d+):(%a+):[^:]*:(%d+)$")
		if tonumber(id) == seq then
			return status, tonumber(tick)
		end
	end
	return nil, nil
end

return table.freeze(Prediction)
