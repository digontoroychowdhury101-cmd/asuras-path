--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Input = game:GetService("UserInputService")
local Assets = ReplicatedStorage:WaitForChild("AsurasPath")
local Vendor = script.Parent.Parent:WaitForChild("Vendor")
local Spr = require(Vendor.Spr)
local Trove = require(Vendor.Trove)
local ViewportModel = require(Vendor.ViewportModel)
local Effects = require(Assets.Shared.EffectsPreference)
local Hud = require(script.Parent.HudKit)
local Kit = require(script.Parent.UiKit)
local Scene = require(script.Parent.InspectionStage)
local Cues = require(script.Parent.InspectionCues)

local Inspection = {}
Inspection.__index = Inspection
local T = Kit.Theme
local BRASS = Color3.fromRGB(220, 179, 117)
local INK = Color3.fromRGB(13, 14, 16)

type Lens = { Name: string, Yaw: number, Pitch: number, Fov: number, Duration: number }
type Shot = Lens & { Fit: any }
export type Stage = typeof(setmetatable({} :: {
	Root: Frame, Viewport: ViewportFrame, Camera: Camera, FitCamera: Camera, World: WorldModel,
	Hint: TextLabel, Message: TextLabel, Tabs: Frame, Rail: Frame, Controls: Frame,
	Parts: { TextButton }, Shots: { Shot }, Selected: number, Key: string?, Serial: number,
	Yaw: number, Pitch: number, Zoom: number, Tween: Tween?, Prop: Model?, Kind: string?,
	Drag: InputObject?, Cursor: Vector2?, Alive: boolean, Life: any, Item: any, Change: any,
}, Inspection))

local WEAPON = {
	Whole = { Name = "Whole", Yaw = 20, Pitch = -9, Fov = 36, Duration = .64 },
	Blade = { Name = "Blade", Yaw = -11, Pitch = -4, Fov = 39, Duration = .48 },
	Guard = { Name = "Guard", Yaw = -26, Pitch = -18, Fov = 32, Duration = .54 },
	Grip = { Name = "Grip", Yaw = 27, Pitch = -7, Fov = 29, Duration = .52 },
	Pommel = { Name = "Pommel", Yaw = 29, Pitch = -4, Fov = 34, Duration = .48 },
}
local ARMOR = {
	Whole = { Name = "Whole", Yaw = -17, Pitch = -4, Fov = 30, Duration = .72 },
	Torso = { Name = "Torso", Yaw = 12, Pitch = -7, Fov = 33, Duration = .55 },
	Arms = { Name = "Arms", Yaw = -30, Pitch = -10, Fov = 34, Duration = .58 },
	Legs = { Name = "Legs", Yaw = 16, Pitch = -19, Fov = 32, Duration = .55 },
}

local function button(parent: Instance, text: string, activate: () -> ()): TextButton
	local b = Hud.make("TextButton", parent, {
		Name = text, Text = text, Font = Enum.Font.GothamMedium, TextColor3 = T.Muted,
		TextSize = 14, BorderSizePixel = 0, BackgroundColor3 = BRASS, BackgroundTransparency = 1,
		AutoButtonColor = false, Selectable = true,
	}) :: TextButton
	local edge = Hud.make("UIStroke", b, { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = BRASS, Enabled = false }) :: UIStroke
	b.SelectionGained:Connect(function() edge.Enabled = true end)
	b.SelectionLost:Connect(function() edge.Enabled = false end)
	b.MouseEnter:Connect(function() b.BackgroundTransparency = .92 end)
	b.MouseLeave:Connect(function() b.BackgroundTransparency = 1 end)
	b.Activated:Connect(activate)
	return b
end

local function has(text: string, words: { string }): boolean
	for _, word in words do
		if string.find(text, word, 1, true) then return true end
	end
	return false
end

local function addShot(self: Stage, lens: Lens, parts: { BasePart })
	if #parts == 0 then return end
	local proxy = self.Item:Add(Instance.new("Model")) :: Model
	for _, p in parts do
		local volume = Instance.new("Part")
		volume.Size, volume.CFrame, volume.Parent = p.Size, p.CFrame, proxy
	end
	local fit = ViewportModel.new(self.Viewport, self.FitCamera)
	fit:SetModel(proxy)
	local shot = table.clone(lens) :: any
	shot.Fit = fit
	table.insert(self.Shots, shot)
end

local function focus(self: Stage, lens: Lens, parts: { BasePart }, match: (BasePart) -> boolean)
	local group = {}
	for _, p in parts do if match(p) then table.insert(group, p) end end
	addShot(self, lens, group)
end

function Inspection.StopShot(self: Stage)
	local tween = self.Tween
	self.Tween = nil
	if tween then tween:Cancel(); tween:Destroy() end
end

function Inspection.FrameShot(self: Stage, smooth: boolean)
	local shot = self.Shots[self.Selected]
	local size = self.Viewport.AbsoluteSize
	if not shot or size.X <= 1 or size.Y <= 1 then return end

	-- Fit a narrower frustum for breathing room. Each shot is fitted at its own camera angle.
	self.FitCamera.FieldOfView = shot.Fov * .86
	shot.Fit:Calibrate()
	local orientation = CFrame.fromOrientation(math.rad(shot.Pitch) + self.Pitch, math.rad(shot.Yaw) + self.Yaw, 0)
	local goal: CFrame = shot.Fit:GetMinimumFitCFrame(orientation)
	if self.Zoom ~= 1 then
		goal += goal.ZVector * self.Zoom * .35
		goal -= goal.ZVector * .35
	end
	self:StopShot()
	if not smooth or Effects.reducedMotion() then
		self.Camera.CFrame, self.Camera.FieldOfView = goal, shot.Fov
		return
	end
	local tween = TweenService:Create(self.Camera, TweenInfo.new(shot.Duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ CFrame = goal, FieldOfView = shot.Fov })
	self.Tween = tween
	tween.Completed:Once(function()
		if self.Tween == tween then self.Tween = nil; tween:Destroy() end
	end)
	tween:Play()
end

function Inspection.Select(self: Stage, index: number)
	local shot = self.Shots[index]
	if not shot then return end
	self.Selected, self.Yaw, self.Pitch, self.Zoom = index, 0, 0, 1
	self.Root:SetAttribute("InspectionShot", shot.Name)
	for i, tab in self.Parts do tab.TextColor3 = if i == index then BRASS else T.Muted end
	local rail = { Position = UDim2.new((index - .5) / #self.Shots, 0, 1, -1), Size = UDim2.new(1 / #self.Shots, -14, 0, 2) }
	if Effects.reducedMotion() then
		Spr.stop(self.Rail)
		self.Rail.Position, self.Rail.Size = rail.Position, rail.Size
	else
		Spr.target(self.Rail, 1, 5, rail)
	end
	self:FrameShot(true)
end

local function clearItem(self: Stage)
	self:StopShot()
	Spr.stop(self.Rail)
	self.Item:Clean()
	self.World:ClearAllChildren()
	table.clear(self.Parts)
	table.clear(self.Shots)
	self.Prop, self.Kind = nil, nil
	self.Controls.Visible, self.Hint.Visible, self.Rail.Visible = false, false, false
	self.Message.Visible = true
end

function Inspection.Clear(self: Stage)
	self.Serial += 1
	self.Key, self.Drag, self.Cursor = nil, nil, nil
	self.Change:Clean()
	clearItem(self)
	self.Message.Text = "Select an item to inspect"
end

local function moveModel(model: Model, lifetime: any, goal: CFrame, duration: number)
	local pose = lifetime:Add(Instance.new("CFrameValue")) :: CFrameValue
	pose.Value = model:GetPivot()
	lifetime:Connect(pose.Changed, function(value) if model.Parent then model:PivotTo(value) end end)
	local tween = TweenService:Create(pose, TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Value = goal })
	lifetime:Add(function() tween:Cancel(); tween:Destroy() end)
	tween:Play()
end

local function playCue(self: Stage, bag: any, name: string, time: number, callback: () -> ())
	Cues.play(self.World, bag, name, time, function(native)
		if not self.Alive then return end
		self.Root:SetAttribute("InspectionCue", name)
		self.Root:SetAttribute("InspectionCueSource", if native then "Marker" else "Timeline")
		callback()
	end)
end

local function install(self: Stage, source: Model, kind: string)
	local model, parts = Scene.build(self.World, source, kind)
	if #parts == 0 then model:Destroy(); self.Message.Text = "Model unavailable"; return end
	self.Prop, self.Kind = model, kind
	if kind == "Armor" then
		addShot(self, ARMOR.Whole, Scene.parts(self.World))
		focus(self, ARMOR.Torso, parts, function(p) return has(tostring(p:GetAttribute("AsuraBone")), { "Torso" }) end)
		focus(self, ARMOR.Arms, parts, function(p) return has(tostring(p:GetAttribute("AsuraBone")), { "Arm", "Hand" }) end)
		focus(self, ARMOR.Legs, parts, function(p) return has(tostring(p:GetAttribute("AsuraBone")), { "Leg", "Foot" }) end)
	else
		addShot(self, WEAPON.Whole, Scene.parts(self.World))
		focus(self, WEAPON.Blade, parts, function(p) return has(p.Name, { "Blade", "HonedEdge", "PointFacet", "ShadowSai", "Rib", "FocusJade", "Censer" }) end)
		focus(self, WEAPON.Guard, parts, function(p) return has(p.Name, { "Guard", "Mouth" }) end)
		focus(self, WEAPON.Grip, parts, function(p) return has(p.Name, { "Grip", "Binding", "Staff", "ChainLink", "WeightedChain" }) end)
		focus(self, WEAPON.Pommel, parts, function(p) return has(p.Name, { "Pommel", "Counterweight" }) end)
	end
	for index, shot in self.Shots do
		local tab = self.Item:Add(button(self.Tabs, shot.Name, function() self:Select(index) end)) :: TextButton
		tab.Size, tab.LayoutOrder = UDim2.new(1 / #self.Shots, 0, 1, 0), index
		table.insert(self.Parts, tab)
	end
	self.Message.Visible, self.Controls.Visible, self.Hint.Visible, self.Rail.Visible = false, true, true, true
	self.Selected, self.Yaw, self.Pitch, self.Zoom = 1, 0, 0, 1
	self:FrameShot(false)
	local resting = model:GetPivot()
	if not Effects.reducedMotion() then
		local _, size = Scene.bounds(parts)
		if kind == "Weapon" then
			model:PivotTo(resting * CFrame.new(0, -.08, size.X * .24))
			playCue(self, self.Item, "Draw", .08, function() moveModel(model, self.Item, resting, .34) end)
		else
			model:PivotTo(CFrame.Angles(0, math.rad(-13), 0) * resting)
			moveModel(model, self.Item, resting, .42)
		end
		self.Camera.CFrame *= CFrame.new(0, 0, math.clamp(size.Magnitude * .22, .25, 1.2))
	end
	self:Select(1)
end

function Inspection.Show(self: Stage, kind: string, id: string)
	local key = kind .. "/" .. id
	if self.Key == key or not self.Alive then return end
	self.Serial += 1
	local serial = self.Serial
	self.Key = key
	self.Change:Clean()
	local function load()
		if not self.Alive or self.Serial ~= serial then return end
		clearItem(self)
		self.Message.Text = "Loading model…"
		if id == "Unarmed" or id == "None" then
			self.Message.Text = if id == "None" then "No armour equipped" else "Fighting barehanded"
			return
		end
		local function find(): Model?
			local library = Assets:FindFirstChild("ItemInspectionModels")
			local group = library and library:FindFirstChild(kind)
			local model = group and group:FindFirstChild(id)
			return if model and model:IsA("Model") then model else nil
		end
		local source = find()
		if source then install(self, source, kind); return end
		local timeout = task.delay(6, function()
			if self.Serial == serial and self.Alive then self.Message.Text = "Model unavailable" end
		end)
		self.Change:Add(function() if coroutine.status(timeout) == "suspended" then task.cancel(timeout) end end)
		local watcher: RBXScriptConnection?
		watcher = Assets.DescendantAdded:Connect(function(descendant)
			if descendant.Name ~= id then return end
			local ready = find()
			if self.Serial == serial and self.Alive and ready then
				if watcher then watcher:Disconnect() end
				if coroutine.status(timeout) == "suspended" then task.cancel(timeout) end
				install(self, ready, kind)
			end
		end)
		self.Change:Add(watcher)
	end
	local previous = self.Prop
	if previous and self.Kind == "Weapon" and not Effects.reducedMotion() then
		playCue(self, self.Change, "Sheath", .055, function()
			if self.Serial == serial then moveModel(previous, self.Change, previous:GetPivot() * CFrame.new(0, -.15, .78), .19) end
		end)
		local delay = task.delay(.28, load)
		self.Change:Add(function() if coroutine.status(delay) == "suspended" then task.cancel(delay) end end)
	else
		load()
	end
end

function Inspection.new(parent: Instance, properties: { [string]: any }?): Stage
	local root = Hud.make("Frame", parent, {
		Name = "ItemInspection", Size = UDim2.new(1, 0, 0, 320), BackgroundColor3 = INK,
		BorderSizePixel = 0, ClipsDescendants = true,
	}) :: Frame
	for key, value in properties or {} do (root :: any)[key] = value end
	local field = Hud.make("Frame", root, {
		Name = "StageLight", Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(73, 56, 43), BorderSizePixel = 0,
	})
	Hud.make("UIGradient", field, { Rotation = 78, Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(.37, .43), NumberSequenceKeypoint.new(1, 1),
	}) })
	local viewport = Hud.make("ViewportFrame", root, {
		Name = "Model", Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 1, -96),
		BackgroundTransparency = 1, LightColor = Color3.fromRGB(255, 230, 190),
		Ambient = Color3.fromRGB(130, 137, 158), LightDirection = Vector3.new(-.7, -1, -.56), Active = true,
	}) :: ViewportFrame
	local camera = Hud.make("Camera", viewport, { FieldOfView = 36 }) :: Camera
	viewport.CurrentCamera = camera
	local world = Hud.make("WorldModel", viewport, {}) :: WorldModel
	local hint = Hud.label(root, "DRAG TO ORBIT", 10, Enum.Font.GothamMedium, T.Muted, {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -52), Size = UDim2.new(1, -24, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Visible = false,
	})
	local message = Hud.label(root, "Select an item to inspect", 15, T.BodyFont, T.Muted, { Size = UDim2.fromScale(1, 1) })
	local shots = Hud.make("Frame", root, {
		Name = "Shots", AnchorPoint = Vector2.new(.5, 1), Position = UDim2.new(.5, 0, 1, -7),
		Size = UDim2.new(1, -20, 0, 46), BackgroundTransparency = 1,
	})
	Hud.make("Frame", shots, { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = T.Edge, BackgroundTransparency = .48, BorderSizePixel = 0 })
	local tabs = Hud.make("Frame", shots, { Name = "Focus", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }) :: Frame
	Hud.make("UIListLayout", tabs, { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder })
	local rail = Hud.make("Frame", shots, { Name = "ActiveShot", AnchorPoint = Vector2.new(.5, 1),
		BackgroundColor3 = BRASS, BorderSizePixel = 0, Visible = false, ZIndex = 2 }) :: Frame
	local controls = Hud.make("Frame", root, {
		Name = "ViewControls", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -9, 0, 2),
		Size = UDim2.fromOffset(176, 44), BackgroundTransparency = 1, Visible = false, ZIndex = 2,
	}) :: Frame
	Hud.make("UIListLayout", controls, { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder })
	local life = Trove.new()
	local self: Stage = setmetatable({
		Root = root, Viewport = viewport, Camera = camera, World = world, FitCamera = life:Add(Instance.new("Camera")),
		Hint = hint, Message = message, Tabs = tabs, Rail = rail, Controls = controls, Parts = {}, Shots = {},
		Selected = 1, Serial = 0, Yaw = 0, Pitch = 0, Zoom = 1, Alive = true, Life = life, Item = Trove.new(), Change = Trove.new(),
	}, Inspection)
	local function changeZoom(multiplier: number)
		self.Zoom = math.clamp(self.Zoom * multiplier, .32, 2.8)
		self:FrameShot(false)
	end
	for order, option in {
		{ "<", function() self.Yaw -= math.pi / 10; self:FrameShot(true) end },
		{ ">", function() self.Yaw += math.pi / 10; self:FrameShot(true) end },
		{ "-", function() changeZoom(1.28) end },
		{ "+", function() changeZoom(1 / 1.28) end },
	} do
		local control = button(controls, option[1] :: string, option[2] :: () -> ())
		control.Size, control.LayoutOrder, control.ZIndex = UDim2.fromOffset(44, 44), order, 3
	end
	life:Connect(viewport.InputBegan, function(input)
		if not self.Controls.Visible or self.Drag then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self.Drag, self.Cursor = input, Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	life:Connect(viewport.InputChanged, function(input)
		if self.Controls.Visible and input.UserInputType == Enum.UserInputType.MouseWheel then changeZoom(1.14 ^ -input.Position.Z) end
	end)
	life:Connect(Input.InputChanged, function(input)
		if not self.Drag or not self.Cursor then return end
		if input ~= self.Drag and not (self.Drag.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement) then return end
		local point = Vector2.new(input.Position.X, input.Position.Y)
		local delta = point - self.Cursor
		self.Cursor = point
		self.Yaw -= delta.X * .009
		self.Pitch = math.clamp(self.Pitch - delta.Y * .006, -1, 1)
		self:FrameShot(false)
	end)
	life:Connect(Input.InputEnded, function(input)
		if input == self.Drag then self.Drag, self.Cursor = nil, nil end
	end)
	life:Connect(viewport:GetPropertyChangedSignal("AbsoluteSize"), function() self:FrameShot(false) end)
	root.Destroying:Once(function()
		self.Alive, self.Serial = false, self.Serial + 1
		self:StopShot()
		Spr.stop(self.Rail)
		self.Change:Destroy()
		self.Item:Destroy()
		life:Destroy()
	end)
	return self
end

function Inspection.Destroy(self: Stage)
	if self.Alive then self.Root:Destroy() end
end

return Inspection
