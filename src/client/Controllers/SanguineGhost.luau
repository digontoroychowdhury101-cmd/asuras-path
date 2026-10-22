--!strict
-- Read-only silhouette samples: never clone a character, Humanoid, script or motion controller.
local Ghost = {}
local NAMES = { Head = true, UpperTorso = true, LowerTorso = true, Torso = true,
	LeftUpperArm = true, RightUpperArm = true, LeftUpperLeg = true, RightUpperLeg = true }
function Ghost.dodge(ctx: any, model: Model)
	local group = ctx:Group("SanguineDodgeAfterimage", 0.4)
	if not group then return end
	for _, limb in model:GetChildren() do
		if limb:IsA("BasePart") and NAMES[limb.Name] and limb.Transparency < 1 then
			local ghost = ctx:Part(group, "SanguineAfterimage", limb.Size * 0.97, limb.CFrame, Color3.fromRGB(103, 146, 185), 0.88)
			ctx:Tween(ghost, 0.3, { Transparency = 1 })
		end
	end
end
return table.freeze(Ghost)
