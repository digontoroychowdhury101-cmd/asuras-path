--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/UiWindow
-- Shared menu shell. The material falls away toward the body so the content carries the visual weight.
local TweenService = game:GetService("TweenService")
local Effects = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.EffectsPreference)
local HudKit = require(script.Parent:WaitForChild("HudKit") :: ModuleScript)
local UiKit = require(script.Parent:WaitForChild("UiKit") :: ModuleScript)

local Window = {}
local T = UiKit.Theme
local M = UiKit.Motion

export type Window = {
	Root: Frame, -- full-screen holder; Visible is the open/closed truth other systems watch
	Holder: Frame,
	Group: CanvasGroup,
	Shadow: Frame,
	Edge: UIStroke,
	Backdrop: Frame,
	Body: Frame,
	Title: TextLabel,
	Subtitle: TextLabel,
	Close: TextButton,
	Scale: UIScale,
	Rest: UDim2,
	LeftRail: boolean,
	Serial: number,
}

export type Options = { LeftRail: boolean? }

function Window.new(gui: Instance, name: string, title: string, subtitle: string, maxSize: Vector2, onClose: () -> (), options: Options?): Window
	local left = options ~= nil and options.LeftRail == true
	local rest = if left then UDim2.new(0, 20, 0.5, 0) else UDim2.fromScale(0.5, 0.5)
	local root = HudKit.make("Frame", gui, {
		Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 30,
	}) :: Frame
	local backdrop = HudKit.make("Frame", root, {
		Name = "Backdrop", Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Backdrop,
		BackgroundTransparency = 1, BorderSizePixel = 0, Active = true,
	}) :: Frame
	if left then
		HudKit.make("UIGradient", backdrop, { Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.35, 0.1), NumberSequenceKeypoint.new(1, 0.66),
		}) })
	end
	local holder = HudKit.make("Frame", root, {
		Name = "Holder", AnchorPoint = Vector2.new(if left then 0 else 0.5, 0.5), Position = rest,
		Size = if left then UDim2.new(1, -40, 1, -40) else UDim2.fromScale(0.94, 0.90), BackgroundTransparency = 1,
	}) :: Frame
	HudKit.make("UISizeConstraint", holder, { MaxSize = maxSize })
	local scale = HudKit.make("UIScale", holder, {}) :: UIScale
	local shadow = HudKit.make("Frame", holder, {
		Name = "Shadow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 4),
		Size = UDim2.new(1, 8, 1, 8), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
	}) :: Frame
	local canvas = HudKit.make("CanvasGroup", holder, {
		Name = "Panel", Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Surface, BorderSizePixel = 0,
	}) :: CanvasGroup
	-- The stroke lives on the holder: a CanvasGroup would clip an outside border.
	local edge = HudKit.make("UIStroke", holder, { Color = T.Edge, Thickness = 1, Transparency = 1 }) :: UIStroke
	local light = HudKit.make("Frame", canvas, {
		Name = "Lacquer", Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = T.Raised, BorderSizePixel = 0,
	})
	HudKit.make("UIGradient", light, {
		Rotation = 112, Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.10), NumberSequenceKeypoint.new(0.46, 0.91), NumberSequenceKeypoint.new(1, 1),
		}),
	})
	HudKit.inlay(canvas, 24)
	local group = HudKit.make("Frame", canvas, { Name = "Content", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }) :: Frame
	local padding = HudKit.make("UIPadding", group, {}) :: UIPadding
	local titleLabel = HudKit.label(group, title, 40, T.TitleFont, T.Ivory, {
		Name = "WindowTitle", Size = UDim2.new(1, -70, 0, 48), TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = true, TextStrokeTransparency = 1,
	})
	local titleFit = HudKit.make("UITextSizeConstraint", titleLabel, { MinTextSize = 20, MaxTextSize = 46 }) :: UITextSizeConstraint
	local subtitleLabel = HudKit.label(group, subtitle, 13, T.BodyFont, T.Muted, {
		Name = "WindowSubtitle", Size = UDim2.new(1, -70, 0, 19), TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, Visible = subtitle ~= "",
	})
	local rule = HudKit.make("Frame", group, {
		Name = "Rule", Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = T.Edge, BackgroundTransparency = 0.52, BorderSizePixel = 0,
	}) :: Frame
	HudKit.make("Frame", rule, { Name = "KnifeEdge", Size = UDim2.fromOffset(68, 2), BackgroundColor3 = T.Gold, BorderSizePixel = 0 })
	local close = UiKit.button(group, "Close", "Ghost", onClose)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.fromScale(1, 0)
	close.Size = UDim2.fromOffset(64, 44)
	close.TextSize = 14
	local body = HudKit.make("Frame", group, {
		Name = "Body", BackgroundTransparency = 1,
	}) :: Frame
	local function layout()
		local size = holder.AbsoluteSize
		local tight = size.X < (if left then 380 else 520) or size.Y < 430
		local horizontal = if tight then 16 else 26
		local vertical = if tight then 12 else 21
		padding.PaddingLeft, padding.PaddingRight = UDim.new(0, horizontal), UDim.new(0, horizontal)
		padding.PaddingTop, padding.PaddingBottom = UDim.new(0, vertical), UDim.new(0, vertical)
		local titleHeight = if tight then 40 else 50
		local hasSubtitle = subtitleLabel.Text ~= ""
		titleFit.MaxTextSize = if tight then 37 elseif left then 49 else 44
		titleLabel.Size = UDim2.new(1, -70, 0, titleHeight)
		subtitleLabel.Position, subtitleLabel.Visible = UDim2.fromOffset(0, titleHeight), hasSubtitle
		local ruleY = titleHeight + (if hasSubtitle then 23 else 7)
		rule.Position = UDim2.fromOffset(0, ruleY)
		body.Position, body.Size = UDim2.fromOffset(0, ruleY + 11), UDim2.new(1, 0, 1, -ruleY - 11)
	end
	holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	subtitleLabel:GetPropertyChangedSignal("Text"):Connect(layout)
	layout()
	return {
		Root = root, Holder = holder, Group = canvas, Edge = edge, Shadow = shadow, Backdrop = backdrop, Body = body,
		Title = titleLabel, Subtitle = subtitleLabel, Close = close, Scale = scale, Rest = rest, LeftRail = left, Serial = 0,
	}
end

function Window.isOpen(w: Window): boolean
	return w.Root.Visible and w.Root:GetAttribute("UiClosing") ~= true
end

function Window.open(w: Window)
	w.Serial += 1
	w.Root:SetAttribute("UiClosing", false)
	local animate = not Effects.reducedMotion()
	w.Scale.Scale = if animate then M.OpenFrom else 1
	w.Group.GroupTransparency = 1
	local offset = if w.LeftRail then UDim2.fromOffset(-M.SlidePixels, 0) else UDim2.fromOffset(0, M.SlidePixels)
	w.Holder.Position = if animate then w.Rest + offset else w.Rest
	w.Root.Visible = true
	UiKit.play("Open")
	if animate then
		TweenService:Create(w.Scale, M.Open, { Scale = 1 }):Play()
		TweenService:Create(w.Holder, M.Open, { Position = w.Rest }):Play()
	end
	TweenService:Create(w.Group, M.Hover, { GroupTransparency = 0 }):Play()
	TweenService:Create(w.Shadow, M.Hover, { BackgroundTransparency = 0.55 }):Play()
	TweenService:Create(w.Edge, M.Hover, { Transparency = 0.1 }):Play()
	TweenService:Create(w.Backdrop, M.Hover, { BackgroundTransparency = T.BackdropAlpha }):Play()
end

-- Fades out, then hides Root; a re-open during the fade wins (Serial check).
function Window.close(w: Window, done: (() -> ())?)
	if not w.Root.Visible then
		return
	end
	w.Serial += 1
	local serial = w.Serial
	w.Root:SetAttribute("UiClosing", true)
	UiKit.play("Close")
	if not Effects.reducedMotion() then TweenService:Create(w.Scale, M.Close, { Scale = M.OpenFrom }):Play() end
	TweenService:Create(w.Shadow, M.Close, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(w.Edge, M.Close, { Transparency = 1 }):Play()
	TweenService:Create(w.Backdrop, M.Close, { BackgroundTransparency = 1 }):Play()
	local fade = TweenService:Create(w.Group, M.Close, { GroupTransparency = 1 })
	fade.Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed and w.Serial == serial and w.Root.Parent then
			w.Root:SetAttribute("UiClosing", false)
			w.Root.Visible = false
			if done then
				done()
			end
		end
	end)
	fade:Play()
end

return table.freeze(Window)
