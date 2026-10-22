--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/SanctuaryRails
-- Carved stone balustrades for the Shrine of the Ascendant: kit posts (Rail_Post) at both ends and
-- every ~6 studs, carved bays (Rail_Bay, or Rail_BayStair along the 1:2 Ascension stair) between them,
-- and one invisible wall per run for movement. Without the kit a plain plinth-and-cap rail stands in.
local Kit = require(script.Parent:WaitForChild("SanctuaryKit") :: ModuleScript)

local Rails = {}

local SPACING = 6 -- post centres; a 5.1 bay fills the gap between 0.86-stud posts
local BAY = 5.1
local HEIGHT = 3.2 -- collision, a little above the 2.6 handrail
local STAIR = 0.5 -- the stair's rise per run (WorldDefinitions: rise 1, run 2)

local function fallback(parent: Instance, a: Vector3, b: Vector3)
	local cf = Kit.along(a, b)
	local length = (Vector3.new(b.X, 0, b.Z) - Vector3.new(a.X, 0, a.Z)).Magnitude
	Kit.slab(parent, "RailPlinth", Vector3.new(length, 2.2, 0.9), cf * CFrame.new(0, 1.1, 0), "Stone", Kit.decor())
	Kit.slab(parent, "RailCap", Vector3.new(length + 0.4, 0.3, 1.2), cf * CFrame.new(0, 2.35, 0), "Stone", Kit.decor())
end

-- Level run along floor points a -> b. `posts` false skips the end posts (when a column stands there);
-- `collide` false lays the carving only, over a wall that already stops bodies.
function Rails.run(parent: Instance, a: Vector3, b: Vector3, posts: boolean?, collide: boolean?)
	local length = (b - a).Magnitude
	if length < 1 then
		return
	end
	if collide ~= false then
		Kit.blocker(parent, "RailCollision", a, b, HEIGHT, 0.9)
	end
	if not Kit.available() then
		fallback(parent, a, b)
		return
	end
	local n = math.max(1, math.round(length / SPACING))
	local step = length / n
	local dir = (b - a).Unit
	local frame = Kit.along(a, b, a)
	for i = 0, n do
		if posts ~= false or (i > 0 and i < n) then
			Kit.place(parent, "Rail_Post", frame * CFrame.new(step * i, 0, 0))
		end
	end
	local fill = math.max(step - 0.86, 0.5) / BAY
	for i = 1, n do
		Kit.place(parent, "Rail_Bay", CFrame.fromMatrix(a + dir * step * (i - 0.5), dir, Vector3.yAxis), Vector3.new(fill, 1, 1))
	end
end

-- Balustrade up a 1:2 flight: `foot` and `head` are floor points on the nosing line (head higher).
-- Bays are never stretched, so their sheared rails keep the stair's exact pitch.
function Rails.stair(parent: Instance, foot: Vector3, head: Vector3)
	local flat = Vector3.new(head.X - foot.X, 0, head.Z - foot.Z)
	local run = flat.Magnitude
	-- One wall from the foot's floor to above the head's handrail keeps bodies on the flight.
	Kit.blocker(parent, "StairRailCollision", foot, Vector3.new(head.X, foot.Y, head.Z), HEIGHT + (head.Y - foot.Y), 0.9)
	local dir = flat.Unit
	local n = math.max(1, math.floor(run / SPACING))
	local spare = run - n * SPACING
	local start = foot + dir * spare + Vector3.yAxis * spare * STAIR
	local function at(d: number): Vector3
		return start + dir * d + Vector3.yAxis * d * STAIR
	end
	if not Kit.available() then
		local mid = (at(0) + at(n * SPACING)) * 0.5
		local cf = CFrame.lookAt(mid, mid + (at(n * SPACING) - at(0)))
		Kit.slab(parent, "StairRail", Vector3.new(0.9, 2.4, (at(n * SPACING) - at(0)).Magnitude), cf * CFrame.new(0, 1.2, 0), "Stone", Kit.decor())
		return
	end
	for i = 0, n do
		Kit.place(parent, "Rail_Post", CFrame.new(at(i * SPACING) - Vector3.yAxis * 0.35))
	end
	for i = 1, n do
		-- The sheared bay rises toward its own -X, so its X axis points back down the flight.
		Kit.place(parent, "Rail_BayStair", CFrame.fromMatrix(at((i - 0.5) * SPACING) - Vector3.yAxis * 0.1, -dir, Vector3.yAxis))
	end
end

return table.freeze(Rails)
