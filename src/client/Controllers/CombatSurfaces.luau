--!strict
local Debris = game:GetService("Debris")
local Tween = game:GetService("TweenService")
local Assets = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.PresentationAssets)
local Surfaces = {}
local stains: {BasePart} = {}
function Surfaces.ground(folder: Instance, point: Vector3, excludes: {Instance}?): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list: {Instance} = { folder }
	for _, item in excludes or {} do table.insert(list, item) end
	params.FilterDescendantsInstances, params.RespectCanCollide = list, true
	return workspace:Raycast(point + Vector3.yAxis * 2, -Vector3.yAxis * 16, params)
end
function Surfaces.stain(folder: Instance, point: Vector3, direction: Vector3, excludes: {Instance}?)
	local hit = Surfaces.ground(folder, point + direction * 1.4, excludes)
	if not hit then return end
	while #stains > 0 and stains[1].Parent == nil do table.remove(stains, 1) end
	if #stains >= Assets.Limits.Stains then table.remove(stains, 1):Destroy() end
	local p = Instance.new("Part")
	p.Name, p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = "BloodRallyStain", true, false, false, false, false
	local normal = hit.Normal
	local right = normal:Cross(if math.abs(normal.Y) > 0.95 then Vector3.zAxis else Vector3.yAxis).Unit
	p.CFrame = CFrame.fromMatrix(hit.Position + normal * 0.014, right, normal) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
	p.Size = Vector3.new(1.4 + math.random(), 0.016, 1 + math.random())
	p.Color, p.Material = Color3.fromRGB(65, 5, 9), Enum.Material.SmoothPlastic
	if Assets.Textures.BloodStain ~= "" then
		p.Transparency = 1
		local decal = Instance.new("Decal")
		decal.Texture, decal.Face, decal.Parent = Assets.Textures.BloodStain, Enum.NormalId.Top, p
		Tween:Create(decal, TweenInfo.new(7), { Transparency = 1 }):Play()
	else
		p.Shape = Enum.PartType.Ball; p.Transparency = 0.3
		Tween:Create(p, TweenInfo.new(7), { Transparency = 1 }):Play()
	end
	p.Parent = folder; table.insert(stains, p); Debris:AddItem(p, 7.2)
end
function Surfaces.rupture(folder: Instance, point: Vector3, direction: Vector3, color: Color3, excludes: {Instance}?)
	local forward = Vector3.new(direction.X, 0, direction.Z)
	forward = if forward.Magnitude < 0.1 then Vector3.zAxis else forward.Unit
	local side = forward:Cross(Vector3.yAxis)
	local previous: Vector3? = nil
	for i = 0, 10 do
		local hit = Surfaces.ground(folder, point + forward * (i * 1.7) + side * math.sin(i * 2.8) * 0.8, excludes)
		if not hit then previous = nil; continue end
		local at = hit.Position + hit.Normal * 0.035
		if previous then
			local p = Instance.new("Part")
			p.Name, p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = "QiGroundFissure", true, false, false, false, false
			p.Material, p.Color = Enum.Material.Neon, color
			p.Size, p.CFrame = Vector3.new(0.12 + i * 0.012, 0.045, (at - previous).Magnitude), CFrame.lookAt((at + previous)/2, at)
			p.Parent = folder
			Tween:Create(p, TweenInfo.new(1.3), { Transparency = 1 }):Play(); Debris:AddItem(p, 1.4)
		end
		previous = at
	end
end
function Surfaces.clear()
	for _, p in stains do p:Destroy() end
	table.clear(stains)
end
return Surfaces
