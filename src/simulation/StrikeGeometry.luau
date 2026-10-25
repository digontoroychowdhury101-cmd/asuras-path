--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Simulation/StrikeGeometry
-- One omnidirectional strike rule for players, enemies, bosses and grounded duels (post-F26 step 2).
-- Pure numbers, so the server's weapon sweep, the client's drawn arc and every facing budget share
-- one source. Yaw follows Roblox: CFrame.Angles(0, yaw, 0).LookVector == (-sin yaw, 0, -cos yaw).
local hasScript = pcall(function()
	return script.Parent
end)
local Settings: any
if hasScript then
	Settings = require(script.Parent.Parent.Shared.CombatSettings)
else
	Settings = require("../shared/CombatSettings")
end

local Tracking = Settings.Tracking
local RATE = math.rad(Tracking.StartupTurnRate)
local TAU = math.pi * 2

export type Shape = { Arc: number, Reach: number, Lunge: number }
export type Strike = { Arc: number, Reach: number, Lunge: number, Yaw: number, Start: number, Active: number, Weapon: string }
export type Air = { Airborne: boolean, Attacks: number, Dodges: number, Landing: boolean }

local Geometry = {}
-- Moves wider than this sweep round the shoulder; narrower ones thrust along the facing.
Geometry.SlashArc = 40

-- States in which an actor turns freely. Guarding is not one: raising a guard out of a whiffed swing
-- must not spin the body to face a flanker (Studio, post-F26 step 2), so guards turn at the shared rate.
local FREE: { [string]: boolean } = { Idle = true, RestingAtShrine = true }
local GUARD: { [string]: boolean } = { Blocking = true, Deflecting = true, Blockstun = true }

-------------------------------------------------------------------------------------------------
-- Blade path
-------------------------------------------------------------------------------------------------

-- Local-space blade segment (hilt xyz, tip xyz) at `progress` 0..1 through the active frames. Slashes
-- sweep the authored arc left to right round the shoulder; thrusts extend along the facing. Lunge
-- and the fighter's reach bonus fold into the tip.
function Geometry.segment(shape: Shape, progress: number, bonus: number): (number, number, number, number, number, number)
	local reach = shape.Reach + bonus + shape.Lunge * 0.35 * progress
	if shape.Arc > Geometry.SlashArc then
		local angle = math.rad(shape.Arc) * (progress - 0.5)
		local x, z = math.sin(angle), -math.cos(angle)
		return x * 0.8, 0.6, z * 0.8, x * reach, 0.6, z * reach
	end
	local extension = reach * (0.55 + 0.45 * progress)
	return 0, 0.6, -0.8, 0, 0.6, -extension
end

-- Tip positions (local x, z) at `count` + 1 even steps through the active window: the path drawn.
function Geometry.sweep(shape: Shape, bonus: number, count: number): { { number } }
	local points = table.create(count + 1)
	for i = 0, count do
		local _, _, _, x, _, z = Geometry.segment(shape, i / count, bonus)
		points[i + 1] = { x, z }
	end
	return points
end

-------------------------------------------------------------------------------------------------
-- Facing
-------------------------------------------------------------------------------------------------

function Geometry.yaw(x: number, z: number): number?
	if x * x + z * z < 1e-10 then
		return nil
	end
	return math.atan2(-x, -z)
end

function Geometry.look(yaw: number): (number, number)
	return -math.sin(yaw), -math.cos(yaw)
end

-- Signed shortest turn from `from` to `to`, in (-pi, pi].
function Geometry.delta(from: number, to: number): number
	local d = (to - from) % TAU
	return if d > math.pi then d - TAU else d
end

-- Turn `from` toward `to` by at most `step` radians.
function Geometry.turn(from: number, to: number, step: number): number
	local d = Geometry.delta(from, to)
	if math.abs(d) <= step then
		return from + d
	end
	return from + (if d > 0 then step else -step)
end

-- Total turn a windup of `startup` seconds may add to its press aim before it commits. Lights
-- (startup under the commit lead) go exactly where they were aimed.
function Geometry.windupBudget(startup: number): number
	return RATE * math.max(0, startup - Tracking.CommitLeadSeconds)
end

-- Radians an actor in `state` may turn over `dt`. Free in neutral; the shared rate early in a windup,
-- while recovering and while guarding; none in the commit lead, the active frames, dodges or stuns.
-- Sidestepping a committed swing makes it whiff; only getting behind it wins the recovery.
function Geometry.turnStep(state: string, elapsed: number, startup: number, dt: number): number
	if FREE[state] then
		return math.huge
	elseif state == "Startup" then
		return if elapsed < startup - Tracking.CommitLeadSeconds then RATE * dt else 0
	elseif state == "Recovery" or GUARD[state] then
		return RATE * dt
	end
	return 0
end

-- The yaw a swing commits to at its first active frame: where the attacker faces, held within the
-- windup budget of where it was aimed. Server hit validation and the drawn arc both use it.
function Geometry.commit(aim: number, actual: number, startup: number): number
	local budget = Geometry.windupBudget(startup)
	return aim + math.clamp(Geometry.delta(aim, actual), -budget, budget)
end

-------------------------------------------------------------------------------------------------
-- Air
-------------------------------------------------------------------------------------------------

function Geometry.newAir(): Air
	return { Airborne = false, Attacks = 0, Dodges = 0, Landing = false }
end

-- Grounded rules for every current mode. A future "AerialDuel" ruleset (free flight) lifts them.
function Geometry.airAllows(air: Air, action: string, ruleset: string?): (boolean, string)
	if not air.Airborne or ruleset == "AerialDuel" then
		return true, ""
	end
	if action == "Light" then
		return air.Attacks < Tracking.AerialAttacks, "AirAttackSpent"
	elseif action == "Roll" or action == "Dash" then
		return air.Dodges < Tracking.AirDodges, "AirDodgeSpent"
	elseif action == "Heavy" or action == "WeaponArt" or action == "RunningAttack" then
		return false, "Airborne"
	end
	return true, ""
end

-- Records an action granted in the air; an aerial strike owes a landing.
function Geometry.airSpend(air: Air, action: string)
	if not air.Airborne then
		return
	end
	if action == "Light" then
		air.Attacks += 1
		air.Landing = true
	elseif action == "Roll" or action == "Dash" then
		air.Dodges += 1
	end
end

-- Updates the airborne flag; touching down refreshes the air allowances (a pending landing stays
-- until the caller applies it).
function Geometry.airUpdate(air: Air, airborne: boolean)
	air.Airborne = airborne
	if not airborne then
		air.Attacks, air.Dodges = 0, 0
	end
end

-------------------------------------------------------------------------------------------------
-- Replicated strike record (model attribute AsuraStrike)
-------------------------------------------------------------------------------------------------

function Geometry.encode(s: Strike): string
	return string.format("%d|%.2f|%.2f|%.4f|%.3f|%.3f|%s", s.Arc, s.Reach, s.Lunge, s.Yaw, s.Start, s.Active, s.Weapon)
end

function Geometry.decode(text: any): Strike?
	if type(text) ~= "string" then
		return nil
	end
	local arc, reach, lunge, yaw, start, active, weapon = string.match(text, "^(%-?%d+)|([%d%.%-]+)|([%d%.%-]+)|([%d%.%-]+)|([%d%.%-]+)|([%d%.%-]+)|(.*)$")
	if not arc then
		return nil
	end
	return {
		Arc = tonumber(arc) :: number,
		Reach = tonumber(reach) :: number,
		Lunge = tonumber(lunge) :: number,
		Yaw = tonumber(yaw) :: number,
		Start = tonumber(start) :: number,
		Active = tonumber(active) :: number,
		Weapon = weapon :: string,
	}
end

return table.freeze(Geometry)
