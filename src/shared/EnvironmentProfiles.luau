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
Profiles.BambooPass = profile(15.3, rgb(81, 87, 80), rgb(121, 128, 116), rgb(255, 246, 230), rgb(188, 193, 181), 0.31, 1.55, 0.02, 0.045, -0.26)
Profiles.BambooPass.Lighting.EnvironmentDiffuseScale = 0.65
Profiles.BambooPass.Lighting.ColorShift_Bottom = rgb(28, 35, 32)
Profiles.BambooPass.CB_ColorCorrection.TintColor = rgb(255, 246, 231)
Profiles.BambooPass.CB_ColorCorrection.Contrast = 0.08
-- Night stays night (ashen sky), but walking it needs crypt-level fill: at 27/47 fill, -0.3 exposure and
-- 3.8 haze the road, court and arena walls read near-black at character height (Studio F17).
Profiles.AshColosseum = profile(0.15, rgb(52, 45, 50), rgb(88, 76, 80), rgb(217, 191, 184), rgb(84, 74, 80), 0.42, 2.8, -0.12, 0, -0.4)
-- The Sunken Crypt (batch 19) reads by pale, cool fill and its lanterns instead of near-black mist.
Profiles.SanctuaryDepths = profile(0, rgb(48, 56, 64), rgb(74, 86, 94), rgb(186, 214, 224), rgb(72, 94, 102), 0.4, 2.6, -0.12, 0, -0.28)
Profiles.CelestialPagoda = profile(17.5, rgb(46, 34, 39), rgb(81, 61, 65), rgb(245, 208, 190), rgb(153, 111, 108), 0.4, 2.4, -0.08, 0.08, -0.22)
Profiles.SkyCitadel = profile(18.4, rgb(31, 38, 57), rgb(64, 75, 101), rgb(211, 219, 250), rgb(123, 139, 182), 0.38, 2.5, -0.1, 0.06, -0.26)
-- The overworld's five biomes (ticket 08 minimum; weather and time of day are ticket 11). Each is a distinct
-- daylight: Bellwood humid green-gold, Amberfall warm dry haze, Saltreach bright and dry, Frostmere cold
-- blue-white, Ashen Stair cool grey. Fill stays well above the combat floor; the mist thins with altitude.
Profiles.Forest = profile(14.6, rgb(78, 92, 70), rgb(126, 140, 112), rgb(255, 244, 214), rgb(190, 200, 160), 0.34, 1.9, 0, 0.07, -0.05)
Profiles.GoldenRavine = profile(16.2, rgb(96, 80, 62), rgb(150, 128, 100), rgb(255, 230, 190), rgb(224, 190, 140), 0.3, 2, 0.02, 0.1, 0)
Profiles.AridBasin = profile(12.6, rgb(104, 98, 88), rgb(168, 158, 138), rgb(255, 248, 232), rgb(232, 222, 200), 0.18, 1.2, 0.08, 0.05, -0.1)
Profiles.Snowfields = profile(11.8, rgb(86, 98, 118), rgb(150, 164, 186), rgb(226, 238, 255), rgb(214, 226, 244), 0.3, 1.6, 0.05, 0.04, -0.2)
Profiles.MountainAscent = profile(13.4, rgb(76, 80, 88), rgb(124, 130, 142), rgb(226, 230, 238), rgb(172, 178, 188), 0.34, 1.9, -0.02, 0.03, -0.3)
-- C3 fault F: the biome mist above swallowed everything past ~600 studs in a teal wash. Clear overworld air is now thin
-- (Density <= 0.06), neutral blue-grey (Color / Decay per biome, no green or teal cast) with a raised Offset so far ridges and the
-- summit temple (5,000-7,000 studs out) read as silhouettes. Weather states and dusk still add on top (applyWeather / applyTime).
-- Only the five overworld biomes change; the lobby and combat profiles keep their values.
local air: { [string]: { number } } = {
	-- density, haze, mist colour, decay colour
	Forest = { 0.05, 0.4, 0xB0BECC, 0x5C6A7A },
	GoldenRavine = { 0.05, 0.5, 0xC0C0C6, 0x6E6E76 },
	AridBasin = { 0.035, 0.4, 0xC8CCD0, 0x76787C },
	Snowfields = { 0.05, 0.4, 0xCEDAEA, 0x78869E },
	MountainAscent = { 0.04, 0.4, 0xB0B8C6, 0x626A7A },
}
for region, v in air do
	local a = (Profiles :: any)[region].CB_Atmosphere
	a.Density, a.Haze, a.Offset = v[1], v[2], 0.35
	a.Color, a.Decay = rgb(v[3] // 0x10000, (v[3] // 0x100) % 0x100, v[3] % 0x100), rgb(v[4] // 0x10000, (v[4] // 0x100) % 0x100, v[4] % 0x100)
end

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
	Forest = profile(14.4, rgb(86, 100, 78), rgb(130, 146, 118), rgb(250, 240, 214), rgb(186, 198, 162), 0.28, 1.6, 0, 0.06, -0.05),
	GoldenRavine = profile(16, rgb(104, 88, 70), rgb(154, 132, 104), rgb(252, 230, 196), rgb(220, 188, 142), 0.26, 1.7, 0.02, 0.08, 0),
	AridBasin = profile(12.8, rgb(108, 102, 92), rgb(170, 160, 142), rgb(252, 246, 232), rgb(230, 220, 200), 0.2, 1.2, 0.06, 0.04, -0.08),
	Snowfields = profile(12, rgb(90, 102, 122), rgb(152, 166, 188), rgb(220, 232, 250), rgb(212, 224, 242), 0.26, 1.5, 0.04, 0.04, -0.15),
	MountainAscent = profile(13.6, rgb(80, 84, 92), rgb(128, 134, 146), rgb(224, 228, 238), rgb(172, 178, 188), 0.28, 1.6, 0, 0.03, -0.2),
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
	Forest = { Fill = rgb(236, 244, 222), Brazier = rgb(255, 176, 104) },
	GoldenRavine = { Fill = rgb(255, 240, 214), Brazier = rgb(255, 168, 96) },
	AridBasin = { Fill = rgb(250, 244, 228), Brazier = rgb(255, 172, 100) },
	Snowfields = { Fill = rgb(226, 238, 252), Brazier = rgb(255, 176, 112) },
	MountainAscent = { Fill = rgb(232, 236, 242), Brazier = rgb(255, 170, 104) },
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
	if region == "SanctuaryDepths" or region == "AshColosseum" then return "Cloister" end
	-- Amberfall's chasm: the sheltered floor and ledges below the rims (rims about Y 290) ring like a ravine.
	if region == "GoldenRavine" and position.Y < 285 and position.X > -6200 and position.X < -5780 and position.Z < -1550 and position.Z > -3950 then
		return "Ravine"
	end
	if region == "DesecratedMonastery" then
		if position.Z < -940 and position.Z > -985 then return "Ravine" end
		if position.Z < -990 or (position.Z < -870 and position.Z > -940) then return "Cloister" end
	end
	return "Open"
end

-------------------------------------------------------------------------------------------------
-- Overworld composition (ticket 11). Pure: no engine services, no requires. The client weather
-- controller supplies region weights (Overworld.blendAt), the world time and the flags; the single Lighting
-- owner (EnvironmentController) applies the result. Priority: boss > shelter > weather > time > biome.
-- Glare ceilings and the fill floors are enforced last, so no combination can blind or black out a player.
-------------------------------------------------------------------------------------------------

-- DayLength is real seconds per 24 world hours; the server publishes the epoch, clients derive the hour.
Profiles.Clock = table.freeze({ DayLength = 1800, StartHour = 14.5, SlotLength = 300, Ramp = 0.2 })
-- Exploration never reads darker than this (luminance 0..255), even at midnight in rain; fights use Floor.
Profiles.Night = table.freeze({ Ambient = 44, Outdoor = 72 })
-- Sunrise/sunset strength at full dusk factor: fill and sun brightness cut, exposure drop, extra fog density and haze.
-- win-80: no dusk exposure cut (Exposure 0): with the moonlight blend the sunset hour under the canopy was the darkest moment of the day.
Profiles.Horizon = table.freeze({ Fill = 0.2, Sun = 0.3, Exposure = 0, Density = 0.07, Haze = 0.8 })
-- Moonlight (win-80): at full night the fill blends to these and exposure rises by Exposure, so the overworld reads as blue moonlight
-- (path, trunks, silhouettes) instead of the old ~48/255 black under the canopy. Still dimmer than day; the sun is gone.
Profiles.Moon = table.freeze({ Ambient = rgb(74, 88, 124), Outdoor = rgb(100, 118, 162), Exposure = 0.3, Top = rgb(150, 175, 235) })
Profiles.Glare = table.freeze({ Bloom = 0.35, Threshold = 1.8, Rays = 0.12, Atmosphere = 0.4, Brightness = 2.4 })

-- Density/Haze add to the biome, Rays/Fill/Wind multiply, Sat adds, Tint lerps by Amount (all scaled by the state's weight).
local weather: { [string]: any } = {
	Clear = { Density = 0, Haze = 0, Rays = 1, Fill = 1, Sat = 0, Wind = 1, Tint = rgb(255, 255, 255), Amount = 0 },
	Overcast = { Density = 0.06, Haze = 0.5, Rays = 0.2, Fill = 0.94, Sat = -0.1, Wind = 1.1, Tint = rgb(205, 212, 222), Amount = 0.35 },
	Rain = { Density = 0.14, Haze = 1, Rays = 0, Fill = 0.9, Sat = -0.18, Wind = 1.5, Tint = rgb(190, 200, 214), Amount = 0.5, Precip = "Rain" },
	Snow = { Density = 0.18, Haze = 1.1, Rays = 0.1, Fill = 1, Sat = -0.25, Wind = 0.8, Tint = rgb(226, 234, 248), Amount = 0.4, Precip = "Snow" },
	Dust = { Density = 0.1, Haze = 1.5, Rays = 0.35, Fill = 0.95, Sat = -0.1, Wind = 1.8, Tint = rgb(236, 208, 164), Amount = 0.45, Precip = "Dust" },
}
Profiles.WeatherStates = table.freeze({ "Clear", "Overcast", "Rain", "Snow", "Dust" })
Profiles.Weather = weather
-- Odds per slot. Bellwood is the humid windward side; Amberfall and the Saltreach sit in the rain shadow (no rain).
local climate: { [string]: { [string]: number } } = {
	Forest = { Clear = 0.4, Overcast = 0.25, Rain = 0.35 },
	GoldenRavine = { Clear = 0.65, Overcast = 0.2, Dust = 0.15 },
	AridBasin = { Clear = 0.6, Overcast = 0.05, Dust = 0.35 },
	Snowfields = { Clear = 0.3, Overcast = 0.2, Snow = 0.5 },
	MountainAscent = { Clear = 0.3, Overcast = 0.3, Snow = 0.4 },
}
Profiles.Climate = climate

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end
local function lum(c: Color3): number
	return Profiles.luminance(c)
end
local function scaled(c: Color3, k: number): Color3
	return Color3.new(math.min(c.R * k, 1), math.min(c.G * k, 1), math.min(c.B * k, 1))
end
-- Raise a colour to at least `floor` luminance (never darkens it).
local function lift(c: Color3, floor: number): Color3
	local l = lum(c)
	if l >= floor then return c end
	if l < 1 then return Color3.new(floor / 255, floor / 255, floor / 255) end
	return scaled(c, floor / l)
end

-- Integer hash (exact in doubles) so every client and the server roll the same weather for a slot.
local function roll(region: string, slot: number): string
	local seed = 0
	for i = 1, #region do seed = (seed * 31 + string.byte(region, i)) % 1000003 end
	local x = (slot * 73856093 + seed * 19349663) % 2147483647
	x = (x * 48271) % 2147483647
	local r, odds, acc = x / 2147483647, climate[region], 0
	for _, state in Profiles.WeatherStates do
		acc += if odds then odds[state] or 0 else 0
		if r <= acc then return state end
	end
	return "Clear"
end

function Profiles.hourAt(t: number): number
	return (Profiles.Clock.StartHour + math.max(t, 0) / Profiles.Clock.DayLength * 24) % 24
end

-- State weights for one region at world time t (sums to 1): the previous slot's state fades into this slot's.
function Profiles.weatherMix(region: string, t: number): { [string]: number }
	local length = Profiles.Clock.SlotLength
	local slot = math.floor(math.max(t, 0) / length)
	local s = smooth((math.max(t, 0) / length - slot) / Profiles.Clock.Ramp)
	local mix: { [string]: number } = {}
	local now, before = roll(region, slot), roll(region, math.max(slot - 1, 0))
	mix[now] = s
	mix[before] = (mix[before] or 0) + (1 - s)
	return mix
end

-- The same across a margin: region weights (Overworld.blendAt) times each region's mix.
function Profiles.weatherBlend(weights: { [string]: number }, t: number): { [string]: number }
	local mix: { [string]: number } = {}
	for region, w in weights do
		for state, share in Profiles.weatherMix(region, t) do
			mix[state] = (mix[state] or 0) + w * share
		end
	end
	return mix
end

-- Weighted average of whole profiles (every profile() has the same shape; numbers and colours only).
local function average(entries: { { P: any, W: number } }): any
	local out: any = {}
	for name, values in entries[1].P do
		local group: any = {}
		for prop, v in values do
			if type(v) == "number" then
				local sum = 0
				for _, e in entries do sum += e.W * e.P[name][prop] end
				group[prop] = sum
			else
				local r, g, b = 0, 0, 0
				for _, e in entries do
					local c = e.P[name][prop]
					r += e.W * c.R; g += e.W * c.G; b += e.W * c.B
				end
				group[prop] = Color3.new(r, g, b)
			end
		end
		out[name] = group
	end
	return out
end

-- Real sun position, dimmer cool night, warm horizon light at dawn and dusk. Returns the daylight factor.
local function applyTime(p: any, hour: number): number
	local s = math.sin(math.pi * 2 * (hour - 6) / 24)
	local d = smooth((s + 0.3) / 0.6)
	local dusk = math.clamp(1 - math.abs(s) / 0.3, 0, 1)
	local l, a, c, r = p.Lighting, p.CB_Atmosphere, p.CB_ColorCorrection, p.CB_SunRays
	local function night(col: Color3): Color3
		return Color3.new(col.R * 0.5, col.G * 0.58, col.B * 0.8):Lerp(col, d)
	end
	l.ClockTime = hour
	-- Horizon hours (dusk peaks at sunrise/sunset, continuous in the sun height so nothing snaps): low warm sun, less
	-- fill and brightness, sharper long shadows, coloured thicker air. guard() still applies the fill floors and glare caps.
	local H = Profiles.Horizon
	local dim = 1 - H.Fill * dusk
	l.Ambient, l.OutdoorAmbient = scaled(night(l.Ambient), dim), scaled(night(l.OutdoorAmbient), dim)
	l.Brightness *= (0.65 + 0.35 * d) * (1 - H.Sun * dusk)
	l.ExposureCompensation += 0.1 * (1 - d) - H.Exposure * dusk
	l.ShadowSoftness *= 1 - 0.4 * dusk
	-- Moonlight follows the sun height: half at sunset, full once the sun is ~9 deg down, almost none at early dawn.
	local M, moon = Profiles.Moon, smooth((0.15 - s) / 0.3)
	l.Ambient, l.OutdoorAmbient = l.Ambient:Lerp(M.Ambient, moon), l.OutdoorAmbient:Lerp(M.Outdoor, moon)
	l.ExposureCompensation += M.Exposure * moon
	l.ColorShift_Top = l.ColorShift_Top:Lerp(M.Top, moon):Lerp(rgb(255, 176, 120), 0.65 * dusk)
	a.Density += 0.05 * (1 - d) + H.Density * dusk
	a.Haze += H.Haze * dusk
	a.Color = a.Color:Lerp(rgb(60, 72, 110), 0.5 * (1 - d)):Lerp(rgb(255, 178, 128), 0.55 * dusk)
	a.Decay = a.Decay:Lerp(rgb(255, 130, 84), 0.45 * dusk)
	c.TintColor = c.TintColor:Lerp(rgb(190, 205, 240), 0.5 * (1 - d)):Lerp(rgb(255, 214, 182), 0.25 * dusk)
	r.Intensity *= d * (1 + 0.6 * dusk)
	return d
end

-- Mix is already region-blended and sums to 1. Returns the precipitation shares and the wind gain.
local function applyWeather(p: any, mix: { [string]: number }, comfort: boolean): ({ [string]: number }, number)
	local l, a, c, r = p.Lighting, p.CB_Atmosphere, p.CB_ColorCorrection, p.CB_SunRays
	local precip: { [string]: number } = {}
	local gain = 0
	for _, state in Profiles.WeatherStates do
		local w = mix[state] or 0
		if w > 0 then
			local m = weather[state]
			a.Density += m.Density * w
			a.Haze += m.Haze * w
			r.Intensity *= 1 - w + m.Rays * w
			l.Ambient, l.OutdoorAmbient = scaled(l.Ambient, 1 - w + m.Fill * w), scaled(l.OutdoorAmbient, 1 - w + m.Fill * w)
			c.Saturation += m.Sat * w
			if m.Amount > 0 then
				l.ColorShift_Top = l.ColorShift_Top:Lerp(m.Tint, m.Amount * w)
				c.TintColor = c.TintColor:Lerp(m.Tint, m.Amount * w)
				a.Color = a.Color:Lerp(m.Tint, m.Amount * w)
			end
			gain += m.Wind * w
			if m.Precip then precip[m.Precip] = (precip[m.Precip] or 0) + w * (if comfort then 0.35 else 1) end
		end
	end
	return precip, if gain > 0 then gain else 1
end

local function guard(p: any, comfort: boolean)
	local G = Profiles.Glare
	local l, a, r, b = p.Lighting, p.CB_Atmosphere, p.CB_SunRays, p.CB_Bloom
	l.Ambient, l.OutdoorAmbient = lift(l.Ambient, Profiles.Night.Ambient), lift(l.OutdoorAmbient, Profiles.Night.Outdoor)
	l.Brightness = math.min(l.Brightness, G.Brightness)
	r.Intensity = math.min(r.Intensity * (if comfort then 0.5 else 1), G.Rays)
	b.Intensity = math.min(b.Intensity * (if comfort then 0.6 else 1), G.Bloom)
	b.Threshold = math.max(b.Threshold, G.Threshold)
	a.Glare = math.min(a.Glare, G.Atmosphere)
end

-- input: { Weights = Overworld.blendAt(...) or nil outside the overworld, Time = world seconds, Mix = weather mix,
--          Sheltered, Comfort, Boss = { Phase, Arena } when a fight is on }.
-- Returns the Lighting-child profile (nil = not the open overworld: lobby and domain keep their own path) and
-- { Hour, Daylight, Precip = { Rain/Snow/Dust = 0..1 }, WindGain }.
function Profiles.compose(input: any): (any?, any)
	if input.Boss then
		-- A fight keeps its arena treatment untouched: no clock, weather or glare change under the readability floor.
		local key = Profiles.resolve(nil, true, input.Boss.Phase or 1, input.Boss.Arena)
		return Profiles.get(key), { Key = key, Precip = {}, WindGain = 1, Hour = nil, Daylight = 1 }
	end
	if not input.Weights then return nil, { Precip = {}, WindGain = 1, Daylight = 1 } end
	local entries = {}
	for region, w in input.Weights do
		if w > 0 then table.insert(entries, { P = (Profiles :: any)[region], W = w }) end
	end
	local p = average(entries)
	local hour = Profiles.hourAt(input.Time)
	local daylight = applyTime(p, hour)
	-- Roofed shelter suppresses weather: no precipitation and no weather grading, the clock still applies.
	local mix = if input.Sheltered then { Clear = 1 } else (input.Mix or { Clear = 1 })
	local precip, gain = applyWeather(p, mix, input.Comfort == true)
	local ridge = input.Vesperhold or 0
	if ridge > 0 then
		local fog = p.CB_Atmosphere
		fog.Density += 0.11 * ridge
		fog.Haze += 0.64 * ridge
		fog.Color = fog.Color:Lerp(rgb(165, 172, 182), 0.67 * ridge)
		fog.Decay = fog.Decay:Lerp(rgb(85, 89, 97), 0.65 * ridge)
		local light = p.Lighting
		light.Brightness *= 1 - 0.32 * ridge
		light.ExposureCompensation -= 0.21 * ridge
		light.EnvironmentSpecularScale *= 1 - 0.32 * ridge
		p.CB_ColorCorrection.Saturation -= 0.29 * ridge
		p.CB_SunRays.Intensity *= 1 - 0.85 * ridge
		-- Storm grade: darker overcast, a faint red cast in the key light and grade, cold shadows, denser banks of haze.
		light.Brightness *= 1 - 0.18 * ridge
		light.ColorShift_Top = light.ColorShift_Top:Lerp(rgb(150, 72, 74), 0.35 * ridge)
		light.ColorShift_Bottom = light.ColorShift_Bottom:Lerp(rgb(18, 24, 38), 0.5 * ridge)
		p.CB_ColorCorrection.TintColor = p.CB_ColorCorrection.TintColor:Lerp(rgb(208, 176, 178), 0.4 * ridge)
		p.CB_ColorCorrection.Contrast += 0.08 * ridge
		fog.Density += 0.05 * ridge
		fog.Decay = fog.Decay:Lerp(rgb(96, 62, 66), 0.2 * ridge)
	end
	guard(p, input.Comfort == true)
	return p, { Hour = hour, Daylight = daylight, Precip = precip, WindGain = gain }
end

-- Living sky (win-80): one volumetric cloud deck (Terrain.Clouds, owned by WeatherController) over the whole overworld.
-- Cover/Density per biome: the dry Saltreach is the clearest, the Ashen Stair the heaviest; weather adds cover and greys it,
-- dust thins and warms it. The Vesperhold ridge blends to its storm deck by weight. nil outside the overworld.
local deck: { [string]: { number } } = {
	-- Studio win-80: the engine draws almost nothing below ~0.55 cover and a closed lid near 0.9; 0.68 / 0.45 is broken cumulus.
	Forest = { 0.67, 0.45 }, GoldenRavine = { 0.62, 0.4 }, AridBasin = { 0.57, 0.34 }, Snowfields = { 0.67, 0.48 }, MountainAscent = { 0.72, 0.52 },
}
local deckWeather: { [string]: any } = {
	Clear = { 0, 0, rgb(255, 255, 255) }, Overcast = { 0.12, 0.15, rgb(206, 211, 220) }, Rain = { 0.18, 0.3, rgb(150, 156, 168) },
	Snow = { 0.14, 0.2, rgb(214, 220, 232) }, Dust = { -0.08, -0.1, rgb(240, 216, 182) },
}
Profiles.RidgeDeck = table.freeze({ Density = 0.82, Color = rgb(88, 90, 99) })
function Profiles.clouds(input: any): { Cover: number, Density: number, Color: Color3 }?
	if not input.Weights then return nil end
	local cover, density = 0, 0
	for region, w in input.Weights do
		local d = deck[region] or deck.Forest
		cover += d[1] * w; density += d[2] * w
	end
	local color = rgb(255, 255, 255)
	for state, w in input.Mix or { Clear = 1 } do
		local m = deckWeather[state]
		if m and w > 0 then
			cover += m[1] * w; density += m[2] * w
			color = color:Lerp(m[3], w)
		end
	end
	local ridge = input.Vesperhold or 0
	if ridge > 0 then
		local mix = input.Mix or {}
		local storm = 0.86 + 0.12 * ((mix.Overcast or 0) + (mix.Snow or 0))
		cover += (storm - cover) * ridge
		density += (Profiles.RidgeDeck.Density - density) * ridge
		color = color:Lerp(Profiles.RidgeDeck.Color, ridge)
	end
	return { Cover = math.clamp(cover, 0, if ridge > 0 then 0.98 else 0.92), Density = math.clamp(density, 0, 1), Color = color }
end

-- Ambient life (win-80): 0..1 rates per kind for OverworldAmbience. Motes are sunlit pollen and dust, Leaves fall from the
-- canopy, Fireflies come out after dusk, Glitter is diamond dust in cold clear sun. Rain and snow ground the motes and
-- fireflies; a roof stops leaves and glitter; comfort keeps 40%. nil outside the overworld.
local life: { [string]: { [string]: number } } = {
	Forest = { Motes = 1, Leaves = 0.85, Fireflies = 1 },
	GoldenRavine = { Motes = 0.8, Leaves = 1, Fireflies = 0.6 },
	AridBasin = { Motes = 0.45 },
	Snowfields = { Glitter = 1 },
	MountainAscent = { Motes = 0.25, Glitter = 0.6 },
}
Profiles.AmbienceKinds = table.freeze({ "Motes", "Leaves", "Fireflies", "Glitter" })
function Profiles.ambience(input: any): { [string]: number }?
	if not input.Weights then return nil end
	local hour = Profiles.hourAt(input.Time or 0)
	local s = math.sin(math.pi * 2 * (hour - 6) / 24)
	local day = smooth((s + 0.15) / 0.4)
	local dark = smooth((-s + 0.02) / 0.25)
	local mix = input.Mix or { Clear = 1 }
	local wet = math.clamp((mix.Rain or 0) + (mix.Snow or 0), 0, 1)
	local clear = mix.Clear or 0
	local out: { [string]: number } = {}
	for _, kind in Profiles.AmbienceKinds do
		local base = 0
		for region, w in input.Weights do
			local r = life[region]
			base += (if r then r[kind] or 0 else 0) * w
		end
		local v = base
		if kind == "Motes" then v *= day * (clear + 0.4 * (mix.Overcast or 0) + 0.6 * (mix.Dust or 0))
		elseif kind == "Leaves" then v *= 1 - 0.3 * wet
		elseif kind == "Fireflies" then v *= dark * (1 - wet) * (1 - (mix.Dust or 0))
		elseif kind == "Glitter" then v *= day * (clear + 0.5 * (mix.Snow or 0)) end
		if input.Sheltered and (kind == "Leaves" or kind == "Glitter") then v = 0 end
		if input.Comfort then v *= 0.4 end
		out[kind] = math.clamp(v, 0, 1)
	end
	-- Lantern lights: on from deep dusk to dawn in every region and weather; comfort keeps them (light, not motion).
	out.Lanterns = smooth((-s + 0.12) / 0.3)
	out.Amber = math.clamp(input.Weights.GoldenRavine or 0, 0, 1) -- leaf tint share (Amberfall turns the leaves amber)
	return out
end

return table.freeze(Profiles)
