--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/CameraClearance
-- Post-F26 Step 4. A hostile body that stands between the lens and the player (nearer the camera
-- than the player, and not the locked target) is drawn see-through on this client only. Studio: with
-- the Iron Bull locked, General Zhao flanked beside the lens and covered 35% of the frame (62% peak).
-- The camera spherecast ignores fighters by design, so this fade is the clearance for bodies. Purely
-- visual: hurtboxes, telegraphs and the server are untouched; the faded body keeps its silhouette.
local Clearance = {}

Clearance.Fade = 0.6 -- LocalTransparencyModifier for a body in the lens's near field
Clearance.Margin = 1.5 -- studs nearer the camera than the player before a body counts as in front
Clearance.Range = 30 -- only bodies this close to the player (the fight, not the far arena)

-- Whether a body fades: nearer the lens than the player by Margin, near the player, not locked.
function Clearance.shouldFade(cameraToBody: number, cameraToPlayer: number, bodyToPlayer: number, locked: boolean): boolean
	return not locked and bodyToPlayer <= Clearance.Range and cameraToBody < cameraToPlayer - Clearance.Margin
end

local faded: { [Model]: { BasePart } } = {}

local function setFade(model: Model, value: number)
	local parts = faded[model]
	if not parts then
		parts = {}
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 1 then table.insert(parts, d) end
		end
		faded[model] = parts
	end
	for _, part in parts do
		if part.Parent then part.LocalTransparencyModifier = value end
	end
	if value == 0 then faded[model] = nil end
end

-- Called once per camera frame with the hostile, living bodies the camera knows about.
function Clearance.step(bodies: { { Model: Model, Root: BasePart, Locked: boolean } }, cameraPosition: Vector3, playerPosition: Vector3)
	local keep: { [Model]: boolean } = {}
	local toPlayer = (playerPosition - cameraPosition).Magnitude
	for _, body in bodies do
		local position = body.Root.Position
		if Clearance.shouldFade((position - cameraPosition).Magnitude, toPlayer, (position - playerPosition).Magnitude, body.Locked) then
			keep[body.Model] = true
			setFade(body.Model, Clearance.Fade)
		end
	end
	for model in faded do
		if not keep[model] then setFade(model, 0) end
	end
end

function Clearance.clear()
	for model in faded do setFade(model, 0) end
end

return Clearance
