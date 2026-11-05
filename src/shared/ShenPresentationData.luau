--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/ShenPresentationData
-- Grandmaster Shen's cosmetic data: the named sound manifest, the effect palette per phase and the tier rules. Pure, so tests read it. Nothing here
-- decides damage; every time below is relative to the server's impact (or the BossPhase cue, for the transition).
-- Sounds: Key is the original layer tools/assets/build_shen_audio.py authors (assets/build/shen_audio/<Key>.wav). Until that upload exists, Audio.id(Key) is
-- empty and StandIn, an id the project already owns (PresentationAssets.Audio), plays instead. No id here is invented.
local Data = {}

export type Sfx = { Key: string, StandIn: string, Attach: string, Onset: number, Loop: boolean, Stop: string, Volume: number, Pitch: number, Rolloff: number, Priority: number }
local function sfx(key: string, standIn: string, attach: string, onset: number, volume: number, pitch: number, rolloff: number, priority: number, stop: string?): Sfx
	return { Key = key, StandIn = standIn, Attach = attach, Onset = onset, Loop = false, Stop = stop or "cancel", Volume = volume, Pitch = pitch, Rolloff = rolloff, Priority = priority }
end

-- event -> layers. Attach: BladeTip | BeadHand | ChestCore | Root. Priority 1 drops first on the low tier; 3 always plays (it carries a warning).
Data.Sfx = table.freeze({
	FlowingJian_Thrust = { sfx("ShenSteelAir", "GithubWhooshLight", "BladeTip", -0.2, 0.62, 1.0, 110, 3) },
	FlowingJian_Contact = { sfx("ShenBronzeContact", "GithubSwordLight", "BladeTip", 0, 0.5, 1.0, 110, 2, "ring") },
	PrayerBeads_Gather = { sfx("ShenBeadClick", "GithubSecret", "BeadHand", -0.95, 0.42, 1.0, 80, 2), sfx("ShenBeadClick", "GithubSecret", "BeadHand", -0.6, 0.42, 1.12, 80, 1),
		sfx("ShenBeadClick", "GithubSecret", "BeadHand", -0.32, 0.46, 1.24, 80, 1), sfx("ShenTensionRise", "NovaCharge", "BeadHand", -1.0, 0.36, 1.0, 100, 3) },
	PrayerBeads_Launch = { sfx("ShenBeadLaunch", "GithubWhooshHeavy", "BeadHand", 0, 0.62, 1.15, 130, 3, "ring"), sfx("ShenJadeChime", "Bell", "BeadHand", 0, 0.2, 1.5, 90, 1, "ring") },
	PrayerBeads_Impact = { sfx("ShenBeadClick", "Clash", "Root", 0, 0.42, 1.3, 90, 2, "ring") },
	AbbotSweep = { sfx("ShenClothRustle", "Wind", "ChestCore", -0.72, 0.3, 1.0, 70, 1), sfx("ShenLowSweep", "GithubWhooshHeavy", "BladeTip", -0.16, 0.72, 0.82, 130, 3), sfx("ShenBronzeContact", "GithubSwordHeavy", "BladeTip", 0.02, 0.48, 0.9, 110, 2, "ring") },
	BloodWave_Windup = { sfx("ShenScrape", "Stone", "BladeTip", -0.8, 0.52, 0.8, 110, 2), sfx("ShenGrowlExhale", "GithubMonsterGrowl", "ChestCore", -0.5, 0.58, 0.85, 130, 3) },
	BloodWave_Release = { sfx("ShenBowedMetal", "NovaVoid", "Root", 0, 0.72, 0.8, 190, 3, "ring") },
	GuandaoSkyfall_Rise = { sfx("ShenAirTear", "GithubWind", "Root", -1.1, 0.55, 1.0, 170, 3) },
	GuandaoSkyfall_Land = { sfx("ShenLandImpact", "Blunt", "Root", 0, 0.95, 0.72, 200, 3, "ring"), sfx("ShenBowedMetal", "NovaVoid", "Root", 0.02, 0.4, 0.7, 170, 1, "ring") },
	CrimsonEmbrace = { sfx("ShenBreathIntake", "Wind", "ChestCore", -0.95, 0.5, 0.7, 90, 2), sfx("ShenGrowlExhale", "GithubMonsterGrowl", "BeadHand", -0.1, 0.5, 1.1, 120, 3) },
	Melee_P1 = { sfx("ShenSteelAir", "GithubWhooshLight", "BladeTip", -0.12, 0.5, 1.0, 100, 2) },
	Melee_P2 = { sfx("ShenSteelAir", "GithubWhooshHeavy", "BladeTip", -0.12, 0.55, 0.82, 110, 2) },
	-- the transition, relative to the BossPhase cue (the 2.4 s Duration, Reveal 0.9)
	Transition_Falter = { sfx("ShenClothRustle", "Wind", "ChestCore", 0, 0.42, 0.9, 110, 1), sfx("ShenFalter", "GithubMonsterGrowl", "ChestCore", 0.1, 0.32, 1.2, 120, 2) },
	Transition_Inhale = { sfx("ShenBreathIntake", "Wind", "ChestCore", 0.4, 0.6, 0.6, 150, 3) },
	Transition_Roar = { sfx("ShenRoar", "GithubMonsterGrowl", "ChestCore", 0.9, 1.0, 0.72, 240, 3, "ring"), sfx("ShenBowedMetal", "NovaVoid", "Root", 0.9, 0.42, 0.62, 200, 1, "ring") },
} :: { [string]: { Sfx } })

-- Effect colours: restrained jade and steel for the master, dark crimson for the corrupted form.
Data.Palette = table.freeze({
	[1] = { EdgeA = Color3.fromRGB(226, 234, 232), EdgeB = Color3.fromRGB(110, 148, 138), Dust = Color3.fromRGB(148, 136, 118) },
	[2] = { EdgeA = Color3.fromRGB(238, 44, 40), EdgeB = Color3.fromRGB(86, 6, 14), Dust = Color3.fromRGB(66, 44, 40) },
})
Data.Jade = Color3.fromRGB(116, 196, 158)
Data.Wood = Color3.fromRGB(58, 34, 22)
Data.Cloth = table.freeze({ Color3.fromRGB(40, 48, 96), Color3.fromRGB(218, 208, 182), Color3.fromRGB(190, 158, 92) })

-- A window around the server's impact in which the blade trail draws (open before, close after).
Data.Trails = table.freeze({
	FlowingJian = { Open = -0.13, Close = 0.12, Width = 0.13, Fade = 0.5 },
	AbbotSweep = { Open = -0.14, Close = 0.3, Width = 0.2, Fade = 0.45 },
	Cut = { Open = -0.14, Close = 0.2, Width = 0.17, Fade = 0.45 },
	BloodWave = { Open = -0.3, Close = 0.2, Width = 0.34, Fade = 0.3 },
	GuandaoSkyfall = { Open = -0.3, Close = 0.08, Width = 0.34, Fade = 0.3 },
	Melee = { Open = -0.1, Close = 0.14, Width = 0.15, Fade = 0.45 },
} :: { [string]: { Open: number, Close: number, Width: number, Fade: number } })

-- Density by tier. Warnings never depend on this: the telegraph ring and the wave's leading edge exist on every tier.
Data.Tiers = table.freeze({
	Low = { WaveSegments = 16, WaveLayers = 1, Shards = 4, Debris = 0, Shreds = 4, BeadTrails = false, Dust = 0.35, Grit = false },
	Mid = { WaveSegments = 28, WaveLayers = 2, Shards = 8, Debris = 5, Shreds = 8, BeadTrails = true, Dust = 0.7, Grit = true },
	High = { WaveSegments = 40, WaveLayers = 2, Shards = 12, Debris = 10, Shreds = 12, BeadTrails = true, Dust = 1, Grit = true },
})

-- savedQuality: 0 automatic, 1-10 the graphics slider. Reduced effects always takes the lowest density.
function Data.tier(savedQuality: number, reduced: boolean): string
	if reduced or (savedQuality >= 1 and savedQuality <= 3) then return "Low" end
	return if savedQuality == 0 or savedQuality <= 7 then "Mid" else "High"
end

-- How far the wave's leading edge has run at server time `now`: the same arithmetic as BossEncounterRules.waveHit.
function Data.waveRadius(now: number, start: number, speed: number, radius: number): number
	return math.clamp((now - start) * speed, 0, radius)
end

-- A cancelling fighter state ends any windup or trail he owns, as BossAttackService.step cancels the attack.
Data.Cancels = table.freeze({ StanceBroken = true, GuardBroken = true, Hitstun = true, DeathblowVictim = true, KO = true } :: { [string]: boolean })

Data.Limits = table.freeze({ Beads = 7, BeadTtlPad = 1.6, Shreds = 12, ShredLife = 1.3 })

return table.freeze(Data)
