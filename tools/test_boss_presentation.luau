--!nonstrict
-- Lune regression for playtest findings #13, #16, #17 and #23 (batches 11-13). Runs the real
-- CostumeKit, BossSkin, EncounterHandoff, EncounterHandoffController, CreatureMotion poses and the
-- BossHandoff/BossBodies rules: every boss look validates and builds non-colliding on a rig, the
-- Twins resolve their own skins, a valid template binds and a broken one is diagnosed, weapons end
-- at the server's reach, creature bodies sit inside their hurt capsules with feet on the ground,
-- the Titan leaves the ankle camera clear, the beast steers and leaps clear of the pillars, and
-- the entry handoff protects, holds, skips and restores. Geometry uses nominal R15 rest poses and
-- emulated Model:ScaleTo; it is not a Studio view of the bosses.
-- Run from the project root: lune run tools/test_boss_presentation.luau
local fs = require("@lune/fs")
local Scene = require("./rig_scene")
local Schema = require("../src/shared/CostumeSchema")
local Bodies = require("../src/shared/BossBodies")
local HandoffRules = require("../src/shared/BossHandoff")
local BossRules = require("../src/shared/BossEncounterRules")
local TutorialRules = require("../src/shared/TutorialRules")
local InputMap = require("../src/shared/InputMap")
local Combat = require("../src/simulation/CombatRules")
local Weapons = require("../src/simulation/WeaponSchema")
local World = require("../src/shared/WorldDefinitions")
local AnimRules = require("../src/shared/BossAnimationRules")
local Attacks = require("../src/shared/BossAttackCatalog")
local V3, CF, Instance = Scene.V3, Scene.CF, Scene.Instance

local passed, failed = 0, 0
local function check(name: string, condition: any)
	if condition then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local function src(path: string): string return fs.readFile(path) end
local LOOKS = {}
for _, file in { "LooksDuelists", "LooksBeasts", "LooksSovereigns" } do
	for key, look in Scene.load("src/shared/" .. file .. ".luau", { script = { Parent = { CostumeSchema = Schema } } }) do LOOKS[key] = look end
end
local BOSS_LOOK = { GrandmasterShen = "GrandmasterShen", TwinSentinels = "GeneralZhao", VenerableBaize = "VenerableBaize",
	SlumberingTitan = "SlumberingTitan", SovereignWu = "SovereignWu", AzureWyrm = "AzureWyrm" }

-- 1. Every boss look is valid data, within budget, and each two-phase boss changes visibly.
for key, look in LOOKS do
	local ok, problems = Schema.validate(look)
	check(key .. " look validates (" .. table.concat(problems, "; ") .. ")", ok)
	if (look.Phases or 1) > 1 then
		local only = { 0, 0 }
		for _, p in look.Pieces do if p.Phase then only[p.Phase] += 1 end end
		check(key .. " phase 1 and 2 each own pieces", only[1] >= 2 and only[2] >= 3)
	end
end
for id, key in BOSS_LOOK do check(id .. " has an authored look", LOOKS[key] ~= nil and World.Bosses[id] ~= nil) end
check("the Twins are dressed apart", LOOKS.GeneralZhao and LOOKS.IronBull and LOOKS.GeneralZhao.Key ~= LOOKS.IronBull.Key)

-- 2. Weapons end where the authoritative strike does: tip ~ (weapon reach + bonus), scaled.
local function tip(look, phase: number): number
	local far = 0
	for _, p in look.Pieces do
		if p.Role == "Weapon" and Schema.visible(p, phase) then
			local c, e = Scene.box(p)
			far = math.max(far, math.sqrt(c.X ^ 2 + c.Z ^ 2) + math.max(e.X, e.Z))
		end
	end
	return far
end
local cases = {
	{ "Shen jian", LOOKS.GrandmasterShen, 1, Weapons.Weapons.Jian.Reach, 1 },
	{ "Shen chimera glaive", LOOKS.GrandmasterShen, 2, Weapons.Weapons.Guandao.Reach + 2.5, 1 },
	{ "Zhao guandao", LOOKS.GeneralZhao, 1, Weapons.Weapons.Guandao.Reach, 1.2 },
	{ "Iron Bull maul", LOOKS.IronBull, 1, Weapons.Weapons.IronBullMaul.Reach, 1.7 },
	{ "Wu staff", LOOKS.SovereignWu, 1, Weapons.Weapons.Catalyst.Reach, 1.2 },
}
for _, case in cases do
	local reach = tip(case[2], case[3]) * case[5]
	check(string.format("%s tip %.1f vs reach %.1f", case[1], reach, case[4]), math.abs(reach - case[4]) <= 1.25)
end
check("roster scales match the authored weapon lengths", World.Bosses.TwinSentinels.Scale == 1.2 and World.Bosses.TwinSentinels.Partner.Scale == 1.7
	and World.Bosses.SovereignWu.Scale == 1.2 and (World.Bosses.GrandmasterShen.Scale or 1) == 1)

-- 3. Creature bodies sit inside their hurt capsules; feet on the ground; hull within the body.
local function segDistance(p, a, b): number
	local ab, ap = b - a, p - a
	local t = math.clamp(ap:Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
	return (p - (a + ab * t)).Magnitude
end
for _, pair in { { "VenerableBaize", "Beast" }, { "AzureWyrm", "Dragon" } } do
	local look, shape = LOOKS[pair[1]], Bodies.Shapes[pair[2]]
	local caps = {}
	for _, c in shape.Capsules do table.insert(caps, { A = V3.new(c.A[1], c.A[2], c.A[3]), B = V3.new(c.B[1], c.B[2], c.B[3]), R = c.Radius }) end
	local outside, feet, grounded = {}, 0, 0
	for _, p in look.Pieces do
		local centre = Scene.box(p)
		if p.Role == "Body" then
			local best = math.huge
			for _, c in caps do best = math.min(best, segDistance(centre, c.A, c.B) - c.R) end
			if best > 0.45 then table.insert(outside, p.Name) end
		elseif p.Role == "Foot" then
			feet += 1
			local c, e = Scene.box(p)
			if math.abs((c.Y - e.Y) - Schema.Ground) <= 0.12 then grounded += 1 end
		end
	end
	check(pair[1] .. " body pieces lie on its hurt capsules (" .. table.concat(outside, ",") .. ")", #outside == 0)
	check(pair[1] .. " four feet rest on the ground", feet == 4 and grounded == 4)
	local covered = 0
	for _, c in caps do
		for _, point in { c.A, c.B } do
			for _, p in look.Pieces do
				local centre, e = Scene.box(p)
				local d = point - centre
				if p.Role == "Body" and math.abs(d.X) <= e.X + 0.3 and math.abs(d.Y) <= e.Y + 0.3 and math.abs(d.Z) <= e.Z + 0.3 then covered += 1; break end
			end
		end
	end
	check(pair[1] .. " every capsule end is inside visible body", covered == #caps * 2)
	local hull = Bodies.Hulls[pair[2]]
	check(pair[1] .. " world hull stays off the floor", hull[5] - hull[2] / 2 > Schema.Ground + 1)
	check(pair[1] .. " broad-phase reach covers the capsules", shape.Reach >= 3.4)
end

-- 4. Titan: slim shins and a camera that stays clear behind a player at the ankles (scale 3).
local titan, scale = LOOKS.SlumberingTitan, 3
local boxes = {}
for _, p in titan.Pieces do local c, e = Scene.box(p); table.insert(boxes, { C = c * scale, E = e * scale, Name = p.Name }) end
for bone, spec in Schema.R15 do
	if bone ~= "HumanoidRootPart" then
		table.insert(boxes, { C = V3.new(spec.At[1], spec.At[2], spec.At[3]) * scale, E = V3.new(spec.Size[1], spec.Size[2], spec.Size[3]) * (scale / 2), Name = bone })
	end
end
local function hitsBox(a, b, box): boolean
	local lo, hi = box.C - box.E, box.C + box.E
	local t0, t1 = 0, 1
	for _, axis in { "X", "Y", "Z" } do
		local d = b[axis] - a[axis]
		if math.abs(d) < 1e-6 then
			if a[axis] < lo[axis] or a[axis] > hi[axis] then return false end
		else
			local u, v = (lo[axis] - a[axis]) / d, (hi[axis] - a[axis]) / d
			t0, t1 = math.max(t0, math.min(u, v)), math.min(t1, math.max(u, v))
			if t0 > t1 then return false end
		end
	end
	return true
end
local ground, blocked, wide, samples = Schema.Ground * scale, 0, {}, 0
for _, b in boxes do
	if b.C.Y - b.E.Y < ground + 0.55 * 3 * scale / 2 and math.abs(b.C.X) > 0 and math.max(b.E.X, b.E.Z) > 0.75 * scale then table.insert(wide, b.Name) end
end
check("nothing below the knee is wider than a slim shin (" .. table.concat(wide, ",") .. ")", #wide == 0)
for _, side in { -1, 1 } do
	for k = 0, 15 do
		local a = k / 16 * math.pi * 2
		local dir = V3.new(math.cos(a), 0, math.sin(a))
		local ankle = V3.new(side * 0.5 * scale, ground + 1, 0)
		local player = ankle + dir * (0.5 * scale + 3)
		local eye, camera = player + V3.new(0, 2, 0), player + dir * 12 + V3.new(0, 4, 0)
		local standing = true -- only places a player can stand: not inside the other leg or between them
		for _, b in boxes do
			local d = player - b.C
			if math.abs(d.X) < b.E.X + 1 and math.abs(d.Z) < b.E.Z + 1 and player.Y + 3 > b.C.Y - b.E.Y and player.Y < b.C.Y + b.E.Y then standing = false end
		end
		if not standing then continue end
		samples += 1
		for _, b in boxes do if hitsBox(eye, camera, b) then blocked += 1; print("  camera ray meets " .. b.Name); break end end
	end
end
check("follow camera behind a player at either ankle never passes through the Titan (" .. blocked .. "/" .. samples .. ")", blocked == 0 and samples >= 16)

-- 5. Baize steers round the pillars and its pounce never clips one.
local boss = World.Bosses.VenerableBaize
local pillars = Bodies.pillars(boss)
check("four frost pillars from shared data", #pillars == 4 and src("src/server/Services/BossArenas.luau"):find("Bodies.pillars(boss)", 1, true))
local clear = Bodies.Hulls.Beast[3] * 0.5 * boss.Scale + 0.5
math.randomseed(11)
local rng, inside, stuck = { NextNumber = function(_, a, b) return a + (b - a) * math.random() end }, 0, 0
local c = boss.Arena.Center
for _ = 1, 160 do
	local x, z = c.X + rng:NextNumber(-80, 80), c.Z + rng:NextNumber(-80, 80)
	local tx, tz = c.X + rng:NextNumber(-80, 80), c.Z + rng:NextNumber(-80, 80)
	local ok = true
	for _, p in pillars do if math.abs(x - p.X) < p.Half + clear + 1 and math.abs(z - p.Z) < p.Half + clear + 1 then ok = false end end
	for _, p in pillars do if math.abs(tx - p.X) < p.Half + clear + 1 and math.abs(tz - p.Z) < p.Half + clear + 1 then ok = false end end
	if not ok then continue end
	local arrived = false
	for _ = 1, 600 do
		local wx, wz = Bodies.steer(x, z, tx, tz, pillars, clear)
		local dx, dz = wx - x, wz - z
		local len = math.sqrt(dx * dx + dz * dz)
		if math.sqrt((tx - x) ^ 2 + (tz - z) ^ 2) < 1 then arrived = true; break end
		x, z = x + dx / math.max(len, 1e-6) * math.min(len, 0.5), z + dz / math.max(len, 1e-6) * math.min(len, 0.5)
		for _, p in pillars do if math.abs(x - p.X) < p.Half + clear * 0.5 and math.abs(z - p.Z) < p.Half + clear * 0.5 then inside += 1 end end
	end
	if not arrived then stuck += 1 end
end
check("steered walks never enter a pillar's footprint", inside == 0)
check("steered walks reach their goal", stuck == 0)
local high, clipped, oldClipped = 0, 0, 0
for k = 1, 40 do
	local p = pillars[(k % 4) + 1]
	local perchY = Bodies.perchY(p, boss.Scale)
	high = perchY
	local a = rng:NextNumber(0, math.pi * 2)
	local r = rng:NextNumber(4 + clear, 70)
	local from = { p.X + math.cos(a) * r, 3 * boss.Scale, p.Z + math.sin(a) * r }
	local perch, radius = { p.X, perchY, p.Z }, p.Half * math.sqrt(2) + 2.5 * boss.Scale
	for step = 0, 40 do
		local u = step / 40
		for _, path in { Bodies.arc(from, perch, perchY, radius, false, true, u), Bodies.arc(perch, from, perchY, radius, true, false, u) } do
			local d = math.sqrt((path[1] - p.X) ^ 2 + (path[3] - p.Z) ^ 2)
			if d < p.Half + 2.5 * boss.Scale * 0.5 and path[2] - 3 * boss.Scale < p.Top - 0.01 then clipped += 1 end
		end
		local old = { from[1] + (perch[1] - from[1]) * u, from[2] + (perch[2] - from[2]) * u, from[3] + (perch[3] - from[3]) * u }
		local d = math.sqrt((old[1] - p.X) ^ 2 + (old[3] - p.Z) ^ 2)
		if d < p.Half + 2.5 * boss.Scale * 0.5 and old[2] - 3 * boss.Scale < p.Top - 0.01 then oldClipped += 1 end
	end
end
check("pounce rises before and falls after the column (0 clipping samples)", clipped == 0)
check("the old straight-line pounce clipped the column (regression proof)", oldClipped > 0)
check("perched feet rest on the pillar top", math.abs(high - 3 * boss.Scale - pillars[1].Top - 0.2) < 1e-6)

-- 6. Real CostumeKit on rigs: non-colliding welded pieces, phases, hidden creature bodies.
local Kit = Scene.load("src/server/Services/CostumeKit.luau", { game = { GetService = function() return { WaitForChild = function() return { Shared = { CostumeSchema = Schema } } end } end } })
for key, look in LOOKS do
	local rig = Scene.rig(key)
	local stock = Instance.new("Part"); stock.Name = "AsuraWeapon"; stock.Parent = rig
	local folder, missing = Kit.build(rig, look, 1)
	local bad, count = 0, 0
	for _, piece in folder:GetChildren() do
		count += 1
		local weld = piece:FindFirstChild("AsuraBind")
		if piece.CanCollide or piece.CanQuery or piece.CanTouch or not piece.Massless or piece.Anchored or not weld or weld.Part1 ~= piece or weld.Part0.Parent ~= rig then bad += 1 end
	end
	check(key .. " every piece is a non-colliding welded part on a live limb", bad == 0 and count == #look.Pieces and #missing == 0)
	check(key .. " carries its own weapon (generic block removed)", rig:FindFirstChild("AsuraWeapon") == nil and rig:GetAttribute("AsuraWeaponVisual") == "Costume")
	local hidden = rig:FindFirstChild("UpperTorso").Transparency == 1
	check(key .. " creature looks hide the humanoid, humanoid looks keep it", hidden == (look.Rig == "Creature"))
	if (look.Phases or 1) > 1 then
		Kit.phase(rig, 2)
		local wrong = 0
		for _, piece in folder:GetChildren() do
			local tag = piece:GetAttribute("AsuraPhase")
			if tag and (piece.Transparency == 1) ~= (tag ~= 2) then wrong += 1 end
		end
		check(key .. " phase 2 shows its own pieces and hides phase 1's", wrong == 0)
	end
end
local beast = Scene.rig("Baize")
Kit.build(beast, LOOKS.VenerableBaize, 1)
local leg = beast.AsuraAttire:FindFirstChild("ForelegL")
local hinge = leg:GetAttribute("AsuraPivot") * leg.Size
local expect = leg.AsuraBind.C0:PointToObjectSpace(V3.new(-0.75, -1.05, -1.25))
check("joint hinge stored scale-free and maps back to the authored shoulder", (hinge - expect).Magnitude < 1e-4)
beast:ScaleTo(1.5)
check("hinge survives Model:ScaleTo (emulated)", ((leg:GetAttribute("AsuraPivot") * leg.Size) - expect * 1.5).Magnitude < 1e-3)
local finger = Scene.rig("Wyrm"); Kit.build(finger, LOOKS.AzureWyrm, 1)
check("wing tips ride the inner wing (second hinge)", finger.AsuraAttire.WingFingerL:GetAttribute("AsuraPivot2") ~= nil)
local shen = Scene.rig("Shen"); Kit.build(shen, LOOKS.GrandmasterShen, 1)
check("rig skin and cloth take the phase colours", shen.Head.Color == shen.AsuraAttire:GetAttribute("Skin1") and shen.UpperTorso.Color == shen.AsuraAttire:GetAttribute("Cloth1"))
Kit.phase(shen, 2)
check("chimera recolours the rig", shen.UpperTorso.Color == shen.AsuraAttire:GetAttribute("Cloth2"))

-- 7. Skin binding: per-actor keys, phase templates, valid binding, diagnosed failures.
local function mesh(name, bone)
	local m = Instance.new("MeshPart"); m.Name = name; m:SetAttribute("AsuraBone", bone)
	local a = Instance.new("Attachment"); a.Name = "AsuraBind"; a.CFrame = CF.new(); a.Parent = m
	m.Size, m.CFrame = V3.new(1, 1, 1), CF.new()
	return m
end
local library = Instance.new("Folder"); library.Name = "AsuraAssets"
local function template(name, bones)
	local t = Instance.new("Model"); t.Name = name
	for _, b in bones do mesh("Skin" .. b, b).Parent = t end
	t.Parent = library
	return t
end
local full = table.clone(Schema.RequiredBones.Humanoid)
template("AsuraBoss_GeneralZhao", full)
template("AsuraBoss_IronBull_P1", full)
template("AsuraBoss_GrandmasterShen_P2", { "Head", "UpperTorso" })
local storage = { FindFirstChild = function(_, n) return if n == "AsuraAssets" then library else nil end }
local Skin = Scene.load("src/server/Services/BossSkin.luau", {
	game = { GetService = function(_, n) return if n == "ServerStorage" then storage else { WaitForChild = function() return { Shared = { CostumeSchema = Schema } } end } end },
	script = { Parent = { PbrAssets = { validate = function() return true end } } } })
local function actor(key, encounter, phase)
	local rig = Scene.rig(key)
	rig:SetAttribute("AsuraLookKey", key); rig:SetAttribute("AsuraEncounter", encounter); rig:SetAttribute("AsuraBossPhase", phase)
	return rig
end
local zhao, bull = actor("GeneralZhao", "TwinSentinels", 1), actor("IronBull", "TwinSentinels", 1)
check("each Twin resolves its own template", Skin.resolve(library, zhao).Name == "AsuraBoss_GeneralZhao" and Skin.resolve(library, bull).Name == "AsuraBoss_IronBull_P1")
Kit.build(zhao, LOOKS.GeneralZhao, 1)
check("a valid template binds, hides the rig and the costume but keeps the weapon", Skin.attach(zhao) and zhao:FindFirstChild("AsuraBossSkin")
	and zhao.UpperTorso.Transparency == 1 and zhao.AsuraAttire.Lamellar0.Transparency == 1 and zhao.AsuraAttire.GuandaoHaft.Transparency == 0
	and zhao:GetAttribute("AsuraSkinStatus") == "Template:AsuraBoss_GeneralZhao")
local bound = 0
for _, p in zhao.AsuraBossSkin:GetChildren() do if p:FindFirstChildOfClass("WeldConstraint") and not p.CanCollide and not p.CanQuery then bound += 1 end end
check("skin meshes are welded, non-colliding and non-querying", bound == #full and #full == 15)
local shenActor = actor("GrandmasterShen", "GrandmasterShen", 2)
check("an incomplete phase template is refused and diagnosed", not Skin.attach(shenActor) and string.find(shenActor:GetAttribute("AsuraSkinStatus"), "missing LowerTorso", 1, true))
local wu = actor("SovereignWu", "SovereignWu", 1)
check("a missing template falls back to the costume, named", not Skin.attach(wu) and string.find(wu:GetAttribute("AsuraSkinStatus"), "Fallback:Costume (no AsuraBoss_SovereignWu_P1", 1, true))
-- Post-F26 Shen handoff: a skin must cover every limb it hides, and a skin that carries its own weapon
-- replaces the costume weapon (no doubled blade); a later phase without one shows the costume weapon again.
local handless = table.clone(full); table.remove(handless, table.find(handless, "LeftHand"))
template("AsuraBoss_Handless", handless)
local handActor = actor("Handless", "Handless", 1)
check("a humanoid skin missing a hand is refused (hands would vanish)", not Skin.attach(handActor) and string.find(handActor:GetAttribute("AsuraSkinStatus"), "missing LeftHand", 1, true))
local armed = template("AsuraBoss_GrandmasterShen_P1", full)
local blade = mesh("JianBladeMesh", "RightHand"); blade:SetAttribute("AsuraRole", "Weapon"); blade.Parent = armed
library.AsuraBoss_GrandmasterShen_P2:Destroy()
template("AsuraBoss_GrandmasterShen_P2", full)
local master = actor("GrandmasterShen", "GrandmasterShen", 1)
Kit.build(master, LOOKS.GrandmasterShen, 1)
check("a skin with its own weapon hides the costume weapon", Skin.attach(master) and master.AsuraBossSkin:GetAttribute("OwnsWeapon") == true
	and master.AsuraAttire.JianBlade.Transparency == 1 and master.AsuraBossSkin.JianBladeMesh.Transparency == 0)
Kit.phase(master, 1)
check("re-showing the phase keeps the costume weapon hidden under a weapon skin", master.AsuraAttire.JianBlade.Transparency == 1)
master:SetAttribute("AsuraBossPhase", 2); Kit.phase(master, 2)
check("phase 2 skin without a weapon shows the costume glaive again", Skin.attach(master) and master.AsuraBossSkin:GetAttribute("OwnsWeapon") == false
	and master.AsuraAttire.GlaiveHaft.Transparency == 0 and master.AsuraAttire.JianBlade.Transparency == 1
	and master:GetAttribute("AsuraSkinStatus") == "Template:AsuraBoss_GrandmasterShen_P2")
check("creature skins only need the root bone", Schema.RequiredBones.Creature[1] == "HumanoidRootPart" and #Schema.RequiredBones.Creature == 1)
check("template names: phase, look, then legacy", table.concat(Schema.templates("GeneralZhao", 2, "TwinSentinels", "Ancient Oath"), ",")
	== "AsuraBoss_GeneralZhao_P2,AsuraBoss_GeneralZhao,AsuraBoss_TwinSentinels_Ancient Oath,AsuraBoss_TwinSentinels")

-- 8. The entry handoff (#16): lock, protection, hold, deferral, skip, release.
local window = HandoffRules.window("Intro", 10)
check("lock covers the shot, protection adds the camera blend", window.Lock == 10 + HandoffRules.Shots.Intro and window.Ends == window.Lock + HandoffRules.Blend)
check("no impact before readable control + lead", HandoffRules.defer(10.5, window) == window.Ends + HandoffRules.Lead and HandoffRules.defer(99, window) == 99)
local skipped = HandoffRules.skip(window, 11)
check("skipping ends the lock now and keeps the blend", skipped.Lock == 11 and skipped.Ends == 11 + HandoffRules.Blend and skipped.Skipped)
local fighters, now, held = {}, 100, {}
for _, id in { 1, 2, -9 } do fighters[id] = { Fighter = Combat.new(id, "Jian", 0) } end
local Characters = { Now = function() return now end, GetEntity = function(id) return fighters[id] end,
	Cinematic = function(id, d) Combat.cinematic(fighters[id].Fighter, now, d) end }
local Handoff = Scene.load("src/server/Services/EncounterHandoff.luau", {
	game = { GetService = function() return { WaitForChild = function() return { Shared = { BossHandoff = HandoffRules } } end } end },
	script = { Parent = { CharacterService = Characters } } })
Handoff.SetHolder(function(boss, t) held[boss] = t end)
local open = Handoff.begin("TwinSentinels", "Intro", { 1, 2 }, { -9 })
local function hit(id) return Combat.applyArea(fighters[-9].Fighter, fighters[id].Fighter, now, 40, 20, true, true, {}) end
now = 101
check("participants are locked and cannot be struck during the shot", hit(1) == "Whiff" and fighters[1].Fighter.State == "Recovery" and Combat.isInvulnerable(fighters[2].Fighter, now))
check("the boss is held until control returns", held.TwinSentinels == open.Ends)
check("boss impacts defer to the readable lead", Handoff.defer("TwinSentinels", 101.2) == open.Ends + HandoffRules.Lead)
local ok1 = Handoff.skip(1)
now = 101 + HandoffRules.Blend + 0.01
check("one skip frees only that player, after the blend", ok1 and not Combat.isInvulnerable(fighters[1].Fighter, now) and Combat.isInvulnerable(fighters[2].Fighter, now)
	and held.TwinSentinels == open.Ends)
local before = held.TwinSentinels
Handoff.skip(2)
check("when everyone has skipped the boss hold ends with them", held.TwinSentinels < before and held.TwinSentinels == now + HandoffRules.Blend)
check("a second skip is refused", not Handoff.skip(2))
fighters[1].Fighter = Combat.new(1, "Jian", 0)
Handoff.begin("GrandmasterShen", "Phase", { 1 })
now = 101.3
Handoff.release(1)
check("death/leave releases the lock immediately", not Combat.isInvulnerable(fighters[1].Fighter, now + 0.01) and not Handoff.isProtected(1))
check("protection ends exactly when control resumes", (function()
	fighters[2].Fighter = Combat.new(2, "Jian", 0)
	local w = Handoff.begin("SovereignWu", "Intro", { 2 })
	now = w.Ends - 0.01
	local inside = hit(2) == "Whiff"
	now = w.Ends + 0.01
	return inside and hit(2) == "Hit"
end)())
local ai = src("src/server/Services/AIService.luau")
check("phase wave is scheduled no sooner than the handoff allows", string.find(ai, "scheduleShockwave(agent, transition.Shockwave, now, false, HandoffRules.earliest(window))", 1, true) ~= nil)
check("boss entry opens the Intro handoff and announces the shot", string.find(ai, 'Handoff.begin(boss.Id, "Intro", participants, members)', 1, true) and string.find(ai, "shot = shot })", 1, true))
check("held bosses neither move nor attack", string.find(ai, "if now < agent.HoldUntil then", 1, true) and string.find(src("src/server/Services/BossTactics.luau"), "function Tactics.hold", 1, true))
check("every boss impact passes the handoff", string.find(src("src/server/Services/BossAttackService.luau"), "impact = Handoff.defer(encounter, impact)", 1, true) ~= nil)
check("fights forget their handoff; leavers are released", string.find(src("src/server/Services/WorldService.luau"), "EncounterHandoff.forget(fight.BossId)", 1, true)
	and string.find(src("src/server/Services/WorldService.luau"), "EncounterHandoff.release(userId)", 1, true))
local phaseWindow = HandoffRules.window("Phase", 0)
for id, boss in World.Bosses do
	for _, phase in boss.Phases do
		if phase.Transition then
			check(id .. " transition still ends near its authored length", HandoffRules.earliest(phaseWindow) <= phase.Transition.Duration + 0.1)
		end
	end
end

-- 9. Client side of the handoff: shot, closed input, skip on any command, restore on reset/KO.
local log = {}
local camera = { BossShotState = nil }
function camera:BossShot(id, d) self.BossShotState = { Id = id, D = d }; table.insert(log, "shot" .. d) end
function camera:EndBossShot() self.BossShotState = nil; table.insert(log, "end") end
local input = { MenuOpen = false, OnCommand = nil }
function input:SetMenu(open) self.MenuOpen = open; table.insert(log, "menu" .. tostring(open)) end
function input:Label(c) return if c == "Interact" then "E" else "?" end
local cueListener, sent = nil, {}
local own = { Snapshot = { State = "Idle" } }
local state = { LocalId = 7, OnCue = function(_, f) cueListener = f; return function() end end, Own = function() return own end }
local pill = Instance.new("TextButton")
local Controller = Scene.load("src/client/Controllers/EncounterHandoffController.luau", {
	game = { GetService = function(_, n) return if n == "Players" then { LocalPlayer = { GetAttribute = function() return "TwinSentinels" end } } else { WaitForChild = function() return { Shared = { InputMap = InputMap } } end } end },
	script = { Parent = { WaitForChild = function(_, n) return n end } },
	require = function(m) return if m == "UiKit" then { button = function() return pill end } else m end })
local client = Controller.new(state, camera, input, { Gui = Instance.new("ScreenGui") }, function(a) table.insert(sent, a) end)
cueListener({ Kind = "BossIntro", Source = -9, Data = { participants = { 7 }, shot = 2.4, boss = "TwinSentinels" } })
check("entry shot frames the boss for the server's lock and closes input", camera.BossShotState and camera.BossShotState.D == 2.4 and input.MenuOpen and pill.Visible)
input.OnCommand("Light")
check("any command skips: intent sent, camera and input restored", sent[1] == "Skip" and camera.BossShotState == nil and not input.MenuOpen and not pill.Visible)
cueListener({ Kind = "BossPhase", Source = -9, Data = { participants = { 7 }, shot = 1.2 } })
cueListener({ Kind = "BossReset", Source = -9, Data = {} })
check("reset ends a shot and restores input", camera.BossShotState == nil and not input.MenuOpen)
cueListener({ Kind = "BossEnrage", Source = -9, Data = { boss = "TwinSentinels", shot = 1.1 } })
own.Snapshot.State = "KO"; client:Update()
check("death mid-shot restores the follow camera and input", camera.BossShotState == nil and not input.MenuOpen)
own.Snapshot.State = "Idle"
cueListener({ Kind = "BossPhase", Source = -9, Data = { participants = { 8 }, boss = "Other", shot = 1.2 } })
check("other players' shots are ignored", camera.BossShotState == nil)
cueListener({ Kind = "BossIntro", Source = -9, Data = { participants = { 7 }, shot = 2.4 } })
camera.BossShotState = nil; client:Update()
check("a shot that ends naturally reopens input", not input.MenuOpen and #sent == 1)
check("bootstrap mounts the handoff and creature controllers", string.find(src("src/client/Bootstrap.client.luau"), "Handoff.new(state, camera, input, ui", 1, true)
	and string.find(src("src/client/Bootstrap.client.luau"), "creatures:Update(frame)", 1, true))
check("interface leaves handoff shots to the controller", string.find(src("src/client/Controllers/InterfaceController.luau"), "if data.shot == nil then self.Camera:BossShot", 1, true) ~= nil)
check("boss framing grows with the actor", string.find(src("src/client/Controllers/BossCinematics.luau"), "span * 1.4 + 6", 1, true) ~= nil)

-- 10. Creature poses, readable phase VFX and counter teaching (#13).
local Motion = Scene.load("src/client/Controllers/CreatureMotion.luau", { game = { GetService = function() return {} end } })
local fl, fr, hl = Motion.angles("LegFL", 0, 1, 1, nil, false), Motion.angles("LegFR", 0, 1, 1, nil, false), Motion.angles("LegHR", 0, 1, 1, nil, false)
check("trot moves diagonal legs together and opposite pairs apart", math.abs(fl - hl) < 1e-9 and math.abs(fl + fr) < 1e-9 and math.abs(fl) > 0.1)
check("legs rest when standing", Motion.angles("LegFL", 0, 1, 0, nil, false) == 0)
check("jaw opens for grabs and breath", Motion.angles("Jaw", 0, 0, 0, "PerilousGrab", false) > math.rad(20) and Motion.angles("Jaw", 0, 0, 0, nil, false) < math.rad(6))
local _, _, flap = Motion.angles("WingL", 0.2, 0, 0, nil, true)
local _, _, fold = Motion.angles("WingL", 0.2, 0, 0, nil, false)
check("wings beat in flight and fold on the ground", math.abs(flap) > math.rad(10) and fold < 0 and fold > math.rad(-20))
local _, sweep = Motion.angles("Tail1", 0.25, 0, 0, "Tail", false)
check("tail strike sweeps wide", math.abs(sweep) > math.rad(15))
local effects = src("src/client/Controllers/BossEffects.luau")
check("phase bloom is translucent and sized to the actor, not 35 studs", string.find(effects, "Vector3.one * span * 1.6", 1, true) and not string.find(effects, "Vector3.one * 35", 1, true))
local counters = {}
for _, kind in { "PerilousSweep", "PerilousThrust", "PerilousGrab", "Gravity", "Shockwave", "Barrage" } do
	local _, counter = BossRules.classify(kind)
	counters[counter] = true
end
for counter in counters do
	local keys = BossRules.CounterKeys[counter]
	local text = keys and TutorialRules.text(keys, function(c) return InputMap.label(c, "Keyboard") end)
	check("counter '" .. counter .. "' teaches real keys: " .. tostring(text), text and not string.find(text, "{", 1, true) and not string.find(text, "[?]", 1, true))
end
check("hints only on the first few warnings", BossRules.CounterHintCount == 3 and string.find(src("src/client/Controllers/CombatHud.luau"), "count <= BossRules.CounterHintCount", 1, true))
check("felled-in-flight bosses come down before dissolving", string.find(src("src/server/CharacterService.luau"), "A boss felled mid-flight", 1, true) ~= nil)

-- 11. The shared boss animation contract (F10): per actor, phase and attack, honest fallbacks.
local function attrs(t) return function(name) return t[name] end end
local none = attrs({})
for look, sets in AnimRules.Moves do
	for phase = 1, #sets do
		local slots = AnimRules.slots(look, phase)
		local stock, ids = 0, 0
		for _, action in slots do
			local r = AnimRules.resolve(look, phase, action, nil, "R15", none)
			if r.Source == "Stock" and AnimRules.validId(r.Id) then stock += 1 end
			if string.sub(r.Key, 1, #look + 3) == look .. "_P" .. phase then ids += 1 end
		end
		check(look .. " P" .. phase .. ": every slot falls back to a stock track under its own key", stock == #slots and ids == #slots)
		for _, move in Attacks[sets[phase]] do check(look .. " P" .. phase .. " requests " .. move.Id, table.find(slots, move.Id) ~= nil) end
	end
end
check("every roster boss look has a move contract", AnimRules.Moves.GrandmasterShen and AnimRules.Moves.AzureWyrm and AnimRules.Moves.IronBull and AnimRules.Moves.GeneralZhao)
local spears = AnimRules.resolve("SovereignWu", 1, "SoulSpears", nil, "R15", none)
local thrust = AnimRules.resolve("GeneralZhao", 1, "LightningSpear", nil, "R15", none)
check("attack kinds pick their stand-in (cast vs thrust)", spears.Id ~= thrust.Id and spears.Key == "SovereignWu_P1_SoulSpears" and not spears.Looped)
local creature = AnimRules.resolve("VenerableBaize", 2, "MeteorPounce", nil, "Creature", none)
check("a creature with nothing authored keeps its procedural pose", creature.Source == "Procedural" and creature.Id == nil)
local wide = attrs({ AsuraBossAnimation_SlumberingTitan_CryptHand = "rbxassetid://111" })
check("a look-wide override survives the phase change", AnimRules.resolve("SlumberingTitan", 1, "CryptHand", nil, "Creature", wide).Id == "rbxassetid://111"
	and AnimRules.resolve("SlumberingTitan", 2, "CryptHand", nil, "Creature", wide).Source == "Override")
local phased = attrs({ AsuraBossAnimation_SovereignWu_P2_Idle = "rbxassetid://222", AsuraBossAnimation_SovereignWu_Idle = "rbxassetid://333" })
check("a phase override beats the look-wide one only in its phase", AnimRules.resolve("SovereignWu", 2, "Idle", nil, "R15", phased).Id == "rbxassetid://222"
	and AnimRules.resolve("SovereignWu", 1, "Idle", nil, "R15", phased).Id == "rbxassetid://333")
check("an attack without its own track uses the look's Strike override", AnimRules.resolve("GeneralZhao", 1, "ThunderQuickstep", nil, "R15",
	attrs({ AsuraBossAnimation_GeneralZhao_Strike = "rbxassetid://444" })).Id == "rbxassetid://444")
check("Shen's legacy override names still count", AnimRules.resolve("GrandmasterShen", 2, "Transform", nil, "R15",
	attrs({ AsuraBossAnimation_Shen_Phase2_Transform = "rbxassetid://555" })).Source == "Override")
check("malformed overrides are ignored", AnimRules.resolve("SovereignWu", 1, "Idle", nil, "R15", attrs({ AsuraBossAnimation_SovereignWu_Idle = "555" })).Source == "Stock")
check("status names the stand-ins honestly", AnimRules.status("GrandmasterShen", 1, "R15", none) == "Fallback:Stock 0/5 authored (first missing GrandmasterShen_P1_Idle)"
	and string.find(AnimRules.status("AzureWyrm", 2, "Creature", none), "Fallback:CreatureMotion 0/6", 1, true) ~= nil)
local all = {}
for _, action in AnimRules.slots("IronBull", 1) do all["AsuraBossAnimation_IronBull_" .. action] = "rbxassetid://9" end
check("status reports a fully authored actor (Bull: 5 + 6 maul/shield swings + Zhao's 2 on the oath)", AnimRules.status("IronBull", 1, "R15", attrs(all)) == "Authored 13/13")
check("the Bull's swings are their own slots, in WeaponSchema order", #AnimRules.Melee.IronBull == 6 and AnimRules.Melee.IronBull[1] == Weapons.get("IronBullMaul").Light[1].Id
	and AnimRules.Melee.IronBull[6] == Weapons.get("IronBullMaul").WeaponArt.Id)
local guandao = Weapons.get("Guandao")
check("Zhao's Guandao swings are their own slots, in WeaponSchema order", #AnimRules.Melee.GeneralZhao == 6 and AnimRules.Melee.GeneralZhao[1] == guandao.Light[1].Id
	and AnimRules.Melee.GeneralZhao[3] == guandao.Light[3].Id and AnimRules.Melee.GeneralZhao[4] == guandao.Heavy.Id
	and AnimRules.Melee.GeneralZhao[6] == guandao.WeaponArt.Id)
local zhaoSlots = AnimRules.slots("GeneralZhao", 1)
check("Zhao requests the brief's keys, the Bull's two on the oath included", #zhaoSlots == 13 and table.find(zhaoSlots, "IronCharge")
	and table.find(zhaoSlots, "ColossalHammer") and table.find(zhaoSlots, "Transform") and table.find(zhaoSlots, "Guandao_Art"))
for action, list in AnimRules.Contacts.GeneralZhao do
	check("Zhao's " .. action .. " contacts are a slot with rising times", (table.find(zhaoSlots, action) ~= nil) and list[1] > 0
		and (list[2] == nil or list[2] > list[1]))
end
local spearMove = Attacks.Zhao[1]
check("the Lightning Spear clip's thrusts sit on the server's pulse spacing", spearMove.Id == "LightningSpear"
	and math.abs(AnimRules.Contacts.GeneralZhao.LightningSpear[1] - spearMove.Windup) < 1e-6
	and math.abs(AnimRules.Contacts.GeneralZhao.LightningSpear[2] - AnimRules.Contacts.GeneralZhao.LightningSpear[1] - spearMove.Interval) < 1e-6
	and #AnimRules.Contacts.GeneralZhao.LightningSpear == spearMove.Repeats)
local sworn = attrs({ AsuraBossEnraged = true, AsuraBossAnimation_GeneralZhao_P1_Oath_Idle = "rbxassetid://61", AsuraBossAnimation_GeneralZhao_P1_Idle = "rbxassetid://60",
	AsuraBossAnimation_GeneralZhao_P1_IronCharge = "rbxassetid://62" })
check("under the oath Zhao prefers his Oath_ clip and falls back to the plain one", AnimRules.resolve("GeneralZhao", 1, "Idle", nil, "R15", sworn).Id == "rbxassetid://61"
	and AnimRules.resolve("GeneralZhao", 1, "IronCharge", nil, "R15", sworn).Id == "rbxassetid://62"
	and AnimRules.resolve("GeneralZhao", 1, "Idle", nil, "R15", attrs({ AsuraBossAnimation_GeneralZhao_P1_Oath_Idle = "rbxassetid://61" })).Source == "Stock")
check("an unauthored reaction resolves to nothing, never a stock strike", AnimRules.resolve("GeneralZhao", 1, "PostureBreak", nil, "R15", none).Id == nil
	and AnimRules.resolve("GeneralZhao", 1, "PostureBreak", nil, "R15", none).Source == "None"
	and AnimRules.resolve("GeneralZhao", 1, "PostureBreak", nil, "R15", attrs({ AsuraBossAnimation_GeneralZhao_PostureBreak = "rbxassetid://63" })).Priority == "Action3")
check("every attack-cancelling server state has a reaction", AnimRules.Reactions.KO and AnimRules.Reactions.StanceBroken and AnimRules.Reactions.DeathblowVictim
	and AnimRules.Reactions.Hitstun and AnimRules.Reactions.GuardBroken)
-- Phase lock: the contact lands on the impact; out-of-range time holds or skips ahead.
local function near(a, b) return math.abs(a - b) < 1e-6 end
local p0, s0, h0 = AnimRules.startPlan(0.8, 0.8)
local p1, s1, h1 = AnimRules.startPlan(0.8, 2.0)
local p2, s2, h2 = AnimRules.startPlan(0.8, 0.2)
local p3, s3, h3 = AnimRules.startPlan(0.15, -0.1)
check("a fresh attack lands its contact on the impact", near(p0, 0) and near(s0, 1) and near(h0, 0)
	and near(p1, 0) and near(s1, AnimRules.SyncSpeed.Min) and near(h1 + 0.8 / s1, 2.0)
	and near(s2, AnimRules.SyncSpeed.Max) and near(h2, 0) and near(p2 + 0.2 * s2, 0.8)
	and near(p3, 0.15) and near(h3, 0))
check("a repeat cue means the thrust its impact spacing names", AnimRules.contactFor({ 0.8, 1.5, 2.2 }, 0) == 1 and AnimRules.contactFor({ 0.8, 1.5, 2.2 }, 0.7) == 2
	and AnimRules.contactFor({ 0.8, 1.5, 2.2 }, 1.45) == 3 and AnimRules.contactFor({ 0.8, 1.5, 2.2 }, 0.2) == 1)
check("re-timing reaches the next contact or plays on", near(AnimRules.retime(1.5, 0.8, 0.7), 1) and near(AnimRules.retime(1.5, 0.8, 0.5), 1.4)
	and near(AnimRules.retime(1.5, 1.6, 0.5), 1) and near(AnimRules.retime(1.5, 0.8, 0), AnimRules.SyncSpeed.Max))
check("an unauthored Bull swing stands in with the stock strike", AnimRules.resolve("IronBull", 1, "IronBullMaul_L3", nil, "R15", none).Source == "Stock")
check("cosmetic tracks drive no gameplay (no marker/keyframe hooks)", not string.find(src("src/server/Services/BossAttackService.luau") .. src("src/simulation/CombatRules.luau")
	.. src("src/server/Services/AIService.luau") .. src("src/server/CharacterService.luau"), "MarkerReached", 1, true))

-- Server: the phase reaches the skin and the status; imported tracks bind per look.
local shared = { CostumeSchema = Schema, BossBodies = Bodies, BossAnimationRules = AnimRules, WaitForChild = function() return {} end }
local Appearance = Scene.load("src/server/Services/BossAppearance.luau", {
	game = { GetService = function(_, n)
		if n == "ServerStorage" then return storage end
		return { WaitForChild = function() return { Shared = shared } end }
	end },
	script = { Parent = { CharacterService = { GetEntityByModel = function() return nil end }, CostumeKit = { phase = function() end } } } })
template("AsuraBoss_GrandmasterShen_P1", full)
local shen = actor("GrandmasterShen", "GrandmasterShen", 1)
Appearance.phase(shen, "DisciplinedMaster", 1)
local p1 = Skin.resolve(library, shen)
Appearance.phase(shen, "DemonicChimera", 2) -- beginTransition: the set changes before applyPhase finishes
check("the phase-2 skin resolves when the set changes (was _P1 until the transition ended)", p1.Name == "AsuraBoss_GrandmasterShen_P1"
	and Skin.resolve(library, shen).Name == "AsuraBoss_GrandmasterShen_P2")
check("phase change rewrites the animation status", string.find(shen:GetAttribute("AsuraAnimationStatus"), "first missing GrandmasterShen_P2_Idle", 1, true) ~= nil)
local tracks = Instance.new("Folder"); tracks.Name = "AsuraBossAnimations"; tracks.Parent = library
local function anim(name, id) local a = Instance.new("Animation"); a.Name = name; a.AnimationId = id; a.Parent = tracks end
anim("SovereignWu_P2_Idle", "rbxassetid://777"); anim("SovereignWuX_Idle", "rbxassetid://778"); anim("SovereignWu_Bad", "nope"); anim("AzureWyrm_Idle", "rbxassetid://779")
local wuActor = actor("SovereignWu", "SovereignWu", 1)
Appearance.bindAnimations(wuActor, library)
check("imported tracks bind to their own look only", wuActor:GetAttribute("AsuraBossAnimation_SovereignWu_P2_Idle") == "rbxassetid://777"
	and wuActor:GetAttribute("AsuraBossAnimation_SovereignWuX_Idle") == nil and wuActor:GetAttribute("AsuraBossAnimation_SovereignWu_Bad") == nil
	and wuActor:GetAttribute("AsuraBossAnimation_AzureWyrm_Idle") == nil)
check("bosses bind imported tracks at spawn", string.find(src("src/server/Services/BossAppearance.luau"), "Appearance.bindAnimations(model, ServerStorage:FindFirstChild(\"AsuraAssets\"))", 1, true) ~= nil)

-- Client: the dispatcher requests per actor and attack, re-resolves on phase, yields creature joints.
local function fakeActor(look, rig, attributes)
	local a = { Name = look, attributes = attributes or {}, loads = {} }
	a.attributes.AsuraLookKey = look; a.attributes.AsuraRig = rig
	function a:GetAttribute(n) return self.attributes[n] end
	function a:SetAttribute(n, v) self.attributes[n] = v end
	local animator = { LoadAnimation = function(_, animation)
		local t = { Id = animation.AnimationId, IsPlaying = true, TimePosition = 0 }
		function t:Play(_, _, speed) self.Speed = speed end
		function t:AdjustSpeed(speed) self.Speed = speed end
		function t:Stop() self.IsPlaying = false end
		function t:Destroy() end
		table.insert(a.loads, t)
		return t
	end }
	local humanoid = { RigType = "R15", FindFirstChildOfClass = function() return animator end }
	function a:FindFirstChildOfClass(c) return if c == "Humanoid" then humanoid else nil end
	return a
end
local Dispatch = Scene.load("src/client/Controllers/BossAnimations.luau", {
	game = { GetService = function() return { AsurasPath = { Shared = { BossAnimationRules = AnimRules } } } end },
	Instance = { new = function() return { Destroy = function() end } end },
	Enum = { HumanoidRigType = { R6 = "R6" }, AnimationPriority = { Idle = 1, Action = 2, Action4 = 4 } } })
local zhaoA, bullA = fakeActor("GeneralZhao", "Humanoid"), fakeActor("IronBull", "Humanoid")
Dispatch.action(zhaoA, false, "LightningSpear", "PerilousThrust"); Dispatch.action(bullA, false, "ColossalHammer", "Shockwave")
check("each Twin requests its own attack slot", zhaoA.attributes.AsuraAnimationPlaying == "GeneralZhao_P1_LightningSpear|Stock"
	and bullA.attributes.AsuraAnimationPlaying == "IronBull_P1_ColossalHammer|Stock" and zhaoA.loads[1].Id ~= bullA.loads[1].Id)
local wuA = fakeActor("SovereignWu", "Humanoid", { AsuraBossPhase = 1, AsuraAnimationSet = "Ancient Oath", AsuraBossAnimation_SovereignWu_P2_Idle = "rbxassetid://777" })
Dispatch.sync(wuA); Dispatch.sync(wuA)
check("idle is requested once per phase", #wuA.loads == 1 and wuA.attributes.AsuraAnimationPlaying == "SovereignWu_P1_Idle|Stock")
wuA.attributes.AsuraBossPhase, wuA.attributes.AsuraAnimationSet = 2, "Unbound"
Dispatch.sync(wuA)
check("a phase change re-resolves and plays the phase override", #wuA.loads == 2 and wuA.loads[2].Id == "rbxassetid://777" and not wuA.loads[1].IsPlaying)
local wyrmA = fakeActor("AzureWyrm", "Creature")
Dispatch.action(wyrmA, false, "AzureTail", "Tail")
check("a creature without tracks loads nothing and keeps procedural motion", #wyrmA.loads == 0 and wyrmA.attributes.AsuraAuthoredMotion == nil
	and wyrmA.attributes.AsuraAnimationPlaying == "AzureWyrm_P1_AzureTail|Procedural")
wyrmA.attributes.AsuraBossAnimation_AzureWyrm_AzureTail = "rbxassetid://880"
Dispatch.action(wyrmA, false, "AzureTail", "Tail")
check("an authored creature track plays and claims the joints", #wyrmA.loads == 1 and wyrmA.attributes.AsuraAuthoredMotion == true)
check("CreatureMotion releases joints an authored track owns", string.find(src("src/client/Controllers/CreatureMotion.luau"), "AsuraAuthoredMotion\") == true", 1, true) ~= nil)
check("telegraphs pass the move, kind and impact to the dispatcher", string.find(src("src/client/Controllers/InterfaceController.luau"), "BossAnimations.action(sourceEntity.Model, cue.Kind == \"BossPhase\" or cue.Kind == \"BossEnrage\", data.move, data.kind, data.impact)", 1, true) ~= nil)
check("the boss frame hands each actor's server state to the dispatcher", string.find(src("src/client/Controllers/InterfaceController.luau"), "BossAnimations.sync(entity.Model, entity.Snapshot and entity.Snapshot.State)", 1, true) ~= nil)
check("Zhao's shared-Guandao light swings are cued for their clips", string.find(src("src/server/Services/AIService.luau"), "AnimationRules.Melee[e.Model:GetAttribute(\"AsuraLookKey\")]", 1, true) ~= nil)

-- The Lightning Spear plays once across its three pulses: phase-locked, re-timed, never restarted.
local clock = 100
Dispatch.now = function() return clock end
local spearA = fakeActor("GeneralZhao", "Humanoid", { AsuraBossAnimation_GeneralZhao_LightningSpear = "rbxassetid://70",
	AsuraBossAnimation_GeneralZhao_P1_Idle = "rbxassetid://71" })
Dispatch.sync(spearA)
Dispatch.action(spearA, false, "LightningSpear", "PerilousThrust", clock + 0.8)
local spear = spearA.loads[2]
check("the spear starts from its first frame at speed 1 for a 0.8 s windup", #spearA.loads == 2 and spear.Id == "rbxassetid://70" and near(spear.Speed, 1)
	and near(spear.TimePosition, 0))
local function advance(dt) clock += dt; spear.TimePosition += dt * spear.Speed; Dispatch.sync(spearA) end
advance(0.8)
check("speed returns to 1 once the first thrust lands", near(spear.Speed, 1) and near(spear.TimePosition, 0.8))
advance(0.1)
Dispatch.action(spearA, false, "LightningSpear", "PerilousThrust", 100 + 1.5 + 0.2) -- pulse 2, impact deferred 0.2 s
check("a repeat pulse re-times the running track instead of restarting it", #spearA.loads == 2 and spear.IsPlaying
	and near(spear.Speed, (1.5 - 0.9) / 0.8) and spearA.attributes.AsuraAnimationPlaying == "GeneralZhao_LightningSpear|Override")
advance(0.8)
check("the deferred second thrust lands on its server impact", near(spear.TimePosition, 1.5) and near(spear.Speed, 1))
spearA.attributes.AsuraBossAnimation_GeneralZhao_PostureBreak = "rbxassetid://72"
Dispatch.sync(spearA, "StanceBroken")
check("a posture break stops the spear and plays the authored reaction", not spear.IsPlaying and #spearA.loads == 3 and spearA.loads[3].Id == "rbxassetid://72")
Dispatch.sync(spearA, "StanceBroken")
check("a reaction plays once per state", #spearA.loads == 3)
local hollow = fakeActor("GeneralZhao", "Humanoid")
Dispatch.action(hollow, false, "Guandao_L1", "Light", clock + 0.4)
Dispatch.sync(hollow, "KO")
check("an unauthored reaction returns the actor to its idle", hollow.attributes.AsuraAnimationPlaying == "GeneralZhao_P1_Idle|Stock" and not hollow.loads[1].IsPlaying)

-- 12. The Twins flank instead of sharing one engage point (F10: 0.6 studs apart in Studio).
do
	local zx, zz = Bodies.closeIn(0, 20, 0, 0, 4)
	local bx, bz = Bodies.flank(0.5, 22, 0, 0, 4, zx, zz, 7.25)
	check("the second Twin swings round the target, clear of its partner", math.sqrt((bx - zx) ^ 2 + (bz - zz) ^ 2) >= 7.25 - 1e-6
		and math.abs(math.sqrt(bx * bx + bz * bz) - 4) < 1e-6)
	local fx, fz = Bodies.flank(0, -20, 0, 0, 4, zx, zz, 7.25)
	local cx, cz = Bodies.closeIn(0, -20, 0, 0, 4)
	check("a Twin already on another side keeps its own engage point", fx == cx and fz == cz)
	local ax, az = Bodies.flank(0, 0, 0, 0, 4, 0, 4, 7.25)
	check("flank resolves a coincident start", ax == ax and math.sqrt((ax) ^ 2 + (az - 4) ^ 2) >= 7.25 - 1e-6)
	check("AI chases flank the living partner", string.find(src("src/server/Services/AIService.luau"), "Bodies.flank(at.X, at.Z, to.X, to.Z, reach * 0.6", 1, true) ~= nil)
end

print(string.format("boss presentation: %d passed, %d failed", passed, failed))
if failed > 0 then error("boss presentation regression failed") end
