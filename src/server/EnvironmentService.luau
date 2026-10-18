--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/EnvironmentService
-- Applies Config.Lighting at runtime so the place file and the live server always agree: the
-- Overcast sanctuary sun, colour shift, Atmosphere, SunRays, Bloom, colour correction and
-- depth of field. Effects are created by name if missing and updated in place if present.
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("AsurasPath"):WaitForChild("Config") :: ModuleScript) :: any

local Environment = {}

local function color(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function effect(name: string, className: string): Instance
	local existing = Lighting:FindFirstChild(name)
	if existing then
		assert(existing.ClassName == className, "Unexpected class at Lighting/" .. name)
		return existing
	end
	local created = Instance.new(className :: any)
	created.Name = name
	created.Parent = Lighting
	return created
end

function Environment.Apply()
	local l = Config.Lighting
	Workspace.Gravity = Config.Workspace.Gravity
	local wind = Config.Workspace.GlobalWind
	Workspace.GlobalWind = Vector3.new(wind[1], wind[2], wind[3])

	Lighting.Brightness = l.Brightness
	Lighting.ClockTime = l.ClockTime
	Lighting.GeographicLatitude = l.GeographicLatitude
	Lighting.Ambient = color(l.Ambient)
	Lighting.OutdoorAmbient = color(l.OutdoorAmbient)
	Lighting.ColorShift_Top = color(l.ColorShiftTop)
	Lighting.ColorShift_Bottom = color(l.ColorShiftBottom)
	Lighting.EnvironmentDiffuseScale = l.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = l.EnvironmentSpecularScale
	Lighting.GlobalShadows = l.GlobalShadows
	Lighting.ShadowSoftness = l.ShadowSoftness
	Lighting.ExposureCompensation = l.ExposureCompensation
	Lighting.FogColor = color(l.FogColor)
	Lighting.FogStart = l.FogStart
	Lighting.FogEnd = l.FogEnd
	-- Technology and quality are baked into the place; Studio restricts writing them at runtime.
	if Lighting.LightingStyle ~= Enum.LightingStyle.Realistic or Lighting.PrioritizeLightingQuality ~= l.PrioritizeLightingQuality then
		warn("[AsurasPath] In Studio set LightingStyle=Realistic and PrioritizeLightingQuality=true.")
	end
	if Workspace.StreamingEnabled ~= Config.Workspace.StreamingEnabled then
		warn("[AsurasPath] In Studio set Workspace.StreamingEnabled to the Config value.")
	end
	if Workspace.FallenPartsDestroyHeight ~= Config.Workspace.FallenPartsDestroyHeight then
		warn("[AsurasPath] In Studio set Workspace.FallenPartsDestroyHeight to the Config value.")
	end

	local cc = effect("CB_ColorCorrection", "ColorCorrectionEffect") :: ColorCorrectionEffect
	cc.Enabled = l.ColorCorrection.Enabled
	cc.Brightness = l.ColorCorrection.Brightness
	cc.Contrast = l.ColorCorrection.Contrast
	cc.Saturation = l.ColorCorrection.Saturation
	cc.TintColor = color(l.ColorCorrection.TintColor)

	local bloom = effect("CB_Bloom", "BloomEffect") :: BloomEffect
	bloom.Enabled = l.Bloom.Enabled
	bloom.Intensity = l.Bloom.Intensity
	bloom.Size = l.Bloom.Size
	bloom.Threshold = l.Bloom.Threshold

	local dof = effect("CB_DepthOfField", "DepthOfFieldEffect") :: DepthOfFieldEffect
	dof.Enabled = l.DepthOfField.Enabled
	dof.FarIntensity = l.DepthOfField.FarIntensity
	dof.NearIntensity = l.DepthOfField.NearIntensity
	dof.FocusDistance = l.DepthOfField.FocusDistance
	dof.InFocusRadius = l.DepthOfField.InFocusRadius

	local atmosphere = effect("CB_Atmosphere", "Atmosphere") :: Atmosphere
	atmosphere.Density = l.Atmosphere.Density
	atmosphere.Offset = l.Atmosphere.Offset
	atmosphere.Haze = l.Atmosphere.Haze
	atmosphere.Glare = l.Atmosphere.Glare
	atmosphere.Color = color(l.Atmosphere.Color)
	atmosphere.Decay = color(l.Atmosphere.Decay)

	local rays = effect("CB_SunRays", "SunRaysEffect") :: SunRaysEffect
	rays.Enabled = l.SunRays.Enabled
	rays.Intensity = l.SunRays.Intensity
	rays.Spread = l.SunRays.Spread

	-- Only one Atmosphere renders; a second authored one would fight the configured sky.
	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") and child ~= atmosphere then
			warn("[AsurasPath] Extra Atmosphere in Lighting overrides the configured sky: " .. child.Name)
		end
	end
end

return table.freeze(Environment)
