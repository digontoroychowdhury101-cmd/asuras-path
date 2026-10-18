--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Simulation/Tempo
-- Converts baseline timing into Asura's Path tempo and snaps it to the 60 Hz server tick.
local hasScript = pcall(function()
	return script.Parent
end)
local Settings: any
if hasScript then
	Settings = require(script.Parent.Parent.Shared.CombatSettings)
else
	Settings = require("../shared/CombatSettings")
end

export type TelegraphClass = "Light" | "Heavy" | "RunningAttack" | "WeaponArt"

local EPSILON = 1e-6
local SCALAR: number = Settings.Tempo.Scalar
local TICK_RATE: number = Settings.Tempo.TickRate
local TICK: number = Settings.Tempo.TickSeconds

local Tempo = {}

Tempo.Scalar = SCALAR
Tempo.TickRate = TICK_RATE
Tempo.TickSeconds = TICK
Tempo.HalfTick = TICK * 0.5

local function snapFramesUp(seconds: number): number
	return math.ceil(seconds * TICK_RATE - EPSILON)
end

local function snapFramesNearest(seconds: number): number
	return math.floor(seconds * TICK_RATE + 0.5 + EPSILON)
end

Tempo.HeavyMinFrames = snapFramesUp(Settings.Tempo.Telegraph.HeavyMinSeconds)
Tempo.LightMinFrames = math.max(1, snapFramesNearest(Settings.Tempo.Telegraph.LightTargetSeconds))
Tempo.HeavyMinSeconds = Tempo.HeavyMinFrames * TICK
Tempo.LightMinSeconds = Tempo.LightMinFrames * TICK

function Tempo.toDuration(baseSec: number): number
	assert(baseSec == baseSec and baseSec >= 0, "Tempo.toDuration requires a non-negative number")
	return baseSec / SCALAR
end

function Tempo.toRate(baseRate: number): number
	assert(baseRate == baseRate, "Tempo.toRate requires a number")
	return baseRate * SCALAR
end

function Tempo.toFrames(seconds: number): number
	assert(seconds == seconds and seconds >= 0, "Tempo.toFrames requires a non-negative number")
	return snapFramesNearest(seconds)
end

function Tempo.toFramesCeil(seconds: number): number
	assert(seconds == seconds and seconds >= 0, "Tempo.toFramesCeil requires a non-negative number")
	return math.max(0, snapFramesUp(seconds))
end

function Tempo.framesToSeconds(frames: number): number
	return frames * TICK
end

-- Baseline 60 Hz frame count -> tempo-scaled frame count (never below one frame).
function Tempo.scaleFrames(baseFrames: number): number
	assert(baseFrames == baseFrames and baseFrames >= 0, "Tempo.scaleFrames requires a non-negative number")
	if baseFrames == 0 then
		return 0
	end
	return math.max(1, math.floor(baseFrames / SCALAR + 0.5 + EPSILON))
end

function Tempo.quantize(seconds: number): number
	return snapFramesNearest(seconds) * TICK
end

function Tempo.quantizeUp(seconds: number): number
	return snapFramesUp(seconds) * TICK
end

function Tempo.quantizeDown(seconds: number): number
	return math.floor(seconds * TICK_RATE + EPSILON) * TICK
end

function Tempo.tickIndex(time: number, origin: number?): number
	return math.floor((time - (origin or 0)) * TICK_RATE + EPSILON)
end

function Tempo.tickTime(index: number, origin: number?): number
	return (origin or 0) + index * TICK
end

-- Snaps a client or replicated timestamp onto the nearest server tick boundary.
function Tempo.snapTime(time: number, origin: number?): number
	local base = origin or 0
	return base + snapFramesNearest(time - base) * TICK
end

-- Snaps a client-reported timestamp to a tick, never later than the server's current tick and
-- never earlier than the allowed rewind, so 16.6 ms jitter cannot buy a timing advantage.
function Tempo.reconcile(clientTime: number, serverTime: number, maxRewind: number): number
	local latest = Tempo.snapTime(serverTime)
	local earliest = math.min(Tempo.quantizeUp(serverTime - maxRewind), latest)
	return math.clamp(Tempo.snapTime(clientTime), earliest, latest)
end

function Tempo.sameTick(a: number, b: number): boolean
	return math.abs(a - b) < Tempo.HalfTick
end

-- Window test with half-tick tolerance on both edges so 16.6 ms jitter cannot flip a result.
function Tempo.withinWindow(eventTime: number, windowStart: number, windowLength: number): boolean
	local tolerance = Tempo.HalfTick
	return eventTime >= windowStart - tolerance and eventTime <= windowStart + windowLength + tolerance
end

function Tempo.minimumStartupFrames(class: TelegraphClass): number
	if class == "Heavy" or class == "WeaponArt" then
		return Tempo.HeavyMinFrames
	end
	return Tempo.LightMinFrames
end

function Tempo.enforceTelegraph(class: TelegraphClass, frames: number): number
	return math.max(frames, Tempo.minimumStartupFrames(class))
end

function Tempo.isReactable(class: TelegraphClass, frames: number): boolean
	return frames >= Tempo.minimumStartupFrames(class)
end

return table.freeze(Tempo)
