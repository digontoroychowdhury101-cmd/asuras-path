--!nonstrict
local Shared=game:GetService("ReplicatedStorage").AsurasPath
local Schema=require(Shared.ProfileSchema)
local Engine=require(script.Parent.ProfileStore)
local RunService=game:GetService("RunService")
local Http=game:GetService("HttpService")
local Config=require(Shared.Config)
local mock={}
local dataStore
if RunService:IsStudio() and not Config.Backend.StudioLiveData then
 dataStore={UpdateAsync=function(_,key,callback)
  local value=callback(Engine.Copy(mock[key]))
  if value~=nil then mock[key]=Engine.Copy(value) end
  return Engine.Copy(value)
 end}
else
 dataStore=game:GetService("DataStoreService"):GetDataStore("AsuraProfiles_v1")
end
local engine=Engine.new(dataStore,Schema,{owner=game.JobId..":"..Http:GenerateGUID(false),now=os.time,wait=task.wait,
 attempts=4,leaseSeconds=Config.Backend.LeaseSeconds})
local Service={Engine=engine,IsMock=RunService:IsStudio() and not Config.Backend.StudioLiveData}
function Service.Load(id)
 local deadline=os.clock()+20
 local ownershipAttempts=0
 repeat
  local p,err=engine:Load(id)
  if p then return p end
  if os.clock()>=deadline then error(err,0) end
  if err=="Profile is active on another server" then
   -- Teleport/rejoin can arrive before PlayerRemoving finishes its release.
   -- Wait for that normal release; never force an active owner's lease.
   ownershipAttempts+=1
   if ownershipAttempts>=8 then error(err,0) end
   task.wait(math.min(ownershipAttempts,3,math.max(0,deadline-os.clock())))
  elseif err=="Profile is busy" then task.wait(0.05)
  else error(err,0) end
 until false
end
function Service.Get(id) return engine:Get(id) end
function Service.Transaction(id,fn) return engine:Transaction(id,fn) end
function Service.Save(id) return engine:Save(id) end
function Service.Unload(id)
 local deadline=os.clock()+20
 repeat
  local ok,err=engine:Release(id)
  if ok or err~="Profile is busy" then return ok,err end
  task.wait(0.05)
 until os.clock()>deadline
 return false,"Release timed out"
end
function Service.ProcessReceipt(id,purchaseId,productId,grant) return engine:Receipt(id,purchaseId,productId,grant) end
function Service.ApplyResult(id,matchId,result) return engine:ApplyResult(id,matchId,result) end
function Service.PublicProfile(id)
 local p=Service.Get(id)
 if p then p.receipts=nil;p.appliedMatches=nil;p.pendingMatches=nil end
 return p
end
function Service.Start()
 task.spawn(function()
  while not engine.closed do
   task.wait(Config.Backend.AutosaveSeconds)
   if engine.closed then break end
   for id in engine.profiles do task.spawn(function()
    local ok,err=Service.Save(id)
    if not ok then
     warn("[Persistence] Autosave "..id..": "..tostring(err))
     if not Service.Get(id) then
      local player=game:GetService("Players"):GetPlayerByUserId(id)
      if player then player:Kick("Your fighter session expired. Please rejoin safely.") end
     end
    end
   end) end
  end
 end)
end
function Service.Close(deadline)
 engine.closed=true
 local pending=0
 for id in engine.profiles do pending+=1;task.spawn(function() Service.Unload(id);pending-=1 end) end
 deadline=deadline or os.clock()+25
 repeat task.wait(0.05) until pending==0 or os.clock()>deadline
 if pending>0 then warn("[Persistence] Shutdown deadline; remaining leases expire safely") end
end
return Service
