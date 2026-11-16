--!nonstrict
-- Regression for the gameplay compass bearing maths and label density (open-world brief section 12).
-- Run from the project root: python3 tools/lune_compat.py tools/test_compass_bearing.luau
-- Pure maths and source checks only: no rendered pixels, Studio remains the visual acceptance.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox") :: any

local passed, failed = 0, 0
local function check(name: string, condition: any)
	if condition then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local PATH = "src/client/Controllers/SakuraCompass.luau"
local stubScript = { Parent = { WaitForChild = function(_, name) return { Colors = {} } end } }
local env = { game = { GetService = function() return {} end }, script = stubScript, require = function(m) return m end, Vector2 = roblox.Vector2 }
local Compass = luau.load(fs.readFile(PATH), { debugName = PATH, environment = env })()
local function near(a: number, b: number): boolean return math.abs(a - b) < 1e-6 end

-- 1. Cardinal bearings (north is world -Z).
check("north", near(Compass.bearing(0, -1), 0))
check("east", near(Compass.bearing(1, 0), 90))
check("south", near(Compass.bearing(0, 1), 180))
check("west", near(Compass.bearing(-1, 0), 270))
check("north-east", near(Compass.bearing(1, -1), 45))

-- 2. Always normalised to [0, 360), including a tiny negative angle that rounds to 360.
for _, v in { { -1e-17, -1 }, { -1e-300, -1 }, { -0.001, -1 }, { 0.001, -1 }, { -1, -1e-12 }, { 3, 4 }, { -3, 4 } } do
	local b = Compass.bearing(v[1], v[2])
	check("normalised " .. v[1] .. "," .. v[2], b >= 0 and b < 360)
end
check("tiny negative is 0 not 360", Compass.bearing(-1e-17, -1) == 0)

-- 3. Wrap continuity: marks move a few degrees, never jump, across 359 -> 0.
check("offset 0 vs 359 is +1", near(Compass.offset(0, 359), 1))
check("offset 359 vs 0 is -1", near(Compass.offset(359, 0), -1))
local worst = 0
for tenth = 3500, 3700 do
	local heading = (tenth / 10) % 360
	local step = math.abs(Compass.offset(15, heading) - Compass.offset(15, (heading + 0.1) % 360))
	worst = math.max(worst, math.min(step, 360 - step))
end
check("mark 15 moves 0.1 per 0.1 turn across north", worst < 0.1 + 1e-6)
for heading = 0, 359 do
	for _, bearing in { 0, 90, 180, 270, 359 } do
		local d = Compass.offset(bearing, heading)
		check("offset range " .. bearing .. "/" .. heading, d >= -180 and d <= 180)
	end
end

-- 4. Readout is an integer 0-359 that wraps to 0 instead of showing 360.
check("readout 359.6 wraps to 0", Compass.readout(359.6) == 0)
check("readout 359.4 is 359", Compass.readout(359.4) == 359)
check("readout 0.4 is 0", Compass.readout(0.4) == 0)
check("readout 45 is 45", Compass.readout(45) == 45)

-- 5. Label density at the UISizeConstraint extremes (240..520 px, HALF_SPAN 80 deg, size-11 label ~16 px wide).
local source = fs.readFile(PATH)
check("HALF_SPAN still 80", string.find(source, "HALF_SPAN = 80", 1, true) ~= nil)
check("numbers every 30 degrees", string.find(source, "NUMBER_STEP = 30", 1, true) ~= nil)
for _, width in { 240, 520 } do
	local pxPerDeg = width / 160
	local numberGap = 30 * pxPerDeg - 16 -- clear space between adjacent number labels
	local letterGap = 15 * pxPerDeg - (16 / 2 + 14 / 2) -- number to nearest letter (NE ~14 px wide)
	check(width .. " px: numbers clear of each other (" .. numberGap .. ")", numberGap >= 12)
	check(width .. " px: numbers clear of letters (" .. letterGap .. ")", letterGap >= 4)
end

-- 6. Marker API exists and the readout sits on a different row from waypoint icons.
check("setMarker exported", type(Compass.setMarker) == "function")
check("readout row above marker row", string.find(source, "MARKER_Y = 20", 1, true) ~= nil and string.find(source, "Position = UDim2.fromScale(0.5, 0)", 1, true) ~= nil)

print(string.format("compass bearing: %d passed, %d failed", passed, failed))
if failed > 0 then error("test_compass_bearing failed") end
