--!strict
-- Server-authored enemy silhouettes for the opening regions, in the same welded-part language as
-- the player's FighterAppearance (no uploaded imagery). Each look colours the rig's body (skin vs.
-- cloth) and builds an "AsuraAttire" folder; CharacterService's tint skips that folder so boss
-- phase recolours never flatten the clothing.
local Appearance = require(script.Parent:WaitForChild("FighterAppearance") :: ModuleScript)

local gear = Appearance.Gear
local EnemyAppearance = {}

local FABRIC, METAL, WOOD = Enum.Material.Fabric, Enum.Material.Metal, Enum.Material.Wood
local EMBER = Color3.fromRGB(255, 70, 40)

type Parts = { Head: BasePart, Torso: BasePart, Waist: BasePart, Model: Model, Outfit: Folder }

local function limb(model: Model, name: string): BasePart?
	local found = model:FindFirstChild(name)
	return if found and found:IsA("BasePart") then found else nil
end

local function colorBody(model: Model, skin: Color3, cloth: Color3)
	for _, item in model:GetChildren() do
		if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" and item.Name ~= "AsuraWeapon" then
			local bare = item.Name == "Head" or string.find(item.Name, "Hand") ~= nil
			item.Color = if bare then skin else cloth
			-- Fabric's weave reads as wicker on whole limbs; keep it for the smaller attire pieces.
			item.Material = Enum.Material.SmoothPlastic
		end
	end
end

-- Corruption reads through the eyes: two faint embers under the brow.
local function emberEyes(p: Parts)
	local h = p.Head.Size
	for side = -1, 1, 2 do
		local eye = gear(p.Outfit, p.Head, "EmberEye", Vector3.new(0.13, 0.06, 0.05), CFrame.new(side * h.X * 0.18, h.Y * 0.08, -h.Z * 0.5 - 0.01), EMBER, Enum.Material.Neon)
		eye.CastShadow = false
	end
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range, light.Shadows = EMBER, 0.6, 5, false
	light.Parent = p.Head
end

local function splitSkirt(p: Parts, front: Color3, back: Color3, length: number)
	local w = p.Waist.Size
	for side = -1, 1, 2 do
		gear(p.Outfit, p.Waist, "RaggedSkirtBack", Vector3.new(w.X * 0.5, length, 0.12),
			CFrame.new(side * w.X * 0.26, -length * 0.5 - 0.1, w.Z * 0.5 + 0.08) * CFrame.Angles(math.rad(-7), 0, side * math.rad(6)), back, FABRIC)
		gear(p.Outfit, p.Waist, "RaggedSkirtFront", Vector3.new(w.X * 0.42, length * 0.8, 0.12),
			CFrame.new(side * w.X * 0.28, -length * 0.4 - 0.1, -w.Z * 0.5 - 0.08) * CFrame.Angles(math.rad(7), 0, side * math.rad(-8)), front, FABRIC)
	end
end

local LOOKS: { [string]: (p: Parts) -> () } = {
	-- Fallen temple monk: ash-grey skin, rust kasaya over one shoulder, rope belt, prayer beads.
	CorruptWanderingMonk = function(p)
		local rust, robe, rope = Color3.fromRGB(96, 40, 26), Color3.fromRGB(46, 34, 28), Color3.fromRGB(120, 104, 78)
		colorBody(p.Model, Color3.fromRGB(104, 98, 92), robe)
		local t, w = p.Torso.Size, p.Waist.Size
		gear(p.Outfit, p.Torso, "KasayaDrape", Vector3.new(t.X * 0.62, t.Y * 1.25, t.Z + 0.16),
			CFrame.new(-t.X * 0.12, 0, 0) * CFrame.Angles(0, 0, math.rad(24)), rust, FABRIC)
		gear(p.Outfit, p.Waist, "RopeBelt", Vector3.new(w.X + 0.12, 0.2, w.Z + 0.12), CFrame.new(0, 0.1, 0), rope, FABRIC)
		for bead = 0, 11 do
			local a = bead / 12 * math.pi * 2
			local b = gear(p.Outfit, p.Torso, "PrayerBead", Vector3.new(0.17, 0.17, 0.17),
				CFrame.new(math.sin(a) * t.X * 0.36, t.Y * 0.36 - math.abs(math.cos(a)) * 0.25, -math.cos(a) * t.Z * 0.55), Color3.fromRGB(34, 26, 22), WOOD)
			b.Shape = Enum.PartType.Ball
		end
		splitSkirt(p, robe, rust:Lerp(robe, 0.5), 1.25)
		-- Brawler role: bare forearms bound in stained wraps and iron-knuckled fists.
		for _, name in { "LeftLowerArm", "RightLowerArm", "LeftHand", "RightHand" } do
			local arm = limb(p.Model, name)
			if arm then
				local fist = string.find(name, "Hand") ~= nil
				gear(p.Outfit, arm, if fist then "IronKnuckles" else "StainedWraps", arm.Size + (if fist then Vector3.new(0.18, 0.12, 0.18) else Vector3.new(0.06, -0.2, 0.06)),
					CFrame.new(), if fist then Color3.fromRGB(70, 66, 62) else Color3.fromRGB(112, 100, 84), if fist then METAL else FABRIC)
			end
		end
		emberEyes(p)
	end,
	-- Ash Pagoda guard: dark iron lamellar, pauldrons, black kasa and a tattered cloak.
	CursedSwordsman = function(p)
		local iron, cloth, straw = Color3.fromRGB(66, 66, 70), Color3.fromRGB(24, 24, 28), Color3.fromRGB(58, 48, 34)
		colorBody(p.Model, Color3.fromRGB(88, 80, 74), cloth)
		local t, h = p.Torso.Size, p.Head.Size
		for row = 0, 3 do
			gear(p.Outfit, p.Torso, "Lamellar", Vector3.new(t.X + 0.14, t.Y * 0.22, t.Z + 0.14),
				CFrame.new(0, t.Y * (0.33 - row * 0.22), 0), if row % 2 == 0 then iron else iron:Lerp(cloth, 0.3), METAL)
		end
		for side = -1, 1, 2 do
			gear(p.Outfit, p.Torso, "Pauldron", Vector3.new(0.9, 0.22, t.Z + 0.35),
				CFrame.new(side * (t.X * 0.5 + 0.3), t.Y * 0.42, 0) * CFrame.Angles(0, 0, side * math.rad(-22)), iron, METAL)
		end
		for tier = 0, 9 do
			local radius = 1.6 * (1 - tier / 10.5)
			gear(p.Outfit, p.Head, "BlackKasa", Vector3.new(0.09, radius * 2, radius * 2),
				CFrame.new(0, h.Y * 0.42 + tier * 0.1, 0) * CFrame.Angles(0, 0, math.pi * 0.5), straw:Lerp(cloth, tier / 12), WOOD, true)
		end
		gear(p.Outfit, p.Torso, "TatteredCloak", Vector3.new(t.X * 1.05, t.Y * 2.1, 0.1),
			CFrame.new(0, -t.Y * 0.45, t.Z * 0.5 + 0.12) * CFrame.Angles(math.rad(-6), 0, 0), Color3.fromRGB(34, 22, 22), FABRIC)
		splitSkirt(p, cloth, iron, 1.1)
		-- Swordsman role: the dao's lacquered scabbard rides the left hip.
		gear(p.Outfit, p.Waist, "Scabbard", Vector3.new(0.22, 0.4, 3.4), CFrame.new(-p.Waist.Size.X * 0.62, -0.2, 0.3) * CFrame.Angles(math.rad(-28), 0, 0), Color3.fromRGB(40, 22, 20), WOOD)
		emberEyes(p)
	end,
	-- Sparring Phantom: a translucent jade training spirit with a white sash; never mistaken for a foe.
	SparringPhantom = function(p)
		local jade = Color3.fromRGB(150, 220, 196)
		colorBody(p.Model, jade, jade)
		for _, item in p.Model:GetChildren() do
			if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" then item.Transparency, item.Material = 0.35, Enum.Material.Glass end
		end
		local sash = gear(p.Outfit, p.Waist, "TrainingSash", p.Waist.Size + Vector3.new(0.14, 0.2, 0.14), CFrame.new(), Color3.fromRGB(240, 240, 232), FABRIC)
		sash.Transparency = 0.1
		local glow = Instance.new("PointLight")
		glow.Color, glow.Brightness, glow.Range, glow.Shadows = jade, 0.8, 8, false
		glow.Parent = p.Torso
	end,
}

function EnemyAppearance.Has(definition: string?): boolean
	return definition ~= nil and LOOKS[definition] ~= nil
end

-- Returns true when a look was applied; callers fall back to the flat body tint otherwise.
function EnemyAppearance.Apply(model: Model, definition: string?): boolean
	local build = if definition then LOOKS[definition] else nil
	local head, torso = limb(model, "Head"), limb(model, "UpperTorso") or limb(model, "Torso")
	local waist = limb(model, "LowerTorso") or torso
	if not build or not head or not torso or not waist then
		return false
	end
	local outfit = Instance.new("Folder")
	outfit.Name = "AsuraAttire"
	outfit.Parent = model
	build({ Head = head, Torso = torso, Waist = waist, Model = model, Outfit = outfit })
	return true
end

return table.freeze(EnemyAppearance)
