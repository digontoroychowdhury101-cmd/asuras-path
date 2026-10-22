--!nonstrict
-- Runs CameraController's real stepShake. Regression for follow-up 02: the Studio client measured
-- 88 ms median frames, and the one-step shake oscillator then grew a hit impulse to ~1e35. The
-- camera froze far away and every line-of-sight prompt (altars, portals) stopped appearing. The
-- shake must stay bounded and settle at 60 FPS, 11 FPS and through a single 0.5 s hitch.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox") :: any
local Vector3 = roblox.Vector3

local passed, failed = 0, 0
local function check(name: string, ok: boolean)
	if ok then
		passed += 1
	else
		failed += 1
		print("FAIL " .. name)
	end
end

local source = fs.readFile("src/client/Controllers/CameraController.luau")
local first = assert(string.find(source, "local function stepShake(", 1, true))
local last = assert(string.find(source, "\nlocal function wrap(", first, true))
local env = setmetatable({ math = math }, { __index = getfenv() }) :: any
local stepShake = luau.load("type Fields = any\n" .. string.sub(source, first, last) .. "\nreturn stepShake", { debugName = "CameraController.stepShake", environment = env })()

local function run(frames: { number }): (number, number)
	-- The same push Impulse applies for a heavy hit (direction * magnitude * 6).
	local fields = { Shake = Vector3.new(0, 0, 0), ShakeVelocity = Vector3.new(1.2, 0.8, 0) * 6 }
	local peak = 0
	for _, dt in frames do
		stepShake(fields, dt)
		peak = math.max(peak, fields.Shake.Magnitude)
	end
	return peak, fields.Shake.Magnitude
end
local function frames(dt: number, seconds: number): { number }
	local list = {}
	for i = 1, math.ceil(seconds / dt) do list[i] = dt end
	return list
end

local peak60, end60 = run(frames(1 / 60, 3))
check("60 FPS shake stays small", peak60 < 1)
check("60 FPS shake settles", end60 < 1e-3)
local peakSlow, endSlow = run(frames(0.088, 6))
check("88 ms frames (Studio measurement) stay bounded", peakSlow < 1)
check("88 ms frames settle", endSlow < 1e-3)
local hitch = frames(1 / 60, 1)
table.insert(hitch, 5, 0.5)
local peakHitch, endHitch = run(hitch)
check("a single 0.5 s hitch stays bounded", peakHitch < 1 and endHitch < 1e-2)

print(string.format("camera shake: %d passed, %d failed", passed, failed))
if failed > 0 then
	error("camera shake regression failed")
end
