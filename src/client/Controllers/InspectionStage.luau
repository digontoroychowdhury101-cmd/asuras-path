--!strict
local Players = game:GetService("Players")
local Stage = {}
local rgb = Color3.fromRGB
local STONE, BURNISHED, LEATHER = rgb(42, 40, 38), rgb(152, 112, 64), rgb(38, 30, 28)

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local piece = Instance.new("Part")
	piece.Name, piece.Size, piece.CFrame, piece.Color, piece.Material = name, size, cf, color, material
	piece.Anchored, piece.CanCollide, piece.CanQuery, piece.CanTouch = true, false, false, false
	if shape then piece.Shape = shape end
	piece.Parent = parent
	return piece
end

function Stage.parts(model: Instance): { BasePart }
	local parts: { BasePart } = {}
	for _, piece in model:GetDescendants() do
		if piece:IsA("BasePart") and piece.Transparency < 1 then table.insert(parts, piece) end
	end
	return parts
end

function Stage.bounds(parts: { BasePart }): (Vector3, Vector3)
	local low, high = Vector3.one * math.huge, Vector3.one * -math.huge
	for _, p in parts do
		local cf, half = p.CFrame, p.Size / 2
		local reach = cf.RightVector:Abs() * half.X + cf.UpVector:Abs() * half.Y + cf.LookVector:Abs() * half.Z
		low, high = low:Min(p.Position - reach), high:Max(p.Position + reach)
	end
	return (low + high) / 2, high - low
end

local function dressHead(model: Model, at: CFrame, height: number): boolean
	local player = Players.LocalPlayer
	local character = player and player.Character
	local head = character and character:FindFirstChild("Head")
	if not (head and head:IsA("BasePart") and head.Archivable) then return false end
	local scale = height / head.Size.Y
	local function copyPiece(original: BasePart)
		local offset = head.CFrame:ToObjectSpace(original.CFrame)
		local copy = original:Clone()
		if not copy then return end
		for _, child in copy:GetChildren() do
			if not (child:IsA("SurfaceAppearance") or child:IsA("Decal") or child:IsA("SpecialMesh")) then child:Destroy() end
		end
		copy.Size = original.Size * scale
		copy.CFrame = at * CFrame.new(offset.Position * scale) * offset.Rotation
		copy.Anchored, copy.CanCollide, copy.CanTouch, copy.CanQuery = true, false, false, false
		copy.Parent = model
	end
	copyPiece(head)
	local attire = character:FindFirstChild("AsuraAttire")
	if attire then
		for _, piece in attire:GetChildren() do
			if not piece:IsA("BasePart") then continue end
			local weld = piece:FindFirstChildOfClass("WeldConstraint")
			if weld and (weld.Part0 == head or weld.Part1 == head) then copyPiece(piece) end
		end
	end
	return true
end

function Stage.poseArmor(model: Model)
	local parts = Stage.parts(model)
	if #parts == 0 then return end
	local center, size = Stage.bounds(parts)
	local chest = center.Y + size.Y * 0.25
	for _, side in { "Left", "Right" } do
		local arm: { BasePart } = {}
		for _, piece in parts do
			local bone = tostring(piece:GetAttribute("AsuraBone"))
			if string.sub(bone, 1, #side) == side and (string.find(bone, "Arm") or string.find(bone, "Hand")) then
				table.insert(arm, piece)
			end
		end
		if #arm == 0 then continue end
		local at = Stage.bounds(arm)
		local pivot = CFrame.new(at.X, chest, at.Z)
		local sign = if at.X > center.X then 1 else -1
		local pose = pivot * CFrame.Angles(math.rad(if side == "Left" then -15 else 13), 0, sign * math.rad(8)) * pivot:Inverse()
		for _, piece in arm do piece.CFrame = pose * piece.CFrame end
	end
	local unit = size.Y
	local top = center.Y + size.Y / 2
	local axis = CFrame.new(center.X, top, center.Z)
	local headAt = axis * CFrame.new(0, unit * .106, 0) * CFrame.Angles(0, math.pi, 0)
	if not dressHead(model, headAt, unit * .183) then
		part(model, "DisplayHead", Vector3.new(unit * .171, unit * .197, unit * .16), headAt, LEATHER, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
end

local function armorPlinth(parent: Instance, size: Vector3, bottom: number)
	local radius = math.max(size.X * .63, .8)
	local height = size.Y * .105
	local top = bottom - .05
	local axis = CFrame.new(0, top, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local function ring(name: string, depth: number, scale: number, y: number, color: Color3, material: Enum.Material)
		part(parent, name, Vector3.new(depth, radius * 2 * scale, radius * 1.64 * scale),
			axis * CFrame.new(y, 0, 0), color, material, Enum.PartType.Cylinder)
	end
	ring("Basalt face", height * .52, .96, -height * .26, STONE, Enum.Material.Slate)
	ring("Inlaid lip", height * .08, .985, -height * .54, BURNISHED, Enum.Material.Metal)
	ring("Basalt foot", height * .47, 1.02, -height * .8, rgb(30, 28, 28), Enum.Material.Slate)
	for index = 0, 15 do
		local theta = math.pi * index / 8
		local at = Vector3.new(radius * math.cos(theta) * .985, top - height * .54, radius * math.sin(theta) * .807)
		part(parent, "Rim pin", Vector3.one * height * .16, CFrame.new(at), BURNISHED, Enum.Material.Metal, Enum.PartType.Ball)
	end
end

local function weaponRest(parent: Instance, size: Vector3, bottom: number)
	local length = math.max(1.36, size.X * .92)
	local foot = CFrame.new(0, bottom - .19, 0)
	part(parent, "Basalt block", Vector3.new(length, .24, length * .31), foot, STONE, Enum.Material.Slate)
	part(parent, "Bronze lip", Vector3.new(length * .995, .029, length * .313), foot * CFrame.new(0, .092, 0), BURNISHED, Enum.Material.Metal)
	part(parent, "Rosewood rail", Vector3.new(length * .89, .075, length * .233), foot * CFrame.new(0, .154, 0), rgb(60, 36, 32), Enum.Material.Wood)
	for _, sign in { -1, 1 } do
		local seat = foot * CFrame.new(length * .345 * sign, .27, 0)
		part(parent, "Rest", Vector3.new(.11, .22, .27), seat, rgb(75, 54, 34), Enum.Material.Wood)
		part(parent, "Leather rest", Vector3.new(.126, .04, .285), seat * CFrame.new(0, .107, 0), LEATHER, Enum.Material.Fabric)
	end
	for index = -4, 4 do
		part(parent, "Inlay", Vector3.new(.026, .027, .02), foot * CFrame.new(index * length * .095, .03, length * .155) * CFrame.Angles(0, 0, math.pi / 4), BURNISHED, Enum.Material.Metal)
	end
end

function Stage.build(parent: WorldModel, source: Model, kind: string): (Model, { BasePart })
	local model = source:Clone()
	local armor = kind == "Armor"
	local before = model:GetBoundingBox()
	local orientation = if armor then CFrame.Angles(0, math.pi, 0)
		else CFrame.Angles(0, 0, math.rad(-68)) * CFrame.Angles(math.rad(78), 0, 0) * CFrame.Angles(0, 0, math.rad(70))
	model:PivotTo(orientation * CFrame.new(-before.Position) * model:GetPivot())
	if armor then Stage.poseArmor(model) end
	local pieces = Stage.parts(model)
	if #pieces == 0 then return model, pieces end
	model.Parent = parent
	local center, size = Stage.bounds(pieces)
	local bottom = center.Y - size.Y / 2
	if armor then armorPlinth(parent, size, bottom) else weaponRest(parent, size, bottom) end
	return model, pieces
end

return Stage
