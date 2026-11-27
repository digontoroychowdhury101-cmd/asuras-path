--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/SakuraMinimap
-- The lobby radar shows the walked route, nearby fighters and altars. Outside the lobby its
-- controls fold into the navigation row and the full map takes over.
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath")
local World = require(Shared:WaitForChild("Shared"):WaitForChild("WorldDefinitions") :: ModuleScript) :: any
local HudKit = require(script.Parent:WaitForChild("HudKit") :: ModuleScript)
local Sakura = require(script.Parent:WaitForChild("SakuraKit") :: ModuleScript)
local RouteLayer = require(script.Parent:WaitForChild("MinimapRoute") :: ModuleScript)

local Map = {}
local C = Sakura.Colors

-- Customization ------------------------------------------------------------------------------
local DIAMETER = 150
local RANGE = 140 -- studs from centre to rim
local DOT_POOL = 24
local ALTAR_POOL = 8

local CLUSTER = Vector2.new(35, 35) -- first blossom of the radar-less row, in root pixels
local CLUSTER_STEP = 38
local TOUCH_TARGET = 44

-- Slot is the blossom's place in the radar-less row; MapOnly blossoms exist only without the radar.
export type Button = { Glyph: string, Angle: number, Press: () -> (), Slot: number, MapOnly: boolean? }
type Blossom = { Holder: GuiObject, Button: TextButton, Rim: UDim2, Row: UDim2, MapOnly: boolean }
export type View = { Root: Frame, Disc: Frame, Letters: { [number]: TextLabel }, Dots: { Frame }, Altars: { Frame }, Region: TextLabel, State: any,
	Route: RouteLayer.View, Blossoms: { Blossom }, Radar: boolean, Touch: boolean }

local function dot(parent: Instance, size: number, color: Color3, diamond: boolean): Frame
	local d = HudKit.make("Frame", parent, {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(size, size), BackgroundColor3 = color,
		BorderSizePixel = 0, Rotation = if diamond then 45 else 0, Visible = false, ZIndex = 3,
	}) :: Frame
	if not diamond then HudKit.make("UICorner", d, { CornerRadius = UDim.new(1, 0) }) end
	HudKit.make("UIStroke", d, { Color = C.Ink, Thickness = 1 })
	return d
end

function Map.new(gui: ScreenGui, state: any, buttons: { Button }): View
	local root = HudKit.make("Frame", gui, {
		Name = "Minimap", Position = UDim2.fromOffset(20, 66), Size = UDim2.fromOffset(DIAMETER + 40, DIAMETER + 40), BackgroundTransparency = 1,
	}) :: Frame
	root.Destroying:Once(HudKit.bindScale(root, 0.82))
	local centre = UDim2.fromOffset((DIAMETER + 40) / 2, (DIAMETER + 40) / 2)
	local disc = Sakura.medallion(root, DIAMETER, centre)
	disc.BackgroundTransparency = 0.23
	for _, rotation in { 0, 90 } do -- faint crosshair
		HudKit.make("Frame", disc, {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -24, 0, 1), Rotation = rotation,
			BackgroundColor3 = C.Gold, BackgroundTransparency = 0.85, BorderSizePixel = 0,
		})
	end
	local letters: { [number]: TextLabel } = {}
	for i, text in { "N", "E", "S", "W" } do
		letters[(i - 1) * 90] = HudKit.label(disc, text, if text == "N" then 15 else 12, HudKit.BodyFont, if text == "N" then C.Gold else C.Ivory, {
			AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(16, 16), ZIndex = 4, TextStrokeTransparency = 0.3,
		})
	end
	HudKit.label(disc, "▲", 15, Enum.Font.GothamBold, C.Ivory, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(20, 20), ZIndex = 5, TextStrokeTransparency = 0.2,
	})
	local route = RouteLayer.new(disc, DIAMETER)
	local dots, altars = {}, {}
	for i = 1, DOT_POOL do dots[i] = dot(disc, 7, C.Crimson, false) end
	for i = 1, ALTAR_POOL do altars[i] = dot(disc, 8, C.Gold, true) end
	local region = HudKit.label(disc, "", 12, HudKit.TitleFont, C.Ivory, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.66, 0), Size = UDim2.fromOffset(110, 14), ZIndex = 4, TextStrokeTransparency = 0.3,
	})
	local blossoms: { Blossom } = {}
	for _, b in buttons do
		local a = math.rad(b.Angle - 90)
		local r = DIAMETER * 0.5 + 4
		local rim = centre + UDim2.fromOffset(math.cos(a) * r, math.sin(a) * r)
		local button = Sakura.roundButton(root, 30, rim, b.Glyph)
		button.TextSize, button.Font = 15, Enum.Font.GothamBold
		button.Activated:Connect(b.Press)
		local holder = button.Parent :: GuiObject
		holder.Visible = b.MapOnly ~= true
		table.insert(blossoms, { Holder = holder, Button = button, Rim = rim, Row = UDim2.fromOffset(CLUSTER.X + (b.Slot - 1) * CLUSTER_STEP, CLUSTER.Y), MapOnly = b.MapOnly == true })
	end
	return { Root = root, Disc = disc, Letters = letters, Dots = dots, Altars = altars, Region = region, State = state, Route = route,
		Blossoms = blossoms, Radar = true, Touch = false }
end

-- Radar (lobby) or radar-less row (open world). Touch grows the Map blossom to a 44 pt target the way DeviceLayout does for the others.
local function arrange(view: View, radar: boolean, touch: boolean)
	view.Radar, view.Touch = radar, touch
	view.Disc.Visible = radar
	local scale = view.Root:FindFirstChildOfClass("UIScale")
	for _, b in view.Blossoms do
		b.Holder.Position = if radar then b.Rim else b.Row
		if b.MapOnly then
			b.Holder.Visible = not radar
			local grow = (b.Button:FindFirstChild("TouchGrow") :: UIScale?) or (HudKit.make("UIScale", b.Button, { Name = "TouchGrow" }) :: UIScale)
			grow.Scale = if touch then math.max(1, TOUCH_TARGET / (30 * (if scale then scale.Scale else 1))) else 1
		end
	end
end

-- Places `offset` (world, studs) on the disc relative to the camera's flat heading.
local function place(gui: Frame, offset: Vector3, look: Vector3, right: Vector3)
	local x, y = offset:Dot(right) / RANGE, -offset:Dot(look) / RANGE
	local distance = math.sqrt(x * x + y * y)
	local edge = distance > 0.86
	if edge then x, y = x / distance * 0.86, y / distance * 0.86 end
	gui.Position = UDim2.fromScale(0.5 + x * 0.5, 0.5 + y * 0.5)
	gui.BackgroundTransparency = if edge then 0.55 else 0
	gui.Visible = true
end

-- `route` is ObjectiveController's staged route (ui.Route), nil when guidance is hidden. `radar`
-- is false beyond the lobby: only the blossom row is arranged then.
function Map.step(view: View, route: RouteLayer.Route?, radar: boolean, touch: boolean)
	if radar ~= view.Radar or touch ~= view.Touch then arrange(view, radar, touch) end
	if not radar then return end
	local camera = Workspace.CurrentCamera
	local own = view.State:Own()
	local root = own and own.Root
	if not camera or not root then return end
	local flat = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
	local look = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
	local right = look:Cross(Vector3.yAxis)
	local heading = math.atan2(look.X, -look.Z)
	for bearing, letter in view.Letters do
		local a = math.rad(bearing) - heading
		letter.Position = UDim2.new(0.5, math.sin(a) * (DIAMETER * 0.5 - 13), 0.5, -math.cos(a) * (DIAMETER * 0.5 - 13))
	end
	RouteLayer.step(view.Route, route, root.Position, look, right, RANGE)
	local used = 0
	for _, entity in view.State.Entities do
		if entity ~= own and entity.Root and used < #view.Dots and view.State:IsAlive(entity) then
			local offset = entity.Root.Position - root.Position
			if offset.Magnitude < RANGE * 2 then
				used += 1
				local d = view.Dots[used]
				d.BackgroundColor3 = if view.State:IsHostile(entity) then C.Crimson else C.Blossom
				place(d, offset, look, right)
			end
		end
	end
	for i = used + 1, #view.Dots do view.Dots[i].Visible = false end
	used = 0
	for _, altar in World.Altars do
		local p = altar.Placement
		local offset = Vector3.new(p.X, p.Y, p.Z) - root.Position
		if offset.Magnitude < RANGE * 1.5 and used < #view.Altars then
			used += 1
			place(view.Altars[used], offset, look, right)
		end
	end
	for i = used + 1, #view.Altars do view.Altars[i].Visible = false end
	local id = Players.LocalPlayer:GetAttribute("AsuraRegion")
	local info = if type(id) == "string" then World.Regions[id] else nil
	view.Region.Text = if info then info.Name else ""
end

return table.freeze(Map)
