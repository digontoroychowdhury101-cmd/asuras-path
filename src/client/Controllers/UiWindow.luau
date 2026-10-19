--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/UiWindow
-- Shared modal shell for menus: dim backdrop, centred lacquer panel (CanvasGroup) with drop shadow,
-- calligraphic title, ember subtitle, gold hairline and a ghost close button. Sized in Scale and
-- clamped by UISizeConstraint + UIAspectRatioConstraint so it never stretches on phones or
-- ultrawides. Open springs in (scale + slide + group fade); close fades out, then hides Root.
local TweenService = game:GetService("TweenService")
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
	Serial: number,
}

function Window.new(gui: Instance, name: string, title: string, subtitle: string, maxSize: Vector2, onClose: () -> ()): Window
	local root = HudKit.make("Frame", gui, {
		Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 30,
	}) :: Frame
	local backdrop = HudKit.make("Frame", root, {
		Name = "Backdrop", Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Backdrop,
		BackgroundTransparency = 1, BorderSizePixel = 0, Active = true,
	}) :: Frame
	local holder = HudKit.make("Frame", root, {
		Name = "Holder", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.86), BackgroundTransparency = 1,
	}) :: Frame
	HudKit.make("UISizeConstraint", holder, { MaxSize = maxSize, MinSize = Vector2.new(280, 220) })
	HudKit.make("UIAspectRatioConstraint", holder, { AspectRatio = maxSize.X / maxSize.Y })
	local scale = HudKit.make("UIScale", holder, {}) :: UIScale
	local shadow = HudKit.make("Frame", holder, {
		Name = "Shadow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 8),
		Size = UDim2.new(1, 18, 1, 18), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
	}) :: Frame
	HudKit.make("UICorner", shadow, { CornerRadius = UDim.new(0, T.Radius + 8) })
	local canvas = HudKit.make("CanvasGroup", holder, {
		Name = "Panel", Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Surface, BorderSizePixel = 0,
	}) :: CanvasGroup
	HudKit.make("UICorner", canvas, { CornerRadius = UDim.new(0, T.Radius + 2) })
	-- The stroke lives on the holder: a CanvasGroup would clip an outside border.
	HudKit.make("UICorner", holder, { CornerRadius = UDim.new(0, T.Radius + 2) })
	local edge = HudKit.make("UIStroke", holder, { Color = T.Edge, Thickness = 2, Transparency = 1 }) :: UIStroke
	local glow = HudKit.make("Frame", canvas, { -- ember glow bleeding up from the foot of the panel
		Name = "Glow", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.55),
		BackgroundColor3 = T.Ember, BorderSizePixel = 0,
	})
	HudKit.make("UIGradient", glow, {
		Rotation = 90, Transparency = NumberSequence.new(1, 0.9),
	})
	local group = HudKit.make("Frame", canvas, { Name = "Content", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }) :: Frame
	HudKit.make("UIPadding", group, {
		PaddingLeft = UDim.new(0, 22), PaddingRight = UDim.new(0, 22), PaddingTop = UDim.new(0, 16), PaddingBottom = UDim.new(0, 16),
	})
	local titleLabel = HudKit.label(group, title, 32, T.TitleFont, T.Ivory, {
		Size = UDim2.new(1, -60, 0, 36), TextXAlignment = Enum.TextXAlignment.Left,
	})
	local subtitleLabel = HudKit.label(group, subtitle, 15, T.TitleFont, T.Ember, {
		Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, -60, 0, 20), TextXAlignment = Enum.TextXAlignment.Left,
	})
	local rule = HudKit.make("Frame", group, {
		Name = "Rule", Position = UDim2.fromOffset(0, 64), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = T.Gold, BorderSizePixel = 0,
	})
	HudKit.make("UIGradient", rule, {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.6, 0.6), NumberSequenceKeypoint.new(1, 1),
		}),
	})
	local close = UiKit.button(group, "✕", "Ghost", onClose)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.fromScale(1, 0)
	close.Size = UDim2.fromOffset(40, 40)
	close.TextSize = 20
	local body = HudKit.make("Frame", group, {
		Name = "Body", Position = UDim2.fromOffset(0, 78), Size = UDim2.new(1, 0, 1, -78), BackgroundTransparency = 1,
	}) :: Frame
	return {
		Root = root, Holder = holder, Group = canvas, Edge = edge, Shadow = shadow, Backdrop = backdrop, Body = body,
		Title = titleLabel, Subtitle = subtitleLabel, Close = close, Scale = scale, Serial = 0,
	}
end

function Window.isOpen(w: Window): boolean
	return w.Root.Visible and w.Root:GetAttribute("UiClosing") ~= true
end

function Window.open(w: Window)
	w.Serial += 1
	w.Root:SetAttribute("UiClosing", false)
	w.Scale.Scale = M.OpenFrom
	w.Group.GroupTransparency = 1
	w.Holder.Position = UDim2.new(0.5, 0, 0.5, M.SlidePixels)
	w.Root.Visible = true
	UiKit.play("Open")
	TweenService:Create(w.Scale, M.Open, { Scale = 1 }):Play()
	TweenService:Create(w.Holder, M.Open, { Position = UDim2.fromScale(0.5, 0.5) }):Play()
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
	TweenService:Create(w.Scale, M.Close, { Scale = M.OpenFrom }):Play()
	TweenService:Create(w.Shadow, M.Close, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(w.Edge, M.Close, { Transparency = 1 }):Play()
	TweenService:Create(w.Backdrop, M.Close, { BackgroundTransparency = 1 }):Play()
	local fade = TweenService:Create(w.Group, M.Close, { GroupTransparency = 1 })
	fade.Completed:Connect(function()
		if w.Serial == serial then
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
