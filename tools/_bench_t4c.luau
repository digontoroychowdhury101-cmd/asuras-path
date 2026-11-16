--!nonstrict
-- THROWAWAY (T4): Compute.tile only. work/bin/luau/luau.exe [--codegen] tools/_bench_t4c.luau
local O = require("../src/shared/Overworld")
local C = require("../src/server/Services/OverworldTerrainCompute")
local F = O.Frame
local g = O.Altars[O.Gateway].Placement
O.terrainData()
local picks = {}
local gi, gj = math.floor((g.X - F.MinX) / 128), math.floor((g.Z - F.MinZ) / 128)
for di = -1, 1 do for dj = -1, 1 do table.insert(picks, { gi + di, gj + dj }) end end
local idx = 0
for i = 0, 65 do for j = 0, 65 do
	if idx % 16 == 0 then table.insert(picks, { i, j }) end
	idx += 1
end end

-- T3 reference (copied compute of writeTile: 2D tables, per-voxel fill over every 64-stud slab, no write)
local function oldTile(x0, z0, nx, nz)
	local t = {}
	local c = os.clock
	local a = c()
	local hs, roadW, channelW, chasmW = {}, {}, {}, {}
	local minH, maxH = math.huge, -math.huge
	for i = -1, nx do
		hs[i], roadW[i], channelW[i], chasmW[i] = {}, {}, {}, {}
		for j = -1, nz do
			local h, r, cc, k = O.sampleAt(x0 + (i + 0.5) * 4, z0 + (j + 0.5) * 4)
			hs[i][j], roadW[i][j], channelW[i][j], chasmW[i][j] = h, r, cc, k
			if i >= 0 and i < nx and j >= 0 and j < nz then minH, maxH = math.min(minH, h), math.max(maxH, h) end
		end
	end
	local b = c(); t.SampleMs = (b - a) * 1000
	local mats = table.create(nx)
	for i = 0, nx - 1 do
		mats[i + 1] = table.create(nz)
		for j = 0, nz - 1 do
			local h = hs[i][j]
			local slope = math.sqrt((hs[i + 1][j] - h) ^ 2 + (hs[i][j + 1] - h) ^ 2) / 4
			mats[i + 1][j + 1] = O.materialAt(x0 + (i + 0.5) * 4, z0 + (j + 0.5) * 4, h, slope, roadW[i][j], channelW[i][j], chasmW[i][j])
		end
	end
	local d = c(); t.MaterialMs = (d - b) * 1000
	local top = math.max(maxH, if minH < F.WaterY then F.WaterY else -math.huge)
	local bottoms, floor = table.create(nx), math.huge
	for i = 1, nx do
		bottoms[i] = table.create(nz)
		for j = 1, nz do
			local bb = O.shellBottom(hs, i - 1, j - 1, 8)
			bottoms[i][j] = bb
			if bb < floor then floor = bb end
		end
	end
	local e = c()
	local written = 0
	for y0 = math.floor((floor - 4) / 64) * 64, top, 64 do
		for i = 1, nx do
			for j = 1, nz do
				local h = hs[i - 1][j - 1]
				local lake = h < F.WaterY and chasmW[i - 1][j - 1] == 0
				local bottom = bottoms[i][j]
				for k = 1, 16 do
					local yc = y0 + (k - 0.5) * 4
					local occ = math.min(math.clamp((h - yc) / 4 + 0.5, 0, 1), math.clamp((yc - bottom) / 4 + 0.5, 0, 1))
					if occ >= 0.02 then
						if occ < 0.5 and lake then
							local w = math.clamp((F.WaterY - yc) / 4 + 0.5, 0, 1)
							if w > occ then written += 1 continue end
						end
						written += 1
					elseif lake and yc < F.WaterY then
						written += 1
					end
				end
			end
		end
	end
	t.ShellMs = (d - d) + (e - d) * 1000
	t.FillMs = (c() - e) * 1000
	t.Solid = written
	return t
end
if arg and false then end
local oldTot, oldSolid = { SampleMs = 0, MaterialMs = 0, ShellMs = 0, FillMs = 0 }, 0
local t1 = os.clock()
for _, p in picks do
	local r = oldTile(F.MinX + p[1] * 128, F.MinZ + p[2] * 128, 32, 32)
	for k in oldTot do oldTot[k] += r[k] end
	oldSolid += r.Solid
end
local nn = #picks
print(string.format("T3 REF  tiles %d  %.1f ms/tile  [sample %.1f, material %.1f, shell %.1f, fill %.1f]  solid/tile %.0f", nn, (os.clock() - t1) * 1000 / nn,
	oldTot.SampleMs / nn, oldTot.MaterialMs / nn, oldTot.ShellMs / nn, oldTot.FillMs / nn, oldSolid / nn))
local times, tot = {}, { SampleMs = 0, MaterialMs = 0, ShellMs = 0 }
local solid, bytes, worst = 0, 0, 0
local t0 = os.clock()
for _, p in picks do
	local x0, z0 = F.MinX + p[1] * 128, F.MinZ + p[2] * 128
	local a = os.clock()
	local buf = C.tile(O, x0, z0, 32, 32, F.WaterY, O.padsNear and O.padsNear(x0 - 4, z0 - 4, x0 + 132, z0 + 132) or nil, nil, times)
	worst = math.max(worst, os.clock() - a)
	for k, v in times do tot[k] += v end
	solid += buffer.readu32(buf, 16)
	bytes += buffer.len(buf)
end
local n = #picks
local all = (os.clock() - t0) * 1000 / n
print(string.format("COMPUTE tiles %d  %.1f ms/tile (worst %.0f)  [sample %.1f, material %.1f, pack %.1f]  solid/tile %.0f  bytes/tile %.0f",
	n, all, worst * 1000, tot.SampleMs / n, tot.MaterialMs / n, tot.ShellMs / n, solid / n, bytes / n))
