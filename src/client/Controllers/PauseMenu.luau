--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/PauseMenu
-- Respite releases held inputs while the world keeps running.
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

local WINDOW_SIZE = Vector2.new(468, 668)
local TOGGLE_KEYS: { Enum.KeyCode } = {}
for _, name in (InputMap.get("Pause") :: any).Keys do
	table.insert(TOGGLE_KEYS, (Enum.KeyCode :: any)[name])
end
local BACK_KEYS = { Enum.KeyCode.ButtonB, Enum.KeyCode.Backspace } -- only bound while open
local FOOTNOTE = "The world keeps running while this menu is open."

export type Saved = { fov: number, sensitivity: number, leftHanded: boolean, comfort: any }
export type PauseMenu = typeof(setmetatable({} :: {
	Window: UiWindow.Window, Camera: any, Input: any, Ui: any, Remote: RemoteEvent, Controls: any,
	Arsenal: GuiObject, Pages: { [string]: ScrollingFrame }, First: { [string]: TextButton }, Saved: Saved,
	SettingsFooter: Frame, SaveStatus: TextLabel,
	Refresh: () -> (), Bin: UiKit.Bin,
}, Menu))

local function page(self: any, name: string): ScrollingFrame
	local frame = HudKit.make("ScrollingFrame", self.Window.Body, { Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false,
		BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = T.Edge, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, VerticalScrollBarInset = Enum.ScrollBarInset.Always }) :: ScrollingFrame
	HudKit.make("UIPadding", frame, { PaddingTop = UDim.new(0, 2), PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 4) })
	HudKit.make("UIListLayout", frame, { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	self.Pages[name] = frame
	return frame
end

local function section(parent: Instance, order: number, title: string)
	local header = HudKit.make("Frame", parent, {
		Name = title, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 27), BackgroundTransparency = 1,
	}) :: Frame
	HudKit.label(header, title, 18, T.TitleFont, T.Gold, {
		Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Left, TextStrokeTransparency = 1,
	})
	HudKit.make("Frame", header, {
		Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = T.Edge, BackgroundTransparency = 0.5, BorderSizePixel = 0,
	})
end

local function route(parent: Instance, order: number, text: string, activate: () -> ())
	local button = UiKit.button(parent, text, "Ghost", activate)
	button.LayoutOrder, button.Size = order, UDim2.new(1, 0, 0, 44)
	button.TextSize, button.TextXAlignment = 18, Enum.TextXAlignment.Left
	HudKit.make("UIPadding", button, { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) })
end

local function stepper(parent: Instance, order: number, text: string, step: (direction: number) -> string): (() -> (), TextButton)
	local row = HudKit.make("Frame", parent, { Name = text, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1 }) :: Frame
	HudKit.label(row, text, 16, T.BodyFont, T.Ivory, { Size = UDim2.new(1, -146, 1, 0), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left })
	local value = HudKit.label(row, "", 16, T.BodyFont, T.Ivory, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -44, 0.5, 0), Size = UDim2.fromOffset(48, 30) })
	local first = nil :: TextButton?
	for _, direction in { -1, 1 } do
		local b = UiKit.button(row, if direction < 0 then "−" else "+", "Secondary", function()
			value.Text = step(direction)
		end)
		b.AnchorPoint, b.Size, b.TextSize = Vector2.new(1, 0.5), UDim2.fromOffset(44, 44), 24
		b.Position = UDim2.new(1, if direction < 0 then -92 else 0, 0.5, 0)
		first = first or b
	end
	return function() value.Text = step(0) end, first :: TextButton
end

function Menu.new(camera: any, input: any, ui: any, remote: RemoteEvent, controls: any, arsenal: GuiObject): PauseMenu
	local self: any = setmetatable({ Camera = camera, Input = input, Ui = ui, Remote = remote, Controls = controls, Arsenal = arsenal, Pages = {}, First = {}, Bin = {},
		Saved = { fov = camera.Fov, sensitivity = camera.Sensitivity, leftHanded = false, comfort = Effects.get() } }, Menu)
	self.Window = UiWindow.new(ui.Gui, "RespiteMenu", "Respite", "", WINDOW_SIZE, function() self:Close() end, { LeftRail = true })

	local main = page(self, "Main")
	local resume = UiKit.button(main, "Resume", "Primary", function() self:Close() end)
	resume.LayoutOrder, resume.Size, resume.TextSize = 1, UDim2.new(1, 0, 0, 52), 19
	self.First.Main = resume
	HudKit.label(main, FOOTNOTE, 13, T.BodyFont, T.Muted, {
		LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 26), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
	})

	section(main, 3, "Journey")
	route(main, 4, "World map", function() self:Close(); if ui.OpenMap then ui.OpenMap() end end)
	route(main, 5, "Codex", function() self:Close(); if ui.OpenCodex then ui.OpenCodex() end end)

	section(main, 6, "Preferences")
	route(main, 7, "Settings", function() self:Show("Settings") end)
	route(main, 8, "Controls", function() self:Close(); controls:SetOpen(true) end)

	section(main, 9, "Replay")
	route(main, 10, "Training", function() self:Close(); if ui.OnTraining then ui.OnTraining("Replay") end end)
	route(main, 11, "Opening", function() self:Close(); if ui.OnPrologue then ui.OnPrologue() end end)

	local settings = page(self, "Settings")
	settings.Size = UDim2.new(1, 0, 1, -76)
	section(settings, 1, "Camera")
	local fov, first = stepper(settings, 2, "Field of view", function(d: number)
		camera.Fov = math.clamp(camera.Fov + d * C.FOVStep, C.MinFOV, C.MaxFOV)
		return string.format("%d°", math.floor(camera.Fov + 0.5))
	end)
	local sens = stepper(settings, 3, "Camera sensitivity", function(d: number)
		camera.Sensitivity = math.clamp(camera.Sensitivity + d * C.SensitivityStep, C.SensitivityMin, C.SensitivityMax)
		return string.format("%.2f×", camera.Sensitivity)
	end)
	section(settings, 4, "Accessibility")
	local comfort = Comfort.build(settings, 5)
	self.Refresh = function() fov(); sens(); comfort() end
	local footer = HudKit.make("Frame", self.Window.Body, {
		Name = "SettingsFooter", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 71), BackgroundTransparency = 1, Visible = false,
	}) :: Frame
	self.SettingsFooter = footer
	self.SaveStatus = HudKit.label(footer, "", 13, T.BodyFont, T.Muted, {
		Name = "SaveStatus", Size = UDim2.new(1, 0, 0, 24), TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left,
	})
	local apply = UiKit.button(footer, "Save settings", "Primary", function()
		self.SaveStatus.Text, self.SaveStatus.TextColor3 = "Saving settings…", T.Muted
		remote:FireServer({ action = "SaveSettings", settings = { fov = camera.Fov, sensitivity = camera.Sensitivity, leftHanded = self.Saved.leftHanded, comfort = Effects.get() } })
	end)
	apply.Position, apply.Size = UDim2.fromOffset(0, 25), UDim2.new(1, -88, 0, 46)
	local back = UiKit.button(footer, "Back", "Secondary", function() self:Revert(); self:Show("Main") end)
	back.AnchorPoint, back.Position, back.Size = Vector2.new(1, 0), UDim2.new(1, 0, 0, 25), UDim2.fromOffset(80, 46)
	self.First.Settings = first

	-- Profile syncs and save results arrive on ShopIntent; the bootstrap applies them to the camera.
	table.insert(self.Bin, remote.OnClientEvent:Connect(function(payload: any)
		if type(payload) ~= "table" then return end
		local s = type(payload.profile) == "table" and payload.profile.settings
		if type(s) == "table" and type(s.fov) == "number" and type(s.sensitivity) == "number" then
			self.Saved = { fov = s.fov, sensitivity = s.sensitivity, leftHanded = s.leftHanded == true, comfort = Effects.sanitize(s.comfort) }
		end
		if payload.action == "SettingsResult" then
			local result = if payload.ok then "Settings saved." else tostring(payload.err or "Settings could not be saved.")
			self.SaveStatus.Text, self.SaveStatus.TextColor3 = result, if payload.ok then T.Jade else T.Ember
			UiKit.play(if payload.ok then "Click" else "Error")
			if not (self.SettingsFooter.Visible and UiWindow.isOpen(self.Window)) then ui:ShowToast(result) end
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
	self.Window.Title.Text = if name == "Settings" then "Settings" else "Respite"
	self.SettingsFooter.Visible, self.SaveStatus.Text = name == "Settings", ""
	self.Pages[name].CanvasPosition = Vector2.zero
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
