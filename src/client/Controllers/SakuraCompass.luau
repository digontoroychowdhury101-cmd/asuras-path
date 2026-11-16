--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/SakuraCompass
-- Top-centre heading strip: a sakura hairline with seal-crest finials, a crest medallion at the
-- centre, the nearest heading above it, and cardinal/intercardinal marks plus 15-degree ticks that
-- slide along the line as the camera turns. North is world -Z.
local Workspace = game:GetService("Workspace")
local HudKit = require(script.Parent:WaitForChild("HudKit") :: ModuleScript)
local Sakura = require(script.Parent:WaitForChild("SakuraKit") :: ModuleScript)

local Compass = {}
local C = Sakura.Colors

-- Customization ------------------------------------------------------------------------------
local SIZE = Vector2.new(520, 60)
local HALF_SPAN = 80 -- degrees visible either side of centre
local LINE_Y = 30
local NAMES = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }
-- Numbers sit every 30 degrees (90s are letters): at the 240 px minimum width that is 45 px between
-- numbers and 22.5 px from a number to the nearest letter, versus a ~16 px three-digit label.
local NUMBER_STEP = 30
local MARKER_Y = 20 -- waypoint row between the bearing readout (top) and the line

type Mark = { Gui: GuiObject, Bearing: number }
export type View = { Root: Frame, Marks: { Mark }, Heading: TextLabel, Markers: { [string]: Mark } }

-- Pure math (no Roblox types) so tools/test_compass_bearing.luau can check it.
function Compass.bearing(lookX: number, lookZ: number): number
	local degrees = math.deg(math.atan2(lookX, -lookZ)) % 360
	return if degrees >= 360 then 0 else degrees -- a tiny negative angle rounds up to exactly 360
end

function Compass.offset(bearing: number, heading: number): number
	return (bearing - heading + 540) % 360 - 180
end

function Compass.readout(heading: number): number
	return math.floor(heading + 0.5) % 360
end

function Compass.new(gui: ScreenGui): View
	local root = HudKit.make("Frame", gui, {
		Name = "Compass", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.new(0.36, 0, 0, SIZE.Y), BackgroundTransparency = 1,
	}) :: Frame
	HudKit.make("UISizeConstraint", root, { MaxSize = SIZE, MinSize = Vector2.new(240, SIZE.Y) })
	local line = HudKit.make("Frame", root, {
		Name = "Line", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(0, LINE_Y), Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = C.Sakura, BorderSizePixel = 0,
	})
	HudKit.make("UIGradient", line, { Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(0.15, 0.25), NumberSequenceKeypoint.new(0.85, 0.25), NumberSequenceKeypoint.new(1, 0.9),
	}) })
	Sakura.crest(root, 16, UDim2.new(0, 2, 0, LINE_Y))
	Sakura.crest(root, 16, UDim2.new(1, -2, 0, LINE_Y))
	local marks: { Mark } = {}
	for bearing = 0, 345, 15 do
		local named = bearing % 45 == 0
		local gui: GuiObject
		if named then
			local text = NAMES[bearing // 45 + 1]
			local cardinal = #text == 1
			gui = HudKit.label(root, text, if cardinal then 16 else 12, Enum.Font.Garamond, if cardinal then C.Ivory else C.Blossom, {
				AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(28, 16),
			})
			gui.Position = UDim2.new(0.5, 0, 0, LINE_Y + 6)
		else
			gui = HudKit.make("Frame", root, {
				Name = "Tick", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(1, 6), BackgroundColor3 = C.Sakura, BorderSizePixel = 0,
			}) :: Frame
			gui.Position = UDim2.new(0.5, 0, 0, LINE_Y)
		end
		table.insert(marks, { Gui = gui, Bearing = bearing })
		if bearing % NUMBER_STEP == 0 and not named then
			local number = HudKit.label(root, tostring(bearing), 11, Enum.Font.Garamond, C.Blossom, {
				AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(24, 12),
			})
			number.Position = UDim2.new(0.5, 0, 0, LINE_Y + 8)
			table.insert(marks, { Gui = number, Bearing = bearing })
		end
	end
	Sakura.medallion(root, 30, UDim2.new(0.5, 0, 0, LINE_Y), false)
	Sakura.crest(root, 24, UDim2.new(0.5, 0, 0, LINE_Y))
	-- Heading doubles as the numeric readout ("NE 045°") on the top row, clear of the waypoint row.
	local heading = HudKit.label(root, "N 000°", 13, Enum.Font.Garamond, C.Ivory, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(64, 14), TextStrokeTransparency = 0.3,
	})
	return { Root = root, Marks = marks, Heading = heading, Markers = {} }
end

-- Places or moves a waypoint icon at a world bearing (degrees); nil clears it. Outside the visible
-- window it pins, dimmed, to the strip edge. Lives on its own row below the labels' ZIndex.
function Compass.setMarker(view: View, id: string, bearing: number?)
	local marker = view.Markers[id]
	if bearing == nil then
		if marker then marker.Gui:Destroy() end
		view.Markers[id] = nil
		return
	end
	if not marker then
		marker = {
			Gui = HudKit.make("Frame", view.Root, {
				Name = "Marker_" .. id, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(8, 8), Rotation = 45, ZIndex = 0,
				Position = UDim2.new(0.5, 0, 0, MARKER_Y), BackgroundColor3 = C.Gold, BorderSizePixel = 0,
			}) :: Frame,
			Bearing = 0,
		}
		view.Markers[id] = marker
	end
	marker.Bearing = bearing % 360
end

function Compass.step(view: View)
	local camera = Workspace.CurrentCamera
	if not camera then return end
	local look = camera.CFrame.LookVector
	local heading = Compass.bearing(look.X, look.Z)
	for _, marker in view.Markers do
		local delta = Compass.offset(marker.Bearing, heading)
		local x = 0.5 + math.clamp(delta, -HALF_SPAN, HALF_SPAN) / (HALF_SPAN * 2)
		marker.Gui.Position = UDim2.new(math.clamp(x, 0.04, 0.96), 0, 0, MARKER_Y)
		marker.Gui.BackgroundTransparency =if math.abs(delta) > HALF_SPAN then 0.55 else 0.1
	end
	for _, mark in view.Marks do
		local delta = Compass.offset(mark.Bearing, heading)
		local shown = math.abs(delta) < HALF_SPAN and math.abs(delta) > 6
		mark.Gui.Visible = shown
		if shown then
			local x = 0.5 + delta / (HALF_SPAN * 2)
			mark.Gui.Position = UDim2.new(x, 0, mark.Gui.Position.Y.Scale, mark.Gui.Position.Y.Offset)
			local fade = math.clamp((math.abs(delta) - HALF_SPAN * 0.6) / (HALF_SPAN * 0.4), 0, 1)
			if mark.Gui:IsA("TextLabel") then
				mark.Gui.TextTransparency = fade
				mark.Gui.TextStrokeTransparency = math.max(fade, 0.5)
			else
				mark.Gui.BackgroundTransparency = 0.2 + fade * 0.8
			end
		end
	end
	view.Heading.Text = string.format("%s %03d°", NAMES[math.floor((heading + 22.5) / 45) % 8 + 1], Compass.readout(heading))
end

return table.freeze(Compass)
