--!nonstrict
-- Vesperhold atmosphere (mac-54): the client module is gated by Overworld.vesperholdWeight alone. Weight 0 creates nothing, the weight
-- scales every effect, leaving destroys it, comfort drops lightning, and the lobby/other regions are untouched.
-- Run: python3 tools/lune_compat.py tools/test_vesperhold_atmosphere.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox") :: any
local Vector3, CFrame, Instance = roblox.Vector3, roblox.CFrame, roblox.Instance
local O = require("../src/shared/Overworld")
local L = require("../src/shared/VesperholdLayout")
local B = require("../src/shared/BiomeDressing")

local passed, failed = 0, 0
local function check(name: string, ok: any)
	if ok then passed += 1 else failed += 1; print("FAIL " .. name) end
end

local ws = Instance.new("Folder")
local env = setmetatable({ workspace = ws, require = function(m) return m end,
	game = { GetService = function() return { WaitForChild = function() return { Shared = { Overworld = O, VesperholdLayout = L } } end } end },
	Instance = Instance, Vector3 = Vector3, CFrame = CFrame, Color3 = roblox.Color3, Enum = roblox.Enum, UDim = roblox.UDim, UDim2 = roblox.UDim2,
	Vector2 = roblox.Vector2, NumberSequence = roblox.NumberSequence, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	NumberRange = roblox.NumberRange, ColorSequence = roblox.ColorSequence, Random = roblox.Random }, { __index = _G })
local Atmos = luau.load(fs.readFile("src/client/Controllers/VesperholdAtmosphere.luau"), { debugName = "VesperholdAtmosphere", environment = env })()

local g = O.Vesperhold
local gateCamera = CFrame.new(g.X, g.Y, g.Z) * CFrame.Angles(0, math.rad(g.Yaw), 0) * CFrame.new(0, 10, 300)
local near = gateCamera.Position
local far = Vector3.new(-3000, 140, -2000)
local function root() return #ws:GetChildren() end
local function emitters(a) return a:Counts().Emitters end

-- 1. Weight 0: no effect at all -------------------------------------------------------------------------------------
local a = Atmos.new()
for _ = 1, 50 do a:Update(0, 0.1, near, false) end
check("weight 0 creates nothing and fires no lightning", root() == 0 and a.Folder == nil and a.Flash == 0 and a:Counts().Instances == 0)
a:Update(0.02, 0.1, near, false)
check("a weight at the floor (0.02) is still nothing", root() == 0)

-- 2. Full weight -----------------------------------------------------------------------------------------------------
local mistAnchors = 0
for _, s in L.slots(function(x, z) return 0 end) do if s.Group == "Mist" then mistAnchors += 1 end end
a:Update(1, 0.016, near, false)
local c = a:Counts()
check("one folder holds the whole atmosphere", root() == 1 and ws:FindFirstChild("VesperholdAtmosphere") ~= nil)
check("fog banks in the gorge and between the tiers (>= 6) plus mist at every waterfall anchor", #a.Banks >= 6 and #a.Mists == mistAnchors and mistAnchors >= 3 and c.Emitters == #a.Banks + #a.Mists)
check("crows circle the towers (8)", c.Crows == 8 and #a.Crows == 8)
check("candle pool and tower flash lights exist and start dark", c.Lights == 12 + 3 and (function() for _, gl in a.Glow do if gl.Light.Brightness > 1 then return false end end return not a.BurstLights[1].Enabled end)())
check("eclipse disc, dark core and lightning burst are sky billboards", a.EclipsePart ~= nil and a.EclipseRim.BackgroundTransparency < 0.3 and a.EclipseCore.BackgroundTransparency < 0.1)
local rate1 = a.Banks[1].E.Rate
local before = a.Crows[1].Body.CFrame.Position
a:Update(1, 0.5, near, false)
check("crows fly (positions advance) and flap", (a.Crows[1].Body.CFrame.Position - before).Magnitude > 0.5 and a.Crows[1].L.CFrame ~= a.Crows[1].R.CFrame)
local dir = ((CFrame.new(g.X, g.Y, g.Z) * CFrame.Angles(0, math.rad(g.Yaw), 0) * Vector3.new(0, 380, -900)) - near).Unit
check("the eclipse hangs on the bearing of the spires", (a.EclipsePart.Position - near).Unit:Dot(dir) > 0.999)

-- 3. The weight scales the effects ----------------------------------------------------------------------------------
a:Update(0.5, 0.016, near, false)
check("emitter rates and eclipse opacity scale with the weight", math.abs(a.Banks[1].E.Rate - rate1 * 0.5) < 1e-9 and a.EclipseRim.BackgroundTransparency > 0.5)

-- 4. Lightning -------------------------------------------------------------------------------------------------------
a:Update(1, 0.016, near, false)
check("no strike before one is scheduled", a.Flash == 0 and not a.BurstLights[1].Enabled)
a:Lightning()
a:Update(1, 0.05, near, false)
check("a strike lights the towers and the sky burst", a.Flash > 0.5 and a.BurstLights[1].Enabled and a.BurstLights[1].Brightness > 1 and a.BurstDisc.BackgroundTransparency < 0.5)
a:Update(1, 0.6, near, false)
check("the flash is over within 0.7 s (a short double pulse)", a.Flash == 0 and not a.BurstLights[1].Enabled)
local strikes, t = 0, 0
local prev = 0
for _ = 1, 20000 do -- ~ 55 minutes of 0.167 s steps
	a:Update(1, 1 / 6, near, false)
	if a.Flash > 0 and prev == 0 then strikes += 1 end
	prev = a.Flash
	t += 1 / 6
end
check("lightning is rare (a strike every 14-42 s: " .. strikes .. " in " .. math.floor(t) .. " s)", strikes >= t / 60 and strikes <= t / 10)

-- 5. Candle glow ------------------------------------------------------------------------------------------------------
local candle
for _, s in L.slots(function(x, z) return O.heightAt(g.X - z, g.Z + x) - g.Y end) do
	if s.Group == "Candle" then candle = CFrame.new(g.X, g.Y, g.Z) * CFrame.Angles(0, math.rad(g.Yaw), 0) * Vector3.new(s.X, s.Y + 2, s.Z); break end
end
a:Update(1, 0.6, candle + Vector3.new(3, 0, 3), false)
local lit = 0
for _, gl in a.Glow do if gl.Light.Enabled then lit += 1 end end
check("candle lights light the nearest clusters", lit >= 1 and a.Glow[1].Light.Brightness > 0.5)
a:Update(1, 0.6, far, false)
lit = 0
for _, gl in a.Glow do if gl.Light.Enabled then lit += 1 end end
check("far from every candle no glow light is lit", lit == 0)

-- 6. Comfort: no lightning, half the crows --------------------------------------------------------------------------------
a:Update(1, 0.1, near, true)
check("comfort rebuilds with 4 crows", #a.Crows == 4)
a:Lightning()
a:Update(1, 0.1, near, true)
check("comfort never flashes", a.Flash == 0 and not a.BurstLights[1].Enabled)

-- 7. Leaving the ridge destroys everything --------------------------------------------------------------------------------
a:Update(0, 0.1, near, false)
check("weight back to 0 removes every instance", root() == 0 and a:Counts().Instances == 0 and a.Weight == 0 and a.Flash == 0)
local b = Atmos.new()
b:Update(1, 0.1, near, false)
b:Destroy()
check("Destroy clears the folder", root() == 0)

-- 8. Scope: never touches Lighting, only runs on the ridge ----------------------------------------------------------------
local src = fs.readFile("src/client/Controllers/VesperholdAtmosphere.luau")
check("the module never writes Lighting or tweens", string.find(src, 'GetService("Lighting")', 1, true) == nil and string.find(src, "TweenService", 1, true) == nil)
local weatherSrc = fs.readFile("src/client/Controllers/WeatherController.luau")
check("WeatherController creates the atmosphere only for ridge > 0", string.find(weatherSrc, "if ridge > 0 and not self.Atmos then self.Atmos = Atmosphere.new() end", 1, true) ~= nil
	and string.find(weatherSrc, "if region == \"Snowfields\" then Overworld.vesperholdWeight", 1, true) ~= nil)
check("the weight is zero outside the ridge (lobby and other regions)", O.vesperholdWeight(-3000, -2000) == 0 and O.vesperholdWeight(0, 0) == 0 and O.vesperholdWeight(g.X - 100, g.Z) == 1)

-- 9. The stray red post: no trail stake inside the ridge weight ------------------------------------------------------------
local stakes, inside = 0, 0
for _, p in B.build("Snowfields").Placements do
	if p.Piece == "Snow_Trail_Stake" then
		stakes += 1
		if O.vesperholdWeight(p.X, p.Z) > 0 then inside += 1 end
	end
end
check("trail stakes still stand elsewhere in the Snowfields (" .. stakes .. ") but none inside the Vesperhold weight", stakes > 0 and inside == 0)

print(string.format("vesperhold atmosphere: %d passed, %d failed", passed, failed))
if failed > 0 then error("vesperhold atmosphere checks failed") end
