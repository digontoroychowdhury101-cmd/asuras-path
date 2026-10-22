--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/TargetPlate
-- Top-centre health readout for the foe you are fighting (lock-on target, else whoever you last
-- hit or were hit by). Shows name, a crimson health bar with exact numbers and a damage trail, and
-- posture. Sits in the boss bar's slot and stays hidden while a boss bar is showing.
local TweenService = game:GetService("TweenService")
local HudKit = require(script.Parent:WaitForChild("HudKit") :: ModuleScript)
local Sakura = require(script.Parent:WaitForChild("SakuraKit") :: ModuleScript)

local Target = {}
local C = Sakura.Colors

-- Customization ------------------------------------------------------------------------------
local MAX_WIDTH = 520
local TOP = 78
local TRAIL_SPEED = 0.5
local FADE = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

export type View = { Root: CanvasGroup, Name: TextLabel, Numbers: TextLabel, Fill: Frame, Trail: Frame, Posture: Frame, Trailing: number, Shown: boolean, Id: number }

function Target.new(gui: ScreenGui): View
	local root = HudKit.make("CanvasGroup", gui, {
		Name = "TargetPlate", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, TOP),
		Size = UDim2.new(0.4, 0, 0, 52), BackgroundTransparency = 1, GroupTransparency = 1, Visible = false,
	}) :: CanvasGroup
	HudKit.make("UISizeConstraint", root, { MaxSize = Vector2.new(MAX_WIDTH, 52), MinSize = Vector2.new(260, 52) })
	local name = HudKit.label(root, "", 20, Enum.Font.Garamond, C.Ivory, {
		Size = UDim2.new(1, 0, 0, 22), TextStrokeTransparency = 0.2,
	})
	local track = HudKit.make("Frame", root, {
		Name = "Health", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 26), Size = UDim2.new(1, -24, 0, 14),
		BackgroundColor3 = C.Track, BorderSizePixel = 0,
	}) :: Frame
	HudKit.make("UIStroke", track, { Color = C.Gold, Thickness = 1, Transparency = 0.3 })
	local trail = HudKit.make("Frame", track, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Blossom, BorderSizePixel = 0 }) :: Frame
	local fill = HudKit.make("Frame", track, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Crimson, BorderSizePixel = 0 }) :: Frame
	HudKit.make("UIGradient", fill, { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 110, 120), Color3.fromRGB(130, 8, 24)) })
	local numbers = HudKit.label(track, "", 12, Enum.Font.GothamBold, C.Ivory, { Size = UDim2.fromScale(1, 1), ZIndex = 3, TextStrokeTransparency = 0.2 })
	for _, x in { 0, 1 } do Sakura.diamond(track, 14, UDim2.fromScale(x, 0.5), C.Gold, C.Ink) end
	local postureTrack = HudKit.make("Frame", root, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 45), Size = UDim2.new(0.6, 0, 0, 5),
		BackgroundColor3 = C.Ink, BackgroundTransparency = 0.3, BorderSizePixel = 0,
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
	view.Posture.BackgroundColor3 = if broken then C.Ivory elseif p > 0.8 then C.Crimson else C.Gold
	show(view, true)
end

return table.freeze(Target)
