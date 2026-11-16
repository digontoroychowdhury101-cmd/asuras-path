--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/OverworldTerrainCompute
-- Pure terrain-tile computation for OverworldTerrain: no Instances, no services, so it runs in an Actor (OverworldTerrainWorker)
-- or inline on the main thread (the fallback, and every offline test). A tile is sampled once per column (height, road,
-- channel and chasm weights, material), the shell bottom of each column is taken from the cached heights, and only the
-- voxels that exist (occupancy >= 0.02, plus lake water) are packed, column by column, into one buffer:
--   header (24 bytes): u16 nx, u16 nz, f32 floor, i32 kMin, i32 kMax, u32 solid, u32 reserved (the worker stores its compute microseconds here)
--   column table, nx * nz entries (c = i * nz + j): i16 lo (voxel index of the first voxel), u16 count
--   voxel stream, per column in order, count x { u8 material id, u8 occupancy * 255 }
-- A voxel index k spans world Y 4k .. 4k + 4 (centre 4k + 2); the Y grid is world aligned, as WriteVoxels needs.
-- The hot kernels are @native and allocate nothing: heights and weights live in flat module arrays sized for a full tile.
-- Rows are the slice unit: step() runs after each row of samples, materials or columns (the caller yields there).
local Compute = {}

local RES = 4
local SHELL = 8 -- studs of solid below the lowest of a column and its 8 neighbours (C3 ruling 1a)
local HEADER = 24
local MAXN = 32 -- columns per tile side (128 studs / 4)
local STRIDE = MAXN + 2

-- Material ids in the buffer. 0 = Air, 1 = Water, then the Enum.Material names regionMaterial can return.
local NAMES = { "Air", "Water", "Ground", "Limestone", "Slate", "Sandstone", "Rock", "Mud", "LeafyGrass", "Grass", "Sand", "Salt", "Glacier", "Snow", "Basalt" }
local IDS: { [string]: number } = {}
for id, name in NAMES do
	IDS[name] = id - 1
end
Compute.Materials = NAMES -- id + 1 -> name
Compute.Header = HEADER

local H: { number } = table.create(STRIDE * STRIDE, 0) -- height at each column centre, margin of one column all round
local RW: { number } = table.create(STRIDE * STRIDE, 0)
local CW: { number } = table.create(STRIDE * STRIDE, 0)
local KW: { number } = table.create(STRIDE * STRIDE, 0)
local MID: { number } = table.create(MAXN * MAXN, 0)
local scratch = buffer.create(65536)
local solidCount, kMin, kMax = 0, 0, 0

@native
local function sampleRow(O: any, x0: number, z0: number, nz: number, i: number, pads: any)
	local x = x0 + (i + 0.5) * RES
	local base = (i + 1) * STRIDE + 1
	for j = -1, nz do
		local h, r, c, k = O.sampleAt(x, z0 + (j + 0.5) * RES, pads)
		local at = base + j
		H[at], RW[at], CW[at], KW[at] = h, r, c, k
	end
end

@native
local function materialRow(O: any, x0: number, z0: number, nz: number, i: number)
	local x = x0 + (i + 0.5) * RES
	local base = (i + 1) * STRIDE + 1
	for j = 0, nz - 1 do
		local at = base + j
		local h = H[at]
		local dx, dz = H[at + STRIDE] - h, H[at + 1] - h
		local slope = math.sqrt(dx * dx + dz * dz) / RES
		local name = O.materialAt(x, z0 + (j + 0.5) * RES, h, slope, RW[at], CW[at], KW[at])
		local id = IDS[name]
		if not id then error("unknown terrain material " .. tostring(name)) end
		MID[i * nz + j + 1] = id
	end
end

-- Packs column row i; returns the stream cursor and the lowest shell bottom of the row.
@native
local function packRow(nz: number, i: number, waterY: number, cur: number, lowest: number): (number, number)
	local base = (i + 1) * STRIDE + 1
	for j = 0, nz - 1 do
		local at = base + j
		local h = H[at]
		local low = h
		for di = -1, 1 do
			local row = at + di * STRIDE
			for dj = -1, 1 do
				local v = H[row + dj]
				if v < low then low = v end
			end
		end
		local bottom = low - SHELL
		if bottom < lowest then lowest = bottom end
		local lake = h < waterY and KW[at] == 0
		local m = MID[i * nz + j + 1]
		local top = if lake then waterY else h
		local k0 = math.floor((bottom - 2) / RES) - 1
		local k1 = math.ceil((top - 2) / RES) + 1
		if cur + (k1 - k0 + 1) * 2 > buffer.len(scratch) then
			local bigger = buffer.create(buffer.len(scratch) * 2)
			buffer.copy(bigger, 0, scratch, 0, cur)
			scratch = bigger
		end
		local lo, count = 0, 0
		for k = k0, k1 do
			local yc = k * RES + 2
			local occ = math.min(math.clamp((h - yc) / RES + 0.5, 0, 1), math.clamp((yc - bottom) / RES + 0.5, 0, 1))
			local mat: number, o: number = 0, 0
			if occ >= 0.02 then
				mat, o = m, occ
				if occ < 0.5 and lake then
					local w = math.clamp((waterY - yc) / RES + 0.5, 0, 1)
					if w > occ then mat, o = 1, w end
				end
			elseif lake and yc < waterY then
				mat, o = 1, math.clamp((waterY - yc) / RES + 0.5, 0, 1)
			end
			if mat ~= 0 then
				if count == 0 then
					lo = k
				else
					-- an air gap inside a column is kept as Air with zero occupancy (the formulas never produce one)
					for _ = lo + count, k - 1 do
						buffer.writeu16(scratch, cur, 0)
						cur += 2
					end
				end
				buffer.writeu8(scratch, cur, mat)
				buffer.writeu8(scratch, cur + 1, math.floor((o :: number) * 255 + 0.5))
				cur += 2
				count = k - lo + 1
				solidCount += 1
				if k < kMin then kMin = k end
				if k > kMax then kMax = k end
			end
		end
		local c = i * nz + j
		buffer.writei16(scratch, HEADER + c * 4, lo)
		buffer.writeu16(scratch, HEADER + c * 4 + 2, count)
	end
	return cur, lowest
end

-- Computes one tile (nx x nz columns at RES studs, minimum corner x0, z0). pads: the pad list that reaches the tile
-- (Overworld.padsNear), nil for all. times (optional) receives SampleMs, MaterialMs, ShellMs (the pack phase).
-- Returns the buffer and the tile floor (lowest shell bottom).
function Compute.tile(O: any, x0: number, z0: number, nx: number, nz: number, waterY: number, pads: any?, step: (() -> ())?, times: { [string]: number }?): (buffer, number)
	assert(nx <= MAXN and nz <= MAXN and nx >= 1 and nz >= 1, "tile larger than 128 studs")
	local clock = os.clock
	local t0 = clock()
	for i = -1, nx do
		sampleRow(O, x0, z0, nz, i, pads)
		if step then step() end
	end
	local t1 = clock()
	for i = 0, nx - 1 do
		materialRow(O, x0, z0, nz, i)
		if step then step() end
	end
	local t2 = clock()
	solidCount, kMin, kMax = 0, math.huge, -math.huge
	local cur, lowest = HEADER + nx * nz * 4, math.huge
	for i = 0, nx - 1 do
		cur, lowest = packRow(nz, i, waterY, cur, lowest)
		if step then step() end
	end
	local t3 = clock()
	buffer.writeu16(scratch, 0, nx)
	buffer.writeu16(scratch, 2, nz)
	buffer.writef32(scratch, 4, lowest)
	buffer.writei32(scratch, 8, if solidCount > 0 then kMin else 0)
	buffer.writei32(scratch, 12, if solidCount > 0 then kMax else -1)
	buffer.writeu32(scratch, 16, solidCount)
	buffer.writeu32(scratch, 20, 0)
	local out = buffer.create(cur)
	buffer.copy(out, 0, scratch, 0, cur)
	if times then
		times.SampleMs = (t1 - t0) * 1000
		times.MaterialMs = (t2 - t1) * 1000
		times.ShellMs = (t3 - t2) * 1000
	end
	return out, lowest
end

return Compute
