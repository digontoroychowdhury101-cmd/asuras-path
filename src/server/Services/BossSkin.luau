--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/BossSkin
-- Production skin binding. A template is a Model in ServerStorage.AsuraAssets named by
-- CostumeSchema.templates (AsuraBoss_<LookKey>_P<phase>, then AsuraBoss_<LookKey>, then the legacy
-- encounter names). Each MeshPart carries an AsuraBone attribute (R15 limb, or HumanoidRootPart for
-- creatures) and an AsuraBind Attachment aligned to that limb; skin geometry never collides,
-- queries or touches. Audit (batch 11): the library held no AsuraBoss_* templates at all, both
-- Twins resolved the same encounter template, and a missing/invalid template returned silently, so
-- every boss showed its bare block rig. Now each actor resolves its own look key, every outcome is
-- written to the AsuraSkinStatus attribute (and warned once), and the authored CostumeKit look
-- remains the visible fallback until a valid template is imported.
local ServerStorage = game:GetService("ServerStorage")
local Schema = require(game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath").Shared.CostumeSchema)
local Pbr = require(script.Parent.PbrAssets)

local Skin = {}
local reported: { [string]: boolean } = {}

local function report(actor: Model, status: string)
	actor:SetAttribute("AsuraSkinStatus", status)
	local key = tostring(actor:GetAttribute("AsuraLookKey")) .. "|" .. status
	if not reported[key] and string.sub(status, 1, 9) ~= "Template:" then
		reported[key] = true
		warn("[Asura AV] " .. actor.Name .. " skin " .. status)
	end
end

-- The candidate names for this actor and the first one present in the library.
function Skin.resolve(library: Instance?, actor: Model): (Model?, { string })
	local encounter = actor:GetAttribute("AsuraEncounter")
	local key = actor:GetAttribute("AsuraLookKey")
	local phase = actor:GetAttribute("AsuraBossPhase")
	local set = actor:GetAttribute("AsuraAnimationSet")
	local lookKey = if type(key) == "string" then key elseif type(encounter) == "string" then encounter else actor.Name
	local names = Schema.templates(lookKey, if type(phase) == "number" then phase else 1,
		if type(encounter) == "string" then encounter else nil, if type(set) == "string" then set else nil)
	for _, name in names do
		local found = library and library:FindFirstChild(name)
		if found and found:IsA("Model") then return found, names end
	end
	return nil, names
end

function Skin.attach(actor: Model): boolean
	local library = ServerStorage:FindFirstChild("AsuraAssets")
	local template, names = Skin.resolve(library, actor)
	local old = actor:FindFirstChild("AsuraBossSkin")
	if not template then
		if not old then report(actor, "Fallback:Costume (no " .. names[1] .. " or " .. names[2] .. ")") end
		return old ~= nil
	end
	if old and old:GetAttribute("Template") == template.Name then return true end
	local valid, reason = Pbr.validate(template)
	if not valid then report(actor, "Invalid:" .. template.Name .. " " .. tostring(reason)); return false end
	local rig = actor:GetAttribute("AsuraRig")
	local required = Schema.RequiredBones[if type(rig) == "string" then rig else "Humanoid"] or Schema.RequiredBones.Humanoid
	local model = template:Clone()
	model:ScaleTo(actor:GetScale())
	local coverage: { [string]: boolean } = {}
	local ownsWeapon = false
	for _, part in model:GetDescendants() do
		if not part:IsA("BasePart") then continue end
		part.Anchored, part.Massless, part.CanCollide, part.CanQuery, part.CanTouch = false, true, false, false, false
		if not part:IsA("MeshPart") then continue end
		local bone = part:GetAttribute("AsuraBone")
		local limb = if type(bone) == "string" then actor:FindFirstChild(bone) else nil
		local bind = part:FindFirstChild("AsuraBind")
		if not limb or not limb:IsA("BasePart") or not bind or not bind:IsA("Attachment") then
			model:Destroy()
			report(actor, "Invalid:" .. template.Name .. " " .. part.Name .. " unbound (AsuraBone " .. tostring(bone) .. ")")
			return false
		end
		coverage[bone :: string] = true
		ownsWeapon = ownsWeapon or part:GetAttribute("AsuraRole") == "Weapon"
		part.CFrame = limb.CFrame * bind.CFrame:Inverse()
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = limb, part, part
	end
	for _, bone in required do
		if not coverage[bone] then
			model:Destroy()
			report(actor, "Invalid:" .. template.Name .. " missing " .. bone)
			return false
		end
	end
	model:SetAttribute("Template", template.Name)
	-- A template that carries its own weapon meshes (AsuraRole=Weapon) replaces the costume weapon too;
	-- otherwise the costume weapon stays visible, so the drawn blade never doubles or vanishes.
	model:SetAttribute("OwnsWeapon", ownsWeapon)
	local phase = actor:GetAttribute("AsuraBossPhase") or 1
	if old then old:Destroy() end
	model.Name, model.Parent = "AsuraBossSkin", actor
	for _, part in actor:GetDescendants() do
		if part:IsA("BasePart") and not part:IsDescendantOf(model) and (ownsWeapon or (part.Name ~= "AsuraWeapon" and not part:FindFirstAncestor("ArsenalWeapon")
			and part:GetAttribute("AsuraRole") ~= "Weapon")) then
			part.Transparency, part.CastShadow = 1, false
		elseif not ownsWeapon and part:GetAttribute("AsuraRole") == "Weapon" and part:IsDescendantOf(actor:FindFirstChild("AsuraAttire") or model) then
			-- a weapon-owning skin of the previous phase may have hidden this phase's costume weapon
			local tag, base = part:GetAttribute("AsuraPhase"), part:GetAttribute("AsuraOpacity")
			if tag == nil or tag == phase then part.Transparency = if type(base) == "number" then base else 0 end
		end
	end
	report(actor, "Template:" .. template.Name)
	return true
end

return Skin
