--!nonstrict
-- Unmapped Studio-only walker (post-F26 Step 5, Desecrated Monastery approach). Insert into the
-- player's PlayerScripts during Play (tools/qa/qa_inject.py); answers PlayerScripts.WalkQA:Invoke(op, ...).
-- It walks the player's own character with Humanoid:MoveTo under real Studio physics along the route
-- RouteGuide stages for the minimap (scripted locomotion: a seeded Studio diagnostic, never earned
-- play), and logs falls, stalls, the lowest floor, edge drops beside the line and sightlines.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Guide = require(RS.AsurasPath.Shared.RouteGuide)
local player = Players.LocalPlayer

local function body()
	local c = player.Character
	return c, c and c:FindFirstChildOfClass("Humanoid"), c and c:FindFirstChild("HumanoidRootPart")
end
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
local function floorY(x, z, fromY)
	local c = body()
	params.FilterDescendantsInstances = { c }
	local hit = workspace:Raycast(Vector3.new(x, fromY + 6, z), Vector3.new(0, -80, 0), params)
	return hit and hit.Position.Y, hit and hit.Instance
end

-- One MoveTo leg: "ok", "stalled" (no progress 4 s even after a jump) or "fell" (12+ studs down).
local function leg(target, timeout)
	local _, hum, root = body()
	local startY, minY, air, jumped = root.Position.Y, root.Position.Y, 0, false
	local best, since, began, issued = math.huge, os.clock(), os.clock(), 0
	while true do
		if os.clock() - issued > 5 then hum:MoveTo(Vector3.new(target.X, root.Position.Y, target.Z)); issued = os.clock() end
		task.wait(0.1)
		local p = root.Position
		local d = Vector3.new(target.X - p.X, 0, target.Z - p.Z).Magnitude
		minY = math.min(minY, p.Y)
		if hum.FloorMaterial == Enum.Material.Air then air += 0.1 end
		if d < 2.5 then return "ok", minY - startY, air end
		if p.Y < startY - 12 then return "fell", minY - startY, air end
		if d < best - 0.5 then best, since = d, os.clock() end
		if os.clock() - since > 2.5 and not jumped then hum.Jump, jumped = true, true end
		if os.clock() - since > 4 or os.clock() - began > timeout then return "stalled", minY - startY, air end
	end
end

local ops = {}
function ops.where()
	local _, hum, root = body()
	local p = root.Position
	return string.format("(%.1f,%.1f,%.1f) floor %s hp %.0f", p.X, p.Y, p.Z, hum.FloorMaterial.Name, hum.Health)
end
-- Walk a list of {x, z} points; one line per leg.
function ops.walk(points, timeout)
	local out = {}
	for i, pt in points do
		local status, drop, air = leg(Vector3.new(pt[1], 0, pt[2]), timeout or 40)
		local _, _, root = body()
		table.insert(out, string.format("%d -> (%.0f,%.0f): %s at (%.1f,%.1f,%.1f) lowest %+.1f air %.1fs", i, pt[1], pt[2], status, root.Position.X, root.Position.Y, root.Position.Z, drop, air))
		if status ~= "ok" then break end
	end
	return table.concat(out, "\n")
end
-- The route the minimap draws from here to `goal`, then walk it.
function ops.route(gx, gy, gz, timeout)
	local _, _, root = body()
	local stage = Guide.next(root.Position, Vector3.new(gx, gy, gz))
	local points, names = {}, {}
	for i, p in stage.Route.Points do table.insert(points, { p.X, p.Z }); table.insert(names, stage.Route.Names[i] or "goal") end
	return "route: " .. table.concat(names, " > ") .. "\n" .. ops.walk(points, timeout)
end
-- Floor-edge scan along a polyline: every 3 studs, the floor 3.5 studs either side; a side lower by
-- more than 4 studs (or no floor) is an edge the walked line passes.
function ops.edges(points, side)
	side = side or 3.5
	local out, count = {}, 0
	for k = 1, #points - 1 do
		local a, b = Vector3.new(points[k][1], 0, points[k][2]), Vector3.new(points[k + 1][1], 0, points[k + 1][2])
		local dir = (b - a).Unit
		local n = Vector3.new(-dir.Z, 0, dir.X)
		for s = 0, (b - a).Magnitude, 3 do
			local p = a + dir * s
			local y = floorY(p.X, p.Z, 4)
			for _, sign in { -1, 1 } do
				local q = p + n * side * sign
				local y2 = floorY(q.X, q.Z, (y or 0) + 4)
				if y and (y2 == nil or y - y2 > 4) then
					count += 1
					if #out < 12 then table.insert(out, string.format("edge at (%.0f,%.0f) side %d: floor %.1f -> %s", p.X, p.Z, sign, y, if y2 then string.format("%.1f", y2) else "none")) end
				end
			end
		end
	end
	return string.format("edge samples %d\n%s", count, table.concat(out, "\n"))
end
-- Eye-height sightline from each point to a target: clear, or the first part in the way.
function ops.sight(points, tx, ty, tz)
	local c = body()
	params.FilterDescendantsInstances = { c }
	local out = {}
	for _, pt in points do
		local y = (floorY(pt[1], pt[2], 4) or 0) + 5
		local from = Vector3.new(pt[1], y, pt[2])
		local hit = workspace:Raycast(from, Vector3.new(tx, ty, tz) - from, params)
		table.insert(out, string.format("(%.0f,%.0f) -> %s", pt[1], pt[2], if hit then "blocked by " .. hit.Instance:GetFullName() else "clear"))
	end
	return table.concat(out, "\n")
end

local old = player.PlayerScripts:FindFirstChild("WalkQA")
if old then old:Destroy() end
local fn = Instance.new("BindableFunction")
fn.Name = "WalkQA"
fn.OnInvoke = function(op, ...)
	local handler = ops[op]
	if not handler then return "unknown op" end
	local ok, a = pcall(handler, ...)
	return if ok then a else "error: " .. tostring(a)
end
fn.Parent = player.PlayerScripts
print("[WalkQA] walker ready")
