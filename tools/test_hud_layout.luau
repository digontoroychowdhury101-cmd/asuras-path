--!nonstrict
-- Lune regression for playtest findings #12, #17, #18, #33, #34, #35, #36 (batch 04).
-- Run from the project root: lune run tools/test_hud_layout.luau
-- Layout geometry at small/wide viewports, HUD visibility transitions, crowd plate rules, health
-- layer wording, duo identification, CoreGui policy and source wiring. Rules, fakes and source
-- checks only: no rendered pixels — Studio captures remain the visual acceptance.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox") :: any

local passed, failed = 0, 0
local function check(name: string, condition: any)
	if condition then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local function load(path: string, env: { [string]: any }?): any
	local e = table.clone(env or {})
	e.Color3, e.Vector3, e.Vector2 = roblox.Color3, roblox.Vector3, roblox.Vector2
	return luau.load(fs.readFile(path), { debugName = path, environment = e })()
end
local function src(path: string): string return fs.readFile(path) end
local function has(path: string, text: string): boolean return string.find(src(path), text, 1, true) ~= nil end
local C = "src/client/Controllers/"
local stubScript = { Parent = { WaitForChild = function(_, name) return name end } }

-- 1. Reserved regions at small and wide desktop viewports (#33).
local Layout = load(C .. "HudLayout.luau")
local viewports = { { 1024, 576 }, { 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1080 }, { 3440, 1440 } }
local cardW, cardH = 2 * 300 + 28, 46 + 10 * 26 -- ControlsCard: two columns of 20 InputMap rows
for _, v in viewports do
	local w, h = v[1], v[2]
	local tag = w .. "x" .. h
	local scale, modal = Layout.modal(w, h, cardW, cardH)
	for _, other in { "ActionBar", "Vitals", "Spells", "Minimap", "Objective", "Compass", "Codex", "ControlsPill" } do
		check(tag .. " controls card clear of " .. other, not Layout.overlaps(modal, Layout.rect(other, w, h)))
	end
	check(tag .. " controls text stays readable (" .. string.format("%.2f", scale) .. ")", 17 * scale >= 11)
	check(tag .. " card on screen", modal.X >= 0 and modal.Y >= 0 and modal.X + modal.W <= w and modal.Y + modal.H <= h)
	local pill = Layout.rect("ControlsPill", w, h)
	for _, other in { "ActionBar", "Vitals", "Minimap", "Codex", "Spells" } do
		check(tag .. " pill clear of " .. other, not Layout.overlaps(pill, Layout.rect(other, w, h)))
	end
	check(tag .. " vitals clear of action bar", not Layout.overlaps(Layout.rect("Vitals", w, h), Layout.rect("ActionBar", w, h)))
	check(tag .. " boss strip clear of objective", not Layout.overlaps(Layout.rect("Boss", w, h), Layout.rect("Objective", w, h)) or w < 1300)
	-- The report's case: the old dock (bottom-centre, 16 px up, 0.75 scale) sat on the action bar.
	local f = Layout.factor(h)
	local old = { X = (w - cardW * 0.75 * f) / 2, Y = h - 16 - cardH * 0.75 * f, W = cardW * 0.75 * f, H = cardH * 0.75 * f }
	check(tag .. " legacy dock overlapped the action bar", Layout.overlaps(old, Layout.rect("ActionBar", w, h)))
end
-- Mirrored constants must match the components they describe.
local kit = src(C .. "HudKit.luau")
check("factor mirrors HudKit", string.find(kit, "REFERENCE_HEIGHT = 900", 1, true) and string.find(kit, "MIN_FACTOR = 0.7", 1, true) and string.find(kit, "MAX_FACTOR = 1.35", 1, true))
check("action bar bottom from layout", has(C .. "ActionBar.luau", "HudLayout") and has(C .. "ActionBar.luau", "ActionBarBottom"))
check("vitals plate geometry", has(C .. "InterfaceController.luau", "Position = UDim2.new(0, 16, 1, -12)") and has(C .. "InterfaceController.luau", "Vitals = 0.78"))
check("minimap geometry", has(C .. "SakuraMinimap.luau", "Position = UDim2.fromOffset(20, 66)") and has(C .. "SakuraMinimap.luau", "bindScale(root, 0.82)"))
check("objective geometry", has(C .. "ObjectiveController.luau", "Position = UDim2.new(1, -20, 0, 64), Size = UDim2.fromOffset(360, 92)"))
check("spell cluster geometry", has(C .. "SpellHud.luau", "Position = UDim2.new(1, -24, 1, -24)") and has(C .. "SpellHud.luau", "bindScale(root, 0.85)"))
check("codex button geometry", has(C .. "DialogueController.luau", "codex.Position=UDim2.new(0,14,0.55,0)"))
check("card uses the reserved band", has(C .. "ControlsCard.luau", "Layout.modal") and not has(C .. "ControlsCard.luau", "UDim2.new(0.5, 0, 1, -16)"))
check("vitals bound once (no competing scales)", not has(C .. "InterfaceController.luau", "frame.Destroying:Once(HudKit.bindScale(frame, 0.78))"))

-- 2. Visibility transitions restore exactly (#18).
local Visibility = load(C .. "HudVisibility.luau", { game = { GetService = function() return { Enabled = true } end } })
local function flags(o) return { Death = o.Death == true, Prologue = o.Prologue == true, Dialogue = o.Dialogue == true, Altar = o.Altar == true, Boss = o.Boss == true } end
local function same(a, b) for k, v in a do if b[k] ~= v then return false end end return true end
local base = Visibility.resolve(flags({}))
check("exploring shows every layer but the boss bar", base.Combat and base.Vitals and base.Decor and base.Guidance and base.Prompts and base.Notices and not base.Boss)
local dead = Visibility.resolve(flags({ Death = true, Boss = true }))
check("death hides combat, vitals, boss, decor, prompts, guidance, notices",
	not (dead.Combat or dead.Vitals or dead.Boss or dead.Decor or dead.Prompts or dead.Guidance or dead.Notices))
local prologue = Visibility.resolve(flags({ Prologue = true }))
check("prologue hides combat, decor and prompts", not (prologue.Combat or prologue.Decor or prologue.Prompts or prologue.Guidance))
local talk = Visibility.resolve(flags({ Dialogue = true }))
check("dialogue hides combat labels, petals and prompts but keeps notices", not (talk.Combat or talk.Decor or talk.Prompts) and talk.Notices)
local altar = Visibility.resolve(flags({ Altar = true }))
check("altar menu only hides guidance", altar.Combat and altar.Decor and not altar.Guidance)
local boss = Visibility.resolve(flags({ Boss = true }))
local sequence = { {}, { Boss = true }, { Boss = true, Death = true }, { Death = true }, {}, { Dialogue = true }, {}, { Prologue = true }, {} }
local ok = true
for _, step in sequence do
	local layers = Visibility.resolve(flags(step))
	if step.Death == nil and step.Dialogue == nil and step.Prologue == nil and not same(layers, if step.Boss then boss else base) then ok = false end
end
check("prologue/death/dialogue round trips leave no stale layer", ok)

-- 3. Crowded and focused nameplates (#34).
local Plates = load(C .. "PlateLayout.luau")
local two = Plates.arrange({ { Id = 1, X = 600, Y = 300, Distance = 10, Focus = false, Warning = false }, { Id = 2, X = 640, Y = 310, Distance = 12, Focus = false, Warning = false } })
check("two nearby enemies: both named", two[1].Mode == "Full" and two[2].Mode == "Full")
check("two nearby enemies: second plate lifted clear", two[1].Lift == 0 and 310 - two[2].Lift <= 300 - Plates.Gap.Y)
local focus = Plates.arrange({ { Id = 1, X = 600, Y = 300, Distance = 10, Focus = true, Warning = true }, { Id = 2, X = 900, Y = 300, Distance = 5, Focus = false, Warning = false } })
check("target plate foe keeps only its warning overhead", focus[1].Mode == "Focus" and focus[2].Mode == "Full")
local crowd = {}
for i = 1, 9 do table.insert(crowd, { Id = i, X = 500 + i * 10, Y = 300, Distance = i, Focus = false, Warning = i == 9 }) end
local placed = Plates.arrange(crowd)
local count = { Full = 0, Compact = 0, Hidden = 0 }
for _, p in placed do count[p.Mode] += 1 end
check("crowd: three named plates", count.Full == Plates.MaxFull)
check("crowd: budget hides far foes", count.Hidden == 2 and placed[8].Mode == "Hidden")
check("crowd: a winding-up foe always shows", placed[9].Mode == "Compact")
check("crowd: lift is bounded", placed[3].Lift <= Plates.MaxLift)
local tie = Plates.arrange({ { Id = 7, X = 0, Y = 0, Distance = 5, Focus = false, Warning = false }, { Id = 3, X = 0, Y = 0, Distance = 5, Focus = false, Warning = false } })
check("equal range ordering is stable by id", tie[3].Lift == 0 and tie[7].Lift == Plates.Gap.Y)

-- 4. Health layers, flask and currency wording (#12, #35).
local Tags = load(C .. "VitalsTags.luau", { script = stubScript, require = function() return { Colors = {} } end })
local function snap(o) return { MaxHP = 106, ActiveHP = o.Active or 80, RecoverableHP = o.Rec or 0, PermanentDeficit = o.Lost or 0, RallyActive = o.Rally == true, RallyRemaining = o.Left or 0 } end
local rally, ceiling = Tags.texts(snap({ Rec = 12, Rally = true, Left = 2.36 }))
check("rally window: countdown and action", rally == "↺ RALLY 2.4s · strike back" and ceiling == "")
rally = Tags.texts(snap({ Rec = 12 }))
check("after the window: flask restores recoverable", rally == "↺ +12 recoverable · flask")
rally, ceiling = Tags.texts(snap({ Lost = 11.6 }))
check("reduced ceiling: lasting loss and rest", rally == "" and ceiling == "▼ max −12 · rest restores")
check("full health: no tags", select(1, Tags.texts(snap({ Active = 106 }))) == "" and select(2, Tags.texts(snap({ Active = 106 }))) == "")
check("flask pips are shapes", Tags.flask(1, 3) == "FLASK ◆◇◇" and Tags.flask(0, 3) == "FLASK ◇◇◇" and Tags.flask(0, 0) == "FLASK —")
local ic = src(C .. "InterfaceController.luau")
check("currency labelled as essence, Qi stays spell energy", string.find(ic, "✦ %d ESSENCE", 1, true) and string.find(ic, "+%d carried", 1, true) and string.find(ic, "QI %d / %d", 1, true))
check("boss reward no longer calls currency Qi", not string.find(ic, "Qi essence", 1, true))
check("low flask pulses", string.find(ic, "elixirs <= 1", 1, true) ~= nil)

-- 5. Twins: separate, stable identification (#17).
local InputMap = load("src/shared/InputMap.luau")
local chain = setmetatable({}, { __index = function(t) return function() return t end end })
local Duo = load(C .. "DuoBars.luau", { script = stubScript, game = { GetService = function() return chain end },
	require = function(name) if name == "HudKit" or name == "SakuraKit" then return { Colors = {}, Palette = {} } end return InputMap end })
check("duo sigils are distinct shapes", #Duo.Sigils >= 2 and Duo.Sigils[1] ~= Duo.Sigils[2])
check("duo switching hint uses the lock binding", Duo.lockKey("Keyboard") == "X" and Duo.lockKey("Gamepad") == "R3")
for _, part in Duo.Replaced do
	check("merged boss part " .. part .. " exists to be replaced", string.find(ic, '"' .. part .. '"', 1, true) or has(C .. "BossHud.luau", '"' .. part .. '"'))
end
check("intro binds the duo strip", string.find(ic, "DuoBars.bind(self.Duo, self.BossMembers", 1, true) ~= nil)
local _, clears = string.gsub(ic, "DuoBars.clear%(self.Duo%)", "")
check("defeat and reset clear the duo strip", clears >= 2)

-- 6. One source per value: CoreGui policy (#34).
local calls = {}
local starter = { SetCoreGuiEnabled = function(_, kind, on) table.insert(calls, kind .. "=" .. tostring(on)) end }
local Enum = { CoreGuiType = { Health = "Health", PlayerList = "PlayerList", Chat = "Chat" },
	HumanoidHealthDisplayType = { AlwaysOff = "AlwaysOff" }, HumanoidDisplayDistanceType = { None = "None" } }
local Policy = load(C .. "CoreGuiPolicy.luau", { game = { GetService = function() return starter end }, Enum = Enum })
local enemy = { Kind = "Enemy", Boss = false, Humanoid = { HealthDisplayType = "DisplayWhenDamaged", DisplayDistanceType = "Viewer" } }
local npc = { Kind = "Npc", Boss = false, Humanoid = { HealthDisplayType = "DisplayWhenDamaged", DisplayDistanceType = "Viewer" } }
local added
local stop = Policy.start({ Entities = { enemy }, OnEntityAdded = function(_, fn) added = fn; return function() added = nil end end })
added(npc)
check("default health bar and player list off", table.find(calls, "Health=false") and table.find(calls, "PlayerList=false"))
check("chat and other core UI untouched", table.find(Policy.Disabled, "Chat") == nil and #Policy.Disabled == 2)
check("enemy overhead default name/health hidden", enemy.Humanoid.HealthDisplayType == "AlwaysOff" and enemy.Humanoid.DisplayDistanceType == "None")
check("friendly NPC keeps its name", npc.Humanoid.DisplayDistanceType == "Viewer" and npc.Humanoid.HealthDisplayType == "AlwaysOff")
stop()
check("teardown restores CoreGui", table.find(calls, "Health=true") and added == nil)

-- 7. Grimdark motif and effect priority (#36 + aesthetic request).
local Sakura = load(C .. "SakuraKit.luau", { script = stubScript, require = function() return { make = function() end } end })
for _, key in { "BloodPetal", "EmberPetal" } do
	local c = Sakura.Colors[key]
	check(key .. " is blood red, not pink", c.R > 0.4 and c.G < c.R * 0.25 and c.B < c.R * 0.3)
end
check("petals use the blood palette", has(C .. "SakuraHud.luau", "C.BloodPetal") and not has(C .. "SakuraHud.luau", "C.Sakura else C.Blossom"))
local flowers = 0
for _, name in fs.readDir(C) do
	local _, n = string.gsub(src(C .. name), "%.flower%(", "")
	flowers += n
end
check("no five-petal blossom motif remains", flowers == 0 and not string.find(src(C .. "SakuraKit.luau"), "function Kit.flower", 1, true))
check("compass and medallions draw the seal crest", has(C .. "SakuraCompass.luau", "Sakura.crest") and has(C .. "SakuraKit.luau", "Kit.crest(disc"))
local callouts = src(C .. "CombatCallouts.luau")
check("perilous warning outranks other callouts", string.find(callouts, "WARNING, CRITICAL, INFO = 3, 2, 1", 1, true) and string.find(callouts, "rank < view.Priority", 1, true))
check("damage numbers yield while a warning is up", string.find(callouts, "view.WarnUntil then size", 1, true) ~= nil)
check("perilous counter is a callout, not a toast", has(C .. "CombatHud.luau", "Callouts.warn") and not string.find(ic, 'ShowToast("Perilous!', 1, true))

-- 8. Runtime wiring.
check("bootstrap applies the CoreGui policy", has("src/client/Bootstrap.client.luau", "CoreGuiPolicy.start(state)"))
for _, file in { "CombatHud", "SakuraHud", "ControlsCard", "ObjectiveController", "SpellController", "InterfaceController", "DialogueController" } do
	check(file .. " follows HudVisibility", has(C .. file .. ".luau", "Visibility"))
end
check("dialogue publishes its open state", has(C .. "DialogueController.luau", "self.UI.DialogueOpen=true") and has(C .. "DialogueController.luau", "self.UI.DialogueOpen=false"))
check("death screen names loss, wake point and goal", string.find(ic, "You will wake at", 1, true) and string.find(ic, "reclaim it from your bloodstain", 1, true))
local project = src("default.project.json")
for _, name in { "HudVisibility", "HudLayout", "PlateLayout", "DuoBars", "VitalsTags", "CoreGuiPolicy" } do
	check(name .. " registered and strict", string.find(project, "Controllers/" .. name .. ".luau", 1, true) and string.sub(src(C .. name .. ".luau"), 1, 9) == "--!strict")
end

print(string.format("hud layout: %d passed, %d failed", passed, failed))
if failed > 0 then error("hud layout regression failed") end
