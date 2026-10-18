--!nonstrict
-- Explicitly armed private-only fixtures. One closing job overlaps a running replacement.
-- No client commands, combat hooks, purchase prompts or production records.
local expected=require(script.Parent.PrivateValidationUniverse)
assert(expected==10770990655 and game.GameId==expected,"Isolated cross-job universe only")
if game:GetService("RunService"):IsStudio() or game.JobId=="" then return end
local Shared=game:GetService("ReplicatedStorage").Cagebound
local Config=require(Shared.Config)
assert(not Config.Features.PaidPurchases and not Config.Release.PurchasesIntegrationPassed and not Config.Features.Matchmaking,"Release gates must stay closed")
local DSS=game:GetService("DataStoreService")
local Http=game:GetService("HttpService")
local Msg=game:GetService("MessagingService")
local Engine=require(script.Parent.Services.ProfileStore)
local Schema=require(Shared.ProfileSchema)
local Journal=require(script.Parent.Services.MatchJournal)
local Shop=require(script.Parent.Services.ShopService)
local bundle=require(Shared.ShopCatalog).Bundles.Cash_Small
local coord=DSS:GetDataStore("CageboundValidationCoordination_v1")
local reports=DSS:GetDataStore("CageboundValidationReports_v1")
local proposed=Http:GenerateGUID(false):gsub("-","")
local state=coord:UpdateAsync("ActiveCrossJob",function(old)
 local abandoned=old and old.state=="Closing" and old.expires and os.time()>old.expires+30
 if old and old.deadline>os.time() and not old.complete and not abandoned then
  if old.aJob~=game.JobId and not old.bJob then old.bJob=game.JobId end
  return old
 end
 return {runId=proposed,aJob=game.JobId,state="Armed",deadline=os.time()+600}
end)
assert(state and (state.aJob==game.JobId or state.bJob==game.JobId),"Cross-job fixture already has two participants")
local run=state.runId;local role=if state.aJob==game.JobId then "A" else "B"
local scope="Chain_"..run;local topic="CageboundValidation_"..run
local data=DSS:GetDataStore("CageboundValidationProfiles_v1",scope)
local journalData=DSS:GetDataStore("CageboundValidationMatches_v1",scope)
local e=Engine.new(data,Schema,{owner=game.JobId,now=os.time,wait=task.wait,attempts=4,leaseSeconds=180})
local journal=Journal.new(journalData,function(fn) return e:Retry(fn) end,os.time)
local r={runId=run,role=role,jobId=game.JobId,aJob=state.aJob,bJob=state.bJob,universeId=expected,
 passed=false,crossServer=false,overlapState="A in BindToClose, B running",platformReceiptDelivery=false}
local function persist() reports:SetAsync("CrossJob_"..run.."_"..role,r) end
local function waitFor(fn,seconds,message,interval)
 local limit=os.clock()+seconds
 repeat task.wait(interval or .1) until fn() or os.clock()>limit
 assert(fn(),message)
end
local fenceAttempted=false;local ack=nil;local heartbeats=0
local subscription=Msg:SubscribeAsync(topic,function(message)
 local m=message.Data
 if type(m)~="table" or m.runId~=run then return end
 if role=="B" and m.kind=="Alive" and m.jobId==state.aJob then heartbeats+=1 end
 if role=="B" and m.kind=="Fenced" and m.jobId==state.aJob then ack=m end
 if role=="A" and m.kind=="Takeover" and not fenceAttempted then
  fenceAttempted=true
  task.spawn(function()
   local ok,err=pcall(function()
    local current=coord:GetAsync("ActiveCrossJob")
    assert(current.runId==run and current.bJob==m.jobId,"Unregistered replacement job")
    r.bJob=m.jobId
    -- Inject only a stale local-cache expiry to force the real UpdateAsync owner fence.
    e.profiles[800].session.expires=os.time()+180
    r.staleCacheInjected=true
    r.staleWriteRejected=not e:Transaction(800,function(p) p.fightCash=999999 end)
    assert(r.staleWriteRejected,"Old job overwrote the new owner's profile")
    r.passed=true;persist()
    Msg:PublishAsync(topic,{kind="Fenced",runId=run,jobId=game.JobId,staleWriteRejected=true})
   end)
   if not ok then r.error=tostring(err);persist() end
  end)
 end
end)
if role=="A" then
 local closing=false
 local ok,err=pcall(function()
  assert(e:Load(800))
  assert(e:Receipt(800,"chain-receipt",bundle.productId,function(p) Shop.GrantBundle(p,bundle) end))
  assert(journal:Create("chain-result",{800,801},"validation"))
  assert(e:Transaction(800,function(p) p.pendingMatches["chain-result"]=true end))
  assert(journal:Finish("chain-result",{["800"]={userId=800,mode="Ranked1v1",outcome="Win",eloDelta=16,cash=150,style="Ironline",xp=150}}))
  r.armedAt=os.time();persist()
 end)
 if not ok then r.error=tostring(err);persist();error(err) end
 task.spawn(function()
  while not closing do
   task.wait(45)
   if not closing then
    local saved=e:Save(800)
    if not saved then r.error="Armed fixture lease renewal failed";pcall(persist);return end
   end
  end
 end)
 game:BindToClose(function()
  closing=true
  local ok,err=pcall(function()
   waitFor(function() return not e.busy[800] end,3,"Fixture write still in progress at shutdown")
   e.options.leaseSeconds=15;assert(e:Save(800))
   local expires=e.profiles[800].session.expires
   coord:UpdateAsync("ActiveCrossJob",function(v) assert(v.runId==run);v.state="Closing";v.expires=expires;v.closingAt=os.time();return v end)
   r.closingAt=os.time();r.leaseExpires=expires;persist()
   local untilTime=os.clock()+26
   while os.clock()<untilTime do
    pcall(function() Msg:PublishAsync(topic,{kind="Alive",runId=run,jobId=game.JobId}) end)
    task.wait(2)
   end
   if not r.passed then r.error="No verified replacement takeover during closing overlap";persist() end
  end)
  if not ok then r.error=tostring(err);pcall(persist) end
  subscription:Disconnect()
 end)
 print("[Cagebound CrossJob] A ARMED "..run.."; leave/rejoin promptly for actual closing-job overlap")
 -- Allocate the replacement through Roblox before the old job loses its player.
 -- Manual Safari relaunch can take longer than BindToClose's finite overlap.
 task.spawn(function()
  local ok,err=pcall(function()
   local players=game:GetService("Players")
   waitFor(function() return #players:GetPlayers()>0 end,120,"No private test player for transfer",1)
   waitFor(function() return workspace:GetAttribute("PrivateCloudRunFinished")==true end,180,"Isolated cloud fixture run did not finish",1)
   assert(workspace:GetAttribute("PrivateCloudRunPassed")==true,"Cloud fixtures failed before transfer")
   task.wait(20)
   local player=players:GetPlayers()[1]
   assert(player and player.UserId==3148600636,"Only the authorized private-test owner may transfer")
   local options=Instance.new("TeleportOptions");options.ShouldReserveServer=true
   options:SetTeleportData({cageboundValidationRun=run})
   r.teleportIssuedAt=os.time();persist()
   game:GetService("TeleportService"):TeleportAsync(game.PlaceId,{player},options)
  end)
  if not ok then r.teleportError=tostring(err);pcall(persist) end
 end)
else
 task.spawn(function()
  local ok,err=xpcall(function()
   waitFor(function() state=coord:GetAsync("ActiveCrossJob");return state.state=="Closing" end,15,"Original job did not enter shutdown",1)
   r.aJob=state.aJob;r.bJob=game.JobId;r.leaseExpires=state.expires
   local loaded=e:Load(800)
   assert(not loaded,"Replacement arrived after lease expiry; contention was not tested")
   r.activeLeaseRefused=true
   waitFor(function() return os.time()>state.expires end,25,"Lease did not expire")
   assert(e:Load(800),"New job could not acquire the expired lease")
   assert(e:Receipt(800,"chain-receipt",bundle.productId,function(p) Shop.GrantBundle(p,bundle) end))
   local read,record=journal:Read("chain-result");assert(read and record.state=="Complete")
   assert(e:ApplyResult(800,"chain-result",record.results["800"]))
   assert(e:ApplyResult(800,"chain-result",record.results["800"]))
   assert(e:Get(800).fightCash==500+bundle.amount+150 and e:Get(800).wins==1,"Cross-job reward duplicated")
   Msg:PublishAsync(topic,{kind="Takeover",runId=run,jobId=game.JobId})
   waitFor(function() return ack~=nil end,20,"Old job did not acknowledge its stale-write rejection")
   assert(ack.staleWriteRejected and heartbeats>0,"No actual concurrent-job evidence")
   local players=game:GetService("Players")
   local persistence=require(script.Parent.Services.PersistenceService)
   waitFor(function()
    return players:GetPlayerByUserId(3148600636)~=nil and persistence.Get(3148600636)~=nil
   end,30,"Real transferred player's gameplay profile did not load",.5)
   local gameplay=persistence.Get(3148600636)
   r.gameplayProfileLoaded=true;r.gameplayCash=gameplay.fightCash;r.gameplayWins=gameplay.wins;r.gameplayElo=gameplay.elo
   r.oldJobHeartbeats=heartbeats;r.staleWriteRejected=true;r.receiptReplayPassed=true;r.journalRecoveryPassed=true
   r.crossServer=true;r.passed=true;r.finishedAt=os.time()
   assert(e:Release(800));persist()
   coord:UpdateAsync("ActiveCrossJob",function(v) assert(v.runId==run);v.complete=true;return v end)
  end,debug.traceback)
  if not ok then r.error=tostring(err);pcall(function() if e:Get(800) then e:Release(800) end end);pcall(persist) end
  subscription:Disconnect()
  print("[Cagebound CrossJob] B "..(if ok then "PASS" else "FAIL").." "..run)
 end)
end
