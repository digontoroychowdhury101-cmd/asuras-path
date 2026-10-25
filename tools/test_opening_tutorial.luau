--!nonstrict
-- Lune regression for playtest findings #11, #12, #13, #15, #19, #43 and #44 (batch 10). The real
-- TutorialService runs against fake players, combat events and the real ProfileStore schema: a
-- fresh profile trains step by step, only genuine successes advance (button presses, whiffs and
-- out-of-order successes do not), client reports are limited to lock-on and glide, skip and replay
-- persist, veterans start complete, and the sparring ring is non-lethal. World data, the opening
-- veil and the Codex introduction are checked as data and source. Studio play is not covered.
-- Run from the project root: lune run tools/test_opening_tutorial.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Rules = require("../src/shared/TutorialRules")
local InputMap = require("../src/shared/InputMap")
local World = require("../src/shared/WorldDefinitions")
local Narrative = require("../src/shared/NarrativeCatalog")
local Store = require("../src/server/ProfileStore")
local Profiles = require("../src/shared/ProfileSchema")
local Protocol = require("../src/infrastructure/IntentProtocol")
local Scene = require("./monastery_scene")
local V3 = roblox.Vector3

local passed, failed = 0, 0
local function check(name: string, condition: any)
	if condition then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local function src(path: string): string return fs.readFile(path) end

-- 1. The curriculum (#11, #12, #13).
local ids = {}
for _, step in Rules.Steps do table.insert(ids, step.Id) end
check("teaches every required skill in order", table.concat(ids, ",") == "LockOn,Light,Guard,Deflect,Dodge,Rally,Heal,Perilous,Deathblow,Glide")
for _, step in Rules.Steps do
	local text = Rules.text(step.Do, function(c) return InputMap.label(c, "Keyboard") end)
	check(step.Id .. " names real keys", not string.find(text, "{", 1, true) and not string.find(text, "[?]", 1, true))
end
check("perilous step names the concrete inputs", Rules.text(Rules.Steps[8].Do, function(c) return InputMap.label(c, "Keyboard") end) == "When ▲ PERILOUS flashes, deflect with [F] or dodge with [Shift/Q].")
check("air glide taught before bosses ask for it", string.find(Rules.Steps[10].Why, "Counter: Air Glide", 1, true) ~= nil)
check("health ceiling and rally explained", string.find(Rules.Steps[6].Why, "ceiling", 1, true) and string.find(Rules.Steps[6].Why, "rest", 1, true))
check("stakes explain carried, reclaimed and lost Essence", string.find(Rules.Stakes, "bloodstain", 1, true) and string.find(Rules.Stakes, "lost", 1, true) and string.find(Rules.Stakes, "Spend Essence", 1, true))
local done = {}
check("only the current step advances", Rules.advance(done, "Light") == nil and Rules.advance(done, "LockOn") == "LockOn")
local M1, DASH = { State = "Active", Move = "Light" }, { State = "Dashing" }
check("signals: own hit = Light, blocked strike = Guard", Rules.signal("Hit", 1, 9, 1, false, M1) == "Light" and Rules.signal("Block", 9, 1, 1, false) == "Guard")
check("signals: a spell, art, heavy or burn tick is not a light attack (F08)", Rules.signal("Hit", 1, 9, 1, false, { State = "Casting" }) == nil
	and Rules.signal("Hit", 1, 9, 1, false, { State = "Active", Move = "Heavy" }) == nil and Rules.signal("Hit", 1, 9, 1, false) == nil
	and Rules.signal("Hit", 1, 9, 1, false, { State = "Active", Move = "RunningAttack" }) == "Light")
check("signals: being hit or a foe blocking teaches nothing", Rules.signal("Hit", 9, 1, 1, false, M1) == nil and Rules.signal("Block", 1, 9, 1, false) == nil)
check("signals: deflect/evade, perilous when the strike was perilous", Rules.signal("DeflectSpark", 1, 9, 1, false) == "Deflect" and Rules.signal("Evade", 1, 9, 1, false, DASH) == "Dodge"
	and Rules.signal("DeflectSpark", 1, 9, 1, true) == "Perilous" and Rules.signal("Evade", 1, 9, 1, true, DASH) == "Perilous")
check("signals: an evade outside a dash (deathblow or rest invulnerability) teaches nothing", Rules.signal("Evade", 1, 9, 1, false, { State = "DeathblowVictim" }) == nil and Rules.signal("Evade", 1, 9, 1, true) == nil)
check("signals: whiffs and feints are not successes", Rules.signal("Whiff", 1, 9, 1, false) == nil and Rules.signal("Feint", 1, 1, 1, false) == nil)
check("client may only report lock-on and glide", Rules.ClientSignals.LockOn and Rules.ClientSignals.Glide and not Rules.ClientSignals.Light and not Rules.ClientSignals.Deathblow)
check("progress round-trips", Rules.serialize(Rules.parse("LockOn,Light,Bogus")) == "LockOn,Light" and Rules.serialize({ Skipped = true }) == "Skipped" and Rules.current(Rules.parse("Complete")) == nil)

-- 2. The service, driven like the server would drive it.
local cues, spawned, attrs, listener, handler, loop = {}, 0, {}, nil, nil, nil
local profile = { souls = Store.DefaultSouls(nil) }
local function transact(_, fn)
	local copy = Store.Copy(profile)
	fn(copy)
	local ok, why = Store.ValidateSouls(copy.souls)
	if ok then profile = copy end
	return ok, why
end
local player = { UserId = 7, SetAttribute = function(_, k, v) attrs[k] = v end, GetAttribute = function(_, k) return attrs[k] end }
local fighter = { KOProtected = false }
local entities = { [7] = { Root = { Position = V3.new(12, 3, -708) }, Fighter = fighter, Model = { GetAttribute = function() return nil end } } }
local phantom = { Root = { Position = V3.new(15, 3, -705) }, Fighter = {}, Model = { Tag = nil, GetAttribute = function(self) return self.Tag end } }
entities[-50] = phantom
local now = 100
local fakeTask = { wait = function() error("yield") end, spawn = function(f, ...) if not loop then loop = f else f(...) end end }
local env = {
	game = { GetService = function(_, name)
		if name == "Players" then return { GetPlayers = function() return { player } end, PlayerRemoving = { Connect = function() return { Disconnect = function() end } end } } end
		return { WaitForChild = function() return { Shared = { TutorialRules = Rules, IntentProtocol = Protocol, WorldDefinitions = World },
			Net = { WaitForChild = function() return { OnServerEvent = { Connect = function(_, f) handler = f; return { Disconnect = function() end } end } } end } } end }
	end },
	script = { Parent = {
		CharacterService = { Subscribe = function(f) listener = f; return function() end end, GetEntity = function(id) return entities[id] end, Now = function() return now end,
			Cue = function(kind, id, data) table.insert(cues, { Kind = kind, Id = id, Data = data }) end },
		AIService = { SpawnMob = function() spawned += 1 end },
		PersistenceService = { Get = function() return profile end, Transaction = transact },
	} },
	require = function(m) return m end, task = fakeTask, os = os, math = math, table = table, string = string, type = type, tostring = tostring,
	tonumber = tonumber, next = next, pcall = pcall, warn = function() end, assert = assert, Vector3 = V3, setmetatable = setmetatable,
}
local Service = luau.load(src("src/server/Services/TutorialService.luau"), { debugName = "TutorialService", environment = env })()
Service.Start()
local function poll() pcall(loop) end
local function event(kind, source, target) listener({ Kind = kind, Source = source, Target = target, Value = 0 }, nil) end
poll()
check("fresh profile starts training at step 1", attrs.AsuraTutorial == "" and Rules.current(Rules.parse(attrs.AsuraTutorial)).Id == "LockOn")
check("sparring ring is non-lethal while training", fighter.KOProtected == true)
check("phantom kept available near the landing", spawned >= 1)
event("Hit", 7, -50)
check("a hit before locking on does not skip ahead", attrs.AsuraTutorial == "")
handler(player, { action = "Signal", signal = "Light" })
check("client cannot claim a combat step", attrs.AsuraTutorial == "")
handler(player, { action = "Signal", signal = "LockOn" })
check("lock-on report advances its own step", attrs.AsuraTutorial == "LockOn")
event("Whiff", 7, -50); event("Feint", 7, 7)
check("whiff and feint do not count as a light attack", attrs.AsuraTutorial == "LockOn")
fighter.State = "Casting"; event("Hit", 7, -50)
check("a palm spell landing is not the light attack", attrs.AsuraTutorial == "LockOn")
fighter.State, fighter.Move = "Active", { Kind = "Light" }; event("Hit", 7, -50); fighter.State, fighter.Move = "Idle", nil
check("a landed hit advances Light", attrs.AsuraTutorial == "LockOn,Light" and profile.souls.world.tutorial.Light == true)
event("Block", -50, 7); event("DeflectSpark", 7, -50)
fighter.State = "DeathblowVictim"; event("Evade", 7, -50)
check("struck while helpless after a deathblow is not a dodge (F08 Studio log)", attrs.AsuraTutorial == "LockOn,Light,Guard,Deflect")
fighter.State = "Dashing"; event("Evade", 7, -50); fighter.State = "Idle"; event("Rally", 7, 7)
check("guard, deflect, dodge, rally each advance in turn", attrs.AsuraTutorial == "LockOn,Light,Guard,Deflect,Dodge,Rally")
attrs.AsuraElixirs = 3; poll(); attrs.AsuraElixirs = 3; poll()
check("no drink, no heal step", not string.find(attrs.AsuraTutorial, "Heal", 1, true))
attrs.AsuraElixirs = 2; poll()
check("a spent charge (accepted drink) advances Heal", string.find(attrs.AsuraTutorial, "Heal", 1, true) ~= nil)
event("DeflectSpark", 7, -50)
check("an ordinary deflect is not the perilous lesson", not string.find(attrs.AsuraTutorial, "Perilous", 1, true))
phantom.Model.Tag = string.format("Perilous|Unarmed_Art|%.3f", now + 0.3)
fighter.State = "DeathblowVictim"; event("Evade", 7, -50)
check("a perilous strike met while helpless is not the perilous lesson", not string.find(attrs.AsuraTutorial, "Perilous", 1, true))
fighter.State = "Dashing"; event("Evade", 7, -50); fighter.State = "Idle"
check("evading a published perilous strike advances Perilous", string.find(attrs.AsuraTutorial, "Perilous", 1, true) ~= nil)
event("Deathblow", 7, -50)
handler(player, { action = "Signal", signal = "Glide" })
check("deathblow and glide finish the training", attrs.AsuraTutorial == "Complete" and profile.souls.world.tutorial.Complete == true)
local last = cues[#cues]
check("completion cued to the player", last.Kind == "TutorialStep" and last.Data.complete == true and last.Id == 7)
poll()
check("ring protection lifts once training is done", fighter.KOProtected == false)
handler(player, { action = "Replay" })
check("replay restarts from step 1 and persists", attrs.AsuraTutorial == "" and next(profile.souls.world.tutorial) == nil)
handler(player, { action = "Skip" })
check("skip persists", attrs.AsuraTutorial == "Skipped" and profile.souls.world.tutorial.Skipped == true)
for _ = 1, 10 do handler(player, { action = "Replay" }) end
check("requests are rate limited", attrs.AsuraTutorial == "" and true)
handler(player, { action = "Skip" })
check("a flood of requests cannot keep toggling", attrs.AsuraTutorial == "")
check("veteran without a record starts complete", Service.initial({ world = { tutorial = nil, altars = { Altar_DesecratedCloister = true }, bosses = {} } }).Complete == true)
check("fresh record starts empty", next(Service.initial({ world = { tutorial = {}, altars = { Altar_SanctuaryBonfire = true }, bosses = {} } })) == nil)
Service.Destroy()

-- 3. Persistence schema.
local fresh = Store.DefaultSouls(nil)
check("default souls carry an empty training record", type(fresh.world.tutorial) == "table" and next(fresh.world.tutorial) == nil and Store.ValidateSouls(fresh))
local bad = Store.Copy(fresh); bad.world.tutorial = { Light = "yes" }
check("corrupt training record rejected", not Store.ValidateSouls(bad))
local old = Store.Copy(fresh); old.world.tutorial = nil
check("older records without training load", Store.ValidateSouls(old) and next(Store.MigrateSouls(old).world.tutorial) == nil)
local kept = Store.Copy(fresh); kept.world.tutorial = { LockOn = true, Light = true }
check("training progress survives migration", Store.MigrateSouls(kept).world.tutorial.Light == true)
local data = {}
local db = { UpdateAsync = function(_, key, fn) local u = fn(Store.Copy(data[key])); if u then data[key] = Store.Copy(u) end; return Store.Copy(u) end }
local store = Store.new(db, Profiles, { owner = "t", now = function() return 1 end, wait = function() end, attempts = 1, leaseSeconds = 180 })
assert(store:Load(9))
assert(store:Transaction(9, function(p) p.souls.world.tutorial = { LockOn = true } end))
assert(store:Release(9))
local again = Store.new(db, Profiles, { owner = "u", now = function() return 2 end, wait = function() end, attempts = 1, leaseSeconds = 180 })
check("training progress survives release and rejoin", assert(again:Load(9)).souls.world.tutorial.LockOn == true)

-- 4. The landing, the courtyard and the first memorial (#15, #44).
local scene = Scene.build()
-- On paving: a few flagstones are deliberately missing (mud 0.2 lower), so sample around the point.
local function ground(x, z)
	for _, o in { { 0.6, 0.6 }, { -1.3, 0.9 }, { 1.1, -1.4 } } do
		local p, e = Scene.cast(scene, V3.new(x + o[1], 40, z + o[2]), V3.new(x + o[1], -30, z + o[2]), Scene.solid)
		if p and e and e.Name == "Flagstone" then return true end
	end
	return false
end
local spawns = {}
for _, s in World.spawnsIn("DesecratedMonastery") do spawns[s.Id] = s end
local p = spawns.DM_Sparring_Phantom
check("phantom waits on the gate landing", p and p.Placement.Z < -698 and p.Placement.Z > -748 and math.abs(p.Placement.X) < 26 and ground(p.Placement.X, p.Placement.Z))
local mob = World.Mobs.SparringPhantom
local gate = World.Altars.Altar_MonasteryGate
local gap = math.sqrt((p.Placement.X - gate.Placement.X) ^ 2 + (p.Placement.Z - gate.Placement.Z) ^ 2)
check("phantom does not notice someone resting at the altar", gap - gate.Radius > mob.AI.SightRange and mob.AI.LeashRange < 30)
check("phantom pays nothing and is gentle", mob.Essence == 0 and mob.Stats.StrengthScale < 0.5 and mob.Weapon == "Unarmed")
check("its weapon art is the unblockable lesson", require("../src/simulation/WeaponSchema").get("Unarmed").WeaponArt.Unblockable == true and mob.AI.ArtChance > 0.2)
check("kills of a zero-essence mob grant nothing", string.find(src("src/server/Services/WorldService.luau"), "if not agent or agent.Essence <= 0 then return end", 1, true) ~= nil)
local duel, b, c = spawns.DM_Monk_Courtyard_A, spawns.DM_Monk_Courtyard_B, spawns.DM_Monk_Courtyard_C
local sight = World.Mobs.CorruptWanderingMonk.AI.SightRange
local function dist(a, z) return math.sqrt((a.Placement.X - z.Placement.X) ^ 2 + (a.Placement.Z - z.Placement.Z) ^ 2) end
check("courtyard opens with a lone monk", duel and dist(duel, b) > sight + 10 and dist(duel, c) > sight + 10)
check("the pair stands together later", b and c and dist(b, c) < sight and b.Placement.Z < duel.Placement.Z - 40)
check("lone monk is not visible from the altar", math.sqrt((duel.Placement.X - gate.Placement.X) ^ 2 + (duel.Placement.Z - gate.Placement.Z) ^ 2) > sight)
for _, s in { p, duel, b, c } do
	for i, point in s.Patrol do check(s.Id .. " patrol " .. i .. " on stone", ground(point.X, point.Z)) end
end
local first = Narrative.Lore[Narrative.LoreOrder[1]]
check("first memorial stands on the arrival landing", first.Z < -698 and first.Z > -748 and math.abs(first.X) < 26 and ground(first.X, first.Z + 2))
local clear = true
for _, e in scene.Parts do
	if e.Collide and e.Name ~= "Flagstone" and (e.CFrame.Position - V3.new(first.X, 3, first.Z)).Magnitude < 4 + e.Radius then
		if Scene.inside(e, V3.new(first.X, 1.5, first.Z)) or Scene.inside(e, V3.new(first.X, 1.5, first.Z + 2)) then clear = false end
	end
end
check("first memorial is free of gatehouse stone", clear)
check("first memorial lies beside the walk to the gatehouse", math.abs(first.X) < 16 and first.Z > gate.Exit.Z)
local nw = src("src/server/Services/NarrativeWorld.luau")
check("memorials read from both faces; the first glows brighter", string.find(nw, "cf*CFrame.new(0,0,0.45)", 1, true) and string.find(nw, "Catalog.LoreOrder[1]", 1, true))
check("first reading explains the Codex", string.find(src("src/client/Controllers/CodexView.luau"), "First inscription recorded in your Codex", 1, true) ~= nil)

-- 5. Opening veil, handoff, skip and replay (#43).
local pro = src("src/client/Controllers/PrologueController.luau")
check("veil is opaque from the first frame", string.find(pro, "BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0,", 1, true) ~= nil)
check("waits for the avatar's appearance and the spawn hold", string.find(pro, "player:HasAppearanceLoaded()", 1, true) and string.find(pro, "task.wait(SETTLE)", 1, true))
check("no blind delay before the veil", not string.find(pro, "task.wait(1.5) -- let the profile", 1, true))
check("camera framed behind the avatar before reveal", string.find(pro, "camera:Face(root.CFrame.LookVector)", 1, true) ~= nil)
check("skip works on any device, replay forces the lines", string.find(pro, "Press any key or tap to skip", 1, true) and string.find(pro, "force == true", 1, true))
check("handoff names the first rest and the training", string.find(pro, "then train at the Monastery Gate", 1, true) ~= nil)
check("handoff window published before its banner", string.find(pro, "ui.HandoffUntil = os.clock() + Controller.HandoffSeconds", 1, true) ~= nil)
local pause, boot = src("src/client/Controllers/PauseMenu.luau"), src("src/client/Bootstrap.client.luau")
check("Respite offers replay of training and opening", string.find(pause, "Replay training", 1, true) and string.find(pause, "Replay opening", 1, true))
check("bootstrap wires prologue camera, tutorial and replay", string.find(boot, "task.spawn(Prologue.Play, ui, input, camera)", 1, true) and string.find(boot, "tutorial:Update(frame)", 1, true)
	and string.find(boot, "task.spawn(Prologue.Play, ui, input, camera, true)", 1, true))
local tc = src("src/client/Controllers/TutorialController.luau")
check("lock-on reported only when locked on a hostile", string.find(tc, "self.State:IsHostile(target)", 1, true) ~= nil)
check("glide reported only after holding a glide", string.find(tc, "self.Glide >= Rules.GlideSeconds", 1, true) ~= nil)
check("skip needs a confirming press", string.find(tc, "Press again to skip", 1, true) ~= nil)
check("skip names the cursor key a mouse player must hold to click it (F08)", string.find(tc, 'self:Label("Cursor") .. "] to click"', 1, true) ~= nil)
check("stakes card folds once the fight starts and clears the action bar (F08)", string.find(tc, 'snapshot.State ~= "Idle" then self.StakesPanel:Destroy()', 1, true) ~= nil
	and string.find(tc, 'Position = UDim2.new(0.5, 0, 0.72, 0)', 1, true) ~= nil)
check("stakes shown before the courtyard fight", string.find(tc, "root.Position.Z < COURTYARD_Z", 1, true) ~= nil)
-- F08 (Studio, fresh profile): the Space or click that skips the prologue reached the Controls card's
-- fold rule while it was hidden under the veil, so the reference never showed at the handoff. The
-- real ControlsCard runs on permissive engine stubs.
do
	local function stub(): any
		local store = {}
		return setmetatable(store, { __index = function(t, k)
			if k == "Visible" or k == "Enabled" then return false end
			local child = stub(); rawset(t, k, child); return child
		end, __call = function() return stub() end })
	end
	local function instance(...) -- make/panel/label: the property table is the last argument
		local i, args = stub(), { ... }
		local props = args[#args]
		if type(props) == "table" and getmetatable(props) == nil then for k, v in props do i[k] = v end end
		return i
	end
	local HudKit = setmetatable({ make = instance, panel = instance, label = instance, onViewport = function() return function() end end,
		bindScale = function() return function() end end, cue = function() end }, { __index = function() return stub() end })
	local guidance = false
	local Visibility = { of = function() return { Guidance = guidance } end }
	local Layout = { modal = function() return 1, { X = 0, Y = 0, W = 1, H = 1 } end, Regions = { ControlsPill = { At = { 0, 0 }, Offset = { 0, 0 }, Size = { 1, 1 } } } }
	local modules = { HudKit = HudKit, HudLayout = Layout, HudVisibility = Visibility, InputMap = InputMap }
	local named = function(name) return { Name = name, WaitForChild = function(self, n) return modules[n] or { Name = n, WaitForChild = self.WaitForChild } end } end
	local scriptStub = { Parent = { WaitForChild = function(_, n) return modules[n] end } }
	local env = setmetatable({ script = scriptStub, require = function(m) return m end, setmetatable = setmetatable, math = math, table = table, string = string,
		Vector2 = roblox.Vector2, UDim2 = roblox.UDim2, UDim = roblox.UDim, Color3 = roblox.Color3, Enum = roblox.Enum,
		game = { GetService = function(_, name) if name == "ReplicatedStorage" then return { WaitForChild = function() return named("AsurasPath") end } end
			return { InputBegan = { Connect = function() return { Disconnect = function() end } end }, GetFocusedTextBox = function() return nil end } end },
		workspace = { CurrentCamera = nil } }, { __index = function(_, k) return (getfenv() :: any)[k] end })
	local Card = luau.load(src("src/client/Controllers/ControlsCard.luau"), { debugName = "ControlsCard", environment = env })()
	local input = { MenuOpen = true, Device = "Keyboard" }
	local card = Card.new(input, { Gui = stub() })
	card:Update(0.1)
	input.OnCommand("Jump") -- the prologue skip key while the veil owns input
	input.OnCommand("Light") -- a click skip
	local ui = card.Ui
	input.MenuOpen, guidance, ui.HandoffUntil = false, true, os.clock() + 60
	card:Update(0.1)
	check("the handoff line is not covered by the controls card", card.Open and card.Card.Visible == false and card.Pill.Visible == false)
	input.OnCommand("Light")
	ui.HandoffUntil = 0
	card:Update(0.1)
	check("a skip under the veil leaves the controls reference to open at the handoff", card.Open and card.Card.Visible == true)
	input.OnCommand("Light")
	card:Update(0.1)
	check("a combat command still folds the card once it is on screen", not card.Open and card.Card.Visible == false and card.Pill.Visible == true)
end

-- 6. Hygiene.
local project = src("default.project.json")
for _, path in { "src/shared/TutorialRules.luau", "src/server/Services/TutorialService.luau", "src/client/Controllers/TutorialController.luau", "src/client/Controllers/PrologueController.luau", "src/client/Controllers/CodexView.luau" } do
	local text = src(path)
	local _, lines = string.gsub(text, "\n", "")
	check(path .. " strict and under 150 lines", string.sub(text, 1, 9) == "--!strict" and lines < 150)
end
check("modules and remote registered", string.find(project, "shared/TutorialRules.luau", 1, true) and string.find(project, "Services/TutorialService.luau", 1, true)
	and string.find(project, "Controllers/TutorialController.luau", 1, true) and string.find(project, '"TutorialIntent"', 1, true))
check("server starts and stops the tutorial", string.find(src("src/server/Bootstrap.server.luau"), "Tutorial.Start();started.Tutorial=true", 1, true) ~= nil)

print(string.format("opening tutorial: %d passed, %d failed", passed, failed))
if failed > 0 then error("opening tutorial regression failed") end
