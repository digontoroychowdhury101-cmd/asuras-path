--!strict
-- Multipart skin contract: each MeshPart has AsuraBone (R15 limb name) and AsuraBind Attachment.
-- The bind attachment is aligned to that limb. Skin geometry never participates in physics.
local ServerStorage = game:GetService("ServerStorage")
local Pbr = require(script.Parent.PbrAssets)
local Skin = {}
function Skin.attach(actor: Model): boolean
	if actor:FindFirstChild("AsuraBossSkin") then return true end
	local library = ServerStorage:FindFirstChild("AsuraAssets")
	local id = actor:GetAttribute("AsuraEncounter")
	local template = if library and type(id)=="string" then library:FindFirstChild("AsuraBoss_"..id) else nil
	if not template or not template:IsA("Model") then return false end
	local valid = Pbr.validate(template)
	if not valid then return false end
	local model = template:Clone()
	model:ScaleTo(actor:GetScale())
	local coverage: {[string]: boolean} = {}
	for _, part in model:GetDescendants() do
		if not part:IsA("MeshPart") then continue end
		local bone = part:GetAttribute("AsuraBone")
		local limb = if type(bone)=="string" then actor:FindFirstChild(bone) else nil
		local bind = part:FindFirstChild("AsuraBind")
		if not limb or not limb:IsA("BasePart") or not bind or not bind:IsA("Attachment") then model:Destroy(); return false end
		coverage[bone :: string] = true
		part.CFrame = limb.CFrame * bind.CFrame:Inverse()
		part.Anchored,part.Massless,part.CanCollide,part.CanQuery,part.CanTouch = false,true,false,false,false
		local weld=Instance.new("WeldConstraint");weld.Part0,weld.Part1,weld.Parent=limb,part,part
	end
	for _, bone in {"Head","UpperTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg"} do
		if not coverage[bone] then model:Destroy(); return false end
	end
	model.Name,model.Parent = "AsuraBossSkin",actor
	for _, part in actor:GetDescendants() do
		if part:IsA("BasePart") and not part:IsDescendantOf(model) and part.Name~="AsuraWeapon" and not part:FindFirstAncestor("ArsenalWeapon") then
			part.Transparency=1;part.CastShadow=false
		end
	end
	return true
end
return Skin
