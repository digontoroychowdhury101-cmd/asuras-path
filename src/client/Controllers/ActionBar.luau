--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/ActionBar
-- Bottom-centre row of sakura medallions, one per combat move, each with a drawn icon, its name and
-- the key for the current device (keyboard or gamepad; hidden on touch, which has its own buttons).
-- A medallion pops and glows gold while its move is happening: attacks on press, Block while the
-- guard is up, Parry during the deflect window, Dodge while dashing, Lock while locked on.
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local HudKit = require(script.Parent:WaitForChild("HudKit") :: ModuleScript)
local Sakura = require(script.Parent:WaitForChild("SakuraKit") :: ModuleScript)
local Icons = require(script.Parent:WaitForChild("MoveIcons") :: ModuleScript)

local Bar = {}
local C = Sakura.Colors

-- Customization ------------------------------------------------------------------------------
local SLOT = 46 -- medallion diameter (px at 900px screen height)
local GAP = 74 -- centre-to-centre spacing
local BOTTOM = require(script.Parent:WaitForChild("HudLayout") :: ModuleScript).ActionBarBottom -- reserved combat row
local FLASH = 0.35 -- seconds an attack medallion stays lit after its key is pressed
-- Kind = icon, Command = input action whose key is shown, Hint = suffix for shared keys.
local MOVES: { { Kind: string, Name: string, Command: string, Hint: string? } } = {
	{ Kind = "Light", Name = "Slash", Command = "Light" },
	{ Kind = "Heavy", Name = "Heavy", Command = "Heavy" },
	{ Kind = "Parry", Name = "Parry", Command = "Guard", Hint = "tap" },
	{ Kind = "Block", Name = "Block", Command = "Guard", Hint = "hold" },
	{ Kind = "Dash", Name = "Dodge", Command = "Dash" },
	{ Kind = "WeaponArt", Name = "Art", Command = "WeaponArt" },
	{ Kind = "Heal", Name = "Heal", Command = "Heal" },
	{ Kind = "Lock", Name = "Lock On", Command = "Lock" },
}

type Slot = { Kind: string, Command: string, Hint: string?, Disc: Frame, Stroke: UIStroke?, Scale: UIScale, Key: TextLabel, Icon: CanvasGroup, Lit: boolean, Until: number }
export type View = { Root: Frame, Slots: { [string]: Slot }, Device: string }

local POP = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

function Bar.new(gui: ScreenGui): View
	local width = GAP * (#MOVES - 1) + SLOT + 24
	local root = HudKit.make("Frame", gui, {
		Name = "ActionBar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -BOTTOM),
		Size = UDim2.fromOffset(width, SLOT + 40), BackgroundTransparency = 1,
	}) :: Frame
	root.Destroying:Once(HudKit.bindScale(root, 0.8))
	local slots: { [string]: Slot } = {}
	for n, move in MOVES do
		local x = 12 + SLOT / 2 + (n - 1) * GAP
		local disc = Sakura.medallion(root, SLOT, UDim2.fromOffset(x, SLOT / 2), false)
		disc.BackgroundTransparency = 0.15
		local scale = HudKit.make("UIScale", disc, {}) :: UIScale
		local icon = Icons.draw(disc, move.Kind, SLOT)
		local key = HudKit.label(disc, "", 11, Enum.Font.GothamBold, C.Ink, {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromOffset(34, 16),
			BackgroundColor3 = C.Blossom, BackgroundTransparency = 0, ZIndex = 5,
		})
		HudKit.make("UICorner", key, { CornerRadius = UDim.new(1, 0) })
		HudKit.make("UIStroke", key, { Color = C.Rose, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
		HudKit.label(root, move.Name, 12, Enum.Font.Garamond, C.Blossom, {
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(x, SLOT + 12), Size = UDim2.fromOffset(GAP, 16), TextStrokeTransparency = 0.35,
		})
		slots[move.Kind] = {
			Kind = move.Kind, Command = move.Command, Hint = move.Hint, Disc = disc, Stroke = disc:FindFirstChildOfClass("UIStroke"),
			Scale = scale, Key = key, Icon = icon, Lit = false, Until = 0,
		}
	end
	return { Root = root, Slots = slots, Device = "" }
end

-- Lights the medallion for a pressed command (attacks only stay lit for FLASH seconds).
function Bar.press(view: View, command: string)
	local kind = if command == "Guard" then "Parry" elseif command == "Roll" then "Dash" else command
	local slot = view.Slots[kind]
	if slot then slot.Until = os.clock() + FLASH end
end

local function light(slot: Slot, on: boolean)
	if on == slot.Lit then return end
	slot.Lit = on
	TweenService:Create(slot.Scale, POP, { Scale = if on then 1.14 else 1 }):Play()
	if slot.Stroke then
		TweenService:Create(slot.Stroke, POP, { Color = if on then C.Gold else C.Sakura, Thickness = if on then 3.5 else 2 }):Play()
	end
end

function Bar.update(view: View, snapshot: any?, input: any, locked: boolean)
	local device = tostring(input.Device)
	view.Root.Visible = device ~= "Touch"
	if device ~= view.Device then
		view.Device = device
		for _, slot in view.Slots do
			local key = input:Label(slot.Command)
			slot.Key.Text = if slot.Hint then string.format("%s %s", key, slot.Hint) else key
			slot.Key.Size = UDim2.fromOffset(math.max(28, #slot.Key.Text * 7 + 10), 16)
		end
	end
	local now = os.clock()
	local state = if snapshot then snapshot.State else "Idle"
	local active: { [string]: boolean } = {
		Block = snapshot ~= nil and (snapshot.Blocking or state == "Blocking" or state == "Blockstun"),
		Parry = state == "Deflecting",
		Dash = state == "Dashing",
		Lock = locked,
	}
	local flasks = tonumber(Players.LocalPlayer:GetAttribute("AsuraElixirs")) or 0
	view.Slots.Heal.Icon.GroupTransparency = if flasks > 0 then 0 else 0.6
	local winded = snapshot ~= nil and snapshot.State == "StaminaBroken"
	for kind, slot in view.Slots do
		light(slot, active[kind] == true or now < slot.Until)
		if kind ~= "Heal" then slot.Icon.GroupTransparency = if winded and kind ~= "Lock" then 0.55 else 0 end
	end
end

return table.freeze(Bar)
