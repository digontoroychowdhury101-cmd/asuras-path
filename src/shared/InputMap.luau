--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/InputMap
-- The one authoritative control scheme. Every binding (combat, spells, menus), every in-world
-- ProximityPrompt key, the action bar, spell badges and the controls reference read from here, so
-- a displayed key can never differ from the key that is accepted. Keys are Enum names so the map
-- stays testable outside Roblox; `Interact` is also the key every world prompt uses.
local InputMap = {}

export type Command =
	"Light" | "Heavy" | "WeaponArt" | "Guard" | "Roll" | "Dash" | "Sprint" | "Lock" | "Swap" | "Heal"
	| "Interact" | "Shoulder" | "Cursor" | "Jump" | "Slide" | "Aim"
	| "SpellOne" | "SpellTwo" | "Arsenal" | "Codex" | "Controls" | "Pause"
export type Owner = "Combat" | "Spell" | "Interface"
export type Binding = {
	Command: Command,
	Owner: Owner,
	Keys: { string }, -- Enum.KeyCode names (keyboard)
	Mouse: { string }, -- Enum.UserInputType names
	Pad: { string }, -- Enum.KeyCode names (gamepad)
	Key: string, -- keyboard caption
	PadKey: string, -- gamepad caption ("—" when unbound)
	Touch: string?, -- on-screen control caption, nil when touch has no equivalent
	Help: string?, -- controls reference row; nil keeps it off the card
}

local function bind(command: Command, owner: Owner, keys: { string }, mouse: { string }, pad: { string }, key: string, padKey: string, touch: string?, help: string?): Binding
	return { Command = command, Owner = owner, Keys = keys, Mouse = mouse, Pad = pad, Key = key, PadKey = padKey, Touch = touch, Help = help }
end

-- Order is the order a newcomer needs them on the controls reference.
InputMap.Bindings = {
	bind("Light", "Combat", {}, { "MouseButton1" }, { "ButtonR1" }, "M1", "R1", "ATK", "Light attack"),
	bind("Heavy", "Combat", { "V" }, {}, { "ButtonR2" }, "V", "R2", "HVY", "Heavy attack · Deathblow"),
	bind("Guard", "Combat", { "F" }, {}, { "ButtonL1" }, "F", "L1", "GUARD", "Guard · tap on impact to deflect"),
	bind("Jump", "Combat", { "Space" }, {}, { "ButtonA" }, "Space", "A", "JUMP", "Jump · double jump"),
	bind("Dash", "Combat", { "LeftShift", "Q" }, {}, { "ButtonB" }, "Shift/Q", "B", "DASH", "Dash · stamina + brief i-frames"),
	bind("Slide", "Combat", { "C", "LeftControl" }, {}, { "ButtonL3" }, "C/Ctrl", "L3", "SLIDE", "Hold slide · + Jump: bullet jump"),
	bind("Aim", "Combat", {}, { "MouseButton2" }, { "ButtonL2" }, "RMB", "L2", "GLIDE", "Hold in air to glide (3.5 s)"),
	bind("Lock", "Combat", { "X" }, { "MouseButton3" }, { "ButtonR3" }, "X", "R3", "LOCK", "Lock on to a foe"),
	bind("Heal", "Combat", { "R" }, {}, { "ButtonStart" }, "R", "Start", "HEAL", "Drink from the gourd"),
	bind("Interact", "Combat", { "Z" }, {}, { "ButtonX" }, "Z", "X", "USE", "Interact · rest, recover, read, speak"),
	bind("WeaponArt", "Combat", { "G" }, {}, { "ButtonY" }, "G", "Y", "SKILL", "Weapon art"),
	bind("Swap", "Combat", { "K" }, {}, { "DPadRight" }, "K", "D-Right", "SWAP", "Swap weapon"),
	bind("SpellOne", "Spell", { "One" }, {}, { "DPadUp" }, "1", "D-Up", "SPELL", "Cast spell slot 1"),
	bind("SpellTwo", "Spell", { "E" }, {}, { "DPadDown" }, "E", "D-Down", "SPELL", "Cast spell slot 2"),
	bind("Arsenal", "Spell", { "B" }, {}, { "ButtonSelect" }, "B", "Select", "ARSENAL", "Open the Arsenal"),
	bind("Sprint", "Combat", { "CapsLock" }, {}, { "DPadLeft" }, "Caps", "D-Left", nil, "Toggle sprint"),
	bind("Codex", "Interface", { "J" }, {}, {}, "J", "—", "CODEX", "Open the Codex"),
	bind("Shoulder", "Combat", { "T" }, {}, {}, "T", "—", nil, "Switch camera shoulder"),
	bind("Cursor", "Combat", { "LeftAlt" }, {}, {}, "Alt", "—", nil, "Hold to release the mouse cursor"),
	bind("Controls", "Interface", { "H" }, {}, {}, "H", "—", nil, nil),
	bind("Pause", "Interface", { "P" }, {}, {}, "P", "—", nil, nil),
}

-- Evasion uses the dash input; it has no key of its own.
local ALIASES: { [string]: Command } = { Roll = "Dash" }

local byCommand: { [string]: Binding } = {}
for _, binding in InputMap.Bindings do
	byCommand[binding.Command] = binding
end

function InputMap.get(command: string): Binding?
	return byCommand[ALIASES[command] or command]
end

-- Caption for a device; touch answers its on-screen label (or "—" when it has none).
function InputMap.label(command: string, device: string): string
	local binding = InputMap.get(command)
	if not binding then
		return "?"
	end
	if device == "Gamepad" then
		return binding.PadKey
	elseif device == "Touch" then
		return binding.Touch or "—"
	end
	return binding.Key
end

-- Lookup tables { [keyName]: Command } for one owner, built from the map.
function InputMap.lookup(owner: Owner, field: "Keys" | "Mouse" | "Pad"): { [string]: Command }
	local result: { [string]: Command } = {}
	for _, binding in InputMap.Bindings do
		if binding.Owner == owner then
			for _, name in (binding :: any)[field] :: { string } do
				result[name] = binding.Command
			end
		end
	end
	return result
end

-- Every in-world prompt answers the Interact binding: one key for altars, NPCs, caches, lore,
-- fog gates, bloodstains, portals and the smith.
InputMap.PromptKey = (byCommand.Interact :: Binding).Keys[1]
InputMap.PromptPad = (byCommand.Interact :: Binding).Pad[1]

function InputMap.applyPrompt(prompt: ProximityPrompt)
	prompt.KeyboardKeyCode = (Enum.KeyCode :: any)[InputMap.PromptKey]
	prompt.GamepadKeyCode = (Enum.KeyCode :: any)[InputMap.PromptPad]
end

export type PromptView = { Enabled: boolean, Key: string, Pad: string }
export type Route = "Blocked" | "Prompt" | "Intent"

-- Who owns an Interact press. Open menus and focused text boxes own every key; otherwise the
-- newest visible prompt on this device's Interact input owns it (touch USE drives any prompt),
-- and only with no such prompt does the press become the server Interact intent.
function InputMap.routeInteract(device: string, prompts: { PromptView }, blocked: boolean): (Route, number?)
	if blocked then
		return "Blocked", nil
	end
	for index = #prompts, 1, -1 do
		local prompt = prompts[index]
		if prompt.Enabled and (device == "Touch"
			or (device == "Keyboard" and prompt.Key == InputMap.PromptKey)
			or (device == "Gamepad" and prompt.Pad == InputMap.PromptPad)) then
			return "Prompt", index
		end
	end
	return "Intent", nil
end

-- Inputs claimed by more than one command on the same device ({} when the scheme is clean).
function InputMap.conflicts(): { string }
	local found: { string } = {}
	for _, field in { "Keys", "Mouse", "Pad" } do
		local seen: { [string]: string } = {}
		for _, binding in InputMap.Bindings do
			for _, name in (binding :: any)[field] :: { string } do
				local other = seen[name]
				if other and other ~= binding.Command then
					table.insert(found, string.format("%s %s: %s / %s", field, name, other, binding.Command))
				end
				seen[name] = binding.Command
			end
		end
	end
	return found
end

return table.freeze(InputMap)
