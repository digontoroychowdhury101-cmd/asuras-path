--!nonstrict
-- Lune regression for playtest findings #2, #7, #36 (batch 03).
-- Run from the project root: lune run tools/test_combat_presentation.luau
-- Rules and engine-fake checks only: per-biome combat lighting floors, arena light coverage,
-- idempotent audio source lifetime under Roblox-like destruction locking, and the decorative
-- effects hook. Studio captures and any audio listening assessment are separate.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox") :: any
local World = require("../src/shared/WorldDefinitions") :: any

local passed, failed = 0, 0
local function check(name: string, condition: any)
	if condition then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local function load(path: string, extra: { [string]: any }?): any
	local e = table.clone(extra or {})
	e.Color3, e.Vector3 = roblox.Color3, roblox.Vector3
	return luau.load(fs.readFile(path), { debugName = path, environment = e })()
end
local Profiles = load("src/shared/EnvironmentProfiles.luau")
local Plan = load("src/shared/ArenaLightPlan.luau")
local Effects = load("src/shared/EffectsPreference.luau", { task = require("@lune/task") })
local L = Profiles.luminance

-- 1. Lighting: each arena gets its biome's combat treatment, not the Colosseum night.
local bosses = 0
for id, boss in World.Bosses do
	bosses += 1
	local key = Profiles.resolve("Sanctuary", true, 1, boss.Region)
	check(id .. " fights in its own biome (" .. key .. ")", key == "Combat:" .. boss.Region and Profiles.get(key) ~= nil)
	check(id .. " phase two stays in biome", Profiles.resolve(nil, true, 2, boss.Region) == "Unbound:" .. boss.Region)
	check(id .. " arena lighting not Colosseum unless there", (key == "Combat:AshColosseum") == (boss.Region == "AshColosseum"))
	check(id .. " no ash outside the Colosseum", Profiles.ashFall(key) == (boss.Region == "AshColosseum"))
end
for _, id in { "GrandmasterShen", "TwinSentinels", "VenerableBaize", "SlumberingTitan", "SovereignWu", "AzureWyrm" } do
	check(id .. " arena present", World.Bosses[id] ~= nil)
end
check("campaign arenas plus optional general (" .. bosses .. ")", bosses >= 6)
check("unknown arena falls back to shrine combat", Profiles.resolve(nil, true, 1, nil) == "Combat:Sanctuary")
check("exploration unchanged", Profiles.resolve("BambooPass", false, 3) == "BambooPass" and Profiles.resolve("Nowhere", false, 1) == "Sanctuary")
local F = Profiles.Floor
for region in Profiles.Biomes do
	for _, prefix in { "Combat:", "Unbound:" } do
		local p = Profiles.get(prefix .. region)
		local l, a = p.Lighting, p.CB_Atmosphere
		check(prefix .. region .. " ambient fill", L(l.Ambient) >= F.Ambient * 0.97)
		check(prefix .. region .. " outdoor fill", L(l.OutdoorAmbient) >= F.Outdoor * 0.97)
		check(prefix .. region .. " exposure", l.ExposureCompensation >= F.Exposure)
		check(prefix .. region .. " mist keeps the far wall", a.Density <= F.Density and a.Haze <= F.Haze)
	end
	local c, u = Profiles.get("Combat:" .. region).Lighting, Profiles.get("Unbound:" .. region).Lighting
	check(region .. " phase two does not darken", L(u.Ambient) >= L(c.Ambient) * 0.97 and L(u.OutdoorAmbient) >= L(c.OutdoorAmbient) * 0.97)
	check(region .. " phase two is atmospheric (warmer)", u.ColorShift_Top.R >= u.ColorShift_Top.B and u.Ambient.R > c.Ambient.R)
	check(region .. " keeps the biome clock", u.ClockTime == c.ClockTime)
	local fill = Profiles.arena(region).Fill
	check(region .. " fill is bright and near neutral", L(fill) >= 200 and math.max(fill.R, fill.G, fill.B) - math.min(fill.R, fill.G, fill.B) <= 0.2)
end
-- The cause: the shared night profile every first phase used is far below the floor.
check("legacy Colosseum night fails the floor", L(Profiles.AshColosseum.Lighting.OutdoorAmbient) < F.Outdoor and Profiles.AshColosseum.CB_Atmosphere.Density > F.Density)
local s = Profiles.Sanctuary
-- The monumental sanctuary needs active engine scattering to separate the courtyard and remote peaks.
check("shrine golden hour", s.Lighting.ClockTime == 17.4 and s.Lighting.Brightness == 2.2
	and s.Lighting.EnvironmentDiffuseScale == 0.65 and s.Lighting.EnvironmentSpecularScale == 1.0
	and s.Lighting.Ambient == roblox.Color3.fromRGB(60, 70, 92) and s.Lighting.OutdoorAmbient == roblox.Color3.fromRGB(105, 117, 139)
	and s.Lighting.ColorShift_Top == roblox.Color3.fromRGB(255, 245, 226) and s.Lighting.ExposureCompensation == -0.12
	and s.CB_Atmosphere.Density == 0.38 and s.CB_Atmosphere.Haze == 2.2
	and s.CB_Atmosphere.Color == roblox.Color3.fromRGB(250, 215, 185) and s.CB_Atmosphere.Decay == roblox.Color3.fromRGB(120, 130, 165)
	and s.CB_Atmosphere.Glare == 0.35 and s.CB_Atmosphere.Offset == 0.2
	and s.CB_SunRays.Intensity == 0.12 and s.CB_SunRays.Spread == 0.45
	and s.CB_ColorCorrection.Saturation == 0.05 and s.CB_ColorCorrection.Contrast == 0.15
	and s.CB_ColorCorrection.TintColor == roblox.Color3.fromRGB(255, 246, 236)
	and s.CB_Bloom.Intensity == 0.25 and s.CB_Bloom.Size == 24 and s.CB_Bloom.Threshold == 2.0)
check("shrine fill reads floors and faces", L(s.Lighting.Ambient) >= F.Ambient and L(s.Lighting.OutdoorAmbient) >= F.Outdoor)
check("night sky only Colosseum and phase two", Profiles.nightSky("Combat:AshColosseum") and Profiles.nightSky("Unbound:BambooPass") and not Profiles.nightSky("Combat:BambooPass"))

-- 2. Arena lights: braziers alone leave each centre dark; with fill every floor point is lit.
for id, boss in World.Bosses do
	local braziers, fills = Plan.braziers(boss.Arena), Plan.fills(boss.Arena)
	local legacy, dark = Plan.worstReach(boss.Arena, braziers, Plan.Brazier.Range, 2)
	check(id .. " braziers alone leave dark floor (worst " .. string.format("%.2f", legacy) .. ")", legacy > 1 and dark ~= nil)
	local worst = Plan.worstReach(boss.Arena, fills, Plan.Fill.Range, 2)
	check(id .. " fill lights cover the whole floor (worst " .. string.format("%.2f", worst) .. ")", worst <= Plan.Reach)
	check(id .. " fill light budget", #fills <= 9 and Plan.Fill.Range <= 60)
end

-- 3. Audio lifetime under Roblox-like locking: re-entering a destruction in progress throws.
local errors, queue, timers, now = {}, {}, {}, 0
local objects = {}
local Inst = {}
Inst.__index = function(self, k)
	local raw = rawget(self, "_props")
	if raw[k] ~= nil then return raw[k] end
	return Inst[k]
end
Inst.__newindex = function(self, k, v)
	local raw = rawget(self, "_props")
	if k == "Parent" and raw.Locked then error("The Parent property of " .. self:GetFullName() .. " is locked") end
	raw[k] = v
end
local function signal()
	local list = {}
	return { Once = function(_, fn) table.insert(list, fn) end, Connect = function(_, fn) table.insert(list, fn); return { Disconnect = function() end } end,
		Fire = function(_, ...) local c = table.clone(list); table.clear(list); for _, fn in c do fn(...) end end }
end
local function new(class: string): any
	local o = setmetatable({ _props = { ClassName = class, Name = class, Ended = signal(), Destroying = signal() } }, Inst)
	table.insert(objects, o); return o
end
function Inst:GetFullName() return if self.Parent and self.Parent.Parent then self.Parent.Name .. "." .. self.Name else self.Name end
function Inst:GetChildren() local out = {}; for _, o in objects do if rawget(o, "_props").Parent == self then table.insert(out, o) end end; return out end
function Inst:IsA(c) return self.ClassName == c end
function Inst:FindFirstChild() return nil end
function Inst:Play() self.Playing = true end
function Inst:Destroy()
	local raw = rawget(self, "_props")
	if raw.Dead then return end
	if raw.Busy then error("The Parent property of " .. self:GetFullName() .. " is locked") end
	raw.Busy = true
	self.Destroying:Fire()
	for _, child in self:GetChildren() do child:Destroy() end
	self.Parent = nil; raw.Locked, raw.Dead = true, true
end
local workspace = new("Workspace"); workspace.Name = "Workspace"
local SoundService = new("SoundService")
local fakeTask = {
	defer = function(fn, ...) table.insert(queue, { fn, ... }) end,
	delay = function(t, fn, ...) table.insert(timers, { now + t, fn, ... }) end,
}
local function run(fn, ...) local ok, err = pcall(fn, ...); if not ok then table.insert(errors, tostring(err)) end end
local function flush()
	while #queue > 0 do local item = table.remove(queue, 1); run(table.unpack(item)) end
end
local function advance(t: number)
	now += t
	for i = #timers, 1, -1 do
		local item = timers[i]
		if item[1] <= now then table.remove(timers, i); run(table.unpack(item, 2)) end
	end
	flush()
end
local Assets = { Audio = { Clash = "rbxassetid://1", Blunt = "rbxassetid://2", Water = "rbxassetid://3", Wind = "rbxassetid://4" }, Limits = { Voices = 32 } }
local game = { GetService = function(_, n)
	if n == "SoundService" then return SoundService end
	return { WaitForChild = function() return { Shared = { PresentationAssets = Assets } } end }
end }
local Audio = load("src/client/Controllers/SpatialAudio.luau", { game = game, workspace = workspace, task = fakeTask,
	Instance = { new = new }, require = function(m) return m end, Enum = { RollOffMode = { InverseTapered = "InverseTapered" } },
	Random = { new = function() return { NextNumber = function(_, a, b) return (a + b) / 2 end } end } })
local function alive(class: string): number
	local n = 0; for _, o in objects do if o.ClassName == class and not rawget(o, "_props").Dead then n += 1 end end; return n
end

-- Legacy pattern reproduces the report: the sound's Destroying handler destroys its parent part.
do
	local p = new("Part"); p.Name, p.Parent = "AsuraAudioSource", workspace
	local snd = new("Sound"); snd.Name, snd.Parent = "Asura_Blunt", p
	snd.Destroying:Once(function() if p.Parent then p:Destroy() end end)
	local ok, err = pcall(function() snd:Destroy() end)
	check("legacy cleanup reproduces locked-Parent error", not ok and string.find(tostring(err), "AsuraAudioSource.Asura_Blunt is locked") ~= nil)
end
local baseParts = alive("Part")
-- Ended path, never-loading asset (lifetime bound), external source and sound destruction.
local a = Audio.at("Blunt", roblox.Vector3.zero, 0.7); local aPart = a.Parent; a.Ended:Fire(); flush()
check("ended cue frees its source part", rawget(aPart, "_props").Dead and rawget(a, "_props").Dead and Audio.stats().Sources == 0)
local b = Audio.at("Clash", roblox.Vector3.zero); advance(12.1)
check("never-loading cue bounded by lifetime", rawget(b, "_props").Dead and Audio.stats().Voices == 0)
local c = Audio.at("Clash", roblox.Vector3.zero); local cPart = c.Parent; cPart:Destroy(); flush()
check("source part destroyed first (debris/parent)", rawget(c, "_props").Dead and Audio.stats().Sources == 0)
local d = Audio.at("Clash", roblox.Vector3.zero); local dPart = d.Parent; d:Destroy(); flush()
check("sound destroyed first still frees its part", rawget(dPart, "_props").Dead)
c.Ended:Fire(); advance(13); flush()
check("late Ended/timeouts after release are no-ops", #errors == 0)
-- Repeated hits and parries with eviction pressure; then a death removes the character root.
local root = new("Part"); root.Name, root.Parent = "HumanoidRootPart", workspace
local loop = Audio.play("Wind", SoundService, 0.2, true)
local slide = Audio.play("Clash", root, 0.3, true)
local peak = 0
for i = 1, 600 do
	local cue = Audio.at(if i % 2 == 0 then "Blunt" else "Clash", roblox.Vector3.zero)
	if i % 3 == 0 and cue then cue.Ended:Fire() end
	if i % 50 == 0 then advance(2) end
	local st = Audio.stats(); peak = math.max(peak, st.Voices)
	if st.Sources > st.Voices then check("sources never outnumber voices", false) end
end
check("voice pool bounded under combat spam", peak <= Assets.Limits.Voices and not rawget(loop, "_props").Dead)
root:Destroy(); flush()
check("death releases voices on the character", rawget(slide, "_props").Dead)
-- Batch 26: repeated combat -> rest -> death cycles return voices, sources and parts to baseline.
do
	advance(13) -- let the spam's one-shot cues expire before sampling the baseline
	local parts, voices = alive("Part"), Audio.stats().Voices
	local drift = 0
	for cycle = 1, 30 do
		local body = new("Part"); body.Name, body.Parent = "HumanoidRootPart", workspace
		Audio.play("Clash", body, 0.3, true) -- a looped scrape on the character
		for i = 1, 40 do
			local cue = Audio.at(if i % 2 == 0 then "Blunt" else "Clash", roblox.Vector3.zero)
			if i % 4 == 0 and cue then cue.Ended:Fire() end
		end
		Audio.zone(if cycle % 2 == 0 then "Sanctuary" else "DesecratedMonastery") -- rest / travel
		advance(13) -- one-shot lifetimes run out at the altar
		body:Destroy(); flush() -- death
		local st = Audio.stats()
		drift = math.max(drift, math.abs(st.Voices - voices) + st.Sources)
	end
	check(string.format("30 combat/rest/death cycles return to baseline (drift %d)", drift), drift == 0 and alive("Part") == parts)
	check("and throw no cleanup exceptions", #errors == 0)
end
-- Looped world source (cloister water) and shutdown.
local water = Audio.at("Water", roblox.Vector3.zero, 0.3, true); local waterPart = water.Parent
Audio.destroy(); flush(); advance(20)
check("shutdown releases loops and world sources", rawget(loop, "_props").Dead and rawget(waterPart, "_props").Dead)
check("no orphan sources after shutdown", Audio.stats().Voices == 0 and Audio.stats().Sources == 0 and alive("Part") == baseParts)
check("no cleanup exceptions (" .. table.concat(errors, " | ") .. ")", #errors == 0)

-- 4. Decorative effects hook (batch 25 wires the settings toggle to setReduced).
check("decor full while exploring", Effects.decor(false) == 1 and Effects.decor(true) < 0.5)
local heard = nil
local stop = Effects.onChanged(function(v) heard = v end)
Effects.setReduced(true)
check("reduced effects notifies and removes combat decoration", heard == true and Effects.decor(true) == 0 and Effects.decor(false) < 1)
stop(); Effects.setReduced(false); check("unsubscribed listener stays quiet", heard == true and Effects.reduced() == false)

-- 5. Runtime wiring (source checks).
local function src(path: string): string return fs.readFile(path) end
check("ArenaLighting builds fill lanterns", string.find(src("src/server/Services/ArenaLighting.luau"), "Plan.fills", 1, true) ~= nil)
check("EnvironmentController uses the arena biome", string.find(src("src/client/Controllers/EnvironmentController.luau"), "definition.Region", 1, true) ~= nil)
check("SakuraHud petals follow the effects hook", string.find(src("src/client/Controllers/SakuraHud.luau"), "Effects.decor", 1, true) ~= nil)
check("ArenaAsh follows the effects hook", string.find(src("src/client/Controllers/ArenaAsh.luau"), "Effects.decor", 1, true) ~= nil)
check("Soundscape water owned by SpatialAudio", string.find(src("src/client/Controllers/SoundscapeController.luau"), "Destroying:Once", 1, true) == nil)
check("no Debris on audio sources", string.find(src("src/client/Controllers/SpatialAudio.luau"), "Debris", 1, true) == nil)

-- F09 (Studio, Reduced flashes on): Blazing Sun's skill bloom still peaked at its full 1.0.
check("spell bloom honours reduced flashes", string.find(src("src/client/Controllers/VoidStage.luau"), "{ Intensity = Comfort.flash(intensity) }", 1, true) ~= nil)
check("spell flash sphere and its light honour reduced flashes", string.find(src("src/client/Controllers/SkillFx.luau"), "ball.Transparency = 1 - Comfort.flash(0.95)", 1, true) ~= nil
	and string.find(src("src/client/Controllers/SkillFx.luau"), "Comfort.flash(8)", 1, true) ~= nil)
-- F09 (Studio): the bare Titan and Wu duel floors (slate 49,45,43) rendered black at dusk and dark
-- costumes vanished on them; the floor tone, not the lights, carries the silhouette.
do
	local r, g, b = string.match(src("src/server/Services/BossArenas.luau"), "Arenas%.FloorColor = Color3%.fromRGB%((%d+), (%d+), (%d+)%)")
	local luminance = r and (0.2126 * tonumber(r) + 0.7152 * tonumber(g) + 0.0722 * tonumber(b)) / 255 or 0
	check("boss duel floors are a mid tone that dark actors read against", luminance >= 0.35 and luminance <= 0.6)
	check("every boss floor uses that tone", string.find(src("src/server/Services/BossArenas.luau"), 'boss.Id .. "Floor", Vector3.new(s.X, 4, s.Z), center - Vector3.new(0, 2, 0), Arenas.FloorColor)', 1, true) ~= nil)
end
print(string.format("combat presentation: %d passed, %d failed", passed, failed))
if failed > 0 then error("combat presentation regression failed") end
