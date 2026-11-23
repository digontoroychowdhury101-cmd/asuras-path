--!nonstrict
-- Overworld ambience (win-80): one camera-following box, an emitter per kind with a non-zero rate, the live-particle budget,
-- leaf tint toward amber, wind drift, and nothing left behind at rate 0 or on Destroy. Lighting is never touched.
-- Run: python tools/lune_compat.py tools/test_overworld_ambience.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox") :: any
local Vector3, Instance = roblox.Vector3, roblox.Instance
local Wind = require("../src/shared/Wind")

local passed, failed = 0, 0
local function check(name: string, ok: any)
	if ok then passed += 1 else failed += 1; print("FAIL " .. name) end
end

local ws = Instance.new("Folder")
local tagged = {}
local caps = {}
local CollectionService = { GetTagged = function(_, tag) return if tag == "AsuraLanternLight" then tagged elseif tag == "AsuraGlowCap" then caps else {} end }
local env = setmetatable({ workspace = ws,
	game = { GetService = function(_, name)
		if name == "CollectionService" then return CollectionService end
		return { WaitForChild = function() return { Shared = { Wind = "Wind" } } end }
	end },
	require = function() return Wind end,
	Instance = Instance, Vector3 = Vector3, CFrame = roblox.CFrame, Color3 = roblox.Color3, Enum = roblox.Enum, Vector2 = roblox.Vector2,
	NumberSequence = roblox.NumberSequence, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint, NumberRange = roblox.NumberRange,
	ColorSequence = roblox.ColorSequence }, { __index = _G })
local Ambience = luau.load(fs.readFile("src/client/Controllers/OverworldAmbience.luau"), { debugName = "OverworldAmbience", environment = env })()

local at = Vector3.new(-3000, 140, -2000)
local wind = Wind.sample(true, Vector3.new(6, 0, 2), 1)
local a = Ambience.new()
a:Update(0.1, at, { Motes = 0, Leaves = 0, Fireflies = 0, Glitter = 0 }, wind)
check("all rates zero: nothing in the workspace", #ws:GetChildren() == 0 and a.Box == nil)
a:Update(0.1, at, { Motes = 1, Leaves = 0.8, Fireflies = 0, Glitter = 0, Amber = 0 }, wind)
check("one box, parented to the workspace, follows the camera", #ws:GetChildren() == 1 and a.Box.Name == "AsuraAmbienceFx" and (a.Box.Position - at).Magnitude < 10)
check("the box is invisible and never collides, queries or casts shadow", a.Box.Transparency == 1 and not a.Box.CanCollide and not a.Box.CanQuery and not a.Box.CastShadow)
check("an emitter per live kind only", a.Box:FindFirstChild("Motes") ~= nil and a.Box:FindFirstChild("Leaves") ~= nil and a.Box:FindFirstChild("Fireflies") == nil)
for _, e in a.Box:GetChildren() do
	check(e.Name .. " uses an uploaded sprite and stays in the world", string.match(e.Texture, "^rbxassetid://%d+$") ~= nil and e.LockedToPart == false)
end
local leaves = a.Box.Leaves
check("leaves fall and drift with the one wind", leaves.Acceleration.Y < 0 and math.abs(leaves.Acceleration.X / leaves.Acceleration.Z - wind.X / wind.Z) < 1e-6)
check("leaves tumble (spin and edge-on squash)", leaves.RotSpeed.Max > 0 and #leaves.Squash.Keypoints > 2)
local function first(seq) local k = seq.Keypoints[1]; return if typeof(k) == "Color3" then k else k.Value end
local green = first(leaves.Color)
a:Update(0.1, at, { Motes = 1, Leaves = 0.8, Amber = 1 }, wind)
local amber = first(a.Box.Leaves.Color)
check("Amberfall turns the leaves amber", amber.R > green.R and amber.G < green.G)
a:Update(0.1, at, { Motes = 1, Leaves = 1, Fireflies = 1, Glitter = 1, Wisps = 1, Spores = 1 }, wind)
check(string.format("everything at full stays inside the budget (%.0f <= %d)", a:Live(), Ambience.Budget), a:Live() <= Ambience.Budget + 1e-6)
check("night glow kinds get emitters", a.Box:FindFirstChild("Wisps") ~= nil and a.Box:FindFirstChild("Spores") ~= nil)
check("wisps and spores glow on their own (LightEmission 1, LightInfluence 0)", a.Box.Wisps.LightEmission == 1 and a.Box.Spores.LightInfluence == 0)
check("spores rise off the ground", a.Box.Spores.Acceleration.Y > 0)
a:Update(0.1, at, { Motes = 1, Leaves = 0, Fireflies = 0, Glitter = 0 }, wind)
check("a kind dropping to zero loses its emitter", a.Box.Leaves == nil or a.Box:FindFirstChild("Leaves") == nil)
a:Update(0.1, at, { Motes = 1 }, nil)
check("no wind sample yet: still emits, no error", a.Box:FindFirstChild("Motes") ~= nil)
a:Update(0.1, nil, { Motes = 1 }, wind)
check("no camera position: everything cleared", a.Box == nil and #ws:GetChildren() == 0)
a:Update(0.1, at, { Motes = 1 }, wind)
a:Destroy()
check("Destroy leaves nothing behind", #ws:GetChildren() == 0)
check("this module never touches Lighting", string.find(fs.readFile("src/client/Controllers/OverworldAmbience.luau"), "Lighting", 1, true) ~= nil
	and string.find(fs.readFile("src/client/Controllers/OverworldAmbience.luau"), 'GetService("Lighting")', 1, true) == nil)

-- Lantern lights (tagged by the server on every __Glow sub) follow rates.Lanterns: off by day, full after dusk, even with no particles.
for _ = 1, 3 do local l = Instance.new("PointLight"); l.Enabled = false; table.insert(tagged, l) end
local b = Ambience.new()
b:Update(1, at, { Motes = 0, Lanterns = 1 }, wind)
check("night with no particles: every tagged lantern light is on at full", tagged[1].Enabled and tagged[3].Enabled and tagged[2].Brightness >= 1.5 and #ws:GetChildren() == 0)
b:Update(1, at, { Motes = 1, Lanterns = 0.5 }, wind)
check("dusk: lanterns at half strength", tagged[1].Enabled and math.abs(tagged[1].Brightness - 0.5 * Ambience.LanternBrightness) < 1e-6)
b:Update(1, at, { Motes = 1, Lanterns = 0 }, wind)
check("day: lanterns off", not tagged[1].Enabled and not tagged[2].Enabled)
-- Glowing mushroom caps (AsuraGlowCap emitters) follow the same night level, but only near the camera.
local function cap(offset)
	local part = Instance.new("Part"); part.Position = at + offset
	local e = Instance.new("ParticleEmitter"); e.Enabled = false; e.Parent = part
	table.insert(caps, e)
	return e
end
local near, far = cap(Vector3.new(40, 0, 0)), cap(Vector3.new(600, 0, 0))
-- Qi aura: one soft, shadowless light on the player's root after dusk so the floor under the canopy reads at night.
local root = Instance.new("Part")
b:Update(1, at, { Lanterns = 1 }, wind, root)
check("night: a nearby mushroom glows, a far one stays dark", near.Enabled and not far.Enabled)
local aura = root:FindFirstChildOfClass("PointLight")
check("night: the player carries one soft shadowless aura light", aura ~= nil and aura.Enabled and not aura.Shadows and aura.Range >= 18 and aura.Range <= 32
	and #root:GetChildren() == 1)
b:Update(1, at, { Lanterns = 1 }, wind, root)
check("the aura is reused, not stacked", #root:GetChildren() == 1)
b:Update(1, at, { Lanterns = 0 }, wind, root)
check("day: no mushroom glows and the aura is off", not near.Enabled and not aura.Enabled)
local respawned = Instance.new("Part")
b:Update(1, at, { Lanterns = 1 }, wind, respawned)
check("a respawned character gets the aura", respawned:FindFirstChildOfClass("PointLight") ~= nil and respawned:FindFirstChildOfClass("PointLight").Enabled)
b:Destroy()
check("Destroy (leaving the overworld) switches the lanterns off", not tagged[1].Enabled)
check("Destroy darkens the mushrooms and removes the aura", not near.Enabled and respawned:FindFirstChildOfClass("PointLight") == nil)

print(string.format("overworld ambience: %d passed, %d failed", passed, failed))
if failed > 0 then error("overworld ambience checks failed") end
