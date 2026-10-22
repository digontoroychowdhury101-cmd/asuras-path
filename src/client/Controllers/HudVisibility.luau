--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/HudVisibility
-- One rule for which HUD layers may show. Every layer asks this each frame instead of keeping its
-- own hidden flag, so leaving the prologue, death screen or a dialogue restores exactly what the
-- current situation allows and no stale label survives a transition.
local ProximityPromptService = game:GetService("ProximityPromptService")

local Visibility = {}

export type Flags = { Death: boolean, Prologue: boolean, Dialogue: boolean, Altar: boolean, Boss: boolean, Touch: boolean? }
export type Layers = {
	Combat: boolean, -- action bar, enemy plates, target plate, callouts, lock-on
	Vitals: boolean, -- health / stamina / Qi plate and loadout
	Boss: boolean, -- boss bar and duo strip
	Decor: boolean, -- compass, minimap, screen petals
	Guidance: boolean, -- objective, controls pill/card, Codex button, spell cluster
	Pointer: boolean, -- guidance buttons for mouse/controller only (touch reaches them through Respite)
	Prompts: boolean, -- in-world ProximityPrompts
	Notices: boolean, -- toasts and banners
}

-- Pure decision table (tested in tools/test_hud_layout.luau).
function Visibility.resolve(flags: Flags): Layers
	local cinematic = flags.Death or flags.Prologue
	local talking = flags.Dialogue
	return {
		Combat = not cinematic and not talking,
		Vitals = not cinematic and not talking,
		Boss = flags.Boss and not cinematic and not talking,
		Decor = not cinematic and not talking,
		Guidance = not cinematic and not talking and not flags.Altar,
		Pointer = not cinematic and not talking and not flags.Altar and flags.Touch ~= true,
		Prompts = not cinematic and not talking and not flags.Altar, -- menus own the interact key
		Notices = not flags.Death,
	}
end

function Visibility.flags(ui: any): Flags
	return {
		Death = ui.DeathShown == true,
		Prologue = ui.PrologueActive == true or ui.EndingActive == true, -- the crossing is cinematic too
		Dialogue = ui.DialogueOpen == true,
		Altar = ui.Altar ~= nil and ui.Altar.Visible == true,
		Boss = ui.BossEntity ~= nil,
		Touch = ui.TouchHud == true,
	}
end

function Visibility.of(ui: any): Layers
	return Visibility.resolve(Visibility.flags(ui))
end

-- Small HUD pieces without their own update (e.g. the Codex button) register a layer once.
local registered: { [GuiObject]: string } = setmetatable({}, { __mode = "k" }) :: any
function Visibility.register(object: GuiObject, layer: string)
	registered[object] = layer
end

-- Prompts are a local client setting: hiding them never disables the server-side interaction.
local promptsShown = true
function Visibility.apply(ui: any): Layers
	local layers = Visibility.of(ui)
	if layers.Prompts ~= promptsShown then
		promptsShown = layers.Prompts
		ProximityPromptService.Enabled = layers.Prompts
	end
	for object, layer in registered do
		object.Visible = (layers :: any)[layer] == true
	end
	return layers
end

function Visibility.restore()
	promptsShown = true
	ProximityPromptService.Enabled = true
	table.clear(registered)
end

return table.freeze(Visibility)
