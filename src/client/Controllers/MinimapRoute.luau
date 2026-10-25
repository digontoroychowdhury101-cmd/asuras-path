--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/MinimapRoute
-- Route layer for the SakuraMinimap (follow-up 14, #28): the walked line RouteGuide stages for the
-- objective marker (player -> doorways -> goal), drawn as thin pooled segments clipped to the disc.
-- Nodes mark what the line cannot show flat: a climb or drop (▲/▼ when a doorway sits a storey
-- above or below), a portal the route leaves through (◎, nothing drawn past it), and the
-- bloodstain (✕). The route comes from ObjectiveController's refresh; nothing here scans the world.
local HudKit = require(script.Parent:WaitForChild("HudKit") :: ModuleScript)
local Sakura = require(script.Parent:WaitForChild("SakuraKit") :: ModuleScript)

local Layer = {}
local C = Sakura.Colors

-- Customization ------------------------------------------------------------------------------
local SEGMENTS = 10 -- longest staged route (Monastery doors + campaign doors) fits
local NODES = 6
local RIM = 0.86 -- disc radius the line is clipped to (dots clamp to the same rim)
local NODE_RIM = 0.7 -- off-disc nodes ride inside the N/E/S/W ring, never under a letter
local STOREY = 7 -- studs above/below the player before a doorway shows a climb or a drop
local WIDTH = 3 -- line thickness, px

export type Route = { Points: { Vector3 }, Names: { string }, Exit: string?, Stain: boolean? }
export type View = { Segments: { Frame }, Nodes: { TextLabel }, Diameter: number }

function Layer.new(disc: Frame, diameter: number): View
	local segments, nodes = {}, {}
	for i = 1, SEGMENTS do
		segments[i] = HudKit.make("Frame", disc, {
			Name = "RouteSegment", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C.Gold, BackgroundTransparency = 0.25,
			BorderSizePixel = 0, Visible = false, ZIndex = 2,
		}) :: Frame
	end
	for i = 1, NODES do
		nodes[i] = HudKit.label(disc, "", 11, Enum.Font.GothamBold, C.Gold, {
			Name = "RouteNode", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(14, 14), Visible = false, ZIndex = 3,
			TextStrokeTransparency = 0.2,
		})
	end
	return { Segments = segments, Nodes = nodes, Diameter = diameter }
end

-- The part of a -> b inside the rim circle (disc units: 1 = RANGE studs), or nil when outside.
local function clip(ax: number, ay: number, bx: number, by: number): (number?, number?, number?, number?)
	local dx, dy = bx - ax, by - ay
	local a = dx * dx + dy * dy
	if a < 1e-6 then return nil, nil, nil, nil end
	local b = 2 * (ax * dx + ay * dy)
	local c = ax * ax + ay * ay - RIM * RIM
	local disc = b * b - 4 * a * c
	if disc <= 0 then return nil, nil, nil, nil end
	local root = math.sqrt(disc)
	local t0, t1 = math.max(0, (-b - root) / (2 * a)), math.min(1, (-b + root) / (2 * a))
	if t0 >= t1 then return nil, nil, nil, nil end
	return ax + dx * t0, ay + dy * t0, ax + dx * t1, ay + dy * t1
end

local function glyph(route: Route, index: number, rise: number): (string, Color3)
	local last = index == #route.Points
	if last and route.Exit then return "◎", C.Blossom end
	if last and route.Stain then return "✕", C.Crimson end
	if rise > STOREY then return "▲", C.Gold end
	if rise < -STOREY then return "▼", C.Gold end
	return if last then "◆" else "", C.Gold
end

-- Projects the route around `origin` with the camera's flat basis (as SakuraMinimap places dots).
function Layer.step(view: View, route: Route?, origin: Vector3, look: Vector3, right: Vector3, range: number)
	local drawn, marked = 0, 0
	if route then
		local px, py = 0, 0 -- the player sits at the centre
		for index, point in route.Points do
			local offset = point - origin
			local x, y = offset:Dot(right) / range, -offset:Dot(look) / range
			local ax, ay, bx, by = clip(px, py, x, y)
			if ax and ay and bx and by and drawn < #view.Segments then
				drawn += 1
				local segment = view.Segments[drawn]
				local length = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2) * view.Diameter * 0.5
				segment.Position = UDim2.fromScale(0.5 + (ax + bx) * 0.25, 0.5 + (ay + by) * 0.25)
				segment.Size = UDim2.fromOffset(length, WIDTH)
				segment.Rotation = math.deg(math.atan2(by - ay, bx - ax))
				segment.Visible = true
			end
			local text, color = glyph(route, index, offset.Y)
			local distance = math.sqrt(x * x + y * y)
			-- Off-disc nodes ride the rim only for the next step, so the rim never fills with icons.
			if text ~= "" and marked < #view.Nodes and (distance <= RIM or index == 1) then
				marked += 1
				local node = view.Nodes[marked]
				local scale = if distance > RIM then NODE_RIM / distance else 1
				node.Text, node.TextColor3 = text, color
				node.Position = UDim2.fromScale(0.5 + x * scale * 0.5, 0.5 + y * scale * 0.5)
				node.TextTransparency = if distance > RIM then 0.45 else 0
				node.Visible = true
			end
			px, py = x, y
		end
	end
	for i = drawn + 1, #view.Segments do view.Segments[i].Visible = false end
	for i = marked + 1, #view.Nodes do view.Nodes[i].Visible = false end
end

return table.freeze(Layer)
