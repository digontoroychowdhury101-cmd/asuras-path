--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/CryptDressing
-- The Sunken Crypt's depth and storytelling (batch 19). All decor: ribbed vaults over the nave and
-- the ossuary (the Titan's hall stays open to a far crack of sky, so his height, the Wyrm-free air and
-- the camera are never capped), bone niches, candle drifts on the sarcophagi, the Titan's broken
-- chains anchored at the hall's corners, a pale inlaid ring on the hall floor that keeps his ankles
-- legible against the stone, teal light from the flooded pit, and carved signs at the landing and
-- the gallery. Lighting is warm and pale instead of near-black (with EnvironmentProfiles). Collision
-- lives in SunkenCryptLayout.
local Kit = require(script.Parent:WaitForChild("MonasteryKit") :: ModuleScript)
local Fx = require(script.Parent:WaitForChild("MonasteryFx") :: ModuleScript)
local Decor = require(script.Parent:WaitForChild("RegionDecor") :: ModuleScript)

local Dressing = {}
local P = Kit.Palette
local M = Enum.Material
local rgb = Color3.fromRGB
local VAULT = rgb(58, 64, 70)
local BONE = rgb(206, 196, 170)
local TEAL = rgb(120, 214, 206)

local function sign(parent: Instance, text: string, cf: CFrame)
	local board = Kit.part(parent, "CarvedSign", Vector3.new(7, 1.8, 0.3), cf, rgb(44, 48, 52), M.Slate, Kit.decor())
	local gui = Instance.new("SurfaceGui")
	gui.Face, gui.LightInfluence, gui.PixelsPerStud = Enum.NormalId.Front, 0.4, 40
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency, label.Text = UDim2.fromScale(1, 1), 1, text
	label.Font, label.TextScaled, label.TextColor3 = Enum.Font.Antique, true, rgb(226, 206, 160)
	label.Parent = gui
end

function Dressing.Build(map: Instance, _layout: any, rng: Random)
	local set = Kit.folder("CryptDressing", map)
	-- Vaults: ribs and shells over the nave (z 975..1046) and the ossuary (x 356..404), none over the hall.
	for x = 364, 620, 16 do
		Kit.part(set, "VaultRib", Vector3.new(2, 2, 74), CFrame.new(x, 44, 1010), VAULT, M.Slate, Kit.decor())
	end
	Kit.part(set, "VaultShell", Vector3.new(272, 2, 76), CFrame.new(492, 47, 1010), VAULT:Lerp(rgb(30, 34, 38), 0.4), M.Slate, Kit.decor())
	Kit.part(set, "VaultShell", Vector3.new(50, 2, 196), CFrame.new(380, 47, 874), VAULT:Lerp(rgb(30, 34, 38), 0.4), M.Slate, Kit.decor())
	-- Bone niches along the ossuary and nave walls.
	for z = 790, 1040, 10 do
		if z < 850 or z > 900 then
			Kit.part(set, "BoneNiche", Vector3.new(1.2, 3, 7), CFrame.new(358.8, 6 + (z % 20) * 0.2, z), rgb(34, 36, 40), M.Slate, Kit.decor())
			for k = -1, 1 do
				local skull = Kit.part(set, "Skull", Vector3.new(1, 1, 1), CFrame.new(359.3, 5.4 + (z % 20) * 0.2, z + k * 2), BONE, M.Limestone, Kit.decor())
				skull.Shape = Enum.PartType.Ball
			end
		end
	end
	-- Candle drifts on the sarcophagi and the gallery sill.
	for _, spot in { { 384, 3, 1012 }, { 404, 3, 1028 }, { 572, 3, 1004 }, { 596, 3, 1020 }, { 452, 15, 1022 }, { 366, 0.4, 812 } } do
		for _ = 1, 5 do
			Kit.part(set, "Candle", Vector3.new(0.3, rng:NextNumber(0.5, 1.2), 0.3),
				CFrame.new(spot[1] + rng:NextNumber(-1.4, 1.4), spot[2] + 0.4, spot[3] + rng:NextNumber(-2.5, 2.5)), BONE, M.Limestone, Kit.decor())
		end
		local glow = Kit.hidden(set, "CandleGlow", Vector3.one, CFrame.new(spot[1], spot[2] + 1.4, spot[3]))
		Fx.glow(glow, 0.6)
		Kit.light(glow, rgb(255, 196, 140), 14, 0.9, false)
	end
	-- The Titan's broken chains: anchors at the hall's corners, links slack on the floor.
	for _, c in { { 434, 794 }, { 606, 794 }, { 434, 966 }, { 606, 966 } } do
		Kit.part(set, "ChainAnchor", Vector3.new(4, 6, 4), CFrame.new(c[1] + (if c[1] < 520 then -8 else 8), 3, c[2]), rgb(40, 38, 40), M.Metal, Kit.decor())
		for k = 1, 6 do
			Kit.part(set, "ChainLink", Vector3.new(2.4, 0.5, 1.2), CFrame.new(c[1] + (if c[1] < 520 then -6 + k * 2 else 6 - k * 2), 0.3, c[2] + rng:NextNumber(-1, 1))
				* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), rgb(54, 50, 50), M.Metal, Kit.decor())
		end
	end
	-- A pale inlaid ring on the hall floor (top 0): reads under the Titan's feet without blocking.
	for k = 0, 23 do
		local a = math.rad(k * 15)
		Kit.part(set, "InlayRing", Vector3.new(10.6, 0.06, 1.2), CFrame.new(520 + math.cos(a) * 40, 0.04, 880 + math.sin(a) * 40) * CFrame.Angles(0, -a + math.pi / 2, 0),
			rgb(176, 168, 150), M.Marble, Kit.decor())
	end
	-- Light: teal from the pit, pale shafts in the hall, warm braziers by the gate.
	local pit = Kit.hidden(set, "PitGlow", Vector3.one, CFrame.new(380, -8, 875))
	Kit.light(pit, TEAL, 40, 1.2, false)
	for _, spot in { { 470, 40, 830 }, { 570, 40, 830 }, { 470, 40, 930 }, { 570, 40, 930 } } do
		local shaft = Kit.hidden(set, "SkyShaft", Vector3.one, CFrame.new(spot[1], spot[2], spot[3]))
		Kit.light(shaft, rgb(200, 220, 230), 60, 1.1, false)
	end
	for _, x in { 504, 536 } do
		Decor.brazier(set, CFrame.new(x, 0, 1012))
	end
	Fx.mist(set, CFrame.new(380, -4, 875), Vector3.new(46, 6, 48), 2, 18, TEAL)
	-- Way signs: back to the shrine at the landing, down to the nave from the gallery.
	sign(set, "RETURN TO THE SHRINE  ↑", CFrame.new(520, 38, 1077.6))
	sign(set, "THE TITAN'S HALL  ↓", CFrame.new(455, 19, 1077.6))
end

return Dressing
