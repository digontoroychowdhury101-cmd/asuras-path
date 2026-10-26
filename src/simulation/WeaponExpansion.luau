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
-- Boss-only arms (never in WeaponKeys, profiles, drops or the Arsenal). Post-F26 step 6 (D1): the Iron
-- Bull fights with a one-handed iron maul and a tower shield instead of borrowing the guandao. Reach is
-- from the root (not scaled with the 1.7 body); arcs follow the motion: hook sweep, narrow shield ram,
-- vertical anvil drop, shield-up crush, shield-first rush, front-only bell-breaker. Slow finishers carry
-- long recoveries, and nothing covers the back.
local function strike(id: string, name: string, kind: string, index: number, t: {number}, dmg: number, posture: number, reach: number, arc: number, lunge: number, extra: {[string]: any}?): any
 local m = { Id=id, Name=name, Kind=kind, ComboIndex=index, Startup=t[1], Active=t[2], Recovery=t[3], ComboWindow=t[4], CancelFrom=t[5],
  BaseDamage=dmg, PostureDamage=posture, Bleed=0.1, DeflectVulnerability=if kind=="Light" then 0.7 else 0.9, Deflectable=true, Unblockable=false,
  HyperArmor=kind=="Heavy" or kind=="WeaponArt", StaminaCost=if kind=="Light" then 4 elseif kind=="WeaponArt" then 12 else 10, QiCost=if kind=="WeaponArt" then 40 else 0,
  Reach=reach, Arc=arc, Lunge=lunge, DamageType="Blunt", Trauma={Head=0.04,Torso=0.08,Arms=0.03,Legs=0.02}, Animation="IronBull."..string.gsub(name," ","") }
 for k,v in extra or {} do m[k]=v end
 return m
end
function Expansion.bossSpecs(): {any}
 local maul={Id="IronBullMaul",Type="Odachi",Name="Iron Bull's Maul and Tower Shield",Grip="OneHanded",Reach=10,Weight=7,DeflectEfficiency=0.9,
  GuardChip=0.25,BleedMultiplier=0.4,PostureMultiplier=1.4,BlockPostureResistance=1.5,MoveSpeedMultiplier=0.85,Stance="Iron Rampart",WeightClass="Colossal",
  Light={
   strike("IronBullMaul_L1","Iron Hook","Light",1,{18,5,24,10,12},15,20,9.5,100,1.5),
   strike("IronBullMaul_L2","Shield Ram","Light",2,{14,5,22,10,12},8,26,7.0,36,3.0),
   strike("IronBullMaul_L3","Anvil Drop","Light",3,{26,6,42,0,20},22,30,10.0,24,2.5),
  },
  Heavy=strike("IronBullMaul_Heavy","Ox-Yoke Crush","Heavy",0,{44,7,50,0,30},32,46,10.5,70,2.0),
  RunningAttack=strike("IronBullMaul_Running","Rampart Rush","RunningAttack",0,{24,7,36,0,24},16,34,8.0,40,7.0,{StaminaCost=8}),
  WeaponArt=strike("IronBullMaul_Art","Bell-Breaker","WeaponArt",0,{36,10,52,0,40},30,50,9.5,200,1.0)}
 maul.Light[3].StaminaCost=4
 return {maul}
end
return table.freeze(Expansion)
