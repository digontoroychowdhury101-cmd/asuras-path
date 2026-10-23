--!strict
-- Original Blender karst kit, placed at landscape scale with its authored foot pivots intact.
-- Real Sanctuary Atmosphere supplies aerial perspective; mountains remain opaque PBR geometry.
-- Waterfall ribbons are authored rippled meshes, never emissive rectangular wall parts.
local Kit = require(script.Parent:WaitForChild("SanctuaryKit") :: ModuleScript)
local Assets = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.PresentationAssets)
local Vista = {}

type Peak = { Name: string, X: number, Z: number, Foot: number, Height: number, Width: number, Yaw: number, Shrine: boolean }
-- All eight peaks lie 1,000–3,000 studs from the plaza. Width and height scales remain similar,
-- Buried lower shafts extend beneath the cloud sea; each authored summit elevation stays fixed.
local PEAKS: { Peak } = {
	{ Name = "Vista_Crown", X = -1180, Z = -1120, Foot = -1100, Height = 1425, Width = 3.1, Yaw = 24, Shrine = true },
	{ Name = "Vista_Needle", X = 1120, Z = -1050, Foot = -1100, Height = 1510, Width = 2.7, Yaw = -24, Shrine = true },
	{ Name = "Vista_Ridge", X = -1920, Z = -980, Foot = -1100, Height = 1465, Width = 3.0, Yaw = 52, Shrine = false },
	{ Name = "Vista_Crown", X = 1870, Z = -1640, Foot = -1100, Height = 1660, Width = 4.1, Yaw = -38, Shrine = false },
	{ Name = "Vista_Needle", X = -920, Z = 890, Foot = -1100, Height = 1450, Width = 2.3, Yaw = -72, Shrine = false },
	{ Name = "Vista_Crown", X = 1320, Z = 640, Foot = -1100, Height = 1355, Width = 2.8, Yaw = 101, Shrine = true },
	{ Name = "Vista_Ridge", X = 400, Z = 2000, Foot = -1100, Height = 1495, Width = 3.6, Yaw = 32, Shrine = false },
	{ Name = "Vista_Needle", X = -980, Z = 2490, Foot = -1100, Height = 1630, Width = 3.2, Yaw = -25, Shrine = false },
}
-- A separate nearer layer remains legible through the mandated dense peach atmosphere. These
-- crags flank the tree outside the terrace footprint; no silhouette crosses the central procession.
-- Summit world heights at the canonical plaza are 950, 1020 and 860 studs; feet are buried at -400.
local INTERMEDIATE: { Peak } = {
	{ Name = "Vista_Crown", X = -430, Z = -365, Foot = -380, Height = 730, Width = 2.4, Yaw = 21, Shrine = true },
	{ Name = "Vista_Needle", X = 445, Z = -445, Foot = -380, Height = 800, Width = 2.7, Yaw = -31, Shrine = true },
	{ Name = "Vista_Needle", X = -715, Z = 75, Foot = -380, Height = 640, Width = 2.9, Yaw = -65, Shrine = true },
}
local HEIGHT: { [string]: number } = { Vista_Crown = 173.40224, Vista_Ridge = 155.18605, Vista_Needle = 223.92113 }
local SUMMIT: { [string]: Vector3 } = {
	Vista_Crown = Vector3.new(5, 173.1, 2), Vista_Ridge = Vector3.new(-6, 154.8, 9), Vista_Needle = Vector3.new(5, 223.4, 1),
}

local function nonphysical(model: Model, rockTint: Color3?)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
			if rockTint and string.find(p.Name, "__Rock", 1, true) then
				local surface = p:FindFirstChildOfClass("SurfaceAppearance")
				if surface then surface.Color = rockTint else p.Color = rockTint end
				p.Transparency = 0
			end
		end
	end
	model:SetAttribute("AsuraDecorative", true)
end

local function pagoda(parent: Instance, summit: CFrame, scale: number)
	local shrine = Kit.folder("CloudSummitShrine", parent)
	Kit.slab(shrine, "SummitPlinth", Vector3.new(18, 2.4, 18) * scale, summit * CFrame.new(0, 0.4 * scale, 0), "StoneDark", Kit.decor())
	for tier = 0, 1 do
		local s = scale * (1 - tier * 0.19)
		local base = summit * CFrame.new(0, (1.6 + tier * 12) * scale, 0)
		Kit.slab(shrine, "DistantChamber", Vector3.new(8.6, 8.6, 8.6) * s, base * CFrame.new(0, 4.3 * s, 0), "Timber", Kit.decor())
		for _, x in { -5.5, 5.5 } do
			for _, z in { -5.5, 5.5 } do
				Kit.place(shrine, "Column_Lacquer", base * CFrame.new(x * s, 0, z * s), Vector3.new(0.7, 0.9, 0.7) * s, false)
			end
		end
		Kit.place(shrine, "Roof_Square", base * CFrame.new(0, 10 * s, 0), s * 1.03, false)
		-- Inset paper windows are warm reflecting surfaces, with no unshaded neon blocks or distant lights.
		for _, x in { -2.4, 2.4 } do
			Kit.part(shrine, "DistantPaperWindow", Vector3.new(1.3, 2.7, 0.08) * s, base * CFrame.new(x * s, 5 * s, -4.34 * s),
				Color3.fromRGB(192, 135, 76), Enum.Material.SmoothPlastic, Kit.decor())
		end
	end
end

local function summitFoliage(parent: Instance, summit: CFrame, focus: Vector3)
	if Assets.Textures.CrimsonBranch == "" then return end
	for _, side in { -1, 1 } do
		local at = summit:PointToWorldSpace(Vector3.new(side * 23, 8, 9))
		local frame = CFrame.lookAt(at, Vector3.new(focus.X, at.Y, focus.Z)) * CFrame.Angles(0, side * 0.3, side * 0.07)
		local card = Kit.hidden(parent, "SummitCrimsonBranch", Vector3.new(25, 14, 0.04), frame)
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local decal = Instance.new("Decal")
			decal.Name, decal.Texture, decal.Face = "CrimsonSpray", Assets.Textures.CrimsonBranch, face
			decal.Color3, decal.Parent = Color3.fromRGB(183, 149, 155), card
		end
	end
end

local function waterRibbon(parent: Instance, label: string, cf: CFrame, scale: Vector3, color: Color3, transparency: number)
	local model = Kit.place(parent, "Vista_Waterfall", cf, scale, false)
	if not model then return end
	nonphysical(model)
	model.Name = label
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Color, p.Material, p.Transparency = color, Enum.Material.SmoothPlastic, transparency
		end
	end
end

local function spillway(parent: Instance, origin: CFrame, x: number, z: number, yaw: number, index: number, width: number)
	local length = 108 + (index % 2) * 9
	local top = origin * CFrame.new(x, -0.14, z) * CFrame.Angles(0, math.rad(yaw), 0)
	local foot = top * CFrame.new(0, -length, 0)
	-- The exported mesh rises 120 studs from its foot. Its thin rippled face lies across local X;
	-- +Z is out from the rock. Matching the whole frame keeps foam and splash on that visible face.
	waterRibbon(parent, "CourtyardWaterfall_" .. index, foot, Vector3.new(width / 12.5, length / 120, 0.8), Color3.fromRGB(179, 213, 217), 0.24)
	for _, side in { -1, 1 } do
		waterRibbon(parent, "WaterfallFoam_" .. index, foot * CFrame.new(side * width * 0.32, 0, 0.25),
			Vector3.new(0.055, length / 120, 0.75), Color3.fromRGB(237, 239, 224), 0.27)
	end
	-- A crisp carved lip makes the water belong to the flagstones rather than hover beside them.
	for _, side in { -1, 1 } do
		Kit.slab(parent, "SpillwayCheek", Vector3.new(0.7, 0.8, 3.4), top * CFrame.new(side * (width / 2 + 0.3), -0.2, -0.6), "StoneDark", Kit.decor())
	end
	Kit.slab(parent, "SpillwaySill", Vector3.new(width + 1.5, 0.5, 1.3), top * CFrame.new(0, -0.55, -0.1), "Stone", Kit.decor())
	if Assets.Textures.Smoke == "" then return end
	local anchor = Kit.hidden(parent, "WaterfallCloudMerge", Vector3.new(width + 6, 4, 12), foot * CFrame.new(0, 14, 1))
	local e = Instance.new("ParticleEmitter")
	e.Name, e.Texture, e.Rate = "WaterfallSpray", Assets.Textures.Smoke, 0.9
	e.Lifetime, e.Speed, e.Acceleration = NumberRange.new(6, 10), NumberRange.new(1.5, 3), Vector3.new(0.15, 0.35, 0)
	e.SpreadAngle, e.EmissionDirection = Vector2.new(70, 70), Enum.NormalId.Top
	e.Size = Kit.sequence({ { 0, 10 }, { 0.5, 23 }, { 1, 33 } })
	e.Transparency = Kit.sequence({ { 0, 0.9 }, { 0.2, 0.58 }, { 0.7, 0.7 }, { 1, 1 } })
	e.Color, e.LightInfluence, e.Rotation = ColorSequence.new(Color3.fromRGB(237, 231, 220)), 0.7, NumberRange.new(0, 360)
	e.Parent = anchor
	e:Emit(6)
end

function Vista.Build(parent: Instance, origin: CFrame): Folder
	local group = Kit.folder("KarstHorizon", parent)
	for i, peak in PEAKS do
		local scale = Vector3.new(peak.Width, peak.Height / HEIGHT[peak.Name], peak.Width * (if i % 2 == 0 then 0.96 else 1.06))
		local base = origin * CFrame.new(peak.X, peak.Foot, peak.Z) * CFrame.Angles(0, math.rad(peak.Yaw), 0)
		local mountain = Kit.place(group, peak.Name, base, scale, false)
		if mountain then
			nonphysical(mountain, Color3.fromRGB(184, 198, 217))
			mountain.Name = peak.Name .. "_" .. i
			mountain:SetAttribute("VistaFootElevation", origin.Position.Y + peak.Foot)
			mountain:SetAttribute("VistaDistance", math.sqrt(peak.X * peak.X + peak.Z * peak.Z))
			mountain:SetAttribute("VistaLayer", if i <= 2 then "MiddleDistance" else "FarDistance")
			if peak.Shrine then
				local summit = base * CFrame.new(SUMMIT[peak.Name] * scale)
				pagoda(group, summit, 2.2)
				if i == 1 or i == 2 then summitFoliage(group, summit, origin.Position) end
			end
		end
	end
	local middle = Kit.folder("IntermediateKarst", group)
	for i, peak in INTERMEDIATE do
		local scale = Vector3.new(peak.Width, peak.Height / HEIGHT[peak.Name], peak.Width)
		local base = origin * CFrame.new(peak.X, peak.Foot, peak.Z) * CFrame.Angles(0, math.rad(peak.Yaw), 0)
		local mountain = Kit.place(middle, peak.Name, base, scale, false)
		if mountain then
			-- A cooler, darker mineral tint provides the silhouette contrast; atmospheric scattering
			-- supplies the peach fade naturally, without translucent rock or extra lights.
			nonphysical(mountain, Color3.fromRGB(74, 99, 133))
			mountain.Name = "Intermediate_" .. peak.Name .. "_" .. i
			mountain:SetAttribute("VistaFootElevation", origin.Position.Y + peak.Foot)
			mountain:SetAttribute("VistaDistance", math.sqrt(peak.X * peak.X + peak.Z * peak.Z))
			mountain:SetAttribute("VistaLayer", "Intermediate")
			local summit = base * CFrame.new(SUMMIT[peak.Name] * scale)
			pagoda(middle, summit, if i == 3 then 2.3 else 2.0)
		end
	end
	middle:SetAttribute("MountainBudget", 3)
	middle:SetAttribute("AddedMeshTriangleBudget", 89906)
	middle:SetAttribute("AddedBasePartBudget", 93)
	local falls = Kit.folder("CourtyardCascades", group)
	spillway(falls, origin, -33, 46.4, 0, 1, 7.5)
	spillway(falls, origin, 33, 46.4, 0, 2, 6.2)
	spillway(falls, origin, -58.4, -29, -90, 3, 5.4)
	spillway(falls, origin, 58.4, -29, 90, 4, 7.1)
	spillway(falls, origin, -104, -5, -90, 5, 4.8)
	group:SetAttribute("MountainBudget", 11)
	group:SetAttribute("RequiredFarMountainBudget", 8)
	group:SetAttribute("IntermediateMountainBudget", 3)
	group:SetAttribute("CascadeEmitterBudget", 5)
	group:SetAttribute("CascadeMeshBudget", 15)
	group:SetAttribute("CascadeTriangleBudget", 4800)
	group:SetAttribute("CascadeParticleSteadyStateCeiling", 45)
	group:SetAttribute("SummitFoliageCardBudget", 4)
	return group
end

return table.freeze(Vista)
