--!strict
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage").AsurasPath
local Armor = require(Shared.Shared.ArmorRules)
local Facts = require(Shared.Shared.ArsenalFacts)
local Weapons = require(Shared.Simulation.WeaponSchema)
local HudKit = require(script.Parent.HudKit)
local UiKit = require(script.Parent.UiKit)
local ItemInspection = require(script.Parent.ItemInspection)

local Equipment = {}
local T = UiKit.Theme
local LEFT = Enum.TextXAlignment.Left
local Y = Enum.AutomaticSize.Y
local EQUIPPED = Color3.fromRGB(151, 199, 171)
local EDGE = Color3.fromRGB(196, 155, 101)
local ACTIVE = Color3.fromRGB(53, 38, 29)
local LACQUER = Color3.fromRGB(15, 16, 18)

type Entry = { Id: string, Name: string, Status: string, Equipped: boolean }

function Equipment.choice(parent: Instance, text: string, activate: () -> ()): TextButton
	local button: TextButton = HudKit.make("TextButton", parent, {
		Text = text, Font = T.BodyFont, TextColor3 = T.Muted, AutoButtonColor = false, Selectable = true,
		BackgroundTransparency = 1, BackgroundColor3 = T.Raised, BorderSizePixel = 0,
	})
	local focus: UIStroke = HudKit.make("UIStroke", button, {
		Name = "Focus", Color = T.Gold, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Enabled = false,
	})
	local hovered, focused = false, false
	local function paint()
		local on = button:GetAttribute("AsuraSelected") == true
		button.BackgroundColor3 = if on then ACTIVE else T.Raised
		button.BackgroundTransparency = if on then 0.08 elseif hovered or focused then 0.4 else 1
		focus.Enabled = focused
	end
	button.MouseEnter:Connect(function() hovered = true; paint() end)
	button.MouseLeave:Connect(function() hovered = false; paint() end)
	button.SelectionGained:Connect(function() focused = true; paint() end)
	button.SelectionLost:Connect(function() focused = false; paint() end)
	button:GetAttributeChangedSignal("AsuraSelected"):Connect(paint)
	button.Activated:Connect(function() UiKit.play("Click"); activate() end)
	return button
end

local function frame(parent: Instance, name: string): Frame
	return HudKit.make("Frame", parent, { Name = name, BackgroundTransparency = 1, BorderSizePixel = 0 })
end

local function scroll(parent: Frame, name: string, gap: number): ScrollingFrame
	local root = HudKit.make("ScrollingFrame", parent, {
		Name = name, BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
		ScrollBarImageColor3 = T.Edge, AutomaticCanvasSize = Y, CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y, Selectable = false,
	})
	HudKit.make("UIListLayout", root, { Padding = UDim.new(0, gap), SortOrder = Enum.SortOrder.LayoutOrder })
	HudKit.make("UIPadding", root, { PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 7), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2) })
	return root
end

local function line(parent: ScrollingFrame, text: string, size: number, color: Color3, order: number, font: Enum.Font?): TextLabel
	return HudKit.label(parent, text, size, font or T.BodyFont, color, {
		LayoutOrder = order, Size = UDim2.fromScale(1, 0), AutomaticSize = Y, TextWrapped = true,
		TextXAlignment = LEFT, TextStrokeTransparency = 1,
	})
end

local function clear(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end
end

function Equipment.new(parent: Frame): any
	local root = frame(parent, "Equipment")
	root.BackgroundColor3, root.BackgroundTransparency = LACQUER, 0
	local catalog = scroll(root, "EquipmentCatalog", 5)
	local display = frame(root, "InspectionCase")
	local detail = scroll(root, "EquipmentDetails", 9)
	local stage = ItemInspection.new(display, { Size = UDim2.fromScale(1, 1) })
	local nameplate = HudKit.label(display, "", 30, T.TitleFont, T.Ivory, {
		Position = UDim2.fromOffset(15, 6), Size = UDim2.new(1, -204, 0, 36),
		TextScaled = true, TextXAlignment = LEFT, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 2,
	})
	HudKit.make("UITextSizeConstraint", nameplate, { MinTextSize = 15, MaxTextSize = 30 })
	local view = { Root = root, Catalog = catalog, Detail = detail, Display = display, Stage = stage, Nameplate = nameplate, Selected = {}, Rows = {} }
	local function layout()
		local width, height = root.AbsoluteSize.X, root.AbsoluteSize.Y
		local columns = width >= 680 or (width >= 500 and height < 320)
		if not columns then
			local stageHeight = math.clamp(math.floor(height * 0.55), 110, 400)
			display.Position, display.Size = UDim2.new(), UDim2.new(1, 0, 0, stageHeight)
			catalog.Position, catalog.Size = UDim2.fromOffset(0, stageHeight + 12), UDim2.new(0.40, -5, 1, -stageHeight - 12)
			detail.Position, detail.Size = UDim2.new(0.40, 7, 0, stageHeight + 12), UDim2.new(0.60, -7, 1, -stageHeight - 12)
		else
			local side = math.clamp(math.floor(width * 0.165), 108, 211)
			local text = math.clamp(math.floor(width * 0.205), 135, 245)
			catalog.Position, catalog.Size = UDim2.new(), UDim2.new(0, side, 1, 0)
			display.Position, display.Size = UDim2.fromOffset(side + 14, 0), UDim2.new(1, -side - text - 30, 1, 0)
			detail.Position, detail.Size = UDim2.new(1, -text, 0, 0), UDim2.new(0, text, 1, 0)
		end
	end
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	root.Destroying:Connect(function() stage:Destroy() end)
	layout()
	return view
end

local function weapons(inv: any): { Entry }
	local entries: { Entry } = {}
	for _, id in Weapons.WeaponKeys do
		local weapon = Weapons.get(id :: any)
		local equipped = inv.mainhand == id or inv.offhand == id
		local status = if inv.mainhand == id then "Wielded" elseif inv.offhand == id then "Off-hand"
			elseif inv.weapons[id] then "Owned" else "Unowned"
		table.insert(entries, { Id = id, Name = weapon.Name, Status = status, Equipped = equipped })
	end
	if (inv.materials and inv.materials.LastBreathTalisman or 0) > 0 then
		table.insert(entries, { Id = "LastBreathTalisman", Name = "Last Breath Talisman", Status = "Consumable", Equipped = false })
	end
	return entries
end

local function armour(inv: any): { Entry }
	local entries: { Entry } = {}
	for _, id in Armor.Order do
		local entry = inv.armor and inv.armor[id]
		local equipped = inv.armorSet == id
		local status = if equipped then "Worn" elseif entry or id == Armor.Default then "Owned" else "Unowned"
		table.insert(entries, { Id = id, Name = Armor.Sets[id].Name, Status = status, Equipped = equipped })
	end
	return entries
end

local function actionButton(parent: ScrollingFrame, order: number, text: string, action: () -> ())
	local button = UiKit.button(parent, text, if order == 10 then "Primary" else "Secondary", action)
	button.Name, button.LayoutOrder = "EquipmentAction" .. order, order
	button.TextWrapped, button.TextSize = true, 16
end

local function armorStats(values: any): string
	return string.format("Protection %.1f%%  ·  Posture +%d\nMovement %d%%", values.Protection * 100, values.Posture, math.round(values.Speed * 100))
end

local function details(view: any, item: Entry, tab: string, inv: any, attributes: { [string]: number }, send: (any) -> ())
	local detail: ScrollingFrame = view.Detail
	clear(detail)
	detail.CanvasPosition = Vector2.zero
	local id = item.Id
	if view.Nameplate then view.Nameplate.Text = item.Name end
	local statusColor = if item.Equipped then EQUIPPED else T.Muted
	line(detail, string.upper(item.Status), 13, statusColor, 0)
	if tab == "Armor" then
		local piece = Armor.Sets[id]
		local owned = inv.armor and inv.armor[id]
		local level = if owned then owned.Level else 0
		line(detail, piece.Role .. " armour" .. (if level > 0 then "  ·  +" .. level else ""), 15, T.Gold, 2)
		line(detail, piece.Blurb, 17, T.Ivory, 3)
		line(detail, armorStats(Armor.values(id, level)), 17, EQUIPPED, 4)
		if not item.Equipped then
			line(detail, "Current armour\n" .. armorStats(Armor.worn(inv.armor, inv.armorSet)), 15, T.Muted, 5)
		end
		if item.Status == "Unowned" and piece.Requirement then line(detail, piece.Requirement, 15, T.Muted, 6) end
		line(detail, "Visit Gao in the Loggia to change or reinforce armour.", 15, T.Muted, 7)
		view.Stage:Show("Armor", id)
	elseif id == "LastBreathTalisman" then
		line(detail, tostring(inv.materials.LastBreathTalisman) .. " owned  ·  Wards one fatal blow for 30 seconds.", 17, T.Ivory, 3)
		actionButton(detail, 10, "Invoke", function() send({ action = "UseTalisman" }) end)
		view.Stage:Clear()
	else
		local facts = Facts.weapon(id, Facts.context(inv, attributes))
		line(detail, facts.Use, 18, T.Ivory, 3)
		line(detail, facts.Detail, 15, T.Muted, 4)
		line(detail, facts.Effects, 16, T.Gold, 5)
		if inv.weapons[id] then
			if inv.mainhand ~= id then
				actionButton(detail, 10, "Wield", function() send({ action = "EquipWeapon", id = id, offhand = false }) end)
			end
			if id == "Catalyst" and inv.offhand ~= id then
				actionButton(detail, 11, "Equip off-hand", function() send({ action = "EquipWeapon", id = id, offhand = true }) end)
			end
		end
		view.Stage:Show("Weapon", id)
	end
end

function Equipment.render(view: any, tab: string, inv: any, attributes: { [string]: number }, send: (any) -> ())
	local entries = if tab == "Armor" then armour(inv) else weapons(inv)
	local remembered = view.Selected[tab]
	local selected, active = nil :: Entry?, nil :: Entry?
	for _, item in entries do
		if item.Id == remembered then selected = item end
		if item.Equipped and not active then active = item end
	end
	selected = selected or active or entries[1]
	if not selected then return end
	local previous = GuiService.SelectedObject
	local previousId = if previous and previous:IsDescendantOf(view.Catalog) then previous.Name else nil
	local position = view.Catalog.CanvasPosition
	clear(view.Catalog)
	table.clear(view.Rows)
	local function choose(item: Entry)
		view.Selected[tab] = item.Id
		for _, row in view.Rows do
			local on = row.Button.Name == item.Id
			row.Mark.Visible = on
			row.Name.TextColor3 = if on then T.Gold else T.Ivory
			row.Name.Font, row.Name.TextSize = if on then T.TitleFont else T.BodyFont, if on then 19 else 17
			row.Button:SetAttribute("AsuraSelected", on)
		end
		details(view, item, tab, inv, attributes, send)
	end
	for order, item in entries do
		local button = Equipment.choice(view.Catalog, "", function() choose(item) end)
		button.Name, button.LayoutOrder, button.Size = item.Id, order, UDim2.new(1, 0, 0, 55)
		HudKit.make("Frame", button, {
			Name = "Divider", Position = UDim2.new(0, 9, 1, -1), Size = UDim2.new(1, -18, 0, 1),
			BackgroundColor3 = T.Edge, BackgroundTransparency = 0.72, BorderSizePixel = 0,
		})
		local mark = HudKit.make("Frame", button, {
			Name = "SelectionMark", Position = UDim2.fromOffset(0, 4), Size = UDim2.new(0, 4, 1, -8),
			BackgroundColor3 = EDGE, BorderSizePixel = 0, Visible = false,
		})
		local name = HudKit.label(button, item.Name, 17, T.BodyFont, T.Ivory, {
			Position = UDim2.fromOffset(10, 5), Size = UDim2.new(1, -17, 0, 24), TextXAlignment = LEFT,
			TextTruncate = Enum.TextTruncate.AtEnd, TextStrokeTransparency = 1,
		})
		HudKit.label(button, item.Status, 13, T.BodyFont, if item.Equipped then EQUIPPED else T.Muted, {
			Position = UDim2.fromOffset(10, 29), Size = UDim2.new(1, -17, 0, 17), TextXAlignment = LEFT, TextStrokeTransparency = 1,
		})
		view.Rows[item.Id] = { Button = button, Mark = mark, Name = name }
	end
	choose(selected)
	if previousId then view.Catalog.CanvasPosition = position end
	if UserInputService.GamepadEnabled then
		local button = view.Rows[previousId or selected.Id] or view.Rows[selected.Id]
		GuiService.SelectedObject = button.Button
	end
end

return table.freeze(Equipment)
