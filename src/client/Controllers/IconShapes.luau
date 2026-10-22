--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/IconShapes
-- Drawing primitives for MoveIcons. Coordinates are 0..1 inside a square icon frame, so shapes
-- scale with whatever size the icon is shown at. `px` values are stroke widths in pixels.
local HudKit = require(script.Parent:WaitForChild("HudKit") :: ModuleScript)
local Sakura = require(script.Parent:WaitForChild("SakuraKit") :: ModuleScript)

local Shapes = {}
-- Customization ------------------------------------------------------------------------------
Shapes.Accent = Sakura.Colors.Gold -- crossguards, pommels and highlights on every icon
Shapes.make = HudKit.make

function Shapes.box(icon: Instance, x: number, y: number, w: number, h: number, rotation: number, color: Color3, round: number?): Frame
	local f = HudKit.make("Frame", icon, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(w, h),
		Rotation = rotation, BackgroundColor3 = color, BorderSizePixel = 0,
	}) :: Frame
	if round then HudKit.make("UICorner", f, { CornerRadius = UDim.new(round, 0) }) end
	return f
end

-- A stroke between two points (icon space 0..1); the icon is square so scale is isotropic.
function Shapes.line(icon: Instance, x1: number, y1: number, x2: number, y2: number, thick: number, color: Color3): Frame
	local dx, dy = x2 - x1, y2 - y1
	return Shapes.box(icon, (x1 + x2) / 2, (y1 + y2) / 2, math.sqrt(dx * dx + dy * dy) + thick * 0.5, thick, math.deg(math.atan2(dy, dx)), color, 0.5)
end

function Shapes.disc(icon: Instance, x: number, y: number, d: number, color: Color3): Frame
	return Shapes.box(icon, x, y, d, d, 0, color, 1)
end

-- Circle outline; `cut` (0..1) hides that share of it behind a straight edge facing `facing`°.
function Shapes.ring(icon: Instance, x: number, y: number, d: number, px: number, color: Color3, cut: number?, facing: number?): Frame
	local f = Shapes.disc(icon, x, y, d, color)
	f.BackgroundTransparency = 1
	local stroke = HudKit.make("UIStroke", f, { Color = color, Thickness = math.max(1, px) }) :: UIStroke
	if cut then
		HudKit.make("UIGradient", stroke, { Rotation = facing or 0, Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1 - cut - 0.001, 0),
			NumberSequenceKeypoint.new(1 - cut, 1), NumberSequenceKeypoint.new(1, 1),
		}) })
	end
	return f
end

function Shapes.sword(icon: Instance, x1: number, y1: number, x2: number, y2: number, thick: number, color: Color3)
	Shapes.line(icon, x1, y1, x2, y2, thick, color) -- blade, tip at (x2, y2)
	local gx, gy = x1 + (x2 - x1) * 0.18, y1 + (y2 - y1) * 0.18
	local nx, ny = -(y2 - y1) * 0.22, (x2 - x1) * 0.22
	Shapes.line(icon, gx - nx, gy - ny, gx + nx, gy + ny, thick * 0.9, Shapes.Accent) -- crossguard
	Shapes.disc(icon, x1 - (x2 - x1) * 0.08, y1 - (y2 - y1) * 0.08, thick * 1.6, Shapes.Accent) -- pommel
end

return table.freeze(Shapes)
