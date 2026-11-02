--!nonstrict
-- Windows acceptance (3 November 2026): an ordinary foe's new attack must leave the player its reaction floor
-- measured from when the player can first answer, not from when the foe decided. Studio trace before the fix
-- (outputs/mac-followup-2026-11-02/windows-acceptance/monk/): a monk chose Heavy after Heavy while the player
-- was still in heavy hitstun, and each landed 0.14-0.24 s after the player could act (floor 0.25 s).
-- Runs the real CombatRules and the real Telegraph block of AIService (loaded from source) under Lune.
-- Evidence class: offline behaviour.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Combat = require("../src/simulation/CombatRules")
local Weapons = require("../src/simulation/WeaponSchema")
local Tempo = require("../src/simulation/Tempo")
local Settings = require("../src/shared/CombatSettings")

local TICK = Tempo.TickSeconds
local passed, failed = 0, 0
local function check(name: string, ok: any, detail: any?)
	if ok then
		passed += 1
	else
		failed += 1
		print("FAIL  " .. name .. (if detail ~= nil then "  (" .. tostring(detail) .. ")" else ""))
	end
end

-- The Telegraph section of AIService, compiled on its own with the real Tempo.
local source = fs.readFile("src/server/Services/AIService.luau")
local first = string.find(source, "local Telegraph = {}", 1, true)
local last = string.find(source, "AIService.Telegraph = table.freeze(Telegraph)", 1, true)
assert(first and last, "Telegraph block not found")
local PLAYER_REACTION = tonumber(string.match(source, "local PLAYER_REACTION = ([%d%.]+)"))
local PERILOUS_LEAD = tonumber(string.match(source, "local PERILOUS_LEAD = ([%d%.]+)"))
local block = "local Tempo, PLAYER_REACTION, PERILOUS_LEAD = ...\n" .. string.sub(source, first, last - 1) .. "\nreturn Telegraph"
local Telegraph = luau.load(block, { debugName = "Telegraph" })(Tempo, PLAYER_REACTION, PERILOUS_LEAD)

local monkHeavy = Weapons.get("Unarmed").Heavy
local monkLight = Weapons.get("Unarmed").Light[1]

-- F-01 heavy hitstun: the monk's Heavy recovery ends while the player still reels.
local player = Combat.new(1, "Jian", 0)
local monk = Combat.new(2, "Unarmed", 0)
local hitAt = 10
player.State, player.StateStart, player.StateEnd = "Hitstun", hitAt, hitAt + Settings.Stun.HitstunHeavy
local decide = hitAt + monkHeavy.Timing.ActiveSeconds + monkHeavy.Timing.RecoverySeconds -- monk Idle again
local ready = Combat.defendableAt(player, decide)
check("F-01 the player in heavy hitstun can answer only when it ends", math.abs(ready - player.StateEnd) < 1e-9, ready)
local _, _, oldImpact = Telegraph.plan(monkHeavy, decide, PLAYER_REACTION)
local attackAt, warnAt, impact = Telegraph.plan(monkHeavy, decide, PLAYER_REACTION, ready)
check("F-01 before: impact came inside the floor after the player could act", oldImpact - ready < PLAYER_REACTION - 1e-6,
	string.format("%.3f", oldImpact - ready))
check("F-01 after: impact leaves the full floor after hitstun", impact - ready >= PLAYER_REACTION - 1e-6,
	string.format("%.3f", impact - ready))
check("F-01 the warning is still published at the decision", warnAt == decide)
check("F-01 the attack starts on a tick and never before the decision", attackAt >= decide - 1e-9
	and math.abs(attackAt / TICK - math.round(attackAt / TICK)) < 1e-6)
check("F-01 the wait is no longer than needed (within one tick)", impact - ready < PLAYER_REACTION + TICK + 1e-6,
	string.format("%.3f", impact - ready))

-- F-02 light hitstun: the defend point (Stun.LightDefendCancel) is when the player can answer.
player.State, player.StateStart, player.StateEnd = "Hitstun", hitAt, hitAt + Settings.Stun.HitstunLight
ready = Combat.defendableAt(player, hitAt + 0.02)
check("F-02 light hitstun answers from the defend point", math.abs(ready - (hitAt + Settings.Stun.LightDefendCancel)) < 1e-9, ready)
check("F-02 past the defend point it is now", Combat.defendableAt(player, hitAt + 0.2) == hitAt + 0.2)

-- F-03 a free target is unchanged: same schedule with or without `ready`.
player.State, player.StateStart, player.StateEnd = "Idle", hitAt, hitAt
for _, move in { monkLight, monkHeavy } do
	local a1, _, i1 = Telegraph.plan(move, decide, PLAYER_REACTION)
	local a2, _, i2 = Telegraph.plan(move, decide, PLAYER_REACTION, Combat.defendableAt(player, decide))
	check("F-03 idle target unchanged for " .. move.Id, a1 == a2 and i1 == i2)
end

-- F-04 wiring: openers pass the target's readiness, follow-ups and bosses do not.
check("F-04 ordinary openers count the lead from the target's readiness",
	string.find(source, "local ready = if agent.Boss then nil else Combat.defendableAt(target.Fighter, now)", 1, true) ~= nil
	and select(2, string.gsub(source, 'queueAttack%(agent, f, "%a+", now, ready%)', "")) == 3)
check("F-04 combo follow-ups stay true links", string.find(source, 'queueAttack(agent, f, "Light", now)\n', 1, true) ~= nil)

-- F-05 respawn: foes that fought the player who just died go home; another player's fight is left alone.
-- (Windows acceptance: the Cloister monk and swordsman stayed engaged at the altar and killed each respawn.)
local rFirst = string.find(source, "function AIService.RespawnRegion", 1, true)
local rLast = string.find(source, "\nend\n", rFirst, true)
local respawnBlock = "local World, spawnAgents, agents, Characters, AIService = ...\n" .. string.sub(source, rFirst, rLast + 4)
	.. "return AIService.RespawnRegion"
local reset = {}
local fakeAgents = {
	[11] = { Mode = "Combat", Target = 0 }, -- its target (the dead player) went KO: cleared
	[12] = { Mode = "Engage", Target = 7 }, -- still aimed at the dead player
	[13] = { Mode = "Combat", Target = 8 }, -- fighting another player
	[14] = { Mode = "Idle", Target = 0 },
}
local fakeAI = { ResetMob = function(spawnId) table.insert(reset, spawnId) end, SpawnMob = function() end }
local RespawnRegion = luau.load(respawnBlock, { debugName = "RespawnRegion" })(
	{ Spawns = { { Id = "a", Region = "Cloister" }, { Id = "b", Region = "Cloister" }, { Id = "c", Region = "Cloister" },
		{ Id = "d", Region = "Cloister" } } },
	{ a = 11, b = 12, c = 13, d = 14 }, fakeAgents,
	{ GetEntity = function() return { Fighter = { State = "Idle" } } end, DespawnEnemy = function() end }, fakeAI)
RespawnRegion("Cloister", true, 7)
table.sort(reset)
check("F-05 after a death the dead player's foes reset, another player's fight is kept",
	table.concat(reset, ",") == "a,b,d", table.concat(reset, ","))
table.clear(reset)
fakeAgents[11].Target = 9
RespawnRegion("Cloister", true)
table.sort(reset)
check("F-05 a rest (no one freed) still skips every live fight", table.concat(reset, ",") == "d",
	table.concat(reset, ","))
check("F-05 the death path frees the player who died",
	string.find(fs.readFile("src/server/Services/WorldService.luau"), "AI.RespawnRegion(altar.Region, true, s.UserId)", 1, true) ~= nil)

-- F-06 altar shelter: after a rest or respawn at an altar, ordinary foes leave the player alone until they step
-- out of the circle or attack; bosses ignore it. (Windows acceptance: resting at the Cloister revived its pair,
-- who saw the altar from their posts, re-engaged in ~4 s, refused Travel and killed each respawn.)
local sFirst = string.find(source, "local sheltered:", 1, true)
local sLast = string.find(source, "local function noisy", sFirst, true)
assert(sFirst and sLast, "shelter block not found")
local shelterBlock = "local Vector3 = ...\n" .. string.sub(source, sFirst, sLast - 1)
	.. "\nreturn isTargetable, function(id, x, z, r) sheltered[id] = { X = x, Z = z, Radius = r } end, sheltered"
local isTargetable, shelter, shelters = luau.load(shelterBlock, { debugName = "Shelter" })()
local function body(x: number, z: number, state: string)
	return { Id = 7, Kind = "Player", Respawning = false, Duel = nil, Root = { Position = { X = x, Y = 3, Z = z } },
		Fighter = { State = state } }
end
local ordinary, boss = { Boss = nil }, { Boss = { Id = "B" } }
shelter(7, 60, -1010, 13)
check("F-06 a player resting/respawned at the altar is not acquired by ordinary foes",
	isTargetable(ordinary, body(60, -1018, "Idle")) == false)
check("F-06 bosses ignore the shelter", isTargetable(boss, body(60, -1018, "Idle")) == true)
check("F-06 the shelter still holds after a boss check", shelters[7] ~= nil)
check("F-06 stepping out of the circle ends it", isTargetable(ordinary, body(60, -1030, "Idle")) == true)
check("F-06 and walking back in does not restore it", isTargetable(ordinary, body(60, -1018, "Idle")) == true)
shelter(7, 60, -1010, 13)
check("F-06 attacking from the altar ends it", isTargetable(ordinary, body(60, -1018, "Startup")) == true and shelters[7] == nil)
check("F-06 wiring: rest and respawn shelter, a landed hit ends it",
	select(2, string.gsub(fs.readFile("src/server/Services/WorldService.luau"), "AI%.Shelter%(s%.UserId, altar%.Placement%.X", "")) == 2
	and string.find(source, "sheltered[event.Source] = nil", 1, true) ~= nil
	and string.find(source, "if agent.Boss == nil and isSheltered(e) then", 1, true) ~= nil)

print(string.format("ordinary foe fairness: %d passed, %d failed (offline behaviour; feel needs human play)", passed, failed))
