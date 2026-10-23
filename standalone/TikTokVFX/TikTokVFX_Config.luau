--!strict
-- ModuleScript: ReplicatedStorage/TikTokVFX_Config
-- Standalone port of Asura's Path's showcase sorceries (Celestial Supernova, Blazing Sun Awakening)
-- for any Roblox experience. Shared by TikTokVFX_Server and TikTokVFX_Client: tune everything here.
local Config = {}

Config.RemoteName = "TikTokVFX_Remote"
Config.ReplicateRange = 220 -- clients farther than this from the caster build nothing

Config.Palette = {
	Teal = Color3.fromRGB(0, 255, 255),
	DeepTeal = Color3.fromRGB(36, 177, 174),
	Gold = Color3.fromRGB(255, 170, 0),
	Cyan = Color3.fromRGB(0, 230, 230),
	White = Color3.fromRGB(255, 255, 255),
	Void = Color3.fromRGB(8, 12, 18),
	CoreFlash = Color3.fromRGB(251, 252, 29),
	Flame = Color3.fromRGB(255, 69, 0),
	Coal = Color3.fromRGB(225, 112, 81),
	Amber = Color3.fromRGB(200, 162, 106),
	Heat = Color3.fromRGB(255, 106, 0),
	Plasma = Color3.fromRGB(255, 245, 157),
	Ink = Color3.fromRGB(15, 2, 2),
}

-- Particle textures. Empty strings fall back to Roblox's built-in particle sprite.
Config.Textures = {
	Flame = "rbxasset://textures/particles/fire_main.dds",
	Ember = "rbxasset://textures/particles/sparkles_main.dds",
}

export type Skill = {
	Name: string, Key: Enum.KeyCode, Cooldown: number, Windup: number, Lock: number,
	Radius: number, Damage: number, Pulses: number, PulseDelay: number, Burn: number,
	Animation: string, -- optional rbxassetid:// of a cast animation; "" plays none
}

Config.Skills = {
	-- Skill 1: levitate, planetary orb + orbital rings, implosion, sky pillar, whiteout.
	Supernova = {
		Name = "Celestial Supernova", Key = Enum.KeyCode.Q, Cooldown = 12,
		Windup = 5.0, -- seconds before the pillar erupts (reference: 5.0 s)
		Lock = 4.0, -- seconds after release the caster stays rooted
		Radius = 12, Damage = 30, Pulses = 2, PulseDelay = 2.5, Burn = 0, Animation = "",
	},
	-- Skill 2: stance clench, manga impact frame, fire shockwave, blazing eyes, flame gauntlets.
	BlazingSun = {
		Name = "Blazing Sun Awakening", Key = Enum.KeyCode.E, Cooldown = 10,
		Windup = 2.5, -- seconds before the impact frame (reference: 2.5 s)
		Lock = 2.0,
		Radius = 14, Damage = 18, Pulses = 3, PulseDelay = 1.5, Burn = 3, Animation = "", -- burn: damage per second for 3 s
	},
} :: { [string]: Skill }

Config.Supernova = {
	Rise = 10, -- studs of levitation
	OrbAt = 1.8 / 5.0, -- fractions of the windup (reference timeline 0-5 s)
	ImplodeAt = 4.2 / 5.0,
	OrbSize = 6,
	Rings = { { Radius = 6.5, Color = "Gold", Tilt = { 28, 0, 8 }, Spin = 1 }, { Radius = 7.6, Color = "Cyan", Tilt = { -22, 0, -34 }, Spin = -1 } },
	RingSegments = 28,
	Voxels = 14,
	PillarDiameter = 24,
	PillarHeight = 120,
	WhiteoutFade = 0.6,
}

Config.BlazingSun = {
	StanceFov = 52,
	StanceDutch = 6,
	EyeAt = 0.7, -- seconds after the impact frame that the eyes ignite (reference: 3.2 s)
	EyeShot = 1.3, -- seconds of the macro eye shot (reference: 3.2 - 4.5 s)
	Gauntlets = 5.5, -- seconds the flame gauntlets burn after release
}

-- Trauma camera shake: shake = trauma ^ power, decaying by `decay` per second.
Config.Shake = { MaxAngle = math.rad(4.5), Frequency = 17 }

-- Comfort: set false to skip scripted camera shots or calm the screen flashes.
Config.CameraShots = true
Config.FlashScale = 1

return table.freeze(Config)
