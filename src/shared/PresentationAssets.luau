--!strict
-- Only owned, uploaded IDs belong here. Missing textures stay disabled; never fake an ID.
-- SoundService.AsuraAudio/<key> Sound templates can override Audio slots in Studio.
local Assets = {}
Assets.Audio = {
	Clash = "rbxassetid://112256493525265", ParryBass = "rbxassetid://132244224106707", Flesh = "rbxassetid://135539914951495", Blunt = "rbxassetid://96420173928383", Stone = "rbxassetid://99727362444008",
	BulletJump = "rbxassetid://100694818881612", Glide = "rbxassetid://120377372310702", Slide = "rbxassetid://96988662266744", Wind = "rbxassetid://122450130719273", Bell = "rbxassetid://123385330740698", Water = "rbxassetid://113213311649809", BossDrone = "rbxassetid://123393717022210",
}
Assets.Textures = {
	Ember = "rbxassetid://71210522377346", Smoke = "rbxassetid://118836433841190", Flame = "rbxassetid://109612319904107", Blood = "rbxassetid://130551791057565", BloodStain = "rbxassetid://127759159077031", Rune = "rbxassetid://122602029003354",
	Shockwave = "rbxassetid://83732553901476", Ribbon = "rbxassetid://103002669230055", Leaf = "rbxassetid://79417774806659", LeafScatter = "rbxassetid://85184122225102", CrimsonBranch = "rbxassetid://133941376172785", Ash = "rbxassetid://84748845356339",
}
Assets.Sky = { Back = "rbxassetid://87628549041414", Down = "rbxassetid://103952866093370", Front = "rbxassetid://77637140898450", Left = "rbxassetid://83782412023406", Right = "rbxassetid://126646523881532", Up = "rbxassetid://94728124992475" }
-- Golden-hour Shrine sky (tools/assets/make_sunset_sky.py; assignment verified in Studio, assets/LOBBY_SKY_UPLOADED.json).
Assets.SunsetSky = { Front = "rbxassetid://108067720936233", Back = "rbxassetid://91892434596631", Left = "rbxassetid://132527418910759", Right = "rbxassetid://135495662234371", Up = "rbxassetid://74428004859056", Down = "rbxassetid://134298860757348" }
Assets.Limits = { Voices = 32, Bursts = 16, Shards = 96, Stains = 20, TrailActors = 24, Scenery = 100 }
return table.freeze(Assets)
