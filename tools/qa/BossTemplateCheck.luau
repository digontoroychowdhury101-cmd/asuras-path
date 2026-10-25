--!nonstrict
-- Studio Edit / command-bar tool for boss skin templates (post-F26 Shen handoff). Never saves, never
-- uploads. Two modes, set below:
--   STAMP    writes each MeshPart's AsuraBind Attachment from the template's current pose over a
--            reference R15 rig (workspace.AsuraRigReference, or a default R15 built on demand), so
--            BossSkin's `part.CFrame = limb.CFrame * AsuraBind.CFrame:Inverse()` reproduces the pose.
--   VALIDATE read-only: the BossSkin + PbrAssets contract plus the Shen handoff's own rules
--            (15-limb coverage, separate weapon meshes, scale, weapon tip reach, per-part naming).
-- Usage: select nothing, paste into the command bar with MODE/NAME set, or run through execute_luau.
local MODE = "VALIDATE" -- "STAMP" | "VALIDATE"
local NAME = "AsuraBoss_GrandmasterShen_P1"

local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local LIMBS = { "Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm",
	"RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" }
-- Weapon tip distance from the RightHand centre at scale 1, matching the costume blades that already
-- line up with the server's reach (LooksDuelists: Jian 7.5, Guandao 11 + 2.5 bonus).
local TIP = { AsuraBoss_GrandmasterShen_P1 = { 6.75, "Jian" }, AsuraBoss_GrandmasterShen_P2 = { 12.7, "Guandao" } }

local function reference(): Model
	local rig = workspace:FindFirstChild("AsuraRigReference")
	if rig then return rig end
	rig = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	rig.Name = "AsuraRigReference"
	rig:PivotTo(CFrame.new(0, 3, 0))
	rig.Parent = workspace
	return rig
end

local library = ServerStorage:FindFirstChild("AsuraAssets")
local template = (library and library:FindFirstChild(NAME)) or workspace:FindFirstChild(NAME)
if not template or not template:IsA("Model") then
	return "no Model named " .. NAME .. " in ServerStorage.AsuraAssets or Workspace"
end

if MODE == "STAMP" then
	local rig = reference()
	local stamped, problems = 0, {}
	for _, part in template:GetDescendants() do
		if part:IsA("MeshPart") then
			local bone = part:GetAttribute("AsuraBone")
			local limb = type(bone) == "string" and rig:FindFirstChild(bone)
			if not limb then
				table.insert(problems, part.Name .. ": AsuraBone " .. tostring(bone) .. " is not an R15 limb")
			else
				local bind = part:FindFirstChild("AsuraBind") or Instance.new("Attachment")
				bind.Name = "AsuraBind"
				bind.CFrame = part.CFrame:ToObjectSpace(limb.CFrame)
				bind.Parent = part
				stamped += 1
			end
		end
	end
	return string.format("stamped %d AsuraBind attachments on %s%s", stamped, NAME, if #problems > 0 then "\n" .. table.concat(problems, "\n") else "")
end

local out, fails = {}, 0
local function check(ok: boolean, text: string)
	if not ok then fails += 1 end
	table.insert(out, (if ok then "PASS " else "FAIL ") .. text)
end
local coverage, weapons, meshes = {}, {}, 0
for _, part in template:GetDescendants() do
	if part:IsA("BasePart") and not part:IsA("MeshPart") then
		check(false, part.Name .. " is a " .. part.ClassName .. " (BossSkin only binds MeshParts; remove it)")
	end
	if part:IsA("MeshPart") then
		meshes += 1
		local bone, role = part:GetAttribute("AsuraBone"), part:GetAttribute("AsuraRole")
		local surface = part:FindFirstChildOfClass("SurfaceAppearance")
		local maps = surface ~= nil
		if surface then
			for _, key in { "ColorMapContent", "NormalMapContent", "RoughnessMapContent", "MetalnessMapContent" } do
				local content = surface[key]
				if not content or not content.Uri or content.Uri == "" then maps = false end
			end
		end
		check(table.find(LIMBS, bone) ~= nil, part.Name .. " AsuraBone=" .. tostring(bone))
		check(part:FindFirstChild("AsuraBind") ~= nil and part.AsuraBind:IsA("Attachment"), part.Name .. " has an AsuraBind Attachment")
		check(maps, part.Name .. " SurfaceAppearance with Color/Normal/Roughness/Metalness maps")
		check(part.MeshId ~= "" and string.match(part.MeshId, "^rbxassetid://%d+$") ~= nil, part.Name .. " uploaded MeshId")
		if type(bone) == "string" then coverage[bone] = true end
		if role == "Weapon" then
			table.insert(weapons, part)
			check(bone == "RightHand" or bone == "LeftHand", part.Name .. " weapon binds to a hand")
		end
	end
end
check(meshes > 0, meshes .. " MeshParts")
for _, limb in LIMBS do check(coverage[limb] == true, "covers " .. limb) end
local size = template:GetExtentsSize()
check(size.Y > 4.6 and size.Y < 7.5, string.format("authored at scale 1: height %.2f studs (R15 body about 5.2; horns/mane may add)", size.Y))
check(template:GetScale() == 1, "Model scale 1 (BossSkin applies the actor's scale; never bake it)")
local tip = TIP[NAME]
if tip then
	check(#weapons > 0, string.format("%d separate weapon MeshParts (AsuraRole=Weapon) for the %s", #weapons, tip[2]))
	local rig = reference()
	local hand, far = rig:FindFirstChild("RightHand"), 0
	for _, w in weapons do
		local placed = hand.CFrame * w.AsuraBind.CFrame:Inverse()
		local half = w.Size / 2
		for _, corner in { Vector3.new(half.X, half.Y, half.Z), Vector3.new(-half.X, -half.Y, -half.Z), Vector3.new(half.X, -half.Y, -half.Z), Vector3.new(-half.X, half.Y, half.Z) } do
			far = math.max(far, (placed:PointToWorldSpace(corner) - hand.Position).Magnitude)
		end
	end
	check(math.abs(far - tip[1]) <= 0.6, string.format("%s tip %.2f studs from the RightHand centre (target %.2f ± 0.6)", tip[2], far, tip[1]))
end
return string.format("%s: %d checks, %d failed\n%s", NAME, #out, fails, table.concat(out, "\n"))
