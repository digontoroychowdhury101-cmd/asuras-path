--!nonstrict
-- Ticket 08 follow-up: the preserved mechanics that test_recovery_lifecycle, test_opening_tutorial, test_route_foundry,
-- test_campaign_ledger and test_monastery_* protect, run against the LIVE overworld (Overworld.Active = true, real src).
-- Those suites still run on the archived corridor (tools/legacy_world.py); this one proves the same rules hold on the
-- overworld: death/bloodstain/wake/fall catch, the opening tutorial at its glade spawn, the BambooRidge gate and the
-- forge cache in the Saltreach, lore/caches/Codex on overworld placements, and the stand-ins for removed mob/boss/warden
-- assertions. Checks named "DEFECT(...)" fail on purpose: they report a real src problem, they are not weakened.
-- Full encounter placement (mob roster per region) is ticket 09; only the spawns that exist today are asserted here.
-- Run: python3 tools/lune_compat.py tools/test_live_world_mechanics.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox") :: any
local Rig = require("./rig_scene")
local O = require("../src/shared/Overworld") :: any
local World = require("../src/shared/WorldDefinitions") :: any
local Store = require("../src/server/ProfileStore") :: any
local Schema = require("../src/shared/ProfileSchema") :: any
local Rules = require("../src/shared/TutorialRules") :: any
local Protocol = require("../src/infrastructure/IntentProtocol") :: any
local Gates = require("../src/shared/RouteGates") :: any
local Arsenal = require("../src/shared/ArsenalCatalog") :: any
local Narrative = require("../src/shared/NarrativeCatalog") :: any
local Inventory = require("../src/simulation/ArsenalInventory") :: any
local Armor = require("../src/shared/ArmorRules") :: any
local Progress = require("../src/shared/ProgressionRules") :: any
local V3, CF = roblox.Vector3, roblox.CFrame

local passed, failed = 0, 0
local function check(name: string, condition: any)
	if condition then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local function src(path: string): string return fs.readFile(path) end
local function count(t: any): number local n = 0 for _ in t do n += 1 end return n end
local function vec(p: any): any return V3.new(p.X, p.Y, p.Z) end
local function flatDist(a: any, b: any): number return math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2) end
local function inside(b: any, x: number, y: number, z: number): boolean
	return math.abs(x - b.Center.X) <= b.Size.X / 2 and math.abs(y - b.Center.Y) <= b.Size.Y / 2 and math.abs(z - b.Center.Z) <= b.Size.Z / 2
end

assert(O.Active == true, "this suite is the live-world run: Overworld.Active must be true")
local glade = World.Altars.Altar_MonasteryGate
local gladeSpawn = vec(glade.Spawn)

---------------------------------------------------------------------------------------------------------------------
-- 1. Recovery lifecycle (death, wake point, fall catch, bloodstain) on the overworld altars.
---------------------------------------------------------------------------------------------------------------------
local ROOT_HEIGHT = 3
local ORIGIN = V3.new(0, 600, 900) -- Sanctuary layout origin (SanctuaryService ORIGIN)
local LIMITS = { Radius = 1300, FloorY = ORIGIN.Y - 40 } -- SanctuaryService CATCH_RADIUS / CATCH_DEPTH
local ENGINE_DEFAULT = V3.new(0, 100, 0)
local env = setmetatable({ Vector3 = V3, CFrame = CF }, { __index = _G }) :: any
for _, name in { "math", "table", "string", "type", "setmetatable", "tostring" } do env[name] = (getfenv() :: any)[name] end
local Recovery = luau.load(src("src/server/RecoveryRules.luau"), { debugName = "RecoveryRules", environment = env })() :: any
local function cf(p: any): any return CF.new(p.X, p.Y, p.Z) * CF.Angles(0, math.rad(p.Yaw or 0), 0) end
local function flat(p: any): number return V3.new(p.X - ORIGIN.X, 0, p.Z - ORIGIN.Z).Magnitude end

check("engine default spawn is unclaimed by any live region", World.regionAt(ENGINE_DEFAULT.X, ENGINE_DEFAULT.Y, ENGINE_DEFAULT.Z) == nil)
local altarCount = 0
for id, altar in World.Altars do
	altarCount += 1
	local spawn = cf(altar.Spawn)
	local floorY = if altar.Region == "Sanctuary" then ORIGIN.Y else altar.Placement.Y
	local probe = function(origin: any, direction: any): any
		local bottom = origin + direction
		return if floorY <= origin.Y and floorY >= bottom.Y then V3.new(origin.X, floorY, origin.Z) else nil
	end
	local target = Recovery.standing(spawn, ROOT_HEIGHT, probe)
	check(id .. " stands on its floor", math.abs(target.Position.Y - (floorY + ROOT_HEIGHT)) < 1e-6)
	check(id .. " keeps facing", (target.LookVector - spawn.LookVector).Magnitude < 1e-6)
	check(id .. " wake point lies in its own region", World.regionAt(target.Position.X, target.Position.Y, target.Position.Z) == altar.Region)
	local hold = Recovery.begin(target, 10)
	check(id .. " holds at target", Recovery.check(hold, target.Position, 10.1) == "Hold")
	check(id .. " corrects engine displacement", Recovery.check(hold, ENGINE_DEFAULT, 10.2) == "Correct")
	check(id .. " releases after settle", Recovery.check(hold, target.Position, 10 + Recovery.SETTLE_SECONDS) == "Release")
	local state = { Aloft = false }
	check(id .. " displaced settling body not caught", not Recovery.sanctuaryFall(state, nil, flat(ENGINE_DEFAULT), ENGINE_DEFAULT.Y, true, LIMITS))
	local region = World.regionAt(target.Position.X, target.Position.Y, target.Position.Z)
	check(id .. " standing body not caught", not Recovery.sanctuaryFall(state, region, flat(target.Position), target.Position.Y, false, LIMITS))
	-- Travel lands within resting reach of every overworld altar (F04); only the lobby bonfire's spawn sits outside it.
	local anchor = vec(altar.Placement)
	local arrived = Recovery.arrival(vec(altar.Spawn), anchor, altar.Radius)
	check(id .. " travel arrives within resting reach", (arrived - anchor).Magnitude <= altar.Radius + 2)
	if altar.Region ~= "Sanctuary" then check(id .. " spawn already inside resting reach", (vec(altar.Spawn) - anchor).Magnitude <= altar.Radius + 2) end
end
check("every live altar covered (9 overworld + lobby)", altarCount == count(World.Altars) and altarCount == 10)
-- Fall catch: only the lobby catches, and no overworld region can ever sit inside its catch disc.
local fall = { Aloft = false }
check("lobby plaza standing not caught", not Recovery.sanctuaryFall(fall, "Sanctuary", 10, 603, false, LIMITS))
check("fall from the lobby caught", Recovery.sanctuaryFall(fall, "Sanctuary", 10, 540, false, LIMITS))
check("portal arrival at the glade clears aloft", not Recovery.sanctuaryFall(fall, "Forest", flat(gladeSpawn), glade.Spawn.Y, false, LIMITS) and fall.Aloft == false)
check("ravine and mountain heights are never caught", not Recovery.sanctuaryFall({ Aloft = false }, "GoldenRavine", flat(V3.new(-5990, 100, -3000)), 100, false, LIMITS)
	and not Recovery.sanctuaryFall({ Aloft = false }, "MountainAscent", flat(V3.new(-8300, 280, -4700)), 280, false, LIMITS))
check("a fall off the overworld edge is not a lobby fall", not Recovery.sanctuaryFall({ Aloft = false }, nil, flat(V3.new(-12000, -300, -3000)), -300, false, LIMITS))
for id, region in World.Regions do
	if id ~= "Sanctuary" then
		local b = region.Bounds
		local nx = math.clamp(ORIGIN.X, b.Center.X - b.Size.X / 2, b.Center.X + b.Size.X / 2)
		local nz = math.clamp(ORIGIN.Z, b.Center.Z - b.Size.Z / 2, b.Center.Z + b.Size.Z / 2)
		check("region " .. id .. " lies outside the lobby catch disc", math.sqrt((nx - ORIGIN.X) ^ 2 + (nz - ORIGIN.Z) ^ 2) > LIMITS.Radius)
	end
end
local life = { Life = 1, DeathLife = 0 }
check("one penalty per life", Recovery.claimDeath(life) and not Recovery.claimDeath(life) and (Recovery.spawned(life) == nil) and Recovery.claimDeath(life))

-- Bloodstain through the real store, with overworld regions and coordinates.
local mock: { [string]: any } = {}
local function newStore(owner: string, source: any?, clock: any?): any
	return Store.new(source or {
		UpdateAsync = function(_: any, key: string, callback: (any) -> any): any
			local value = callback(Store.Copy(mock[key]))
			if value ~= nil then mock[key] = Store.Copy(value) end
			return Store.Copy(value)
		end,
	}, Schema, { owner = owner, now = clock or os.time, wait = function() end, attempts = 1, leaseSeconds = 600 })
end
local store = newStore("test")
local id = 7
assert(store:Load(id), "profile load")
local carried = store:Souls(id).essence
local ok, _, dropped = store:RecordDeath(id, "Forest", glade.Placement.X, glade.Placement.Y, glade.Placement.Z, 45)
check("death in the Forest drops carried plus unbanked", ok and dropped == carried + 45 and store:Souls(id).essence == 0)
local first = store:Souls(id).world.bloodstain
check("stain records the Forest death point", first ~= nil and first.death == 1 and first.essence == carried + 45 and first.x == glade.Placement.X and first.z == glade.Placement.Z)
local _, _, again = store:RecordDeath(id, "Forest", -3000, 140, -2000, 0)
check("dying again with nothing carried forfeits the stain", again == 0 and store:Souls(id).world.bloodstain == nil and not (store:RecoverBloodstain(id, first.death)))
store:RecordDeath(id, "MountainAscent", -8300, 280, -4700, 30)
local stain = store:Souls(id).world.bloodstain
local _, _, recovered = store:RecoverBloodstain(id, stain.death)
check("recovery returns the mountain stain once", recovered == 30 and store:Souls(id).essence == 30 and not (store:RecoverBloodstain(id, stain.death)))
check("the starting altar survives deaths", store:Souls(id).world.activeAltar == World.startingAltar().Id)
assert(store:ActivateAltar(id, "Altar_BellTerrace", true, true))
store:Release(id)
local rejoined = newStore("next", store.dataStore, function() return os.time() + 10000 end)
assert(rejoined:Load(id), "rejoin load")
check("rejoin keeps the later overworld altar active", rejoined:Souls(id).world.activeAltar == "Altar_BellTerrace")
check("rejoin keeps essence without a duplicate stain", rejoined:Souls(id).essence == 30 and rejoined:Souls(id).world.bloodstain == nil)

-- The real WorldService wake-region handler (unparented body keeps its region) against overworld altars.
do
	local source = src("src/server/Services/WorldService.luau")
	local firstAt = assert(string.find(source, "local function onCharacterSpawned(", 1, true))
	local last = assert(string.find(source, "\nlocal function hooks(", firstAt, true))
	local root = { Position = gladeSpawn }
	local published, attributes = 0, {} :: { [string]: any }
	local player = { SetAttribute = function(_, key: string, value: any) attributes[key] = value end }
	local s = { Life = 3, DeathLife = 3, Region = "Forest", Player = player }
	local fakes = setmetatable({
		Recovery = Recovery, World = World,
		Characters = { GetEntity = function() return nil end, Entities = function() return { [7] = { Root = root } } end },
		session = function() return s end, entityPosition = function() return nil end, publish = function() published += 1 end,
	}, { __index = env }) :: any
	local spawned = luau.load("local Recovery, World, Characters, session, entityPosition, publish = Recovery, World, Characters, session, entityPosition, publish\n"
		.. string.sub(source, firstAt, last) .. "\nreturn onCharacterSpawned", { debugName = "WorldService.onCharacterSpawned", environment = fakes })() :: any
	attributes.AsuraRegion = "Forest"
	spawned(7, "Player")
	check("unparented respawn at the glade keeps the Forest wake region", s.Region == "Forest" and attributes.AsuraRegion == "Forest")
	check("unparented respawn opens a new life", s.Life == 4 and published == 1)
	root.Position = vec(World.Altars.Altar_RavineOverlook.Spawn)
	spawned(7, "Player")
	check("respawn at a later altar publishes that region", s.Region == "GoldenRavine" and attributes.AsuraRegion == "GoldenRavine")
	root.Position = vec(World.Altars.Altar_SanctuaryBonfire.Spawn)
	spawned(7, "Player")
	check("respawn in the lobby publishes Sanctuary", s.Region == "Sanctuary" and attributes.AsuraRegion == "Sanctuary")
end

---------------------------------------------------------------------------------------------------------------------
-- 2. Opening tutorial and Sparring Phantom at the glade.
---------------------------------------------------------------------------------------------------------------------
local phantomSpawn = assert(World.spawnById("DM_Sparring_Phantom"), "phantom spawn")
local HOME = vec(phantomSpawn.Placement)
local cues, spawnedCount, attrs, listener, handler, loop = {}, 0, {}, nil, nil, nil
local profile = { souls = Store.DefaultSouls(nil) }
local function transact(_, fn)
	local copy = Store.Copy(profile)
	fn(copy)
	local valid, why = Store.ValidateSouls(copy.souls)
	if valid then profile = copy end
	return valid, why
end
local player = { UserId = 7, SetAttribute = function(_, k, v) attrs[k] = v end, GetAttribute = function(_, k) return attrs[k] end }
local fighter = { KOProtected = false }
local entities = { [7] = { Root = { Position = gladeSpawn }, Fighter = fighter, Model = { GetAttribute = function() return nil end } } }
local phantom = { Root = { Position = HOME }, Fighter = {}, Model = { Tag = nil, GetAttribute = function(self) return self.Tag end } }
entities[-50] = phantom
local now = 100
local fakeTask = { wait = function() error("yield") end, spawn = function(f, ...) if not loop then loop = f else f(...) end end }
local tenv = {
	game = { GetService = function(_, name)
		if name == "Players" then return { GetPlayers = function() return { player } end, PlayerRemoving = { Connect = function() return { Disconnect = function() end } end } } end
		return { WaitForChild = function() return { Shared = { TutorialRules = Rules, IntentProtocol = Protocol, WorldDefinitions = World },
			Net = { WaitForChild = function() return { OnServerEvent = { Connect = function(_, f) handler = f; return { Disconnect = function() end } end } } end } } end }
	end },
	script = { Parent = {
		CharacterService = { Subscribe = function(f) listener = f; return function() end end, GetEntity = function(i) return entities[i] end, Now = function() return now end,
			Cue = function(kind, i, data) table.insert(cues, { Kind = kind, Id = i, Data = data }) end },
		AIService = { SpawnMob = function() spawnedCount += 1 end },
		PersistenceService = { Get = function() return profile end, Transaction = transact },
	} },
	require = function(m) return m end, task = fakeTask, os = os, math = math, table = table, string = string, type = type, tostring = tostring,
	tonumber = tonumber, next = next, pcall = pcall, warn = function() end, assert = assert, Vector3 = V3, setmetatable = setmetatable,
}
local Service = luau.load(src("src/server/Services/TutorialService.luau"), { debugName = "TutorialService", environment = tenv })()
Service.Start()
local function poll() pcall(loop) end
local function event(kind, source, target) listener({ Kind = kind, Source = source, Target = target, Value = 0 }, nil) end
poll()
check("fresh profile starts training at step 1 at the glade", attrs.AsuraTutorial == "" and Rules.current(Rules.parse(attrs.AsuraTutorial)).Id == "LockOn")
check("the glade altar spawn lies inside the non-lethal sparring ring", (gladeSpawn - HOME).Magnitude <= Service.RingRadius and fighter.KOProtected == true)
check("phantom is kept available for a player resting at the altar", spawnedCount >= 1)
event("Hit", 7, -50)
check("a hit before locking on does not skip ahead", attrs.AsuraTutorial == "")
handler(player, { action = "Signal", signal = "Light" })
check("client cannot claim a combat step", attrs.AsuraTutorial == "")
handler(player, { action = "Signal", signal = "LockOn" })
check("lock-on report advances its own step", attrs.AsuraTutorial == "LockOn")
fighter.State, fighter.Move = "Active", { Kind = "Light" }; event("Hit", 7, -50); fighter.State, fighter.Move = "Idle", nil
check("a landed hit advances Light and persists", attrs.AsuraTutorial == "LockOn,Light" and profile.souls.world.tutorial.Light == true)
event("Block", -50, 7); event("DeflectSpark", 7, -50)
fighter.State = "Dashing"; event("Evade", 7, -50); fighter.State = "Idle"; event("Rally", 7, 7)
check("guard, deflect, dodge, rally advance in turn", attrs.AsuraTutorial == "LockOn,Light,Guard,Deflect,Dodge,Rally")
attrs.AsuraElixirs = 3; poll(); attrs.AsuraElixirs = 2; poll()
check("a spent gourd charge advances Heal", string.find(attrs.AsuraTutorial, "Heal", 1, true) ~= nil)
phantom.Model.Tag = string.format("Perilous|Unarmed_Art|%.3f", now + 0.3)
fighter.State = "Dashing"; event("Evade", 7, -50); fighter.State = "Idle"
check("evading a published perilous strike advances Perilous", string.find(attrs.AsuraTutorial, "Perilous", 1, true) ~= nil)
event("Deathblow", 7, -50)
handler(player, { action = "Signal", signal = "Glide" })
check("deathblow and glide finish the training", attrs.AsuraTutorial == "Complete" and profile.souls.world.tutorial.Complete == true)
poll()
check("finishing mid-fight stays safe until the player walks out of the ring", fighter.KOProtected == true)
entities[7].Root.Position = HOME + V3.new(0, 0, Service.RingRadius + 18); poll()
check("ring protection lifts on leaving", fighter.KOProtected == false)
entities[7].Root.Position = gladeSpawn; poll()
check("the ring is not safe to come back to once training is done", fighter.KOProtected == false)
handler(player, { action = "Replay" })
check("replay restarts from step 1 and persists", attrs.AsuraTutorial == "" and next(profile.souls.world.tutorial) == nil)
handler(player, { action = "Skip" })
check("skip persists", attrs.AsuraTutorial == "Skipped" and profile.souls.world.tutorial.Skipped == true)
check("veteran save (Cloister kindled) starts complete on the overworld altar id", World.Altars.Altar_DesecratedCloister ~= nil
	and Service.initial({ world = { tutorial = nil, altars = { Altar_DesecratedCloister = true }, bosses = {} } }).Complete == true)
check("fresh record starts empty", next(Service.initial({ world = { tutorial = {}, altars = { Altar_SanctuaryBonfire = true }, bosses = {} } })) == nil)
Service.Destroy()

-- The phantom itself, its landing and its gentleness on the overworld.
local mob = World.Mobs.SparringPhantom
check("phantom spawn is in the Forest, inside its region, patrol included", phantomSpawn.Region == "Forest" and inside(World.Regions.Forest.Bounds, HOME.X, HOME.Y, HOME.Z))
check("phantom sits at the Overworld.Training placement", HOME.X == O.Training.Placement.X and HOME.Z == O.Training.Placement.Z and phantomSpawn.Region == O.Training.Region)
check("phantom does not notice someone resting at the glade altar", flatDist(HOME, glade.Placement) - glade.Radius > mob.AI.SightRange and mob.AI.LeashRange < 30)
local patrolOk = #phantomSpawn.Patrol > 0
for _, point in phantomSpawn.Patrol do patrolOk = patrolOk and flatDist(point, HOME) <= mob.AI.PatrolRadius + 1 and inside(World.Regions.Forest.Bounds, point.X, point.Y, point.Z) end
check("phantom patrol stays on the landing", patrolOk)
check("phantom pays nothing and is gentle", mob.Essence == 0 and mob.Stats.StrengthScale < 0.5 and mob.Weapon == "Unarmed")
check("its weapon art is the unblockable lesson", require("../src/simulation/WeaponSchema").get("Unarmed").WeaponArt.Unblockable == true and mob.AI.ArtChance > 0.2)
check("kills of a zero-essence mob grant nothing", string.find(src("src/server/Services/WorldService.luau"), "if not agent or agent.Essence <= 0 then return end", 1, true) ~= nil)
local first = Narrative.Lore[Narrative.LoreOrder[1]]
check("first memorial is the Pillars tablet on its overworld placement in the Forest", Narrative.LoreOrder[1] == "Pillars" and first.Region == "Forest"
	and first.X == O.Lore.Pillars.Position.X and World.regionAt(first.X, first.Y, first.Z) == "Forest")
check("TutorialController finds the phantom through the world spawn id", string.find(src("src/client/Controllers/TutorialController.luau"), 'World.spawnById("DM_Sparring_Phantom")', 1, true) ~= nil)
-- DEFECT(ticket 09, cosmetic): the opening handoff names the retired place.
check("DEFECT(PrologueController.luau:30) handoff names the live training altar '" .. glade.Name .. "'", string.find(src("src/client/Controllers/PrologueController.luau"), glade.Name, 1, true) ~= nil)
-- The stakes card shows once the player leaves the glade training area (flat distance from the phantom home > StakesRadius)
-- inside the Overworld frame before kindling an altar beyond the glade; never at the landing, the phantom or the lobby.
do
	local tc = src("src/client/Controllers/TutorialController.luau")
	local radius = tonumber(string.match(tc, "Controller%.StakesRadius = (%d+)"))
	local function stakesShows(p: any): boolean
		local F = O.Frame
		local dx, dz = p.X - HOME.X, p.Z - HOME.Z
		return p.X >= F.MinX and p.X <= F.MaxX and p.Z >= F.MinZ and p.Z <= F.MaxZ and math.sqrt(dx * dx + dz * dz) > radius
	end
	local terrace = vec(World.Altars.Altar_BellTerrace.Placement)
	check("stakes card reads the overworld frame, not monastery coordinates", radius ~= nil and string.find(tc, "Overworld.Frame", 1, true) ~= nil and string.find(tc, "COURTYARD_Z", 1, true) == nil)
	check("stakes card stays hidden at the glade landing and the phantom", radius ~= nil and not stakesShows(gladeSpawn) and not stakesShows(HOME))
	check("stakes card shows past the radius on the way to the first altar beyond the glade", radius ~= nil and stakesShows(terrace))
	check("stakes card never shows in the lobby", radius ~= nil and not stakesShows(V3.new(0, 10, 0)))
end
-- DEFECT: the relocated spawns place the root at ground level, the old spawn() convention is root = floor + 3.
for _, entry in World.Spawns do
	local p = entry.Placement
	check(string.format("DEFECT(WorldDefinitions.luau:651-655) %s root stands >= 3 above the terrain (%.2f above)", entry.Id, p.Y - O.heightAt(p.X, p.Z)), p.Y - O.heightAt(p.X, p.Z) >= ROOT_HEIGHT - 0.01)
end

---------------------------------------------------------------------------------------------------------------------
-- 3. Route gate and forge cache.
---------------------------------------------------------------------------------------------------------------------
check("a fresh profile finds the ridge gate shut", not Gates.isOpen({ unlockedAltars = {}, defeatedBosses = {}, routeFlags = {} }, "BambooRidge"))
check("kindling the glade, terrace and cloister does not open it", not Gates.isOpen({ unlockedAltars = { Altar_MonasteryGate = true, Altar_BellTerrace = true, Altar_DesecratedCloister = true }, defeatedBosses = {}, routeFlags = {} }, "BambooRidge"))
for _, altarId in Gates.List.BambooRidge.Past.Altars do
	check("gate Past altar " .. altarId .. " exists in the live world", World.Altars[altarId] ~= nil)
	check("kindling " .. altarId .. " opens the gate with no flag", Gates.isOpen({ unlockedAltars = { [altarId] = true }, defeatedBosses = {} }, "BambooRidge"))
end
check("the saved flag opens it; an unknown gate and garbage stay shut", Gates.isOpen({ routeFlags = { BambooRidge = true } }, "BambooRidge") and not Gates.isOpen({ routeFlags = { Nope = true } }, "Nope")
	and not Gates.isOpen(nil, "BambooRidge") and not Gates.isOpen({ routeFlags = 3, unlockedAltars = 4, defeatedBosses = 5 }, "BambooRidge"))
check("a save with Baize at rest finds it open although Baize is archived", World.Bosses.VenerableBaize.Inactive == true and Gates.isOpen({ unlockedAltars = {}, defeatedBosses = { VenerableBaize = true } }, "BambooRidge"))
local lock
for _, e in O.Edges do if e.Lock == "BambooRidge" then lock = e end end
check("the overworld shortcut is locked by this gate between live altars", lock ~= nil and Gates.List[lock.Lock] ~= nil and World.Altars[lock.A] ~= nil and World.Altars[lock.B] ~= nil and lock.Kind == "shortcut")
check("the client reads what the server sends", Gates.decode(Gates.encode({ routeFlags = { BambooRidge = true } })).BambooRidge == true and next(Gates.decode(Gates.encode({}))) == nil)
local raw = Schema.Default(1)
raw.routeFlags = nil
raw.unlockedAltars.Altar_BambooShrine = true
raw.defeatedBosses.TwinSentinels = true -- archived boss: an old save keeps its record
local migrated = Schema.Migrate(raw, 1)
check("an old save migrates with empty route flags, validates, and finds the gate open from its progress", next(migrated.routeFlags) == nil and (Schema.Validate(migrated)) and Gates.isOpen(migrated, "BambooRidge"))
local saved = Schema.Default(1)
saved.routeFlags.BambooRidge = true
check("a saved flag survives migration; a fresh record starts shut", Schema.Migrate(saved, 1).routeFlags.BambooRidge == true and not Gates.isOpen(Schema.Default(1), "BambooRidge"))
local junk = Schema.Default(1)
junk.routeFlags = { [3] = "x" }
check("garbage route flags are dropped and the save still validates", next(Schema.Migrate(junk, 1).routeFlags) == nil and (Schema.Validate(Schema.Migrate(junk, 1))))
local routeService = src("src/server/Services/RouteGates.luau")
check("lifting asks the server where the player stands and writes only its own flag", string.find(routeService, "Service.canLift(e.Root.Position, gate)", 1, true) ~= nil
	and select(2, string.gsub(routeService, "Persistence.Transaction", "")) == 1 and string.find(routeService, "p.routeFlags[ID] = true", 1, true) ~= nil and string.find(routeService, "qiEssence", 1, true) == nil)
-- The kiln: moved to the Saltreach, still pays what Iron Oath costs, and only a first claim pays.
local kiln = Arsenal.Caches.FoundersKiln
check("the kiln pays materials", kiln and kiln.Materials.StarfallShard == 2 and kiln.Materials.SpiritIronOre == 3)
check("two shards buy Iron Oath's shard cost", Armor.Sets.IronOath.Material == "StarfallShard" and kiln.Materials.StarfallShard >= Armor.Sets.IronOath.Need)
check("the kiln stands in the Saltreach at its overworld placement", kiln.Region == "AridBasin" and kiln.X == O.Caches.FoundersKiln.Position.X and kiln.Z == O.Caches.FoundersKiln.Position.Z
	and World.regionAt(kiln.X, kiln.Y, kiln.Z) == "AridBasin" and World.Regions.AridBasin.Name == "The Saltreach")
local inv = Inventory.defaults()
inv.weapons = { Unarmed = true }
local before = count(inv.weapons)
check("the first kiln claim succeeds and grants no weapon", (Inventory.claim(inv, "FoundersKiln")) and count(inv.weapons) == before)
check("a second claim refuses; the claim survives migration", not Inventory.claim(inv, "FoundersKiln") and Inventory.migrate(inv).caches.FoundersKiln == true and Inventory.validate(Inventory.migrate(inv)))
local loot = src("src/server/Services/LootService.luau")
local claimBody = string.match(loot, "function Loot.Claim.-\nend") or ""
local refused = string.find(claimBody, "Inventory.claim(i,id);assert(ok,reason)", 1, true)
local paid = string.find(claimBody, "m[material]=", 1, true)
check("materials are paid after the refusal, inside the claim's transaction", refused and paid and refused < paid)
check("a cache claim needs no region: it keys on the id only", string.find(loot, "local c=Catalog.Caches[id];local e=canClaim(player.UserId)", 1, true) ~= nil)

---------------------------------------------------------------------------------------------------------------------
-- 4. Lore, caches and the Codex on overworld placements.
---------------------------------------------------------------------------------------------------------------------
local lobbyCaches = 0
for cid, cache in Arsenal.Caches do if cache.Region == "Sanctuary" then lobbyCaches += 1 end end
check("nine inscriptions; the six overworld caches plus the lobby's own", count(Narrative.Lore) == 9 and count(O.Caches) == 6 and count(O.Lore) == 9 and count(Arsenal.Caches) == 6 + lobbyCaches)
for lid, lore in Narrative.Lore do
	local at = O.Lore[lid]
	if at then
		check("lore " .. lid .. " sits on its overworld placement", lore.Region == at.Region and lore.X == at.Position.X and lore.Y == at.Position.Y and lore.Z == at.Position.Z)
		check("lore " .. lid .. " lies inside its live region", World.Regions[lore.Region] ~= nil and World.regionAt(lore.X, lore.Y, lore.Z) == lore.Region)
	else
		check("lore " .. lid .. " is the one authored in the Sanctuary lobby", lore.Region == "Sanctuary" and World.regionAt(lore.X, lore.Y, lore.Z) == "Sanctuary")
	end
end
for cid, cache in Arsenal.Caches do
	local at = O.Caches[cid]
	if at then
		check("cache " .. cid .. " sits on its overworld placement", cache.Region == at.Region and cache.X == at.Position.X and cache.Y == at.Position.Y and cache.Z == at.Position.Z)
	else
		check("cache " .. cid .. " is a lobby cache", cache.Region == "Sanctuary")
	end
	check("cache " .. cid .. " lies inside its live region", World.regionAt(cache.X, cache.Y, cache.Z) == cache.Region)
	check("cache " .. cid .. " has a reward", next(cache.Spells or {}) ~= nil or next(cache.Materials or {}) ~= nil or cache.Weapon ~= nil or cache.Armor ~= nil or cache.Essence ~= nil)
end
local hermit = Narrative.NPCs.Hermit
local hut
for _, poi in O.POIs do if poi.Id == "HermitHut" then hut = poi end end
check("the Hermit stands at his hut", hut ~= nil and hermit.X == hut.Position.X and hermit.Z == hut.Position.Z and World.regionAt(hermit.X, hermit.Y, hermit.Z) ~= nil)
-- The real LootWorld builds a chest and prompt at every cache's overworld position.
do
	roblox.implementProperty("ProximityPrompt", "Triggered", function() return { Connect = function() return { Disconnect = function() end } end } end)
	for _, class in { "Part", "TrussPart" } do
		roblox.implementProperty(class, "Position", function(p) return p.CFrame.Position end, function(p, v) p.CFrame = CF.new(v) * p.CFrame.Rotation end)
	end
	local workspace = roblox.Instance.new("Folder")
	local shared = { WaitForChild = function() return { Shared = { ArsenalCatalog = Arsenal, WorldDefinitions = World, InputMap = Rig.load("src/shared/InputMap.luau", {}), Overworld = O } } end }
	shared.AsurasPath = shared:WaitForChild()
	local game = { GetService = function(_, n) return if n == "Workspace" then workspace else shared end }
	Rig.load("src/server/Services/LootWorld.luau", { game = game }).build(function() end, function() end)
	local chests = {}
	for _, d in workspace:GetDescendants() do
		if d:IsA("BasePart") then pcall(function() local at = (d :: any).Position; if at then d.CFrame = CF.new(at) * d.CFrame.Rotation end end) end
		if d:GetAttribute("CacheId") then chests[d:GetAttribute("CacheId")] = d end
	end
	for cid, cache in Arsenal.Caches do
		local chest = chests[cid]
		check("LootWorld places chest " .. cid .. " on the overworld", chest ~= nil and (chest.CFrame.Position - V3.new(cache.X, cache.Y, cache.Z)).Magnitude < 0.01 and chest:FindFirstChildOfClass("ProximityPrompt") ~= nil)
	end
end
-- Discovery pays once and survives a rejoin; the Codex counts the nine inscriptions.
do
	local db = {}
	local doubled = { UpdateAsync = function(_, key, fn)
		fn(Store.Copy(db[key]))
		local result = fn(Store.Copy(db[key]))
		if result ~= nil then db[key] = Store.Copy(result) end
		return Store.Copy(result)
	end }
	local clock = 1000
	local engine = Store.new(doubled, Schema, { owner = "Ledger", now = function() return clock end, wait = function() end, attempts = 2, leaseSeconds = 180 })
	local uid = 4242
	assert(engine:Load(uid))
	local qi = engine:Get(uid).qiEssence
	local expected = qi
	for _, lid in Narrative.LoreOrder do
		assert(engine:Transaction(uid, function(p) Progress.discover(p, lid, Narrative.Lore[lid].Qi) end))
		assert(engine:Transaction(uid, function(p) Progress.discover(p, lid, Narrative.Lore[lid].Qi) end))
		expected += Narrative.Lore[lid].Qi
	end
	check("every overworld inscription is recorded, each paying once", engine:Get(uid).qiEssence == expected)
	for cid, cache in Arsenal.Caches do
		local claimed = engine:Transaction(uid, function(p) assert(Inventory.claim(p.souls.inventory, cid)) end)
		local again = engine:Transaction(uid, function(p) assert(Inventory.claim(p.souls.inventory, cid)) end)
		check("cache " .. cid .. " claims once", claimed and not again and (cache.Weapon == nil or engine:Get(uid).souls.inventory.weapons[cache.Weapon]))
	end
	assert(engine:Release(uid)); clock += 5; assert(engine:Load(uid))
	local after = engine:Get(uid)
	local kept = after.qiEssence == expected
	for _, lid in Narrative.LoreOrder do kept = kept and after.inventory.LoreEntries[lid] == true end
	for cid in Arsenal.Caches do kept = kept and after.souls.inventory.caches[cid] == true end
	check("rejoin keeps inscriptions, caches and essence", kept)
	local function load(path: string, e: { [string]: any }): any
		e.Vector3, e.table, e.math, e.string, e.type, e.require = V3, table, math, string, type, function(m) return m end
		return luau.load(src(path), { debugName = path, environment = e })()
	end
	local Ending = load("src/shared/EndingRules.luau", {})
	local Codex = load("src/client/Controllers/CodexView.luau", { game = { GetService = function() return { AsurasPath = { Shared = {
		NarrativeCatalog = Narrative, WorldDefinitions = World, InputMap = require("../src/shared/InputMap"), EndingRules = Ending } } } end } })
	local summary = Codex.summary({ inventory = after.inventory, bosses = after.defeatedBosses, story = after.souls.world.story })
	check("Codex counts all nine inscriptions on the overworld", summary.Found == 9)
	local fresh = Codex.summary({ inventory = Schema.Default(1).inventory, bosses = {}, story = {} })
	check("a fresh Codex has found nothing and rested no sovereign", fresh.Found == 0 and fresh.Rested == 0)
end

---------------------------------------------------------------------------------------------------------------------
-- 5. Replacements for the removed mob / archived boss / warden assertions.
---------------------------------------------------------------------------------------------------------------------
-- (a) Mob placement: every live spawn (warden, phantom and the ticket 09 encounters) is held to the archetype, region and clearance rules;
-- the per-biome encounter placement, floor and leash checks live in tools/test_overworld_encounters.luau.
check("every spawn's archetype exists in the mob catalog", (function() for _, e in World.Spawns do if World.Mobs[e.Mob] == nil then return false end end return true end)())
for _, entry in World.Spawns do
	local region = World.Regions[entry.Region]
	local p = entry.Placement
	check("spawn " .. entry.Id .. " lies inside its live region", region ~= nil and inside(region.Bounds, p.X, p.Y, p.Z) and World.regionAt(p.X, p.Y, p.Z) == entry.Region)
	local sight = World.Mobs[entry.Mob].AI.SightRange
	for aid, altar in World.Altars do
		check(string.format("spawn %s clear of %s's rest ring beyond its sight", entry.Id, aid), flatDist(p, altar.Placement) - altar.Radius > sight or altar.Region ~= entry.Region)
	end
	for rid, ring in O.Rings do
		check("spawn " .. entry.Id .. " clear of ring " .. rid, flatDist(p, ring) > 60)
	end
end
-- (b) Archived bosses: no gate, no built arena, never spawned.
for bid, boss in World.Bosses do
	if boss.Inactive then
		check("archived " .. bid .. " has no fog gate", World.FogGates[boss.FogGate] == nil)
		local reserved = O.ReservedArenas[bid]
		check("archived " .. bid .. " arena is only the reserved footprint", reserved ~= nil and boss.Arena.Center.X == reserved.Arena.Center.X and boss.Arena.Center.Z == reserved.Arena.Center.Z)
		check("archived " .. bid .. " is no mob spawn", (function() for _, e in World.Spawns do if e.Mob == bid or e.Mob == boss.Id then return false end end return true end)())
	end
end
check("every fog gate belongs to a live boss, so nothing can start an archived fight", (function()
	for _, gate in World.FogGates do local boss = World.Bosses[gate.Boss]; if not boss or boss.Inactive then return false end end
	return true
end)())
check("arena and arena-lighting builders skip archived bosses", string.find(src("src/server/Services/BossArenas.luau"), "if boss.Inactive then continue end", 1, true) ~= nil
	and string.find(src("src/server/Services/ArenaLighting.luau"), "if boss.Inactive then continue end", 1, true) ~= nil)
check("Shen keeps the gate flow: one gate, inside the domain", count(World.FogGates) == 1 and World.Bosses.GrandmasterShen.Inactive == nil and World.regionAt(World.FogGates.Gate_AshColosseum.Inside.X, World.FogGates.Gate_AshColosseum.Inside.Y, World.FogGates.Gate_AshColosseum.Inside.Z) == "AshColosseum"
	and World.regionAt(World.FogGates.Gate_AshColosseum.Outside.X, World.FogGates.Gate_AshColosseum.Outside.Y, World.FogGates.Gate_AshColosseum.Outside.Z) ~= "AshColosseum")
-- (c) Warden: home and leash re-expressed. The old zone leash is gone; the generic home leash (AIService) is what holds it now.
local wardenSpawn = assert(World.spawnById("DM_Warden_Graves"), "warden spawn")
local warden = World.Mobs[wardenSpawn.Mob]
local site = O.Minibosses.HollowBellWarden
check("warden stands in the Forest at its Overworld.Minibosses placement", wardenSpawn.Mob == "HollowBellWarden" and wardenSpawn.Region == "Forest" and site.Region == "Forest"
	and wardenSpawn.Placement.X == site.Placement.X and wardenSpawn.Placement.Z == site.Placement.Z and World.regionAt(wardenSpawn.Placement.X, wardenSpawn.Placement.Y, wardenSpawn.Placement.Z) == "Forest")
check("the Hollow-Bell Warden is the only warden, and its reward flag is intact", count((function() local t = {} for _, e in World.Spawns do if e.Mob == "HollowBellWarden" then t[e.Id] = true end end return t end)()) == 1
	and warden.Reward.Flag == "HollowBellWarden" and warden.Reward.ElixirCapacity == true)
local leashEdge = World.Regions.Forest.Bounds
local reach = warden.AI.LeashRange + warden.AI.SightRange
check("warden's leash disc stays inside the Forest", wardenSpawn.Placement.X - reach >= leashEdge.Center.X - leashEdge.Size.X / 2 and wardenSpawn.Placement.X + reach <= leashEdge.Center.X + leashEdge.Size.X / 2
	and wardenSpawn.Placement.Z - reach >= leashEdge.Center.Z - leashEdge.Size.Z / 2 and wardenSpawn.Placement.Z + reach <= leashEdge.Center.Z + leashEdge.Size.Z / 2)
local leashed = true
for aid, altar in World.Altars do
	if altar.Region == "Forest" then leashed = leashed and flatDist(wardenSpawn.Placement, altar.Placement) - altar.Radius > warden.AI.LeashRange end
end
check("no altar rest ring lies within the warden's leash, so resting never drags it", leashed)
local ai = src("src/server/Services/AIService.luau")
check("the generic home leash still returns a foe past LeashRange to its home", string.find(ai, "homeDistance > profile.LeashRange or fled", 1, true) ~= nil and string.find(ai, "moveTo(agent, agent.Home.Position)", 1, true) ~= nil)
check("the old zone leash is guarded off, not run, on the overworld", string.find(ai, "if World.Regions.DesecratedMonastery then", 1, true) ~= nil and World.Regions.DesecratedMonastery == nil)

print(string.format("live world mechanics: %d passed, %d failed", passed, failed))
if failed > 0 then error("live world mechanics regression failed") end
