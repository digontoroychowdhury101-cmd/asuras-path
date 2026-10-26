--!nonstrict
-- Lune regression for post-F26 step 6, decision D1: the Iron Bull fights with a boss-only maul and
-- tower shield (IronBullMaul) through the shared server combat path, outside the 12-weapon player
-- registry. Checks the registry and wire order, the snapshot round trip, the moveset's identity, that
-- the drawn path is the validated path, commitment and punish windows, spacing, and the swing cue.
-- Run from the project root: lune run tools/test_iron_bull.luau
local fs = require("@lune/fs")
local Weapons = require("../src/simulation/WeaponSchema")
local Combat = require("../src/simulation/CombatRules")
local Geometry = require("../src/simulation/StrikeGeometry")
local World = require("../src/shared/WorldDefinitions")
local Bodies = require("../src/shared/BossBodies")
local AnimRules = require("../src/shared/BossAnimationRules")

local passed, failed = 0, 0
local function check(name: string, condition: any)
	if condition then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local function src(path: string): string return fs.readFile(path) end
local function has(path: string, text: string): boolean return string.find(src(path), text, 1, true) ~= nil end

-- 1. Registry: the player list is untouched; the maul rides after it on the wire only.
check("player registry still 12", #Weapons.WeaponKeys == 12)
check("maul is not a player weapon", table.find(Weapons.WeaponKeys, "IronBullMaul") == nil)
check("wire = player registry, then boss arms", type(Weapons.WireKeys) == "table" and #Weapons.WireKeys == 13 and Weapons.WireKeys[13] == "IronBullMaul")
local same = true
for i, key in Weapons.WeaponKeys do if (Weapons.WireKeys or {})[i] ~= key then same = false end end
check("every player weapon keeps its wire index", same)
check("isBossOnly", Weapons.isBossOnly and Weapons.isBossOnly("IronBullMaul") and not Weapons.isBossOnly("Guandao"))
for _, path in { "src/shared/ArsenalCatalog.luau", "src/server/ProfileStore.luau", "src/shared/ProfileSchema.luau" } do
	check(path .. " never offers the maul", not has(path, "IronBullMaul"))
end
check("held-weapon models leave boss arms to the look", has("src/server/Services/WeaponModels.luau", "Weapons.isBossOnly(id) then return false end"))

-- 2. Roster: the Bull carries it; Zhao keeps the guandao; perilous ids are unchanged.
local twins = World.Bosses.TwinSentinels
check("Bull wields IronBullMaul", twins.Partner.Weapon == "IronBullMaul")
check("Zhao keeps the guandao", twins.Phases[1].Weapon == "Guandao")
check("Bull perilous ids unchanged", twins.Partner.Attacks[1].Id == "IronCharge" and twins.Partner.Attacks[2].Id == "ColossalHammer")

-- 3. Snapshot round trip (the old encoder had no index for a boss weapon).
local ok, snap = pcall(function()
	local f = Combat.new(-7, "IronBullMaul", 0)
	return Combat.unpack(Combat.pack(f, 0))
end)
check("a Bull snapshot packs and unpacks", ok and snap and snap.Weapon == "IronBullMaul")
local okJ, snapJ = pcall(function() return Combat.unpack(Combat.pack(Combat.new(1, "Jian", 0), 0)) end)
check("player snapshots unchanged", okJ and snapJ and snapJ.Weapon == "Jian")

-- 4. Identity: a maul and shield, not a borrowed glaive.
local maul, glaive = Weapons.get("IronBullMaul"), Weapons.get("Guandao")
local moves = { maul.Light[1], maul.Light[2], maul.Light[3], maul.Heavy, maul.RunningAttack, maul.WeaponArt }
local shared = false
for _, m in moves do if glaive.Moves[m.Id] then shared = true end end
check("no move shared with the guandao", not shared)
local blunt = true
for _, m in moves do if m.DamageType ~= "Blunt" then blunt = false end end
check("every maul or shield strike is blunt", blunt)
check("one-handed maul (shield in the off hand)", maul.Grip == "OneHanded")
check("lights shorter than the glaive", maul.Light[1].Reach < glaive.Light[1].Reach and maul.Light[2].Reach < glaive.Light[2].Reach)
check("animation slots name the motion", maul.Light[1].Animation == "IronBull.IronHook" and maul.WeaponArt.Animation == "IronBull.Bell-Breaker")

-- 5. The drawn path is the validated path: lines for the ram, drop and rush; fans for hook, crush, bell.
local function line(m) return m.Arc <= Geometry.SlashArc end
check("Shield Ram, Anvil Drop and Rampart Rush draw as lines", line(maul.Light[2]) and line(maul.Light[3]) and line(maul.RunningAttack))
check("Iron Hook, Ox-Yoke Crush and Bell-Breaker draw as fans", not line(maul.Light[1]) and not line(maul.Heavy) and not line(maul.WeaponArt))
for _, m in moves do
	local path = Geometry.sweep({ Arc = m.Arc, Reach = m.Reach, Lunge = m.Lunge }, 0, 8)
	local _, _, _, x, _, z = Geometry.segment({ Arc = m.Arc, Reach = m.Reach, Lunge = m.Lunge }, 1, 0)
	check(m.Id .. " drawn tip = server tip", math.abs(path[9][1] - x) < 1e-9 and math.abs(path[9][2] - z) < 1e-9
		and math.abs(math.sqrt(x * x + z * z) - (m.Reach + m.Lunge * 0.35)) < 1e-6)
end
-- Bell-Breaker sweeps 200 degrees in front: the 160 degrees behind stay open.
local art = maul.WeaponArt
local edge = math.rad(art.Arc / 2)
check("Bell-Breaker leaves the back open", math.deg(math.pi - edge) >= 79)

-- 6. Commitment and punish windows.
local function deg(r: number): number return math.deg(r) end
check("Iron Hook tracks at most ~16 deg before it commits", deg(Geometry.windupBudget(maul.Light[1].Timing.StartupSeconds)) <= 17)
check("Ox-Yoke Crush commits ~88 deg of windup tracking, then holds", deg(Geometry.windupBudget(maul.Heavy.Timing.StartupSeconds)) <= 90)
check("Anvil Drop recovery >= 0.5 s (glaive L3 0.267)", maul.Light[3].Timing.RecoverySeconds >= 0.49 and glaive.Light[3].Timing.RecoverySeconds < 0.3)
check("Ox-Yoke Crush recovery 0.6 s, hyper armour", maul.Heavy.Timing.RecoverySeconds >= 0.59 and maul.Heavy.HyperArmor)
for i, m in moves do
	local g = ({ glaive.Light[1], glaive.Light[2], glaive.Light[3], glaive.Heavy, glaive.RunningAttack, glaive.WeaponArt })[i]
	check(m.Id .. " recovers no faster than its glaive slot", m.Timing.RecoverySeconds >= g.Timing.RecoverySeconds)
	check(m.Id .. " stays reactable", m.Timing.Reactable)
end
check("the 100 ms deflect baseline is untouched", require("../src/shared/CombatSettings").Posture.DeflectWindow == 0.10)

-- 7. Spacing: the Bull engages at the maul's reach, still inside one guard cone beside Zhao.
local bullStop, zhaoStop, gap = maul.Light[1].Reach * 0.6, glaive.Light[1].Reach * 0.6, 2.5 * (1.2 + 1.7)
local zx, zz = Bodies.closeIn(0, 20, 0, 0, zhaoStop)
local bx, bz = Bodies.flank(3, 18, 0, 0, bullStop, zx, zz, gap)
local spread = math.deg(math.abs(((math.atan2(bz, bx) - math.atan2(zz, zx)) + math.pi) % (2 * math.pi) - math.pi))
check(string.format("Bull at %.1f, Zhao at %.1f, %.0f deg apart: one guard covers both", bullStop, zhaoStop, spread), spread <= 2 * math.deg(math.acos(0.15)))

-- 8. Every Bull swing plays its own clip slot; other bosses are unchanged.
check("swing cue for boss-only arms only", has("src/server/Services/AIService.luau", "elseif agent.Boss and e and Weapons.isBossOnly(e.Fighter.Weapon) then"))
check("client plays BossSwing as an action, not a transform", has("src/client/Controllers/InterfaceController.luau", "cue.Kind == \"BossSwing\""))
check("clip slots match the moveset", #AnimRules.slots("IronBull", 1) == 11 and #AnimRules.slots("GeneralZhao", 1) == 5)

print(string.format("iron bull: %d passed, %d failed", passed, failed))
if failed > 0 then error("iron bull regression failed") end
