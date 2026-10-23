--!strict
-- Small Blender-authored erosion and botanical modules. All pieces are decorative; the existing
-- terrace/bridge movement supports remain authoritative. Shared meshes keep repetition cheap.
local Kit = require(script.Parent.SanctuaryKit)
local Ecology = {}

local function piece(group: Instance, name: string, frame: CFrame, scale: Vector3, tint: Color3?): Model?
	local model = Kit.place(group, name, frame, scale, false)
	if not model then return nil end
	model:SetAttribute("AsuraDetailCluster", true)
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			part:SetAttribute("AsuraMicroDetail", true)
			if tint then
				local finish = part:FindFirstChildOfClass("SurfaceAppearance")
				if finish then finish.Color = tint else part.Color = tint end
			end
		end
	end
	return model
end

local function planting(group: Instance, at: CFrame, scale: number, seed: number)
	local rng = Random.new(seed)
	for i = 1, 3 do
		local cf = at * CFrame.new(rng:NextNumber(-2.6, 2.6) * scale, 0, rng:NextNumber(-1.5, 1.5) * scale)
			* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), math.rad(rng:NextNumber(-7, 7)))
		piece(group, "Detail_Fern", cf, Vector3.one * scale * rng:NextNumber(0.65, 1.25),
			if i % 2 == 0 then Color3.fromRGB(51, 71, 43) else Color3.fromRGB(70, 86, 43))
	end
	piece(group, "Detail_MapleSpray", at * CFrame.new(0, 0.25 * scale, 0) * CFrame.Angles(0, seed, math.rad(-9)),
		Vector3.new(1.4, 0.9, 1.1) * scale, Color3.fromRGB(139, 22, 31))
end

function Ecology.Build(parent: Instance, origin: CFrame)
	local group = Kit.folder("CreviceEcology", parent)
	-- The procession and spillway mouths stay open. Unequal shelves break the smooth edge into
	-- short beds, dark crevices and warm lichen-bearing ledges visible from player height.
	for i, a in { {-49,-27,1.2,19}, {47,-30,1.0,-24}, {-50,32,1.25,-13}, {48,34,0.9,16},
		{-84,6,1.0,27}, {83,-1,0.85,-22}, {-18,46,0.8,8}, {19,46,0.95,-13} } do
		local at = origin * CFrame.new(a[1], -2.3, a[2]) * CFrame.Angles(0, math.rad(a[4]), 0)
		piece(group, "Detail_Strata", at, Vector3.new(1.2, 1.2, 1.3) * a[3], Color3.fromRGB(138, 153, 164))
		piece(group, "Detail_Fissure", at * CFrame.new(2, -12, 1.1) * CFrame.Angles(0, 0, math.rad(12)),
			Vector3.new(1.0, 1.1, 0.9) * a[3], Color3.fromRGB(116, 132, 145))
		planting(group, at * CFrame.new(-2.6, 2.5, 0), a[3] * 0.65, 3100 + i)
	end
	-- Root terrace front shoulders: fractured strata run beneath the parapets, not through stairs.
	local terrace = origin * CFrame.new(0, 20, -345)
	for i, a in { {-51,246,1.3,-20}, {54,244,1.6,18}, {-106,211,1.6,-37}, {112,204,1.3,36},
		{-181,130,1.5,-48}, {186,118,1.7,44}, {-226,38,1.8,-70}, {223,18,1.6,68} } do
		local at = terrace * CFrame.new(a[1], -2.5, a[2]) * CFrame.Angles(0, math.rad(a[4]), 0)
		for k = 0, 1 do
			piece(group, "Detail_Strata", at * CFrame.new(k * 3, -k * 2.6, -k),
				Vector3.new(1.6, 1.1, 1.4) * a[3], Color3.fromRGB(148, 163, 173))
		end
		piece(group, "Detail_Fissure", at * CFrame.new(-3, -18, 1), Vector3.new(1.3, 1.5, 1.1) * a[3], Color3.fromRGB(121, 138, 153))
		planting(group, at * CFrame.new(0, 3.0, -2), a[3], 4200 + i)
	end
	-- Rich foreground planting under the prayer-court maples and at the stone/water junctions.
	for i, a in { {-38,-14}, {39,-17}, {-48,13}, {47,9} } do planting(group, origin * CFrame.new(a[1], 0.1, a[2]), 0.7, 5100 + i) end
	group:SetAttribute("AuthoredMeshTriangles", 1382)
	group:SetAttribute("CollisionParts", 0)
end

return table.freeze(Ecology)
