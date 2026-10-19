--!strict
local hasScript=pcall(function() return script.Parent end)
local Tempo: any=if hasScript then require(script.Parent.Tempo) else require("./Tempo")
export type Discipline="CelestialThunder" | "CrimsonFlame" | "AbyssalVoid" | "SpiritTalismans"
export type Payload={Burn: number,Root: number,Interrupt: boolean,IgnoreGuard: boolean,Drain: number,Ward: boolean,Teleport: boolean,Decoy: boolean}
export type Spell={Id: string,Name: string,Discipline: Discipline,QiCost: number,Range: number,Radius: number,Arc: number,Damage: number,Posture: number,
 Cooldown: number,Startup: number,Active: number,Recovery: number,Speed: number,Pierces: boolean,Pulses: number,Delay: number,Shape: string,Status: Payload}
local Schema={}
Schema.Disciplines=table.freeze({"CelestialThunder","CrimsonFlame","AbyssalVoid","SpiritTalismans"})
Schema.Slots=2
local function spell(id: string,name: string,school: Discipline,cost: number,range: number,shape: string,damage: number): Spell
 return {Id=id,Name=name,Discipline=school,QiCost=cost,Range=range,Radius=5,Arc=65,Damage=damage,Posture=18,Cooldown=6,
  Startup=18,Active=6,Recovery=24,Speed=0,Pierces=false,Pulses=1,Delay=0,Shape=shape,
  Status={Burn=0,Root=0,Interrupt=false,IgnoreGuard=false,Drain=0,Ward=false,Teleport=false,Decoy=false}}
end
local palm=spell("ThunderclapPalm","Thunderclap Palm","CelestialThunder",18,8,"Cone",16)
palm.Startup=6;palm.Status.Interrupt=true;palm.Posture=32
local spear=spell("HeavenlyLightningSpear","Heavenly Lightning Spear","CelestialThunder",28,80,"Line",30)
spear.Startup=42;spear.Speed=160;spear.Pierces=true;spear.Radius=2
local maw=spell("DragonsMaw","Dragon's Maw","CrimsonFlame",24,20,"Cone",10)
maw.Status.Burn=1;maw.Pulses=3;maw.Delay=0.22;maw.Active=30
local ember=spell("EmberCataclysm","Ember Cataclysm","CrimsonFlame",40,45,"Pillars",22)
ember.Pulses=3;ember.Delay=0.6;ember.Cooldown=12;ember.Startup=36;ember.Status.Burn=1
local surge=spell("BlackflameSurge","Blackflame Surge","AbyssalVoid",30,28,"Cone",28)
surge.Arc=130;surge.Status.IgnoreGuard=true
local grave=spell("GraveTendrils","Grave Tendrils","AbyssalVoid",26,32,"Pillars",12)
grave.Status.Root=2;grave.Radius=7
local aegis=spell("JadeAegis","Jade Aegis","SpiritTalismans",35,0,"Self",0)
aegis.Status.Ward=true;aegis.Cooldown=20
local gale=spell("GaleStep","Gale Step","SpiritTalismans",20,18,"Self",0)
gale.Status.Teleport=true;gale.Status.Decoy=true;gale.Startup=6;gale.Cooldown=7
local dirge=spell("AbbotDirge","Abbot's Dirge","AbyssalVoid",35,14,"Aura",4)
dirge.Pulses=5;dirge.Delay=0.75;dirge.Posture=15;dirge.Status.Drain=12;dirge.Status.Interrupt=true
local fissure=spell("FissureSlam","Fissure Slam","CrimsonFlame",40,40,"Line",36)
fissure.Pierces=true;fissure.Radius=5;fissure.Status.Burn=2;fissure.Posture=48;fissure.Startup=42
local thunder=spell("Thunderfall","Thunderfall","CelestialThunder",45,65,"Impact",38)
thunder.Speed=180;thunder.Radius=9;thunder.Status.Teleport=true;thunder.Status.Interrupt=true;thunder.Startup=36
local wind=spell("WindSlash","Wind-Cutting Slash","SpiritTalismans",1,30,"Line",12)
wind.Speed=90;wind.Radius=2
local byId: {[string]: Spell}={}
local order: {string}={}
function Schema.validate(s: Spell)
 assert(#s.Id>0 and table.find(Schema.Disciplines,s.Discipline),"Invalid spell identity")
 for _,n in {s.QiCost,s.Range,s.Radius,s.Damage,s.Posture,s.Cooldown,s.Startup,s.Active,s.Recovery,s.Speed,s.Delay} do
  assert(n==n and n>=0 and n<math.huge,"Invalid spell number")
 end
 assert(s.QiCost>0 and s.QiCost<=100 and s.Range<=100 and s.Radius<=20 and s.Cooldown>=1,"Invalid spell limits")
 assert(s.Arc>=0 and s.Arc<=360 and s.Speed<=240 and s.Cooldown<=60,"Invalid spell reach/timing limits")
 assert(s.Startup>=1 and s.Active>=1 and s.Recovery>=1 and s.Pulses>=1 and s.Pulses<=5 and s.Pulses%1==0,"Invalid spell timings")
 assert(s.Status.Root>=0 and s.Status.Root<=2 and s.Status.Burn>=0 and s.Status.Burn<=5 and s.Status.Drain>=0,"Invalid status")
 assert(table.find({"Self","Cone","Line","Pillars","Aura","Impact"},s.Shape),"Invalid spell shape")
end
function Schema.timing(s: Spell,quick: boolean?): {Startup: number,Active: number,Recovery: number,Total: number}
 local startup=Tempo.framesToSeconds(Tempo.enforceTelegraph("Light",Tempo.scaleFrames(s.Startup)))
 if quick then startup=math.max(Tempo.LightMinSeconds,startup*0.75) end
 local active=Tempo.framesToSeconds(Tempo.scaleFrames(s.Active))
 local recovery=Tempo.framesToSeconds(Tempo.scaleFrames(s.Recovery))
 return {Startup=startup,Active=active,Recovery=recovery,Total=startup+active+recovery}
end
for _,s in {palm,spear,maw,ember,surge,grave,aegis,gale,dirge,fissure,thunder,wind} do
 Schema.validate(s);local previous=byId[s.Id];assert(previous==nil,"Duplicate spell")
 byId[s.Id]=s;table.insert(order,s.Id);table.freeze(s.Status);table.freeze(s)
end
Schema.ById=table.freeze(byId)
Schema.Order=table.freeze(order)
function Schema.get(id: string): Spell?
 return byId[id]
end
return table.freeze(Schema)
