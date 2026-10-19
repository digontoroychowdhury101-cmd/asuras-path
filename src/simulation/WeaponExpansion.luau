--!strict
-- Compact authored families; every generated move passes WeaponSchema's normal validator.
local Expansion = {}
local function move(id: string, name: string, kind: string, index: number, reach: number, speed: number, damage: number, posture: number): any
 local heavy = kind ~= "Light"
 return { Id=id, Name=name, Kind=kind, ComboIndex=index, Startup=if heavy then 30+speed else 9+speed,
  Active=if heavy then 7 else 4, Recovery=if heavy then 32+speed else 16+speed, ComboWindow=0, CancelFrom=10,
  BaseDamage=damage, PostureDamage=posture, Bleed=0.2, DeflectVulnerability=if heavy then 0.85 else 0.6,
  Deflectable=true, Unblockable=false, HyperArmor=false, StaminaCost=if heavy then 10 else 4, QiCost=if kind=="WeaponArt" then 30 else 0,
  Reach=reach, Arc=if heavy then 140 else 85, Lunge=2, DamageType="Slash", Trauma={Head=0.02,Torso=0.04,Arms=0.02,Legs=0.01}, Animation=id }
end
local function family(id: string, name: string, grip: string, reach: number, weight: number, speed: number, names: {string}): any
 local lights = {}
 for i, title in names do
  local m=move(id.."_L"..i,title,"Light",i,reach,speed,6+weight+i,8+weight*2+i)
  m.ComboWindow=if i<#names then 8 else 0
  table.insert(lights,m)
 end
 return {Id=id,Type=id,Name=name,Grip=grip,Reach=reach,Weight=weight,DeflectEfficiency=1,GuardChip=0.1,BleedMultiplier=1,
  PostureMultiplier=1,BlockPostureResistance=1,MoveSpeedMultiplier=1,Light=lights,
  Heavy=move(id.."_Heavy","Crushing Overhead","Heavy",0,reach,speed,18+weight,28+weight*3),
  RunningAttack=move(id.."_Running","Pursuing Cut","RunningAttack",0,reach,speed,12+weight,18+weight),
  WeaponArt=move(id.."_Art","Qi Release","WeaponArt",0,reach,speed,20+weight,32+weight*2),
  Stance="Balanced",WeightClass="Medium",CriticalMultiplier=1.5,SpellPotency=1,QuickCast=false,ProjectileParry=false,PostureReflect=0}
end
function Expansion.specs(): {any}
 local odachi=family("Odachi","Colossal Odachi","TwoHanded",13,5,12,{"Mountain Sweep","Iron Horizon","Earthshatter"})
 odachi.Stance="Immovable Mountain";odachi.WeightClass="Colossal";odachi.MoveSpeedMultiplier=0.8;odachi.PostureMultiplier=1.35
 for _,m in odachi.Light do m.HyperArmor=true end
 odachi.Heavy.HyperArmor=true;odachi.Heavy.Name="Ground-Shattering Overhead";odachi.WeaponArt.HyperArmor=true
 local daggers=family("TwinDaggers","Twin Shadow Sai","TwoHanded",5,0.5,-4,{"Shadow Fang","Twin Flurry","Rising Talon","Falling Sai"})
 daggers.Stance="Airborne Shadow";daggers.WeightClass="Light";daggers.CriticalMultiplier=3;daggers.MoveSpeedMultiplier=1.08
 daggers.Heavy.Name="Airborne Launch";daggers.Heavy.Effect="Launch";daggers.WeaponArt.Name="Nightfall Flurry"
 local chain=family("ChainScythe","Chain Scythe","TwoHanded",15,2.5,1,{"Reaping Arc","Weighted Crescent","Chain Reversal"})
 chain.Stance="Coiling Serpent";chain.Heavy.Name="Distant Snare";chain.Heavy.Effect="Pull";chain.WeaponArt.Name="Reaper's Orbit";chain.WeaponArt.Arc=360
 local fan=family("WarFan","Iron Tessen","OneHanded",6,0.8,-2,{"Silken Edge","Gale Turn","Wind-Cutting Finisher"})
 fan.Stance="Wind Ward";fan.WeightClass="Light";fan.ProjectileParry=true;fan.DeflectEfficiency=1.5
 fan.Light[3].Effect="WindSlash";fan.WeaponArt.Effect="WindSlash";fan.WeaponArt.Name="Tempest Ward"
 local staff=family("Catalyst","Jade Spell Staff","OneHanded",8,1,-1,{"Jade Tap","Seal Sweep","Spirit Thrust"})
 staff.Stance="Quick Seal";staff.WeightClass="Light";staff.SpellPotency=1.25;staff.QuickCast=true;staff.WeaponArt.Name="Resonant Seal"
 local censer=family("PrayerOfTheDefiled","Prayer of the Defiled","TwoHanded",12,3,4,{"Censer Toll","Black Incense","Funeral Procession"})
 censer.Type="ChainScythe";censer.Stance="Abbot's Vigil";censer.PostureReflect=0.25
 censer.WeaponArt.Name="Abbot's Dirge";censer.WeaponArt.Effect="AbbotDirge";censer.WeaponArt.QiCost=35
 local cleaver=family("CalamityBoneCleaver","Calamity Bone Cleaver","TwoHanded",13,5,12,{"Serrated Sweep","Chimera's Bite","Calamity Fall"})
 cleaver.Type="Odachi";cleaver.Stance="Chimera";cleaver.WeightClass="Colossal";cleaver.Heavy.HyperArmor=true
 cleaver.WeaponArt.Name="Fissure Slam";cleaver.WeaponArt.Effect="FissureSlam";cleaver.WeaponArt.HyperArmor=true;cleaver.WeaponArt.QiCost=40
 local lightning=family("HeavenPiercingGuandao","Heaven-Piercing Lightning Guandao","TwoHanded",14,3,3,{"Ashen Crescent","Storm Coil","Heaven Piercer"})
 lightning.Type="Guandao";lightning.Stance="Thunder General";lightning.WeaponArt.Name="Thunderfall";lightning.WeaponArt.Effect="Thunderfall";lightning.WeaponArt.QiCost=45
 return {odachi,daggers,chain,fan,staff,censer,cleaver,lightning}
end
return table.freeze(Expansion)
