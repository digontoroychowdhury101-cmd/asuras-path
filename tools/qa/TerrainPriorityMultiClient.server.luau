--!nonstrict
-- Unmapped Studio-only harness (lane R2-5): overworld terrain tile priority with TWO real local clients far apart.
-- Evidence type: seeded Studio diagnostic (placement by teleport; the writer, Refocus/Priority, SiteReady flags and the
-- unwritten-ground guard are the live game). Measures, per player, the time from placement until the ground under them is
-- written (Terrain.Verdict nil and the site's Ready flag), server Heartbeat while writing, and OverworldTerrain.Stats.
-- Launch (local copy only, never saved): inject this script and a RemoteEvent "TerrainQA" in ReplicatedStorage (no client
-- script needed: Characters.Teleport moves the server-side character), then Test > Clients and Servers > Local Server,
-- 2 players, or StudioTestService:ExecuteMultiplayerTestAsync(2, {}). Results: "[TerrainMC] PASS|FAIL|INFO" lines and one
-- "[TerrainMC RESULT] {json}".
-- Config: PLACE_EARLY true = both are placed right after AsuraReady (the brief); an anchored hold keeps a player from
-- falling until his ground exists. The guard may still bounce an early-placed player to a ready altar once any altar is
-- ready (that is its job); a bounce is reported as FAIL and the harness puts the player back so measurement continues.
-- false = each player is placed only when his site is written (the real travel rule): no guard contact expected.
local PLACE_EARLY = true
local NEAR_ALTAR, FAR_ALTAR = "Altar_MonasteryGate", "Altar_BasinCistern" -- ~5900 studs apart
local ARRIVAL_TARGET = 90 -- seconds, per player (24a targets)
local HEARTBEAT_HZ, HEARTBEAT_FLOOR_HZ = 45, 30 -- mean of 1 s windows >= 45; no single window under 30
local MIN_SEPARATION = 3000

local Run = game:GetService("RunService")
if not Run:IsStudio() then return end
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local STS = game:GetService("StudioTestService")
local Http = game:GetService("HttpService")
if not RS:WaitForChild("TerrainQA", 15) then return end

local result = { kind = "Seeded Studio diagnostic: overworld tile priority, 2 local clients; no live service", checks = {}, infos = {} }
local function check(ok, name, details)
	table.insert(result.checks, { name = name, passed = ok == true, details = details })
	print(string.format("[TerrainMC] %s %s %s", if ok then "PASS" else "FAIL", name, if details ~= nil then Http:JSONEncode(details) else ""))
end
local function info(name, details) table.insert(result.infos, { name = name, details = details }); print(string.format("[TerrainMC] INFO %s %s", name, if details ~= nil then Http:JSONEncode(details) else "")) end

local ok, err = xpcall(function()
	local t0 = os.clock()
	local S = game.ServerScriptService.AsurasPath.Services
	local C = require(S.CharacterService)
	local Terrain = require(S.OverworldTerrain)
	local World = require(S.OverworldService)
	local O = require(RS.AsurasPath.Shared.Overworld)
	repeat task.wait(0.2) until (workspace:GetAttribute("AsuraReady") and #Players:GetPlayers() == 2) or os.clock() - t0 > 900
	local list = Players:GetPlayers(); table.sort(list, function(a, b) return a.UserId < b.UserId end)
	assert(#list == 2, "two players")
	local who = { { p = list[1], id = NEAR_ALTAR }, { p = list[2], id = FAR_ALTAR } }
	repeat task.wait(0.2) until (C.GetEntity(list[1].UserId) and C.GetEntity(list[2].UserId)) or os.clock() - t0 > 600
	local a, b = O.Altars[NEAR_ALTAR].Spawn, O.Altars[FAR_ALTAR].Spawn
	local separation = math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2)
	check(separation > MIN_SEPARATION, "targets are far apart", { studs = math.floor(separation), near = NEAR_ALTAR, far = FAR_ALTAR })
	local root = workspace:FindFirstChild(O.Root)
	local rescues0 = root and root:GetAttribute("Rescues") or 0
	local stats0 = table.clone(Terrain.Stats)
	local ready0 = { Glade = World.Ready("Glade"), Near = World.Ready(NEAR_ALTAR), Far = World.Ready(FAR_ALTAR) }
	info("at placement (seconds since harness start)", { t = os.clock() - t0, ready = ready0, tiles = Terrain.Stats.Tiles })

	local start = os.clock()
	for _, w in who do
		local s = O.Altars[w.id].Spawn
		w.target = Vector3.new(s.X, s.Y, s.Z)
		w.frame = CFrame.new(w.target) * CFrame.Angles(0, math.rad(s.Yaw), 0)
		w.placed, w.grounded, w.fell, w.rescued, w.exposed = false, nil, false, 0, 0
	end
	local function entity(w) return C.GetEntity(w.p.UserId) end
	local function place(w)
		w.placed = true
		C.Teleport(w.p.UserId, w.frame)
		local e = entity(w)
		if e then e.Root.Anchored = not World.Ready(w.id) end -- hold in the air until the ground exists
	end
	if PLACE_EARLY then for _, w in who do place(w) end end

	-- Heartbeat windows while the writer runs (until both are grounded plus 5 s, or the target plus margin).
	local windows, acc, n, windowStart = {}, 0, 0, os.clock()
	local hb = Run.Heartbeat:Connect(function(dt)
		acc += dt; n += 1
		if os.clock() - windowStart >= 1 then
			table.insert(windows, n / acc)
			acc, n, windowStart = 0, 0, os.clock()
		end
	end)
	local deadline = start + ARRIVAL_TARGET + 60
	local settleAt
	while os.clock() < deadline do
		for _, w in who do
			local e = entity(w)
			if e then
				if not w.placed and World.Ready(w.id) and Terrain.Verdict(w.target.X, w.target.Y, w.target.Z) == nil then place(w) end
				local p = e.Root.Position
				if w.placed and not w.grounded then
					if (p - w.target).Magnitude > 100 then -- bounced by the guard (or moved): count it and put the player back
						w.rescued += 1
						info("player displaced from target (guard rescue?)", { player = w.p.UserId, now = tostring(p), target = tostring(w.target), t = os.clock() - start })
						C.Teleport(w.p.UserId, w.frame)
						e.Root.Anchored = true
					elseif Terrain.Verdict(p.X, p.Y, p.Z) == nil and World.Ready(w.id) then
						w.grounded = os.clock() - start
						e.Root.Anchored = false
					elseif Terrain.Verdict(p.X, p.Y, p.Z) == "Unwritten" and not e.Root.Anchored then
						w.exposed += 1 -- free-standing over unwritten ground: must never happen
					end
				end
				if w.grounded and (Terrain.Verdict(p.X, p.Y, p.Z) == "Fell" or p.Y < w.target.Y - 60 or e.Fighter.State == "KO") then w.fell = true end
			end
		end
		if who[1].grounded and who[2].grounded and not settleAt then settleAt = os.clock() + 5 end -- watch 5 s after release for falls
		if settleAt and os.clock() >= settleAt then break end
		task.wait(0.25)
	end
	hb:Disconnect()
	for _, w in who do local e = entity(w); if e then e.Root.Anchored = false end end

	local stats = Terrain.Stats
	local rescued = (if root then root:GetAttribute("Rescues") else 0) - rescues0
	local minHz, sum = math.huge, 0
	for _, hz in windows do minHz = math.min(minHz, hz); sum += hz end
	local meanHz = if #windows > 0 then sum / #windows else 0
	for _, w in who do
		info("player result", { player = w.p.UserId, site = w.id, groundedSeconds = w.grounded, bounced = w.rescued, exposedSamples = w.exposed, fell = w.fell })
		check(w.grounded ~= nil and w.grounded <= ARRIVAL_TARGET, string.format("%s ground written within %d s", w.id, ARRIVAL_TARGET), w.grounded)
	end
	check(who[1].grounded ~= nil and who[2].grounded ~= nil and not who[1].fell and not who[2].fell, "both grounded without falls", { fellA = who[1].fell, fellB = who[2].fell })
	check(rescued == 0 and who[1].rescued == 0 and who[2].rescued == 0 and who[1].exposed == 0 and who[2].exposed == 0, "no player left on unwritten ground (guard verdicts: Rescues delta 0, no free-standing sample)", { rescuesDelta = rescued, bounced = { who[1].rescued, who[2].rescued }, exposed = { who[1].exposed, who[2].exposed }, early = PLACE_EARLY })
	check(#windows >= 5 and meanHz >= HEARTBEAT_HZ and minHz >= HEARTBEAT_FLOOR_HZ, string.format("server Heartbeat mean >= %d Hz, no window < %d Hz while writing", HEARTBEAT_HZ, HEARTBEAT_FLOOR_HZ), { windows = #windows, meanHz = math.floor(meanHz * 10) / 10, minHz = math.floor(minHz * 10) / 10 })
	info("OverworldTerrain.Stats during the run", {
		Tiles = stats.Tiles, Parallel = stats.Parallel - stats0.Parallel, Inline = stats.Inline - stats0.Inline, WriteCalls = stats.WriteCalls, WriteMs = stats.WriteMs, ComputeMs = stats.ComputeMs, YieldMs = stats.YieldMs,
		Done = World.Stats().Done, Total = World.Stats().Total, Failed = World.Stats().Failed })
	check(World.Stats().Failed == nil, "terrain generation did not fail", World.Stats().Failed)
end, debug.traceback)

result.passed = ok
result.error = if ok then nil else err
local failed = 0
for _, c in result.checks do if not c.passed then failed += 1 end end
result.failed = failed
if not ok then print("[TerrainMC] FAIL harness aborted " .. tostring(err)) end
local encoded = Http:JSONEncode(result)
print("[TerrainMC RESULT] " .. encoded)
pcall(function() STS:EndTest(encoded) end)
