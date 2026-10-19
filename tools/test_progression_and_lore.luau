--!strict
local Schema=require("../src/shared/ProfileSchema")
local Store=require("../src/server/ProfileStore")
local Progress=require("../src/shared/ProgressionRules")
local Dialogue=require("../src/shared/DialogueRules")
local Catalog=require("../src/shared/NarrativeCatalog")
local Arena=require("../src/shared/ArenaRules")
local World=require("../src/shared/WorldDefinitions")
local Combat=require("../src/simulation/CombatRules")
local Spells=require("../src/simulation/SpellRules")
local checks=0
local function check(ok: boolean,message: string)
 assert(ok,message);checks+=1
end
local function near(a: number,b: number): boolean return math.abs(a-b)<0.00001 end
local raw: any={schemaVersion=3,fightCash=270,elo=1460,wins=9,losses=2,winStreak=3,
 receipts={purchase=42},appliedMatches={match=true},pendingMatches={},souls={version=2,essence=730,
 attributes={Vitality=22,Qi=18,Strength=25,Dexterity=16},inventory={weapons={Unarmed=true,Jian=true,Guandao=true},mainhand="Guandao",offhand="Unarmed",reinforcement={Guandao=4}},
 world={bosses={GrandmasterShen=true},altars={Altar_BambooPass=true},activeAltar="Altar_BambooPass"}}}
local p=Schema.Migrate(raw,7)
check(p.schemaVersion==4 and p.qiEssence==1000,"legacy currencies merge once")
check((p :: any).fightCash==nil,"boxing currency removed")
check(p.attributes.Vigor==22 and p.attributes.Endurance==18 and p.attributes.ArcaneQi==10,"attribute mapping")
check(p.inventory.Weapons.Guandao.Level==4 and p.equippedLoadout.MainWeapon=="Guandao","forged loadout preserved")
check(p.colosseum.Elo==1460 and p.colosseum.Rank=="Sword Saint" and p.colosseum.Wins==9,"rank migration")
check(p.defeatedBosses.GrandmasterShen and p.unlockedAltars.Altar_BambooPass,"world flags preserved")
check(p.receipts.purchase==42 and p.appliedMatches.match,"durable receipts preserved")
check(Schema.Validate(p),"migrated profile validates")
local again=Schema.Migrate(p,7)
check(again.qiEssence==1000,"migration is idempotent")
again.attributes.Vigor=40;again.inventory.Weapons.Guandao.Level=6
check(raw.souls.attributes.Vitality==22 and p.attributes.Vigor==22 and p.inventory.Weapons.Guandao.Level==4,"migration has no table aliases")
check(not pcall(Schema.Migrate,{schemaVersion=5},7),"future schema fails closed")
for _,n in {1,2,10,75,446} do check(Progress.levelCost(n)==math.floor(150*n^1.4),"cost formula") end
local a={Vigor=10,Endurance=10,Strength=10,Dexterity=10,ArcaneQi=10}
local base=Progress.stats(a,0)
for _,key in Progress.Attributes do
 local view=table.clone(a);view[key]+=1;local stats=Progress.stats(view,0)
 if key=="Vigor" then check(stats.HPBonus==6 and stats.RallyScale>base.RallyScale,"vigor scaling")
 elseif key=="Endurance" then check(stats.StaminaBonus==2.5 and stats.PostureBonus==1.5,"endurance scaling")
 elseif key=="ArcaneQi" then check(stats.MaxQi==103 and stats.SpellScale>1,"arcane scaling")
 else check(stats[key.."Scale"]>1,"weapon scaling") end
end
local forge: any=Schema.Default(8);forge.qiEssence=1000000
forge.inventory.Materials={SpiritIronOre=100,StarfallShard=100,DragoniteCore=100,CrimsonFireGem=1,CelestialLightningGem=1,AbyssalVoidGem=1}
for tier=0,9 do
 local cost,material,count=Progress.upgradeCost(tier);local qi=forge.qiEssence;local ore=forge.inventory.Materials[material]
 Progress.upgrade(forge,"Jian")
 check(forge.inventory.Weapons.Jian.Level==tier+1 and forge.qiEssence==qi-cost and forge.inventory.Materials[material]==ore-count,"upgrade consumes exact resources")
 check(near(Progress.stats(a,tier+1).StrengthScale,1+0.1*(tier+1)),"ten percent reinforcement")
end
check(not pcall(Progress.upgrade,forge,"Jian"),"+10 cap")
for _,affinity in {"CrimsonFire","CelestialLightning","AbyssalVoid"} do
 Progress.infuse(forge,"Jian",affinity);check(forge.inventory.Weapons.Jian.Infusion==affinity,"infusion persisted")
 check(not pcall(Progress.infuse,forge,"Jian",affinity),"duplicate infusion refused")
end
check(Progress.affinity("AbyssalVoid",a).GuardPierce==0.3,"void guard pierce")
local strong=table.clone(a);strong.Strength=30;strong.Dexterity=30;strong.ArcaneQi=30
check(Progress.affinity("CrimsonFire",strong).Burn>Progress.affinity("CrimsonFire",a).Burn,"fire strength scaling")
check(Progress.affinity("CelestialLightning",strong).Stun>Progress.affinity("CelestialLightning",a).Stun,"lightning dexterity scaling")
check(Progress.affinity("AbyssalVoid",strong).VoidScale>1,"void arcane scaling")
for id,npc in Catalog.NPCs do
 for node,n in npc.Nodes do for index,c in n.Choices do
  local nextNode=Dialogue.choose(id,node,index)
  check(nextNode~=nil and (c.Close or Dialogue.node(id,nextNode.Next)~=nil),"dialogue links resolve")
 end end
 check(Dialogue.node(id,npc.Start)~=nil,"NPC entry point")
end
check(Dialogue.choose("Gao","Greeting",99)==nil,"invalid choice refused")
check(not Dialogue.valid({action="Level",id="Vigor",revision=0/0}),"nonfinite revision refused")
check(not Dialogue.valid({action="Upgrade",revision=1,qi=999}),"client grant field refused")
local loreCount=0
for id,l in Catalog.Lore do
 loreCount+=1;local qi=forge.qiEssence
 check(World.contains(World.Regions[l.Region].Bounds,l.X,l.Y,l.Z),"lore inside declared region")
 check(Progress.discover(forge,id,l.Qi) and forge.qiEssence==qi+l.Qi,"first read rewards Qi")
 check(not Progress.discover(forge,id,l.Qi) and forge.qiEssence==qi+l.Qi,"repeat read cannot duplicate reward")
end
check(loreCount==8,"eight memorials")
Progress.mastery(forge,"Jian",1499);check(Progress.masteryRank(forge.weaponMastery.Jian)==4,"finisher remains locked")
Progress.mastery(forge,"Jian",1);check(Progress.masteryRank(forge.weaponMastery.Jian)==5,"rank five finisher")
local db: {[string]: any}={};local now=1000
local engine=Store.new({UpdateAsync=function(_: any,key: string,fn: (any)->any): any
 local v=fn(Store.Copy(db[key]));if v then db[key]=Store.Copy(v) end;return Store.Copy(v)
end},Schema,{owner="Test",now=function() return now end,wait=function() end,attempts=2,leaseSeconds=180})
db.Player_7=raw;check(engine:Load(7)~=nil,"legacy store loads")
check(engine:Souls(7).essence==1000 and engine:Souls(7).attributes.Vigor==22,"runtime view matches canonical data")
check(engine:Transaction(7,function(profile: any) profile.qiEssence+=111 end),"canonical transaction")
check(engine:Souls(7).essence==1111,"canonical currency mirrors world")
check(engine:GrantEssence(7,89),"legacy runtime grant")
check(engine:Get(7).qiEssence==1200,"world grant mirrors canonical currency")
check(engine:RecordDeath(7,"BambooPass",1,3,-1400,100),"death writes stain")
check(engine:Get(7).qiEssence==0 and engine:Souls(7).world.bloodstain.essence==1300,"all Qi dropped")
check(engine:RecordDeath(7,"BambooPass",2,3,-1400,0),"second death overwrites stain")
check(engine:Souls(7).world.bloodstain==nil,"zero-Qi second death destroys prior pool")
check(engine:Transaction(7,function(profile: any) profile.qiEssence=500000;profile.inventory.Materials.SpiritIronOre=20 end),"fund progression")
check(engine:LevelAttribute(7,"ArcaneQi"),"runtime attribute level")
check(engine:Get(7).attributes.ArcaneQi==11,"runtime attribute mirrors canonical")
check(engine:ReinforceWeapon(7,"Jian"),"runtime forge")
check(engine:Get(7).inventory.Weapons.Jian.Level==1,"runtime forge mirrors canonical")
local fighter=Combat.new(1,"Jian",0);Combat.applyStats(fighter,{MaxQi=150,SpellScale=1.5,RallyScale=1.4},true)
fighter.Qi=150;local cast=Spells.begin(fighter,"ThunderclapPalm",1,{},"Unarmed")
check(cast~=nil and cast.Potency==1.5,"arcane scales actual spell casts")
-- Verify the actual combat resolver applies affinities and mastery, including defense timing.
local function strike(affinity: string?)
 local attacker=Combat.new(10,"Jian",0);local victim=Combat.new(11,"Jian",0)
 local stats=Progress.affinity(affinity,a)
 Combat.applyStats(attacker,{InfusionBurn=stats.Burn,InfusionStun=stats.Stun,GuardPierce=stats.GuardPierce,VoidScale=stats.VoidScale})
 assert(Combat.tryAttack(attacker,"Light",0))
 attacker.State="Active"
 return attacker,victim
end
local fire,target=strike("CrimsonFire")
Combat.resolveHit(fire,target,1,{Facing=true,Region="Torso"},{})
local health=target.ActiveHP;Combat.step(target,1.5,0.5,{})
check(target.BurnSource==10 and target.ActiveHP<health,"fire DOT ticks through actual combat")
local plain,guard=strike(nil);guard.State="Blocking"
Combat.resolveHit(plain,guard,1,{Facing=true,Region="Torso"},{})
local plainHealth=guard.ActiveHP
local void,voidGuard=strike("AbyssalVoid");voidGuard.State="Blocking"
Combat.resolveHit(void,voidGuard,1,{Facing=true,Region="Torso"},{})
check(voidGuard.ActiveHP<plainHealth,"void bypasses actual guard defense")
local lightning,stunned=strike("CelestialLightning")
Combat.resolveHit(lightning,stunned,1,{Facing=true,Region="Torso"},{})
local normal,unstunned=strike(nil);Combat.resolveHit(normal,unstunned,1,{Facing=true,Region="Torso"},{})
check(stunned.Posture>unstunned.Posture and stunned.StateEnd>unstunned.StateEnd,"lightning adds posture and stun")
local master=Combat.new(20,"Jian",0);local victim=Combat.new(21,"Jian",0)
Combat.applyStats(master,{SignatureFinisher=true});victim.State="StanceBroken"
local damage=Combat.executeDeathblow(master,victim,1,{})
local novice=Combat.new(22,"Jian",0);local other=Combat.new(23,"Jian",0);other.State="StanceBroken"
check(damage>Combat.executeDeathblow(novice,other,1,{}),"rank-five signature modifies actual execution")
local rally=Combat.new(24,"Jian",0);rally.ActiveHP=50;rally.RecoverableHP=40;rally.RallyUntil=5
Combat.applyStats(rally,{RallyScale=1.5});local recovery=Combat.rally(rally,10,1,{},25)
local baseline=Combat.new(26,"Jian",0);baseline.ActiveHP=50;baseline.RecoverableHP=40;baseline.RallyUntil=5
check(recovery>Combat.rally(baseline,10,1,{},25),"vigor improves actual blood rally")
local normalized=Arena.normalized();check(normalized.Vigor==20 and normalized.ArcaneQi==20,"ranked equal attributes")
for _,amount in {49,501,0/0,math.huge,50.5} do check(not Arena.validWager(amount),"invalid wager refused") end
local bank=forge.qiEssence;Arena.place(forge,"duel",9,500)
check(forge.qiEssence==bank-500 and not pcall(Arena.place,forge,"duel",9,500),"escrow once")
check(Arena.settle(forge,"duel",9,false)==900 and forge.qiEssence==bank+400,"winning payout")
check(Arena.settle(forge,"duel",9,false)==0,"settlement idempotent")
Arena.place(forge,"draw",9,50);check(Arena.settle(forge,"draw",nil,true)==50,"draw refund")
Arena.place(forge,"loss",9,50);check(Arena.settle(forge,"loss",10,false)==0,"losing stake consumed")
check(Schema.Validate(forge),"progressed profile validates")
print("PASS progression and lore: "..checks.." checks")
