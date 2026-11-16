--!nonstrict
-- Lune regression for ticket 11: overworld weather, time of day, light composition and the one wind source.
-- Run from the project root: python3 tools/lune_compat.py tools/test_weather_composition.luau
-- Loads the real Wind, EnvironmentProfiles, Overworld, WeatherController and server EnvironmentService under engine
-- fakes. Rules, lifecycle and source checks only; Studio captures remain the visual acceptance.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox") :: any

local passed, failed = 0, 0
local function check(name, condition)
	if condition then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-6) end

-- Engine fakes -------------------------------------------------------------------------------------------
local tagged = {}
local function newInstance(class)
	local kids, props = {}, { ClassName = class, Attr = {} }
	local self
	self = setmetatable({}, {
		__index = function(_, k)
			if k == "IsA" then return function(_, c) return props.ClassName == c end end
			if k == "GetChildren" then return function() local out = {}; for _, kid in kids do if not kid.Dead then table.insert(out, kid) end end; return out end end
			if k == "FindFirstChild" then return function(_, n) for _, kid in kids do if kid.Name == n and not kid.Dead then return kid end end end end
			if k == "FindFirstChildOfClass" then return function(_, c) for _, kid in kids do if kid.ClassName == c and not kid.Dead then return kid end end end end
			if k == "Destroy" then return function() props.Dead = true; for _, kid in kids do kid:Destroy() end end end
			if k == "SetAttribute" then return function(_, n, v) props.Attr[n] = v end end
			if k == "GetAttribute" then return function(_, n) return props.Attr[n] end end
			return props[k]
		end,
		__newindex = function(_, k, v)
			props[k] = v
			if k == "Parent" and v then v:_adopt(self) end
		end,
	})
	props._adopt = function(_, kid) table.insert(kids, kid) end
	return self
end
local CollectionService = {
	GetTagged = function(_, tag) local out = {}; for inst, t in tagged do if t == tag and not inst.Dead then table.insert(out, inst) end end; return out end,
	AddTag = function(_, inst, tag) tagged[inst] = tag end,
}
local Instance = { new = newInstance }

local function load(path, env)
	local e = table.clone(env or {})
	for _, k in { "Color3", "Vector3", "Vector2", "CFrame", "Enum", "NumberRange", "NumberSequence", "ColorSequence", "RaycastParams" } do e[k] = e[k] or roblox[k] end
	e.Instance = e.Instance or Instance
	return luau.load(fs.readFile(path), { debugName = path, environment = e })()
end
local function has(path, text) return string.find(fs.readFile(path), text, 1, true) ~= nil end

local Overworld = load("src/shared/Overworld.luau")
local Profiles = load("src/shared/EnvironmentProfiles.luau")
local Wind = load("src/shared/Wind.luau")
local Config = load("src/shared/Config.luau")
local lobbyWind = Config.Workspace.GlobalWind
local regions = Overworld.RegionIds
local L = Profiles.luminance

-- 1. One wind source ---------------------------------------------------------------------------------------
local P = Wind.Prevailing
check("overworld prevailing wind is ESE", P.Name == "ESE" and near(P.FromDegrees, 112.5))
local from = math.deg(math.atan2(-Wind.Toward.X, Wind.Toward.Z))
check("wind comes FROM bearing 112.5 (east-south-east)", near((from + 360) % 360, 112.5, 1e-6))
check("wind blows toward the west-north-west", Wind.Toward.X < 0 and Wind.Toward.Z < 0 and near(math.sqrt(Wind.Toward.X ^ 2 + Wind.Toward.Z ^ 2), 1))
check("rain shadow: windward Bellwood lies east of the lee Amberfall and Saltreach",
	Overworld.Regions.Forest.Bounds.Center.X > Overworld.Regions.GoldenRavine.Bounds.Center.X
	and Overworld.Regions.GoldenRavine.Bounds.Center.X > Overworld.Regions.AridBasin.Bounds.Center.X and Wind.Toward.X < 0)
local lobby = Wind.sample(false, lobbyWind, 3)
check("lobby keeps its own wind untouched", lobby.X == lobbyWind[1] and lobby.Y == lobbyWind[2] and lobby.Z == lobbyWind[3])
local calm, gusty = Wind.sample(true, lobbyWind, 1), Wind.sample(true, lobbyWind, 2)
check("overworld wind differs from the lobby and scales with weather gain", near(calm.Speed, P.Speed) and near(gusty.Speed, 2 * P.Speed) and calm.X ~= lobbyWind[1])
local ax, ay, az = Wind.drift(calm, 14, 0.6)
check("precipitation drift is a share of the same vector", near(ax / az, calm.X / calm.Z) and ay == -14)
check("ambience volume follows the same speed", Wind.ambience(gusty) > Wind.ambience(calm) and Wind.ambience(lobby) >= 0.1)
-- Grep checks: FoliageWind is the only GlobalWind writer, and no other module holds a wind bearing.
local writers, bearings = {}, {}
local function scan(dir)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then scan(path)
		elseif string.sub(name, -5) == ".luau" then
			local source = fs.readFile(path)
			if string.find(source, "[wW]orkspace%.GlobalWind%s*=[^=]") then table.insert(writers, path) end
			if string.find(source, "FromDegrees", 1, true) then table.insert(bearings, path) end
		end
	end
end
scan("src")
check("FoliageWind is the only GlobalWind writer", #writers == 1 and writers[1] == "src/client/Controllers/FoliageWind.luau")
check("the prevailing bearing is defined only in Shared/Wind", #bearings == 1 and bearings[1] == "src/shared/Wind.luau")
local weatherSource = fs.readFile("src/client/Controllers/WeatherController.luau")
check("weather controller takes wind from Shared/Wind and never writes Lighting or GlobalWind",
	string.find(weatherSource, "Wind.sample", 1, true) ~= nil and string.find(weatherSource, "TweenService") == nil
	and string.find(weatherSource, 'GetService("Lighting")', 1, true) == nil)

-- 2. Compose priority: biome < time < weather < shelter < boss; comfort scales effects --------------------
local function hourT(hour) return ((hour - Profiles.Clock.StartHour) % 24) / 24 * Profiles.Clock.DayLength end
local noon, midnight = hourT(12), hourT(0)
check("hourAt inverts hourT", near(Profiles.hourAt(noon), 12, 1e-6) and near(Profiles.hourAt(midnight), 0, 1e-6)
	and near(Profiles.hourAt(0), Profiles.Clock.StartHour) and near(Profiles.hourAt(Profiles.Clock.DayLength), Profiles.Clock.StartHour, 1e-6))
local function compose(extra)
	local input = { Weights = { Forest = 1 }, Time = noon, Mix = { Clear = 1 } }
	for k, v in extra do input[k] = v end
	return Profiles.compose(input)
end
local clear, clearInfo = compose({})
local rain, rainInfo = compose({ Mix = { Rain = 1 } })
check("compose priority: weather darkens and thickens the biome day", rain.CB_Atmosphere.Density > clear.CB_Atmosphere.Density
	and rain.CB_SunRays.Intensity < clear.CB_SunRays.Intensity and L(rain.Lighting.OutdoorAmbient) < L(clear.Lighting.OutdoorAmbient) and rainInfo.Precip.Rain == 1)
check("clear weather has no precipitation", next(clearInfo.Precip) == nil and near(clearInfo.WindGain, 1))
local covered, coveredInfo = compose({ Mix = { Rain = 1 }, Sheltered = true })
check("compose priority: shelter suppresses weather (grade and precipitation) but keeps the clock",
	next(coveredInfo.Precip) == nil and near(covered.CB_Atmosphere.Density, clear.CB_Atmosphere.Density) and covered.Lighting.ClockTime == clear.Lighting.ClockTime)
local night, nightInfo = compose({ Time = midnight })
check("compose priority: time sets the sun and dims a cool night", near(night.Lighting.ClockTime, 0, 1e-6) and nightInfo.Daylight < 0.01 and clearInfo.Daylight > 0.99
	and L(night.Lighting.OutdoorAmbient) < L(clear.Lighting.OutdoorAmbient) and night.Lighting.Brightness < clear.Lighting.Brightness)
local snow = Profiles.compose({ Weights = { Snowfields = 1 }, Time = noon, Mix = { Clear = 1 } })
check("compose priority: biome gives its own palette", snow.CB_Atmosphere.Color ~= clear.CB_Atmosphere.Color and snow.CB_ColorCorrection.TintColor ~= clear.CB_ColorCorrection.TintColor)
local fight, fightInfo = compose({ Boss = { Phase = 1, Arena = "Forest" }, Mix = { Rain = 1 }, Sheltered = true, Time = midnight })
check("compose priority: boss beats weather, shelter and time with the arena's own combat look", rawequal(fight, Profiles.get("Combat:Forest")) and next(fightInfo.Precip) == nil)
check("boss phase two takes the unbound treatment", rawequal(compose({ Boss = { Phase = 2, Arena = "Forest" } }), Profiles.get("Unbound:Forest")))
local comfortRain, comfortInfo = compose({ Mix = { Rain = 1 }, Comfort = true })
check("comfort cuts precipitation, sun rays and bloom", near(comfortInfo.Precip.Rain, 0.35) and comfortRain.CB_SunRays.Intensity <= rain.CB_SunRays.Intensity
	and comfortRain.CB_Bloom.Intensity <= rain.CB_Bloom.Intensity)
check("compose gives nothing outside the overworld (lobby and domain keep their own path)", Profiles.compose({ Time = noon }) == nil)
check("weather wind gain reaches the shared sample", near(rainInfo.WindGain, Profiles.Weather.Rain.Wind) and near(Wind.sample(true, lobbyWind, rainInfo.WindGain).Speed, P.Speed * 1.5))

-- 3. Glare cap and fill floors over every hour, biome and weather ----------------------------------------
local G, Night, Floor = Profiles.Glare, Profiles.Night, Profiles.Floor
local worst, cases = { bloom = 0, rays = 0, glare = 0, brightness = 0 }, 0
local lowestAmbient, lowestOutdoor = math.huge, math.huge
for _, region in regions do
	for _, state in Profiles.WeatherStates do
		for hour = 0, 23.75, 0.25 do
			for _, comfort in { false, true } do
				local p = Profiles.compose({ Weights = { [region] = 1 }, Time = hourT(hour), Mix = { [state] = 1 }, Comfort = comfort })
				cases += 1
				worst.bloom, worst.rays = math.max(worst.bloom, p.CB_Bloom.Intensity), math.max(worst.rays, p.CB_SunRays.Intensity)
				worst.glare, worst.brightness = math.max(worst.glare, p.CB_Atmosphere.Glare), math.max(worst.brightness, p.Lighting.Brightness)
				lowestAmbient, lowestOutdoor = math.min(lowestAmbient, L(p.Lighting.Ambient)), math.min(lowestOutdoor, L(p.Lighting.OutdoorAmbient))
				if p.CB_Bloom.Threshold < G.Threshold - 1e-9 then worst.bloom = math.huge end
			end
		end
	end
end
check("glare cap: bloom, sun rays, atmosphere glare and sun brightness stay under their ceilings (" .. cases .. " cases)",
	worst.bloom <= G.Bloom + 1e-9 and worst.rays <= G.Rays + 1e-9 and worst.glare <= G.Atmosphere + 1e-9 and worst.brightness <= G.Brightness + 1e-9)
check("exploration fill never falls under the night floor, even at midnight in rain", lowestAmbient >= Night.Ambient - 0.5 and lowestOutdoor >= Night.Outdoor - 0.5)
check("night floor sits under the combat floor, so fights are never darker", Night.Ambient <= Floor.Ambient and Night.Outdoor <= Floor.Outdoor)
for key, profile in Profiles.Biomes do
	for _, prefix in { "Combat:", "Unbound:" } do
		local p = Profiles.get(prefix .. key)
		check("combat fill kept " .. prefix .. key, L(p.Lighting.Ambient) >= Floor.Ambient - 1 and L(p.Lighting.OutdoorAmbient) >= Floor.Outdoor - 1
			and p.CB_Atmosphere.Density <= Floor.Density + 1e-9 and p.Lighting.ExposureCompensation >= Floor.Exposure - 0.15)
	end
end

-- 4. Weather per biome: deterministic, shadowed, blended in time ---------------------------------------
local seen = {}
for _, region in regions do
	seen[region] = {}
	for slot = 0, 600 do
		local mix = Profiles.weatherMix(region, slot * Profiles.Clock.SlotLength + 200)
		local sum = 0
		for state, w in mix do sum += w; if w > 0.99 then seen[region][state] = true end end
		if not near(sum, 1, 1e-9) then check("mix sums to one " .. region, false) end
		local again = Profiles.weatherMix(region, slot * Profiles.Clock.SlotLength + 200)
		for state, w in mix do if again[state] ~= w then check("deterministic " .. region, false) end end
	end
end
check("Bellwood sees rain and clear", seen.Forest.Rain and seen.Forest.Clear and not seen.Forest.Snow and not seen.Forest.Dust)
check("rain shadow: Amberfall and the Saltreach never rain, they raise dust", not seen.GoldenRavine.Rain and not seen.AridBasin.Rain and seen.AridBasin.Dust and seen.GoldenRavine.Dust)
check("Frostmere and the Ashen Stair snow", seen.Snowfields.Snow and seen.MountainAscent.Snow and not seen.Snowfields.Rain)
local slotLength, ramp = Profiles.Clock.SlotLength, Profiles.Clock.Ramp
local steady = 0
for slot = 1, 200 do
	local before = Profiles.weatherMix("Forest", slot * slotLength - 1e-6)
	local after = Profiles.weatherMix("Forest", slot * slotLength + 1e-6)
	for state, w in before do if math.abs(w - (after[state] or 0)) > 1e-3 then steady += 1 end end
end
check("weather changes blend across slot boundaries (no snap in time)", steady == 0)
local late = Profiles.weatherBlend({ Forest = 0.5, GoldenRavine = 0.5 }, 12345)
local lateSum = 0
for _, w in late do lateSum += w end
check("blended weather mix sums to one", near(lateSum, 1, 1e-9))

-- 5. Selection blends across region Blend margins with no snap at box edges ------------------------------
local function findTime(a, b)
	for slot = 0, 1000 do
		local t = slot * slotLength + slotLength * 0.5
		local ma, mb = Profiles.weatherMix(a, t), Profiles.weatherMix(b, t)
		local da, db = "Clear", "Clear"
		for s, w in ma do if w > 0.99 then da = s end end
		for s, w in mb do if w > 0.99 then db = s end end
		if da ~= db and (ma.Rain == 1 or ma.Snow == 1 or ma.Dust == 1 or mb.Rain == 1 or mb.Snow == 1 or mb.Dust == 1) then return t end
	end
	return slotLength * 0.5
end
local function sample(x, z, t)
	local weights = Overworld.blendAt(x, z)
	local p, info = Profiles.compose({ Weights = weights, Time = t, Mix = Profiles.weatherBlend(weights, t) })
	local rate = 0
	for _, r in info.Precip do rate += r end
	return { p.CB_Atmosphere.Density, p.CB_Atmosphere.Haze, L(p.Lighting.Ambient), L(p.Lighting.OutdoorAmbient), p.CB_SunRays.Intensity, rate, info.WindGain }
end
local borders = {
	{ "Forest|GoldenRavine", "Forest", "GoldenRavine", -5200, -2500, 1, 0 },
	{ "GoldenRavine|AridBasin", "GoldenRavine", "AridBasin", -7600, -2500, 1, 0 },
	{ "Forest|Snowfields", "Forest", "Snowfields", -3500, -4200, 0, 1 },
	{ "GoldenRavine|MountainAscent", "GoldenRavine", "MountainAscent", -6400, -4200, 0, 1 },
	{ "AridBasin|MountainAscent", "AridBasin", "MountainAscent", -8800, -4200, 0, 1 },
	{ "Snowfields|MountainAscent", "Snowfields", "MountainAscent", -5600, -6000, 1, 0 },
}
local step = 4
for _, b in borders do
	local name, a, c, cx, cz, dx, dz = b[1], b[2], b[3], b[4], b[5], b[6], b[7]
	local t = findTime(a, c)
	local reach = Overworld.Blend / 2 + 40
	local first = sample(cx - dx * reach, cz - dz * reach, t)
	local last = sample(cx + dx * reach, cz + dz * reach, t)
	local previous, worstRatio, total = first, 0, 0
	for k = 1, math.floor(2 * reach / step) do
		local now = sample(cx + dx * (-reach + k * step), cz + dz * (-reach + k * step), t)
		for i = 1, #now do
			local span = math.abs(last[i] - first[i])
			if span > 0.02 then worstRatio = math.max(worstRatio, math.abs(now[i] - previous[i]) / span) end
			total += 1
		end
		previous = now
	end
	-- A snap would move a property by its whole span in one step; the margin spreads it over Blend / step steps.
	check("no snap across the " .. name .. " margin (largest step " .. string.format("%.3f", worstRatio) .. " of the span)", worstRatio < 0.12)
	for _, side in { -1, 1 } do
		local x, z = cx + dx * side * (reach + 200), cz + dz * side * (reach + 200)
		local weights = Overworld.blendAt(x, z)
		local region, count = next(weights)
		local pure = Profiles.compose({ Weights = { [region] = 1 }, Time = t, Mix = Profiles.weatherMix(region, t) })
		check("deep inside " .. region .. " (" .. name .. ") the composition is the pure region", next(weights, region) == nil and near(weights[region], 1)
			and near(sample(x, z, t)[1], pure.CB_Atmosphere.Density, 1e-9))
	end
end

-- 6. Lifecycle: controller FX, shelter, region, fight, respawn, reset, join and leave ---------------------
local epoch, now = 5000, 5000
local own = nil
local roofHit = false
local player = newInstance("Player")
local workspaceFake = newInstance("Workspace")
workspaceFake.GetServerTimeNow = function() return now end
workspaceFake.Raycast = function() return if roofHit then { Instance = true } else nil end
workspaceFake.CurrentCamera = nil
workspaceFake:SetAttribute("AsuraWorldEpoch", epoch)
local shared = { Shared = { Overworld = "Overworld", EnvironmentProfiles = "EnvironmentProfiles", Wind = "Wind", EffectsPreference = "EffectsPreference" },
	WaitForChild = function(_, name) return name end }
local reducedMotion, reducedEffects = false, false
local modules = { Config = Config, Overworld = Overworld, EnvironmentProfiles = Profiles, Wind = Wind, EffectsPreference = { reducedMotion = function() return reducedMotion end, reduced = function() return reducedEffects end } }
local services = { Players = { LocalPlayer = player }, CollectionService = CollectionService, ReplicatedStorage = { WaitForChild = function() return shared end } }
local controllerEnv = { game = { GetService = function(_, name) return services[name] end }, workspace = workspaceFake,
	require = function(name) return modules[name] end }
local Weather = load("src/client/Controllers/WeatherController.luau", controllerEnv)
local state = { Own = function() return own end }
local function place(x, y, z) own = { Root = { Position = roblox.Vector3.new(x, y, z) } } end
local function counts(controller) local c = controller:Counts(); return c.Parts, c.Emitters end
-- A moment when the Bellwood is in steady rain and the Saltreach is clear.
local rainAt
for slot = 1, 1000 do
	local t = slot * slotLength + slotLength * 0.5
	if Profiles.weatherMix("Forest", t).Rain == 1 and (Profiles.weatherMix("AridBasin", t).Clear or 0) == 1 then rainAt = t; break end
end
check("test setup: found a rainy Bellwood with a clear Saltreach", rainAt ~= nil)
now = epoch + rainAt
local weather = Weather.new(state)
place(-3000, 140, -2000)
weather:Sample()
local parts, emitters = counts(weather)
check("rain in the Bellwood creates one FX part with one rain emitter", parts == 1 and emitters == 1 and player:GetAttribute("AsuraWeather") == "Rain")
local emitter = weather.Fx:FindFirstChild("Rain")
check("rain slants with the one wind sample", emitter ~= nil and near(emitter.Acceleration.X / emitter.Acceleration.Z, Wind.Toward.X / Wind.Toward.Z, 1e-6))
-- Streak direction: the particle lies along its velocity (initial Bottom launch + Acceleration over its life), tall not wide.
local rk = Weather.Kinds.Rain
local a, vDown = emitter.Acceleration, rk.Fall * 0.5
local vx, vy, vz = a.X * rk.Life, vDown - a.Y * rk.Life, a.Z * rk.Life
local horiz = math.sqrt(vx * vx + vz * vz)
check("rain streaks along its velocity, tall (VelocityParallel, Squash < 0)", emitter.Orientation.Name == "VelocityParallel" and emitter.Squash.Keypoints[1] < 0)
check("rain velocity falls faster than it drifts and blows WNW (toward 292.5 deg)", vy >= horiz and horiz > 0
	and near(vx / horiz, Wind.Toward.X, 1e-6) and near(vz / horiz, Wind.Toward.Z, 1e-6) and Wind.Toward.X < 0 and Wind.Toward.Z < 0)
check("rain emits within the shared 600 budget; snow and dust stay soft, never velocity-parallel", emitter.Rate * rk.Life <= Weather.Budget + 1e-6
	and Weather.Kinds.Snow.Squash == nil and Weather.Kinds.Dust.Squash == nil)
check("rain emitter is a tall volume (drops spawn at head height) and streaks stay bright", weather.Fx.Size.Y >= 30 and rk.Glow >= 0.3 and rk.Rate * rk.Life >= 500)
check("weather wind and profile reach the lighting owner", weather.Wind ~= nil and near(weather.Wind.Speed, P.Speed * Profiles.Weather.Rain.Wind, 1e-6)
	and weather:Profile(nil) ~= nil and weather:Profile({ Phase = 1 }) == nil)
check("clock hour composed from the server epoch", near(weather.Info.Hour, Profiles.hourAt(rainAt), 1e-6))
roofHit = true
tagged[newInstance("Part")] = "AsuraShelter"
weather:Sample()
parts, emitters = counts(weather)
check("shelter removes the FX and shows no weather", parts == 0 and emitters == 0 and player:GetAttribute("AsuraSheltered") == true and next(weather.Info.Precip) == nil)
roofHit = false
weather:Sample()
parts, emitters = counts(weather)
check("leaving shelter brings the rain back", parts == 1 and emitters == 1 and player:GetAttribute("AsuraSheltered") == false)
place(-9000, 150, -3000)
weather:Sample()
parts, emitters = counts(weather)
check("region change into the rain shadow cleans up the FX", parts == 0 and emitters == 0 and weather.Active)
place(-3000, 140, -2000)
weather:Sample()
player:SetAttribute("AsuraEncounter", "Boss")
weather:Sample()
parts, emitters = counts(weather)
check("a fight clears weather FX and leaves the arena profile to the encounter", parts == 0 and emitters == 0)
player:SetAttribute("AsuraEncounter", "")
weather:Sample()
check("fight over, rain returns", select(1, counts(weather)) == 1)
reducedMotion = true
weather:Sample()
check("comfort preference thins the rain", weather.Fx:FindFirstChild("Rain").Rate < Weather.Kinds.Rain.Rate * 0.4)
reducedMotion = false
reducedEffects = true
weather:Sample()
local thin = weather.Fx:FindFirstChild("Rain")
check("Reduced effects setting thins the rain too, but keeps a visible minimum", thin ~= nil and thin.Rate < Weather.Kinds.Rain.Rate * 0.4 and thin.Rate * Weather.Kinds.Rain.Life >= 100)
reducedEffects = false
weather:Sample()
check("rain returns to full when Reduced effects is off", weather.Fx:FindFirstChild("Rain").Rate > Weather.Kinds.Rain.Rate * 0.9)
own = nil
weather:Sample()
parts, emitters = counts(weather)
check("respawn (no character) resets FX, profile, wind and attributes", parts == 0 and emitters == 0 and not weather.Active and weather:Profile(nil) == nil
	and weather.Wind == nil and player:GetAttribute("AsuraWeather") == nil and player:GetAttribute("AsuraSheltered") == nil)
place(-3000, 140, -2000)
weather:Sample()
place(0, 600, 900)
weather:Sample()
parts, emitters = counts(weather)
check("lobby: no FX, no composed profile, lobby wind untouched", parts == 0 and emitters == 0 and weather:Profile(nil) == nil and weather.Wind == nil)
place(-3000, 140, -2000)
weather:Sample()
place(-7200, 1600, -8255)
weather:Sample()
parts, emitters = counts(weather)
check("Ash Colosseum domain keeps its own night: no weather", parts == 0 and emitters == 0 and weather:Profile(nil) == nil)
place(-3000, 140, -2000)
weather:Sample()
weather:Reset()
parts, emitters = counts(weather)
check("Reset leaves nothing behind", parts == 0 and emitters == 0 and not weather.Active)
-- Join/leave: a second client on the same epoch composes the identical sky; leaving destroys everything.
local second = Weather.new(state)
weather:Sample()
second:Sample()
check("late joiner on the same epoch sees the same weather and clock", weather.Info.Hour == second.Info.Hour and weather.Wind.Speed == second.Wind.Speed
	and weather.Composed.CB_Atmosphere.Density == second.Composed.CB_Atmosphere.Density and weather.Info.Precip.Rain == second.Info.Precip.Rain)
weather:Destroy()
second:Destroy()
parts, emitters = counts(weather)
check("start/stop: Destroy reaches zero FX parts and emitters", parts == 0 and emitters == 0 and player:GetAttribute("AsuraWeather") == nil)
workspaceFake:SetAttribute("AsuraWorldEpoch", nil)
local early = Weather.new(state)
early:Sample()
parts, emitters = counts(early)
check("before the server clock replicates there is no weather", parts == 0 and emitters == 0 and not early.Active)
early:Destroy()
workspaceFake:SetAttribute("AsuraWorldEpoch", epoch)
-- Update cadence: samples at 5 Hz only.
local paced = Weather.new(state)
paced:Update(0.1)
check("first Update samples at once", paced.Active)
place(0, 600, 900)
paced:Update(0.1)
check("Update waits for the 0.2 s cadence", paced.Active)
paced:Update(0.11)
check("Update samples again on the cadence", not paced.Active)
paced:Destroy()
check("no FX leak after the whole run", select(1, counts(paced)) == 0)

-- 7. Server world clock, lobby baseline, no GlobalWind write ----------------------------------------------
local serverWrites = {}
local function guarded(name, base)
	local data = base
	return setmetatable({}, { __index = function(_, k) if k == "_data" then return data end return data[k] end,
		__newindex = function(_, k, v) if k == "GlobalWind" then table.insert(serverWrites, v) end data[k] = v end })
end
local lightingData = newInstance("Lighting")
lightingData.LightingStyle, lightingData.PrioritizeLightingQuality = roblox.Enum.LightingStyle.Realistic, Config.Lighting.PrioritizeLightingQuality
local terrain = newInstance("Terrain")
local serverNow = 10000
local wsData = newInstance("Workspace")
wsData.GetServerTimeNow = function() return serverNow end
wsData.Terrain, wsData.StreamingEnabled, wsData.FallenPartsDestroyHeight = terrain, Config.Workspace.StreamingEnabled, Config.Workspace.FallenPartsDestroyHeight
wsData.GlobalWind = roblox.Vector3.new(lobbyWind[1], lobbyWind[2], lobbyWind[3])
local serverWorkspace = setmetatable({}, { __index = function(_, k) return wsData[k] end,
	__newindex = function(_, k, v) if k == "GlobalWind" then table.insert(serverWrites, v) end wsData[k] = v end })
local serverEnv = { game = { GetService = function(_, name)
	if name == "Lighting" then return lightingData elseif name == "Workspace" then return serverWorkspace end
	local asuras = { WaitForChild = function(_, n) return n end, Shared = { EnvironmentProfiles = "EnvironmentProfiles" } }
	return { WaitForChild = function() return asuras end, AsurasPath = asuras }
end }, require = function(name) return modules[name] end, warn = function() end }
local ServerEnvironment = load("src/server/Services/EnvironmentService.luau", serverEnv)
local okApply, applyError = pcall(ServerEnvironment.Apply)
check("server Apply runs under fakes (" .. tostring(applyError) .. ")", okApply)
check("server Apply never writes GlobalWind (FoliageWind is the sole writer)", #serverWrites == 0)
check("server publishes the world epoch", wsData:GetAttribute("AsuraWorldEpoch") == serverNow)
serverNow += 90
local t, hour = ServerEnvironment.Clock()
check("server clock matches the client arithmetic", t == 90 and near(hour, Profiles.hourAt(90)))
check("lobby baseline lighting unchanged: static ClockTime and the shrine profile", lightingData.ClockTime == Profiles.Sanctuary.Lighting.ClockTime
	and lightingData:FindFirstChild("CB_Bloom").Intensity == Profiles.Sanctuary.CB_Bloom.Intensity)
ServerEnvironment.Stop()
check("server Stop clears the epoch", wsData:GetAttribute("AsuraWorldEpoch") == nil and select(1, ServerEnvironment.Clock()) == nil)

-- 8. Wiring (lane 3b): controllers take the one wind; arena lights follow the relocated floor; lobby values unchanged ----
local World = require("../src/shared/WorldDefinitions") :: any
local Plan = load("src/shared/ArenaLightPlan.luau")
local lightsByKind, parts = { AsuraArenaLight = {}, AsuraArenaFill = {} }, {}
local fakeTagged = { AddTag = function(_, light, tag) table.insert(lightsByKind[tag], light) end }
local arenaModules = { WorldDefinitions = World, ArenaLightPlan = Plan, EnvironmentProfiles = Profiles,
	PbrAssets = { place = function() end } }
local arenaEnv = {
	game = { GetService = function(_, name)
		if name == "CollectionService" then return fakeTagged end
		return { AsurasPath = { Shared = {
			WorldDefinitions = "WorldDefinitions", ArenaLightPlan = "ArenaLightPlan", EnvironmentProfiles = "EnvironmentProfiles" } } }
	end },
	script = { Parent = { PbrAssets = "PbrAssets" } },
	workspace = newInstance("Workspace"),
	require = function(name) return arenaModules[name] end,
	Instance = { new = newInstance },
}
local ArenaLighting = load("src/server/Services/ArenaLighting.luau", arenaEnv)
local ok, built = pcall(ArenaLighting.Build)
check("ArenaLighting.Build runs under fakes (" .. tostring(built) .. ")", ok)
local shen = World.Bosses.GrandmasterShen
local floorY = shen.Arena.Center.Y - 20
check("Shen's arena is relocated off the old Y 0 floor", floorY > 1000 and ArenaLighting.lift(shen.Arena).Y == floorY)
local legacy = { Center = { X = 0, Y = 20, Z = -1960 }, Size = { X = 120, Y = 60, Z = 130 } }
check("a legacy Y 20 arena gets no lift", ArenaLighting.lift(legacy).Y == 0)
local lowest, highest, count = math.huge, -math.huge, 0
for _, kind in { "AsuraArenaLight", "AsuraArenaFill" } do
	for _, light in lightsByKind[kind] do
		local y = light.Parent.Position.Y
		lowest, highest, count = math.min(lowest, y), math.max(highest, y), count + 1
	end
end
check("arena lights sit on the relocated floor, not at Y 0 under the mountain (" .. tostring(lowest) .. ".." .. tostring(highest) .. ")",
	count >= 8 and lowest >= floorY and highest <= floorY + 30)
-- Fill floor: every arena look keeps fighters readable (combat floor) and its glare stays capped.
local F = Profiles.Floor
for _, key in { "Combat:AshColosseum", "Unbound:AshColosseum" } do
	local l = Profiles.get(key).Lighting
	check(key .. " keeps the combat fill floor", L(l.Ambient) >= F.Ambient - 1 and L(l.OutdoorAmbient) >= F.Outdoor - 1)
	check(key .. " glare capped", Profiles.get(key).CB_Bloom.Intensity <= Profiles.Glare.Bloom and Profiles.get(key).CB_SunRays.Intensity <= Profiles.Glare.Rays)
end
check("arena lanterns fill with the neutral light budget", Plan.Fill.Brightness <= 1 and Plan.Fill.Range <= 60)
-- Lobby unchanged: the lobby / domain path (no weather wind) keeps its baked wind and fixed ambience.
local foliage, sound, envSource = fs.readFile("src/client/Controllers/FoliageWind.luau"), fs.readFile("src/client/Controllers/SoundscapeController.luau"), fs.readFile("src/client/Controllers/EnvironmentController.luau")
check("FoliageWind falls back to the baked lobby wind", string.find(foliage, "else self.BaseWind", 1, true) ~= nil and string.find(foliage, "self.Weather.Wind", 1, true) ~= nil)
check("Soundscape keeps the lobby 0.12 / 0.22 levels without weather wind", string.find(sound, "elseif region == \"Sanctuary\" then 0.12 else 0.22", 1, true) ~= nil
	and string.find(sound, "Wind.ambience(w)", 1, true) ~= nil)
check("EnvironmentController keeps the keyed arena/boss path after the weather branch", string.find(envSource, "Profiles.get(key)", 1, true) ~= nil
	and string.find(envSource, "self.Weather:Profile(if boss ~= \"\" and alive then", 1, true) ~= nil)
local lobbyKey = Profiles.resolve("Sanctuary", false, 1, nil)
check("lobby profile untouched", lobbyKey == "Sanctuary" and Profiles.get(lobbyKey).Lighting.ClockTime == 17.4 and Config.Workspace.GlobalWind[1] == lobbyWind[1])

-- 9. Precipitation readability and dawn/dusk look (Studio 10e defects) --------------------------------------
local Kinds, Budget = Weather.Kinds, Weather.Budget
check("rain is a streak at player height: >= 1 stud long, scaled with fall speed, light blue-grey, see-through",
	Kinds.Rain.Size >= 1 and near(Kinds.Rain.Size, Kinds.Rain.Fall * 0.02, 1e-6) and Kinds.Rain.Squash < 0 and Kinds.Rain.Alpha >= 0.2 and Kinds.Rain.Alpha <= 0.6
	and Kinds.Rain.Color[3] > Kinds.Rain.Color[1] and Kinds.Rain.Color[1] >= 150)
check("snow flakes >= 0.4 stud and dust puffs stay translucent", Kinds.Snow.Size >= 0.4 and Kinds.Snow.Alpha <= 0.3 and Kinds.Dust.Alpha <= 0.8 and Kinds.Dust.Size >= 1.5)
check("snow uses the soft round sprite, not the default star, and dust reads (Alpha is transparency: <= 0.6, Size >= 2.6)", Kinds.Snow.Texture == "rbxasset://textures/particles/smoke_main.dds"
	and Kinds.Snow.Alpha <= 0.2 and Kinds.Dust.Alpha <= 0.6 and Kinds.Dust.Size >= 2.6)
check("dust uses a soft smoke sprite, not the default star (Studio: glitter)", Kinds.Dust.Texture == "rbxasset://textures/particles/smoke_main.dds"
	and string.find(weatherSource, "emitter.Texture = spec.Texture", 1, true) ~= nil)
for kind, spec in Kinds do
	local full = spec.Rate * spec.Life
	local comfortLive = full * 0.35
	check(kind .. " live particles " .. full .. " (comfort " .. string.format("%.0f", comfortLive) .. ") inside budget " .. Budget .. " and never below 100",
		full <= Budget and comfortLive >= 100 and comfortLive <= 0.4 * full)
end
local function lighting(hour, region, comfort) return (Profiles.compose({ Weights = { [region or "Forest"] = 1 }, Time = hourT(hour), Mix = { Clear = 1 }, Comfort = comfort })) end
for _, region in regions do
	local day = lighting(12, region)
	for _, hour in { 6.3, 19.5 } do
		local p = lighting(hour, region)
		check(string.format("%s at %.1f: brightness %.2f <= 0.8 x noon %.2f", region, hour, p.Lighting.Brightness, day.Lighting.Brightness), p.Lighting.Brightness <= 0.8 * day.Lighting.Brightness)
		check(string.format("%s at %.1f: ambient %.0f/outdoor %.0f <= 0.85 x noon %.0f/%.0f", region, hour, L(p.Lighting.Ambient), L(p.Lighting.OutdoorAmbient),
			L(day.Lighting.Ambient), L(day.Lighting.OutdoorAmbient)), L(p.Lighting.Ambient) <= 0.85 * L(day.Lighting.Ambient) and L(p.Lighting.OutdoorAmbient) <= 0.85 * L(day.Lighting.OutdoorAmbient))
		check(region .. " at " .. hour .. ": exploration fill floor and glare cap hold", L(p.Lighting.Ambient) >= Night.Ambient - 0.5 and L(p.Lighting.OutdoorAmbient) >= Night.Outdoor - 0.5
			and p.Lighting.Brightness <= G.Brightness and p.CB_SunRays.Intensity <= G.Rays and p.CB_Bloom.Intensity <= G.Bloom)
	end
	local dawn = lighting(6.3, region)
	check(region .. " dawn fog is warm, thicker and hazier than noon", dawn.CB_Atmosphere.Color.R / dawn.CB_Atmosphere.Color.B > day.CB_Atmosphere.Color.R / day.CB_Atmosphere.Color.B
		and dawn.CB_Atmosphere.Density >= day.CB_Atmosphere.Density + 0.05 and dawn.CB_Atmosphere.Haze >= day.CB_Atmosphere.Haze + 0.5
		and dawn.Lighting.ShadowSoftness < day.Lighting.ShadowSoftness)
	-- Interpolated through the cycle: no step between neighbouring 0.25 h samples jumps more than a quarter of the day's swing.
	local worstStep, swing, prev = 0, 0, nil
	for hour = 0, 24, 0.25 do
		local b = lighting(hour % 24, region).Lighting.Brightness
		if prev then worstStep = math.max(worstStep, math.abs(b - prev)) end
		prev = b
		swing = math.max(swing, math.abs(b - day.Lighting.Brightness))
	end
	check(region .. " brightness changes smoothly through the cycle (" .. string.format("%.3f of %.3f", worstStep, swing) .. ")", worstStep <= 0.3 * swing)
end
-- Lobby untouched by the horizon look: the shrine profile table is not part of compose and keeps its values.
check("lobby profile identical after the dawn change", Profiles.Sanctuary.Lighting.Brightness == 2.2 and Profiles.Sanctuary.Lighting.ShadowSoftness == 0.24
	and Profiles.Sanctuary.Lighting.ClockTime == 17.4 and Profiles.Sanctuary.CB_Atmosphere.Density == 0.38)

-- 10. Far-view haze (C3 fault F): clear overworld air stays thin enough for ridges and the summit temple to read ---------
-- Roblox Atmosphere gives no closed form, so contrast uses a calibrated Beer-Lambert estimate: extinction per stud
-- sigma = Density * (1 + Haze / 2) / S. S = 379 is fitted to the Studio finding that the old Bellwood air (0.34 / 1.9) left
-- 35% contrast at 600 studs ("swallows everything past ~600"). Contrast of a dark silhouette against the sky = exp(-sigma * d).
-- Threshold: a temple with ~0.8 unfogged contrast against the sky needs >= 0.3 of it left (0.24 after fog, well above the
-- ~2% detection limit) to read as a silhouette instead of a smudge; 6,000 studs is the glade-to-temple scale, so the
-- longest altar sight line below (about 8,400) is held to a weaker 0.2.
local function farContrast(a, d) return math.exp(-d * a.Density * (1 + a.Haze / 2) / 379) end
local CLEAR_DENSITY, CLEAR_HAZE, MIN_FAR, MIN_FARTHEST, MIN_NEAR = 0.06, 0.6, 0.3, 0.2, 0.8
local temple = Overworld.Landmarks.SummitTemple.Position
local glade = Overworld.Altars.Altar_MonasteryGate.Placement
local longest = math.sqrt((temple.X - glade.X) ^ 2 + (temple.Z - glade.Z) ^ 2)
check("test setup: glade to summit temple sits between 5,000 and 9,000 studs (" .. string.format("%.0f", longest) .. ")", longest > 5000 and longest < 9000)
local oldDay = { Forest = { 0.34, 1.9 } }
check("calibration: the old Bellwood air left 35% at 600 studs and nothing at the temple", near(farContrast({ Density = oldDay.Forest[1], Haze = oldDay.Forest[2] }, 600), 0.35, 0.01)
	and farContrast({ Density = 0.34, Haze = 1.9 }, 6000) < 0.001)
for _, hour in { 12, Profiles.Clock.StartHour } do
	for _, region in regions do
		local a = lighting(hour, region).CB_Atmosphere
		local tag = string.format("%s clear at %.1f h", region, hour)
		check(tag .. string.format(": Atmosphere.Density %.3f <= %.2f and Haze %.2f <= %.1f", a.Density, CLEAR_DENSITY, a.Haze, CLEAR_HAZE),
			a.Density <= CLEAR_DENSITY + 1e-9 and a.Haze <= CLEAR_HAZE + 1e-9)
		check(tag .. string.format(": contrast at 6,000 studs %.2f >= %.1f, at the longest sight line %.2f >= %.1f", farContrast(a, 6000), MIN_FAR, farContrast(a, longest), MIN_FARTHEST),
			farContrast(a, 6000) >= MIN_FAR and farContrast(a, longest) >= MIN_FARTHEST)
		check(tag .. string.format(": near-field depth cue stays (contrast at 600 studs %.2f in 0.8..0.95)", farContrast(a, 600)),
			farContrast(a, 600) <= 0.95 and farContrast(a, 600) >= MIN_NEAR)
		check(tag .. ": Offset raised for silhouettes, glare under the cap", a.Offset >= 0.3 and a.Glare <= G.Atmosphere)
	end
end
-- Neutral blue-grey aerial perspective: blue >= green >= red, a small blue lead, never a saturated teal (green ~ blue, red low).
for _, region in regions do
	local a = lighting(12, region).CB_Atmosphere
	for name, c in { Color = a.Color, Decay = a.Decay } do
		local r, g, b = c.R * 255, c.G * 255, c.B * 255
		check(string.format("%s %s (%.0f,%.0f,%.0f) is blue-grey, not teal", region, name, r, g, b), b >= g and g >= r - 1 and b - g >= 3 and b - r <= 40)
	end
end
-- Fog: the composed look carries no fog fields (Atmosphere owns distance), and no client controller writes Lighting fog.
local fogWriters = {}
local function scanFog(dir)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then scanFog(path)
		elseif string.sub(name, -5) == ".luau" and string.find(fs.readFile(path), "Lighting.Fog", 1, true) then table.insert(fogWriters, path) end
	end
end
scanFog("src/client")
for _, region in regions do
	local p = lighting(12, region)
	check(region .. " composed profile has no Lighting fog fields", p.Lighting.FogEnd == nil and p.Lighting.FogStart == nil and p.Lighting.FogColor == nil)
end
check("no client controller writes Lighting.Fog (the Atmosphere replaces fog in the overworld)", #fogWriters == 0)
-- Weather may still thicken the air, in extinction and in lost contrast at 6,000 studs.
for _, region in regions do
	local base = Profiles.compose({ Weights = { [region] = 1 }, Time = noon, Mix = { Clear = 1 } }).CB_Atmosphere
	for _, state in { "Overcast", "Rain", "Snow", "Dust" } do
		local a = Profiles.compose({ Weights = { [region] = 1 }, Time = noon, Mix = { [state] = 1 } }).CB_Atmosphere
		check(region .. " " .. state .. " is thicker than Clear (density " .. string.format("%.3f > %.3f", a.Density, base.Density) .. ")",
			a.Density > base.Density and a.Haze > base.Haze and farContrast(a, 6000) < farContrast(base, 6000))
	end
end
-- Lobby: the shrine profile and its combat twin keep every atmosphere value.
local sa = Profiles.Sanctuary.CB_Atmosphere
check("lobby atmosphere values unchanged", sa.Density == 0.38 and sa.Haze == 2.2 and sa.Offset == 0.2 and sa.Glare == 0.35
	and sa.Color == roblox.Color3.fromRGB(250, 215, 185) and sa.Decay == roblox.Color3.fromRGB(120, 130, 165))
-- Fights keep their own combat atmosphere (the overworld haze change does not reach them).
check("combat atmospheres untouched by the overworld haze change", Profiles.get("Combat:Forest").CB_Atmosphere.Density == 0.28 and Profiles.get("Combat:MountainAscent").CB_Atmosphere.Haze == 1.6)

print(string.format("weather composition: %d passed, %d failed", passed, failed))
if failed > 0 then
	error("weather composition regression failed")
end
