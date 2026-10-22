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

type Mark = { Gui: GuiObject, Bearing: number }
export type View = { Root: Frame, Marks: { Mark }, Heading: TextLabel }

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
	end
	Sakura.medallion(root, 30, UDim2.new(0.5, 0, 0, LINE_Y), false)
	Sakura.crest(root, 24, UDim2.new(0.5, 0, 0, LINE_Y))
	local heading = HudKit.label(root, "N", 13, Enum.Font.Garamond, C.Ivory, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(40, 12), TextStrokeTransparency = 0.3,
	})
	return { Root = root, Marks = marks, Heading = heading }
end

function Compass.step(view: View)
	local camera = Workspace.CurrentCamera
	if not camera then return end
	local look = camera.CFrame.LookVector
	local heading = math.deg(math.atan2(look.X, -look.Z)) % 360
	for _, mark in view.Marks do
		local delta = (mark.Bearing - heading + 540) % 360 - 180
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
	view.Heading.Text = NAMES[math.floor((heading + 22.5) / 45) % 8 + 1]
end

return table.freeze(Compass)
