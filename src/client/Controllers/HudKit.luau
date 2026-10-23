--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/HudKit
-- Shared presentation kit for HUD modules: the ink-and-ivory palette, instance helpers, a
-- viewport-driven UIScale binding (so panels authored at 1080p shrink on phones and grow on large
-- displays) and a one-shot UI cue sound. Pure presentation; never talks to the server.
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")

local HudKit = {}

HudKit.Palette = table.freeze({ -- sakura theme; SakuraKit.Colors holds the full set
	Ink = Color3.fromRGB(22, 10, 20),
	Ivory = Color3.fromRGB(255, 240, 246),
	Muted = Color3.fromRGB(190, 156, 176),
	Blood = Color3.fromRGB(196, 22, 38),
	Ember = Color3.fromRGB(247, 168, 200),
	Gold = Color3.fromRGB(236, 196, 120),
	Edge = Color3.fromRGB(150, 60, 110),
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
