--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/HudKit
-- Shared presentation kit for HUD modules: the ink-and-ivory palette, instance helpers, a
-- viewport-driven UIScale binding (so panels authored at 1080p shrink on phones and grow on large
-- displays) and a one-shot UI cue sound. Pure presentation; never talks to the server.
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")

local HudKit = {}

HudKit.Palette = table.freeze({
	Ink = Color3.fromRGB(18, 18, 17),
	Ivory = Color3.fromRGB(245, 237, 222),
	Muted = Color3.fromRGB(190, 177, 155),
	Blood = Color3.fromRGB(181, 69, 57),
	Ember = Color3.fromRGB(232, 163, 119),
	Gold = Color3.fromRGB(225, 195, 145),
	Edge = Color3.fromRGB(158, 135, 101),
	Jade = Color3.fromRGB(121, 176, 152),
})

HudKit.TitleFont = Enum.Font.Antique
HudKit.BodyFont = Enum.Font.Gotham

-- Reference viewport height the HUD was authored against, and the factor clamp. The floor keeps
-- text legible on landscape phones (~360 px tall); the ceiling stops panels ballooning on TVs.
local REFERENCE_HEIGHT = 900
local MIN_FACTOR = 0.7
local MAX_FACTOR = 1.35

function HudKit.make(className: string, parent: Instance?, properties: { [string]: any }): any
	local instance = Instance.new(className :: any)
	for key, value in properties do
		(instance :: any)[key] = value
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function HudKit.label(parent: Instance, text: string, size: number, font: Enum.Font, color: Color3, properties: { [string]: any }?): TextLabel
	local result = HudKit.make("TextLabel", parent, {
		Text = text,
		TextSize = size,
		Font = font,
		TextColor3 = color,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		TextStrokeTransparency = 0.6,
		TextStrokeColor3 = HudKit.Palette.Ink,
	}) :: TextLabel
	for key, value in properties or {} do
		(result :: any)[key] = value
	end
	return result
end

function HudKit.panel(parent: Instance, name: string, properties: { [string]: any }): Frame
	local frame = HudKit.make("Frame", parent, {
		Name = name,
		BackgroundColor3 = HudKit.Palette.Ink,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
	}) :: Frame
	for key, value in properties do
		(frame :: any)[key] = value
	end
	HudKit.make("UIStroke", frame, { Color = HudKit.Palette.Edge, Thickness = 1, Transparency = 0.55 })
	return frame
end

-- Fine score marks and a short inner return suggest a beveled frame without boxing its contents.
function HudKit.inlay(parent: GuiObject, length: number)
	for _, x in { 0, 1 } do
		for _, y in { 0, 1 } do
			local corner = HudKit.make("Frame", parent, {
				Name = "Inlay", AnchorPoint = Vector2.new(x, y),
				Position = UDim2.new(x, if x == 0 then 7 else -7, y, if y == 0 then 7 else -7),
				Size = UDim2.fromOffset(length, length), BackgroundTransparency = 1, ZIndex = parent.ZIndex + 2,
			})
			for _, line in {
				{ Size = UDim2.new(1, 0, 0, 1), Inset = 0, Color = HudKit.Palette.Edge },
				{ Size = UDim2.new(0, 1, 1, 0), Inset = 0, Color = HudKit.Palette.Edge },
				{ Size = UDim2.fromOffset(math.floor(length * 0.45), 1), Inset = 4, Color = HudKit.Palette.Gold },
				{ Size = UDim2.fromOffset(1, math.floor(length * 0.45)), Inset = 4, Color = HudKit.Palette.Gold },
			} do
				HudKit.make("Frame", corner, {
					AnchorPoint = Vector2.new(x, y), Position = UDim2.new(x, (1 - 2 * x) * line.Inset, y, (1 - 2 * y) * line.Inset),
					Size = line.Size, BorderSizePixel = 0, BackgroundColor3 = line.Color, ZIndex = corner.ZIndex,
				})
			end
		end
	end
end

function HudKit.factor(): number
	local camera = Workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else REFERENCE_HEIGHT
	if height <= 1 then
		return 1
	end
	return math.clamp(height / REFERENCE_HEIGHT, MIN_FACTOR, MAX_FACTOR)
end

-- Calls `refresh(viewportSize)` now and whenever the viewport resizes or the camera is replaced.
-- Returns a disconnect function.
function HudKit.onViewport(refresh: (Vector2) -> ()): () -> ()
	local viewportConnection: RBXScriptConnection? = nil
	local function watch()
		if viewportConnection then
			viewportConnection:Disconnect()
		end
		local camera = Workspace.CurrentCamera
		viewportConnection = if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			refresh(camera.ViewportSize)
		end) else nil
		refresh(if camera then camera.ViewportSize else Vector2.new(REFERENCE_HEIGHT * 16 / 9, REFERENCE_HEIGHT))
	end
	local cameraConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watch)
	watch()
	return function()
		cameraConnection:Disconnect()
		if viewportConnection then
			viewportConnection:Disconnect()
		end
	end
end

-- Adds (or reuses) a UIScale on `target` whose scale is `base * factor()`, kept current as the
-- viewport resizes or the camera is replaced. Returns a disconnect function.
-- A device profile may override the base through the AsuraScaleBase attribute (DeviceLayout).
-- minScale (desktop only) keeps survival values readable on small windows (HudLayout MinScale).
function HudKit.bindScale(target: GuiObject, base: number, minScale: number?): () -> ()
	local scale = target:FindFirstChildOfClass("UIScale") or HudKit.make("UIScale", target, {})
	return HudKit.onViewport(function()
		local override = target:GetAttribute("AsuraScaleBase")
		scale.Scale = if type(override) == "number" then override * HudKit.factor() else math.max(base * HudKit.factor(), minScale or 0)
	end)
end

-- Built-in content sounds only (rbxasset://), so cues work offline and in Studio.
HudKit.Sounds = table.freeze({
	Objective = "rbxasset://sounds/action_get_up.mp3",
	Tick = "rbxasset://sounds/volume_slider.ogg",
})

function HudKit.cue(id: string, volume: number, pitch: number)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = pitch
	SoundService:PlayLocalSound(sound)
	task.delay(3, function()
		sound:Destroy()
	end)
end

return HudKit
