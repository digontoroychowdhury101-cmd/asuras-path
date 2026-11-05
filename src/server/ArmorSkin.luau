--!strict
-- ModuleScript: ServerScriptService/AsurasPath/ArmorSkin
-- Dresses a player rig in its worn armour: the set's template (ServerStorage.AsuraAssets.AsuraArmor_<Set>) is one rigid MeshPart per
-- limb piece, bound like a boss skin (part = limb * AsuraBind:Inverse()). The suit is the body while worn, so the blocky limbs it covers
-- go invisible; their collision, hurtboxes and joints are untouched, and every piece is massless and answers no query. Only the suit's own
-- folder and the wanderer attire it replaces are ever removed. A set without a template leaves the wanderer as is.
local ServerStorage = game:GetService("ServerStorage")
local Skin = {}

local FOLDER = "AsuraArmor"
local LIMBS = { "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" }
-- Attire worn on the head stays: the sets dress the body, and the wanderer's face and hat are his.
local HEAD_ATTIRE = { WovenHat = true, ShadowedFaceWrap = true, HairCap = true, Queue = true, Eye = true, Brow = true }

local function template(set: string?): Model?
	local assets = ServerStorage:FindFirstChild("AsuraAssets")
	local found = set and assets and assets:FindFirstChild("AsuraArmor_" .. set)
	return if found and found:IsA("Model") then found else nil
end

local function setLimbs(model: Model, transparency: number)
	for _, name in LIMBS do
		local limb = model:FindFirstChild(name)
		if limb and limb:IsA("BasePart") then limb.Transparency = transparency end
	end
end

-- True when the suit on this rig is `set` and every piece is still welded to a live limb (avatar loading can replace limbs).
function Skin.Attached(model: Model, set: string): boolean
	local folder = model:FindFirstChild(FOLDER)
	if not folder or folder:GetAttribute("Set") ~= set then return false end
	local count = 0
	for _, piece in folder:GetChildren() do
		local weld = piece:FindFirstChildOfClass("WeldConstraint")
		local limb = weld and weld.Part0
		if not limb or limb.Parent ~= model then return false end
		count += 1
	end
	return count > 0
end

function Skin.Remove(model: Model)
	local folder = model:FindFirstChild(FOLDER)
	if folder then folder:Destroy() end
	setLimbs(model, 0)
end

-- `set` is the worn id or "None". Returns "Worn", "Bare" or "NoModel". Safe to repeat: an intact suit is left alone.
function Skin.Apply(model: Model, set: string?): string
	model:SetAttribute("AsuraArmorSet", set)
	local source = template(set)
	if not set or not source then
		Skin.Remove(model)
		return if set and set ~= "None" then "NoModel" else "Bare"
	end
	local function worn(): string
		setLimbs(model, 1)
		local attire = model:FindFirstChild("AsuraAttire")
		if attire then
			for _, item in attire:GetChildren() do
				if not HEAD_ATTIRE[item.Name] then item:Destroy() end
			end
		end
		return "Worn"
	end
	if Skin.Attached(model, set) then return worn() end
	Skin.Remove(model)
	local folder = Instance.new("Folder")
	folder.Name = FOLDER
	folder:SetAttribute("Set", set)
	for _, piece in source:GetChildren() do
		if piece:IsA("MeshPart") then
			local bone, bind = piece:GetAttribute("AsuraBone"), piece:FindFirstChild("AsuraBind")
			local limb = type(bone) == "string" and model:FindFirstChild(bone)
			if limb and limb:IsA("BasePart") and bind and bind:IsA("Attachment") then
				local part = piece:Clone()
				part.Anchored, part.Massless, part.CanCollide, part.CanTouch, part.CanQuery = false, true, false, false, false
				part.CFrame = limb.CFrame * bind.CFrame:Inverse()
				local weld = Instance.new("WeldConstraint")
				weld.Part0, weld.Part1 = limb, part
				weld.Parent = part
				part.Parent = folder
			end
		end
	end
	folder.Parent = model
	return worn()
end

return table.freeze(Skin)
