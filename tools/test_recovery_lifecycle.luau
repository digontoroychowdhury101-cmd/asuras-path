--!strict
-- Lune regression for the checkpoint/death/recovery lifecycle (playtest findings #1, #18, #19).
-- Run from the project root: lune run tools/test_recovery_lifecycle.luau
-- Reproduces the observed failure (a later-altar respawn displaced to the engine default spawn and
-- returned to the Sanctuary bonfire by the fall safeguard) against the rules the runtime now uses.
-- Seeded rules/store emulation only; Studio placement and earned play remain separate checks.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox") :: any
local World = require("../src/shared/WorldDefinitions") :: any
local Store = require("../src/server/ProfileStore") :: any
local Schema = require("../src/shared/ProfileSchema") :: any

local Vector3, CFrame = roblox.Vector3, roblox.CFrame
local env = setmetatable({ Vector3 = Vector3, CFrame = CFrame }, { __index = _G }) :: any
for _, name in { "math", "table", "string", "type", "setmetatable", "tostring" } do
	env[name] = (getfenv() :: any)[name]
end
local Recovery = luau.load(fs.readFile("src/server/RecoveryRules.luau"), { debugName = "RecoveryRules", environment = env })() :: any

local passed, failed = 0, 0
local function check(name: string, condition: boolean)
	if condition then
		passed += 1
	else
		failed += 1
		print("FAIL " .. name)
	end
end

local ROOT_HEIGHT = 3
local ORIGIN = Vector3.new(0, 600, 900) -- Sanctuary layout origin
local LIMITS = { Radius = 1300, FloorY = ORIGIN.Y - 40 }
local ENGINE_DEFAULT = Vector3.new(0, 100, 0) -- LoadCharacter without a SpawnLocation
local function cf(p: any): any
	return CFrame.new(p.X, p.Y, p.Z) * CFrame.Angles(0, math.rad(p.Yaw or 0), 0)
end
local function flat(p: any): number
	return Vector3.new(p.X - ORIGIN.X, 0, p.Z - ORIGIN.Z).Magnitude
end
-- Pre-repair safeguard predicate, kept only to prove it explains the observation.
local function legacyCatch(p: any): boolean
	local region = World.regionAt(p.X, p.Y, p.Z)
	return (region == nil or region == "Sanctuary") and flat(p) < LIMITS.Radius and p.Y < LIMITS.FloorY
end

-- 1. Cause: the displaced body sits in no region, inside the catch radius, below the shrine.
check("default spawn is unclaimed", World.regionAt(ENGINE_DEFAULT.X, ENGINE_DEFAULT.Y, ENGINE_DEFAULT.Z) == nil)
check("legacy safeguard caught a displaced respawn", legacyCatch(ENGINE_DEFAULT))

-- 2. Every kindled altar: safe standing placement, displacement restored, never caught.
local altarCount = 0
for id, altar in World.Altars do
	altarCount += 1
	local spawn = cf(altar.Spawn)
	local floorY = if altar.Region == "Sanctuary" then ORIGIN.Y else 0
	local probe = function(origin: any, direction: any): any
		local bottom = origin + direction
		return if floorY <= origin.Y and floorY >= bottom.Y then Vector3.new(origin.X, floorY, origin.Z) else nil
	end
	local target = Recovery.standing(spawn, ROOT_HEIGHT, probe)
	check(id .. " stands on floor", math.abs(target.Position.Y - (floorY + ROOT_HEIGHT)) < 1e-6)
	check(id .. " keeps facing", (target.LookVector - spawn.LookVector).Magnitude < 1e-6)
	check(id .. " spawn in own region", World.regionAt(target.Position.X, target.Position.Y, target.Position.Z) == altar.Region)
	local hold = Recovery.begin(target, 10)
	check(id .. " holds at target", Recovery.check(hold, target.Position, 10.1) == "Hold")
	check(id .. " corrects engine displacement", Recovery.check(hold, ENGINE_DEFAULT, 10.2) == "Correct")
	check(id .. " short step is not corrected", Recovery.check(hold, target.Position + Vector3.new(20, 0, 0), 10.3) == "Hold")
	check(id .. " releases after settle", Recovery.check(hold, target.Position, 10 + Recovery.SETTLE_SECONDS) == "Release")
	-- Safeguard during and after respawn, starting from a body that died in a ground region.
	local state = { Aloft = false }
	check(id .. " displaced settling body not caught", not Recovery.sanctuaryFall(state, nil, flat(ENGINE_DEFAULT), ENGINE_DEFAULT.Y, true, LIMITS))
	local region = World.regionAt(target.Position.X, target.Position.Y, target.Position.Z)
	check(id .. " standing body not caught", not Recovery.sanctuaryFall(state, region, flat(target.Position), target.Position.Y, false, LIMITS))
end
local authored = 0
for _ in World.Altars do
	authored += 1
end
check("every altar covered", altarCount == authored and altarCount >= 5)
print("altars covered: " .. altarCount)
check("unknown floor keeps spawn", Recovery.standing(CFrame.new(1, 2, 3), ROOT_HEIGHT, function() return nil end).Position == Vector3.new(1, 2, 3))
local runaway = Recovery.begin(CFrame.new(0, 3, -728), 0)
for _ = 1, Recovery.MAX_CORRECTIONS do
	Recovery.check(runaway, ENGINE_DEFAULT, 0.1)
end
check("correction is bounded", Recovery.check(runaway, ENGINE_DEFAULT, 0.2) == "Release")

-- 3. Legitimate Sanctuary fall versus ground travel.
local fall = { Aloft = false }
check("plaza standing not caught", not Recovery.sanctuaryFall(fall, "Sanctuary", 10, 603, false, LIMITS))
check("fall from plaza caught", Recovery.sanctuaryFall(fall, "Sanctuary", 10, 540, false, LIMITS))
check("fast fall below bounds caught", Recovery.sanctuaryFall(fall, nil, 10, 300, false, LIMITS))
check("portal arrival clears aloft", not Recovery.sanctuaryFall(fall, "DesecratedMonastery", 1628, 3, false, LIMITS))
check("ground exterior not caught", not Recovery.sanctuaryFall(fall, nil, 1100, 3, false, LIMITS))

-- 4. One penalty per life.
local life = { Life = 1, DeathLife = 0 }
check("first death claimed", Recovery.claimDeath(life))
check("duplicate KO ignored", not Recovery.claimDeath(life))
Recovery.spawned(life)
check("next life claimable", Recovery.claimDeath(life))

-- 5. Bloodstain rules through the real store (mock DataStore): loss, recovery, die-again, zero.
local mock: { [string]: any } = {}
local store = Store.new({
	UpdateAsync = function(_: any, key: string, callback: (any) -> any): any
		local value = callback(Store.Copy(mock[key]))
		if value ~= nil then
			mock[key] = Store.Copy(value)
		end
		return Store.Copy(value)
	end,
} :: any, Schema, { owner = "test", now = os.time, wait = function() end, attempts = 1, leaseSeconds = 600 })
local id = 7
assert(store:Load(id), "profile load")
local carried = store:Souls(id).essence
local ok, _, dropped = store:RecordDeath(id, "DesecratedMonastery", 0, 3, -800, 45)
check("death drops carried plus unbanked", ok and dropped == carried + 45 and store:Souls(id).essence == 0)
local first = store:Souls(id).world.bloodstain
check("stain records death index", first ~= nil and first.death == 1 and first.essence == carried + 45)
local _, _, again = store:RecordDeath(id, "DesecratedMonastery", 0, 3, -900, 0)
check("die again with zero carried forfeits stain", again == 0 and store:Souls(id).world.bloodstain == nil)
check("forfeited stain cannot be recovered", not (store:RecoverBloodstain(id, first.death)))
store:RecordDeath(id, "DesecratedMonastery", 0, 3, -900, 30)
local stain = store:Souls(id).world.bloodstain
local _, _, recovered = store:RecoverBloodstain(id, stain.death)
check("recovery returns stain once", recovered == 30 and store:Souls(id).essence == 30)
check("second recovery refused", not (store:RecoverBloodstain(id, stain.death)))
check("active altar survives deaths", store:Souls(id).world.activeAltar == World.startingAltar().Id)
assert(store:ActivateAltar(id, "Altar_DesecratedCloister", true, true))
store:Release(id)
local rejoined = Store.new(store.dataStore, Schema, { owner = "next", now = function() return os.time() + 10000 end, wait = function() end, attempts = 1, leaseSeconds = 600 })
assert(rejoined:Load(id), "rejoin load")
check("rejoin keeps later active altar", rejoined:Souls(id).world.activeAltar == "Altar_DesecratedCloister")
check("rejoin keeps essence without duplicate", rejoined:Souls(id).essence == 30 and rejoined:Souls(id).world.bloodstain == nil)

-- Follow-up 02 (Studio): the spawned listener runs inside CharacterAdded before the engine parents
-- the body, so GetEntity (live bodies only) is nil while the placed root is already at the altar.
-- The real WorldService handler must keep the wake region instead of publishing nil.
do
	local source = fs.readFile("src/server/Services/WorldService.luau")
	local first = assert(string.find(source, "local function onCharacterSpawned(", 1, true))
	local last = assert(string.find(source, "\nlocal function hooks(", first, true))
	local function spawnOf(id: string): any
		local at = World.Altars[id].Spawn
		return Vector3.new(at.X, at.Y, at.Z)
	end
	local gate = spawnOf("Altar_MonasteryGate")
	local root = { Position = gate }
	local published, attributes = 0, {} :: { [string]: any }
	local player = { SetAttribute = function(_, key: string, value: any) attributes[key] = value end }
	local s = { Life = 3, DeathLife = 3, Region = "DesecratedMonastery", Player = player }
	local fakes = setmetatable({
		Recovery = Recovery, World = World,
		Characters = { GetEntity = function() return nil end, Entities = function() return { [7] = { Root = root } } end },
		session = function() return s end,
		entityPosition = function() return nil end,
		publish = function() published += 1 end,
	}, { __index = env }) :: any
	local spawned = luau.load("local Recovery, World, Characters, session, entityPosition, publish = Recovery, World, Characters, session, entityPosition, publish\n"
		.. string.sub(source, first, last) .. "\nreturn onCharacterSpawned", { debugName = "WorldService.onCharacterSpawned", environment = fakes })() :: any
	attributes.AsuraRegion = "DesecratedMonastery"
	spawned(7, "Player")
	check("unparented respawn keeps the wake region", s.Region == "DesecratedMonastery" and attributes.AsuraRegion == "DesecratedMonastery")
	check("unparented respawn opens a new life", s.Life == 4 and published == 1)
	root.Position = spawnOf("Altar_SanctuaryBonfire")
	spawned(7, "Player")
	check("respawn in another region publishes that region", s.Region == "Sanctuary" and attributes.AsuraRegion == "Sanctuary")
end

-- F04: travel to the Primal Bonfire landed on its spawn 20 studs out, refused to rest ("TooFar")
-- and left the previous checkpoint active. Travel now lands within resting reach of every altar.
local outOfReach, landed = {}, true
for id, altar in World.Altars do
	local spawn = Vector3.new(altar.Spawn.X, altar.Spawn.Y, altar.Spawn.Z)
	local anchor = Vector3.new(altar.Placement.X, altar.Placement.Y, altar.Placement.Z)
	if (spawn - anchor).Magnitude > altar.Radius + 2 then table.insert(outOfReach, id) end
	local at = Recovery.arrival(spawn, anchor, altar.Radius)
	landed = landed and (at - anchor).Magnitude <= altar.Radius + 2 and math.abs(at.Y - spawn.Y) < 1e-6
end
check("the Primal Bonfire's spawn is the one outside resting reach", #outOfReach == 1 and outOfReach[1] == "Altar_SanctuaryBonfire")
check("altar travel always arrives within resting reach, at spawn height", landed)
local gate = World.Altars.Altar_MonasteryGate
local gateSpawn = Vector3.new(gate.Spawn.X, gate.Spawn.Y, gate.Spawn.Z)
check("a spawn already in reach is used unchanged", Recovery.arrival(gateSpawn, Vector3.new(gate.Placement.X, gate.Placement.Y, gate.Placement.Z), gate.Radius) == gateSpawn)

print(string.format("recovery lifecycle: %d passed, %d failed", passed, failed))
if failed > 0 then
	error("recovery lifecycle regression failed")
end
