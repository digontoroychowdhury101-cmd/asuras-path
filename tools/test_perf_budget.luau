--!nonstrict
-- Ticket 18: PerfBudget with fakes (plain Luau). Run: work/bin/luau/luau.exe tools/test_perf_budget.luau
local Perf = require("../src/server/Services/PerfBudget")

local passed, failed = 0, 0
local function check(name, ok)
	if ok then passed += 1 else failed += 1; print("FAIL " .. name) end
end

local function make(over)
	local state = { attrs = {}, warns = {}, logs = {}, counts = 0, waits = {}, spawned = 0, hbLinks = 0, hbLive = 0, mem = 50, parts = 100 }
	local hbFn
	local env = {
		folder = { SetAttribute = function(_, k, v) state.attrs[k] = v end },
		warn = function(s) table.insert(state.warns, s) end,
		log = function(s) table.insert(state.logs, s) end,
		memory = function() return state.mem end,
		entities = function() return { entities = 7, p95StepMs = 4 } end,
		terrain = function() return { Total = 10, Done = 4, Failed = 0 } end,
		count = function() state.counts += 1; return { Instances = 900, Regions = { Forest = state.parts } } end,
		heartbeat = { Connect = function(_, fn)
			hbFn = fn; state.hbLinks += 1; state.hbLive += 1
			return { Disconnect = function() state.hbLive -= 1 end }
		end },
		task = { spawn = function(fn) state.spawned += 1; state.loop = fn end, wait = function(s) table.insert(state.waits, s); if #state.waits >= 3 then state.perf.Alive = false end end },
	}
	for k, v in over or {} do env[k] = v end
	local perf = Perf.new(env)
	state.perf = perf
	state.beat = function(dt) hbFn(dt) end
	return perf, state
end

-- 1. Publishes attributes; heartbeat Hz comes from beats since the last sample.
do
	local perf, s = make()
	perf:Start()
	for _ = 1, 60 do s.beat(1 / 60) end
	perf:Sample()
	check("hz published", s.attrs.HeartbeatHz == 60)
	check("memory + counts published", s.attrs.Mem_TerrainVoxels == 50 and s.attrs.Instances_Map == 900 and s.attrs.Parts_Forest == 100)
	check("terrain + entities published", s.attrs.TerrainDone == 4 and s.attrs.Entities == 7 and s.attrs.StepP95Ms == 4)
end

-- 2. Cadence: counts every COUNT_EVERY samples, log every LOG_EVERY samples.
do
	local perf, s = make()
	for _ = 1, Perf.LOG_EVERY do perf:Sample() end
	check("counts cadence", s.counts == math.ceil(Perf.LOG_EVERY / Perf.COUNT_EVERY))
	check("one log line per LOG_EVERY", #s.logs == 1 and s.logs[1]:find("hb=", 1, true) ~= nil)
end

-- 2b. Overworld.Stats().Failed is the error text: published as 1, never fed to round() as a string.
do
	local perf, s = make({ terrain = function() return { Total = 10, Done = 4, Failed = "boom" } end })
	perf:Sample()
	check("string Failed becomes 1", s.attrs.TerrainFailed == 1)
end

-- 3. Breach warns once per key; Min budget (heartbeat) and per-region parts budget both apply.
do
	local perf, s = make()
	perf:Start()
	s.mem = 250; s.parts = 9000
	for _ = 1, 3 do s.beat(1 / 30) end
	for _ = 1, 4 do perf:Sample() end
	local voxel, hz, parts = 0, 0, 0
	for _, w in s.warns do
		if w:find("Mem_TerrainVoxels", 1, true) then voxel += 1 end
		if w:find("HeartbeatHz", 1, true) then hz += 1 end
		if w:find("Parts_Forest", 1, true) then parts += 1 end
	end
	check("voxel breach once", voxel == 1)
	check("heartbeat breach once", hz == 1)
	check("region parts breach once", parts == 1)
	local quiet, q = make()
	quiet:Sample(); quiet:Sample()
	check("no breach, no warn", #q.warns == 0)
end

-- 4. Loop yields only through task.wait(PERIOD); Stop ends it and disconnects the heartbeat link.
do
	local perf, s = make()
	perf:Start(); perf:Start()
	check("start idempotent", s.spawned == 1 and s.hbLinks == 1)
	s.loop()
	check("waits via task.wait at PERIOD", #s.waits == 3 and s.waits[1] == Perf.PERIOD)
	local p2, s2 = make()
	p2:Start()
	p2:Stop()
	check("stop disconnects", s2.hbLive == 0 and not p2.Alive and #p2.Links == 0)
	s2.loop()
	check("loop exits after stop", #s2.waits == 0 and not next(s2.attrs))
end

print(string.format("perf budget: %d passed, %d failed", passed, failed))
if failed > 0 then error("test_perf_budget failed") end
