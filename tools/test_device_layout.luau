--!nonstrict
-- Batch 25 regression (findings #5 #6 #12 #13 #33-#37 #39-#43): device layouts, touch targets,
-- active-device hint captions, the controller/touch routes to Respite and the Codex, comfort
-- settings (reduced effects/motion/flashes, text size) persisted through the real schema and
-- protocol, and DeviceLayout applied to emulated HUD frames. Layout geometry and emulation only:
-- no rendered pixels, phones, tablets or controllers were used.
-- Run: lune run tools/test_device_layout.luau (locally: python3 tools/lune_compat.py tools/test_device_layout.luau)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox") :: any
local InputMap = require("../src/shared/InputMap")
local Tutorial = require("../src/shared/TutorialRules")
local Boss = require("../src/shared/BossEncounterRules")
local Schema = require("../src/shared/ProfileSchema")
local Protocol = require("../src/infrastructure/IntentProtocol")

local passed, failed = 0, 0
local function check(name: string, ok: any)
	if ok then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local C = "src/client/Controllers/"
local function src(path: string): string return fs.readFile(path) end
local function load(path: string, env: { [string]: any }?): any
	local e = env or {}
	e.Vector2, e.Vector3, e.UDim2, e.UDim, e.Enum, e.Color3 = roblox.Vector2, roblox.Vector3, roblox.UDim2, roblox.UDim, roblox.Enum, roblox.Color3
	return luau.load(src(path), { debugName = path, environment = e })()
end
local Layout = load(C .. "HudLayout.luau")
local Effects = load("src/shared/EffectsPreference.luau", { task = { spawn = function(f, ...) f(...) end } })
local function overlaps(a, b) return a.X < b.X + b.W and b.X < a.X + a.W and a.Y < b.Y + b.H and b.Y < a.Y + a.H end

-- 1. Touch profile inside the device safe area: phones (SE, 14 with notch insets, Pro Max) and tablets.
local apart = { Objective = { Boss = true }, Target = { Boss = true }, Boss = { Objective = true, Target = true } }
local touchViewports = { { 667, 375 }, { 750, 369 }, { 838, 409 }, { 1024, 768 }, { 1180, 820 }, { 1366, 1024 } }
for _, v in touchViewports do
	local tag = v[1] .. "x" .. v[2] .. " touch"
	local r = Layout.touch(v[1], v[2])
	local names = {}
	for n in r do table.insert(names, n) end
	table.sort(names)
	local clashes = {}
	for i = 1, #names do for j = i + 1, #names do
		local a, b = names[i], names[j]
		if not (apart[a] and apart[a][b]) and overlaps(r[a], r[b]) then table.insert(clashes, a .. "/" .. b) end
	end end
	check(tag .. ": no co-visible HUD regions overlap (" .. table.concat(clashes, ", ") .. ")", #clashes == 0)
	local outside = {}
	for n, rect in r do if rect.X < 0 or rect.Y < 0 or rect.X + rect.W > v[1] + 0.01 or rect.Y + rect.H > v[2] + 0.01 then table.insert(outside, n) end end
	check(tag .. ": every region inside the safe area (" .. table.concat(outside, ", ") .. ")", #outside == 0)
	check(tag .. ": warnings sit between the thumbstick and the buttons", r.Callout.X >= r.Thumb.W and r.Callout.X + r.Callout.W <= r.Cluster.X)
	check(tag .. ": target plate and boss bar keep a readable width", r.Target.W >= Layout.Touch.MinTarget and r.Boss.W >= Layout.Touch.MinBoss)
	local s = Layout.modal(v[1], v[2], 2 * 300 + 28, 46 + 10 * 26, true)
	check(tag .. ": controls reference readable as a touch modal", 17 * s >= 11)
end

-- 2. Touch buttons: 44-point targets at the smallest HUD factor, no overlaps, inside the cluster.
local input = src(C .. "InputController.luau")
local minTouch = tonumber(string.match(input, "local MIN_TOUCH = (%d+)"))
local buttons = {}
for command, x, y, size in string.gmatch(input, '{ Command = "(%a+)", Position = UDim2.new%(1, (%-?%d+), 1, (%-?%d+)%), Size = (%d+) }') do
	table.insert(buttons, { Command = command, X = tonumber(x), Y = tonumber(y), R = math.max(tonumber(size), minTouch or 0) / 2 })
end
check("touch layout parsed (12 buttons)", #buttons == 12 and minTouch ~= nil)
local smallest, tight = math.huge, nil
for i, a in buttons do
	smallest = math.min(smallest, a.R * 2 * Layout.MinFactor)
	check(a.Command .. " button inside the cluster", a.X - a.R >= -340 and a.X + a.R <= 0 and a.Y - a.R >= -360 and a.Y + a.R <= 0)
	for j = i + 1, #buttons do
		local b = buttons[j]
		if math.sqrt((a.X - b.X) ^ 2 + (a.Y - b.Y) ^ 2) < a.R + b.R then tight = a.Command .. "/" .. b.Command end
	end
end
check(string.format("every touch button is a 44-point target at the smallest scale (%.1f)", smallest), smallest >= 44)
check("no touch buttons overlap (" .. tostring(tight) .. ")", tight == nil)
local deviceSource = src(C .. "DeviceLayout.luau")
local target = tonumber(string.match(deviceSource, "local TOUCH_TARGET: number = (%d+)"))
local blossom = tonumber(string.match(deviceSource, "local BLOSSOM_SIZE: number = (%d+)"))
check("the Respite blossom grows to a 44-point touch target", target == 44 and blossom == 30
	and string.find(src(C .. "SakuraMinimap.luau"), "roundButton(root, 30", 1, true) ~= nil)

-- 3. Hints name the active device's input (#5 #13): counters and tutorial on keyboard, pad and touch.
check("counter hints read input:Hint (touch names its button)", string.find(src(C .. "CombatHud.luau"), "input:Hint(c)", 1, true) ~= nil
	and string.find(input, "function Controller.Hint", 1, true) ~= nil)
for _, device in { "Keyboard", "Gamepad", "Touch" } do
	local hint = Tutorial.text(Boss.CounterKeys["Air Glide"], function(c) return InputMap.label(c, device) end)
	check(device .. " counter hint names a real input: " .. hint, not string.find(hint, "[]", 1, true) and not string.find(hint, "—", 1, true))
end
check("touch Air Glide hint reads the JUMP button", Tutorial.text(Boss.CounterKeys["Air Glide"], function(c) return InputMap.label(c, "Touch") end) == "[JUMP] [JUMP], hold [JUMP]")

-- 4. Visibility: pointer-only buttons give way on touch; Respite carries Controls and the Codex.
local Visibility = load(C .. "HudVisibility.luau", { game = { GetService = function() return {} end }, setmetatable = setmetatable, table = table })
local plain = { Death = false, Prologue = false, Dialogue = false, Altar = false, Boss = false }
check("desktop shows the Codex button and controls pill", Visibility.resolve(plain).Pointer == true)
local touchFlags = table.clone(plain); touchFlags.Touch = true
check("touch hides them but keeps guidance", Visibility.resolve(touchFlags).Pointer == false and Visibility.resolve(touchFlags).Guidance == true)
check("the crossing hides the HUD like the prologue", Visibility.flags({ EndingActive = true }).Prologue == true)
local pause = src(C .. "PauseMenu.luau")
check("Respite lists Controls and the Codex", string.find(pause, '{ Text = "Codex"', 1, true) ~= nil and string.find(pause, '{ Text = "Controls"', 1, true) ~= nil)
check("Respite pages scroll on short screens", string.find(pause, 'HudKit.make("ScrollingFrame", self.Window.Body', 1, true) ~= nil)
check("a controller reaches Respite and the Codex from the Arsenal window", string.find(deviceSource, 'UiKit.button(row, "Respite"', 1, true) ~= nil
	and string.find(deviceSource, 'UiKit.button(row, "Codex"', 1, true) ~= nil)
check("the Codex has a route on every device", string.find(src(C .. "DialogueController.luau"), "ui.OpenCodex=function()", 1, true) ~= nil)

-- 5. Comfort settings: one validator each side, persisted, previewed and reverted.
check("defaults are calm-off and 100% text", Effects.reduced() == false and Effects.reducedMotion() == false and Effects.textScale() == 1)
Effects.set({ ReducedMotion = true, ReducedFlashes = true, TextScale = 1.3 })
check("reduced motion keeps a share of shake, not none", Effects.motion(4) == 4 * Effects.MotionFloor and Effects.MotionFloor > 0)
check("reduced flashes dim blooms but keep them visible", Effects.flash(1) == Effects.FlashFloor and Effects.FlashFloor > 0)
check("text scale applies", Effects.textScale() == 1.3)
check("sanitize rejects junk", Effects.sanitize({ ReducedMotion = "yes", TextScale = 9 }).TextScale == 1 and Effects.sanitize({ ReducedMotion = "yes" }).ReducedMotion == false)
local heard = 0
local stop = Effects.onChanged(function() heard += 1 end)
Effects.set({ ReducedMotion = true }); check("unchanged settings stay quiet", heard == 0)
Effects.set({ ReducedEffects = true }); check("a change notifies listeners", heard == 1 and Effects.decor(true) == 0)
stop(); Effects.set(Effects.Default); check("revert restores the defaults", Effects.reducedMotion() == false and Effects.textScale() == 1)
local profile = Schema.Default(5)
check("new profiles carry comfort defaults", Schema.ValidComfort(profile.settings.comfort) and Schema.Validate(profile))
profile.settings.comfort = { ReducedEffects = true, ReducedMotion = false, ReducedFlashes = true, TextScale = 1.15 }
local migrated = Schema.Migrate(profile, 5)
check("saved comfort survives migration", migrated.settings.comfort.ReducedEffects and migrated.settings.comfort.TextScale == 1.15)
local legacy = Schema.Default(6); legacy.settings.comfort = nil
check("profiles from before batch 25 validate and gain defaults", Schema.Validate(legacy) and Schema.Migrate(legacy, 6).settings.comfort.TextScale == 1)
local bad = Schema.Default(7); bad.settings.comfort = { ReducedEffects = 1, ReducedMotion = false, ReducedFlashes = false, TextScale = 1 }
check("corrupt comfort is refused and repaired", not Schema.Validate(bad) and Schema.Validate(Schema.Migrate(bad, 7)))
local packet = { action = "SaveSettings", settings = { fov = 80, sensitivity = 1, leftHanded = false, comfort = { ReducedEffects = false, ReducedMotion = true, ReducedFlashes = false, TextScale = 1.3 } } }
check("the settings intent accepts comfort", Protocol.Shop(packet))
packet.settings.comfort.TextScale = 3
check("and rejects an out-of-range text size", not Protocol.Shop(packet))
check("older clients without comfort still save", Protocol.Shop({ action = "SaveSettings", settings = { fov = 80, sensitivity = 1, leftHanded = false } }))
local shop = src("src/server/ShopService.luau")
check("the server stores comfort through the schema validator", string.find(shop, "Schema.ValidComfort(settings.comfort)", 1, true) ~= nil)
check("Back reverts camera and comfort; Apply sends both", string.find(pause, "Effects.set(self.Saved.comfort)", 1, true) ~= nil and string.find(pause, "comfort = Effects.get() }", 1, true) ~= nil)
check("the profile sync applies saved comfort", string.find(src("src/client/Bootstrap.client.luau"), "Effects.set(Effects.sanitize(settings.comfort))", 1, true) ~= nil)
for path, needle in { ["CameraController.luau"] = "Effects.motion(magnitude)", ["BossEffects.luau"] = "Comfort.flash(0.4)", ["CombatVfx.luau"] = "Comfort.flash(3)",
	["DialogueView.luau"] = "Effects.textScale()", ["EndingController.luau"] = "Effects.reducedMotion()", ["CombatFeedback.luau"] = "Comfort.reducedMotion()" } do
	check(path .. " reads the comfort setting", string.find(src(C .. path), needle, 1, true) ~= nil)
end
local Comfort = load(C .. "ComfortSettings.luau", { game = { GetService = function() return { WaitForChild = function(s) return s end } end },
	script = { Parent = { WaitForChild = function() return {} end } }, require = function(m) return if type(m) == "table" and m.WaitForChild then Effects else m end })
check("text size cycles 100 -> 115 -> 130 -> 100", Comfort.nextScale(1) == 1.15 and Comfort.nextScale(1.15) == 1.3 and Comfort.nextScale(1.3) == 1 and Comfort.caption(1.15) == "115%")

-- 6. DeviceLayout on emulated frames: touch placement from the profile, desktop restored.
local Shim = roblox
local gui = Shim.Instance.new("ScreenGui")
local size = Shim.Vector2.new(750, 369)
roblox.implementProperty("ScreenGui", "AbsoluteSize", function() return size end)
local function frame(name, anchor, pos, sz)
	local f = Shim.Instance.new("Frame"); f.Name, f.AnchorPoint, f.Position, f.Size = name, anchor, pos, sz; f.Parent = gui
	return f
end
local vitals = frame("Vitals", Shim.Vector2.new(0, 1), Shim.UDim2.new(0, 16, 1, -12), Shim.UDim2.fromOffset(470, 150))
Shim.Instance.new("UIScale").Parent = vitals
local bossBar = frame("BossBar", Shim.Vector2.new(0.5, 0), Shim.UDim2.new(0.5, 0, 0, 74), Shim.UDim2.new(0.5, 0, 0, 96))
local limit = Shim.Instance.new("UISizeConstraint"); limit.MinSize = Shim.Vector2.new(300, 96); limit.Parent = bossBar
frame("ObjectiveTracker", Shim.Vector2.new(1, 0), Shim.UDim2.new(1, -20, 0, 64), Shim.UDim2.fromOffset(360, 92))
local map = frame("Minimap", Shim.Vector2.new(0, 0), Shim.UDim2.fromOffset(20, 66), Shim.UDim2.fromOffset(190, 190))
local mapScale = Shim.Instance.new("UIScale"); mapScale.Scale = 0.82 * 0.7; mapScale.Parent = map
local menu = Shim.Instance.new("TextButton"); menu.Text = "≡"; menu.Parent = map
local help = Shim.Instance.new("TextButton"); help.Text = "?"; help.Visible = true; help.Parent = map
local ui = { Gui = gui }
local device = { Device = "Touch" }
local kit = { factor = function() return 0.7 end, make = function(class, parent, props) local i = Shim.Instance.new(class); for k, v in props do i[k] = v end; i.Parent = parent; return i end }
local DeviceLayout = load(C .. "DeviceLayout.luau", { script = { Parent = { WaitForChild = function(_, n) return ({ HudKit = kit, UiKit = {}, HudLayout = Layout, UiWindow = {} })[n] end } },
	require = function(m) return m end, pcall = pcall, math = math, table = table, type = type, setmetatable = setmetatable, task = task })
local placed = DeviceLayout.new(ui, device, {})
local want = Layout.touch(750, 369)
check("touch places the vitals in the freed bottom centre", vitals.Position.X.Offset == math.floor(want.Vitals.X) and vitals.Position.Y.Offset == math.floor(want.Vitals.Y) and vitals.AnchorPoint.X == 0)
check("touch vitals scale follows the profile", math.abs(vitals:FindFirstChildOfClass("UIScale").Scale - Layout.Touch.VitalsBase * 0.7) < 1e-9 and vitals:GetAttribute("AsuraScaleBase") == Layout.Touch.VitalsBase)
check("touch sizes the boss bar to the top band", bossBar.Size.X.Offset == math.floor(want.Boss.W) and limit.MinSize.X <= want.Boss.W)
check("touch: Respite blossom >= 44 pt, controls blossom hidden", 30 * mapScale.Scale * menu:FindFirstChild("TouchGrow").Scale >= 44 - 1e-6 and help.Visible == false and ui.TouchHud == true)
device.Device = "Keyboard"; device.OnDeviceChanged("Keyboard")
check("a keyboard restores the authored desktop placement", vitals.AnchorPoint.Y == 1 and vitals.Position.Y.Offset == -12 and bossBar.Size.X.Scale == 0.5 and limit.MinSize.X == 300
	and vitals:GetAttribute("AsuraScaleBase") == nil and help.Visible == true and menu:FindFirstChild("TouchGrow").Scale == 1 and ui.TouchHud == false)
device.Device = "Touch"; device.OnDeviceChanged("Touch")
placed:Destroy()
check("Destroy restores desktop placement and the device hook", vitals.AnchorPoint.Y == 1 and device.OnDeviceChanged == nil)

print(string.format("device layout: %d passed, %d failed (geometry + emulation; no phone, tablet or controller hardware)", passed, failed))
if failed > 0 then error("device layout regression failed") end
