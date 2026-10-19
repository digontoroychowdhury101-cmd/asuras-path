--!strict
-- Authored SoundService.BossMusic_<bossId> tracks override the built-in rhythmic placeholder.
local SoundService = game:GetService("SoundService")
local Audio = require(script.Parent.SpatialAudio)
local Music = {}
export type Score = { Intensity: number, Beat: number, Track: Sound?, Connection: RBXScriptConnection? }
function Music.new(): Score
	return { Intensity = 0, Beat = 0, Track = nil, Connection = nil }
end
function Music.stop(score: Score)
	score.Intensity = 0
	if score.Track then score.Track:Stop(); score.Track:Destroy(); score.Track = nil end
	if score.Connection then score.Connection:Disconnect(); score.Connection = nil end
	SoundService:SetAttribute("AsuraBossMusicIntensity", 0)
	SoundService:SetAttribute("AsuraBossMusic", nil)
end
function Music.set(score: Score, bossId: string, intensity: number)
	if score.Intensity == 0 then
		local authored = SoundService:FindFirstChild("BossMusic_" .. bossId)
		if authored and authored:IsA("Sound") then
			score.Track = authored:Clone(); score.Track.Parent = SoundService; score.Track.Looped = true; score.Track:Play()
		else
			score.Track = Audio.play("BossDrone", SoundService, 0.28, true)
		end
	end
	score.Intensity = intensity
	if score.Track then score.Track.PlaybackSpeed = 1 + (intensity - 1) * 0.12 end
	SoundService:SetAttribute("AsuraBossMusic", bossId)
	SoundService:SetAttribute("AsuraBossMusicIntensity", intensity)
end
return Music
