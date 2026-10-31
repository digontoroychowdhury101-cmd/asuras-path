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
local Animations = {}
type Playing = { Signature: string, Key: string, Source: string, Track: AnimationTrack?, Move: string?, Contacts: { number }?,
	First: number?, Target: number?, Speed: number?, HoldUntil: number? }
local playing: { [Model]: Playing } = {}
local reacted: { [Model]: string } = {}

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
		track:Play(0.1, 1, if hold > 0 then 0 else speed)
		track.TimePosition = position
		entry.Move, entry.Contacts, entry.First, entry.Target, entry.Speed = action, contacts, impact, contacts[1], speed
		entry.HoldUntil = if hold > 0 then now + hold else nil
	else
		track:Play(0.15, 1, resolved.Speed)
	end
	model:SetAttribute("AsuraAuthoredMotion", if authored then true else nil)
	playing[model] = entry
	return resolved
end
Animations.play = play

-- Every frame: releases a held windup, returns to speed 1 once a contact passes, answers a cancelling
-- server state (`state`: the actor's replicated fighter state) and otherwise keeps the idle for the
-- current look and phase; a phase change re-resolves (and re-reads overrides).
function Animations.sync(model: Model, state: string?)
	local reaction = state and Rules.Reactions[state]
	if not reaction then
		reacted[model] = nil
	elseif reacted[model] ~= state then
		reacted[model] = state
		local resolved = play(model, reaction)
		if not resolved or not resolved.Id then play(model, "Idle") end
		return
	end
	local _, _, sig = signature(model)
	local previous = playing[model]
	local track = previous and previous.Track
	if previous and track and previous.Move and track.IsPlaying then
		if previous.HoldUntil and Animations.now() >= previous.HoldUntil then
			previous.HoldUntil = nil
			track:AdjustSpeed(previous.Speed or 1)
		elseif not previous.HoldUntil and previous.Target and track.TimePosition >= previous.Target - 1e-3 then
			previous.Target = nil
			track:AdjustSpeed(1)
		end
	end
	if previous and previous.Signature == sig and (track == nil or track.IsPlaying) then return end
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
			track:AdjustSpeed(speed)
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
end
function Animations.clear()
	for model in playing do
		stop(model)
		if model.Parent then model:SetAttribute("AsuraAuthoredMotion", nil) end
	end
end
return Animations
