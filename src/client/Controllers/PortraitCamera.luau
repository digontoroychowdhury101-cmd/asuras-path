--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/PortraitCamera
-- Conversation framing for physical NPCs and Lin's altar projection. Tries over-the-shoulder shots
-- from the player's side (right, then left), then raised and wider angles, and takes the first whose
-- line to the speaker's head and chest is clear of visible geometry (bonfire, stone, pillars).
-- If every angle is blocked it pulls the best one in front of the obstruction, and as a last resort
-- frames from above. The projected spirit is placed on clear ground beside the altar, facing the
-- player. Selection is pure (a probe function is injected) so it is tested without the engine.
local Workspace = game:GetService("Workspace")

local Portrait = {}
Portrait.Distance = 7 -- studs from the speaker
Portrait.Shoulder = 2
Portrait.Height = 1
Portrait.Margin = 0.8 -- clearance kept around the camera
Portrait.MinReach = 3.2 -- a pulled-in shot closer than this is rejected
Portrait.Chest = 1.2 -- second sight line, below the head
Portrait.Fov = 52 -- vertical field of view while a conversation is framed (CameraController)

-- Returns where a segment first meets visible geometry, or nil when it is clear.
export type Probe = (from: Vector3, to: Vector3) -> Vector3?

local function facing(subject: Vector3, viewer: Vector3): (Vector3, Vector3)
	local flat = Vector3.new(viewer.X - subject.X, 0, viewer.Z - subject.Z)
	local toward = if flat.Magnitude > 0.1 then flat.Unit else Vector3.zAxis
	return toward, toward:Cross(Vector3.yAxis)
end

-- Camera positions in preference order: both shoulders, raised shoulders, then wide side angles.
function Portrait.candidates(subject: Vector3, viewer: Vector3): { Vector3 }
	local toward, side = facing(subject, viewer)
	local list: { Vector3 } = {}
	for _, spec in { { 1, 0, 1 }, { -1, 0, 1 }, { 1, 1.6, 0.9 }, { -1, 1.6, 0.9 }, { 2.6, 0.6, 0.7 }, { -2.6, 0.6, 0.7 } } do
		local offset = toward * Portrait.Distance * spec[3] + side * Portrait.Shoulder * spec[1]
		table.insert(list, subject + offset + Vector3.new(0, Portrait.Height + spec[2], 0))
	end
	return list
end

-- Picks a shot. Returns the camera position and whether it was a clean (unobstructed) candidate.
function Portrait.choose(subject: Vector3, viewer: Vector3, probe: Probe): (Vector3, boolean)
	local chest = subject - Vector3.new(0, Portrait.Chest, 0)
	local best: Vector3? = nil
	local bestReach = 0
	for _, c in Portrait.candidates(subject, viewer) do
		local away = (c - subject).Unit
		local past = c + away * Portrait.Margin
		local hit = probe(subject, past) or probe(chest, past)
		if not hit then return c, true end
		local reach = (hit - subject).Magnitude - Portrait.Margin
		if reach > bestReach then best, bestReach = subject + away * reach, reach end
	end
	if best and bestReach >= Portrait.MinReach then return best, false end
	local toward = facing(subject, viewer)
	return subject + toward * 2 + Vector3.new(0, 6, 0), false
end

-- Where Lin's spirit stands: beside the altar on the player's side, with a clear path from the
-- altar at chest height and (batch 07) in plain view of the player, so a stele or pillar never
-- stands between the two; resting on the ground below. Returns the spirit's pivot position.
function Portrait.spiritSpot(altar: Vector3, viewer: Vector3, probe: Probe): Vector3
	local toward, side = facing(altar, viewer)
	local chosen = altar + toward * 3 + side * 2
	local eye = viewer + Vector3.new(0, 1.5, 0)
	for _, offset in { toward * 3 + side * 2, toward * 3 + side * -2, toward * 4, side * 3, side * -3 } do
		local spot = altar + offset
		local chest = spot + Vector3.new(0, 3, 0)
		if not probe(altar + Vector3.new(0, 3, 0), chest) and not probe(chest, eye) then chosen = spot; break end
	end
	local ground = probe(chosen + Vector3.new(0, 5, 0), chosen - Vector3.new(0, 4, 0))
	return Vector3.new(chosen.X, (if ground then ground.Y else chosen.Y) + 2, chosen.Z)
end

-- Engine probe: ignores the excluded instances and invisible volumes, so only what the player
-- would actually see between the camera and the speaker counts as an obstruction.
function Portrait.probe(exclude: { Instance }): Probe
	return function(from: Vector3, to: Vector3): Vector3?
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local ignored = table.clone(exclude)
		params.FilterDescendantsInstances = ignored
		for _ = 1, 6 do
			local result = Workspace:Raycast(from, to - from, params)
			if not result then return nil end
			local part = result.Instance
			if part.Transparency < 0.9 then return result.Position end
			table.insert(ignored, part)
			params.FilterDescendantsInstances = ignored
		end
		return nil
	end
end

-- Looks from `position` at `face`, pitched down so the face sits at `faceY` of the screen height
-- (0 = top) instead of the centre, which the dialogue panel covers.
function Portrait.aim(position: Vector3, face: Vector3, faceY: number): CFrame
	local above = math.clamp(1 - 2 * faceY, 0, 0.9) -- how far above the centre, in half-screens
	local pitch = math.atan(above * math.tan(math.rad(Portrait.Fov) / 2))
	return CFrame.lookAt(position, face) * CFrame.Angles(-pitch, 0, 0)
end

-- The speaker's own model: JadeCataclysm.<npc>, else any model tagged AsuraNPC = npc (Master Smith
-- Gao stands in the Sanctuary loggia). F13: Gao was never found, so his body was not excluded from
-- the probe, every shot hit him and the portrait fell back to looking down on his topknot.
function Portrait.speaker(npc: string, world: Instance?, tagged: { Instance }): Instance?
	local found = world and world:FindFirstChild(npc)
	if found then return found end
	for _, model in tagged do
		if model:IsA("Model") and model:GetAttribute("AsuraNPC") == npc then return model end
	end
	return nil
end

function Portrait.frame(subject: Vector3, viewer: Vector3, exclude: { Instance }): CFrame
	local position = Portrait.choose(subject, viewer, Portrait.probe(exclude))
	return CFrame.lookAt(position, subject)
end

return table.freeze(Portrait)
