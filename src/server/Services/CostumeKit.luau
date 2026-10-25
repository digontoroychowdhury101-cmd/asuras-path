--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/CostumeKit
-- Builds a CostumeSchema look onto a live rig (batches 11-14). Every piece is a non-colliding,
-- non-querying, massless Part joined to its limb by a Weld whose C0 is the authored offset, so the
-- rig's Motor6Ds, animations and the server's rewound hurtboxes are untouched; creature joints
-- (AsuraJoint) are posed client-side by CreatureMotion through the same C0. Phase pieces are shown
-- or hidden in place. Creature looks hide the humanoid body (BossAppearance adds their world hull).
local Schema = require(game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath").Shared.CostumeSchema)

local Kit = {}
local warned: { [string]: boolean } = {}

local function v3(list: { number }): Vector3 return Vector3.new(list[1], list[2], list[3]) end

local function offset(piece: Schema.Piece, limb: BasePart): CFrame
	local at, face, rot = v3(piece.At or { 0, 0, 0 }), v3(piece.Face or { 0, 0, 0 }), piece.Rot or { 0, 0, 0 }
	return CFrame.new(at + face * limb.Size * 0.5) * CFrame.Angles(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
end

local function make(piece: Schema.Piece, limb: BasePart, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = piece.Name
	p.Shape = (Enum.PartType :: any)[piece.Shape or "Block"]
	p.Size = if piece.Fit then limb.Size + v3(piece.Size) else v3(piece.Size)
	p.Color = Color3.fromRGB(piece.Color[1], piece.Color[2], piece.Color[3])
	p.Material = (Enum.Material :: any)[piece.Material]
	p.Transparency = piece.Transparency or 0
	p.Anchored, p.Massless, p.CanCollide, p.CanQuery, p.CanTouch = false, true, false, false, false
	p.CastShadow = piece.Glow == nil
	local c0 = offset(piece, limb)
	p.CFrame = limb.CFrame * c0
	local weld = Instance.new("Weld")
	weld.Name, weld.Part0, weld.Part1, weld.C0 = "AsuraBind", limb, p, c0
	weld.Parent = p
	p:SetAttribute("AsuraOpacity", p.Transparency)
	if piece.Phase then p:SetAttribute("AsuraPhase", piece.Phase) end
	if piece.Joint then
		p:SetAttribute("AsuraJoint", piece.Joint)
		-- The hinge in the piece's own space as a fraction of its size, so it survives Model:ScaleTo.
		local hinge = c0:PointToObjectSpace(if piece.Pivot then v3(piece.Pivot) else c0.Position)
		p:SetAttribute("AsuraPivot", hinge / p.Size)
		if piece.Pivot2 then p:SetAttribute("AsuraPivot2", c0:PointToObjectSpace(v3(piece.Pivot2)) / p.Size) end
	end
	if piece.Role then p:SetAttribute("AsuraRole", piece.Role) end
	if piece.Glow then
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness, light.Shadows = p.Color, piece.Glow, 0.7, false
		if piece.Name == "SoulLantern" then
			light.Color, light.Range, light.Brightness, light.Shadows = Color3.fromRGB(255, 175, 95), 15, 1.2, true
		end
		light.Parent = p
	end
	p.Parent = parent
	return p
end

-- Builds `look` onto `model`, replacing any earlier attire. Returns the folder and missing limbs.
function Kit.build(model: Model, look: Schema.Look, phase: number?): (Folder, { string })
	for _, name in { "AsuraAttire", "AsuraHull" } do
		local old = model:FindFirstChild(name)
		if old then old:Destroy() end
	end
	local folder = Instance.new("Folder")
	folder.Name = "AsuraAttire"
	folder:SetAttribute("AsuraCostume", look.Key)
	folder.Parent = model
	local missing: { string } = {}
	for _, piece in look.Pieces do
		local limb = model:FindFirstChild(piece.Bone)
		if limb and limb:IsA("BasePart") then
			make(piece, limb, folder)
		elseif not table.find(missing, piece.Bone) then
			table.insert(missing, piece.Bone)
		end
	end
	if look.HideBody then
		for _, item in model:GetChildren() do
			if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" then
				item.Transparency, item.CastShadow = 1, false
				local face = item:FindFirstChildOfClass("Decal")
				if face then face:Destroy() end
			end
		end
	end
	if look.Body and not look.HideBody then
		for index, body in { look.Body, look.Body2 or look.Body } do
			folder:SetAttribute("Skin" .. index, Color3.fromRGB(body[1][1], body[1][2], body[1][3]))
			folder:SetAttribute("Cloth" .. index, Color3.fromRGB(body[2][1], body[2][2], body[2][3]))
		end
	end
	model:SetAttribute("AsuraCostume", look.Key)
	model:SetAttribute("AsuraRig", look.Rig)
	model:SetAttribute("AsuraWeaponVisual", if look.OwnWeapon then "Costume" else nil)
	local held: { string } = if look.OwnWeapon then { "AsuraWeapon", "ArsenalWeapon" } else {}
	for _, name in held do
		local generic = model:FindFirstChild(name) -- the generic held weapon; the look carries its own
		if generic then generic:Destroy() end
	end
	if #missing > 0 and not warned[look.Key] then
		warned[look.Key] = true
		warn("[Asura Costume] " .. look.Key .. " missing limbs: " .. table.concat(missing, ", "))
	end
	Kit.phase(model, phase or 1)
	return folder, missing
end

-- Shows the pieces of `phase` (untagged pieces always show).
function Kit.phase(model: Model, phase: number)
	local folder = model:FindFirstChild("AsuraAttire")
	if not folder then return end
	folder:SetAttribute("AsuraPhase", phase)
	-- Bare skin (head, hands) and base cloth of the rig itself, per phase.
	local skin, cloth = folder:GetAttribute("Skin" .. phase) or folder:GetAttribute("Skin1"), folder:GetAttribute("Cloth" .. phase) or folder:GetAttribute("Cloth1")
	if typeof(skin) == "Color3" and typeof(cloth) == "Color3" then
		for _, item in model:GetChildren() do
			if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" and item.Name ~= "AsuraWeapon" and item.Name ~= "AsuraHull" then
				local bare = item.Name == "Head" or string.find(item.Name, "Hand") ~= nil
				item.Color, item.Material = if bare then skin else cloth, Enum.Material.SmoothPlastic
			end
		end
	end
	local skin = model:FindFirstChild("AsuraBossSkin") -- a production skin covers all but the weapon, unless it owns one
	local skinned, skinWeapon = skin ~= nil, skin ~= nil and skin:GetAttribute("OwnsWeapon") == true
	for _, item in folder:GetChildren() do
		if item:IsA("BasePart") then
			local tagged = item:GetAttribute("AsuraPhase")
			local base = item:GetAttribute("AsuraOpacity")
			local show = (tagged == nil or tagged == phase) and (not skinned or (item:GetAttribute("AsuraRole") == "Weapon" and not skinWeapon))
			item.Transparency = if show then (if type(base) == "number" then base else 0) else 1
			local light = item:FindFirstChildOfClass("PointLight")
			if light then light.Enabled = show end
		end
	end
end

return table.freeze(Kit)
