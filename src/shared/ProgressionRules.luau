--!strict
-- Engine-free progression math shared by persistence, combat, menus and tests.
local Rules = {}
local INFUSIONS: {[string]: string}={CrimsonFire="CrimsonFireGem", CelestialLightning="CelestialLightningGem", AbyssalVoid="AbyssalVoidGem"}
Rules.Attributes = table.freeze({"Vigor", "Endurance", "Strength", "Dexterity", "ArcaneQi"})
Rules.Infusions = table.freeze(INFUSIONS)
function Rules.level(a: {[string]: number}): number
 local n=1;for _,key in Rules.Attributes do n+=a[key]-10 end;return n
end
function Rules.levelCost(n: number): number return math.floor(150*math.max(1,n)^1.4) end
local function cap(n: number,early: number,mid: number,late: number): number
 local p=math.max(0,n-10);return math.min(p,30)*early+math.clamp(p-30,0,20)*mid+math.max(0,p-50)*late
end
function Rules.stats(a: {[string]: number},tier: number): {[string]: number}
 local forge=1+0.1*tier
 return {HPBonus=cap(a.Vigor,6,3,1), StaminaBonus=cap(a.Endurance,2.5,1.2,0.4),
  PostureBonus=cap(a.Endurance,1.5,0.8,0.3), MaxQi=100+cap(a.ArcaneQi,3,1.5,0.5),
  RallyScale=1+cap(a.Vigor,0.015,0.0075,0.0025), SpellScale=1+cap(a.ArcaneQi,0.025,0.0125,0.004),
  StrengthScale=(1+cap(a.Strength,0.018,0.009,0.003))*forge,
  DexterityScale=(1+cap(a.Dexterity,0.018,0.009,0.003))*forge}
end
function Rules.upgradeCost(tier: number): (number,string,number)
 local material=if tier<4 then "SpiritIronOre" elseif tier<8 then "StarfallShard" else "DragoniteCore"
 return math.floor(250*(tier+1)^1.5),material,if tier<4 then tier+1 elseif tier<8 then tier-3 else tier-7
end
function Rules.upgrade(p: any,weapon: string): string
 local w=assert(p.inventory.Weapons[weapon],"Weapon is locked");assert(w.Level<10,"Weapon is already +10")
 local cost,ore,count=Rules.upgradeCost(w.Level)
 assert(p.qiEssence>=cost,"Not enough Essence");assert((p.inventory.Materials[ore] or 0)>=count,"Missing "..ore)
 p.qiEssence-=cost;p.inventory.Materials[ore]-=count;w.Level+=1
 return "Reinforced "..weapon.." +"..w.Level
end
function Rules.infuse(p: any,weapon: string,affinity: string): string
 local gem=assert(Rules.Infusions[affinity],"Unknown infusion")
 local w=assert(p.inventory.Weapons[weapon],"Weapon is locked");assert(w.Infusion~=affinity,"Already infused")
 assert((p.inventory.Materials[gem] or 0)>=1,"Missing "..gem);assert(p.qiEssence>=300,"Not enough Essence")
 p.inventory.Materials[gem]-=1;p.qiEssence-=300;w.Infusion=affinity;return "Infused "..weapon
end
function Rules.affinity(id: string?,a: {[string]: number}): {[string]: number}
 return {Burn=if id=="CrimsonFire" then 2*(1+(a.Strength-10)*0.025) else 0,
  Stun=if id=="CelestialLightning" then 5*(1+(a.Dexterity-10)*0.025) else 0,
  GuardPierce=if id=="AbyssalVoid" then 0.3 else 0,
  VoidScale=if id=="AbyssalVoid" then 1+(a.ArcaneQi-10)*0.01 else 1}
end
function Rules.masteryRank(xp: number): number
 local rank=1;for index,threshold in {0,100,300,700,1500} do if xp>=threshold then rank=index end end;return rank
end
function Rules.discover(p: any,id: string,reward: number): boolean
 if p.inventory.LoreEntries[id] then return false end
 p.inventory.LoreEntries[id]=true;p.qiEssence+=reward;return true
end
function Rules.mastery(p: any,weapon: string,xp: number)
 if not p.inventory.Weapons[weapon] then return end
 p.weaponMastery[weapon]=math.min(9007199254740991,(p.weaponMastery[weapon] or 0)+xp)
end
return table.freeze(Rules)
