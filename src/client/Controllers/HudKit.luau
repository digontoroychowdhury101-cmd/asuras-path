--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/HudKit
-- Shared presentation kit for HUD modules: the ink-and-ivory palette, instance helpers, a
-- viewport-driven UIScale binding (so panels authored at 1080p shrink on phones and grow on large
-- displays) and a one-shot UI cue sound. Pure presentation; never talks to the server.
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")

local HudKit = {}

HudKit.Palette = table.freeze({
	Ink = Color3.fromRGB(14, 10, 9),
	Ivory = Color3.fromRGB(236, 226, 206),
	Muted = Color3.fromRGB(150, 140, 126),
	Blood = Color3.fromRGB(176, 22, 24),
	Ember = Color3.fromRGB(232, 132, 52),
	Gold = Color3.fromRGB(232, 188, 76),
	Edge = Color3.fromRGB(110, 36, 30),
})

HudKit.TitleFont = Enum.Font.Antique
HudKit.BodyFont = Enum.Font.Garamond

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

-- Ink panel with the house red edge, matching the altar menu and loadout styling.
function HudKit.panel(parent: Instance, name: string, properties: { [string]: any }): Frame
	local frame = HudKit.make("Frame", parent, {
		Name = name,
		BackgroundColor3 = HudKit.Palette.Ink,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
	}) :: Frame
	for key, value in properties do
		(frame :: any)[key] = value
	end
	HudKit.make("UICorner", frame, { CornerRadius = UDim.new(0, 6) })
	HudKit.make("UIStroke", frame, { Color = HudKit.Palette.Edge, Thickness = 1, Transparency = 0.2 })
	return frame
end

function HudKit.factor(): number
	local camera = Workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else REFERENCE_HEIGHT
	if height <= 1 then
		return 1
	end
	return math.clamp(height / REFERENCE_HEIGHT, MIN_FACTOR, MAX_FACTOR)
end

-- Adds (or reuses) a UIScale on `target` whose scale is `base * factor()`, kept current as the
-- viewport resizes or the camera is replaced. Returns a disconnect function.
function HudKit.bindScale(target: GuiObject, base: number): () -> ()
	local scale = target:FindFirstChildOfClass("UIScale") or HudKit.make("UIScale", target, {})
	local viewportConnection: RBXScriptConnection? = nil
	local function refresh()
		scale.Scale = base * HudKit.factor()
	end
	local function watch()
		if viewportConnection then
			viewportConnection:Disconnect()
		end
		local camera = Workspace.CurrentCamera
		viewportConnection = if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(refresh) else nil
		refresh()
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
