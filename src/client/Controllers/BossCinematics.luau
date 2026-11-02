--!strict
local WorldState = require(script.Parent.WorldStateController)
local PlaybackScale = require(script.Parent.PlaybackScale)
local Cinematics = {}
local SLOW_MOTION = 0.25
export type Shot = { Target: number, Start: number, Duration: number, From: CFrame, Finish: boolean, Span: number }
-- Framing grows with the actor (batch 11): a scale-3 Titan or a winged Wyrm is framed whole
-- instead of the camera sitting inside its body at the old fixed 14 studs.
function Cinematics.span(model: Model?): number
	if not model then return 6 end
	local ok, size = pcall(function() return model:GetExtentsSize() end)
	return if ok then math.clamp(math.max(size.Y, size.Z * 0.8), 6, 40) else 6
end
function Cinematics.begin(camera: Camera, state: WorldState.WorldState, id: number, duration: number, finish: boolean): Shot
	-- A finishing shot slows both bodies' clips through their playback owners, whichever clips they start during it.
	if finish then
		for _, entity in { state:Get(id), state:Own() } do
			if entity then PlaybackScale.request(entity.Model, "Finish", SLOW_MOTION, os.clock() + duration, true) end
		end
	end
	local entity = state:Get(id)
	return { Target = id, Start = os.clock(), Duration = duration, From = camera.CFrame, Finish = finish,
		Span = Cinematics.span(entity and entity.Model) }
end
function Cinematics.restore(shot: Shot?)
	if shot and shot.Finish then PlaybackScale.clear("Finish") end
end
function Cinematics.step(shot: Shot?, state: WorldState.WorldState, camera: Camera): boolean
	if not shot then return false end
	local elapsed = os.clock() - shot.Start
	local entity = state:Get(shot.Target)
	local own = state:Own()
	if elapsed >= shot.Duration or not entity or not entity.Root or not own or not own.Snapshot or own.Snapshot.State == "KO" then
		Cinematics.restore(shot); return false
	end
	local span = shot.Span
	local target = entity.Root.Position + Vector3.new(0, span * 0.3, 0)
	local view = target + entity.Root.CFrame.LookVector * (span * 1.4 + 6) + entity.Root.CFrame.RightVector * (span * 0.55 + 3.5) + Vector3.new(0, span * 0.2 + 3.5, 0)
	local goal = CFrame.lookAt(view, target)
	camera.CFrame = shot.From:Lerp(goal, math.clamp(elapsed / 0.65, 0, 1))
	camera.Focus = CFrame.new(target)
	camera.FieldOfView = if shot.Finish then 46 else 56
	return true
end
return Cinematics
