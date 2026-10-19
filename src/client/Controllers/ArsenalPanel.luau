--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/ArsenalPanel
-- The Arsenal (B / Select): Qi spell slots, weapon loadout and Gao's transmutation as one tabbed
-- lacquer window. Re-renders the active tab from the last inventory packet; every action goes to
-- the server through `Send` (ArsenalIntent), which stays authoritative. Forging asks twice.
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local HudKit = require(script.Parent:WaitForChild("HudKit") :: ModuleScript)
local UiKit = require(script.Parent:WaitForChild("UiKit") :: ModuleScript)
local UiWindow = require(script.Parent:WaitForChild("UiWindow") :: ModuleScript)
local ArsenalTabs = require(script.Parent:WaitForChild("ArsenalTabs") :: ModuleScript)

local Panel = {}
local T = UiKit.Theme

-- Customization ------------------------------------------------------------------------------
local WINDOW_SIZE = Vector2.new(760, 560)
local TABS = { "Spells", "Weapons", "Forge" }
local TAB_TEXT: { [string]: string } = { Spells = "Qi Sorcery", Weapons = "Weapons", Forge = "Transmutation" }
local HINTS: { [string]: string } = {
	Spells = "Slot I casts on 1 / D-Pad Up · Slot II on E / D-Pad Down · Melee hits +8 Qi · Perfect deflects +15 Qi",
	Weapons = "A Jade Catalyst held off-hand focuses sorcery: +25% potency and faster casting.",
	Forge = "Each remembrance forges ONE weapon or spell. The choice is permanent. Visit Gao's Loggia.",
}
export type View = {
	Root: Frame, List: ScrollingFrame, Send: (any) -> (), Inventory: any,
	Window: UiWindow.Window, Tab: string, Tabs: { [string]: TextButton }, Hint: TextLabel,
}

local function render(view: View)
	for _, child in view.List:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	for name, tab in view.Tabs do
		tab.TextColor3 = if name == view.Tab then T.Gold else T.Muted;
		(tab:FindFirstChild("Underline") :: Frame).Visible = name == view.Tab
	end
	view.Hint.Text = HINTS[view.Tab]
	local inv = view.Inventory
	if not inv then
		HudKit.label(view.List, "The arsenal stirs…", 18, T.BodyFont, T.Muted, { Size = UDim2.new(1, 0, 0, 40) })
		return
	end
	local fill: (send: (any) -> (), inv: any, list: ScrollingFrame) -> () = if view.Tab == "Spells" then ArsenalTabs.Spells elseif view.Tab == "Weapons" then ArsenalTabs.Weapons else ArsenalTabs.Forge
	fill(view.Send, inv, view.List)
	if UserInputService.GamepadEnabled and UiWindow.isOpen(view.Window) then
		GuiService.SelectedObject = view.List:FindFirstChildWhichIsA("TextButton", true)
	end
end

function Panel.new(gui: ScreenGui, send: (any) -> ()): View
	local view: View
	local window = UiWindow.new(gui, "ArsenalPanel", "Arsenal", "Weapons · Qi Sorcery · Transmutation", WINDOW_SIZE, function() Panel.close(view) end)
	local tabs = HudKit.make("Frame", window.Body, { Name = "Tabs", Size = UDim2.new(1, -50, 0, 38), BackgroundTransparency = 1 }) :: Frame
	HudKit.make("UIListLayout", tabs, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	local list = HudKit.make("ScrollingFrame", window.Body, {
		Name = "List", Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 1, -92), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 4, ScrollBarImageColor3 = T.Edge, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y,
	}) :: ScrollingFrame
	HudKit.make("UIListLayout", list, { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	HudKit.make("UIPadding", list, { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 2) })
	local hint = HudKit.label(window.Body, "", 14, T.BodyFont, T.Muted, {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 36), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
	})
	view = { Root = window.Root, List = list, Send = send, Inventory = nil, Window = window, Tab = "Spells", Tabs = {}, Hint = hint }
	for order, name in TABS do
		local tab = UiKit.button(tabs, TAB_TEXT[name], "Ghost", function()
			view.Tab = name
			render(view)
		end)
		tab.LayoutOrder, tab.Size = order, UDim2.new(1 / #TABS, -6, 1, 0)
		HudKit.make("Frame", tab, { Name = "Underline", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -3), Size = UDim2.new(0.6, 0, 0, 2), BackgroundColor3 = T.Gold, BorderSizePixel = 0 })
		view.Tabs[name] = tab
	end
	render(view)
	return view
end

function Panel.update(view: View, inventory: any)
	view.Inventory = inventory
	render(view)
end

function Panel.isOpen(view: View): boolean
	return UiWindow.isOpen(view.Window)
end

function Panel.open(view: View)
	UiWindow.open(view.Window)
	render(view)
end

function Panel.close(view: View)
	UiWindow.close(view.Window)
end

return table.freeze(Panel)
