--!nonstrict
local Schema=require("../src/shared/ProfileSchema")
local Store=require("../src/server/ProfileStore")
local Journal=require("../src/server/MatchJournal")
local Protocol=require("../src/infrastructure/IntentProtocol")
local data={};local now=1000;local failures=0;local afterCommit=0;local calls=0;local waits=0
local db={UpdateAsync=function(_,key,fn)
 calls+=1
 if failures>0 then failures-=1;error("simulated outage") end
 -- Real callbacks may execute repeatedly. Discard an initial speculative evaluation.
 fn(Store.Copy(data[key]))
 local value=fn(Store.Copy(data[key]))
 if value~=nil then data[key]=Store.Copy(value) end
 if afterCommit>0 then afterCommit-=1;error("commit response lost") end
 return Store.Copy(value)
end}
local function engine(owner)
 return Store.new(db,Schema,{owner=owner,now=function() return now end,wait=function() waits+=1 end,attempts=4,leaseSeconds=180})
end
local a,b=engine("A"),engine("B")
local p=assert(a:Load(1));assert(p.fightCash==500)
assert(not b:Load(1),"Concurrent server stole a live lease")
p.fightCash=0;assert(a:Get(1).fightCash==500,"Get exposed mutable cache")
failures=3;assert(a:Save(1));assert(waits==3)
local before=calls;failures=10;assert(not a:Save(1));assert(calls-before==4);failures=0
local c=engine("C");data.Player_2=Schema.Default(2);data.Player_2.fightCash=9999
failures=10;assert(not c:Load(2));assert(not c:Save(2));assert(data.Player_2.fightCash==9999);failures=0
assert(c:Load(2).fightCash==9999)
assert(a:Receipt(1,"purchase-1",10001,function(profile) profile.fightCash+=1000 end))
for _=1,20 do assert(a:Receipt(1,"purchase-1",10001,function(profile) profile.fightCash+=1000 end)) end
assert(a:Get(1).fightCash==1500)
afterCommit=1;assert(a:Receipt(1,"purchase-2",10001,function(profile) profile.fightCash+=1000 end))
assert(a:Get(1).fightCash==2500,"Ambiguous commit duplicated receipt")
afterCommit=1;assert(a:Transaction(1,function(profile) profile.styleSpins-=1 end))
assert(a:Get(1).styleSpins==4,"Ambiguous transaction commit duplicated deduction")
failures=4;assert(not a:Receipt(1,"failed",10001,function(profile) profile.fightCash+=1000 end))
assert(a:Get(1).fightCash==2500 and not a:Get(1).receipts.failed)
assert(not a:Receipt(1,"purchase-1",10002,function() error("Must not grant") end))
assert(a:Release(1));assert(not a:Get(1));assert(b:Load(1).fightCash==2500)
assert(b:Receipt(1,"purchase-2",10001,function(profile) profile.fightCash+=1000 end))
assert(b:Get(1).fightCash==2500,"Reconnect duplicated receipt")
now+=181;assert(not b:Get(1));assert(a:Load(1));assert(not b:Save(1),"Expired owner saved over new session")
-- New/future/corrupt storage never becomes a saveable default.
for id,raw in { [3]={schemaVersion=99,userId=3},[4]="bad",[5]={storageVersion=9},[6]={schemaVersion=2,userId=6,receipts="bad"}} do
 data["Player_"..id]=raw;local e=engine("bad"..id)
 assert(not e:Load(id));assert(not e:Save(id))
end
-- Migration reconciles level with the canonical 7500 XP threshold.
local raw=Schema.Default(10);raw.schemaVersion=1;raw.styles.Ironline={unlocked=true,xp=7000,level=5}
assert(Schema.Migrate(raw,10).styles.Ironline.level==4)
raw.styles.Ironline.xp=7500;assert(Schema.Migrate(raw,10).styles.Ironline.level==5)
c=engine("C2");assert(c:Load(2))
local j=Journal.new(db,function(fn) return a:Retry(fn) end,function() return now end)
assert(j:Create("match-1",{1,2},"A"))
for _,id in {1,2} do assert((if id==1 then a else c):Transaction(id,function(profile) profile.pendingMatches["match-1"]=true end)) end
local results={ ["1"]={userId=1,mode="Ranked1v1",eloDelta=16,cash=285,outcome="Win",style="Ironline",xp=150},
 ["2"]={userId=2,mode="Ranked1v1",eloDelta=-16,cash=135,outcome="Loss",style="Ironline",xp=50}}
assert(j:Finish("match-1",results))
assert(j:Finish("match-1",{wrong=true}))
local _,terminal=j:Read("match-1");assert(terminal.results["1"].cash==285,"Terminal journal was overwritten")
assert(a:ApplyResult(1,"match-1",terminal.results["1"]))
-- Crash between participants: reload second profile and discover the pending result.
assert(c:Release(2));local reconnected=engine("reconnect");assert(reconnected:Load(2).pendingMatches["match-1"])
assert(reconnected:ApplyResult(2,"match-1",terminal.results["2"]))
for _=1,10 do assert(a:ApplyResult(1,"match-1",terminal.results["1"])) end
assert(a:Get(1).wins==1 and a:Get(1).elo==1016 and a:Get(1).styles.Ironline.xp==150)
assert(reconnected:Get(2).losses==1 and reconnected:Get(2).elo==984)
assert(not a:ApplyResult(1,"practice",{userId=1,mode="Practice"}),"Practice awarded ranked results")
assert(j:Create("abandoned",{1,2},"A"));now+=1201
local _,cancelled=j:Read("abandoned");assert(cancelled.state=="Cancelled")
assert(Protocol.QueueEnabled("Casual1v1",false,false,false))
for _,gates in {{false,false},{true,false},{false,true},{true,true}} do
 assert(Protocol.QueueEnabled("Ranked1v1",gates[1],gates[2],false)==(gates[1] and gates[2]))
end
assert(not Protocol.QueueEnabled("Bad",true,true,true))
assert(Protocol.Matchmaking({action="Enqueue",mode="Ranked1v1"}))
for _,packet in {{action="Enqueue",mode="Bad"},{action="Dequeue",userId=2},{action="Enqueue",mode="Ranked1v1",elo=9999}} do assert(not Protocol.Matchmaking(packet)) end
assert(Protocol.Shop({action="SaveSettings",settings={fov=80,sensitivity=1,leftHanded=true}}))
assert(not Protocol.Shop({action="SaveSettings",settings={fov=math.huge,sensitivity=1,leftHanded=true}}))
-- Individually valid ledgers can exceed a record's byte limit when combined.
local large=Schema.Default(20)
for i=1,3000 do
 local key=string.rep('"',190)..string.format("%010d",i)
 large.receipts[key]=10001;large.appliedMatches[key]=true
end
assert(Schema.Validate(large),"Size fixture must otherwise be a valid profile")
data.Player_20=large
local capacity=engine("capacity")
assert(not capacity:Load(20) and not capacity:Get(20),"Oversized profile became writable")
assert(data.Player_20.receipts==large.receipts,"Failed load overwrote durable ledgers")
assert(capacity:Load(21))
local cash=capacity:Get(21).fightCash
assert(not capacity:Transaction(21,function(profile)
 profile.fightCash+=500;profile.receipts=Store.Copy(large.receipts);profile.appliedMatches=Store.Copy(large.appliedMatches)
end),"Oversized grant committed")
assert(capacity:Get(21).fightCash==cash and next(capacity:Get(21).receipts)==nil,"Failed byte-budget grant escaped rollback")
print("PASS backend: leases, expiry/fencing, bounded retries, load failure protection, callback replay, commit-response loss, receipts across reconnect, schema migration, durable result inbox recovery, exactly-once results, practice rejection and request schemas")
