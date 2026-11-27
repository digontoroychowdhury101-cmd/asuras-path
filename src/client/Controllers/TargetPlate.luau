--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/TargetPlate
-- Top-centre health readout for the foe you are fighting (lock-on target, else whoever you last
-- hit or were hit by). Shows name, a crimson health bar with exact numbers and a damage trail, and
-- posture. Sits in the boss bar's slot and stays hidden while a boss bar is showing.
local TweenService = game:GetService("TweenService")
local HudKit = require(script.Parent:WaitForChild("HudKit") :: ModuleScript)
local C = require(script.Parent.CombatHudStyle)

local Target = {}

-- Customization ------------------------------------------------------------------------------
local MAX_WIDTH = 520
local TOP = 78
local TRAIL_SPEED = 0.5
local FADE = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

export type View = { Root: CanvasGroup, Name: TextLabel, Numbers: TextLabel, Fill: Frame, Trail: Frame, Posture: Frame, Trailing: number, Shown: boolean, Id: number }

function Target.new(gui: ScreenGui): View
	local root = HudKit.make("CanvasGroup", gui, {
		Name = "TargetPlate", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, TOP),
		Size = UDim2.new(0.4, 0, 0, 52), BackgroundTransparency = 1,
		BorderSizePixel = 0, GroupTransparency = 1, Visible = false,
	}) :: CanvasGroup
	HudKit.make("UISizeConstraint", root, { MaxSize = Vector2.new(MAX_WIDTH, 52), MinSize = Vector2.new(260, 52) })
	local vignette = HudKit.make("Frame", root, {
		Size = UDim2.new(1, 0, 0, 39), BackgroundColor3 = C.Shade, BorderSizePixel = 0,
	})
	HudKit.make("UIGradient", vignette, { Rotation = 90, Transparency = NumberSequence.new(0.32, 0.85) })
	local name = HudKit.label(root, "", 20, HudKit.TitleFont, C.Ivory, {
		Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -112, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left, TextStrokeTransparency = 0.2, TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local track = HudKit.make("Frame", root, {
		Name = "Health", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 25), Size = UDim2.new(1, -24, 0, 11),
		BackgroundColor3 = C.Track, BorderSizePixel = 0,
	}) :: Frame
	HudKit.make("UIStroke", track, { Color = C.Edge, Thickness = 1, Transparency = 0.2 })
	local trail = HudKit.make("Frame", track, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Rally, BorderSizePixel = 0 }) :: Frame
	local fill = HudKit.make("Frame", track, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Blood, BorderSizePixel = 0 }) :: Frame
	HudKit.make("UIGradient", fill, { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(215, 120, 94), Color3.fromRGB(143, 42, 34)) })
	local numbers = HudKit.label(root, "", 13, HudKit.BodyFont, C.Ivory, {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 0), Size = UDim2.fromOffset(85, 22),
		TextXAlignment = Enum.TextXAlignment.Right, TextStrokeTransparency = 0.2,
	})
	local postureTrack = HudKit.make("Frame", root, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 43), Size = UDim2.new(0.56, 0, 0, 3),
		BackgroundColor3 = C.Track, BackgroundTransparency = 0.28, BorderSizePixel = 0,
	}) :: Frame
	local posture = HudKit.make("Frame", postureTrack, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Gold, BorderSizePixel = 0,
	}) :: Frame
	return { Root = root, Name = name, Numbers = numbers, Fill = fill, Trail = trail, Posture = posture, Trailing = 1, Shown = false, Id = 0 }
end

local function show(view: View, on: boolean)
	if on == view.Shown then return end
	view.Shown = on
	if on then view.Root.Visible = true end
	local tween = TweenService:Create(view.Root, FADE, { GroupTransparency = if on then 0 else 1 })
	tween.Completed:Once(function()
		if not view.Shown then view.Root.Visible = false end
	end)
	tween:Play()
end

function Target.update(view: View, entity: any?, dt: number, blocked: boolean)
	local snapshot = entity and entity.Snapshot
	if blocked or not entity or not snapshot then
		show(view, false)
		return
	end
	if entity.Id ~= view.Id then view.Id, view.Trailing = entity.Id, 1 end
	local maxHP = math.max(snapshot.MaxHP, 1)
	local ratio = math.clamp(snapshot.ActiveHP / maxHP, 0, 1)
	view.Trailing = if view.Trailing > ratio then math.max(ratio, view.Trailing - TRAIL_SPEED * dt) else ratio
	view.Fill.Size = UDim2.fromScale(ratio, 1)
	view.Trail.Size = UDim2.fromScale(view.Trailing, 1)
	view.Name.Text = entity.Name
	view.Numbers.Text = string.format("%d / %d", math.ceil(snapshot.ActiveHP), math.floor(maxHP + 0.5))
	local p = math.clamp(snapshot.Posture / math.max(snapshot.PostureCapacity, 1), 0, 1)
	local broken = snapshot.State == "StanceBroken"
	view.Posture.Size = UDim2.fromScale(if broken then 1 else p, 1)
	view.Posture.BackgroundColor3 = if broken then C.Ivory elseif p > 0.8 then C.Blood else C.Gold
	show(view, true)
end

return table.freeze(Target)
