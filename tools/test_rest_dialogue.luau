--!nonstrict
-- Lune regression for playtest findings #4 (camera part), #38, #39, #40 (batch 05).
-- Run from the project root: lune run tools/test_rest_dialogue.luau
-- Rest/summon separation, level previews derived from the real stat formulas, portrait framing
-- with injected collision probes, packet validation and source wiring. Rules, fakes and source
-- checks only: Studio play at the three altars remains the visual/feel acceptance.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox") :: any
local Store = require("../src/server/ProfileStore")
local Progress = require("../src/shared/ProgressionRules")
local Preview = require("../src/shared/LevelPreview")
local DialogueRules = require("../src/shared/DialogueRules")

local passed, failed = 0, 0
local function check(name: string, condition: any)
	if condition then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local function src(path: string): string return fs.readFile(path) end
local function has(path: string, text: string): boolean return string.find(src(path), text, 1, true) ~= nil end
local C = "src/client/Controllers/"
local S = "src/server/Services/"

-- 1. Level previews come from the same formulas the server applies (#40).
local function souls(attributes, tier)
	return { attributes = attributes, inventory = { mainhand = "Jian", reinforcement = { Jian = tier } }, rpg = nil }
end
local KEYS = { "MaxHP", "MaxStamina", "PostureCapacity", "MaxQi", "RallyScale", "SpellScale", "StrengthScale", "DexterityScale" }
local base = { Vigor = 10, Endurance = 10, Strength = 10, Dexterity = 10, ArcaneQi = 10 }
for _, sample in { { base, 0 }, { { Vigor = 39, Endurance = 45, Strength = 12, Dexterity = 60, ArcaneQi = 41 }, 3 } } do
	local derived, real = Preview.derived(sample[1], sample[2]), Store.DeriveStats(souls(sample[1], sample[2]))
	local same = true
	for _, key in KEYS do if math.abs(derived[key] - real[key]) > 1e-9 then same = false end end
	check("preview equals ProfileStore.DeriveStats (tier " .. sample[2] .. ")", same)
end
for _, id in Progress.Attributes do
	local after = table.clone(base); after[id] += 1
	local real = Store.DeriveStats(souls(after, 0))
	local benefits = Preview.benefits(base, id, 0)
	check(id .. " lists at least one concrete result", #benefits >= 1)
	for _, b in benefits do check(id .. " " .. b.Label .. " grows", b.After > b.Before) end
	local matched = true
	for _, b in benefits do
		local found = false
		for _, key in KEYS do if math.abs(real[key] - b.After) < 1e-9 then found = true end end
		matched = matched and found
	end
	check(id .. " after-values are the server's derived stats", matched)
end
check("Vigor preview reads health", Preview.line(base, "Vigor", 0) == "Max HP 100 → 106  ·  Rally recovery 100.0% → 101.5%")
check("Arcane Qi preview reads Qi pool and spells", Preview.line(base, "ArcaneQi", 0) == "Max Qi 100 → 103  ·  Spell damage 100.0% → 102.5%")
check("readable label Arcane Qi", Preview.Labels.ArcaneQi == "Arcane Qi")
local peak = table.clone(base); peak.Strength = 99
check("an attribute at 99 says so", Preview.line(peak, "Strength", 0) == "At its peak")
local ok, quote = Preview.quote(500, 395)
check("affordable quote names cost and remaining Essence", ok and quote == "Cost 395 Essence  ·  105 left after")
ok, quote = Preview.quote(105, 395)
check("short quote names the gap in Essence", not ok and quote == "Need 290 more Essence  (105 / 395)")
check("preview cost table is the server's", Store.LevelCost(2) == Progress.levelCost(2))

-- 2. Portrait framing with collision probes (#4 camera, #39).
local probeCalls = 0
local env = { Vector3 = roblox.Vector3, CFrame = roblox.CFrame, table = table, math = math, ipairs = ipairs,
	game = { GetService = function() return { Raycast = function() return nil end } end } }
local Portrait = luau.load(src(C .. "PortraitCamera.luau"), { debugName = "PortraitCamera", environment = env })()
local V = roblox.Vector3.new
local subject, viewer = V(0, 5, 0), V(0, 3, 10)
local candidates = Portrait.candidates(subject, viewer)
local right, left = candidates[1], candidates[2]
check("both shoulder views are offered first and mirror each other", math.abs(right.X + left.X) < 1e-6 and math.abs(right.Z - left.Z) < 1e-6 and right.X ~= 0)
check("shoulder shots sit on the player's side", right.Z > subject.Z and left.Z > subject.Z)
local clear = function() probeCalls += 1; return nil end
local pos, clean = Portrait.choose(subject, viewer, clear)
check("open ground takes the first shoulder", clean and pos == right)
-- A stone pillar on the first shoulder's side blocks it: the opposite shoulder wins.
local pillar = function(from, to) if to.X * right.X > 0.25 then return from:Lerp(to, 0.4) end return nil end
pos, clean = Portrait.choose(subject, viewer, pillar)
check("blocked right shoulder falls back to the left", clean and pos == left)
-- The bonfire sits between the speaker's chest and the player's side: only the chest line is hit.
local fire = function(from, to) if from.Y < subject.Y - 0.5 and to.Z > 2 then return from:Lerp(to, 0.5) end return nil end
pos, clean = Portrait.choose(subject, viewer, fire)
check("fire blocking the chest line is not accepted as clear", not clean or pos.Z <= 2)
-- A wall closes every angle 5 studs out: the shot is pulled in front of it, never through it.
local wall = function(from, to)
	if (to - subject).Magnitude > 5 then return from + (to - from).Unit * 5 end
	return nil
end
pos, clean = Portrait.choose(subject, viewer, wall)
check("enclosed altar pulls the camera in front of the stone", not clean and (pos - subject).Magnitude <= 5 - Portrait.Margin + 1e-6 and (pos - subject).Magnitude >= Portrait.MinReach)
-- F04: a head at the screen centre sat behind the dialogue panel (top at 40% on a 1221x503 view).
local function screenY(cf, point)
	local p = cf:PointToObjectSpace(point)
	return (1 - (p.Y / -p.Z) / math.tan(math.rad(Portrait.Fov) / 2)) / 2, p.Z
end
local face = subject + V(0, 0.6, 0)
local aimed = Portrait.aim(right, face, 0.3)
local y, depth = screenY(aimed, face)
check("the face is framed in the band above the dialogue panel", math.abs(y - 0.3) < 0.01 and depth < 0)
check("the panel-free centre framing is still available", math.abs(screenY(Portrait.aim(right, face, 0.5), face) - 0.5) < 1e-6)
local tight = function(from, to) return from + (to - from).Unit * 1 end
pos, clean = Portrait.choose(subject, viewer, tight)
check("no viable angle falls back to a raised shot", not clean and pos.Y > subject.Y + 4)
local altar = V(0, 0, 0)
local firstBlocked = function(from, to)
	if to.Y < from.Y - 1 then return V(to.X, 0.5, to.Z) end -- ground below
	if to.X * right.X > 0.25 then return from:Lerp(to, 0.5) end -- stone on the preferred side
	return nil
end
local spot = Portrait.spiritSpot(altar, viewer, firstBlocked)
check("spirit avoids the blocked side and stands on the ground", spot.X * right.X < 0 and math.abs(spot.Y - 2.5) < 1e-6 and spot.Z > 0)

-- 3. Rest and summon are separate choices (#38).
check("resting no longer opens Lin", not has(S .. "WorldService.luau", "OnAltarRest") and not has(S .. "DialogueService.luau", "OnAltarRest"))
check("rest still sets the checkpoint and refills before the menu", has(S .. "WorldService.luau", "s.Elixirs = s.MaxElixirs") and has(S .. "WorldService.luau", "Characters.SetRespawnPoint(s.UserId, toCFrame(altar.Spawn))"))
local ic = src(C .. "InterfaceController.luau")
check("altar menu offers Ascension, Summon, Travel, Leave", string.find(ic, '"Ascension"', 1, true) and string.find(ic, '"Summon Lady Lin"', 1, true)
	and string.find(ic, 'button(main, "Travel"', 1, true) and string.find(ic, 'button(main, "Leave"', 1, true))
check("redundant Rest button removed", not string.find(ic, 'button(main, "Rest"', 1, true))
check("summon packet shape accepted", DialogueRules.valid({ action = "Summon", id = "Altar_MonasteryGate" }))
check("summon packet rejects extra fields", not DialogueRules.valid({ action = "Summon", id = "Altar_MonasteryGate", revision = 1 }))
check("summon validated against kindled altars", has(S .. "DialogueService.luau", "kindled") and has(S .. "DialogueService.luau", 'Service.Open(player,"Lin",p.id)'))
check("projection stays intentional; Lin in person beside her bonfire", has(S .. "DialogueService.luau", "PRESENT") and has(S .. "DialogueService.luau", "projection=true"))
check("farewell returns to the altar", has(S .. "DialogueService.luau", 'reason="Farewell"') and has(C .. "DialogueController.luau", "self.UI:OpenAltar(altar)"))

-- 4. Consistent modal, hidden prompts, restoration (#39).
local Visibility = luau.load(src(C .. "HudVisibility.luau"), { debugName = "HudVisibility", environment = { game = { GetService = function() return {} end }, setmetatable = setmetatable, table = table } })()
local altarLayers = Visibility.resolve({ Death = false, Prologue = false, Dialogue = false, Altar = true, Boss = false })
check("altar menu hides world prompts and objectives", not altarLayers.Prompts and not altarLayers.Guidance)
local talking = Visibility.resolve({ Death = false, Prologue = false, Dialogue = true, Altar = false, Boss = false })
check("dialogue hides prompts, objective and combat HUD", not talking.Prompts and not talking.Guidance and not talking.Combat)
local view = src(C .. "DialogueView.luau")
check("dialogue buttons use the Arsenal's UiKit", string.find(view, "UiKit.button(v.List", 1, true) and string.find(view, "UiKit.Theme", 1, true))
check("dialogue currency says Essence", not string.find(view, '" Qi"', 1, true) and not string.find(view, '" Qi · "', 1, true) and string.find(view, "Essence", 1, true))
check("purchases lock until the server answers", string.find(view, "v.Locked=true", 1, true) ~= nil)
local dc = src(C .. "DialogueController.luau")
check("death and respawn close the conversation", string.find(dc, "humanoid.Died", 1, true) and string.find(dc, "CharacterAdded", 1, true))
check("camera frame uses collision-aware portrait", string.find(dc, "Portrait.choose", 1, true) and string.find(dc, "Portrait.spiritSpot", 1, true))
check("ascension list scrolls inside a bounded region", has(C .. "AltarAscension.luau", '"ScrollingFrame"') and has(C .. "AltarAscension.luau", "ClipsDescendants = true"))

-- 5. Module hygiene.
local project = src("default.project.json")
for _, path in { C .. "PortraitCamera.luau", C .. "AltarAscension.luau", "src/shared/LevelPreview.luau", C .. "DialogueController.luau", C .. "DialogueView.luau", S .. "DialogueService.luau" } do
	local text = src(path)
	local _, lines = string.gsub(text, "\n", "")
	check(path .. " strict and under 150 lines", string.sub(text, 1, 9) == "--!strict" and lines < 150)
end
for _, name in { "Controllers/PortraitCamera.luau", "Controllers/AltarAscension.luau", "shared/LevelPreview.luau" } do
	check(name .. " registered", string.find(project, name, 1, true) ~= nil)
end

print(string.format("rest dialogue: %d passed, %d failed", passed, failed))
if failed > 0 then error("rest dialogue regression failed") end
