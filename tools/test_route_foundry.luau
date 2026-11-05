--!nonstrict
-- Route batch: what the Foundry wing asks of saves and rewards. Old saves keep walking; a fresh save starts shut; a claimed kiln pays once,
-- whatever is reset or reopened. Local rules only: Studio geometry, input and live saves are separate.
local fs = require("@lune/fs")
local Gates = require("../src/shared/RouteGates")
local Catalog = require("../src/shared/ArsenalCatalog")
local Inventory = require("../src/simulation/ArsenalInventory")
local Armor = require("../src/shared/ArmorRules")
local Schema = require("../src/shared/ProfileSchema")
local World = require("../src/shared/WorldDefinitions")

local passed, failed = 0, 0
local function check(name, condition)
	if condition then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local function src(path) return fs.readFile(path) end

-- Gate rules: nothing opened, progress past it, and the saved flag.
check("a fresh profile finds the ridge gate shut", not Gates.isOpen({ unlockedAltars = {}, defeatedBosses = {}, routeFlags = {} }, "BambooRidge"))
check("kindling the earlier altars does not open it", not Gates.isOpen({ unlockedAltars = { Altar_MonasteryGate = true, Altar_DesecratedCloister = true, Altar_BellTerrace = true }, defeatedBosses = {}, routeFlags = {} }, "BambooRidge"))
check("a save past the shrine finds it open, with no flag and no routeFlags field", Gates.isOpen({ unlockedAltars = { Altar_BambooShrine = true }, defeatedBosses = {} }, "BambooRidge"))
check("a save past the Colosseum altar finds it open", Gates.isOpen({ unlockedAltars = { Altar_ColosseumAntechamber = true }, defeatedBosses = {} }, "BambooRidge"))
check("a save with Baize at rest finds it open", Gates.isOpen({ unlockedAltars = {}, defeatedBosses = { VenerableBaize = true } }, "BambooRidge"))
check("the saved flag opens it", Gates.isOpen({ unlockedAltars = {}, defeatedBosses = {}, routeFlags = { BambooRidge = true } }, "BambooRidge"))
check("an unknown gate is never open", not Gates.isOpen({ routeFlags = { Nope = true } }, "Nope"))
check("garbage is shut, not an error", not Gates.isOpen(nil, "BambooRidge") and not Gates.isOpen({ routeFlags = 3, unlockedAltars = 4, defeatedBosses = 5 }, "BambooRidge"))
local roundTrip = Gates.decode(Gates.encode({ routeFlags = { BambooRidge = true } }))
check("the client reads what the server sends", roundTrip.BambooRidge == true and next(Gates.decode(Gates.encode({}))) == nil and next(Gates.decode(nil)) == nil)

-- Existing altar ids and the Warden's standing are untouched.
for _, id in { "Altar_SanctuaryBonfire", "Altar_MonasteryGate", "Altar_DesecratedCloister", "Altar_BambooShrine", "Altar_ColosseumAntechamber" } do
	check(id .. " keeps its id", World.Altars[id] and World.Altars[id].Id == id)
end
check("the shrine altar's mark default is unchanged", World.Altars.Altar_BambooShrine.Mark == nil)
local wardens = 0
for _, s in World.Spawns do if s.Mob == "HollowBellWarden" then wardens += 1; check("the Warden stays in the grave field", s.Id == "DM_Warden_Graves") end end
check("no second Warden", wardens == 1)

-- The kiln: it pays what Iron Oath costs, and only a first claim pays.
local kiln = Catalog.Caches.FoundersKiln
check("the kiln pays materials", kiln and kiln.Materials.StarfallShard == 2 and kiln.Materials.SpiritIronOre == 3)
check("two shards buy Iron Oath's shard cost", Armor.Sets.IronOath.Material == "StarfallShard" and kiln.Materials.StarfallShard >= Armor.Sets.IronOath.Need)
check("the kiln stands in Bamboo Pass", World.regionAt(kiln.X, kiln.Y, kiln.Z) == "BambooPass")
local i = Inventory.defaults()
i.weapons = { Unarmed = true }
local weapons = 0
for _ in i.weapons do weapons += 1 end
check("the first claim succeeds", (Inventory.claim(i, "FoundersKiln")))
local after = 0
for _ in i.weapons do after += 1 end
check("a cache with no weapon grants none", after == weapons)
check("a second claim refuses", not Inventory.claim(i, "FoundersKiln"))
check("the claimed cache survives migration", Inventory.migrate(i).caches.FoundersKiln == true and Inventory.validate(Inventory.migrate(i)))
local loot = src("src/server/Services/LootService.luau")
local claimBody = string.match(loot, "function Loot.Claim.-\nend") or ""
local refused = string.find(claimBody, "Inventory.claim(i,id);assert(ok,reason)", 1, true)
local paid = string.find(claimBody, "m[material]=", 1, true)
check("materials are paid after the refusal, inside the claim's transaction", refused and paid and refused < paid and string.find(claimBody, "transact(player,function(i: any,profile: any)", 1, true) ~= nil)

-- The gate pays nothing and asks the server where the player stands.
local service = src("src/server/Services/RouteGates.luau")
check("lifting checks the player's place on the server", string.find(service, "Service.canLift(e.Root.Position, gate)", 1, true) ~= nil)
check("lifting is refused only to the fallen and duellists, never silently mid-fight", string.find(service, 'e.Fighter.State == "KO" or e.Respawning or e.Duel', 1, true) ~= nil and string.find(service, 'State ~= "Idle"', 1, true) == nil)
check("lifting only writes its own flag", select(2, string.gsub(service, "Persistence.Transaction", "")) == 1 and string.find(service, "p.routeFlags[ID] = true", 1, true) ~= nil
	and string.find(service, "qiEssence", 1, true) == nil and string.find(service, "Materials", 1, true) == nil)

-- A save from before this batch loads and validates, with no route flag.
local raw = Schema.Default(1)
raw.routeFlags = nil
raw.unlockedAltars.Altar_BambooShrine = true
raw.defeatedBosses.TwinSentinels = true
local migrated = Schema.Migrate(raw, 1)
check("an old save migrates with empty route flags", next(migrated.routeFlags) == nil)
check("the migrated save validates", (Schema.Validate(migrated)))
check("and finds the gate open from its progress", Gates.isOpen(migrated, "BambooRidge"))
check("a fresh record starts shut", not Gates.isOpen(Schema.Default(1), "BambooRidge") and (Schema.Validate(Schema.Default(1))))
local saved = Schema.Default(1)
saved.routeFlags.BambooRidge = true
check("a saved flag survives migration", Schema.Migrate(saved, 1).routeFlags.BambooRidge == true)
local junk = Schema.Default(1)
junk.routeFlags = { [3] = "x" }
local cleaned = Schema.Migrate(junk, 1)
check("garbage route flags are dropped and the save still validates", next(cleaned.routeFlags) == nil and (Schema.Validate(cleaned)))

-- Foundry kit: every piece the wing places has a registered upload and a library entry with all four maps.
local registry = src("assets/FOUNDRY_KIT_UPLOADED.json")
local library = src("assets/models/AsuraFoundryKit.rbxmx")
local foundrySource = src("src/server/Services/BambooFoundry.luau")
for _, piece in { "Foundry_Bell", "Foundry_KilnStack", "Foundry_Crucible", "Foundry_SlagHeap", "Foundry_BellMould", "Foundry_HallWall" } do
	check(piece .. " is registered", string.find(registry, '"' .. piece .. '"', 1, true) ~= nil)
	check(piece .. " is in the library", string.find(library, piece, 1, true) ~= nil)
end
local _, maps = string.gsub(library, 'class="SurfaceAppearance"', "")
check("every library piece has a SurfaceAppearance", maps == 6)
for _, map in { "ColorMapContent", "NormalMapContent", "RoughnessMapContent", "MetalnessMapContent" } do
	local _, count = string.gsub(library, map, "")
	check("every library piece carries " .. map, count >= 6)
end
check("the kit is mapped into ServerStorage", string.find(src("default.project.json"), "AsuraFoundryKit", 1, true) ~= nil)
check("the wing no longer builds a primitive bell", string.find(foundrySource, "BRONZE", 1, true) == nil)

-- The kiln's guards can be drawn one at a time and the kit's solid bodies stay collidable through the layout.
local function spawnOf(id)
	local line = string.match(src("src/shared/WorldDefinitions.luau"), 'spawn%("' .. id .. '"[^\n]*')
	return line
end
check("the kiln swordsman has a short notice", string.find(spawnOf("BP_Swordsman_Kiln") or "", ", 3, 10)", 1, true) ~= nil)
check("the kiln monk has a short notice", string.find(spawnOf("BP_Monk_Kiln") or "", ", 3, 10)", 1, true) ~= nil)
local layout = src("src/shared/BambooPassLayout.luau")
for _, body in { "CrucibleBody", "MouldBody", "KilnStack", "KilnPlinth", "SlagHeap" } do
	check(body .. " keeps a part collider", string.find(layout, '"' .. body .. '", "Timber"', 1, true) ~= nil)
end

-- Client and service fixes from the Mac playtest. Source guards: the live behaviour is recorded in the evidence folder.
local loot = src("src/server/Services/LootService.luau")
check("a cache claim no longer needs Idle", string.find(loot, "local c=Catalog.Caches[id];local e=canClaim(player.UserId)", 1, true) ~= nil)
check("KO, respawn and duel still refuse a claim", string.find(loot, 'e.Fighter.State~="KO" and not e.Respawning and not e.Duel', 1, true) ~= nil)
check("a claimed cache hides its prompt", string.find(src("src/client/Controllers/SpellController.luau"), "packet.inventory.caches", 1, true) ~= nil)
local dialogue = src("src/client/Controllers/DialogueController.luau")
check("the death screen closes a dialogue", string.find(dialogue, "ui.OnDeathShown=function() self:Close(false) end", 1, true) ~= nil)
check("a blow closes a dialogue", string.find(dialogue, "hp<lastHp", 1, true) ~= nil)
check("the death screen tells the dialogue", string.find(src("src/client/Controllers/InterfaceController.luau"), "self.OnDeathShown()", 1, true) ~= nil)
check("the foe plate ends with the fight", string.find(src("src/client/Controllers/CombatHud.luau"), "FOCUS_RANGE", 1, true) ~= nil)
check("blackouts reach the screen edges", string.find(src("src/client/Controllers/DeviceLayout.luau"), 'fullBleed(gui:FindFirstChild("Death"))', 1, true) ~= nil)

print(string.format("route foundry: %d passed, %d failed (local rules only; Studio geometry, input and live saves are separate)", passed, failed))
if failed > 0 then error("route foundry regression failed") end
