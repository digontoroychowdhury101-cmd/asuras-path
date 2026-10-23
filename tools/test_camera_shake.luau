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

-- Follow-up 03: a lock held over the KO'd body left TargetPitch at ~+48 degrees (Studio lookY 0.75),
-- so every respawn stared at the sky until the mouse moved. A new body must recentre the view.
local helpers = string.sub(source, assert(string.find(source, "local function yawOf(", 1, true)),
	assert(string.find(source, "\nfunction Controller.new(", 1, true)))
local follow = luau.load("type Fields = any\nlocal DEFAULT_PITCH = math.rad(-12)\n" .. helpers .. "\nreturn followRoot",
	{ debugName = "CameraController.followRoot", environment = setmetatable({ math = math, Vector3 = Vector3 }, { __index = getfenv() }) })()
local camera = { TargetPitch = math.rad(48), Pitch = { Value = math.rad(48), Velocity = 2 }, TargetYaw = 1, Yaw = { Value = 1, Velocity = 1 } }
local body = { CFrame = { LookVector = Vector3.new(1, 0, 0) } }
follow(camera, body)
check("respawn recentres pitch", math.abs(camera.TargetPitch - math.rad(-12)) < 1e-6 and camera.Pitch.Value == camera.TargetPitch and camera.Pitch.Velocity == 0)
check("respawn faces the camera along the body", math.abs(camera.TargetYaw - math.atan2(-1, 0)) < 1e-6 and camera.Yaw.Value == camera.TargetYaw and camera.FollowRoot == body)

print(string.format("camera shake: %d passed, %d failed", passed, failed))
if failed > 0 then
	error("camera shake regression failed")
end
