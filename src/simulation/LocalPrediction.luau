--!strict
-- Bounded local prediction (combat recovery Stage 2, TIMING_CONTRACT §5). Decides from the owner's last
-- authoritative snapshot whether a press may be shown before the server confirms it. Presentation and the
-- owner's own movement only: damage, i-frames, deflect/parry, posture, Qi and rewards are never predicted.
-- A prediction is made only where the server's answer is not in doubt from what the client can see (Idle,
-- stamina to spare, no injury or dash-spam scaling to guess). It is named by the intent sequence and is
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

-- The move the server will start for a Light or Heavy press from this snapshot, or nil when the client
-- cannot be sure (not Idle, a combo follow-up, an injured arm, too little stamina).
function Prediction.attack(s: any, kind: string): string?
	if (kind ~= "Light" and kind ~= "Heavy") or not settled(s) or not uninjured(s, "Arm") then
		return nil
	end
	local weapon = Weapons.Weapons[s.Weapon]
	if not weapon then
		return nil
	end
	local move = if kind == "Light" then weapon.Light[1] else Weapons.moveForKind(weapon, kind, nil)
	if not move or move.QiCost > 0 or s.Stamina < move.StaminaCost + STAMINA_MARGIN then
		return nil
	end
	return move.Id
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
