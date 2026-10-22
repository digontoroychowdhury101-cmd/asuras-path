--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/SakuraMinimap
-- Top-left blossom radar that turns with the camera: sakura-ringed plum disc with corner sprigs,
-- N/E/S/W on the rim, the player's arrow fixed at the centre, crimson dots for hostiles, blossom
-- dots for other fighters, gold diamonds for Incense Altars, the region name beneath, and small
-- round blossom buttons on the rim (Respite menu, Controls).
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath")
local World = require(Shared:WaitForChild("Shared"):WaitForChild("WorldDefinitions") :: ModuleScript) :: any
local HudKit = require(script.Parent:WaitForChild("HudKit") :: ModuleScript)
local Sakura = require(script.Parent:WaitForChild("SakuraKit") :: ModuleScript)

local Map = {}
local C = Sakura.Colors

-- Customization ------------------------------------------------------------------------------
local DIAMETER = 150
local RANGE = 140 -- studs from centre to rim
local DOT_POOL = 24
local ALTAR_POOL = 8

export type Button = { Glyph: string, Angle: number, Press: () -> () }
export type View = { Root: Frame, Disc: Frame, Letters: { [number]: TextLabel }, Dots: { Frame }, Altars: { Frame }, Region: TextLabel, State: any }

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
	local disc = Sakura.medallion(root, DIAMETER, centre, false, { 315, 45, 160 })
	disc.BackgroundTransparency = 0.3
	for _, rotation in { 0, 90 } do -- faint crosshair
		HudKit.make("Frame", disc, {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -24, 0, 1), Rotation = rotation,
			BackgroundColor3 = C.Sakura, BackgroundTransparency = 0.8, BorderSizePixel = 0,
		})
	end
	local letters: { [number]: TextLabel } = {}
	for i, text in { "N", "E", "S", "W" } do
		letters[(i - 1) * 90] = HudKit.label(disc, text, if text == "N" then 15 else 12, Enum.Font.Garamond, if text == "N" then C.Sakura else C.Ivory, {
			AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(16, 16), ZIndex = 4, TextStrokeTransparency = 0.3,
		})
	end
	HudKit.label(disc, "▲", 18, Enum.Font.GothamBold, C.Blossom, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(20, 20), ZIndex = 5, TextStrokeTransparency = 0.2,
	})
	local dots, altars = {}, {}
	for i = 1, DOT_POOL do dots[i] = dot(disc, 7, C.Crimson, false) end
	for i = 1, ALTAR_POOL do altars[i] = dot(disc, 8, C.Gold, true) end
	local region = HudKit.label(disc, "", 11, Enum.Font.Garamond, C.Blossom, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.66, 0), Size = UDim2.fromOffset(110, 14), ZIndex = 4, TextStrokeTransparency = 0.3,
	})
	for _, b in buttons do
		local a = math.rad(b.Angle - 90)
		local r = DIAMETER * 0.5 + 4
		local button = Sakura.roundButton(root, 30, centre + UDim2.fromOffset(math.cos(a) * r, math.sin(a) * r), b.Glyph)
		button.TextSize, button.Font = 15, Enum.Font.GothamBold
		button.Activated:Connect(b.Press)
	end
	return { Root = root, Disc = disc, Letters = letters, Dots = dots, Altars = altars, Region = region, State = state }
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

function Map.step(view: View)
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
	view.Region.Text = if info then string.upper(info.Name) else ""
end

return table.freeze(Map)
