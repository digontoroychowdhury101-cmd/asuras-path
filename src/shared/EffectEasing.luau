--!strict
-- Luau adaptation of Effekseer MathUtl.Easing (start/end speed cubic).
-- Modified for normalized particle envelopes; upstream source is preserved in tools/vendor/effekseer/Math.cs.
--[[
The MIT License (MIT)

Copyright (c) 2011 Effekseer Project

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]
local Easing = {}

function Easing.new(startAngle: number, endAngle: number): (number) -> number
	assert(math.abs(startAngle) <= 30 and math.abs(endAngle) <= 30, "Use Effekseer's supported -30..30 speed angles")
	local g1 = math.tan(math.rad(startAngle + 45))
	local g2 = math.tan(math.rad(endAngle + 45))
	local c = g1
	local a = g2 - g1 - 2 * (1 - c)
	local b = (g2 - g1 - 3 * a) / 2
	return function(time: number): number
		local t = math.clamp(time, 0, 1)
		return math.clamp(a * t ^ 3 + b * t ^ 2 + c * t, 0, 1)
	end
end

return table.freeze(Easing)
