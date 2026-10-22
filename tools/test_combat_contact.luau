--!nonstrict
-- Lune regression for playtest findings #14, #20 and #21 (batch 09): authoritative whiff / evade /
-- feint events beside hit, block, deflect and deathblow; hitbox geometry and the 60 Hz rewind path
-- untouched; a drink at full health (or at a lowered ceiling) spends nothing; enemy deaths keep
-- their joints, stop colliding and play the authored collapse. Rules + source checks; the Studio
-- look of the arc, popups and dissolve is not covered here.
-- Run from the project root: lune run tools/test_combat_contact.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Combat = require("../src/simulation/CombatRules")
local Weapons = require("../src/simulation/WeaponSchema")
local Settings = require("../src/shared/CombatSettings")
local Contact = require("../src/shared/ContactCues")

local passed, failed = 0, 0
local function check(name: string, condition: any)
	if condition then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local function src(path: string): string return fs.readFile(path) end
local T, DT = 100, 1 / 60
local function advance(f, events, from, to)
	local t = from
	while t < to - 1e-9 do t = math.min(to, t + DT); Combat.step(f, t, DT, events) end
	return t
end
local function kinds(events)
	local list = {}
	for _, e in events do table.insert(list, e.Kind) end
	return table.concat(list, ",")
end
local front = { Facing = true, Region = "Torso" }

-- 1. Event codes: new kinds appended, existing codes unchanged (snapshot/replication compatible).
check("existing codes stable", Combat.EventCodes.DeflectSpark == 1 and Combat.EventCodes.Hit == 4 and Combat.EventCodes.Deathblow == 8 and Combat.EventCodes.Feint == 13 and Combat.EventCodes.Rest == 16)
check("whiff and evade appended", Combat.EventCodes.Whiff == 17 and Combat.EventCodes.Evade == 18 and Combat.EventNames[17] == "Whiff" and Combat.EventNames[18] == "Evade")

-- 2. Whiff: the active window closes with no contact.
local events = {}
local a = Combat.new(1, "Jian", T)
assert(Combat.tryAttack(a, "Light", T))
local done = T + a.Move.Timing.StartupSeconds + a.Move.Timing.ActiveSeconds + 0.05
advance(a, events, T, done)
check("swing at air emits one Whiff", kinds(events) == "Whiff" and events[1].Source == 1 and events[1].Target == 0)
local snap = Combat.unpackString(Combat.packString(a, done))
check("whiff replicates as last event", snap and snap.LastEvent == "Whiff")

-- 3. A landed hit is not a whiff.
events = {}
local b = Combat.new(2, "Jian", T)
local v = Combat.new(3, "Jian", T)
assert(Combat.tryAttack(b, "Light", T))
local t = advance(b, events, T, T + b.Move.Timing.StartupSeconds + 1e-4)
check("hit lands", Combat.resolveHit(b, v, t, front, events) == "Hit")
advance(b, events, t, t + b.Move.Timing.ActiveSeconds + 0.05)
check("no whiff after contact", not string.find(kinds(events), "Whiff"))

-- 4. Blocked and deflected strikes are contact too (their own events), not whiffs.
for _, case in { { "Blocked", "Block" }, { "Deflected", "DeflectSpark" } } do
	events = {}
	local atk, def = Combat.new(4, "Jian", T), Combat.new(5, "Jian", T)
	assert(Combat.tryAttack(atk, "Light", T))
	t = advance(atk, events, T, T + atk.Move.Timing.StartupSeconds + 1e-4)
	if case[1] == "Blocked" then Combat.setGuard(def, true, T) else assert(Combat.tryDeflect(def, t - 0.01, t - 0.01)) end
	local active = atk.Move.Timing.ActiveSeconds
	local outcome = Combat.resolveHit(atk, def, t, front, events)
	advance(atk, events, t, t + active + 0.05)
	check(case[1] .. " reads as " .. case[2] .. ", never a whiff", outcome == case[1] and string.find(kinds(events), case[2]) and not string.find(kinds(events), "Whiff"))
end

-- 5. Evade: the strike met dodge i-frames.
events = {}
local atk, dodger = Combat.new(6, "Jian", T), Combat.new(7, "Jian", T)
assert(Combat.tryAttack(atk, "Light", T))
t = advance(atk, events, T, T + atk.Move.Timing.StartupSeconds + 1e-4)
dodger.InvulnerableUntil = t + 1
check("i-frame strike is a Whiff outcome", Combat.resolveHit(atk, dodger, t, front, events) == "Whiff")
check("evade event names evader then attacker", events[#events].Kind == "Evade" and events[#events].Source == 7 and events[#events].Target == 6)
advance(atk, events, t, t + 0.6)
check("dodged swing is not also a whiff", not string.find(kinds(events), "Whiff"))
events = {}
check("area strike through i-frames evades", Combat.applyArea(atk, dodger, t, 10, 10, true, true, events) == "Whiff" and events[1].Kind == "Evade")

-- 6. Feint still announced; ranged-effect moves never whiff.
events = {}
local feinter = Combat.new(8, "Jian", T)
assert(Combat.tryAttack(feinter, "Heavy", T))
check("feint emits Feint", Combat.tryFeint(feinter, T + 0.05, events) and kinds(events) == "Feint")
local fan = Weapons.get("WarFan")
check("ranged effect list shared", Combat.RangedEffects[fan.Light[3].Effect] == true and string.find(src("src/server/CharacterService.luau"), "Combat.RangedEffects[move.Effect", 1, true) ~= nil)

-- 7. Hitboxes and rewind untouched.
local cs = src("src/server/CharacterService.luau")
check("weapon segment reach formula unchanged", string.find(cs, "local reach = move.Reach + bonus + move.Lunge * 0.35 * progress", 1, true) ~= nil)
check("weapon radius unchanged", string.find(cs, 'return if f.Weapon == "Unarmed" then 0.55 else 0.3', 1, true) ~= nil)
check("rewind query unchanged", string.find(cs, "Lag.queryHit(prevA, prevB, curA, curB, radius, defender.History, rewindTo, TICK)", 1, true) ~= nil)
check("whiffs annotated after the step, before contacts", string.find(cs, "annotateWhiffs(stepped)\n\n\tfor _, e in live do\n\t\tif entities[e.Id] == e and e.Fighter.State == \"Active\" then", 1, true) ~= nil)

-- 8. ContactCues wording.
check("gap is flat distance beyond body and reach", math.abs(Contact.gap(roblox.Vector3.new(0, 0, 0), roblox.Vector3.new(0, 5, -10), 6) - 2.8) < 1e-9)
check("in reach gives zero gap", Contact.gap(roblox.Vector3.new(0, 0, 0), roblox.Vector3.new(3, 0, 0), 6) == 0)
check("out of reach worded with studs", Contact.describe("Whiff", 1, 9, 2.34, 1, false).Text == "OUT OF REACH  +2.3")
check("close miss worded", Contact.describe("Whiff", 1, 9, 0.1, 1, false).Text == "MISSED")
check("swing at nothing stays quiet", Contact.describe("Whiff", 1, 0, 0, 1, false) == nil)
check("others' whiffs not called", Contact.describe("Whiff", 9, 1, 3, 1, true) == nil)
check("own evade", Contact.describe("Evade", 1, 9, 0, 1, true).Text == "EVADED")
check("own attack dodged, popup over the dodger", Contact.describe("Evade", 9, 1, 0, 1, true).Text == "DODGED" and Contact.describe("Evade", 9, 1, 0, 1, true).Over == "Source")
check("own feint explained", string.find(Contact.describe("Feint", 1, 1, 5, 1, false).Text, "cancelled", 1, true) ~= nil)
check("nearby foe feint called", Contact.describe("Feint", 9, 9, 5, 1, true).Text == "FEINT" and Contact.describe("Feint", 9, 9, 5, 1, false) == nil)
local callouts = src("src/client/Controllers/CombatCallouts.luau")
check("callouts use ContactCues", string.find(callouts, "Contact.describe(event.Kind", 1, true) ~= nil)
check("existing parry/deathblow calls kept", string.find(callouts, '"PARRY!"', 1, true) and string.find(callouts, '"DEATHBLOW"', 1, true))
check("reach arc drawn on whiffs", string.find(src("src/client/Controllers/GameFeelController.luau"), 'kind=="Whiff"', 1, true) and string.find(src("src/client/Controllers/CombatVfx.luau"), "function Vfx.arc", 1, true))

-- 9. Full-health drinks spend nothing (#20).
local d = Combat.new(10, "Jian", T)
local ok, reason = Combat.tryHeal(d, T)
check("full health refuses", not ok and reason == "FullHealth" and d.State == "Idle" and d.PendingHeal == 0)
d.PermanentDeficit = 30; d.ActiveHP = Combat.effectiveMaxHP(d)
ok, reason = Combat.tryHeal(d, T)
check("at a lowered ceiling refuses with its own reason", not ok and reason == "AtCeiling")
d.ActiveHP = Combat.effectiveMaxHP(d) - 20
check("wounded below a lowered ceiling may drink", Combat.tryHeal(d, T))
advance(d, {}, T, T + Settings.Elixir.DrinkDuration + 0.05)
check("drink restores only up to the ceiling", math.abs(d.ActiveHP - Combat.effectiveMaxHP(d)) < 1e-6 and Combat.effectiveMaxHP(d) < d.MaxHP)
local w = Combat.new(11, "Jian", T); w.ActiveHP = 40
check("ordinary wounded drink unchanged", Combat.tryHeal(w, T))
local ws = src("src/server/Services/WorldService.luau")
local refuse, spend = string.find(ws, 'if reason == "FullHealth" or reason == "AtCeiling" then', 1, true), string.find(ws, "s.Elixirs -= 1", 1, true)
check("charge only spent after an accepted drink", refuse and spend and refuse < spend)
check("refusal is cued every press", string.find(ws, 'Characters.Cue("HealRefused"', 1, true) ~= nil and string.find(src("src/client/Controllers/InterfaceController.luau"), "gourd kept", 1, true) ~= nil)

-- 10. Enemy deaths (#21).
check("no joint breakup", string.find(cs, "humanoid.BreakJointsOnDeath = false", 1, true) ~= nil)
check("corpse pinned and non-blocking", string.find(cs, "d.CanCollide, d.CanQuery, d.CanTouch = false, false, false", 1, true) and string.find(cs, 'e.Model:SetAttribute("AsuraDissolve", simTime)', 1, true))
check("corpse settled once when KO begins", string.find(cs, "e.Humanoid:MoveTo(e.Root.Position)\n\t\t\tsettleCorpse(e)", 1, true) ~= nil)
check("plates and lock drop at once", string.find(src("src/client/Controllers/WorldStateController.luau"), 'entity.Model:GetAttribute("AsuraDissolve") == nil', 1, true) ~= nil)
local dsrc = src("src/client/Controllers/EnemyDissolve.luau")
local Dissolve = luau.load(dsrc, { debugName = "EnemyDissolve", environment = {
	game = { GetService = function() return { AsurasPath = { Shared = { PresentationAssets = { Textures = { Ash = "", Smoke = "" } } } } } end },
	require = function(m) return m end, CFrame = roblox.CFrame, Vector3 = roblox.Vector3, Color3 = roblox.Color3, math = math, setmetatable = setmetatable, table = table, os = os } })()
local base = roblox.CFrame.lookAt(roblox.Vector3.new(0, 3, 0), roblox.Vector3.new(0, 3, -10))
check("collapse starts at the standing pose", (Dissolve.pose(base, 0, 3).Position - base.Position).Magnitude < 1e-6)
local down = Dissolve.pose(base, 1, 3)
local feet = (down * roblox.CFrame.new(0, -3 + Dissolve.Sink, 0)).Position
check("falls forward toward its facing", down.Position.Z < -1 and down.Position.Y < 2)
check("feet stay planted while it falls", (feet - roblox.Vector3.new(0, 0, 0)).Magnitude < 1e-4)
check("collapse time fits before the server removes the body", Dissolve.Collapse + Dissolve.Fade < Settings.Respawn.EnemyCorpseTime)
check("dissolve wired into game feel", string.find(src("src/client/Controllers/GameFeelController.luau"), "self.Dissolve:Update(dt)", 1, true) ~= nil)

-- 11. Hygiene.
for _, path in { "src/shared/ContactCues.luau", "src/client/Controllers/EnemyDissolve.luau", "src/client/Controllers/CombatCallouts.luau", "src/client/Controllers/CombatVfx.luau" } do
	local text = src(path)
	local _, lines = string.gsub(text, "\n", "")
	check(path .. " strict and under 150 lines", string.sub(text, 1, 9) == "--!strict" and lines < 150)
end
local project = src("default.project.json")
check("new modules registered", string.find(project, "shared/ContactCues.luau", 1, true) and string.find(project, "Controllers/EnemyDissolve.luau", 1, true))

print(string.format("combat contact: %d passed, %d failed", passed, failed))
if failed > 0 then error("combat contact regression failed") end
