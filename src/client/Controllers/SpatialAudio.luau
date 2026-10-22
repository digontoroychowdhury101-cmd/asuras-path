--!strict
-- Bounded local voice pool. 3D sources always live on a part/attachment, never a Folder.
-- Every voice is released exactly once, whichever comes first: Ended, the lifetime bound (assets
-- that fail permission checks or never load), voice eviction, destruction of the sound or any
-- ancestor, or shutdown. A release never destroys from inside a Destroying callback: that used
-- to re-enter the source part's own destruction and throw locked-Parent errors.
local SoundService = game:GetService("SoundService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath")
local Assets = require(Shared.Shared.PresentationAssets)
local Audio = {}
local LIFETIME = 12
local voices: {Sound} = {}
local sources: {[Sound]: BasePart} = {} -- positional voice -> the source part it owns
local released: {[Sound]: boolean} = setmetatable({}, {__mode = "k"}) :: any
local zone = "Open"
local rng = Random.new()
-- Keep existing combat cues usable while the new owned masters are awaiting upload.
local FALLBACK: {[string]: string} = {
	Clash="rbxasset://sounds/unsheath.wav", Flesh="rbxasset://sounds/swordslash.wav",
	Blunt="rbxasset://sounds/action_jump_land.mp3", Stone="rbxasset://sounds/action_jump_land.mp3",
}
-- Idempotent. `destroying` = called while `s` or an ancestor is already being destroyed.
local function release(s: Sound, destroying: boolean?)
	if released[s] then return end
	released[s] = true
	local index = table.find(voices, s)
	if index then table.remove(voices, index) end
	local source = sources[s]
	sources[s] = nil
	if destroying then
		-- Finish the source part after the current destruction instead of re-entering it.
		if source then task.defer(function() if source.Parent then source:Destroy() end end) end
	else
		(source or s):Destroy() -- its Destroying callback finds `s` already released
	end
end
function Audio.zone(value: string) zone = value end
function Audio.id(key: string): string
	local folder = SoundService:FindFirstChild("AsuraAudio")
	local template = folder and folder:FindFirstChild(key)
	if template and template:IsA("Sound") and template.SoundId ~= "" then return template.SoundId end
	local owned = (Assets.Audio :: {[string]: string})[key]
	return if owned and owned ~= "" then owned else FALLBACK[key] or ""
end
function Audio.play(key: string, parent: Instance, volume: number?, looped: boolean?, pitch: number?): Sound?
	local id = Audio.id(key)
	if id == "" then return nil end
	for i = #voices, 1, -1 do if voices[i].Parent == nil then release(voices[i]) end end
	if #voices >= Assets.Limits.Voices then
		local victim = nil
		for _, voice in voices do if not voice.Looped then victim = voice; break end end
		if not victim then return nil end
		release(victim)
	end
	local s = Instance.new("Sound")
	s.Name, s.SoundId, s.Volume = "Asura_" .. key, id, math.clamp(volume or 0.6, 0, 1.4)
	s.RollOffMode, s.RollOffMinDistance, s.RollOffMaxDistance = Enum.RollOffMode.InverseTapered, 7, 120
	s.PlaybackSpeed = pitch or (if looped then 1 else rng:NextNumber(0.95, 1.05))
	s.Looped = looped == true
	if zone ~= "Open" and parent ~= SoundService then
		local reverb = Instance.new("ReverbSoundEffect")
		reverb.DecayTime = if zone == "Ravine" then 2.4 else 1.5
		reverb.Density, reverb.Diffusion, reverb.DryLevel, reverb.WetLevel = 0.6, 0.7, 0, -17
		reverb.Parent = s
		local eq = Instance.new("EqualizerSoundEffect")
		eq.LowGain, eq.MidGain, eq.HighGain, eq.Parent = 1.5, -1, -3, s
	end
	s.Parent = parent; table.insert(voices, s)
	s.Destroying:Once(function() release(s, true) end)
	if not s.Looped then
		s.Ended:Once(function() release(s) end)
		task.delay(LIFETIME, release, s)
	end
	s:Play()
	return s
end
-- World-space cue on its own invisible source part; the part lives exactly as long as the voice.
function Audio.at(key: string, position: Vector3, volume: number?, looped: boolean?): Sound?
	if Audio.id(key) == "" then return nil end
	local p = Instance.new("Part")
	p.Name, p.Size, p.Position, p.Transparency = "AsuraAudioSource", Vector3.one * 0.1, position, 1
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Parent = workspace
	local s = Audio.play(key, p, volume, looped)
	if s then sources[s] = p else p:Destroy() end
	return s
end
-- Live counts for diagnostics and regression checks (sources never outnumber voices).
function Audio.stats(): {Voices: number, Sources: number}
	local count = 0
	for _ in sources do count += 1 end
	return { Voices = #voices, Sources = count }
end
function Audio.destroy()
	for i = #voices, 1, -1 do release(voices[i]) end
	table.clear(voices); zone = "Open"
end
return Audio
