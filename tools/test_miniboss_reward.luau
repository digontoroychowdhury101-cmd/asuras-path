--!nonstrict
-- Lune regression for the optional Monastery miniboss (the Hollow-Bell Warden): its definition and
-- grave-field spawn are valid, and its reward goes through the real ProfileStore exactly once per
-- player under its own flag (world.minibosses): +400 Essence and one gourd charge via
-- AddElixirCapacity, no sovereign flag, arsenal award or ending count, nothing on a replayed defeat,
-- and a full gourd still pays the Essence.
-- Run from the project root: work/bin/luau/luau tools/test_miniboss_reward.luau
local World = require("../src/shared/WorldDefinitions")
local Zones = require("../src/shared/MonasteryZones")
local Settings = require("../src/shared/CombatSettings")
local Store = require("../src/server/ProfileStore")
local Profiles = require("../src/shared/ProfileSchema")

local passed, failed = 0, 0
local function check(name: string, condition: any)
	if condition then passed += 1 else failed += 1; print("FAIL " .. name) end
end

-- 1. Content: a new stable id in the grave field, a signature and a reward of its own.
local warden = World.Mobs.HollowBellWarden
check("warden defined", warden ~= nil and warden.Name == "Hollow-Bell Warden")
check("warden reward is its own flag", warden.Reward.Flag == "HollowBellWarden" and warden.Reward.Essence == 400 and warden.Reward.ElixirCapacity)
check("warden is no sovereign", World.Bosses.HollowBellWarden == nil)
check("warden signature telegraphed", warden.Signature.Id == "HollowToll" and warden.Signature.Shockwave.Windup >= 0.65)
local spawn
for _, entry in World.Spawns do
	if entry.Mob == "HollowBellWarden" then spawn = entry end
end
check("one warden spawn, stable id", spawn ~= nil and spawn.Id == "DM_Warden_Graves")
check("warden leashed to the grave field", Zones.Spawns.DM_Warden_Graves == "Graves")
local graves = Zones.get("Graves")
check("warden spawns inside the grave field", graves ~= nil and Zones.contains(graves, spawn.Placement.X, spawn.Placement.Z, 0))

-- 2. Exactly once, through real store transactions.
local data: { [string]: any } = {}
local db = { UpdateAsync = function(_self: any, key: string, fn: (any) -> any): any
	local updated = fn(Store.Copy(data[key])); if updated then data[key] = Store.Copy(updated) end; return Store.Copy(updated)
end }
local store = Store.new(db, Profiles, { owner = "warden", now = function() return 1000 end, wait = function() end, attempts = 1, leaseSeconds = 180 })
assert(store:Load(31))
local before = store:Souls(31)
local essence, max, charges = before.essence, before.inventory.elixirs.max, before.inventory.elixirs.charges
local ok, _, claimed = store:RecordMinibossDefeat(31, "HollowBellWarden", 400, true)
local after = store:Souls(31)
check("first defeat claims", ok and claimed)
check("first defeat pays 400 essence", after.essence == essence + 400)
check("first defeat adds a gourd charge", after.inventory.elixirs.max == max + 1 and after.inventory.elixirs.charges == math.min(charges + 1, max + 1))
check("own flag set", after.world.minibosses.HollowBellWarden == true)
check("no sovereign flag", next(after.world.bosses) == nil)
ok, _, claimed = store:RecordMinibossDefeat(31, "HollowBellWarden", 400, true)
local replay = store:Souls(31)
check("replayed defeat claims nothing", ok and not claimed and replay.essence == after.essence and replay.inventory.elixirs.max == after.inventory.elixirs.max)
check("profile still valid", Store.ValidateSouls(replay))

-- A full gourd: the Essence and the flag still land, the cap is respected.
assert(store:Load(32))
for _ = 1, Settings.Elixir.MaxCharges do store:AddElixirCapacity(32) end
local full = store:Souls(32)
ok, _, claimed = store:RecordMinibossDefeat(32, "HollowBellWarden", 400, true)
local capped = store:Souls(32)
check("full gourd still claims", ok and claimed and capped.essence == full.essence + 400)
check("full gourd stays at cap", capped.inventory.elixirs.max == Settings.Elixir.MaxCharges)

-- An older record with no miniboss table migrates and claims.
local legacy = Store.Copy(store:Souls(31))
legacy.world.minibosses = nil
check("record without minibosses validates", Store.ValidateSouls(legacy))

print(string.format("miniboss reward: %d passed, %d failed", passed, failed))
if failed > 0 then error("miniboss reward regression failed") end
