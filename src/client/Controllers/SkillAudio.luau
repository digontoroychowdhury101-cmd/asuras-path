--!strict
-- Sound score for the signature spells. Every cue has its own Assets.Audio slot for its synthesized
-- master (tools/assets/build_skill_audio.py); until that is uploaded, a pitched owned sound stands
-- in. The caster hears the score flat (SoundService); everyone else hears it from the caster's root.
-- Sounds belong to the cast trove, so an interrupted cast falls silent with its visuals.
local SoundService = game:GetService("SoundService")
local Kit = require(script.Parent.SkillKit)
local Audio = require(script.Parent.SpatialAudio)
local Sfx = {}

-- cue = { stand-in key, stand-in pitch, volume }
local CUES: { [string]: { any } } = {
	NovaVoid = { "Wind", 0.7, 0.8 }, NovaRing = { "Bell", 1.6, 0.7 }, NovaSwoop = { "Glide", 1.2, 0.8 },
	NovaPlanet = { "BossDrone", 1.3, 0.8 }, NovaCharge = { "BulletJump", 0.6, 0.9 }, NovaBlast = { "ParryBass", 0.55, 1.2 },
	NovaInk = { "Clash", 1.4, 0.7 }, NovaColumn = { "Wind", 1.5, 1 }, NovaWhite = { "Bell", 0.8, 0.6 },
	SunTension = { "BossDrone", 0.8, 0.8 }, SunBoom = { "ParryBass", 0.9, 1 }, SunEmber = { "Blunt", 1.3, 0.7 },
	SunThorn = { "Clash", 0.7, 0.8 }, SunCharge = { "Glide", 0.7, 0.9 }, SunBlast = { "ParryBass", 0.5, 1.3 },
	SunEyes = { "Slide", 1.4, 0.8 }, SunGauntlet = { "Wind", 1.8, 0.8 }, SunPulse = { "Blunt", 0.8, 0.9 },
}

-- Startup beats are fractions of the windup (a negative beat is seconds before the release, so a
-- riser always lands on the hit); release beats are seconds after the release cue.
local SCORES: { [string]: { [string]: { { any } } } } = {
	Nova = {
		Startup = { { "NovaVoid", 0 }, { "NovaRing", 0.26 }, { "NovaSwoop", 0.34 }, { "NovaPlanet", 0.45 }, { "NovaCharge", -0.75 } },
		Release = { { "NovaBlast", 0 }, { "NovaColumn", 0.22 }, { "NovaInk", 0.36 }, { "NovaInk", 0.47 } },
	},
	Sun = {
		Startup = { { "SunTension", 0 }, { "SunBoom", 0.33 }, { "SunEmber", 0.42 }, { "SunThorn", 0.8 }, { "SunCharge", -0.75 } },
		Release = { { "SunBlast", 0 }, { "SunEyes", 3.55 }, { "SunGauntlet", 5.45 } },
	},
}

function Sfx.play(cast: any, cue: string, volume: number?)
	local spec = CUES[cue]
	if not spec then return end
	local owned = Audio.id(cue) ~= ""
	local root = cast.Entity.Root
	local parent: Instance = if cast.Own or not (root and root.Parent) then SoundService else root
	local s = Audio.play(if owned then cue else spec[1], parent, spec[3] * (volume or 1), false, if owned then 1 else spec[2])
	if s then Kit.add(cast.Trove, s) end
end

function Sfx.score(cast: any, spell: string, phase: string)
	for _, beat in SCORES[spell][phase] do
		local at = beat[2]
		if phase == "Startup" then at = if at < 0 then cast.Windup + at else cast.Windup * at end
		if at >= 0 then Kit.after(cast.Trove, at, function() Sfx.play(cast, beat[1]) end) end
	end
end

return table.freeze(Sfx)
