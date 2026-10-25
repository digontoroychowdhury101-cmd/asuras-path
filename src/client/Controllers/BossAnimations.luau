--!strict
-- Client playback for the shared boss animation contract (BossAnimationRules, F10): every boss
-- actor resolves its own look, phase and attack to an authored override/custom track or a stock
-- stand-in. A creature with nothing authored keeps CreatureMotion's procedural pose; when an
-- authored track plays on it, AsuraAuthoredMotion (local to this client) makes CreatureMotion
-- release its welds so the two never transform the same joints. Cosmetic only.
local Rules = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.BossAnimationRules)
local Animations = {}
type Playing = { Signature: string, Key: string, Source: string, Track: AnimationTrack? }
local playing: { [Model]: Playing } = {}

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

local function play(model: Model, action: string, kind: string?): Rules.Resolved?
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
	track:Play(0.15, 1, resolved.Speed)
	model:SetAttribute("AsuraAuthoredMotion", if resolved.Source == "Override" or resolved.Source == "Custom" then true else nil)
	playing[model] = { Signature = sig, Key = resolved.Key, Source = resolved.Source, Track = track }
	return resolved
end
Animations.play = play

-- Keeps the idle for the current look and phase; a phase change re-resolves (and re-reads overrides).
function Animations.sync(model: Model)
	local _, _, sig = signature(model)
	local previous = playing[model]
	if previous and previous.Signature == sig and (previous.Track == nil or previous.Track.IsPlaying) then return end
	play(model, "Idle")
end

-- A telegraphed move (its catalogue id and kind) or the phase/oath transform.
function Animations.action(model: Model, transform: boolean, move: string?, kind: string?)
	play(model, if transform then "Transform" elseif move and move ~= "" then move else "Strike", kind)
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
