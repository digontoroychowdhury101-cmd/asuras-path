--!strict
-- Numerical behavior, rather than a text snapshot of the port.
local Easing = require("../src/shared/EffectEasing")
local Profile = require("../src/shared/MonasteryRidgeProfile")
local count = 0
local function check(ok: boolean, message: string)
	assert(ok, message)
	count += 1
end
local linear = Easing.new(0, 0)
local taper = Easing.new(10, -20)
local previous = 0
for i = 0, 100 do
	local t = i / 100
	check(math.abs(linear(t) - t) < 1e-12, "zero speed angles must reproduce a linear envelope")
	local v = taper(t)
	check(v >= previous and v >= 0 and v <= 1, "combat envelope must shrink monotonically")
	previous = v
end
check(taper(0) == 0 and taper(1) == 1, "exact envelope endpoints")
check(taper(-1) == 0 and taper(2) == 1, "life normalized to the effect duration")
local h = 1e-6
check(math.abs(taper(h) / h - math.tan(math.rad(55))) < 1e-5, "start speed equals authored tangent")
check(math.abs((1 - taper(1 - h)) / h - math.tan(math.rad(25))) < 1e-5, "end speed equals authored tangent")
check(not pcall(Easing.new, 45, 0), "unsupported singular start angle rejected")
check(#Profile == 24, "every existing ridge station has a baked pair")
for _, row in Profile do
	check(#row == 2, "two valley sides")
	for _, height in row do
		check(height == height and height >= 18 and height <= 38, "upper cliffs stay inside the original height bounds")
	end
end
print("PASS: " .. count .. " GitHub terrain/effect numerical checks")
