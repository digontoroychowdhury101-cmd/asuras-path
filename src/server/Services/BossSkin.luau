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
local Rigs = require(game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath").Shared.BossRigs)
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

-- Loads the next form's meshes and maps ahead of its reveal: one copy per template in ReplicatedStorage (not the world, never rendered) that every
-- client preloads (ShenPresentation), so the swap under the camera never shows untextured geometry. Bounded: at most one copy per template, ever.
function Skin.prewarm(actor: Model, library: Instance?, phase: number)
	local look = actor:GetAttribute("AsuraLookKey")
	local template = library and type(look) == "string" and library:FindFirstChild("AsuraBoss_" .. look .. "_P" .. (phase + 1))
	if not template or not template:IsA("Model") then return end
	local replicated = game:GetService("ReplicatedStorage")
	local folder = replicated:FindFirstChild("AsuraSkinPrewarm")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "AsuraSkinPrewarm"
		folder.Parent = replicated
	end
	if not folder:FindFirstChild(template.Name) then template:Clone().Parent = folder end
end

local STAGED = "AsuraBossSkinStaged"

-- A clone of the template, scaled to the actor and bound to its limbs; nil and the reason if a piece cannot be bound.
local function bindClone(actor: Model, template: Model): (Model?, string?, boolean, boolean)
	local rig = actor:GetAttribute("AsuraRig")
	local required = Schema.RequiredBones[if type(rig) == "string" then rig else "Humanoid"] or Schema.RequiredBones.Humanoid
	local model = template:Clone()
	model:ScaleTo(actor:GetScale())
	local coverage: { [string]: boolean } = {}
	local ownsWeapon, anySkinned = false, false
	for _, part in model:GetDescendants() do
		if not part:IsA("BasePart") then continue end
		if part:GetAttribute("AsuraRole") == "Glow" then part.CastShadow = false end
		part.Anchored, part.Massless, part.CanCollide, part.CanQuery, part.CanTouch = false, true, false, false, false
		if not part:IsA("MeshPart") then continue end
		local bone = part:GetAttribute("AsuraBone")
		local limb = if type(bone) == "string" then actor:FindFirstChild(bone) else nil
		local bind = part:FindFirstChild("AsuraBind")
		local skinned = part:GetAttribute("AsuraSkinned") == "true"
		if not limb or not limb:IsA("BasePart") or not bind or not bind:IsA("Attachment") then
			model:Destroy()
			return nil, part.Name .. " unbound (AsuraBone " .. tostring(bone) .. ")", false, false
		end
		coverage[bone :: string] = true
		ownsWeapon = ownsWeapon or part:GetAttribute("AsuraRole") == "Weapon"
		part.CFrame = limb.CFrame * bind.CFrame:Inverse()
		if skinned then -- one skeleton carries all the limbs. Roblox skins parts together through a Weld or Motor6D, so the piece holds to the root by a Weld; BossCloth drives the bones
			anySkinned = true
			local weld = Instance.new("Weld")
			weld.Part0, weld.Part1, weld.C0, weld.Parent = limb, part, bind.CFrame:Inverse(), part
		else
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1, weld.Parent = limb, part, part
		end
	end
	for _, bone in (if anySkinned then {} else required) do
		if not coverage[bone] then
			model:Destroy()
			return nil, "missing " .. bone, false, false
		end
	end
	model:SetAttribute("Template", template.Name)
	return model, nil, ownsWeapon, anySkinned
end

-- (2026-11-06) The next form, staged before its reveal. A phase change used to destroy the old skin and parent the new one in the same server step,
-- so clients drew the boss with half his pieces for several frames while the rest replicated, then stalled on first use of the new meshes and maps:
-- the "white, see-through" swap. The transition (AIService, Transition.Reveal) now binds the next form hidden as soon as it begins; every piece and
-- bone reaches every client and BossCloth starts simulating it, and attach() at the reveal shows it and removes the old skin in one step.
-- Bounded: one staged skin per actor, replaced or removed by the next attach (a reset drops it).
function Skin.stage(actor: Model, phase: number): boolean
	local library = ServerStorage:FindFirstChild("AsuraAssets")
	local look = actor:GetAttribute("AsuraLookKey")
	local template = library and type(look) == "string" and library:FindFirstChild("AsuraBoss_" .. look .. "_P" .. phase)
	if not template or not template:IsA("Model") then return false end
	local existing = actor:FindFirstChild(STAGED)
	if existing then
		if existing:GetAttribute("Template") == template.Name then return true end
		existing:Destroy()
	end
	if not Pbr.validate(template) then return false end
	local model, _, ownsWeapon, anySkinned = bindClone(actor, template)
	if not model then return false end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part:SetAttribute("AsuraStagedT", part.Transparency)
			part:SetAttribute("AsuraStagedShadow", part.CastShadow)
			part.Transparency, part.CastShadow = 1, false
		end
	end
	model:SetAttribute("OwnsWeapon", ownsWeapon)
	model:SetAttribute("AsuraAnySkinned", anySkinned)
	model.Name, model.Parent = STAGED, actor
	if anySkinned then game:GetService("CollectionService"):AddTag(model, "AsuraSkinnedBoss") end
	return true
end

function Skin.attach(actor: Model): boolean
	local library = ServerStorage:FindFirstChild("AsuraAssets")
	local template, names = Skin.resolve(library, actor)
	local old = actor:FindFirstChild("AsuraBossSkin")
	local staged = actor:FindFirstChild(STAGED)
	if staged and (not template or staged:GetAttribute("Template") ~= template.Name) then -- staged for a form this actor is not becoming (a reset): drop it
		staged:Destroy()
		staged = nil
	end
	if not template then
		if not old then report(actor, "Fallback:Costume (no " .. names[1] .. " or " .. names[2] .. ")") end
		return old ~= nil
	end
	if old and old:GetAttribute("Template") == template.Name then
		Skin.prewarm(actor, library, if type(actor:GetAttribute("AsuraBossPhase")) == "number" then actor:GetAttribute("AsuraBossPhase") :: number else 1)
		return true
	end
	local valid, reason = Pbr.validate(template)
	if not valid then report(actor, "Invalid:" .. template.Name .. " " .. tostring(reason)); return false end
	-- a sculpt that does not share the stock joints moves the pivots and adds its helper bones before any piece is placed
	local rigDef = (Rigs.ByTemplate :: { [string]: Rigs.Def })[template.Name]
	if rigDef then
		local applied, why = Rigs.apply(actor, rigDef)
		if not applied then report(actor, "Invalid:" .. template.Name .. " " .. tostring(why)); return false end
	end
	local model: Model, ownsWeapon: boolean, anySkinned: boolean
	if staged and staged:IsA("Model") then
		model, ownsWeapon, anySkinned = staged, staged:GetAttribute("OwnsWeapon") == true, staged:GetAttribute("AsuraAnySkinned") == true
	else
		local built, why, owns, skinnedAny = bindClone(actor, template)
		if not built then report(actor, "Invalid:" .. template.Name .. " " .. tostring(why)); return false end
		model, ownsWeapon, anySkinned = built, owns, skinnedAny
	end
	if anySkinned then
		game:GetService("CollectionService"):AddTag(model, "AsuraSkinnedBoss") -- BossCloth on every client; ends with the skin
		-- effect points on a limb ride that limb, in its rest frame; the old form's go with its limbs' next attach
		local rest = if rigDef then Rigs.rest(actor, rigDef) else {}
		for _, point in model:GetDescendants() do
			local name = if point:IsA("Attachment") then point:GetAttribute("AsuraFxLimb") else nil
			local limb = if type(name) == "string" then actor:FindFirstChild(name) else nil
			if limb and rest[name :: string] then
				local old_ = limb:FindFirstChild(point.Name)
				if old_ then old_:Destroy() end
				local attachment = point :: Attachment
				local bind = (attachment.Parent :: BasePart):FindFirstChild("AsuraBind") :: Attachment
				attachment.CFrame = rest[name :: string]:Inverse() * bind.CFrame:Inverse() * attachment.CFrame
				attachment.Parent = limb
			end
		end
	end
	-- A template that carries its own weapon meshes (AsuraRole=Weapon) replaces the costume weapon too;
	-- otherwise the costume weapon stays visible, so the drawn blade never doubles or vanishes.
	model:SetAttribute("OwnsWeapon", ownsWeapon)
	if anySkinned then actor:SetAttribute("AsuraTurnRate", Rigs.TurnRate) end
	local phase = actor:GetAttribute("AsuraBossPhase") or 1
	-- the swap is one step: the old form goes and the new one shows together, so no client draws a half-built body
	if old then old:Destroy() end
	if model == staged then
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				local t, shadow = part:GetAttribute("AsuraStagedT"), part:GetAttribute("AsuraStagedShadow")
				part.Transparency, part.CastShadow = if type(t) == "number" then t else 0, shadow ~= false
				part:SetAttribute("AsuraStagedT", nil)
				part:SetAttribute("AsuraStagedShadow", nil)
			end
		end
		model.Name = "AsuraBossSkin"
	else
		model.Name, model.Parent = "AsuraBossSkin", actor
	end
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
	Skin.prewarm(actor, library, if type(phase) == "number" then phase else 1)
	return true
end

return Skin
