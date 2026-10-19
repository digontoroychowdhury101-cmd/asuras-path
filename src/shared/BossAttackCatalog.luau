--!strict
type AttackKind = "PerilousSweep" | "PerilousThrust" | "PerilousGrab" | "Shockwave" | "Barrage" | "Gravity" | "Ritual" | "Leap" | "Breath" | "Tail" | "ShieldCharge"
type Motion = "Pillar" | "Aerial" | "Lunge" | "Teleport"
type BossAttack = {
	Id: string, Kind: AttackKind, Windup: number, Radius: number, Damage: number, Posture: number,
	Height: number?, Speed: number?, Repeats: number?, Interval: number?, Duration: number?,
	Count: number?, Motion: Motion?, Element: string?, Unblockable: boolean?,
}
type GapCloser = { Range: number, Delay: number, Cooldown: number, Motion: Motion }
local function move(id: string, kind: AttackKind, radius: number, damage: number, windup: number, options: { [string]: any }?): BossAttack
	local result: any = { Id = id, Kind = kind, Radius = radius, Damage = damage, Posture = damage * 1.6, Windup = windup, Unblockable = kind ~= "Barrage" and kind ~= "ShieldCharge" }
	for key, value in options or {} do result[key] = value end
	return result :: BossAttack
end
local Catalog = {
	Shen = {
		move("FlowingJian", "PerilousThrust", 18, 15, 0.8, { Repeats = 4, Interval = 0.65, Motion = "Lunge" }),
		move("PrayerBeads", "Barrage", 90, 12, 1.1, { Count = 7, Speed = 34 }),
		move("AbbotSweep", "PerilousSweep", 16, 24, 1),
	},
	Chimera = {
		move("BloodWave", "Shockwave", 90, 30, 1.1, { Speed = 38, Height = 7, Element = "Blood" }),
		move("GuandaoSkyfall", "Leap", 28, 35, 1.5, { Motion = "Aerial", Speed = 45 }),
		move("CrimsonEmbrace", "PerilousGrab", 12, 40, 1.2),
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
