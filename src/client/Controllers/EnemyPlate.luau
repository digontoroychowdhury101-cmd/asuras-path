--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/EnemyPlate
-- One overhead enemy plate for EnemyBars: attack warning (icon + closing ring + cue text), name,
-- health bar with damage trail and diamond caps, and a centre-out posture bar.
local HudKit = require(script.Parent:WaitForChild("HudKit") :: ModuleScript)
local Sakura = require(script.Parent:WaitForChild("SakuraKit") :: ModuleScript)
local Icons = require(script.Parent:WaitForChild("MoveIcons") :: ModuleScript)

local Plate = {}
local C = Sakura.Colors

-- Customization ------------------------------------------------------------------------------
local HEIGHT = 3.4 -- studs above the root part
local WIDTH = 150 -- health bar width (px)
local PARRY_WINDOW = 0.22 -- seconds before impact the ring turns gold
local CLASS_TEXT: { [string]: string } = { Light = "SLASH", Heavy = "HEAVY", Perilous = "PERILOUS" }

export type Plate = {
	Gui: BillboardGui, Name: TextLabel, Fill: Frame, Trail: Frame, Posture: Frame, Track: Frame, PostureTrack: Frame, Warn: Frame, Ring: Frame, RingStroke: UIStroke,
	Cue: TextLabel, Icon: CanvasGroup?, IconKind: string, Trailing: number, Raw: string, Class: string, Start: number, Impact: number, Counter: string?,
}

function Plate.build(gui: ScreenGui, entity: any, range: number): Plate
	local billboard = HudKit.make("BillboardGui", gui, {
		Name = "EnemyPlate", Size = UDim2.fromOffset(WIDTH + 30, 78), StudsOffsetWorldSpace = Vector3.new(0, HEIGHT, 0),
		AlwaysOnTop = true, LightInfluence = 0, MaxDistance = range * 1.5, ResetOnSpawn = false, Adornee = entity.Root,
	}) :: BillboardGui
	local warn = HudKit.make("Frame", billboard, {
		Name = "Warn", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 17), Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = C.Ink, BackgroundTransparency = 0.1, Visible = false,
	}) :: Frame
	HudKit.make("UICorner", warn, { CornerRadius = UDim.new(1, 0) })
	local ring = HudKit.make("Frame", warn, {
		Name = "Ring", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
	}) :: Frame
	HudKit.make("UICorner", ring, { CornerRadius = UDim.new(1, 0) })
	local ringStroke = HudKit.make("UIStroke", ring, { Color = C.Ivory, Thickness = 2 }) :: UIStroke
	local cue = HudKit.label(billboard, "", 13, Enum.Font.GothamBold, C.Ivory, {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.5, 20, 0, 17), Size = UDim2.fromOffset(90, 16),
		TextXAlignment = Enum.TextXAlignment.Left, TextStrokeTransparency = 0.2, Visible = false,
	})
	local name = HudKit.label(billboard, entity.Name, 14, Enum.Font.Garamond, C.Ivory, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 34), Size = UDim2.fromOffset(WIDTH, 15), TextStrokeTransparency = 0.25,
	})
	local track = HudKit.make("Frame", billboard, {
		Name = "Health", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 51), Size = UDim2.fromOffset(WIDTH, 9),
		BackgroundColor3 = C.Track, BorderSizePixel = 0,
	}) :: Frame
	HudKit.make("UIStroke", track, { Color = C.Ink, Thickness = 1.5 })
	local trail = HudKit.make("Frame", track, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Blossom, BorderSizePixel = 0 }) :: Frame
	local fill = HudKit.make("Frame", track, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Crimson, BorderSizePixel = 0 }) :: Frame
	HudKit.make("UIGradient", fill, { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 120, 130), Color3.fromRGB(140, 10, 26)) })
	for _, x in { 0, 1 } do Sakura.diamond(track, 10, UDim2.fromScale(x, 0.5), C.Gold, C.Ink) end
	local postureTrack = HudKit.make("Frame", billboard, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 65), Size = UDim2.fromOffset(WIDTH * 0.75, 4),
		BackgroundColor3 = C.Ink, BackgroundTransparency = 0.3, BorderSizePixel = 0,
	}) :: Frame
	local posture = HudKit.make("Frame", postureTrack, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Gold, BorderSizePixel = 0,
	}) :: Frame
	return {
		Gui = billboard, Name = name, Fill = fill, Trail = trail, Posture = posture, Track = track, PostureTrack = postureTrack, Warn = warn, Ring = ring, RingStroke = ringStroke,
		Cue = cue, Icon = nil, IconKind = "", Trailing = 1, Raw = "", Class = "", Start = 0, Impact = 0, Counter = nil,
	}
end

-- Applies a PlateLayout placement. Focus keeps only the warning (the TargetPlate shows the rest);
-- Compact drops the name; `lift` (screen pixels) raises the plate clear of a neighbour.
function Plate.mode(plate: Plate, mode: string, lift: number)
	plate.Gui.Enabled = mode ~= "Hidden"
	plate.Name.Visible = mode == "Full"
	plate.Track.Visible = mode == "Full" or mode == "Compact"
	plate.PostureTrack.Visible = plate.Track.Visible
	plate.Gui.SizeOffset = Vector2.new(0, lift / plate.Gui.Size.Y.Offset) -- +Y raises the plate
end

-- True while an attack warning is (or is about to be) on screen.
function Plate.warning(plate: Plate, now: number): boolean
	local remaining = plate.Impact - now
	return remaining > -0.12 and remaining < 3
end

-- Reads the NPC's published attack ("class|move|impactTime") and animates the warning ring.
function Plate.telegraph(plate: Plate, model: Model, now: number)
	local raw = model:GetAttribute("AsuraTelegraph")
	if type(raw) == "string" and raw ~= plate.Raw then
		plate.Raw = raw
		local class, _, impact = string.match(raw, "^(%a+)|([^|]*)|([%d%.]+)$")
		if class and tonumber(impact) then
			plate.Class, plate.Start, plate.Impact, plate.Counter = class, now, tonumber(impact) :: number, nil
		end
	end
	local remaining = plate.Impact - now
	local shown = Plate.warning(plate, now)
	plate.Warn.Visible, plate.Cue.Visible = shown, shown
	if not shown then return end
	local perilous = plate.Class == "Perilous"
	local kind = if perilous then "Perilous" elseif plate.Class == "Heavy" then "Heavy" else "Light"
	if kind ~= plate.IconKind then
		if plate.Icon then (plate.Icon :: CanvasGroup):Destroy() end
		plate.Icon = if perilous then nil else Icons.draw(plate.Warn, kind, 28)
		plate.IconKind = kind
		plate.Warn.BackgroundColor3 = if perilous then C.Crimson else C.Ink
		local bang = plate.Warn:FindFirstChild("Bang")
		if perilous and not bang then
			HudKit.label(plate.Warn, "!", 22, Enum.Font.GothamBlack, C.Ivory, { Name = "Bang", Size = UDim2.fromScale(1, 1), ZIndex = 4 })
		elseif bang and not perilous then
			bang:Destroy()
		end
	end
	local lead = math.max(plate.Impact - plate.Start, 0.05)
	local closing = math.clamp(remaining / lead, 0, 1)
	plate.Ring.Size = UDim2.fromScale(1 + closing * 1.6, 1 + closing * 1.6)
	local window = remaining <= PARRY_WINDOW
	plate.RingStroke.Color = if window then C.Gold elseif perilous then C.Crimson else C.Ivory
	plate.RingStroke.Thickness = if window then 3 else 2
	if perilous then
		plate.Cue.Text = string.upper(plate.Counter or "Dodge") .. "!"
		plate.Cue.TextColor3 = C.Crimson
	else
		plate.Cue.Text = if window then "PARRY!" else CLASS_TEXT[plate.Class] or "ATTACK"
		plate.Cue.TextColor3 = if window then C.Gold else C.Ivory
	end
end

return table.freeze(Plate)
