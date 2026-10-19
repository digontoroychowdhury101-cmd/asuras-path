--!strict
local Catalog = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.AnimationCatalog)
local Animations = {}
type Playing = { Set: string, Track: AnimationTrack? }
local playing: { [Model]: Playing } = {}
local function play(model: Model, key: string, action: boolean, speed: number?)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not humanoid or not animator then return end
	local previous = playing[model]
	if previous and previous.Track then previous.Track:Stop(0.15); previous.Track:Destroy() end
	local entry = Catalog.enemy(key :: any)
	local custom = model:GetAttribute("AsuraBossAnimation_" .. key)
	local animation = Instance.new("Animation")
	animation.AnimationId = if type(custom) == "string" then custom else Catalog.resolve(entry, if humanoid.RigType == Enum.HumanoidRigType.R6 then "R6" else "R15")
	local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
	animation:Destroy()
	if not ok then return end
	track.Priority = if action then Enum.AnimationPriority.Action4 else Enum.AnimationPriority.Idle
	track.Looped = not action
	track:Play(0.15, 1, speed or Catalog.speed(entry))
	playing[model] = { Set = tostring(model:GetAttribute("AsuraAnimationSet")), Track = track }
end
function Animations.sync(model: Model)
	local set = tostring(model:GetAttribute("AsuraAnimationSet"))
	local previous = playing[model]
	if previous and previous.Set == set and previous.Track and previous.Track.IsPlaying then return end
	play(model, "Shen_Phase1_Idle", false, if set == "DemonicChimera" then 1.4 else 1)
end
function Animations.action(model: Model, transform: boolean)
	local set = tostring(model:GetAttribute("AsuraAnimationSet"))
	play(model, if transform then "Shen_Phase2_Transform" elseif set == "DemonicChimera" or set == "Unbound" then "Shen_Phase2_GlaiveCombo" else "Shen_Phase1_SwordCombo", true)
end
function Animations.clear()
	for model, entry in playing do
		if entry.Track then entry.Track:Stop(); entry.Track:Destroy() end
		playing[model] = nil
	end
end
return Animations
