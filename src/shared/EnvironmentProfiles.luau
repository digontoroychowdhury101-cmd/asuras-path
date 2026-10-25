--!strict
-- Shared authoring values. The server supplies the shrine baseline; each client blends its biome.
-- Boss fights use the arena biome's own combat treatment ("Combat:<Region>"), and the second
-- phase deepens it atmospherically ("Unbound:<Region>") without lowering the neutral fill floor.
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
-- The Shrine at golden hour (lobby rebuild 2026-10-21): low sun in the west, warm haze over the sea of
-- clouds under the Sanctuary skybox, and enough neutral fill to read floors, faces and the pale statue.
-- Real aerial perspective separates the carved courtyard, the sacred terrace and the remote peaks.
-- Future / Realistic lighting is baked into default.project.json (the runtime cannot change it).
Profiles.Sanctuary = profile(17.4, rgb(60, 70, 92), rgb(105, 117, 139), rgb(255, 245, 226), rgb(250, 215, 185), 0.38, 2.2, -0.12, 0.12, 0.05)
Profiles.Sanctuary.Lighting.Brightness, Profiles.Sanctuary.Lighting.EnvironmentDiffuseScale = 2.2, 0.65
Profiles.Sanctuary.Lighting.ColorShift_Bottom = rgb(32, 40, 53)
Profiles.Sanctuary.CB_Atmosphere.Decay, Profiles.Sanctuary.CB_Atmosphere.Glare, Profiles.Sanctuary.CB_Atmosphere.Offset = rgb(120, 130, 165), 0.35, 0.2
Profiles.Sanctuary.CB_ColorCorrection.TintColor, Profiles.Sanctuary.CB_ColorCorrection.Contrast = rgb(255, 246, 236), 0.15
Profiles.Sanctuary.CB_SunRays.Spread = 0.45
Profiles.Sanctuary.CB_Bloom = { Intensity = 0.25, Threshold = 2.0, Size = 24 }
Profiles.DesecratedMonastery = profile(15, rgb(38, 43, 52), rgb(67, 73, 83), rgb(206, 220, 238), rgb(143, 155, 170), 0.4, 2.5, -0.22, 0.015, -0.45)
Profiles.BambooPass = profile(16, rgb(34, 48, 44), rgb(76, 91, 79), rgb(219, 235, 221), rgb(158, 181, 165), 0.38, 2.2, -0.1, 0.06, -0.22)
-- Night stays night (ashen sky), but walking it needs crypt-level fill: at 27/47 fill, -0.3 exposure and
-- 3.8 haze the road, court and arena walls read near-black at character height (Studio F17).
Profiles.AshColosseum = profile(0.15, rgb(52, 45, 50), rgb(88, 76, 80), rgb(217, 191, 184), rgb(84, 74, 80), 0.42, 2.8, -0.12, 0, -0.4)
-- The Sunken Crypt (batch 19) reads by pale, cool fill and its lanterns instead of near-black mist.
Profiles.SanctuaryDepths = profile(0, rgb(48, 56, 64), rgb(74, 86, 94), rgb(186, 214, 224), rgb(72, 94, 102), 0.4, 2.6, -0.12, 0, -0.28)
Profiles.CelestialPagoda = profile(17.5, rgb(46, 34, 39), rgb(81, 61, 65), rgb(245, 208, 190), rgb(153, 111, 108), 0.4, 2.4, -0.08, 0.08, -0.22)
Profiles.SkyCitadel = profile(18.4, rgb(31, 38, 57), rgb(64, 75, 101), rgb(211, 219, 250), rgb(123, 139, 182), 0.38, 2.5, -0.1, 0.06, -0.26)

-- Combat readability floor: every fight keeps this much neutral fill and this little mist, so
-- actors, weapons and the arena edge read at play distance without any attack effect active.
Profiles.Floor = table.freeze({ Ambient = 60, Outdoor = 95, Exposure = -0.1, Density = 0.34, Haze = 2.2 })
function Profiles.luminance(c: Color3): number
	return (0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B) * 255
end
-- Warm a colour toward blood red while keeping its luminance (phase two must not get darker).
local function crimson(c: Color3, amount: number): Color3
	local shifted = Color3.new(c.R * (1 + 0.6 * amount), c.G * (1 - 0.35 * amount), c.B * (1 - 0.3 * amount))
	local scale = Profiles.luminance(c) / math.max(Profiles.luminance(shifted), 1e-3)
	return Color3.new(math.min(shifted.R * scale, 1), math.min(shifted.G * scale, 1), math.min(shifted.B * scale, 1))
end
local function unbound(base: any): any
	local l, a, c = base.Lighting, base.CB_Atmosphere, base.CB_ColorCorrection
	local p = profile(l.ClockTime, crimson(l.Ambient, 0.5), crimson(l.OutdoorAmbient, 0.4), crimson(l.ColorShift_Top, 0.55),
		crimson(a.Color, 0.7), math.min(a.Density + 0.03, Profiles.Floor.Density), math.min(a.Haze + 0.3, Profiles.Floor.Haze),
		l.ExposureCompensation, 0, c.Saturation + 0.12)
	p.CB_ColorCorrection.Contrast = 0.24
	return p
end

-- Per-biome fight treatment: same palette family as the exploration profile, raised fill, thinner
-- mist. Fill/Brazier colour the arena lanterns (ArenaLighting); night arenas stay night.
local combat: { [string]: any } = {
	Sanctuary = profile(17.4, rgb(100, 104, 119), rgb(143, 150, 166), rgb(255, 225, 190), rgb(250, 215, 185), 0.32, 2, 0.02, 0.12, 0.05),
	DesecratedMonastery = profile(14.5, rgb(66, 72, 82), rgb(112, 118, 128), rgb(218, 226, 238), rgb(150, 160, 172), 0.3, 1.8, -0.05, 0.02, -0.3),
	BambooPass = profile(15.5, rgb(62, 76, 70), rgb(110, 126, 114), rgb(226, 238, 226), rgb(166, 186, 170), 0.28, 1.6, -0.02, 0.05, -0.15),
	AshColosseum = profile(0.15, rgb(80, 70, 72), rgb(122, 108, 108), rgb(232, 206, 198), rgb(92, 80, 84), 0.3, 1.8, 0, 0, -0.3),
	SanctuaryDepths = profile(0, rgb(66, 80, 90), rgb(100, 118, 128), rgb(196, 222, 230), rgb(64, 88, 96), 0.32, 2, -0.02, 0, -0.22),
	CelestialPagoda = profile(17.3, rgb(76, 62, 66), rgb(124, 104, 106), rgb(248, 220, 204), rgb(166, 128, 124), 0.3, 1.8, 0, 0.06, -0.12),
	SkyCitadel = profile(17.8, rgb(62, 70, 92), rgb(110, 120, 150), rgb(222, 228, 252), rgb(136, 150, 190), 0.28, 1.8, -0.02, 0.05, -0.15),
}
combat.Sanctuary.CB_Atmosphere.Decay = rgb(120, 130, 165)
combat.Sanctuary.CB_Atmosphere.Offset, combat.Sanctuary.CB_Atmosphere.Glare = 0.2, 0.35
local arenas: { [string]: { Fill: Color3, Brazier: Color3 } } = {
	Sanctuary = { Fill = rgb(255, 236, 214), Brazier = rgb(255, 170, 96) },
	DesecratedMonastery = { Fill = rgb(214, 224, 240), Brazier = rgb(255, 161, 84) },
	BambooPass = { Fill = rgb(226, 240, 222), Brazier = rgb(255, 176, 104) },
	AshColosseum = { Fill = rgb(246, 226, 210), Brazier = rgb(255, 150, 76) },
	SanctuaryDepths = { Fill = rgb(206, 230, 240), Brazier = rgb(255, 168, 110) },
	CelestialPagoda = { Fill = rgb(255, 232, 214), Brazier = rgb(255, 160, 96) },
	SkyCitadel = { Fill = rgb(220, 228, 255), Brazier = rgb(255, 172, 112) },
}
Profiles.UnboundBrazier = rgb(255, 64, 72)
local byKey: { [string]: any } = {}
for region, values in combat do
	byKey["Combat:" .. region] = values
	byKey["Unbound:" .. region] = unbound(values)
end
Profiles.Biomes = table.freeze(table.clone(combat))

function Profiles.get(key: string): any
	return byKey[key] or (Profiles :: any)[key]
end
function Profiles.arena(region: string?): { Fill: Color3, Brazier: Color3 }
	return arenas[region or ""] or arenas.Sanctuary
end
-- `arena` is the boss arena's region; the fight's look follows the arena, not the camera's spot.
function Profiles.resolve(region: string?, encounter: boolean, phase: number, arena: string?): string
	if encounter then
		local biome = arena or region
		local id = if biome and combat[biome] then biome else "Sanctuary"
		return (if phase >= 2 then "Unbound:" else "Combat:") .. id
	end
	return if region and type((Profiles :: any)[region]) == "table" and combat[region] then region else "Sanctuary"
end
function Profiles.isUnbound(key: string): boolean
	return string.sub(key, 1, 8) == "Unbound:"
end
-- The ashen night skybox: the Colosseum itself and every second phase.
function Profiles.nightSky(key: string): boolean
	return Profiles.isUnbound(key) or key == "AshColosseum" or key == "Combat:AshColosseum"
end
-- Which skybox a profile uses: the ashen night set, the Shrine's golden hour, or the place default.
function Profiles.skyFor(key: string): string?
	if Profiles.nightSky(key) then return "Night" end
	if key == "Sanctuary" or key == "Combat:Sanctuary" then return "Sunset" end
	return nil
end
-- Drifting ash belongs to the Colosseum only (it competes with telegraphs elsewhere).
function Profiles.ashFall(key: string): boolean
	return key == "AshColosseum" or key == "Combat:AshColosseum" or key == "Unbound:AshColosseum"
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
