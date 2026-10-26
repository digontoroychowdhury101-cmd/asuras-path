--!strict
-- Only owned, uploaded IDs belong here. Missing textures stay disabled; never fake an ID.
-- SoundService.AsuraAudio/<key> Sound templates can override Audio slots in Studio.
local Assets = {}
Assets.Audio = {
	-- CC0 physical impacts via Godot demos; uploaded and typed-preloaded 2/2 on 2026-10-26.
	GithubLightImpact = "rbxassetid://84168306022631", GithubHeavyImpact = "rbxassetid://75064735099891",
	-- CC0 Superpowers pack: whooshes are active; the remaining cues are an audition library.
	GithubWhooshLight = "rbxassetid://110795098552792", GithubWhooshHeavy = "rbxassetid://128390103310574",
	GithubSwordHeavy = "rbxassetid://134923760317969", GithubSwordLight = "rbxassetid://90713694021705", GithubSecret = "rbxassetid://101518165997871",
	GithubMagic = "rbxassetid://111038929226449", GithubMonsterGrowl = "rbxassetid://111778581433967",
	Clash = "rbxassetid://112256493525265", ParryBass = "rbxassetid://132244224106707", Flesh = "rbxassetid://135539914951495", Blunt = "rbxassetid://96420173928383", Stone = "rbxassetid://99727362444008",
	BulletJump = "rbxassetid://100694818881612", Glide = "rbxassetid://120377372310702", Slide = "rbxassetid://96988662266744", Wind = "rbxassetid://122450130719273", Bell = "rbxassetid://123385330740698", Water = "rbxassetid://113213311649809", BossDrone = "rbxassetid://123393717022210",
	-- Signature-spell score (tools/assets/build_skill_audio.py, uploaded 2026-10-24); SkillAudio pitches owned stand-ins if a slot is blank.
	NovaVoid = "rbxassetid://129359188549606", NovaRing = "rbxassetid://134564910653256", NovaSwoop = "rbxassetid://110060527562569", NovaPlanet = "rbxassetid://70380265927325", NovaCharge = "rbxassetid://112033209229095", NovaBlast = "rbxassetid://133807813064998", NovaInk = "rbxassetid://131991190965773", NovaColumn = "rbxassetid://107313082560233", NovaWhite = "rbxassetid://96092388966263",
	SunTension = "rbxassetid://100202591727169", SunBoom = "rbxassetid://75096821018311", SunEmber = "rbxassetid://86447083540632", SunThorn = "rbxassetid://81636168021067", SunCharge = "rbxassetid://105215829186624", SunBlast = "rbxassetid://136996507247009", SunEyes = "rbxassetid://116302876643156", SunGauntlet = "rbxassetid://109867440300434", SunPulse = "rbxassetid://103546737552644",
}
Assets.Textures = {
	-- CC0 Effekseer samples; uploaded and typed-preloaded 6/6 on 2026-10-26 (assets/GITHUB_UPLOADED.json).
	GithubThunder = "rbxassetid://91094113748034", GithubWind = "rbxassetid://138369746472175", GithubSpark = "rbxassetid://130696775636258",
	GithubThunderHorizontal = "rbxassetid://90786029633700",
	GithubShockwave = "rbxassetid://113620265045402", GithubSmoke = "rbxassetid://106136904847136", GithubFlame = "rbxassetid://91726489235085",
	Ember = "rbxassetid://71210522377346", Smoke = "rbxassetid://118836433841190", Flame = "rbxassetid://109612319904107", Blood = "rbxassetid://130551791057565", BloodStain = "rbxassetid://127759159077031", Rune = "rbxassetid://122602029003354",
	Shockwave = "rbxassetid://83732553901476", Ribbon = "rbxassetid://103002669230055", Leaf = "rbxassetid://79417774806659", LeafScatter = "rbxassetid://85184122225102", CrimsonBranch = "rbxassetid://133941376172785", Ash = "rbxassetid://84748845356339",
}
Assets.Sky = { Back = "rbxassetid://87628549041414", Down = "rbxassetid://103952866093370", Front = "rbxassetid://77637140898450", Left = "rbxassetid://83782412023406", Right = "rbxassetid://126646523881532", Up = "rbxassetid://94728124992475" }
-- Golden-hour Shrine sky (tools/assets/make_sunset_sky.py; assignment verified in Studio, assets/LOBBY_SKY_UPLOADED.json).
Assets.SunsetSky = { Front = "rbxassetid://108067720936233", Back = "rbxassetid://91892434596631", Left = "rbxassetid://132527418910759", Right = "rbxassetid://135495662234371", Up = "rbxassetid://111642714464286", Down = "rbxassetid://118353493252474" }
Assets.Limits = { Voices = 32, Bursts = 16, Shards = 96, Stains = 20, TrailActors = 24, Scenery = 100 }
return table.freeze(Assets)
