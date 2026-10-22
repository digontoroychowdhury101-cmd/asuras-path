--!nonstrict
-- Test helper (not a test): character-height reachability over RegionLayout boxes, run by the
-- plain Luau CLI. Floors are the tops of solid boxes; a body is a 5-stud column with a 1.6-stud
-- footprint; a cell is 2 studs. Two movement models:
--   Walk: steps of up to 2.2 studs (stairs rise 1) and any drop - the main route must need nothing more.
--   Jump: also climbs up to 6 studs onto an adjacent floor and clears gaps of up to 6 studs landing
--         no higher than 2 studs above take-off - the deliberate optional traversal, no double jump.
-- Not modelled: physics, glide, double jump, the camera, uploaded meshes and terrain voxels.
local Walk = {}
Walk.CELL, Walk.BODY, Walk.STEP, Walk.JUMP, Walk.GAP = 2, 5, 2.2, 6, 6

local HASH = 8
local function key(i, j) return i * 65536 + j end

local function corners(b)
	local a = math.rad(b.Yaw)
	local c, s = math.cos(a), math.sin(a)
	local hx, hz = b.SX / 2, b.SZ / 2
	local ex, ez = math.abs(c) * hx + math.abs(s) * hz, math.abs(s) * hx + math.abs(c) * hz
	return b.X - ex, b.X + ex, b.Z - ez, b.Z + ez
end

local function inside(b, x, y, z)
	if math.abs(y - b.Y) > b.SY / 2 then return false end
	local a = math.rad(b.Yaw)
	local c, s = math.cos(a), math.sin(a)
	local lx, lz = x - b.X, z - b.Z
	return math.abs(lx * c - lz * s) <= b.SX / 2 and math.abs(lx * s + lz * c) <= b.SZ / 2
end
Walk.inside = inside

-- `boxes`: RegionLayout boxes (Kind "Veil" collides but is never a floor).
function Walk.world(boxes, x0, x1, z0, z1)
	local w = { Boxes = boxes, Hash = {}, X0 = x0, X1 = x1, Z0 = math.min(z0, z1), Z1 = math.max(z0, z1), Floors = {} }
	for _, b in boxes do
		local ax, bx, az, bz = corners(b)
		for i = math.floor(ax / HASH), math.floor(bx / HASH) do
			for j = math.floor(az / HASH), math.floor(bz / HASH) do
				local k = key(i, j)
				w.Hash[k] = w.Hash[k] or {}
				table.insert(w.Hash[k], b)
			end
		end
	end
	return setmetatable(w, { __index = Walk })
end

function Walk:near(x, z) return self.Hash[key(math.floor(x / HASH), math.floor(z / HASH))] or {} end

function Walk:solidAt(x, y, z)
	for _, b in self:near(x, z) do
		if b.Kind ~= "Decor" and inside(b, x, y, z) then return b end
	end
	return nil
end

-- Is the body column standing at (x, y, z) free?
function Walk:clear(x, y, z)
	for _, o in { { 0, 0 }, { 0.8, 0.8 }, { -0.8, 0.8 }, { 0.8, -0.8 }, { -0.8, -0.8 } } do
		for _, h in { 2.4, 3.4, 4.6 } do -- anything lower is a step the body walks onto
			if self:solidAt(x + o[1], y + h, z + o[2]) then return false end
		end
	end
	return true
end

-- Standable floor heights in the column at (x, z), low to high.
function Walk:floorsAt(x, z)
	local found = {}
	for _, b in self:near(x, z) do
		if b.Kind ~= "Veil" and b.Kind ~= "Decor" then
			local top = b.Y + b.SY / 2
			if inside(b, x, top - 0.01, z) and self:clear(x, top, z) then table.insert(found, top) end
		end
	end
	table.sort(found)
	return found
end

function Walk:cell(i, j)
	local k = key(i, j)
	local f = self.Floors[k]
	if f == nil then
		f = self:floorsAt(i * Walk.CELL + 0.37, j * Walk.CELL + 0.37)
		self.Floors[k] = f
	end
	return f
end

local function lane(self, ax, az, bx, bz, y)
	for _, t in { 0.25, 0.5, 0.75 } do
		local x, z = ax + (bx - ax) * t, az + (bz - az) * t
		for _, h in { 2.4, 3.6, 4.6 } do
			if self:solidAt(x, y + h, z) then return false end
		end
	end
	return true
end

-- Breadth-first reach from a point; returns a set keyed "i,j,y" and a lookup function.
-- `links` are one-way climbs the grid cannot express (a truss ladder): {ax, ay, az, bx, by, bz}.
function Walk:reach(x, y, z, mode, links)
	local C = Walk.CELL
	local function snap(v) return math.floor(v / C + 0.5) end
	local seen, queue, head = {}, {}, 1
	local function push(i, j, fy)
		local id = i .. "," .. j .. "," .. math.floor(fy * 10 + 0.5)
		if not seen[id] then seen[id] = fy; table.insert(queue, { i, j, fy }) end
	end
	local si, sj = snap(x), snap(z)
	local best = nil
	for _, fy in self:cell(si, sj) do if math.abs(fy - y) < 3 then best = fy end end
	if not best then return nil end
	push(si, sj, best)
	while head <= #queue do
		local q = queue[head]; head += 1
		local i, j, fy = q[1], q[2], q[3]
		for _, link in links or {} do
			if snap(link[1]) == i and snap(link[3]) == j and math.abs(link[2] - fy) < 1.5 then
				for _, ny in self:cell(snap(link[4]), snap(link[6])) do
					if math.abs(ny - link[5]) < 1.5 then push(snap(link[4]), snap(link[6]), ny) end
				end
			end
		end
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			for reachCells = 1, (if mode == "Jump" then Walk.GAP / C + 1 else 1) do
				local ni, nj = i + d[1] * reachCells, j + d[2] * reachCells
				local nx, nz = ni * C + 0.37, nj * C + 0.37
				if nx < self.X0 or nx > self.X1 or nz < self.Z0 or nz > self.Z1 then break end
				for _, ny in self:cell(ni, nj) do
					local rise = ny - fy
					local ok = if reachCells == 1 then (rise <= Walk.STEP or (mode == "Jump" and rise <= Walk.JUMP)) else (rise <= 2 and rise >= -4)
					if ok and lane(self, i * C + 0.37, j * C + 0.37, nx, nz, math.max(fy, ny)) then
						push(ni, nj, ny)
					end
				end
				-- A gap jump only carries on over cells with no floor near take-off height.
				local blocked = false
				for _, ny in self:cell(ni, nj) do if ny > fy - 3 then blocked = true end end
				if blocked then break end
			end
		end
	end
	local set = { Seen = seen, Count = #queue }
	-- Was a floor within `tolerance` of py reached in the cell at (px, pz) or one beside it?
	function set.has(px, py, pz, tolerance)
		local i, j = snap(px), snap(pz)
		for di = -1, 1 do for dj = -1, 1 do
			local f = self:cell(i + di, j + dj)
			for _, ny in f do
				if math.abs(ny - py) <= (tolerance or 1.5) and seen[(i + di) .. "," .. (j + dj) .. "," .. math.floor(ny * 10 + 0.5)] then return true end
			end
		end end
		return false
	end
	return set
end

return Walk
