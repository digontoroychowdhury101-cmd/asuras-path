--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/ActionBar
-- The keyboard and gamepad key strip. Touch keeps its live combat buttons instead.
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local HudKit = require(script.Parent:WaitForChild("HudKit") :: ModuleScript)
local C = require(script.Parent:WaitForChild("CombatHudStyle") :: ModuleScript)
local Icons = require(script.Parent:WaitForChild("MoveIcons") :: ModuleScript)
local HudLayout = require(script.Parent:WaitForChild("HudLayout") :: ModuleScript)
local Effects = require(game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath").Shared.EffectsPreference)

local Bar = {}
local FLASH = 0.35
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

type Slot = { Command: string, Hint: string?, Mark: Frame, Rim: UIStroke, Scale: UIScale, Key: TextLabel, Icon: CanvasGroup, Lit: boolean, Until: number }
export type View = { Root: Frame, Slots: { [string]: Slot }, Device: string }

local POP = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

function Bar.new(gui: ScreenGui): View
	local size = HudLayout.ActionBarSize
	local root = HudKit.make("Frame", gui, {
		Name = "ActionBar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -HudLayout.ActionBarBottom),
		Size = UDim2.fromOffset(size[1], size[2]), BackgroundTransparency = 1,
	}) :: Frame
	root.Destroying:Once(HudKit.bindScale(root, HudLayout.ActionBarBase, HudLayout.ActionBarMinScale))
	local guide = HudKit.make("Frame", root, {
		Name = "Guide", Position = UDim2.fromOffset(8, 22), Size = UDim2.new(1, -16, 0, 1),
		BorderSizePixel = 0, BackgroundColor3 = C.Edge,
	}) :: Frame
	HudKit.make("UIGradient", guide, { Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.22, 0.35),
		NumberSequenceKeypoint.new(0.78, 0.35), NumberSequenceKeypoint.new(1, 1),
	}) })
	local slots: { [string]: Slot } = {}
	local gap = size[1] / #MOVES
	for n, move in MOVES do
		local x = (n - 0.5) * gap
		local plate = HudKit.make("Frame", root, { Name = move.Kind, AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(gap - 4, size[2]), BackgroundTransparency = 1 }) :: Frame
		local socket = HudKit.make("Frame", plate, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0),
			Size = UDim2.fromOffset(24, 20), BackgroundTransparency = 1 }) :: Frame
		local scale = HudKit.make("UIScale", socket, {}) :: UIScale
		local icon = Icons.draw(socket, move.Kind, 24)
		icon.Size = UDim2.fromOffset(22, 22)
		local mark = HudKit.make("Frame", plate, {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 22), Size = UDim2.fromOffset(4, 4),
			Rotation = 45, BackgroundColor3 = C.Edge, BorderSizePixel = 0,
		}) :: Frame
		local key = HudKit.label(plate, "", 13, Enum.Font.GothamBold, C.Ivory, {
			Position = UDim2.fromOffset(3, 26), Size = UDim2.new(1, -6, 0, 13),
			BackgroundColor3 = C.Shade, BackgroundTransparency = 0.18, TextScaled = true, ZIndex = 5,
		})
		HudKit.make("UICorner", key, { CornerRadius = UDim.new(0, 2) })
		local rim = HudKit.make("UIStroke", key, { Color = C.Edge, Thickness = 1, Transparency = 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) :: UIStroke
		HudKit.make("UITextSizeConstraint", key, { MinTextSize = 10, MaxTextSize = 13 })
		HudKit.label(plate, move.Name, 12, HudKit.TitleFont, C.Ivory, {
			Position = UDim2.fromOffset(0, 39), Size = UDim2.new(1, 0, 0, 13), TextStrokeTransparency = 0.35,
		})
		slots[move.Kind] = {
			Command = move.Command, Hint = move.Hint, Mark = mark, Rim = rim,
			Scale = scale, Key = key, Icon = icon, Lit = false, Until = 0,
		}
	end
	return { Root = root, Slots = slots, Device = "" }
end

function Bar.press(view: View, command: string)
	local kind = if command == "Guard" then "Parry" elseif command == "Roll" then "Dash" else command
	local slot = view.Slots[kind]
	if slot then slot.Until = os.clock() + FLASH end
end

local function light(slot: Slot, on: boolean)
	if on == slot.Lit then return end
	slot.Lit = on
	TweenService:Create(slot.Scale, POP, { Scale = if on then 1 + Effects.motion(0.14) else 1 }):Play()
	slot.Mark.BackgroundColor3 = if on then C.Gold else C.Edge
	slot.Mark.Size = UDim2.fromOffset(if on then 6 else 4, if on then 6 else 4)
	slot.Rim.Color, slot.Rim.Transparency = if on then C.Gold else C.Edge, if on then 0.1 else 0.5
	slot.Key.BackgroundColor3 = if on then C.Gold else C.Shade
	slot.Key.TextColor3 = if on then C.Ink else C.Ivory
end

function Bar.update(view: View, snapshot: any?, input: any, locked: boolean)
	local device = tostring(input.Device)
	view.Root.Visible = device ~= "Touch"
	if device ~= view.Device then
		view.Device = device
		for _, slot in view.Slots do
			local key = input:Label(slot.Command)
			slot.Key.Text = if slot.Hint then string.format("%s %s", key, slot.Hint) else key
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
