--!strict
-- Run with work/bin/luau/luau tools/combat_frame_table.luau [-a --json] (no Roblox runtime required).
-- Prints every weapon's tempo-scaled frame data and the light-chain exchange table: for each
-- L(n) -> L(n+1) link, the contact-to-contact interval against light hitstun, so it is explicit
-- which links are true combos (the defender cannot act) and which leave a defensive answer.
-- Evidence type: offline behavior table computed from the real WeaponSchema/CombatSettings.
local Weapons = require("../src/simulation/WeaponSchema")
local Settings = require("../src/shared/CombatSettings")

local TICK = 1 / 60
local HITSTUN = Settings.Stun.HitstunLight
local HITSTUN_HEAVY = Settings.Stun.HitstunHeavy
local DEFLECT = Settings.Posture.DeflectWindow
-- Stage 2: light hitstun opens to Deflect/Block this far in (CombatSettings.Stun.LightDefendCancel).
local DEFEND = Settings.Stun.LightDefendCancel or HITSTUN

-- Width (s) of the press times whose deflect window covers a contact `interval` after the last one, when the
-- defender may first press at `from`: presses in [interval - W - half tick, interval + half tick], from `from` on.
local function deflectAnswer(interval: number, from: number): number
	local half = TICK / 2
	return math.max(0, interval + half - math.max(from, interval - DEFLECT - half))
end
local json = (({ ... } :: { any })[1] == "--json")

local function ms(seconds: number): number
	return math.floor(seconds * 1000 + 0.5)
end

local rows = {}
local links = {}
for _, key in Weapons.WeaponKeys do
	local w = Weapons.get(key)
	local function row(label: string, m: any)
		local t = m.Timing
		table.insert(rows, {
			weapon = key, slot = label, id = m.Id, kind = m.Kind,
			startup = ms(t.StartupSeconds), active = ms(t.ActiveSeconds), recovery = ms(t.RecoverySeconds),
			combo = ms(t.ComboWindowSeconds), cancel = ms(t.CancelFrame * TICK), total = ms(t.TotalSeconds),
			reach = m.Reach, arc = m.Arc, lunge = m.Lunge, deflectable = m.Deflectable, unblockable = m.Unblockable == true,
		})
	end
	for index, m in w.Light do
		row("L" .. index, m)
	end
	row("Heavy", w.Heavy)
	row("Running", w.RunningAttack)
	row("Art", w.WeaponArt)
	for index = 1, #w.Light - 1 do
		local a, b = w.Light[index].Timing, w.Light[index + 1].Timing
		if a.ComboWindowSeconds > 0 then
			-- Contact on L(n)'s first active frame; follow-up pressed on the first Recovery frame (earliest)
			-- or at the end of the combo window (latest buffered continuation).
			local fastest = a.ActiveSeconds + b.StartupSeconds
			local slowest = a.ActiveSeconds + a.ComboWindowSeconds + b.StartupSeconds
			table.insert(links, {
				weapon = key, link = "L" .. index .. "->L" .. (index + 1),
				fastest = ms(fastest), slowest = ms(slowest),
				-- Free time after light hitstun ends before the next contact; <= 0 means a true combo.
				gapFastest = ms(fastest - HITSTUN), gapSlowest = ms(slowest - HITSTUN),
				trueCombo = fastest <= HITSTUN,
				deflectAnswer = slowest - HITSTUN >= TICK,
				-- Deflect press width at the fastest..slowest continuation: before Stage 2 (nothing legal in
				-- hitstun) and with the light-hitstun defend window.
				answerBefore = { ms(deflectAnswer(fastest, HITSTUN)), ms(deflectAnswer(slowest, HITSTUN)) },
				answerAfter = { ms(deflectAnswer(fastest, DEFEND)), ms(deflectAnswer(slowest, DEFEND)) },
			})
		end
	end
end

if json then
	local parts = {}
	local function encode(value: any): string
		local kind = type(value)
		if kind == "table" then
			local items = {}
			for k, v in value do
				table.insert(items, string.format("%q:%s", tostring(k), encode(v)))
			end
			table.sort(items)
			return "{" .. table.concat(items, ",") .. "}"
		elseif kind == "string" then
			return string.format("%q", value)
		elseif kind == "boolean" then
			return tostring(value)
		end
		return tostring(value)
	end
	for _, r in rows do
		table.insert(parts, encode(r))
	end
	local linkParts = {}
	for _, l in links do
		table.insert(linkParts, encode(l))
	end
	print(string.format('{"hitstunLight":%d,"hitstunHeavy":%d,"deflectWindow":%d,"moves":[%s],"links":[%s]}',
		ms(HITSTUN), ms(HITSTUN_HEAVY), ms(DEFLECT), table.concat(parts, ","), table.concat(linkParts, ",")))
	return
end

print(string.format("Light hitstun %d ms (defend from %d ms), heavy hitstun %d ms, deflect window %d ms, tempo %.1fx", ms(HITSTUN), ms(DEFEND), ms(HITSTUN_HEAVY), ms(DEFLECT), Settings.Tempo.Scalar))
print("| Weapon | Slot | Startup | Active | Recovery | Combo | Cancel@ | Total | Reach | Arc | Lunge |")
print("|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
for _, r in rows do
	print(string.format("| %s | %s | %d | %d | %d | %d | %d | %d | %.1f | %s | %.1f |", r.weapon, r.slot, r.startup, r.active, r.recovery,
		r.combo, r.cancel, r.total, r.reach, tostring(r.arc), r.lunge or 0))
end
print("")
print("| Weapon | Link | Contact interval (ms, fastest..slowest) | Gap after light hitstun (ms) | Class (attack answer) | Deflect press width before (ms) | after (ms) |")
print("|---|---|---|---|---|---|---|")
for _, l in links do
	local class = if l.trueCombo and not l.deflectAnswer then "true combo"
		elseif l.trueCombo then "true if pressed early; answerable if delayed"
		else "answerable (gap)"
	print(string.format("| %s | %s | %d..%d | %d..%d | %s | %d..%d | %d..%d |", l.weapon, l.link, l.fastest, l.slowest, l.gapFastest, l.gapSlowest, class,
		l.answerBefore[1], l.answerBefore[2], l.answerAfter[1], l.answerAfter[2]))
end
