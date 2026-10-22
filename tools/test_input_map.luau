--!strict
-- Lune regression for the shared control scheme (playtest findings #5, #6, #37).
-- Run from the project root: lune run tools/test_input_map.luau
-- Checks the InputMap for device conflicts, the requested default keys, interact ownership
-- (prompt range, overlap, menus/text boxes, held input) and that no client/server source
-- re-hard-codes a bound key or a prompt key. Rules/source checks only; Studio play is separate.
local fs = require("@lune/fs")
local Map = require("../src/shared/InputMap") :: any

local passed, failed = 0, 0
local function check(name: string, condition: boolean)
	if condition then
		passed += 1
	else
		failed += 1
		print("FAIL " .. name)
	end
end
local function has(list: { string }, value: string): boolean
	return table.find(list, value) ~= nil
end

-- 1. Requested defaults and conflicts.
local conflicts = Map.conflicts()
check("no device conflicts (" .. table.concat(conflicts, "; ") .. ")", #conflicts == 0)
check("Z interacts", has(Map.get("Interact").Keys, "Z") and Map.PromptKey == "Z")
check("gamepad X interacts", Map.PromptPad == "ButtonX")
check("E is spell slot 2", has(Map.get("SpellTwo").Keys, "E"))
check("J opens Codex", has(Map.get("Codex").Keys, "J"))
check("K swaps weapons", has(Map.get("Swap").Keys, "K") and not has(Map.get("Swap").Keys, "J"))
for _, binding in Map.Bindings do
	if binding.Command ~= "Interact" then
		check(binding.Command .. " does not claim Z/ButtonX", not has(binding.Keys, "Z") and not has(binding.Pad, "ButtonX"))
	end
	if binding.Command ~= "SpellTwo" then
		check(binding.Command .. " does not claim E", not has(binding.Keys, "E"))
	end
	check(binding.Command .. " has a keyboard caption", binding.Key ~= "" and (#binding.Keys + #binding.Mouse > 0))
	check(binding.Command .. " pad caption matches binding", (#binding.Pad == 0) == (binding.PadKey == "—"))
end
local preserved = { Light = "MouseButton1", Heavy = "V", Guard = "F", Jump = "Space", Dash = "LeftShift", Slide = "C",
	Aim = "MouseButton2", Lock = "X", Heal = "R", WeaponArt = "G", Sprint = "CapsLock", Shoulder = "T", Cursor = "LeftAlt",
	SpellOne = "One", Arsenal = "B", Controls = "H", Pause = "P" }
for command, key in preserved do
	local binding = Map.get(command)
	check(command .. " keeps " .. key, has(binding.Keys, key) or has(binding.Mouse, key))
end
check("roll aliases dash", Map.get("Roll") == Map.get("Dash"))
check("touch captions", Map.label("Interact", "Touch") == "USE" and Map.label("Sprint", "Touch") == "—")
check("gamepad captions", Map.label("Swap", "Gamepad") == "D-Right" and Map.label("Interact", "Gamepad") == "X")
for _, command in { "SpellOne", "SpellTwo", "Arsenal", "Codex", "Cursor", "Shoulder", "Interact", "Swap" } do
	check(command .. " on the controls reference", Map.get(command).Help ~= nil)
end
local combat = Map.lookup("Combat", "Keys")
check("combat lookup excludes spells/menus", combat.E == nil and combat.J == nil and combat.One == nil and combat.K == "Swap")

-- 2. Interact ownership.
local Z = { Enabled = true, Key = "Z", Pad = "ButtonX" }
local legacyE = { Enabled = true, Key = "E", Pad = "ButtonX" }
local disabled = { Enabled = false, Key = "Z", Pad = "ButtonX" }
check("outside every prompt: intent", (Map.routeInteract("Keyboard", {}, false)) == "Intent")
check("inside a prompt: prompt owns Z", (Map.routeInteract("Keyboard", { Z }, false)) == "Prompt")
check("menu open blocks interact", (Map.routeInteract("Keyboard", { Z }, true)) == "Blocked")
check("text box blocks interact", (Map.routeInteract("Keyboard", {}, true)) == "Blocked")
check("foreign-key prompt does not swallow Z", (Map.routeInteract("Keyboard", { legacyE }, false)) == "Intent")
check("disabled prompt does not own", (Map.routeInteract("Keyboard", { disabled }, false)) == "Intent")
check("gamepad X owned by prompt", (Map.routeInteract("Gamepad", { legacyE }, false)) == "Prompt")
local route, index = Map.routeInteract("Touch", { Z, legacyE }, false)
check("touch USE drives newest prompt", route == "Prompt" and index == 2)
route, index = Map.routeInteract("Keyboard", { Z, legacyE, disabled }, false)
check("overlap: newest owning prompt wins once", route == "Prompt" and index == 1)

-- 3. Sources: one definition. Bound keys and prompt keys must not be re-hard-coded.
local MENU_LOCAL = { Escape = true, Backspace = true, ButtonB = true, Thumbstick2 = true } -- menu close / analog look
local bound: { [string]: boolean } = {}
for _, binding in Map.Bindings do
	for _, field in { binding.Keys, binding.Pad } do
		for _, name in field do
			bound[name] = true
		end
	end
end
local function scan(dir: string, visit: (path: string, source: string) -> ())
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			scan(path, visit)
		elseif string.sub(name, -5) == ".luau" and path ~= "src/shared/InputMap.luau" then
			visit(path, fs.readFile(path))
		end
	end
end
local promptSites, appliedSites = 0, 0
scan("src", function(path: string, source: string)
	for key in string.gmatch(source, "Enum%.KeyCode%.([%w]+)") do
		if bound[key] and not MENU_LOCAL[key] then
			check(path .. " hard-codes bound key " .. key, false)
		end
	end
	check(path .. " sets prompt keys directly", string.find(source, "KeyboardKeyCode%s*=") == nil and string.find(source, "GamepadKeyCode%s*=") == nil)
	local _, created = string.gsub(source, 'Instance%.new%("ProximityPrompt"%)', "")
	local _, applied = string.gsub(source, "InputMap%.applyPrompt%(", "")
	promptSites += created
	appliedSites += applied
	if created > 0 then
		check(path .. " applies the shared prompt key to each prompt", applied >= created)
	end
end)
check("all prompt sites found", promptSites >= 11)
print(string.format("prompt sites %d, shared-key applications %d", promptSites, appliedSites))
check("Codex button caption derived", string.find(fs.readFile("src/client/Controllers/DialogueController.luau"), "Codex %[J%]") == nil)

print(string.format("input map: %d passed, %d failed", passed, failed))
if failed > 0 then
	error("input map regression failed")
end
