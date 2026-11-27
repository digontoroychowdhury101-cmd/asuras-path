--!strict
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage").AsurasPath.Shared
local Settings = require(Shared.CombatSettings)
local InputMap = require(Shared.InputMap)
local Rules = require(Shared.ProgressionRules)
local HudKit = require(script.Parent.HudKit)
local UiKit = require(script.Parent.UiKit)
local UiWindow = require(script.Parent.UiWindow)
local ArsenalTabs = require(script.Parent.ArsenalTabs)
local Equipment = require(script.Parent.ArsenalEquipment)

local Panel = {}
local T = UiKit.Theme
local WINDOW_SIZE = Vector2.new(1440, 820)
local TABS = { "Weapons", "Armor", "Spells", "Forge" }
local TAB_TEXT: { [string]: string } = { Weapons = "Weapons", Armor = "Armour", Spells = "Qi Sorcery", Forge = "Transmute" }

export type View = {
	Root: Frame, List: ScrollingFrame, Send: (any) -> (), Inventory: any, Label: (string) -> string,
	Window: UiWindow.Window, Tab: string, Tabs: { [string]: TextButton }, Hint: TextLabel, Equipment: any, Content: Frame,
}

local function hint(tab: string, label: (string) -> string): string
	if tab == "Spells" then
		return string.format("Slot 1 [%s]   ·   Slot 2 [%s]   ·   Hits +%d Qi   ·   Perfect deflects +%d Qi",
			label("SpellOne"), label("SpellTwo"), Settings.Qi.GainOnHit, Settings.Qi.GainOnDeflect)
	elseif tab == "Forge" then
		return "At Gao’s Loggia, a remembrance forges one weapon or spell. Choose once."
	end
	return ""
end

local function attributes(): { [string]: number }
	local player, result = Players.LocalPlayer, {}
	for _, id in Rules.Attributes do result[id] = tonumber(player:GetAttribute("Asura" .. id)) or 10 end
	return result
end

local function render(view: View)
	if not UiWindow.isOpen(view.Window) then return end
	for _, child in view.List:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	for name, tab in view.Tabs do
		local selected = name == view.Tab
		tab.TextColor3 = if selected then T.Gold else T.Muted
		local underline = tab:FindFirstChild("Underline") :: Frame
		underline.Visible = selected
		tab:SetAttribute("AsuraSelected", selected)
	end
	view.Hint.Text = hint(view.Tab, view.Label)
	local inv = view.Inventory
	local equipment = inv ~= nil and (view.Tab == "Weapons" or view.Tab == "Armor")
	view.List.Visible, view.Equipment.Root.Visible = not equipment, equipment
	if equipment then
		Equipment.render(view.Equipment, view.Tab, inv, attributes(), view.Send)
		return
	end
	view.Equipment.Stage:Clear()
	if not inv then
		HudKit.label(view.List, "Loading equipment…", 17, T.BodyFont, T.Muted, { Size = UDim2.new(1, 0, 0, 44) })
		return
	end
	local fill = if view.Tab == "Spells" then ArsenalTabs.Spells else ArsenalTabs.Forge
	fill(view.Send, inv, view.List, { Label = view.Label, Attributes = attributes() })
	if UserInputService.GamepadEnabled then GuiService.SelectedObject = view.List:FindFirstChildWhichIsA("TextButton", true) or view.Tabs[view.Tab] end
end

local function layout(view: View)
	local body = view.Window.Body
	local narrow = body.AbsoluteSize.X < 510
	local hasHint = view.Hint.Text ~= ""
	local route = body:FindFirstChild("MenuRoute") :: Frame?
	local reserve = if route then 47 else 0
	if hasHint and (narrow or not route) then reserve += 40 end
	view.Content.Size = UDim2.new(1, 0, 1, -51 - reserve)
	view.Hint.Size = UDim2.new(1, if route and not narrow then -236 else 0, 0, 40)
	view.Hint.Position = UDim2.new(0, 0, 1, if narrow and route then -46 else 0)
	if route then
		route.Size = UDim2.fromOffset(228, 44)
		for _, child in route:GetChildren() do
			if child:IsA("TextButton") then child.Size = UDim2.fromOffset(110, 44) end
		end
	end
end

function Panel.new(gui: ScreenGui, send: (any) -> (), label: ((string) -> string)?): View
	local view: View
	local window = UiWindow.new(gui, "ArsenalPanel", "The Arsenal", "", WINDOW_SIZE, function() Panel.close(view) end)
	local ratio = window.Holder:FindFirstChildOfClass("UIAspectRatioConstraint")
	if ratio then ratio:Destroy() end
	window.Holder.Size = UDim2.fromScale(0.94, 0.94)
	local tabs = HudKit.make("Frame", window.Body, { Name = "Tabs", Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1 })
	HudKit.make("UIListLayout", tabs, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
	local content = HudKit.make("Frame", window.Body, { Name = "ArsenalContent", Position = UDim2.fromOffset(0, 51), BackgroundTransparency = 1 })
	local list = HudKit.make("ScrollingFrame", content, {
		Name = "List", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 4, ScrollBarImageColor3 = T.Edge, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y,
	})
	HudKit.make("UIListLayout", list, { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	HudKit.make("UIPadding", list, { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 2) })
	local footer = HudKit.label(window.Body, "", 14, T.BodyFont, T.Muted, {
		AnchorPoint = Vector2.new(0, 1), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
	})
	local equipment = Equipment.new(content)
	equipment.Root.Size, equipment.Root.Visible = UDim2.fromScale(1, 1), false
	local keys = label or function(command: string): string return InputMap.label(command, "Keyboard") end
	view = { Root = window.Root, List = list, Send = send, Inventory = nil, Label = keys, Window = window,
		Tab = "Weapons", Tabs = {}, Hint = footer, Equipment = equipment, Content = content }
	for order, name in TABS do
		local tab = Equipment.choice(tabs, TAB_TEXT[name], function() view.Tab = name; render(view) end)
		tab.LayoutOrder, tab.Size = order, UDim2.new(0.25, -5, 1, 0)
		tab.Name, tab.TextSize, tab.TextScaled = name, 16, true
		HudKit.make("UITextSizeConstraint", tab, { MinTextSize = 12, MaxTextSize = 17 })
		HudKit.make("Frame", tab, { Name = "Underline", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2),
			Size = UDim2.new(0.66, 0, 0, 2), BackgroundColor3 = T.Gold, BorderSizePixel = 0 })
		view.Tabs[name] = tab
	end
	window.Body:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() layout(view) end)
	window.Body.ChildAdded:Connect(function(child) if child.Name == "MenuRoute" then task.defer(layout, view) end end)
	footer:GetPropertyChangedSignal("Text"):Connect(function() layout(view) end)
	window.Root:GetPropertyChangedSignal("Visible"):Connect(function()
		if not window.Root.Visible then equipment.Stage:Clear() end
	end)
	layout(view)
	return view
end

function Panel.update(view: View, inventory: any) view.Inventory = inventory; render(view) end
function Panel.isOpen(view: View): boolean return UiWindow.isOpen(view.Window) end
function Panel.open(view: View) UiWindow.open(view.Window); render(view) end
function Panel.close(view: View) UiWindow.close(view.Window) end

return table.freeze(Panel)
