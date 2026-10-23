--!strict
-- Static crimson sprays and folded prayer silks on the existing sacred tree. Its imported bark,
-- scale and pose stay untouched. Anchors were sampled from the composed GLB's branch vertices and
-- expressed in each imported chunk's local bounding box; they follow its final mounted transform.
-- Twenty-eight sprays / 84 alpha cards reuse the existing uploaded leaf-scatter texture. Mixed
-- card angles give the crown depth from the terrace as well as the courtyard, with open branch gaps.
local Assets = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.PresentationAssets)
local Kit = require(script.Parent:WaitForChild("SanctuaryKit") :: ModuleScript)

local Canopy = {}
type Branch = { string | number }

-- Chunk name, authored chunk height, normalized local X/Y/Z. These are points on the branches,
-- rather than a volume scattered around their bounding box. Low sprays frame the pale figure;
-- successive tiers trace the two spreading limbs and the highest central fork.
local BRANCHES: { Branch } = {
	{ "Titan_Canopy_09", 162.35215, 0.2426, 0.4216, -0.4662 },
	{ "Titan_Canopy_09", 162.35215, -0.0835, 0.4590, -0.4127 },
	{ "Titan_Canopy_12", 222.38281, -0.2570, -0.4787, 0.4053 },
	{ "Titan_Canopy_11", 101.08314, 0.4106, -0.0504, 0.0890 },
	{ "Titan_Canopy_11", 101.08314, -0.0008, 0.0657, 0.0357 },
	{ "Titan_Canopy_11", 101.08314, -0.4935, 0.2187, -0.1251 },
	{ "Titan_Canopy_13", 148.55579, 0.1469, -0.2085, -0.1402 },
	{ "Titan_Canopy_13", 148.55579, -0.0374, 0.0019, -0.3296 },
	{ "Titan_Canopy_12", 222.38281, -0.2062, -0.2794, 0.2342 },
	{ "Titan_Canopy_10", 105.09483, -0.1377, 0.3833, 0.0618 },
	{ "Titan_Canopy_11", 101.08314, 0.2469, 0.4379, -0.1978 },
	{ "Titan_Canopy_15", 165.23148, -0.3278, -0.3724, 0.1263 },
	{ "Titan_Canopy_12", 222.38281, 0.3703, -0.0784, 0.2689 },
	{ "Titan_Canopy_13", 148.55579, 0.1007, 0.2742, -0.0464 },
	{ "Titan_Canopy_13", 148.55579, -0.2405, 0.3557, 0.1140 },
	{ "Titan_Canopy_14", 223.88031, 0.3102, 0.0241, -0.0673 },
	{ "Titan_Canopy_14", 223.88031, -0.2789, 0.0000, -0.0492 },
	{ "Titan_Canopy_16", 196.48148, -0.1457, -0.1495, 0.0518 },
	{ "Titan_Canopy_15", 165.23148, 0.2881, -0.0769, -0.3229 },
	{ "Titan_Canopy_15", 165.23148, -0.0499, 0.0153, -0.0279 },
	{ "Titan_Canopy_13", 148.55579, -0.1604, 0.4825, 0.0077 },
	{ "Titan_Canopy_13", 148.55579, -0.4588, 0.4692, 0.3362 },
	{ "Titan_Canopy_14", 223.88031, -0.2179, 0.2803, -0.2739 },
	{ "Titan_Canopy_16", 196.48148, 0.2843, 0.1828, -0.0787 },
	{ "Titan_Canopy_16", 196.48148, -0.2719, 0.1956, -0.1567 },
	{ "Titan_Canopy_15", 165.23148, 0.2770, 0.1527, 0.1448 },
	{ "Titan_Canopy_12", 222.38281, -0.4667, 0.4721, 0.3519 },
	{ "Titan_Canopy_16", 196.48148, 0.1654, 0.4948, 0.2801 },
}

local TINTS = {
	Color3.fromRGB(194, 173, 168), Color3.fromRGB(174, 157, 160),
	Color3.fromRGB(180, 169, 181), Color3.fromRGB(205, 176, 158),
}

local function card(parent: Instance, frame: CFrame, width: number, height: number, tint: Color3)
	local p = Instance.new("Part")
	p.Name = "CrimsonLeafCard"
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.Transparency, p.Material = 1, Enum.Material.SmoothPlastic
	p.Size, p.CFrame = Vector3.new(width, height, 0.04), frame
	-- Decals on both faces retain the texture's transparent leaf edges. No opaque backing plane,
	-- camera-facing update, emitter or extra light is needed for the persistent canopy silhouette.
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local decal = Instance.new("Decal")
		decal.Name, decal.Texture, decal.Face = "CrimsonSpray", Assets.Textures.CrimsonBranch, face
		decal.Color3 = tint
		decal.Parent = p
	end
	p.Parent = parent
end

-- The cloth is the kit's double-sided, folded swallowtail mesh, not flat rectangular strips.
-- Narrow widths and long, varied drops read as silk prayers hanging from the actual branch tips.
local function prayer(group: Instance, branch: CFrame, index: number, scale: number, rng: Random): boolean
	local length = rng:NextNumber(22, 47) * scale
	local width = rng:NextNumber(1.25, 2.15) * scale
	local hook = CFrame.new(branch.Position + Vector3.new(0, -0.35 * scale, 0))
		* CFrame.Angles(math.rad(rng:NextNumber(-6, 6)), math.rad(index * 63), math.rad(rng:NextNumber(-5, 5)))
	local silk = Kit.place(group, "Banner_Cloth", hook, Vector3.new(width / 3.2, length / 8.6, 1.1), false)
	if not silk then return false end
	silk.Name = "HangingSilkPrayer"
	for _, p in silk:GetChildren() do
		if p:IsA("BasePart") then
			p.Material, p.Color = Enum.Material.Fabric, Color3.fromRGB(143, 27, 35)
			local finish = p:FindFirstChildOfClass("SurfaceAppearance")
			if finish then finish.Color = Color3.fromRGB(211, 137, 126) end
		end
	end
	return true
end

function Canopy.Build(statue: Model, tree: Model): Model?
	if Assets.Textures.CrimsonBranch == "" then return nil end
	local old = statue:FindFirstChild("SacredCrimsonCanopy")
	if old then old:Destroy() end
	local group = Instance.new("Model")
	group.Name = "SacredCrimsonCanopy"
	local rng = Random.new(14277)
	local cards, sprays, ribbons = 0, 0, 0
	for index, a in BRANCHES do
		local chunk = tree:FindFirstChild(a[1] :: string)
		if chunk and chunk:IsA("BasePart") then
			local scale = chunk.Size.Y / (a[2] :: number)
			local branch = chunk.CFrame * CFrame.new(chunk.Size.X * (a[3] :: number), chunk.Size.Y * (a[4] :: number), chunk.Size.Z * (a[5] :: number))
			-- Three intersecting sprays grow along one limb; their centres stay close to the bark.
			-- The third card tilts upward so the crown also reads from an elevated camera.
			for k = 1, 3 do
				local offset = Vector3.new(rng:NextNumber(-13, 13), rng:NextNumber(-7, 10), rng:NextNumber(-9, 9)) * scale
				local pitch = if k == 3 then rng:NextNumber(65, 85) else rng:NextNumber(-32, 35)
				local turn = CFrame.Angles(math.rad(pitch), math.rad(rng:NextNumber(-58, 58)), math.rad(rng:NextNumber(-24, 24)))
				local size = rng:NextNumber(0.88, 1.15) * scale
				card(group, branch * CFrame.new(offset) * turn, 92 * size, 48 * size, TINTS[rng:NextInteger(1, #TINTS)])
				cards += 1
			end
			sprays += 1
			-- Leave alternating open branch gaps; the ribbons frame her rather than veil her face.
			if index % 3 ~= 0 and prayer(group, branch, index, scale, rng) then ribbons += 1 end
		end
	end
	group:SetAttribute("BranchSprays", sprays)
	group:SetAttribute("LeafCards", cards)
	group:SetAttribute("PrayerRibbons", ribbons)
	group.Parent = statue
	return group
end

return table.freeze(Canopy)
