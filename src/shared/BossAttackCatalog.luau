--!strict
type AttackKind = "PerilousSweep" | "PerilousThrust" | "PerilousCut" | "PerilousGrab" | "Shockwave" | "Barrage" | "Gravity" | "Ritual" | "Leap" | "Breath" | "Tail" | "ShieldCharge"
type Motion = "Pillar" | "Aerial" | "Lunge" | "Teleport"
type BossAttack = {
	Id: string, Kind: AttackKind, Windup: number, Radius: number, Damage: number, Posture: number,
	Height: number?, Speed: number?, Repeats: number?, Interval: number?, Duration: number?,
	Count: number?, Pulses: { number }?, Arc: number?, Motion: Motion?, Element: string?, Unblockable: boolean?, DisplayName: string?, Fan: boolean?, Rise: number?,
}
type GapCloser = { Range: number, Delay: number, Cooldown: number, Motion: Motion }
local function move(id: string, kind: AttackKind, radius: number, damage: number, windup: number, options: { [string]: any }?): BossAttack
	local result: any = { Id = id, Kind = kind, Radius = radius, Damage = damage, Posture = damage * 1.6, Windup = windup, Unblockable = kind ~= "Barrage" and kind ~= "ShieldCharge" }
	for key, value in options or {} do result[key] = value end
	return result :: BossAttack
end
local Catalog = {
	Shen = {
		-- The id FlowingJian stays stable for clips, tests and saves; four curved cuts of the guandao, each one deflected.
		move("FlowingJian", "PerilousCut", 18, 15, 0.8, { Repeats = 4, Interval = 0.65, Arc = 150, Motion = "Lunge", DisplayName = "Flowing Glaive" }),
		-- Parry timing is the point of these two: the blade hangs too long, and the second cut comes early.
		move("HesitantMoon", "PerilousCut", 14, 20, 1.3, { Arc = 140, Motion = "Lunge", DisplayName = "Hesitant Moon" }),
		move("WheelOfHeaven", "PerilousCut", 14, 16, 1.35, { Pulses = { 0, 0.38 }, Arc = 170, DisplayName = "Wheel of Heaven" }),
		move("PrayerBeads", "Barrage", 90, 12, 1.1, { Count = 7, Speed = 34, Fan = true, Rise = 5, DisplayName = "Prayer Beads" }),
		move("AbbotSweep", "PerilousSweep", 16, 24, 1, { DisplayName = "Abbot's Sweep" }),
	},
	Chimera = {
		move("BloodWave", "Shockwave", 90, 30, 1.1, { Speed = 38, Height = 7, Element = "Blood", DisplayName = "Blood Wave" }),
		move("GuandaoSkyfall", "Leap", 28, 35, 1.5, { Motion = "Aerial", Speed = 45, DisplayName = "Guandao Skyfall" }),
		-- The lunge brings the visible claw to the server's 12 stud reach; nothing ever attaches to a player.
		move("CrimsonEmbrace", "PerilousGrab", 12, 40, 1.2, { Motion = "Lunge", DisplayName = "Crimson Embrace" }),
		move("RendingArc", "PerilousCut", 14, 20, 0.9, { Pulses = { 0, 0.42, 1.05 }, Arc = 160, DisplayName = "Rending Arc" }),
		move("PhantomDrift", "PerilousCut", 15, 26, 1, { Arc = 150, Motion = "Lunge", DisplayName = "Phantom Drift" }),
	},
	Baize = {
		move("MeteorPounce", "Leap", 100, 32, 2.1, { Motion = "Pillar", Speed = 32, Height = 9, Duration = 2.6, Element = "Frost" }),
		move("FeralClaws", "PerilousSweep", 18, 23, 0.9),
		move("RidgeMaw", "PerilousGrab", 13, 38, 1.15),
	},
	Titan = {
		move("WorldTremor", "Shockwave", 240, 34, 1.5, { Repeats = 2, Interval = 1.15, Speed = 30, Height = 11, Element = "Earth" }),
		move("CryptHand", "PerilousGrab", 22, 48, 1.6),
		move("MagmaWake", "Ritual", 135, 25, 2, { Duration = 4, Height = 9, Element = "Magma" }),
	},
	Wu = {
		move("SoulSpears", "Barrage", 140, 19, 1.25, { Count = 5, Speed = 26, Element = "Void" }),
		move("StarlessSingularity", "Gravity", 32, 18, 1.8, { Duration = 4, Height = 10, Element = "Void" }),
		move("BloodflameRitual", "Ritual", 130, 27, 2.5, { Duration = 3.5, Height = 9, Element = "Bloodflame" }),
	},
	Zhao = {
		move("LightningSpear", "PerilousThrust", 30, 24, 0.8, { Motion = "Lunge", Repeats = 3, Interval = 0.7, Element = "Lightning" }),
		move("ThunderQuickstep", "ShieldCharge", 35, 26, 1, { Motion = "Lunge" }),
	},
	Bull = {
		move("IronCharge", "ShieldCharge", 50, 35, 1.5, { Motion = "Lunge", Element = "Iron" }),
		move("ColossalHammer", "Shockwave", 65, 34, 1.8, { Speed = 26, Height = 7, Element = "Iron" }),
	},
	Wyrm = {
		move("HeavenlyBreathRun", "Breath", 140, 36, 2, { Motion = "Aerial", Duration = 3, Height = 10, Element = "Thunder" }),
		move("AzureTail", "Tail", 28, 32, 1.15),
		move("DescendingThunder", "Leap", 110, 42, 1.8, { Motion = "Aerial", Speed = 42, Height = 9, Element = "Thunder" }),
	},
}
return Catalog
