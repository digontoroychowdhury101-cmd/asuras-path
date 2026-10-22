--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/DeviceLayout
-- Batch 25 (#33 #35 #37 #39): places the HUD for the active device. On touch it applies the
-- HudLayout.Touch profile measured inside the device safe area (vitals in the freed bottom centre,
-- spell slots top-right above the combat buttons, objective beside the minimap, target plate and
-- boss bar in the top band, warnings between the thumbstick and the buttons) and restores the
-- authored desktop placement when a keyboard or controller takes over. It also keeps the HUD,
-- touch controls and dialogue inside notches (DeviceSafeInsets); on touch the minimap's Respite
-- blossom grows to a 44-point target and the small controls blossom gives way (Controls and the
-- Codex are Respite entries); a controller reaches Respite from the Arsenal window (Select).
-- Presentation only.
local HudKit = require(script.Parent:WaitForChild("HudKit") :: ModuleScript)
local UiKit = require(script.Parent:WaitForChild("UiKit") :: ModuleScript)
local Layout = require(script.Parent:WaitForChild("HudLayout") :: ModuleScript)
local UiWindow = require(script.Parent:WaitForChild("UiWindow") :: ModuleScript)

local Device = {}
Device.__index = Device

-- Frame name in the HUD -> touch rect key, whether its size follows the rect, and its UIScale base.
local MANAGED: { [string]: { Rect: string, Sized: boolean, Base: number? } } = {
	Vitals = { Rect = "Vitals", Sized = false, Base = 0.78 },
	Loadout = { Rect = "Vitals", Sized = false, Base = 0.78 },
	ObjectiveTracker = { Rect = "Objective", Sized = false },
	BossBar = { Rect = "Boss", Sized = true },
	TargetPlate = { Rect = "Target", Sized = true },
	CombatCallout = { Rect = "Callout", Sized = true },
}

type Saved = { AnchorPoint: Vector2, Position: UDim2, Size: UDim2, Min: Vector2? }

function Device.new(ui: any, input: any, extras: { ScreenGui }, arsenal: any?, pause: any?): any
	local self = setmetatable({ Ui = ui, Input = input, Saved = {} :: { [string]: Saved }, Touch = false, Links = {} }, Device) :: any
	for _, gui in { ui.Gui, table.unpack(extras) } do
		pcall(function() (gui :: any).ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets end)
	end
	local function refresh() self:Apply() end
	table.insert(self.Links, (ui.Gui :: ScreenGui):GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh))
	local previous = input.OnDeviceChanged
	input.OnDeviceChanged = function(device: string) if previous then previous(device) end; refresh() end
	self.RestoreDevice = function() input.OnDeviceChanged = previous end
	if arsenal and pause then self:MenuRoute(arsenal, pause) end
	refresh()
	return self
end

local function constraint(frame: GuiObject): UISizeConstraint?
	return frame:FindFirstChildOfClass("UISizeConstraint")
end

function Device.Apply(self: any)
	self:Place(self.Input.Device == "Touch")
end

function Device.Place(self: any, touch: boolean)
	local gui = self.Ui.Gui :: ScreenGui
	local size = gui.AbsoluteSize
	self.Touch = touch
	self.Ui.TouchHud = touch -- HudVisibility: pointer-only buttons give way on touch
	self:Blossoms(gui, touch)
	if size.X < 2 or size.Y < 2 then return end
	local rects = Layout.touch(size.X, size.Y)
	for name, spec in MANAGED do
		local frame = gui:FindFirstChild(name)
		if not frame or not frame:IsA("GuiObject") then continue end
		local limit = constraint(frame)
		local saved = self.Saved[name]
		if not saved then
			saved = { AnchorPoint = frame.AnchorPoint, Position = frame.Position, Size = frame.Size, Min = if limit then limit.MinSize else nil }
			self.Saved[name] = saved
		end
		local scale = frame:FindFirstChildOfClass("UIScale")
		if touch then
			local r = rects[spec.Rect]
			frame.AnchorPoint, frame.Position = Vector2.zero, UDim2.fromOffset(math.floor(r.X), math.floor(r.Y))
			if spec.Sized then
				frame.Size = UDim2.fromOffset(math.floor(r.W), frame.Size.Y.Offset)
				if limit then limit.MinSize = Vector2.new(math.min(limit.MinSize.X, math.floor(r.W)), limit.MinSize.Y) end
			end
			if spec.Base then frame:SetAttribute("AsuraScaleBase", Layout.Touch.VitalsBase) end
			if scale and spec.Base then scale.Scale = Layout.Touch.VitalsBase * HudKit.factor() end
		else
			frame.AnchorPoint, frame.Position, frame.Size = saved.AnchorPoint, saved.Position, saved.Size
			if limit and saved.Min then limit.MinSize = saved.Min end
			if spec.Base then frame:SetAttribute("AsuraScaleBase", nil) end
			if scale and spec.Base then scale.Scale = spec.Base * HudKit.factor() end
		end
	end
end

-- Minimap blossoms: Respite (≡) is the touch menu button, so it gets a 44-point target there.
local TOUCH_TARGET: number = 44
local BLOSSOM_SIZE: number = 30 -- SakuraMinimap's Sakura.roundButton size
Device.TouchTarget, Device.BlossomSize = TOUCH_TARGET, BLOSSOM_SIZE
function Device.Blossoms(self: any, gui: ScreenGui, touch: boolean)
	local map = gui:FindFirstChild("Minimap")
	if not map or not map:IsA("GuiObject") then return end
	local mapScale = map:FindFirstChildOfClass("UIScale")
	local mapFactor: number = if mapScale then mapScale.Scale else 1
	local shown: number = BLOSSOM_SIZE * mapFactor -- on-screen points
	for _, b in map:GetChildren() do
		if b:IsA("TextButton") and (b.Text == "≡" or b.Text == "?") then
			local grow = (b:FindFirstChild("TouchGrow") :: UIScale?) or (HudKit.make("UIScale", b, { Name = "TouchGrow" }) :: UIScale)
			local wanted: number = TOUCH_TARGET / shown
			grow.Scale = if touch and b.Text == "≡" then math.max(1, wanted) else 1
			b.Visible = not (touch and b.Text == "?")
		end
	end
end

-- Respite and Codex buttons in the Arsenal window: the controller's way to settings and lore.
function Device.MenuRoute(self: any, arsenal: any, pause: any)
	local body = arsenal.Window.Body :: Frame
	local hint = arsenal.Hint :: TextLabel
	hint.Size = UDim2.new(1, -236, 0, 36)
	local row = HudKit.make("Frame", body, { Name = "MenuRoute", AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(228, 36), BackgroundTransparency = 1 }) :: Frame
	HudKit.make("UIListLayout", row, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8),
		HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder })
	local function leave() UiWindow.close(arsenal.Window) end
	local respite = UiKit.button(row, "Respite", "Secondary", function() leave(); task.defer(function() pause:Open() end) end)
	local codex = UiKit.button(row, "Codex", "Secondary", function() leave(); if self.Ui.OpenCodex then self.Ui.OpenCodex() end end)
	for order, button in { respite, codex } do
		button.LayoutOrder, button.Size = order, UDim2.fromOffset(110, 36)
	end
	self.Route = row
end

function Device.Destroy(self: any)
	for _, link in self.Links do link:Disconnect() end
	table.clear(self.Links)
	self.RestoreDevice()
	self:Place(false)
	self.Ui.TouchHud = false
	if self.Route then self.Route:Destroy() end
end

return Device
