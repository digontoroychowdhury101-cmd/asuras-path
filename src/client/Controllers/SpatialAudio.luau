--!strict
-- Bounded local voice pool. 3D sources always live on a part/attachment, never a Folder.
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local Shared = game:GetService("ReplicatedStorage").AsurasPath
local Assets = require(Shared.Shared.PresentationAssets)
local Audio = {}
local voices: {Sound} = {}
local zone = "Open"
local rng = Random.new()
function Audio.zone(value: string) zone = value end
function Audio.id(key: string): string
	local folder = SoundService:FindFirstChild("AsuraAudio")
	local template = folder and folder:FindFirstChild(key)
	if template and template:IsA("Sound") and template.SoundId ~= "" then return template.SoundId end
	return (Assets.Audio :: {[string]: string})[key] or ""
end
function Audio.play(key: string, parent: Instance, volume: number?, looped: boolean?, pitch: number?): Sound?
	local id = Audio.id(key)
	if id == "" then return nil end
	for i = #voices, 1, -1 do if voices[i].Parent == nil then table.remove(voices, i) end end
	if #voices >= Assets.Limits.Voices then
		local victim = table.remove(voices, 1); victim:Destroy()
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
	if not s.Looped then
		s.Ended:Once(function() s:Destroy() end)
		Debris:AddItem(s, 12) -- also bounds assets that fail permission checks or never load
	end
	s:Play()
	return s
end
function Audio.at(key: string, position: Vector3, volume: number?): Sound?
	if Audio.id(key) == "" then return nil end
	local p = Instance.new("Part")
	p.Name, p.Size, p.Position, p.Transparency = "AsuraAudioSource", Vector3.one * 0.1, position, 1
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Parent = workspace; Debris:AddItem(p, 12)
	local s = Audio.play(key, p, volume)
	if s then s.Ended:Once(function() p:Destroy() end) else p:Destroy() end
	return s
end
function Audio.destroy()
	for _, s in voices do s:Destroy() end
	table.clear(voices); zone = "Open"
end
return Audio
