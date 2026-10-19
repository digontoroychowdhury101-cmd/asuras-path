--!strict
-- Only owned, uploaded IDs belong here. Empty slots stay silent/disabled; never fake an ID.
-- SoundService.AsuraAudio/<key> Sound templates can override Audio slots in Studio.
local Assets = {}
Assets.Audio = {
	Clash = "", ParryBass = "", Flesh = "", Blunt = "", Stone = "",
	BulletJump = "", Glide = "", Slide = "", Wind = "", Bell = "", Water = "", BossDrone = "",
}
Assets.Textures = {
	Ember = "", Smoke = "", Flame = "", Blood = "", BloodStain = "", Rune = "",
	Shockwave = "", Ribbon = "", Leaf = "", LeafScatter = "", Ash = "",
}
Assets.Sky = { Back = "", Down = "", Front = "", Left = "", Right = "", Up = "" }
Assets.Limits = { Voices = 32, Bursts = 16, Shards = 96, Stains = 20, TrailActors = 24, Scenery = 100 }
return table.freeze(Assets)
