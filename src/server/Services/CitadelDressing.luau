--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/CitadelDressing
-- Sky Citadel skyline, weather and storytelling (batch 21). All decor and none of it over the
-- summit: a sea of cloud far below the bridge, ruined citadel towers ringing the chasm and the
-- bastion (outside the veil), torn azure banners on the battlements, chain posts that mark the
-- saddle stair's edges, the dragon's perch with gouged rock and broken chains, and wind-driven
-- sleet. The summit plateau keeps open air for the Wyrm's flight and landings. Collision lives in
-- SkyCitadelLayout.
local Kit = require(script.Parent:WaitForChild("MonasteryKit") :: ModuleScript)
local Fx = require(script.Parent:WaitForChild("MonasteryFx") :: ModuleScript)
local Decor = require(script.Parent:WaitForChild("RegionDecor") :: ModuleScript)

local Dressing = {}
local P = Kit.Palette
local M = Enum.Material
local rgb = Color3.fromRGB
local AZURE = rgb(64, 96, 150)
local CLOUD = rgb(214, 220, 236)

local function ruinTower(parent: Instance, x: number, z: number, height: number, rng: Random)
	local base = CFrame.new(x, -60, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	Kit.part(parent, "CitadelTower", Vector3.new(16, height, 16), base * CFrame.new(0, height / 2, 0), rgb(122, 126, 138), M.Slate, Kit.decor())
	Kit.part(parent, "TowerBreak", Vector3.new(12, 6, 9), base * CFrame.new(-2, height + 1, 1) * CFrame.Angles(0, 0, math.rad(14)), rgb(108, 112, 124), M.Slate, Kit.decor())
	if rng:NextNumber() < 0.6 then
		Decor.roof(parent, base * CFrame.new(0, height - 6, 0), 22, 22, 5, rgb(52, 60, 80))
	end
end

function Dressing.Build(map: Instance, _layout: any, rng: Random)
	local set = Kit.folder("CitadelDressing", map)
	-- The cloud sea far below, and banks drifting through the chasm.
	for _, c in { { 0, -2600, 360, 200 }, { -170, -2820, 160, 360 }, { 170, -2820, 160, 360 }, { 0, -2960, 360, 80 } } do
		Kit.part(set, "CloudSea", Vector3.new(c[3], 2, c[4]), CFrame.new(c[1], -96, c[2]), CLOUD, M.Glass, { Collide = false, Query = false, Shadow = false, Transparency = 0.35 })
	end
	Fx.mist(set, CFrame.new(0, -48, -2600), Vector3.new(200, 30, 120), 4, 40, CLOUD)
	Fx.mist(set, CFrame.new(0, -40, -2830), Vector3.new(260, 20, 220), 3, 46, CLOUD)
	-- Ruined towers around the chasm and the summit (outside the veil): the skyline from the bridge.
	for _, t in { { -70, -2580, 120 }, { 70, -2600, 140 }, { -120, -2690, 150 }, { 120, -2700, 130 }, { -150, -2860, 170 }, { 150, -2900, 160 } } do
		ruinTower(set, t[1], t[2], t[3], rng)
	end
	-- Banners on the battlements and the gate towers.
	for _, spot in { { -71.5, -2690 }, { -71.5, -2722 }, { 71.5, -2690 }, { 71.5, -2722 } } do
		Decor.banner(set, CFrame.new(spot[1], 6.6, spot[2]) * CFrame.Angles(0, math.rad(90), 0), 8, AZURE)
	end
	for _, side in { -1, 1 } do
		Decor.banner(set, CFrame.new(side * 22, 26, -2719.8), 14, AZURE)
		-- Chain posts marking the saddle stair's edges (the veil stands just outside them).
		for z = -2552, -2584, -8 do
			local y = -(z + 2548) / 2
			Kit.part(set, "ChainPost", Vector3.new(0.8, 3, 0.8), CFrame.new(side * 5.6, y + 1.5, z), P.StoneDark, M.Slate, Kit.decor())
			Kit.beam(set, "Chain", Vector3.new(side * 5.6, y + 2.6, z), Vector3.new(side * 5.6, y - 1.4, z - 8), 0.2, P.Iron, M.Metal)
		end
	end
	-- The dragon's perch: gouges, broken chains, scattered scales.
	for k = 1, 4 do
		Kit.part(set, "ClawGouge", Vector3.new(1, 16, 0.6), CFrame.new(-4 + k * 2, 60 + k * 3, -2944.8) * CFrame.Angles(0, 0, math.rad(12)), rgb(40, 42, 50), M.Slate, Kit.decor())
	end
	for k = 1, 8 do
		Kit.beam(set, "PerchChain", Vector3.new(0, 70, -2952), Vector3.new(math.cos(k) * 30, 10 + k * 3, -2952 + math.sin(k) * 20), 0.5, P.Iron, M.Metal)
	end
	for _ = 1, 12 do
		Kit.part(set, "ShedScale", Vector3.new(1.6, 0.2, 2.2), CFrame.new(rng:NextNumber(-60, 60), 0.12, rng:NextNumber(-2900, -2930))
			* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), rgb(90, 140, 190), M.Glass, Kit.decor())
	end
	-- Wind-driven sleet over the whole approach (thin; effects never compete with telegraphs).
	local sky = Kit.hidden(set, "SleetSky", Vector3.new(300, 1, 460), CFrame.new(0, 90, -2760))
	local sleet = Instance.new("ParticleEmitter")
	sleet.Name, sleet.Texture, sleet.Rate = "Sleet", Kit.Texture.Mote, 18
	sleet.Lifetime, sleet.Speed = NumberRange.new(5, 7), NumberRange.new(18, 26)
	sleet.Acceleration, sleet.EmissionDirection = Vector3.new(14, -8, 4), Enum.NormalId.Bottom
	sleet.Size, sleet.Color = NumberSequence.new(0.18), ColorSequence.new(CLOUD)
	sleet.Transparency, sleet.LightInfluence = NumberSequence.new(0.4), 1
	sleet.Enabled = sleet.Texture ~= ""
	sleet.Parent = sky
end

return Dressing
