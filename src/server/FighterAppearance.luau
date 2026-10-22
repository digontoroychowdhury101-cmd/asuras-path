--!strict
-- Server-authored wanderer silhouette. Uses local geometry and materials only; combat rigs,
-- joints and movement animations remain owned by the character system.
local Appearance = {}

local CLOTH = Color3.fromRGB(32, 39, 41)
local HEM = Color3.fromRGB(45, 51, 49)
local WRAP = Color3.fromRGB(96, 94, 80)
local SKIN = Color3.fromRGB(137, 116, 94)
local SASH = Color3.fromRGB(88, 35, 33)
local STRAW = Color3.fromRGB(85, 76, 54)
local HAIR = Color3.fromRGB(24, 20, 20)

local function gear(parent: Instance, limb: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material, cylinder: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.Anchored = false
	p.Massless = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = true
	if cylinder then p.Shape = Enum.PartType.Cylinder end
	p.CFrame = limb.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = limb
	weld.Part1 = p
	weld.Parent = p
	p.Parent = parent
	return p
end

local function imported(item: Instance): boolean
	return item:IsA("Accessory") or item:IsA("Shirt") or item:IsA("Pants")
		or item:IsA("ShirtGraphic") or item:IsA("BodyColors")
end

local function colorBody(model: Model)
	for _, item in model:GetChildren() do
		if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" and item.Name ~= "AsuraWeapon" then
			local skin = item.Name == "Head" or string.find(item.Name, "Hand") ~= nil
			item.Color = if skin then SKIN else CLOTH
			item.Material = if skin then Enum.Material.SmoothPlastic else Enum.Material.Fabric
			if item:IsA("MeshPart") then item.TextureID = "" end
			for _, child in item:GetChildren() do
				if child:IsA("Decal") or child:IsA("SurfaceAppearance") then child:Destroy() end
			end
		end
	end
end

-- True when every attire piece is still welded to a limb of this rig. Avatar loading can swap the
-- head or torso after CharacterAdded; pieces welded to the old limb fall away, and the old
-- "folder has children" check kept that orphaned attire instead of rebuilding it (#24: the
-- player read as a bald block body).
function Appearance.Attached(model: Model, attire: Instance): boolean
	local count = 0
	for _, piece in attire:GetChildren() do
		local weld = piece:FindFirstChildOfClass("WeldConstraint")
		local limb = weld and weld.Part0
		if not limb or limb.Parent ~= model then return false end
		count += 1
	end
	return count > 0
end

function Appearance.Apply(model: Model, connections: { RBXScriptConnection })
	-- Account accessories can arrive after CharacterAdded; remove them only from this game rig.
	for _, child in model:GetChildren() do
		if imported(child) then child:Destroy() end
	end
	colorBody(model)
	local existing = model:FindFirstChild("AsuraAttire")
	if existing and Appearance.Attached(model, existing) then return end
	if existing then existing:Destroy() end
	if not model:GetAttribute("AsuraAttireWatch") then
		model:SetAttribute("AsuraAttireWatch", true)
		table.insert(connections, model.ChildAdded:Connect(function(child)
			if imported(child) or child:IsA("BasePart") then
				task.defer(function()
					if imported(child) and child.Parent == model then child:Destroy() end
					-- A replaced limb re-dresses the rig so attire always binds to the live body.
					if model.Parent then Appearance.Apply(model, connections) end
				end)
			end
		end))
	end
	local head = model:FindFirstChild("Head")
	local torso = model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")
	local waist = model:FindFirstChild("LowerTorso") or torso
	if not head or not head:IsA("BasePart") or not torso or not torso:IsA("BasePart")
		or not waist or not waist:IsA("BasePart") then return end
	local outfit = Instance.new("Folder")
	outfit.Name = "AsuraAttire"
	outfit.Parent = model
	-- Closely spaced round courses read as the weave of a low travelling hat.
	for tier = 0, 13 do
		local radius = 1.48 * (1-tier/15)
		gear(outfit, head, "WovenHat", Vector3.new(0.065, radius*2, radius*2),
			CFrame.new(0, head.Size.Y*0.4+tier*0.048, 0)*CFrame.Angles(0,0,math.pi*0.5),
			if tier%3==0 then STRAW else STRAW:Lerp(CLOTH,0.15), Enum.Material.Wood, true)
	end
	gear(outfit, head, "ShadowedFaceWrap", Vector3.new(head.Size.X*0.92,head.Size.Y*0.36,0.12),
		CFrame.new(0,-head.Size.Y*0.18,-head.Size.Z*0.5),CLOTH,Enum.Material.Fabric)
	-- Hair under the hat brim, a queue down the back, and a readable eye band above the wrap.
	local h = head.Size
	gear(outfit, head, "HairCap", Vector3.new(h.X * 1.05, h.Y * 0.3, h.Z * 1.05), CFrame.new(0, h.Y * 0.3, h.Z * 0.03), HAIR, Enum.Material.Fabric)
	for link = 0, 2 do
		gear(outfit, head, "Queue", Vector3.new(0.24, 0.5, 0.24), CFrame.new(0, -h.Y * 0.1 - link * 0.42, h.Z * 0.55 + link * 0.04), HAIR, Enum.Material.Fabric)
	end
	for side = -1, 1, 2 do
		gear(outfit, head, "Eye", Vector3.new(h.X * 0.13, h.Y * 0.06, 0.04), CFrame.new(side * h.X * 0.18, h.Y * 0.06, -h.Z * 0.5 - 0.01), Color3.fromRGB(26, 22, 22), Enum.Material.SmoothPlastic)
		gear(outfit, head, "Brow", Vector3.new(h.X * 0.24, h.Y * 0.05, 0.04), CFrame.new(side * h.X * 0.19, h.Y * 0.17, -h.Z * 0.5 - 0.01) * CFrame.Angles(0, 0, side * math.rad(-8)), HAIR, Enum.Material.Fabric)
	end
	local t = torso.Size
	gear(outfit, torso, "ShoulderMantle", Vector3.new(t.X * 1.14, t.Y * 0.32, t.Z * 1.25), CFrame.new(0, t.Y * 0.36, 0.02), HEM, Enum.Material.Fabric)
	gear(outfit, torso, "MantleBack", Vector3.new(t.X * 1.02, t.Y * 1.05, 0.1), CFrame.new(0, -t.Y * 0.05, t.Z * 0.5 + 0.08) * CFrame.Angles(math.rad(-4), 0, 0), HEM, Enum.Material.Fabric)
	gear(outfit, torso, "CrossedLapel", Vector3.new(0.18,torso.Size.Y*1.05,0.1),
		CFrame.new(-0.15,0,-torso.Size.Z*0.5-0.06)*CFrame.Angles(0,0,math.rad(-28)),WRAP,Enum.Material.Fabric)
	gear(outfit, waist, "OxBloodSash", Vector3.new(waist.Size.X+0.15,0.32,waist.Size.Z+0.14),
		CFrame.new(0,0,0),SASH,Enum.Material.Fabric)
	gear(outfit, waist, "SashKnot", Vector3.new(0.32,0.4,0.2),
		CFrame.new(-waist.Size.X*0.3,-0.08,-waist.Size.Z*0.5-0.12),WRAP,Enum.Material.Fabric)
	for side=-1,1,2 do
		gear(outfit, waist, "SplitRobeBack", Vector3.new(waist.Size.X*0.49,1.3,0.12),
			CFrame.new(side*waist.Size.X*0.27,-0.72,waist.Size.Z*0.5+0.08)*CFrame.Angles(math.rad(-8),0,side*math.rad(5)),HEM,Enum.Material.Fabric)
		gear(outfit, waist, "SplitRobeFront", Vector3.new(waist.Size.X*0.4,0.95,0.12),
			CFrame.new(side*waist.Size.X*0.3,-0.58,-waist.Size.Z*0.5-0.08)*CFrame.Angles(math.rad(8),0,side*math.rad(-7)),CLOTH,Enum.Material.Fabric)
	end
	for _, name in {"LeftLowerArm", "RightLowerArm", "LeftLowerLeg", "RightLowerLeg"} do
		local limb = model:FindFirstChild(name)
		if limb and limb:IsA("BasePart") then
			gear(outfit, limb, if string.find(name, "Arm") then "LinenBracer" else "LegWrap", limb.Size+Vector3.new(0.07,-0.15,0.07),CFrame.new(),WRAP,Enum.Material.Fabric)
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
end

-- Shared with EnemyAppearance so every fighter's attire is built the same way.
Appearance.Gear = gear

return table.freeze(Appearance)
