--!nonstrict
-- Server-only private-universe harness. No purchase prompts or client test hooks.
-- Uses the production storage/journal source with isolated validation stores/scopes.
local Validation={}
function Validation.Run(expectedUniverseId)
 assert(game:GetService("RunService"):IsServer(),"Server context required")
 assert(type(expectedUniverseId)=="number" and expectedUniverseId>0 and game.GameId==expectedUniverseId,"Private test universe allowlist mismatch")
 local Shared=game:GetService("ReplicatedStorage").Cagebound
 local Config=require(Shared.Config)
 assert(not Config.Features.PaidPurchases and not Config.Release.PurchasesIntegrationPassed,"Purchase gates must remain closed")
 local services=script.Parent.Services
 local Engine=require(services.ProfileStore)
 local Schema=require(Shared.ProfileSchema)
 local Journal=require(services.MatchJournal)
 local Shop=require(services.ShopService)
 local Catalog=require(Shared.ShopCatalog)
 local cashProduct=Catalog.Bundles.Cash_Small
 local Http=game:GetService("HttpService")
 local DataStores=game:GetService("DataStoreService")
 local runId=Http:GenerateGUID(false):gsub("-","")
 local scope="Run_"..runId
 local data=DataStores:GetDataStore("CageboundValidationProfiles_v1",scope)
 local journalData=DataStores:GetDataStore("CageboundValidationMatches_v1",scope)
 local report={runId=runId,universeId=game.GameId,jobId=game.JobId,checks={},
  crossServer=false,platformReceiptDelivery=false,platformThrottling=false,shutdown=false,productIds={}}
 for key,bundle in Catalog.Bundles do report.productIds[key]=bundle.productId end
 local engines={}
 local function engine(owner,backing,lease)
  local e=Engine.new(backing or data,Schema,{owner=owner..":"..runId,now=os.time,wait=task.wait,attempts=4,leaseSeconds=lease or 180})
  table.insert(engines,e);return e
 end
 local function check(name,fn) fn();table.insert(report.checks,name);print("[Cagebound Cloud] PASS "..name) end
 local a,b=engine("A"),engine("B")
 local ok,err=xpcall(function()
  check("migration and competing owners on real DataStore",function()
   local legacy=Schema.Default(101);legacy.schemaVersion=1;legacy.fightCash=789
   data:UpdateAsync("Player_101",function() return legacy end)
   assert(a:Load(101).fightCash==789);assert(not b:Load(101))
   assert(a:Save(101))
  end)
  check("synthetic receipt replay and reload on real DataStore",function()
   local function syntheticReceipt(store,id,purchaseId)
    return store:Receipt(id,purchaseId,cashProduct.productId,function(p) Shop.GrantBundle(p,cashProduct) end)
   end
   for _=1,3 do assert(syntheticReceipt(a,101,"synthetic-"..runId)) end
   assert(a:Get(101).fightCash==1289)
   assert(a:Release(101));assert(b:Load(101).fightCash==1289)
   assert(syntheticReceipt(b,101,"synthetic-"..runId));assert(b:Get(101).fightCash==1289)
   assert(not syntheticReceipt(a,101,"missing-session"))
  end)
  check("concurrent synthetic mapped receipt and every bundle grant",function()
   local before=b:Get(101).fightCash;local receiptId="concurrent-"..runId;local completed=0
   for _=1,6 do task.spawn(function()
    b:Receipt(101,receiptId,cashProduct.productId,function(p) Shop.GrantBundle(p,cashProduct) end)
    completed+=1
   end) end
   local deadline=os.clock()+90
   repeat task.wait(.1) until completed==6 or os.clock()>deadline
   assert(completed==6,"Missing concurrent receipt completion")
   for _=1,6 do assert(b:Receipt(101,receiptId,cashProduct.productId,function(p) Shop.GrantBundle(p,cashProduct) end)) end
   assert(b:Get(101).fightCash==before+cashProduct.amount,"Concurrent receipt duplicated")
   local index=0
   for key,bundle in Catalog.Bundles do
    index+=1;local id=200+index;assert(b:Load(id));local old=b:Get(id)
    local receipt="bundle-"..key.."-"..runId
    for _=1,2 do assert(b:Receipt(id,receipt,bundle.productId,function(p) Shop.GrantBundle(p,bundle) end)) end
    local new=b:Get(id)
    if bundle.bundleType=="Cash" then assert(new.fightCash==old.fightCash+bundle.amount)
    elseif bundle.bundleType=="Spins" then assert(new.styleSpins==old.styleSpins+bundle.amount)
    else assert(new.ownedCosmetics.VIP_Pass==true) end
   end
   report.concurrentSyntheticReceipt=true
  end)
  check("ambiguous commit response and bounded injected outage",function()
   local lost=true
   local ambiguous={UpdateAsync=function(_,key,fn)
    local result=data:UpdateAsync(key,fn)
    if lost then lost=false;error("Injected response loss after real commit") end
    return result
   end}
   local c=engine("Ambiguous",ambiguous)
   assert(c:Load(102))
   lost=true;assert(c:Transaction(102,function(p) p.fightCash+=37 end))
   assert(c:Get(102).fightCash==537)
   local calls=0
   local outage=engine("Outage",{UpdateAsync=function() calls+=1;error("Injected API outage") end})
   assert(not outage:Load(101));assert(calls==4 and not outage:Get(101))
   assert(b:Get(101).fightCash==1289+cashProduct.amount,"Failed load replaced a valid profile")
  end)
  check("durable journal, partial result and owned reload",function()
   local journal=Journal.new(journalData,function(fn) return b:Retry(fn) end,os.time)
   local matchId="synthetic-"..runId
   assert(journal:Create(matchId,{101,103},"validation"))
   assert(b:Transaction(101,function(p) p.pendingMatches[matchId]=true end))
   local result={userId=101,mode="Ranked1v1",outcome="Win",eloDelta=16,cash=150,style="Ironline",xp=150}
   assert(journal:Finish(matchId,{["101"]=result}))
   assert(b:Release(101));assert(a:Load(101));local before=a:Get(101)
   local read,record=journal:Read(matchId);assert(read and record.state=="Complete")
   assert(a:ApplyResult(101,matchId,record.results["101"]));assert(a:ApplyResult(101,matchId,record.results["101"]))
   local after=a:Get(101);assert(after.wins==before.wins+1 and after.fightCash==before.fightCash+150)
   local _,terminal=journal:Finish(matchId,nil);assert(terminal.state=="Complete")
  end)
  check("expired lease fences stale writes on real DataStore",function()
   local old=engine("ShortLease",nil,8);assert(old:Load(104))
   task.wait(9)
   local fresh=engine("Takeover");assert(fresh:Load(104))
   assert(not old:Transaction(104,function(p) p.fightCash=99999 end))
   assert(fresh:Get(104).fightCash==500)
  end)
  check("oversized ledger grant fails closed on real DataStore",function()
   local large=Schema.Default(105)
   for i=1,6000 do
    local key=string.rep('"',190)..string.format("%010d",i)
    large.receipts[key]=cashProduct.productId;large.appliedMatches[key]=true
   end
   assert(Schema.Validate(large))
   report.oversizedFixtureBytes=#Http:JSONEncode(large)
   assert(report.oversizedFixtureBytes>4194304,"Fixture must exceed the platform record limit")
   assert(a:Load(105))
   assert(not a:Transaction(105,function(p)
    p.fightCash+=500;p.receipts=large.receipts;p.appliedMatches=large.appliedMatches
   end))
   local durable=data:GetAsync("Player_105")
   assert(durable.profile.fightCash==500 and next(durable.profile.receipts)==nil,"Oversized grant changed durable profile")
   report.capacityGuardPassed=true
  end)
  report.profileBytes=#Http:JSONEncode(a:Get(101))
 end,debug.traceback)
 for _,e in engines do for id in e.profiles do if e:Get(id) then e:Release(id) end end end
 report.passed=ok;report.error=if ok then nil else tostring(err)
 -- Report scope contains test fixtures only. It does not touch gameplay stores.
 DataStores:GetDataStore("CageboundValidationReports_v1"):SetAsync(runId,report)
 print("[Cagebound Cloud] REPORT "..Http:JSONEncode(report))
 assert(ok,err)
 return report
end
return Validation
