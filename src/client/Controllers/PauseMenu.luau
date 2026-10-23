--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/PauseMenu
-- Respite menu (P, or the ≡ blossom button beside the minimap): Resume, Settings (field of view and
-- camera sensitivity steppers, comfort/readability toggles, previewed live, saved through ShopIntent
-- SaveSettings), Controls and the Codex. Pages scroll so phones never clip an entry (batch 25).
-- The world keeps running (online Souls), so opening only releases held inputs; it never pauses.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript) :: any
local InputMap = require(Shared:WaitForChild("Shared"):WaitForChild("InputMap") :: ModuleScript)
local HudKit = require(script.Parent:WaitForChild("HudKit") :: ModuleScript)
local UiKit = require(script.Parent:WaitForChild("UiKit") :: ModuleScript)
local UiWindow = require(script.Parent:WaitForChild("UiWindow") :: ModuleScript)
local Comfort = require(script.Parent:WaitForChild("ComfortSettings") :: ModuleScript)
local Effects = require(Shared:WaitForChild("Shared"):WaitForChild("EffectsPreference") :: ModuleScript) :: any

local Menu = {}
Menu.__index = Menu
local T = UiKit.Theme
local C = Config.Camera

-- Customization ------------------------------------------------------------------------------
local WINDOW_SIZE = Vector2.new(460, 470)
local TOGGLE_KEYS: { Enum.KeyCode } = {}
for _, name in (InputMap.get("Pause") :: any).Keys do
	table.insert(TOGGLE_KEYS, (Enum.KeyCode :: any)[name])
end
local BACK_KEYS = { Enum.KeyCode.ButtonB, Enum.KeyCode.Backspace } -- only bound while open
local FOOTNOTE = "The world does not wait. Foes still hunt while you linger here."

export type Saved = { fov: number, sensitivity: number, leftHanded: boolean, comfort: any }
export type PauseMenu = typeof(setmetatable({} :: {
	Window: UiWindow.Window, Camera: any, Input: any, Ui: any, Remote: RemoteEvent, Controls: any,
	Arsenal: GuiObject, Pages: { [string]: Frame }, First: { [string]: TextButton }, Saved: Saved,
	Refresh: () -> (), Bin: UiKit.Bin,
}, Menu))

local function page(self: any, name: string): Frame
	local frame = HudKit.make("ScrollingFrame", self.Window.Body, { Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false,
		BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = T.Edge, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y }) :: Frame
	HudKit.make("UIListLayout", frame, { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder })
	self.Pages[name] = frame
	return frame
end

-- [label .......... (−) value (+)] ; `step` returns the new display text.
local function stepper(parent: Frame, order: number, text: string, step: (direction: number) -> string): () -> ()
	local row = HudKit.make("Frame", parent, { Name = text, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1 }) :: Frame
	HudKit.label(row, text, 19, T.BodyFont, T.Ivory, { Size = UDim2.new(1, -170, 1, 0), TextXAlignment = Enum.TextXAlignment.Left })
	local value = HudKit.label(row, "", 20, Enum.Font.GothamMedium, T.Gold, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -52, 0.5, 0), Size = UDim2.fromOffset(66, 30) })
	for _, direction in { -1, 1 } do
		local b = UiKit.button(row, if direction < 0 then "−" else "+", "Secondary", function()
			value.Text = step(direction)
		end)
		b.AnchorPoint, b.Size, b.TextSize = Vector2.new(1, 0.5), UDim2.fromOffset(44, 44), 24
		b.Position = UDim2.new(1, if direction < 0 then -122 else 0, 0.5, 0)
	end
	return function() value.Text = step(0) end
end

function Menu.new(camera: any, input: any, ui: any, remote: RemoteEvent, controls: any, arsenal: GuiObject): PauseMenu
	local self: any = setmetatable({ Camera = camera, Input = input, Ui = ui, Remote = remote, Controls = controls, Arsenal = arsenal, Pages = {}, First = {}, Bin = {},
		Saved = { fov = camera.Fov, sensitivity = camera.Sensitivity, leftHanded = false, comfort = Effects.get() } }, Menu)
	self.Window = UiWindow.new(ui.Gui, "RespiteMenu", "Respite", "A breath between battles", WINDOW_SIZE, function() self:Close() end)

	local main = page(self, "Main")
	local entries: { { Text: string, Variant: UiKit.Variant, Fn: () -> () } } = {
		{ Text = "Resume", Variant = "Primary", Fn = function() self:Close() end },
		{ Text = "Settings", Variant = "Secondary", Fn = function() self:Show("Settings") end },
		{ Text = "Controls", Variant = "Secondary", Fn = function() self:Close(); controls:SetOpen(true) end },
		{ Text = "Codex", Variant = "Secondary", Fn = function() self:Close(); if ui.OpenCodex then ui.OpenCodex() end end },
		{ Text = "Replay training", Variant = "Secondary", Fn = function() self:Close(); if ui.OnTraining then ui.OnTraining("Replay") end end },
		{ Text = "Replay opening", Variant = "Secondary", Fn = function() self:Close(); if ui.OnPrologue then ui.OnPrologue() end end },
	}
	for order, entry in entries do
		local b = UiKit.button(main, entry.Text, entry.Variant, entry.Fn)
		b.LayoutOrder, b.Size = order, UDim2.new(1, 0, 0, 50)
		self.First.Main = self.First.Main or b
	end
	HudKit.label(main, FOOTNOTE, 15, T.BodyFont, T.Muted, { LayoutOrder = 9, Size = UDim2.new(1, 0, 0, 44), TextWrapped = true })

	local settings = page(self, "Settings")
	local fov = stepper(settings, 1, "Field of view", function(d: number)
		camera.Fov = math.clamp(camera.Fov + d * C.FOVStep, C.MinFOV, C.MaxFOV)
		return string.format("%d°", math.floor(camera.Fov + 0.5))
	end)
	local sens = stepper(settings, 2, "Camera sensitivity", function(d: number)
		camera.Sensitivity = math.clamp(camera.Sensitivity + d * C.SensitivityStep, C.SensitivityMin, C.SensitivityMax)
		return string.format("%.2f×", camera.Sensitivity)
	end)
	local comfort = Comfort.build(settings, 3)
	self.Refresh = function() fov(); sens(); comfort() end
	local apply = UiKit.button(settings, "Apply", "Primary", function()
		remote:FireServer({ action = "SaveSettings", settings = { fov = camera.Fov, sensitivity = camera.Sensitivity, leftHanded = self.Saved.leftHanded, comfort = Effects.get() } })
	end)
	apply.LayoutOrder, apply.Size = 8, UDim2.new(1, 0, 0, 48)
	self.First.Settings = apply
	local back = UiKit.button(settings, "Back", "Secondary", function() self:Revert(); self:Show("Main") end)
	back.LayoutOrder, back.Size = 9, UDim2.new(1, 0, 0, 44)

	-- Profile syncs and save results arrive on ShopIntent; the bootstrap applies them to the camera.
	table.insert(self.Bin, remote.OnClientEvent:Connect(function(payload: any)
		if type(payload) ~= "table" then return end
		local s = type(payload.profile) == "table" and payload.profile.settings
		if type(s) == "table" and type(s.fov) == "number" and type(s.sensitivity) == "number" then
			self.Saved = { fov = s.fov, sensitivity = s.sensitivity, leftHanded = s.leftHanded == true, comfort = Effects.sanitize(s.comfort) }
		end
		if payload.action == "SettingsResult" then
			if payload.ok then UiKit.play("Click"); ui:ShowToast("Settings inscribed.") else UiKit.play("Error"); ui:ShowToast(tostring(payload.err or "The settings would not hold.")) end
			self.Refresh()
		end
	end))
	table.insert(self.Bin, arsenal:GetPropertyChangedSignal("Visible"):Connect(function()
		if arsenal.Visible then self:Close() end
	end))
	ContextActionService:BindAction("AsuraRespite", function(_: string, state: Enum.UserInputState): Enum.ContextActionResult
		if state == Enum.UserInputState.Begin and not UserInputService:GetFocusedTextBox() then self:Toggle() end
		return Enum.ContextActionResult.Sink
	end, false, table.unpack(TOGGLE_KEYS))
	return self
end

function Menu.Blocked(self: PauseMenu): boolean
	local ui = self.Ui
	-- One window at a time: Respite opened over Lin or the Codex stacked two translucent panels (F03).
	return ui.DeathShown or ui.PrologueActive == true or ui.EndingActive == true or ui.DialogueOpen == true or ui.Altar.Visible or self.Arsenal.Visible
end

function Menu.Show(self: PauseMenu, name: string)
	for key, frame in self.Pages do frame.Visible = key == name end
	self.Refresh()
	if UserInputService.GamepadEnabled then GuiService.SelectedObject = self.First[name] end
end

function Menu.Revert(self: PauseMenu)
	self.Camera.Fov, self.Camera.Sensitivity = self.Saved.fov, self.Saved.sensitivity
	Effects.set(self.Saved.comfort)
end

function Menu.Toggle(self: PauseMenu)
	if UiWindow.isOpen(self.Window) then self:Close() elseif not self:Blocked() then self:Open() end
end

function Menu.Open(self: PauseMenu)
	self.Input:SetMenu(true, "Pause")
	UiWindow.open(self.Window)
	self:Show("Main")
	ContextActionService:BindActionAtPriority("AsuraRespiteBack", function(_: string, state: Enum.UserInputState): Enum.ContextActionResult
		if state == Enum.UserInputState.Begin then
			if self.Pages.Settings.Visible then self:Revert(); self:Show("Main") else self:Close() end
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 2, table.unpack(BACK_KEYS))
end

function Menu.Close(self: PauseMenu)
	if not UiWindow.isOpen(self.Window) then return end
	ContextActionService:UnbindAction("AsuraRespiteBack")
	self:Revert()
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.Window.Root) then GuiService.SelectedObject = nil end
	UiWindow.close(self.Window, function()
		self.Input:SetMenu(false, "Pause")
	end)
end

function Menu.Destroy(self: PauseMenu)
	ContextActionService:UnbindAction("AsuraRespite")
	ContextActionService:UnbindAction("AsuraRespiteBack")
	UiKit.clean(self.Bin)
	self.Window.Root:Destroy()
end

return Menu
