--!strict
-- Screen-space layer for the showcase sorceries: colour grading pulses (blackout, solarized burst,
-- whiteout) and 2D anime impact frames (sunburst discs, radial speed lines, character silhouette with
-- a coloured rim). Palettes give each spell its own frame and its negative. Local caster only;
-- reduced flashes keeps a share of every grade via EffectsPreference.flash and shortens frames.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Effects = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.EffectsPreference) :: any
local Kit = require(script.Parent.SkillKit)
local Screen = {}

local rgb = Color3.fromRGB
Screen.Yellow = rgb(251, 252, 29)
Screen.Pale = rgb(255, 245, 157)
Screen.Ink = rgb(15, 2, 2)
local WHITE = Color3.new(1, 1, 1)
local NEUTRAL = { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = WHITE }

export type Palette = { Back: Color3, Rings: { Color3 }, Lines: Color3, Body: Color3, Rim: Color3, Flat: boolean? }
Screen.Palettes = table.freeze({
	Fire = { Back = rgb(255, 140, 0), Rings = { Screen.Yellow, Screen.Pale, WHITE }, Lines = Screen.Ink, Body = Screen.Ink, Rim = rgb(150, 12, 10) },
	FireNegative = { Back = Screen.Ink, Rings = { rgb(120, 8, 6), rgb(255, 69, 0), Screen.Yellow }, Lines = Screen.Pale, Body = WHITE, Rim = rgb(255, 69, 0), Flat = true },
	Celestial = { Back = rgb(6, 12, 30), Rings = { rgb(0, 120, 140), rgb(0, 255, 255), WHITE }, Lines = WHITE, Body = Screen.Ink, Rim = rgb(255, 170, 0) },
	CelestialNegative = { Back = WHITE, Rings = { rgb(190, 250, 255), rgb(120, 230, 240), WHITE }, Lines = rgb(4, 20, 40), Body = rgb(4, 8, 18), Rim = rgb(0, 200, 210) },
})

function Screen.grade(trove: Kit.Trove): ColorCorrectionEffect
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "AsuraSkillGrade"
	cc.Parent = Lighting
	return Kit.add(trove, cc)
end

-- Snap to a grade now, hold it, then ease back to neutral over `fade` seconds.
function Screen.pulse(trove: Kit.Trove, cc: ColorCorrectionEffect, goal: { [string]: any }, hold: number, fade: number)
	cc.Brightness = Effects.flash(goal.Brightness or 0)
	cc.Contrast = Effects.flash(goal.Contrast or 0)
	cc.Saturation = goal.Saturation or 0
	cc.TintColor = goal.TintColor or NEUTRAL.TintColor
	Kit.after(trove, hold, function()
		if fade <= 0 then
			for key, value in NEUTRAL do (cc :: any)[key] = value end
		else
			Kit.tween(trove, cc, fade, NEUTRAL, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		end
	end)
end

-- Eases a grade toward `goal` and leaves it there (void dimming, stance tension).
function Screen.settle(trove: Kit.Trove, cc: ColorCorrectionEffect, goal: { [string]: any }, seconds: number)
	local scaled = table.clone(goal)
	if scaled.Brightness then scaled.Brightness = Effects.flash(scaled.Brightness) end
	Kit.tween(trove, cc, seconds, scaled, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
end

local function silhouette(parent: Instance, model: Model, view: CFrame, fov: number, tint: Color3, scale: number, z: number, flat: boolean?)
	local viewport = Instance.new("ViewportFrame")
	viewport.Size, viewport.AnchorPoint = UDim2.fromScale(scale, scale), Vector2.new(0.5, 0.5)
	viewport.Position, viewport.BackgroundTransparency, viewport.ZIndex = UDim2.fromScale(0.5, 0.5), 1, z
	viewport.Ambient, viewport.LightColor, viewport.ImageColor3 = WHITE, WHITE, tint
	local camera = Instance.new("Camera")
	camera.CFrame, camera.FieldOfView, camera.Parent = view, fov, viewport
	viewport.CurrentCamera = camera
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local was = model.Archivable
	model.Archivable = true
	local clone = model:Clone()
	model.Archivable = was
	if not clone then return end
	for _, d in clone:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("GuiBase") or d:IsA("Constraint") or d:IsA("Beam") then
			d:Destroy()
		elseif flat and (d:IsA("Decal") or d:IsA("SurfaceAppearance") or d:IsA("Clothing")) then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			if flat then d.Color, d.Material = WHITE, Enum.Material.Neon end
		end
	end
	clone.Parent = world
	viewport.Parent = parent
end

-- Impact frame over `seconds` in `palette`: sunburst discs, speed lines re-cut every frame like
-- hand-drawn smears, and the caster's silhouette with a coloured rim exactly where it stands.
function Screen.frame(trove: Kit.Trove, model: Model, seconds: number, palette: Palette)
	local player = Players.LocalPlayer
	local camera = Workspace.CurrentCamera
	if not player or not camera then return end
	if Effects.reducedFlashes() then seconds *= 0.5 end
	local gui = Kit.add(trove, Instance.new("ScreenGui"))
	gui.Name, gui.IgnoreGuiInset, gui.DisplayOrder, gui.ResetOnSpawn = "AsuraImpactFrame", true, 60, false
	local back = Instance.new("Frame")
	back.Size, back.BackgroundColor3, back.BorderSizePixel = UDim2.fromScale(1, 1), palette.Back, 0
	back.Parent = gui
	for n, ring in { 1.9, 1.15, 0.55 } do
		local disc = Instance.new("Frame")
		disc.AnchorPoint, disc.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
		disc.Size, disc.BackgroundColor3, disc.BorderSizePixel, disc.ZIndex = UDim2.fromScale(ring, ring), palette.Rings[n], 0, 1 + n
		local aspect, corner = Instance.new("UIAspectRatioConstraint"), Instance.new("UICorner")
		aspect.DominantAxis, aspect.Parent, corner.CornerRadius, corner.Parent = Enum.DominantAxis.Height, disc, UDim.new(0.5, 0), disc
		disc.Parent = back
	end
	local size = camera.ViewportSize
	local reach = size.Magnitude * 0.5
	local lines: { Frame } = {}
	for n = 1, 48 do
		local line = Instance.new("Frame")
		line.AnchorPoint, line.BackgroundColor3, line.BorderSizePixel, line.ZIndex = Vector2.new(0.5, 0.5), palette.Lines, 0, 6
		local fade = Instance.new("UIGradient")
		fade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 0.6), NumberSequenceKeypoint.new(1, 0) })
		fade.Parent = line
		line.Parent = back
		lines[n] = line
	end
	local function scatter()
		for n, line in lines do
			local angle = (n / #lines) * math.pi * 2 + (math.random() - 0.5) * 0.12
			local length = reach * (0.5 + math.random() * 0.5)
			local mid = size / 2 + Vector2.new(math.cos(angle), math.sin(angle)) * (reach - length / 2)
			line.Size = UDim2.fromOffset(length, 2 + math.random() * 8)
			line.Position, line.Rotation = UDim2.fromOffset(mid.X, mid.Y), math.deg(angle)
		end
	end
	scatter()
	silhouette(back, model, camera.CFrame, camera.FieldOfView, palette.Rim, 1.03, 7, palette.Flat)
	silhouette(back, model, camera.CFrame, camera.FieldOfView, palette.Body, 1, 8, palette.Flat)
	gui.Parent = player:FindFirstChildOfClass("PlayerGui")
	Kit.add(trove, task.spawn(function()
		local stop = os.clock() + seconds
		while os.clock() < stop and gui.Parent do
			task.wait(1 / 30)
			scatter()
		end
		gui:Destroy()
	end))
end

Screen.silhouette = silhouette -- the caster drawn exactly where they stand, for other 2D layers

return table.freeze(Screen)
