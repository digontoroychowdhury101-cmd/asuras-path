--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/WorldMapController
-- The M world map (open-world brief section 12). A UiWindow modal: M or the Map blossom toggles it,
-- M / Escape / pad B close it, and it claims input as the "Map" menu owner so movement, combat and
-- camera look stop while it is up and return the moment it closes (also on death, leaving the open
-- world, Respite opening and Destroy). The world keeps running. Only exists beyond the lobby.
-- The picture is painted from Overworld (WorldMap.paintRow), time-sliced over a few seconds into an
-- EditableImage; where that API is unavailable a 96 x 96 grid of Frames carries the same colours.
-- Markers: region names, discovered altars (never retired ones), sighted landmarks, visible POIs of
-- the player's level, the player arrow (camera heading) and one placed waypoint, which the compass
-- shows through WaypointBearing.
local AssetService = game:GetService("AssetService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath"):WaitForChild("Shared")
local Overworld = require(Shared:WaitForChild("Overworld") :: ModuleScript) :: any
local WorldMap = require(Shared:WaitForChild("WorldMap") :: ModuleScript)
local InputMap = require(Shared:WaitForChild("InputMap") :: ModuleScript)
local HudKit = require(script.Parent:WaitForChild("HudKit") :: ModuleScript)
local UiKit = require(script.Parent:WaitForChild("UiKit") :: ModuleScript)
local UiWindow = require(script.Parent:WaitForChild("UiWindow") :: ModuleScript)
local Visibility = require(script.Parent:WaitForChild("HudVisibility") :: ModuleScript)
local Sakura = require(script.Parent:WaitForChild("SakuraKit") :: ModuleScript)

local Controller = {}
Controller.__index = Controller
local C = Sakura.Colors
local T = UiKit.Theme

-- Customization ------------------------------------------------------------------------------
local WINDOW_SIZE = Vector2.new(1040, 660)
local RES = WorldMap.Resolution
local BUDGET_CLOSED, BUDGET_OPEN = 0.003, 0.009 -- seconds of raster work per frame (closed / open)
local GRID, GRID_BATCH = 96, 450 -- fallback grid edge and Frames built per frame
local OPEN_ZOOM = 2.2
local WHEEL_STEP, BUTTON_STEP = 1.25, 1.6
local LAYOUT = WorldMap.Layout -- control rects and the marker's safe inset come from the same constants (WorldMap.insetFor)
local FOLLOW_MARGIN = 16 -- the arrow is pulled back into the pane when it comes this close to the safe edge
local CLICK_SLOP = 6 -- pixels of drag that still count as a click
local WAYPOINT_GRAB = 14 -- pane pixels around the waypoint that a click clears
local ARRIVED = 30 -- studs from the waypoint at which it clears itself
local BACK = "AsuraMapBack"
local TOGGLE: { [Enum.KeyCode]: boolean } = {}
for _, name in (InputMap.get("Map") :: any).Keys do
	TOGGLE[(Enum.KeyCode :: any)[name]] = true
end

type Label = { Gui: TextLabel, Min: number }
export type WorldMapView = typeof(setmetatable({} :: {
	Input: any, Ui: any, State: any, Window: UiWindow.Window, Pane: Frame, Canvas: Frame, Image: ImageLabel, Editable: any?, Buf: buffer,
	Row: number, Done: boolean, Grid: { Frame }?, GridNext: number, Status: TextLabel, Hint: TextLabel, LevelLabel: TextLabel,
	View: WorldMap.View, Dynamic: { Instance }, Labels: { Label }, Arrow: TextLabel, Pin: Frame, Waypoint: { X: number, Z: number }?,
	Drag: { Input: InputObject, Start: Vector2, Last: Vector2, Moved: number }?, Level: string, Probe: number, Dirty: boolean,
	Lobby: boolean, Bin: { any }, Zoomed: TextButton, PauseGrace: boolean, Legend: Frame, Last: { X: number, Z: number }?,
}, Controller))

-- Pointer in GUI space (AsuraHUD ignores the inset, so mouse location already matches; touch needs it added).
local function cursor(input: InputObject): Vector2
	if input.UserInputType == Enum.UserInputType.Touch then
		return Vector2.new(input.Position.X, input.Position.Y) + GuiService:GetGuiInset()
	end
	return UserInputService:GetMouseLocation()
end

local function parse(value: any): { [string]: boolean }
	local set: { [string]: boolean } = {}
	if type(value) == "string" then
		for id in string.gmatch(value, "[^,]+") do
			set[id] = true
		end
	end
	return set
end

local function swatch(parent: Instance, color: Color3, shape: string, order: number): GuiObject
	if shape == "arrow" then
		return HudKit.label(parent, "▲", 14, Enum.Font.GothamBold, color, { Size = UDim2.fromOffset(12, 16) })
	end
	local f = HudKit.make("Frame", parent, {
		LayoutOrder = order, Size = UDim2.fromOffset(12, 12), BackgroundColor3 = color, BorderSizePixel = 0,
		Rotation = if shape == "diamond" then 45 else 0,
	}) :: Frame
	if shape == "dot" or shape == "ring" then HudKit.make("UICorner", f, { CornerRadius = UDim.new(1, 0) }) end
	if shape == "ring" then
		f.BackgroundTransparency = 1
		HudKit.make("UIStroke", f, { Color = color, Thickness = 2 })
	end
	return f
end

function Controller.new(input: any, ui: any, state: any): WorldMapView
	local window = UiWindow.new(ui.Gui, "WorldMap", "World Map", "", WINDOW_SIZE, function() end)
	local pane = HudKit.make("Frame", window.Body, {
		Name = "Pane", Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Ink, ClipsDescendants = true, Active = true,
	}) :: Frame
	HudKit.make("UIStroke", pane, { Color = T.Edge, Thickness = 1, Transparency = 0.2 })
	local canvas = HudKit.make("Frame", pane, { Name = "Canvas", BackgroundTransparency = 1, Size = UDim2.fromOffset(100, 100) }) :: Frame
	local image = HudKit.make("ImageLabel", canvas, { Name = "Raster", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 1 }) :: ImageLabel
	local editable: any = nil
	pcall(function() -- EditableImage needs the experience setting; without it the grid below is used
		local e = (AssetService :: any):CreateEditableImage({ Size = Vector2.new(RES, RES) })
		image.ImageContent = (Content :: any).fromObject(e)
		editable = e
	end)

	local self = setmetatable({
		Input = input, Ui = ui, State = state, Window = window, Pane = pane, Canvas = canvas, Image = image, Editable = editable,
		Buf = buffer.create(RES * RES * 4), Row = 0, Done = false, Grid = nil, GridNext = 0,
		View = { W = 800, H = 500, Zoom = OPEN_ZOOM, U = 0.5, V = 0.5, Inset = WorldMap.insetFor(800, 500) }, Dynamic = {}, Labels = {}, Waypoint = nil, Drag = nil,
		Level = "Surface", Probe = 0, Dirty = true, Lobby = true, Bin = {}, PauseGrace = false,
	} :: any, Controller) :: any
	window.Close.Activated:Connect(function() self:Close() end)

	-- Static layer: region names straight from Overworld.Regions[...].Name.
	for _, region in WorldMap.regionLabels() do
		local small = region.Id == "AshColosseum"
		HudKit.label(canvas, string.upper(region.Name), if small then 11 else 18, HudKit.TitleFont, C.Ivory, {
			Name = "Region_" .. region.Id, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(region.U, region.V),
			Size = UDim2.fromOffset(240, 22), ZIndex = 3, TextStrokeTransparency = 0.15, TextTransparency = 0.12,
		})
	end
	self.Arrow = HudKit.label(canvas, "▲", 24, Enum.Font.GothamBold, C.Ivory, {
		Name = "You", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(26, 26), ZIndex = 9, TextStrokeTransparency = 0,
		TextStrokeColor3 = C.Ink,
	})
	self.Pin = HudKit.make("Frame", canvas, {
		Name = "Waypoint", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = T.Ink,
		BackgroundTransparency = 0.16, BorderSizePixel = 0, ZIndex = 8, Visible = false,
	}) :: Frame
	HudKit.make("UICorner", self.Pin, { CornerRadius = UDim.new(1, 0) })
	HudKit.make("UIStroke", self.Pin, { Color = C.Qi, Thickness = 2 })

	-- Overlay (pane space, not zoomed): zoom buttons, legend, hint and chart progress.
	local tools = HudKit.make("Frame", pane, { Name = "Tools", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -LAYOUT.ToolsMargin, 0, LAYOUT.ToolsMargin), Size = UDim2.fromOffset(LAYOUT.ToolsW, LAYOUT.ToolsH),
		BackgroundTransparency = 1, ZIndex = 20 }) :: Frame
	HudKit.make("UIListLayout", tools, { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
	local function tool(text: string, order: number, press: () -> ()): TextButton
		local b = UiKit.button(tools, text, "Secondary", press)
		b.LayoutOrder, b.Size, b.TextSize, b.ZIndex = order, UDim2.fromOffset(56, 44), 22, 20
		return b
	end
	local function zoom(factor: number)
		local v = self.View
		WorldMap.zoomAbout(v, factor, v.W / 2, v.H / 2)
	end
	self.Zoomed = tool("+", 1, function() zoom(BUTTON_STEP) end)
	tool("−", 2, function() zoom(1 / BUTTON_STEP) end)
	local you = tool("Centre", 3, function() self:Centre() end)
	you.TextSize = 14

	local legend = HudKit.panel(pane, "Legend", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, LAYOUT.LegendMargin, 1, -LAYOUT.LegendMargin), Size = UDim2.fromOffset(LAYOUT.LegendW, LAYOUT.LegendH), ZIndex = 20, BackgroundTransparency = 0.1, Active = true })
	HudKit.make("UIPadding", legend, { PaddingLeft = UDim.new(0, 8), PaddingTop = UDim.new(0, 6) })
	HudKit.make("UIListLayout", legend, { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder })
	local rows: { { Text: string, Color: Color3, Shape: string } } = {
		{ Text = "You", Color = C.Ivory, Shape = "arrow" }, { Text = "Incense altar", Color = C.Gold, Shape = "diamond" },
		{ Text = "Landmark", Color = C.Ivory, Shape = "square" }, { Text = "Point of interest", Color = C.Sakura, Shape = "dot" },
		{ Text = "Waypoint", Color = C.Qi, Shape = "ring" },
	}
	for order, row in rows do
		local line = HudKit.make("Frame", legend, { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, ZIndex = 21 }) :: Frame
		local s = swatch(line, row.Color, row.Shape, order)
		s.AnchorPoint, s.Position, s.ZIndex = Vector2.new(0, 0.5), UDim2.fromOffset(0, 8), 21
		HudKit.label(line, row.Text, 14, HudKit.BodyFont, T.Ivory, { Position = UDim2.fromOffset(20, 0), Size = UDim2.new(1, -20, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21 })
	end
	self.Legend = legend
	self.LevelLabel = HudKit.label(legend, "", 14, HudKit.BodyFont, T.Gold, { LayoutOrder = 9, Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21 })
	self.Hint = HudKit.label(pane, "", 14, HudKit.BodyFont, T.Ivory, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.new(0.6, 0, 0, 30),
		TextScaled = true, TextWrapped = true, ZIndex = 20, TextStrokeTransparency = 0.15,
	})
	HudKit.make("UITextSizeConstraint", self.Hint, { MinTextSize = 11, MaxTextSize = 14 })
	self.Status = HudKit.label(pane, "", 15, HudKit.BodyFont, T.Gold, {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(260, 22), ZIndex = 20, TextStrokeTransparency = 0.2,
	})

	-- Drag pans; a press that barely moves is a click (waypoint). Wheel zooms about the pointer.
	pane.InputBegan:Connect(function(event: InputObject)
		if self.Drag == nil and (event.UserInputType == Enum.UserInputType.MouseButton1 or event.UserInputType == Enum.UserInputType.Touch) then
			local at = cursor(event)
			self.Drag = { Input = event, Start = at, Last = at, Moved = 0 }
		end
	end)
	table.insert(self.Bin, UserInputService.InputChanged:Connect(function(event: InputObject)
		local drag = self.Drag
		if drag and (event.UserInputType == Enum.UserInputType.MouseMovement or event == drag.Input) then
			local at = cursor(event)
			WorldMap.pan(self.View, at.X - drag.Last.X, at.Y - drag.Last.Y)
			drag.Moved = math.max(drag.Moved, (at - drag.Start).Magnitude)
			drag.Last = at
		elseif event.UserInputType == Enum.UserInputType.MouseWheel and UiWindow.isOpen(self.Window) then
			local at = UserInputService:GetMouseLocation() - pane.AbsolutePosition
			if at.X >= 0 and at.Y >= 0 and at.X <= pane.AbsoluteSize.X and at.Y <= pane.AbsoluteSize.Y then
				WorldMap.zoomAbout(self.View, if event.Position.Z > 0 then WHEEL_STEP else 1 / WHEEL_STEP, at.X, at.Y)
			end
		end
	end))
	table.insert(self.Bin, UserInputService.InputEnded:Connect(function(event: InputObject)
		local drag = self.Drag
		if drag and (event == drag.Input or (event.UserInputType == Enum.UserInputType.MouseButton1 and drag.Input.UserInputType == Enum.UserInputType.MouseButton1)) then
			self.Drag = nil
			if drag.Moved < CLICK_SLOP then self:Click(drag.Start - pane.AbsolutePosition) end
		end
	end))

	table.insert(self.Bin, UserInputService.InputBegan:Connect(function(event: InputObject, processed: boolean)
		if event.KeyCode == Enum.KeyCode.Escape then
			self:Close() -- the engine menu opens as well; Escape never reaches the Respite window
		elseif not processed and TOGGLE[event.KeyCode] and UserInputService:GetFocusedTextBox() == nil then
			self:Toggle()
		end
	end))
	table.insert(self.Bin, GuiService.MenuOpened:Connect(function() self:Close() end))
	local player = Players.LocalPlayer
	for _, attribute in { "AsuraAltars", "AsuraDiscoveries" } do
		table.insert(self.Bin, player:GetAttributeChangedSignal(attribute):Connect(function() self.Dirty = true end))
	end
	table.insert(self.Bin, pane:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:Fit() end))
	ui.OpenMap = function() self:Open(true) end -- Respite entry (gamepad and touch have no free button)
	return self
end

-- Pane size into the view, then the canvas into the pane.
function Controller.Fit(self: WorldMapView)
	local size = self.Pane.AbsoluteSize
	local v = self.View
	local resized = size.X > 1 and size.Y > 1 and (v.W ~= size.X or v.H ~= size.Y)
	if resized then
		v.W, v.H = size.X, size.Y
	end
	v.Inset = WorldMap.insetFor(v.W, v.H) -- the real Tools/Legend rects at this size, never a fixed strip
	WorldMap.clampView(v)
	-- A new size moves the controls and the safe area: pull the arrow out from under them (a manual pan never resizes).
	local last = self.Last
	if resized and last and not WorldMap.markerInside(v, last.X, last.Z, 0) then
		WorldMap.follow(v, last.X, last.Z, 0)
	end
	local left, top, edge = WorldMap.layout(v)
	self.Canvas.Position, self.Canvas.Size = UDim2.fromOffset(left, top), UDim2.fromOffset(edge, edge)
	for _, label in self.Labels do
		label.Gui.Visible = v.Zoom >= label.Min
	end
	self.Legend.Visible = v.H >= LAYOUT.LegendMinHeight
end

function Controller.Centre(self: WorldMapView)
	local own = self.State:Own()
	local root = own and own.Root
	local v = self.View
	if root then
		WorldMap.centreOn(v, root.Position.X, root.Position.Z)
		self.Last = { X = root.Position.X, Z = root.Position.Z }
	else
		WorldMap.clampView(v)
	end
end

-- Rebuilds the markers that depend on discoveries and level.
function Controller.Refresh(self: WorldMapView)
	for _, item in self.Dynamic do item:Destroy() end
	table.clear(self.Dynamic)
	table.clear(self.Labels)
	local player = Players.LocalPlayer
	local found = parse(player:GetAttribute("AsuraDiscoveries"))
	local own = self.State:Own()
	local root = own and own.Root
	local function add(shape: string, color: Color3, size: number, x: number, z: number, name: string, minZoom: number, layer: number)
		local u, v = Overworld.toMap(x, z)
		local mark = HudKit.make("Frame", self.Canvas, {
			Name = "Mark_" .. name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(u, v), Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = color, BorderSizePixel = 0, Rotation = if shape == "diamond" then 45 else 0, ZIndex = layer,
		}) :: Frame
		if shape == "dot" then HudKit.make("UICorner", mark, { CornerRadius = UDim.new(1, 0) }) end
		HudKit.make("UIStroke", mark, { Color = C.Ink, Thickness = 1 })
		table.insert(self.Dynamic, mark)
		local text = HudKit.label(self.Canvas, name, 12, HudKit.BodyFont, C.Ivory, {
			Name = "Name_" .. name, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(u, 0, v, size * 0.5 + 2), Size = UDim2.fromOffset(160, 14),
			ZIndex = layer, TextStrokeTransparency = 0.15, Visible = false,
		})
		table.insert(self.Dynamic, text)
		table.insert(self.Labels, { Gui = text, Min = minZoom })
	end
	for _, altar in WorldMap.discoveredAltars(parse(player:GetAttribute("AsuraAltars")), Overworld.Altars, Overworld.RetiredAltars) do
		add("diamond", C.Gold, 13, altar.Placement.X, altar.Placement.Z, altar.Name, 2, 6)
	end
	if root then
		for _, landmark in WorldMap.visibleLandmarks(Overworld.Landmarks, root.Position.X, root.Position.Z, found) do
			add("square", C.Ivory, 10, landmark.Position.X, landmark.Position.Z, landmark.Id, 2.5, 5)
		end
	end
	for _, poi in WorldMap.visiblePois(Overworld.POIs, self.Level, found) do
		add("dot", C.Sakura, 8, poi.Position.X, poi.Position.Z, poi.Id, 4, 4)
	end
	self.LevelLabel.Text = "Level: " .. self.Level
	self.Dirty = false
end

-- Raster ---------------------------------------------------------------------------------------

local function flush(self: WorldMapView, from: number, to: number)
	if not self.Editable or to <= from then return end
	local count = to - from
	local part = buffer.create(count * RES * 4)
	buffer.copy(part, 0, self.Buf, from * RES * 4, count * RES * 4)
	local ok = pcall(function() self.Editable:WritePixelsBuffer(Vector2.new(0, from), Vector2.new(RES, count), part) end)
	if not ok then -- the image stopped answering: finish through the grid instead
		self.Editable = nil
		self.Image.Visible = false
	end
end

local function stepRaster(self: WorldMapView, budget: number)
	if not self.Done and self.Row < RES then
		local started, first = os.clock(), self.Row
		while self.Row < RES and os.clock() - started < budget do
			WorldMap.paintRow(self.Buf, RES, self.Row)
			self.Row += 1
		end
		if self.Row >= RES then
			WorldMap.paintRoutes(self.Buf, RES)
			first = 0 -- roads and rivers touch rows painted earlier
		end
		flush(self, first, self.Row)
		self.Status.Text = if self.Row >= RES then "" else string.format("Charting the land… %d%%", math.floor(self.Row / RES * 100))
	end
	if self.Row >= RES and not self.Editable then -- grid fallback, a few hundred Frames per frame
		if not self.Grid then
			self.Grid = {}
			self.Image.Visible = false
		end
		local grid = self.Grid :: { Frame }
		local last = math.min(self.GridNext + GRID_BATCH, GRID * GRID)
		for i = self.GridNext, last - 1 do
			local col, row = i % GRID, i // GRID
			local r, g, b = WorldMap.readPixel(self.Buf, RES, math.min(RES - 1, (col * RES) // GRID + RES // (2 * GRID)), math.min(RES - 1, (row * RES) // GRID + RES // (2 * GRID)))
			grid[#grid + 1] = HudKit.make("Frame", self.Canvas, {
				Name = "Cell", Position = UDim2.fromScale(col / GRID, row / GRID), Size = UDim2.fromScale(1 / GRID + 0.0006, 1 / GRID + 0.0006),
				BackgroundColor3 = Color3.fromRGB(r, g, b), BorderSizePixel = 0, ZIndex = 1,
			}) :: Frame
		end
		self.GridNext = last
		self.Done = last >= GRID * GRID
		self.Status.Text = if self.Done then "" else "Charting the land…"
	elseif self.Row >= RES then
		self.Done = true
	end
end

-- Opening, closing ----------------------------------------------------------------------------

local function busy(self: WorldMapView, fromMenu: boolean): boolean
	for owner in self.Input.MenuOwners do
		if owner ~= "Map" and not (fromMenu and owner == "Pause") then
			return true
		end
	end
	return GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() ~= nil
end

function Controller.Open(self: WorldMapView, fromMenu: boolean?)
	if UiWindow.isOpen(self.Window) or self.Lobby or not Visibility.of(self.Ui).Guidance or busy(self, fromMenu == true) then
		return
	end
	self.Input:SetMenu(true, "Map")
	self.PauseGrace = fromMenu == true -- Respite is still fading out when it hands over
	self.View.Zoom = OPEN_ZOOM
	UiWindow.open(self.Window)
	self:Fit() -- real pane size and inset first, so Centre works on them, not on the previous open's
	self:Centre()
	self:Refresh()
	local device = self.Input.Device
	self.Hint.Text = if device == "Keyboard" then string.format("Drag to pan · Click to place a waypoint · [%s] close", InputMap.label("Map", device))
		elseif device == "Gamepad" then "Zoom with + or − · [B] close" else "Drag to pan · Tap to place a waypoint"
	self:Fit()
	ContextActionService:BindActionAtPriority(BACK, function(_: string, state: Enum.UserInputState): Enum.ContextActionResult
		if state == Enum.UserInputState.Begin then self:Close() end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 2, Enum.KeyCode.ButtonB)
	if UserInputService.GamepadEnabled then GuiService.SelectedObject = self.Zoomed end
end

-- Always releases input, even if the window is already fading, so no path can strand the player.
function Controller.Close(self: WorldMapView)
	if not UiWindow.isOpen(self.Window) and not self.Input.MenuOwners.Map then return end
	ContextActionService:UnbindAction(BACK)
	self.Drag = nil
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.Window.Root) then GuiService.SelectedObject = nil end
	self.Input:SetMenu(false, "Map")
	if UiWindow.isOpen(self.Window) then UiWindow.close(self.Window) end
end

function Controller.Toggle(self: WorldMapView)
	if UiWindow.isOpen(self.Window) then self:Close() else self:Open() end
end

-- Click on the pane (pane pixels): place or move the waypoint, or clear it when the click lands on it.
function Controller.Click(self: WorldMapView, at: Vector2)
	local v = self.View
	if self.Waypoint then
		local px, py = WorldMap.toPane(v, self.Waypoint.X, self.Waypoint.Z)
		if (Vector2.new(px, py) - at).Magnitude <= WAYPOINT_GRAB then
			self.Waypoint = nil
			return
		end
	end
	local x, z = WorldMap.fromPane(v, at.X, at.Y)
	local f = Overworld.Frame
	if x >= f.MinX and x <= f.MaxX and z >= f.MinZ and z <= f.MaxZ then
		self.Waypoint = { X = x, Z = z }
	end
end

-- Bearing from the player to the waypoint (compass convention), nil without one.
function Controller.WaypointBearing(self: WorldMapView): number?
	local way = self.Waypoint
	local own = self.State:Own()
	local root = own and own.Root
	if not way or not root then return nil end
	return WorldMap.waypointBearing(root.Position.X, root.Position.Z, way.X, way.Z)
end

function Controller.Update(self: WorldMapView, dt: number)
	local own = self.State:Own()
	local root = own and own.Root
	self.Lobby = WorldMap.isLobby(Players.LocalPlayer:GetAttribute("AsuraRegion"), root and root.Position.X, root and root.Position.Z)
	local open = UiWindow.isOpen(self.Window)
	local paused = self.Input.MenuOwners.Pause ~= nil
	if not paused then self.PauseGrace = false end
	if open and (self.Lobby or not Visibility.of(self.Ui).Guidance or (paused and not self.PauseGrace)) then
		self:Close() -- death, dialogue, a lit altar, Respite, or back to the lobby
		open = false
	end
	if self.Lobby then return end
	stepRaster(self, if open then BUDGET_OPEN else BUDGET_CLOSED)
	if not root then return end
	local position = root.Position
	self.Probe -= dt
	if self.Probe <= 0 then
		self.Probe = 0.5
		local level = WorldMap.levelAt(position.Y, Overworld.heightAt(position.X, position.Z))
		if level ~= self.Level then self.Level, self.Dirty = level, true end
	end
	local way = self.Waypoint
	if way and (position.X - way.X) ^ 2 + (position.Z - way.Z) ^ 2 < ARRIVED * ARRIVED then
		self.Waypoint, way = nil, nil
	end
	if not open then return end
	if self.Dirty then self:Refresh() end
	-- Follow: when the player's own movement carries the arrow out of the safe area, pan just enough to bring it back.
	-- A manual pan that left the arrow outside is left alone (it was already outside before the player moved).
	local last = self.Last
	if last and self.Drag == nil and WorldMap.markerInside(self.View, last.X, last.Z, FOLLOW_MARGIN)
		and not WorldMap.markerInside(self.View, position.X, position.Z, FOLLOW_MARGIN) then
		WorldMap.follow(self.View, position.X, position.Z, FOLLOW_MARGIN)
	end
	self.Last = { X = position.X, Z = position.Z }
	self:Fit()
	local u, v = Overworld.toMap(position.X, position.Z)
	local camera = Workspace.CurrentCamera
	local look = if camera then camera.CFrame.LookVector else Vector3.new(0, 0, -1)
	self.Arrow.Position = UDim2.fromScale(math.clamp(u, 0, 1), math.clamp(v, 0, 1))
	self.Arrow.Rotation = WorldMap.arrowRotation(WorldMap.bearing(look.X, look.Z))
	self.Pin.Visible = way ~= nil
	if way then
		local wu, wv = Overworld.toMap(way.X, way.Z)
		self.Pin.Position = UDim2.fromScale(wu, wv)
	end
end

function Controller.Destroy(self: WorldMapView)
	self:Close()
	for _, item in self.Bin do
		(item :: RBXScriptConnection):Disconnect()
	end
	table.clear(self.Bin)
	self.Ui.OpenMap = nil
	if self.Editable then pcall(function() self.Editable:Destroy() end) end
	self.Window.Root:Destroy()
end

return Controller
