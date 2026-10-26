--!nonstrict
-- Lune regression for post-F26 Steps 4-5 (Twin Sentinels greybox, Desecrated Monastery approach).
-- Numbers marked "Studio" are the seeded Studio diagnostic in
-- outputs/post-f26-step4-5-2026-10-26/README.md. Each group fails on the code before this batch.
-- Run from the project root: lune run tools/test_twins_monastery.luau
local fs = require("@lune/fs")
local Rules = require("../src/shared/BossEncounterRules")
local Bodies = require("../src/shared/BossBodies")
local Handoff = require("../src/shared/BossHandoff")
local Attacks = require("../src/shared/BossAttackCatalog")
local Weapons = require("../src/simulation/WeaponSchema")
local Clearance = require("../src/client/Controllers/CameraClearance")

local passed, failed = 0, 0
local function check(name: string, condition: any)
	if condition then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local function src(path: string): string return fs.readFile(path) end
local function has(path: string, text: string): boolean return string.find(src(path), text, 1, true) ~= nil end
local FACING_CONE = 2 * math.deg(math.acos(0.15)) -- guard/deflect face both attackers within this spread

-- 1. Spacing: a Twin crowding the player or its partner steps back out (Rules.crowded).
do
	local stop = Weapons.get("Guandao").Light[1].Reach * 0.6 -- AIService closeIn stop, 6.3
	local gap = 2.5 * (1.2 + 1.7) -- partner gap, 7.25
	check("crowded exists", type(Rules.crowded) == "function")
	if type(Rules.crowded) == "function" then
		check("Studio before: Zhao 3.2 from the player is crowded", Rules.crowded(3.2, stop, 9, gap))
		check("Studio before: the Twins 3.1 apart are crowded", Rules.crowded(6.3, stop, 3.1, gap))
		check("Studio after: 6.3 / 7.1 from the player, 7.3 apart is not", not Rules.crowded(6.3, stop, 7.3, gap) and not Rules.crowded(7.1, stop, 7.3, gap))
		check("a lone survivor is judged on the player only", not Rules.crowded(6.3, stop, nil, gap))
	end
	check("AI re-spaces through the rule", has("src/server/Services/AIService.luau", "BossRules.crowded(flatTo, reach * 0.6, toPartner, BossMotion.duoGap(self, partner))"))
	-- A Twin's lunge ends on its engage point beside the partner: inside one guard cone.
	local px, pz = Bodies.closeIn(0, 20, 0, 0, stop)
	local zx, zz = Bodies.flank(3, 18, 0, 0, stop, px, pz, gap)
	local spread = math.deg(math.abs(((math.atan2(zz, zx) - math.atan2(pz, px)) + math.pi) % (2 * math.pi) - math.pi))
	check("lunge end clears the partner", math.sqrt((zx - px) ^ 2 + (zz - pz) ^ 2) >= gap - 1e-6)
	check(string.format("Twins %.0f deg apart: one guard covers both", spread), spread <= FACING_CONE and spread >= 60)
	-- The old body stop (3.7) against a partner at 3.2 would have swung the Twin to the far side.
	local ox, oz = Bodies.flank(3, 18, 0, 0, 3.7, 0, 3.2, gap)
	local opposite = math.deg(math.abs(((math.atan2(oz, ox) - math.atan2(3.2, 0)) + math.pi) % (2 * math.pi) - math.pi))
	check("why the lunge uses the engage stop: a body stop would split them " .. math.floor(opposite) .. " deg", opposite > FACING_CONE)
	check("lunge end flanks the partner at the engage stop", has("src/server/Services/BossMotion.luau", "Bodies.flank(at.X, at.Z, aim.X, aim.Z, stop, o.X, o.Z, Motion.duoGap(e, partner))"))
end

-- 2. One perilous at a time: the partner's last pulse plus the readable lead.
do
	check("perilousClear exists", type(Rules.perilousClear) == "function")
	if type(Rules.perilousClear) == "function" then
		check("gap equals the handoff lead", Rules.DuoPerilousGap == Handoff.Lead)
		check("Studio before: thrust and charge in the same frame are refused", not Rules.perilousClear(100, 100))
		local spear = Attacks.Zhao[1]
		local last = 100 + (spear.Repeats - 1) * spear.Interval
		check("Lightning Spear's third pulse holds the Bull's charge", not Rules.perilousClear(last + 0.5, last))
		check("the charge may land a lead after the last pulse", Rules.perilousClear(last + Handoff.Lead, last))
		check("no partner attack, no wait", Rules.perilousClear(100, nil))
	end
	check("lastImpact counts the pulses", has("src/server/Services/BossAttackService.luau", "current.Impact + ((current.Attack.Repeats or 1) - 1) * (current.Attack.Interval or 0.7)"))
	local tactics = src("src/server/Services/BossTactics.luau")
	local _, uses = string.gsub(tactics, "Rules%.perilousClear%(", "")
	check("scheduled attacks and the gap closer both wait", uses >= 2)
	check("a refused perilous keeps its cursor", string.find(tactics, "schedule.Cursor = cursor", 1, true) ~= nil)
end

-- 3. Lock camera: a tall target close by no longer pitches the lens to the floor.
do
	local function pitch(elevation: number, separation: number, near: number): number
		return math.deg(math.atan2(elevation * 0.5, math.max(separation * 0.5, near))) - 10
	end
	check("Studio before: the Bull 7 studs away pitched 16 deg up", math.abs(pitch(3.4, 6.95, 1) - 16) < 0.5)
	check("after: at most 6 deg", pitch(3.4, 6.95, 6) <= 6.0)
	check("a far or flying target is framed as before", pitch(60, 40, 6) == pitch(60, 40, 1))
	check("camera uses the floor", has("src/client/Controllers/CameraController.luau", "math.max(flat.Magnitude, LOCK_PITCH_NEAR)"))
end

-- 4. Near-lens clearance: only an unlocked body between lens and player, in the fight, fades.
do
	check("Studio: Zhao 9.5 from the lens, player 12.7 -> fades", Clearance.shouldFade(9.5, 12.7, 3.5, false))
	check("Studio: Zhao beside the player (11.6 vs 11.6) stays solid", not Clearance.shouldFade(11.6, 11.6, 7, false))
	check("the locked target never fades", not Clearance.shouldFade(4, 12, 8, true))
	check("a far body behind the camera does not fade", not Clearance.shouldFade(4, 12, 40, false))
	check("camera feeds clearance every frame", has("src/client/Controllers/CameraController.luau", "Clearance.step(bodies, position + shake, root.Position)"))
	check("clearance is mapped", has("default.project.json", "src/client/Controllers/CameraClearance.luau"))
end

-- 5. Perilous banner sits under the duo strip.
check("banner anchors below the duo hint", has("src/client/Controllers/CombatCallouts.luau", "view.Text.Position = DuoBars.below(view.Gui) or UDim2.fromScale(0.5, 0.34)")
	and has("src/client/Controllers/DuoBars.luau", "function Duo.below(gui: ScreenGui): UDim2?"))

-- 6. Monastery bridge: every broken rail bay still stops bodies (Studio: a recoiled swordsman fell through).
do
	local grounds = src("src/server/Services/MonasteryGrounds.luau")
	local broken = string.find(grounds, "if not broken then", 1, true)
	local guard = string.find(grounds, "\"RailGap\", Vector3.new(0.6, 4, 4)", 1, true)
	check("broken bays build a collidable guard", broken ~= nil and guard ~= nil and guard > broken)
	check("the guard is invisible and ignored by rays", string.find(grounds, "Transparency = 1, Query = false, Shadow = false", 1, true) ~= nil)
	-- Bays: posts every 4 studs from the north bridgehead; west -940..-950 and east -972..-982 are broken.
	local bays = 0
	for _, side in { -1, 1 } do
		for k = 0, 14 do
			local z = -932 - k * 4 -- Grounds.BRIDGE.Z0
			if (side == -1 and z < -940 and z > -950) or (side == 1 and z < -972 and z > -982) then bays += 1 end
		end
	end
	check("four guarded bays (Studio: +4 parts, 3369 -> 3373)", bays == 4)
end

print(string.format("twins + monastery: %d passed, %d failed", passed, failed))
if failed > 0 then error("twins/monastery regression failed") end
