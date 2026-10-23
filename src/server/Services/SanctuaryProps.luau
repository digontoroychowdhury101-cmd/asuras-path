--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/SanctuaryProps
-- Repeated Shrine dressing built from the lobby kit: stone lanterns with frosted paper chambers, cloth
-- banners on poles with a gold seal, and memorial stelae carrying an engraved inscription. Each solid
-- prop gets one invisible collision box; cloth, glow and text never collide.
local Kit = require(script.Parent:WaitForChild("SanctuaryKit") :: ModuleScript)
local Assets = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.PresentationAssets)

local Props = {}

local function invisible(): any
	return { Collide = true, Query = false, Transparency = 1, Shadow = false }
end

local function branchCard(group: Instance, cf: CFrame, width: number, height: number, tint: Color3)
	if Kit.branchCard(group, cf, width, height, tint) then return end
	local card = Kit.hidden(group, "CrimsonBranchSpray", Vector3.new(width, height, 0.04), cf)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local image = Instance.new("Decal")
		image.Name, image.Texture, image.Face, image.Color3 = "CrimsonSpray", Assets.Textures.CrimsonBranch, face, tint
		image.Parent = card
	end
end

local function removeBlob(model: Model)
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child.Name:find("__Foliage", 1, true) then
			child:Destroy()
		end
	end
end

-- Stone lantern standing on `cf` (floor). A shaded paper chamber sits behind its carved posts.
function Props.lantern(group: Instance, cf: CFrame, range: number?)
	local shell = Kit.place(group, "Lantern_Stone", cf)
	if not shell then Kit.lanternFallback(group, cf, false) end
	Kit.glow(group, cf * CFrame.new(0, 3.35, 0), Vector3.new(1.04, 1.12, 1.04), range or 15, 1.35)
	Kit.part(group, "LanternCollision", Vector3.new(1.9, 4.4, 1.9), cf * CFrame.new(0, 2.2, 0), Color3.new(), Enum.Material.SmoothPlastic, invisible())
end

-- Banner hanging from a pole on `cf` (floor); the cloth faces the pole's front (-Z).
function Props.banner(group: Instance, cf: CFrame, height: number?)
	local h = height or 14
	Kit.slab(group, "BannerFoot", Vector3.new(1, 0.42, 1), cf * CFrame.new(0, 0.21, 0), "StoneDark", Kit.decor())
	Kit.slab(group, "BannerPole", Vector3.new(0.45, h, 0.45), cf * CFrame.new(0, h / 2, 0), "Timber", Kit.decor())
	Kit.slab(group, "BannerBar", Vector3.new(3.6, 0.28, 0.28), cf * CFrame.new(0, h - 0.6, -0.35), "Bronze", Kit.decor())
	-- The kit cloth (Banner_Cloth) carries its own folds, gold border and lotus seal.
	if Kit.place(group, "Banner_Cloth", cf * CFrame.new(0, h - 0.75, -0.42), nil, false) then
		return
	end
	local cloth = Kit.part(group, "Banner", Vector3.new(3.1, 8.2, 0.1), cf * CFrame.new(0, h - 4.8, -0.4), Kit.Palette.Banner, Enum.Material.Fabric, Kit.decor())
	Kit.part(group, "BannerHem", Vector3.new(3.12, 0.6, 0.12), cf * CFrame.new(0, h - 8.6, -0.4), Kit.Palette.BannerDark, Enum.Material.Fabric, Kit.decor())
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face, gui.SizingMode, gui.PixelsPerStud, gui.LightInfluence = face, Enum.SurfaceGuiSizingMode.PixelsPerStud, 32, 1
		local label = Instance.new("TextLabel")
		label.Size, label.Position, label.BackgroundTransparency = UDim2.fromScale(0.8, 0.5), UDim2.fromScale(0.1, 0.12), 1
		label.Text, label.TextScaled, label.Font, label.TextColor3 = "修\n羅", true, Enum.Font.Antique, Kit.Palette.Gold
		label.Parent = gui
		gui.Parent = cloth
	end
end

-- Memorial stele on `cf` (floor), inscription on its front (-Z) panel.
function Props.stele(group: Instance, cf: CFrame, text: string, broken: boolean?)
	local piece = if broken then "Stele_Broken" else "Stele_Dragon"
	if not Kit.place(group, piece, cf) then
		Kit.slab(group, "MemorialStele", Vector3.new(2.6, if broken then 3.6 else 6.8, 0.9), cf * CFrame.new(0, if broken then 1.8 else 3.4, 0), "Stone")
	end
	local height = if broken then 4.4 else 8
	Kit.part(group, "SteleCollision", Vector3.new(4.4, height, 2), cf * CFrame.new(0, height / 2, 0), Color3.new(), Enum.Material.SmoothPlastic, invisible())
	if text == "" then
		return
	end
	local plate = Kit.part(group, "SteleInscription", Vector3.new(1.8, 3.6, 0.05), cf * CFrame.new(0, 3.75, -0.52), Color3.new(), Enum.Material.Slate, Kit.decor())
	plate.Transparency = 1
	local gui = Instance.new("SurfaceGui")
	gui.Face, gui.SizingMode, gui.PixelsPerStud, gui.LightInfluence = Enum.NormalId.Front, Enum.SurfaceGuiSizingMode.PixelsPerStud, 40, 1
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency, label.Text, label.TextScaled = UDim2.fromScale(1, 1), 1, text, true
	label.Font, label.TextColor3, label.TextTransparency = Enum.Font.Antique, Color3.fromRGB(58, 60, 60), 0.1
	label.Parent = gui
	gui.Parent = plate
end

-- Crimson maple (or the smaller one) on `cf`; only its trunk collides.
function Props.tree(group: Instance, cf: CFrame, scale: number?, small: boolean?)
	-- These are secondary garden trees; the unchanged imported sacred tree owns the skyline.
	local s = (scale or 1) * 0.78
	local tree = Kit.place(group, if small then "Tree_MapleSmall" else "Tree_Maple", cf, s)
	if tree then
		removeBlob(tree)
		local rng = Random.new(math.floor(cf.X * 23 + cf.Z * 19) % 100000)
		local height = if small then 12 else 15
		for layer = 1, 3 do
			for k = 0, 3 do
				local angle = math.rad(k * 90 + layer * 31) + rng:NextNumber(-0.2, 0.2)
				local radius = (if layer == 2 then 4.6 elseif layer == 3 then 2.7 else 3.6) * s
				local pos = Vector3.new(math.cos(angle) * radius, (height * (0.43 + layer * 0.14) + rng:NextNumber(-0.5, 0.5)) * s, math.sin(angle) * radius)
				local frame = cf * CFrame.new(pos) * CFrame.Angles(rng:NextNumber(-0.22, 0.22), -angle + math.pi / 2, rng:NextNumber(-0.3, 0.3))
				branchCard(tree, frame, (if layer == 2 then 8 else 6) * s, (if layer == 2 then 4 else 3.5) * s,
					if k % 2 == 0 then Color3.fromRGB(195, 177, 169) else Color3.fromRGB(179, 162, 165))
			end
		end
		Kit.part(group, "TrunkCollision", Vector3.new(2.6, 9, 2.6) * s, cf * CFrame.new(0, 4.5 * s, 0), Color3.new(), Enum.Material.SmoothPlastic, invisible())
	end
end

function Props.shrub(group: Instance, cf: CFrame, scale: number?)
	local s = (scale or 1) * 0.68
	local shrub = Kit.place(group, "Shrub_Crimson", cf * CFrame.new(0, -0.15, 0), s)
	if not shrub then return end
	removeBlob(shrub)
	for k = 0, 4 do
		local angle = math.rad(k * 137 + 17)
		local radius = (if k % 2 == 0 then 1.1 else 0.6) * s
		local frame = cf * CFrame.new(math.cos(angle) * radius, (1.15 + (k % 3) * 0.25) * s, math.sin(angle) * radius)
			* CFrame.Angles(math.rad(-12 + k * 5), angle, math.rad(-18 + k * 8))
		branchCard(shrub, frame, 4.5 * s, 2.8 * s, Color3.fromRGB(190, 172, 163))
	end
end

-- Low resting bench, facing -Z, reserved for the outer edges of galleries and the shrine walk.
function Props.bench(group: Instance, cf: CFrame)
	Kit.slab(group, "BenchSeat", Vector3.new(6.8, 0.28, 1.9), cf * CFrame.new(0, 1.92, 0), "Timber", Kit.decor())
	for _, x in { -2.5, 2.5 } do
		Kit.slab(group, "BenchTrestle", Vector3.new(0.6, 1.8, 1.55), cf * CFrame.new(x, 0.9, 0), "Timber", Kit.decor())
		Kit.slab(group, "BenchFoot", Vector3.new(0.95, 0.2, 1.85), cf * CFrame.new(x, 0.1, 0), "Timber", Kit.decor())
	end
	Kit.slab(group, "BenchStretcher", Vector3.new(5.1, 0.32, 0.36), cf * CFrame.new(0, 0.65, 0), "Timber", Kit.decor())
	Kit.part(group, "BenchCollision", Vector3.new(6.8, 2.1, 1.9), cf * CFrame.new(0, 1.05, 0), Color3.new(), Enum.Material.SmoothPlastic, invisible())
end

-- Iron brazier on a bronze-banded stand (court corners, gate approaches): real fire and warm light.
function Props.brazier(group: Instance, cf: CFrame, range: number?)
	local iron = Kit.Palette.Iron
	Kit.part(group, "BrazierStand", Vector3.new(0.55, 3.8, 0.55), cf * CFrame.new(0, 1.9, 0), iron, Enum.Material.Metal)
	Kit.disc(group, "BrazierFoot", 1.0, 0.3, cf * CFrame.new(0, 0.15, 0), iron, Enum.Material.Metal)
	Kit.disc(group, "BrazierBowl", 1.35, 0.7, cf * CFrame.new(0, 4.1, 0), iron, Enum.Material.Metal).MaterialVariant = "AsuraBronze"
	local coals = Kit.disc(group, "BrazierCoals", 1.1, 0.2, cf * CFrame.new(0, 4.5, 0), Color3.fromRGB(49, 38, 32), Enum.Material.Slate, Kit.decor())
	for k = 0, 6 do
		local a = math.rad(k * 137)
		Kit.part(group, "BankedCoal", Vector3.new(0.48, 0.24, 0.36), cf * CFrame.new(math.cos(a) * 0.65, 4.62, math.sin(a) * 0.65),
			Color3.fromRGB(62, 42, 31), Enum.Material.Slate, { Collide = false, Query = false, Shadow = false, Shape = Enum.PartType.Ball })
	end
	local fire = Instance.new("Fire")
	fire.Size, fire.Heat, fire.Color, fire.SecondaryColor = 2.2, 4, Color3.fromRGB(255, 150, 60), Color3.fromRGB(220, 60, 20)
	fire.Parent = coals
	Kit.light(coals, Color3.fromRGB(255, 170, 100), range or 18, 1.1, false)
end

return table.freeze(Props)
