--!strict
local RunService = game:GetService("RunService")
local Cues = {}
local ids: { [string]: string } = {}
-- The published Zhao equip clip already supplies both timing marks. Only its events are used here.
local EQUIP = "rbxassetid://121747729384282"
local PUBLISHED = {
	Draw = { Name = "TrailOn", Time = .2 },
	Sheath = { Name = "TrailOff", Time = .666667 },
}

local function previewId(name: string, at: number): string
	if ids[name] then return ids[name] end
	local sequence = Instance.new("KeyframeSequence")
	for _, time in { 0, at, at + .12 } do
		local key = Instance.new("Keyframe")
		key.Time, key.Parent = time, sequence
		local root = Instance.new("Pose")
		root.Name, root.Parent = "Root", key
		local prop = Instance.new("Pose")
		prop.Name, prop.Parent = "Prop", root
		if time == at then
			local marker = Instance.new("KeyframeMarker")
			marker.Name = name
			key:AddMarker(marker)
		end
	end
	local ok, id = pcall(function()
		return game:GetService("KeyframeSequenceProvider"):RegisterKeyframeSequence(sequence)
	end)
	sequence:Destroy()
	if not ok then error(tostring(id)) end
	ids[name] = id
	return id
end

-- Keep the reveal on time if the animation has yet to load or markers are unavailable.
function Cues.play(world: WorldModel, lifetime: any, name: string, at: number, run: (boolean) -> ())
	local fired = false
	local function once(native: boolean)
		if fired then return end
		fired = true
		run(native)
	end
	local native = pcall(function()
		local marker = PUBLISHED[name]
		local localClip = RunService:IsStudio()
		local id = if localClip then previewId(name, at) else EQUIP
		local eventName = if localClip then name else marker.Name
		local speed = if localClip then 1 else marker.Time / at
		local rig = lifetime:Add(Instance.new("Model")) :: Model
		rig.Name = "InspectionTimeline"
		local root, prop = Instance.new("Part"), Instance.new("Part")
		root.Name, prop.Name = if localClip then "Root" else "HumanoidRootPart", if localClip then "Prop" else "LowerTorso"
		for _, piece in { root, prop } do
			piece.Transparency, piece.CanCollide, piece.CanTouch, piece.CanQuery = 1, false, false, false
			piece.Parent = rig
		end
		root.Anchored = true
		local joint = Instance.new("Motor6D")
		joint.Part0, joint.Part1, joint.Parent = root, prop, root
		local controller = Instance.new("AnimationController")
		controller.Parent = rig
		local animator = Instance.new("Animator")
		animator.Parent = controller
		rig.Parent = world
		local clip = Instance.new("Animation")
		clip.AnimationId, clip.Parent = id, rig
		local track = animator:LoadAnimation(clip)
		lifetime:Add(track)
		lifetime:Connect(track:GetMarkerReachedSignal(eventName), function() once(true) end)
		track:Play(0, 1, speed)
	end)
	local watchdog = task.delay(at + (if native then .05 else 0), once, false)
	lifetime:Add(function()
		if coroutine.status(watchdog) == "suspended" then task.cancel(watchdog) end
	end)
end

return Cues
