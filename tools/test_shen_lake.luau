--!nonstrict
-- Grandmaster Shen's lake trial (win-106, creator 27 Nov 2026): Shen leaves the Ash Colosseum and fights on the Bellwood lake.
-- He is absent until a player takes the relic in the colossal temple's upper hall; then a crack, a howling wind gathering at the
-- lake's base, and the stilled lake (walkable) holds him until someone steps into the arena.
-- Run: python3 tools/lune_compat.py tools/test_shen_lake.luau
local O = require("../src/shared/Overworld")
local L = require("../src/shared/LandmarkLayout")
local World = require("../src/shared/WorldDefinitions")
local Rules = require("../src/shared/ShenLakeRules")

local passed, failed = 0, 0
local function check(name: string, ok: any)
	if ok then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local function inside(b, p) return O.contains(b, p.X, p.Y, p.Z) end
local function count(t) local n = 0 for _ in t do n += 1 end return n end

local bw = L.Landmarks.Bellwood
local lake = O.shenLake()
local shen = World.Bosses.GrandmasterShen
local floor, water = L.basinLevels(bw)
check("the lake trial is data in Overworld", lake ~= nil and lake.Boss == "GrandmasterShen" and lake.Region == "Forest")

-- Shen moved: one live gate, the lake's; the summit colosseum stays as scenery with no fight.
check("Shen fights in the Bellwood", shen.Inactive == nil and shen.Region == "Forest" and shen.FogGate == "Gate_BellwoodLake")
check("one live gate, summoned, no summit gate", count(World.FogGates) == 1 and World.FogGates.Gate_BellwoodLake ~= nil
	and World.FogGates.Gate_BellwoodLake.Summons == true and World.FogGates.Gate_AshColosseum == nil)
check("summit barrier data kept as scenery", O.Barrier.Gate.Id == "Gate_AshColosseum" and O.Barrier.Arena ~= nil)
check("boss arena and spawn are the lake's", shen.Arena == lake.Arena and shen.Spawn == lake.BossSpawn)

-- The arena: open water in front of the colossal temple stair, inside the shore, in the Forest region.
local A = lake.Arena
local corners = {}
for _, s in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
	table.insert(corners, { X = A.Center.X + s[1] * A.Size.X / 2, Z = A.Center.Z + s[2] * A.Size.Z / 2 })
end
local shoreOk = true
for _, c in corners do shoreOk = shoreOk and L.basinEllipse(bw, c.X, c.Z, -20) < 1 end
check("arena inside the shore with 20 studs to spare", shoreOk)
check("arena is in the Forest region", O.regionAt(A.Center.X, water + 3, A.Center.Z) == "Forest")
check("arena is a large field (160+ a side)", A.Size.X >= 160 and A.Size.Z >= 160)
check("arena spans the water: bed under it, room to leap over it",
	A.Center.Y - A.Size.Y / 2 < floor - bw.Basin.Deep and A.Center.Y + A.Size.Y / 2 > water + 40)

-- Stilled water: Shen and the fighters stand on it.
local S = lake.BossSpawn
check("Shen spawns inside the arena", inside(A, S))
check("Shen stands on the stilled surface", math.abs((S.Y - 3) - lake.StillTop) < 1e-6 and lake.StillTop > water and lake.StillTop - water < 1)
local lx, lz = -math.sin(math.rad(S.Yaw)), -math.cos(math.rad(S.Yaw))
local tx, tz = lake.StairToe.X - S.X, lake.StairToe.Z - S.Z
check("Shen faces the temple stair", (lx * tx + lz * tz) / math.sqrt(tx * tx + tz * tz) > 0.95)
check("the vortex is the arena's centre on the water", math.abs(lake.Vortex.X - A.Center.X) < 1e-6 and math.abs(lake.Vortex.Z - A.Center.Z) < 1e-6
	and math.abs(lake.Vortex.Y - water) < 1e-6)

-- The way in: down the stair, along the causeway. Outside is on the causeway short of the arena, Inside on it within.
local G = lake.Gate
check("gate trigger covers the water surface", G.Trigger.Size.X == A.Size.X and G.Trigger.Size.Z == A.Size.Z
	and G.Boss == "GrandmasterShen" and G.Id == "Gate_BellwoodLake")
check("submerged swimmers do not start the fight", not inside(G.Trigger, { X = S.X, Y = water - 5, Z = S.Z }))
check("Inside is in the arena", inside(A, G.Inside))
check("Outside is out of the arena", not inside(A, G.Outside))
local function flat(a, b) return math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2) end
check("Outside is at the stair toe (causeway)", flat(G.Outside, lake.StairToe) <= 20)
check("Inside is on the causeway, 30-60 studs on from the toe", flat(G.Inside, lake.StairToe) >= 30 and flat(G.Inside, lake.StairToe) <= 60)

-- Clear of the gate towers and the colossal temple's base.
local gate = L.gateSpot(bw)
local nearestGate = math.huge
for _, c in corners do nearestGate = math.min(nearestGate, flat(c, gate)) end
local gx = math.clamp(gate.X, A.Center.X - A.Size.X / 2, A.Center.X + A.Size.X / 2)
local gz = math.clamp(gate.Z, A.Center.Z - A.Size.Z / 2, A.Center.Z + A.Size.Z / 2)
check("arena clear of the gate towers' footprint", flat({ X = gx, Z = gz }, gate) >= bw.Basin.Gate.Radius)
check("stair toe is outside the arena", not inside(A, { X = lake.StairToe.X, Y = water + 3, Z = lake.StairToe.Z }))

-- The relic: on the colossal temple's upper hall floor, far above the lake.
local temple = L.templeSpot(bw, bw.Basin.ColossalTemple)
check("relic stands on the upper hall floor", math.abs(lake.Relic.Y - (temple.Y + bw.Basin.ShenLake.Relic.Rise)) < 1e-6 and lake.Relic.Y - water > 100)
check("relic is inside the hall, behind the stair head", flat(lake.Relic, temple) <= 130 and flat(lake.Relic, lake.StairToe) > 300)

-- The objective leading to the relic is checked in tools/test_objectives_overworld.luau (it needs that harness's Objectives inline).

-- State machine: Dormant -> Summoning (relic) -> Stilled (after SummonSeconds) -> Fight (arena entered) -> Stilled (wipe) / Dormant (felled).
check("crack then wind, both inside the summoning", Rules.CrackAt > 0 and Rules.WindAt > Rules.CrackAt and Rules.SummonSeconds > Rules.WindAt)
check("relic summons only from Dormant", Rules.step("Dormant", "Relic", 0) == "Summoning" and Rules.step("Stilled", "Relic", 0) == "Stilled"
	and Rules.step("Fight", "Relic", 0) == "Fight")
check("summoning stills the lake on time", Rules.step("Summoning", "Tick", Rules.SummonSeconds - 0.1) == "Summoning"
	and Rules.step("Summoning", "Tick", Rules.SummonSeconds) == "Stilled")
check("only the stilled lake starts the fight", Rules.step("Stilled", "Enter", 0) == "Fight" and Rules.step("Dormant", "Enter", 0) == "Dormant"
	and Rules.step("Summoning", "Enter", 1) == "Summoning")
check("a wipe leaves Shen waiting in the storm", Rules.step("Fight", "Wipe", 0) == "Stilled")
check("Shen felled: the lake sleeps", Rules.step("Fight", "Felled", 0) == "Dormant")
check("no summoner left: the lake sleeps", Rules.step("Stilled", "Abandoned", 0) == "Dormant" and Rules.step("Summoning", "Abandoned", 1) == "Dormant"
	and Rules.step("Fight", "Abandoned", 0) == "Fight")
check("walkable only while stilled or fighting", Rules.walkable("Stilled") and Rules.walkable("Fight") and not Rules.walkable("Summoning")
	and not Rules.walkable("Dormant"))

print(string.format("shen lake: %d passed, %d failed", passed, failed))
if failed > 0 then error("shen lake checks failed") end
