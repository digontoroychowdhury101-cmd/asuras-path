--!strict
-- Run with work/bin/luau/luau tools/test_weapons_and_spells.luau (no Roblox runtime required).
local Weapons=require("../src/simulation/WeaponSchema")
local Spells=require("../src/simulation/SpellSchema")
local Magic=require("../src/simulation/SpellRules")
local Combat=require("../src/simulation/CombatRules")
local Inventory=require("../src/simulation/ArsenalInventory")
local Catalog=require("../src/shared/ArsenalCatalog")
local Protocol=require("../src/shared/ArsenalProtocol")
local World=require("../src/shared/WorldDefinitions")
local Store=require("../src/server/ProfileStore")
local Profiles=require("../src/shared/ProfileSchema")
local function near(a: number,b: number): boolean return math.abs(a-b)<1e-6 end
local checks=0
local function check(ok: boolean,message: string)
 checks+=1;assert(ok,message)
end
check(#Weapons.WeaponTypes==9 and #Weapons.WeaponKeys==12,"All families and boss weapons")
for _,key in Weapons.WeaponKeys do
 local w=Weapons.get(key);Weapons.validateWeapon(w)
 check(#w.Light>=3 and w.Light[#w.Light].ComboWindow==0,"Valid combo: "..key)
 for id,m in w.Moves do
  Weapons.validateMove(m,key)
  check(m.Timing.StartupSeconds>0 and m.Timing.ActiveSeconds>0 and m.Timing.RecoverySeconds>0,"Positive timing: "..id)
  check(m.Reach>0 and m.BaseDamage>=0 and m.PostureDamage>=0,"Valid spatial/damage: "..id)
 end
 local f=Combat.new(1,key :: any,0)
 check(assert(Combat.unpack(Combat.pack(f,0))).Weapon==key,"Boss/family packet round-trip: "..key)
end
check(Weapons.get("Odachi").Heavy.HyperArmor,"Odachi armor")
check(Weapons.get("TwinDaggers").CriticalMultiplier==3,"Sai critical multiplier")
check(Weapons.get("ChainScythe").Heavy.Effect=="Pull","Snare move")
check(Weapons.get("WarFan").ProjectileParry==true,"Fan defensive stance")
local ordinary=Weapons.deflectOutcome(Weapons.get("Jian").Heavy,Weapons.get("Jian"),Weapons.get("ChainScythe"))
local cursed=Weapons.deflectOutcome(Weapons.get("Jian").Heavy,Weapons.get("Jian"),Weapons.get("PrayerOfTheDefiled"))
check(near(cursed.AttackerPosture-ordinary.AttackerPosture,Weapons.get("Jian").Heavy.PostureDamage*0.25),"Censer reflects another 25% posture")
local invalidMove=table.clone(Weapons.get("Odachi").Heavy);invalidMove.Startup=0
check(not pcall(Weapons.validateMove,invalidMove,"Invalid"),"Reject invalid weapon timing")
for _,id in Spells.Order do
 local s=Spells.ById[id];Spells.validate(s)
 local payload=Magic.payload(id,1.25)
 check(near(payload.Damage,s.Damage*1.25) and payload.Root==s.Status.Root,"Validated payload: "..id)
end
local invalidSpell=table.clone(Spells.ById.GaleStep);invalidSpell.QiCost=-1
check(not pcall(Spells.validate,invalidSpell),"Reject invalid Qi cost")
local expected: {[string]: {number}}={ThunderclapPalm={18,8},HeavenlyLightningSpear={28,80},DragonsMaw={24,20},EmberCataclysm={40,45},
 BlackflameSurge={30,28},GraveTendrils={26,32},JadeAegis={35,0},GaleStep={20,18}}
for id,n in expected do
 local s=assert(Spells.get(id));Spells.validate(s)
 check(s.QiCost==n[1] and s.Range==n[2],"Cost/range: "..id)
 local f=Combat.new(1,"Jian",0);local cd: {[string]: number}={}
 local cast=assert(Magic.begin(f,id,0,cd,nil))
 check(near(f.Qi,100-s.QiCost) and cd[id]==s.Cooldown,"Authoritative cost/cooldown: "..id)
 check(cast.Release>0 and cast.End>cast.Release and Magic.valid(f,cast),"Cast window: "..id)
 f.State="Hitstun";check(not Magic.valid(f,cast),"Interrupted: "..id)
 f.State="Idle";local denied=Magic.begin(f,id,0,cd,nil);check(denied==nil,"Cooldown enforced: "..id)
end
check(Magic.payload("BlackflameSurge",1).IgnoreGuard,"Void ignores guard")
check(Magic.payload("ThunderclapPalm",1).Interrupt,"Palm interrupts armor")
check(Magic.payload("DragonsMaw",1).Burn==1 and Spells.ById.EmberCataclysm.Pulses==3,"Burn stacks and delayed pillars")
check(Spells.ById.HeavenlyLightningSpear.Pierces and Spells.ById.HeavenlyLightningSpear.Speed==160,"Piercing projectile")
local root=Combat.new(2,"Odachi",0);root.State="Startup";Magic.status(root,"ThunderclapPalm",1)
check(root.State=="Hitstun" and root.Move==nil,"Hyper-armor interruption")
Magic.status(root,"GraveTendrils",2);check(root.RootUntil==4,"Two second root")
check(Combat.tryDash(root,"Dash",3,0,1,nil)==nil,"Root prevents dash escape")
local ward=Combat.new(3,"Jian",0);Magic.ward(ward,0)
check(Combat.applyDamage(ward,1000,"Heavy",1)==0 and ward.ActiveHP==100 and ward.WardUntil==0,"One lethal hit absorbed")
Magic.ward(ward,1);check(not Combat.addPosture(ward,1000,2,nil,1) and ward.WardUntil==0,"One posture break absorbed")
check(Combat.applyDamage(ward,10,"Light",3)>0,"Ward consumed")
local f=Combat.new(1,"Jian",0);f.Qi=0;Combat.step(f,1,1,nil);check(near(f.Qi,2),"Passive Qi: 2/sec")
local striker=Combat.new(1,"Jian",0);striker.Qi=0
local victim=Combat.new(2,"Jian",0);assert(Combat.tryAttack(striker,"Light",0))
striker.State="Active";Combat.resolveHit(striker,victim,0.2,{Facing=true,Region="Torso"},nil)
check(striker.Qi==8,"Melee hit refills 8 Qi")
striker=Combat.new(1,"Jian",0);victim=Combat.new(2,"PrayerOfTheDefiled",0);victim.Qi=0
assert(Combat.tryAttack(striker,"Light",0));striker.State="Active";assert(Combat.tryDeflect(victim,0.2,0.2))
check(Combat.resolveHit(striker,victim,0.2,{Facing=true,Region="Torso"},nil)=="Deflected" and victim.Qi==15,"Perfect deflect refills 15")
local focus=Combat.new(1,"Jian",0);local cd: {[string]: number}={}
local fast=assert(Magic.begin(focus,"HeavenlyLightningSpear",0,cd,"Catalyst"))
check(fast.Potency==1.25 and fast.Release<Spells.timing(Spells.ById.HeavenlyLightningSpear).Startup,"Offhand potency and quick cast")
focus.State="Idle";focus.Qi=0;check(Magic.begin(focus,"GaleStep",100,{},nil)==nil,"Insufficient Qi")
for id,r in Catalog.Recipes do
 local i: any=Inventory.defaults();i.weapons={Unarmed=true}
 Inventory.award(i,if r.Boss=="DemonicChimera" then "GrandmasterShen" else r.Boss)
 local token=i.remembrances[r.Boss]
 check(token~=nil and table.isfrozen(token),"Immutable remembrance: "..id)
 check(Inventory.forge(i,id),"Forge reward: "..id)
 check(i.spentRemembrances[r.Boss] and i.remembrances[r.Boss]==token,"Consume right, preserve token")
 check((if r.Kind=="Weapon" then i.weapons else i.spells)[r.Reward],"Grant reward")
 check(not Inventory.forge(i,id),"No duplicate forge")
 Inventory.award(i,if r.Boss=="DemonicChimera" then "GrandmasterShen" else r.Boss)
 check(not Inventory.forge(i,id),"Repeated victory cannot renew token")
end
local i: any=Inventory.defaults();i.weapons={Unarmed=true}
for id,c in Catalog.Caches do
 check(Inventory.claim(i,id),"Discover cache")
 check(i.weapons[c.Weapon] and not Inventory.claim(i,id),"One-time cache unlock")
 check(World.regionAt(c.X,c.Y,c.Z)==c.Region,"Cache inside authored region")
end
check(Inventory.validate(Inventory.migrate(i)),"Arsenal migration")
check(not Inventory.validate({}),"Reject corrupt inventory")
check(Protocol.valid({action="Cast",slot=1}) and not Protocol.valid({action="Cast",slot=3}),"Slot validation")
check(not Protocol.valid({action="Cast",slot=1,damage=999}) and not Protocol.valid({action="Forge",id="../hack"}),"Reject forged payloads")
-- Real transactional persistence: one of two competing recipes consumes the same remembrance.
local data: {[string]: any}={}
local db={UpdateAsync=function(_self: any,key: string,fn: (any)->any): any
 local updated=fn(Store.Copy(data[key]));if updated then data[key]=Store.Copy(updated) end;return Store.Copy(updated)
end}
local store=Store.new(db,Profiles,{owner="arsenal-test",now=function() return 1000 end,wait=function() end,attempts=1,leaseSeconds=180})
assert(store:Load(42));assert(store:RecordBossDefeat(42,"GrandmasterShen",4000))
check(store:Transaction(42,function(p: any) assert(Inventory.forge(p.souls.inventory,"PrayerOfTheDefiled")) end),"Atomic forge commit")
local saved=store:Souls(42)
check(saved.inventory.weapons.PrayerOfTheDefiled and saved.inventory.remembrances.DemonicChimera~=nil,"Persist rewards and Chimera phase token")
check(not store:Transaction(42,function(p: any) assert(Inventory.forge(p.souls.inventory,"AbbotDirge")) end),"Competing recipe rejected")
check(not store:Souls(42).inventory.spells.AbbotDirge,"Failed forge grants nothing")
check(Store.ValidateSouls(store:Souls(42)),"Stored inventory validates")
local corrupt=Store.Copy(store:Souls(42));corrupt.inventory.spentRemembrances.GrandmasterShen="bad"
check(not pcall(Store.MigrateSouls,corrupt),"Corrupt consumed-token ledger cannot be reset")
for bossId in World.Bosses do
 local tokens: any=Inventory.defaults();Inventory.award(tokens,bossId)
 check(next(tokens.remembrances)~=nil,"Every major boss awards a remembrance: "..bossId)
end
assert(store:Release(42));local reloaded=assert(store:Load(42))
check(reloaded.souls.inventory.spentRemembrances.GrandmasterShen and reloaded.souls.inventory.weapons.PrayerOfTheDefiled,"Save/rejoin preserves consumed token")
local showcase: any=Inventory.defaults();showcase.weapons={Unarmed=true}
check(Inventory.claim(showcase,"SanctuaryEaves") and showcase.spells.CelestialSupernova,"Loggia Eaves grants Celestial Supernova")
check(Inventory.claim(showcase,"SanctuaryReliquary") and showcase.spells.BlazingSunAwakening,"Cloud Reliquary grants Blazing Sun Awakening")
local early=Inventory.migrate({spells={JadeAegis=true},caches={SanctuaryEaves=true,SanctuaryReliquary=true}})
check(early.spells.CelestialSupernova and early.spells.BlazingSunAwakening and Inventory.validate(early),"Caches claimed before the update grant the new spells")
check(Spells.ById.CelestialSupernova.Shape=="Column" and Spells.ById.BlazingSunAwakening.Pulses==3,"Showcase spell shapes")
print("Phase 2 weapons and spells: "..checks.." checks passed")
