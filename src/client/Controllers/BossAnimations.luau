--!strict
-- Client playback for the shared boss animation contract (BossAnimationRules, F10): every boss
-- actor resolves its own look, phase and attack to an authored override/custom track or a stock
-- stand-in. A creature with nothing authored keeps CreatureMotion's procedural pose; when an
-- authored track plays on it, AsuraAuthoredMotion (local to this client) makes CreatureMotion
-- release its welds so the two never transform the same joints. Cosmetic only.
-- An authored attack is phase-locked to the cue's server impact time (Rules.Contacts): it starts,
-- speeds up, slows or holds so its contact lands on the impact; a repeat cue for the same move (the
-- Lightning Spear's later thrusts, a deferred impact) re-times the running track instead of
-- restarting it. A cancelling server state stops the attack and plays its reaction, if authored.
local Rules = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.BossAnimationRules)
local Timing = require(game:GetService("ReplicatedStorage").AsurasPath.Simulation.AnimationTiming)
local PlaybackScale = require(script.Parent.PlaybackScale)
local Animations = {}
type Playing = { Signature: string, Key: string, Source: string, Track: AnimationTrack?, Move: string?, Contacts: { number }?,
	First: number?, Target: number?, Speed: number?, HoldUntil: number?, Rate: number?, Debt: number?, WrittenAt: number? }
local playing: { [Model]: Playing } = {}
local reacted: { [Model]: string } = {}
-- The gait layer: one Movement-priority track per actor, chosen from his planted root velocity and fighter state. It runs under the idle's joints and
-- stands down while any attack, transform or reaction owns the body, so a joint always has one owner and the root is never moved twice: the server slides the
-- root, this only matches the feet to it.
type Gait = { Action: string?, Id: string?, Track: AnimationTrack?, Last: Vector3?, At: number?, Velocity: Vector3, Rate: number }
local gaits: { [Model]: Gait } = {}

-- Server clock, the time base of every cue's impact (overridable for tests).
function Animations.now(): number return workspace:GetServerTimeNow() end

local function rigOf(model: Model, humanoid: Humanoid?): string
	if model:GetAttribute("AsuraRig") == "Creature" then return "Creature" end
	return if humanoid and humanoid.RigType == Enum.HumanoidRigType.R6 then "R6" else "R15"
end

local function signature(model: Model): (string, number, string)
	local look, phase = model:GetAttribute("AsuraLookKey"), model:GetAttribute("AsuraBossPhase")
	local key = if type(look) == "string" then look else model.Name
	local index = if type(phase) == "number" then phase else 1
	return key, index, key .. "|" .. index .. "|" .. tostring(model:GetAttribute("AsuraAnimationSet"))
end

local function stop(model: Model)
	local previous = playing[model]
	if previous and previous.Track then previous.Track:Stop(0.15); previous.Track:Destroy() end
	playing[model] = nil
end

local function play(model: Model, action: string, kind: string?, impact: number?): Rules.Resolved?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local look, phase, sig = signature(model)
	local resolved = Rules.resolve(look, phase, action, kind, rigOf(model, humanoid), function(name) return model:GetAttribute(name) end)
	model:SetAttribute("AsuraAnimationPlaying", resolved.Key .. "|" .. resolved.Source)
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	stop(model)
	if not resolved.Id or not animator then
		model:SetAttribute("AsuraAuthoredMotion", nil)
		playing[model] = { Signature = sig, Key = resolved.Key, Source = resolved.Source, Track = nil }
		return resolved
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = resolved.Id
	local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
	animation:Destroy()
	if not ok then return nil end
	track.Priority = (Enum.AnimationPriority :: any)[resolved.Priority]
	track.Looped = resolved.Looped
	local authored = resolved.Source == "Override" or resolved.Source == "Custom"
	local entry: Playing = { Signature = sig, Key = resolved.Key, Source = resolved.Source, Track = track }
	local contacts = authored and impact and (Rules.Contacts[look] or {})[action]
	if contacts then
		local now = Animations.now()
		local position, speed, hold = Rules.startPlan(contacts[1], impact - now)
		entry.Rate = if hold > 0 then 0 else speed
		track:Play(0.1, 1, entry.Rate * (PlaybackScale.of(model, os.clock())))
		track.TimePosition = position
		entry.Move, entry.Contacts, entry.First, entry.Target, entry.Speed = action, contacts, impact, contacts[1], speed
		entry.HoldUntil = if hold > 0 then now + hold else nil
	else
		entry.Rate = resolved.Speed
		track:Play(0.15, 1, entry.Rate * (PlaybackScale.of(model, os.clock())))
	end
	model:SetAttribute("AsuraAuthoredMotion", if authored then true else nil)
	playing[model] = entry
	return resolved
end
Animations.play = play

-- The one write of a boss track's speed: the rate the contact plan wants, times the scale hitstop and cinematics asked
-- for. The clip time a slowdown costs (its debt) is repaid at MAX_RATE once it lifts, so the next contact is not late.
local function writeRate(model: Model)
	local entry = playing[model]
	local track = entry and entry.Track
	if not entry or not track or not track.IsPlaying then
		return
	end
	local clock = os.clock()
	local dt = math.max(clock - (entry.WrittenAt or clock), 0)
	entry.WrittenAt = clock
	local rate = entry.Rate or 1
	local scale = PlaybackScale.of(model, clock)
	local debt = entry.Debt or 0
	if scale < 1 then
		debt += rate * (1 - scale) * dt
	elseif debt > 0 and rate > 0 then
		local boost = rate * (Timing.MAX_RATE - 1)
		debt = math.max(debt - boost * dt, 0)
		rate += boost
	end
	entry.Debt = debt
	local speed = rate * scale
	if math.abs(track.Speed - speed) > 0.005 then
		track:AdjustSpeed(speed)
	end
end

local function stopGait(gait: Gait)
	if gait.Track then gait.Track:Stop(0.2); gait.Track:Destroy() end
	gait.Track, gait.Action, gait.Id = nil, nil, nil
end

local function syncGait(model: Model, state: string?)
	local root, humanoid = model:FindFirstChild("HumanoidRootPart"), model:FindFirstChildOfClass("Humanoid")
	local look, phase = signature(model)
	if not root or not root:IsA("BasePart") or not humanoid or not Rules.Locomotion[look] then return end
	local gait = gaits[model]
	if not gait then
		gait = { Velocity = Vector3.zero, Rate = 1 }
		gaits[model] = gait
	end
	local clock, at = os.clock(), root.Position
	local dt = clock - (gait.At or clock)
	if gait.Last and dt > 0 then
		local v = (at - gait.Last) / dt
		v = Vector3.new(v.X, 0, v.Z)
		if v.Magnitude < 60 then gait.Velocity = gait.Velocity:Lerp(v, math.clamp(dt * 12, 0, 1)) end -- a teleport is not a gait
	end
	gait.Last, gait.At = at, clock
	local entry = playing[model]
	local busy = reacted[model] ~= nil or (entry ~= nil and entry.Track ~= nil and entry.Track.IsPlaying and not string.find(entry.Key, "_Idle", 1, true))
	if busy then
		if gait.Track then stopGait(gait) end
		return
	end
	local speed = gait.Velocity.Magnitude
	local look3 = root.CFrame.LookVector
	local forward, right = 0, 0
	if speed > 1e-3 then
		local travel = gait.Velocity / speed
		forward, right = travel:Dot(look3), travel:Dot(root.CFrame.RightVector)
	end
	local action, rate = Rules.gait(look, speed, model:GetScale(), forward, right, state, gait.Action, phase)
	local _, yaw = root.CFrame:ToOrientation()
	if gait.Yaw and dt > 0 then
		local turned = (yaw - gait.Yaw + math.pi) % (2 * math.pi) - math.pi
		gait.YawRate = (gait.YawRate or 0) + (turned / dt - (gait.YawRate or 0)) * math.clamp(dt * 12, 0, 1)
	end
	gait.Yaw = yaw
	if not action then -- standing still and being turned: he steps round rather than pivoting on planted feet
		local turning, turnRate = Rules.turning(look, gait.YawRate or 0, gait.Action)
		if turning then action, rate = turning, turnRate end
	end
	if not action then
		if gait.Track then stopGait(gait) end
		return
	end
	local resolved = Rules.resolve(look, phase, action, nil, rigOf(model, humanoid), function(name) return model:GetAttribute(name) end)
	if resolved.Id ~= gait.Id then
		stopGait(gait)
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not resolved.Id or not animator then
			gait.Action = action
			return
		end
		local animation = Instance.new("Animation")
		animation.AnimationId = resolved.Id
		local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
		animation:Destroy()
		if not ok then return end
		track.Priority = Enum.AnimationPriority.Movement
		track.Looped = resolved.Looped
		track:Play(0.2, 1, rate * PlaybackScale.of(model, clock))
		gait.Track, gait.Id, gait.Action, gait.Rate = track, resolved.Id, action, rate
		return
	end
	gait.Action = action
	local track = gait.Track
	if track and track.IsPlaying then
		local want = rate * PlaybackScale.of(model, clock)
		if math.abs(track.Speed - want) > 0.02 then track:AdjustSpeed(want) end
	elseif track and action == "GuardHit" then
		-- the recoil finished; Blockstun holds its last frame until the state moves on
	end
end

local syncFrame: (model: Model, state: string?) -> ()

-- Every frame: see syncFrame, then the one speed write.
function Animations.sync(model: Model, state: string?)
	syncFrame(model, state)
	writeRate(model)
	syncGait(model, state)
end

-- Releases a held windup, returns to speed 1 once a contact passes, answers a cancelling
-- server state (`state`: the actor's replicated fighter state) and otherwise keeps the idle for the
-- current look and phase; a phase change re-resolves (and re-reads overrides).
syncFrame = function(model: Model, state: string?)
	local reaction = state and Rules.Reactions[state]
	if not reaction then
		reacted[model] = nil
	elseif reacted[model] ~= state then
		reacted[model] = state
		if reaction == "HitLightFront" then -- the flinch answers the side the blow came from (AIService: AsuraHitFrom)
			local from = model:GetAttribute("AsuraHitFrom")
			local root = model:FindFirstChild("HumanoidRootPart")
			if typeof(from) == "Vector3" and root and root:IsA("BasePart") then
				local away = root.CFrame:VectorToObjectSpace(from)
				reaction = Rules.hitAction(away.X, -away.Z)
			end
		end
		local resolved = play(model, reaction)
		if not resolved or not resolved.Id then play(model, "Idle") end
		return
	end
	local _, _, sig = signature(model)
	local previous = playing[model]
	local track = previous and previous.Track
	if state == "KO" then -- the fall ends on its last frame; a corpse never goes back to idle
		if previous and track and track.IsPlaying and track.Length > 0 and track.TimePosition >= track.Length - 0.12 then previous.Rate = 0 end
		return
	end
	if previous and track and previous.Move and track.IsPlaying then
		if previous.HoldUntil and Animations.now() >= previous.HoldUntil then
			previous.HoldUntil = nil
			previous.Rate = previous.Speed or 1
		elseif not previous.HoldUntil and previous.Target and track.TimePosition >= previous.Target - 1e-3 then
			previous.Target = nil
			previous.Rate = 1
		end
	end
	if previous and previous.Signature == sig and (track == nil or track.IsPlaying) then return end
	-- the server revealed the new form mid-transition: its own Transform carries on from the shared handoff pose
	local look = signature(model)
	if previous and previous.Signature ~= sig and Rules.RevealContinues[look] and string.sub(previous.Key, -10) == "_Transform" then
		play(model, "Transform")
		return
	end
	play(model, "Idle")
end

-- A telegraphed move (its catalogue id, kind and server impact time) or the phase/oath transform. A
-- cue for the move already playing re-times it toward the contact this impact belongs to.
function Animations.action(model: Model, transform: boolean, move: string?, kind: string?, impact: number?)
	local action = if transform then "Transform" elseif move and move ~= "" then move else "Strike"
	local current = playing[model]
	local track = current and current.Track
	if current and track and track.IsPlaying and current.Move == action and current.Contacts and current.First and type(impact) == "number" then
		local contacts = current.Contacts :: { number }
		local index = Rules.contactFor(contacts, impact - current.First)
		current.First = impact - (contacts[index] - contacts[1])
		local now = Animations.now()
		local position = track.TimePosition
		local speed = Rules.retime(contacts[index], position, impact - now)
		current.Target, current.Speed = if contacts[index] > position then contacts[index] else nil, speed
		if current.HoldUntil then -- still holding the windup: move the release so the contact lands on time
			current.HoldUntil = math.max(now, impact - (contacts[index] - position) / speed)
		else
			current.Rate = speed
			writeRate(model)
		end
		return
	end
	play(model, action, kind, if type(impact) == "number" then impact else nil)
end

-- Drops tracks of actors that have left the world (defeat, reset); called with the boss cues.
function Animations.prune()
	for model, entry in playing do
		if not model.Parent then
			if entry.Track then entry.Track:Destroy() end
			playing[model] = nil
		end
	end
	for model, gait in gaits do
		if not model.Parent then
			stopGait(gait)
			gaits[model] = nil
		end
	end
end
function Animations.clear()
	for model in playing do
		stop(model)
		if model.Parent then model:SetAttribute("AsuraAuthoredMotion", nil) end
	end
	for model, gait in gaits do
		stopGait(gait)
		gaits[model] = nil
	end
end
return Animations
