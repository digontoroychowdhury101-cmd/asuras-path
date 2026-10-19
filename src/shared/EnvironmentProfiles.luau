--!strict
-- Shared authoring values. The server supplies the shrine baseline; each client blends its biome.
local rgb = Color3.fromRGB
local Profiles = {}
local function profile(clock: number, ambient: Color3, outdoor: Color3, tint: Color3, mist: Color3,
	density: number, haze: number, exposure: number, rays: number, saturation: number): any
	return {
		Lighting = { ClockTime = clock, Ambient = ambient, OutdoorAmbient = outdoor, Brightness = 2,
			ExposureCompensation = exposure, EnvironmentDiffuseScale = 0.55, EnvironmentSpecularScale = 1,
			ColorShift_Top = tint, ColorShift_Bottom = rgb(16, 18, 25), ShadowSoftness = 0.24 },
		CB_Atmosphere = { Density = density, Haze = haze, Color = mist, Decay = ambient, Glare = 0.15, Offset = 0.1 },
		CB_ColorCorrection = { TintColor = tint, Saturation = saturation, Contrast = 0.2, Brightness = 0 },
		CB_SunRays = { Spread = 0.4, Intensity = rays },
		CB_Bloom = { Intensity = 0.15, Threshold = 2.2, Size = 24 },
	}
end
Profiles.Sanctuary = profile(17 + 40/60, rgb(42, 38, 37), rgb(80, 75, 70), rgb(255, 237, 212), rgb(224, 191, 142), 0.35, 1.8, 0.05, 0.25, -0.08)
Profiles.DesecratedMonastery = profile(15, rgb(38, 43, 52), rgb(67, 73, 83), rgb(206, 220, 238), rgb(143, 155, 170), 0.4, 2.5, -0.22, 0.015, -0.45)
Profiles.BambooPass = profile(16, rgb(34, 48, 44), rgb(76, 91, 79), rgb(219, 235, 221), rgb(158, 181, 165), 0.38, 2.2, -0.1, 0.06, -0.22)
Profiles.AshColosseum = profile(0.15, rgb(27, 23, 27), rgb(47, 40, 43), rgb(217, 191, 184), rgb(69, 61, 66), 0.5, 3.8, -0.3, 0, -0.48)
Profiles.SanctuaryDepths = profile(0, rgb(20, 28, 35), rgb(32, 42, 49), rgb(175, 211, 222), rgb(45, 66, 73), 0.52, 4, -0.3, 0, -0.35)
Profiles.CelestialPagoda = profile(17.5, rgb(46, 34, 39), rgb(81, 61, 65), rgb(245, 208, 190), rgb(153, 111, 108), 0.4, 2.4, -0.08, 0.08, -0.22)
Profiles.SkyCitadel = profile(18.4, rgb(31, 38, 57), rgb(64, 75, 101), rgb(211, 219, 250), rgb(123, 139, 182), 0.38, 2.5, -0.1, 0.06, -0.26)
Profiles.Cataclysm = profile(0.15, rgb(52, 13, 20), rgb(90, 28, 36), rgb(255, 162, 166), rgb(120, 35, 43), 0.51, 3.9, -0.2, 0, -0.2)

function Profiles.resolve(region: string?, encounter: boolean, phase: number): string
	if encounter and phase >= 2 then return "Cataclysm" end
	if encounter then return "AshColosseum" end
	return if region and type((Profiles :: any)[region]) == "table" then region else "Sanctuary"
end
function Profiles.acoustics(region: string, position: Vector3): string
	if region == "SanctuaryDepths" then return "Cloister" end
	if region == "DesecratedMonastery" then
		if position.Z < -940 and position.Z > -985 then return "Ravine" end
		if position.Z < -990 or (position.Z < -870 and position.Z > -940) then return "Cloister" end
	end
	return "Open"
end
return table.freeze(Profiles)
