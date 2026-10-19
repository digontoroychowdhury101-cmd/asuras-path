--!strict
-- Engine-free contracts shared by authored encounters, the server and verification.
export type AttackKind = "PerilousSweep" | "PerilousThrust" | "PerilousGrab" | "Shockwave" | "Barrage" | "Gravity" | "Ritual" | "Leap" | "Breath" | "Tail" | "ShieldCharge"
export type Motion = "Pillar" | "Aerial" | "Lunge" | "Teleport"
export type Attack = {
	Id: string, Kind: AttackKind, Windup: number, Radius: number, Damage: number, Posture: number,
	Height: number?, Speed: number?, Repeats: number?, Interval: number?, Duration: number?,
	Count: number?, Motion: Motion?, Element: string?, Unblockable: boolean?,
}
export type GapCloser = { Range: number, Delay: number, Cooldown: number, Motion: Motion }
return table.freeze({})
