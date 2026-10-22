--!strict
-- Distant landscape built from the original Blender karst kit. Pivots are at each mountain's foot;
-- summit coordinates are authored with tools/blender/sanctuary_vista.py, not inferred from a box.
-- Templates retain Automatic mesh fidelity. Everything here is decorative and has no point lights.
local Kit = require(script.Parent:WaitForChild("SanctuaryKit") :: ModuleScript)
local Assets = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.PresentationAssets)
local Vista = {}

type Peak = { string | number | boolean }
-- name, x, z, top relative to plaza, foot relative to plaza, width, yaw, pagoda, cascade.
-- Near peaks frame the sacred tree; their inner faces stay outside the processional axis.
local PEAKS: { Peak } = {
	{ "Vista_Crown", -480, -500, 160, -270, 2.08, 24, true, true },
	{ "Vista_Needle", 480, -500, 195, -270, 2.12, -24, false, false },
	{ "Vista_Ridge", -735, -690, 165, -285, 2.32, -18, true, false },
	{ "Vista_Crown", 750, -730, 220, -285, 2.38, 40, true, true },
	{ "Vista_Needle", -1040, -950, 285, -310, 2.15, 53, false, false },
	{ "Vista_Ridge", 1070, -1040, 235, -310, 2.8, -29, false, false },
	{ "Vista_Ridge", -410, -870, 294, -320, 2.25, 17, false, false },
	{ "Vista_Needle", 425, -920, 358, -320, 1.76, 70, true, false },
	{ "Vista_Crown", -665, -1180, 364, -350, 2.6, 30, false, false },
	{ "Vista_Ridge", 720, -1240, 305, -350, 2.8, -40, true, true },
	{ "Vista_Needle", -1030, -1010, 412, -350, 2.05, 91, false, false },
	{ "Vista_Needle", 1100, -1080, 428, -350, 2.2, -13, false, false },
	-- Side vistas remain visible from the forge and circular eastern duel promenade.
	{ "Vista_Crown", 465, 16, 184, -265, 1.62, 101, true, true },
	{ "Vista_Needle", 735, 230, 258, -290, 1.75, -36, false, false },
	{ "Vista_Ridge", 1090, 52, 303, -330, 2.7, 62, false, false },
	{ "Vista_Crown", -510, 80, 190, -280, 1.74, -72, false, true },
	{ "Vista_Needle", -825, 270, 274, -315, 1.9, 32, false, false },
	{ "Vista_Ridge", -1140, -60, 340, -340, 2.4, -17, true, false },
	-- Arrival panorama behind the player; no mountain occupies a gameplay route.
	{ "Vista_Ridge", -345, 535, 178, -275, 1.8, 28, false, false },
	{ "Vista_Crown", 360, 580, 230, -280, 1.72, -50, true, false },
	{ "Vista_Needle", -755, 760, 305, -330, 2.1, 15, false, false },
	{ "Vista_Ridge", 810, 835, 270, -330, 2.5, 64, false, false },
	{ "Vista_Crown", -75, 1000, 234, -330, 2.3, -25, false, false },
	{ "Vista_Needle", 1200, 700, 388, -350, 2.15, 102, false, false },
}
local HEIGHT: { [string]: number } = { Vista_Crown = 173.40224, Vista_Ridge = 155.18605, Vista_Needle = 223.92113 }
local SUMMIT: { [string]: Vector3 } = {
	Vista_Crown = Vector3.new(5, 173.1, 2),
	Vista_Ridge = Vector3.new(-6, 154.8, 9),
	Vista_Needle = Vector3.new(5, 223.4, 1),
}

local function nonphysical(model: Model, rockTint: Color3?)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
			if rockTint and string.find(p.Name, "__Rock", 1, true) then
				local surface = p:FindFirstChildOfClass("SurfaceAppearance")
				if surface then surface.Color = rockTint else p.Color = rockTint end
			end
		end
	end
	model:SetAttribute("AsuraDecorative", true)
end

local function pagoda(parent: Instance, summit: CFrame, scale: number, tiers: number)
	local shrine = Kit.folder("CloudSummitShrine", parent)
	Kit.slab(shrine, "SummitPlinth", Vector3.new(18, 2.4, 18) * scale, summit * CFrame.new(0, 0.4 * scale, 0), "StoneDark", Kit.decor())
	for tier = 0, tiers - 1 do
		local s = scale * (1 - tier * 0.19)
		local base = summit * CFrame.new(0, (1.6 + tier * 12) * scale, 0)
		Kit.slab(shrine, "DistantChamber", Vector3.new(8.6, 8.6, 8.6) * s, base * CFrame.new(0, 4.3 * s, 0), "Lacquer", Kit.decor())
		for _, x in { -5.5, 5.5 } do
			for _, z in { -5.5, 5.5 } do
				Kit.slab(shrine, "DistantColumn", Vector3.new(0.9, 9, 0.9) * s, base * CFrame.new(x * s, 4.5 * s, z * s), "Lacquer", Kit.decor())
			end
		end
		Kit.place(shrine, "Roof_Square", base * CFrame.new(0, 10 * s, 0), s * 1.03, false)
		-- Small warm windows sell inhabited temples without adding distant point lights.
		for _, x in { -2.4, 2.4 } do
			Kit.part(shrine, "DistantWindow", Vector3.new(1.3, 2.7, 0.08) * s, base * CFrame.new(x * s, 5 * s, -4.34 * s),
				Color3.fromRGB(235, 167, 95), Enum.Material.Neon, Kit.decor())
		end
	end
end

local function cascade(parent: Instance, peakCF: CFrame, peakScale: Vector3, name: string, index: number)
	local summit = SUMMIT[name]
	local height = summit.Y * peakScale.Y
	local top = peakCF * CFrame.new(summit.X * peakScale.X + 12 * peakScale.X, height - 8, summit.Z * peakScale.Z - 8 * peakScale.Z)
	local length = math.min(height - 42, 390)
	local model = Kit.place(parent, "Vista_Waterfall", top * CFrame.new(0, -length, 0), Vector3.new(0.5 + peakScale.X * 0.2, length / 120, 1.5), false)
	if model then
		nonphysical(model)
		model.Name = "SummitWaterfall_" .. index
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") then
				p.Color, p.Material, p.Transparency = Color3.fromRGB(202, 219, 218), Enum.Material.SmoothPlastic, 0.58
			end
		end
	end
	if Assets.Textures.Smoke == "" then return end
	local anchor = Kit.hidden(parent, "WaterfallFootMist", Vector3.new(18, 2, 18), top * CFrame.new(0, -length + 5, 0))
	local e = Instance.new("ParticleEmitter")
	e.Name, e.Texture, e.Rate = "CascadeMist", Assets.Textures.Smoke, 0.35
	e.Lifetime, e.Speed, e.Acceleration = NumberRange.new(6, 9), NumberRange.new(1, 2), Vector3.new(0.2, 0.4, 0)
	e.SpreadAngle = Vector2.new(85, 85)
	e.Size = Kit.sequence({ { 0, 14 }, { 1, 35 } })
	e.Transparency = Kit.sequence({ { 0, 1 }, { 0.2, 0.82 }, { 1, 1 } })
	e.Color, e.LightInfluence, e.Rotation = ColorSequence.new(Color3.fromRGB(228, 227, 223)), 0.6, NumberRange.new(0, 360)
	e.Parent = anchor
end

function Vista.Build(parent: Instance, origin: CFrame): Folder
	local group = Kit.folder("KarstHorizon", parent)
	for i, definition in PEAKS do
		local name = definition[1] :: string
		local x, z = definition[2] :: number, definition[3] :: number
		local top, foot = definition[4] :: number, definition[5] :: number
		local width, yaw = definition[6] :: number, definition[7] :: number
		local scale = Vector3.new(width, (top - foot) / HEIGHT[name], width * (if i % 2 == 0 then 0.9 else 1.1))
		local base = origin * CFrame.new(x, foot, z) * CFrame.Angles(0, math.rad(yaw), 0)
		local mountain = Kit.place(group, name, base, scale, false)
		if mountain then
			nonphysical(mountain, if i <= 6 then Color3.fromRGB(143, 179, 216) else Color3.fromRGB(156, 187, 222))
			mountain.Name = name .. "_" .. i
			mountain:SetAttribute("VistaLayer", if i <= 6 then "Near" elseif i <= 12 then "Far" else "Surround")
			if definition[8] == true then
				local s = SUMMIT[name] * scale
				pagoda(group, base * CFrame.new(s), if i <= 6 then 1.6 else 1.15, if i % 3 == 0 then 3 else 2)
			end
			if definition[9] == true then cascade(group, base, scale, name, i) end
		end
	end
	group:SetAttribute("MountainBudget", #PEAKS)
	group:SetAttribute("CascadeEmitterBudget", 5)
	return group
end

return table.freeze(Vista)
