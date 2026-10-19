--!strict
local Players=game:GetService("Players")
local Shared=game:GetService("ReplicatedStorage").AsurasPath
local Rules=require(Shared.Shared.ArenaRules)
local Budget=require(Shared.Shared.IntentProtocol)
local Persistence=require(script.Parent.PersistenceService) :: any
local Characters=require(script.Parent.CharacterService)
local Ledger=require(script.Parent.WagerLedger) :: any
local Build=require(script.Parent.WagerWorld)
local remote=Shared.Net:WaitForChild("WagerIntent") :: RemoteEvent
local Service={}
local matches: {[string]: any}={}
local outcomes: {[string]: any}={}
local links: {RBXScriptConnection}={}
local budgets: {[number]: Budget.Bucket}={}
local busy: {[number]: boolean}={}
local root: Folder?=nil
local arena: any=nil
local running=false
local function near(id: number): boolean
 local e=Characters.GetActor(id);return e~=nil and not e.Duel and e.Fighter.State=="Idle" and Build.near(e.Root.Position)
end
local function settle(id: number,matchId: string,result: any)
 Persistence.Transaction(id,function(p: any) Rules.settle(p,matchId,result.Winner,result.Refund==true) end)
end
function Service.Recover(id: number)
 if busy[id] then return end;busy[id]=true
 local p=Persistence.Get(id)
 if p then for matchId,bet in p.arenaWagers do if bet.State=="Pending" then
  local ok,record=Ledger:Read(matchId)
  if ok and record and record.state~="Active" then
   settle(id,matchId,record.results or {Refund=true})
  end
 end end end
 busy[id]=nil
end
function Service.Begin(id: string,a: number,b: number,an: string,bn: string,starts: number,ring: string)
 if not running or ring~="Ring_SanctuaryPromenade" then return end
 local m={Id=id,A=a,B=b,AN=an,BN=bn,Starts=starts,Phase="Countdown",Ready=false};matches[id]=m
 local ok=Ledger:Create(id,{a,b},game.JobId)
 if not ok then matches[id]=nil;return end
 m.Ready=true
 if not running then Service.Resolve(id,nil,true) elseif outcomes[id] then Service.Resolve(id,outcomes[id].Winner,outcomes[id].Refund) end
end
function Service.Resolve(id: string,winner: number?,refund: boolean)
 local result={Winner=winner,Refund=refund};outcomes[id]=result
 local m=matches[id];if not m or not m.Ready then return end
 m.Phase="Resolved"
 local ok=Ledger:Finish(id,result)
 if not ok then
  if running then task.delay(3,function() Service.Resolve(id,winner,refund) end) end;return
 end
 matches[id]=nil;outcomes[id]=nil
 for _,player in Players:GetPlayers() do task.spawn(Service.Recover,player.UserId) end
end
local function panel(player: Player,message: string?)
 local list={};for _,m in matches do
  if m.Ready and m.Phase~="Resolved" then table.insert(list,{id=m.Id,a=m.A,b=m.B,an=m.AN,bn=m.BN,starts=m.Starts,open=workspace:GetServerTimeNow()<m.Starts}) end
 end
 local p=Persistence.Get(player.UserId)
 remote:FireClient(player,{action="Panel",matches=list,qi=if p then p.qiEssence else 0,message=message})
end
local function handle(player: Player,p: any)
 if not running or type(p)~="table" or (p.action~="Refresh" and p.action~="Wager") then return end
 local fields=if p.action=="Refresh" then {action=true} else {action=true,match=true,fighter=true,amount=true}
 local count=0;for key in p do if not fields[key] then return end;count+=1 end
 if count~=(if p.action=="Refresh" then 1 else 4) then return end
 local id=player.UserId;local now=os.clock();local b=budgets[id] or {tokens=4,time=now};budgets[id]=b
 if not Budget.Take(b,now,1,2,4) or not near(id) or busy[id] then return end
 if p.action=="Refresh" then panel(player);return end
 if type(p.match)~="string" or #p.match>64 or type(p.fighter)~="number" or not Rules.validWager(p.amount) then return end
 local m=matches[p.match]
 if not m or not m.Ready or m.Phase=="Resolved" or workspace:GetServerTimeNow()>=m.Starts or (p.fighter~=m.A and p.fighter~=m.B) or id==m.A or id==m.B then return end
 busy[id]=true
 local ok,err=Persistence.Transaction(id,function(profile: any)
  assert(near(id) and m.Phase~="Resolved" and workspace:GetServerTimeNow()<m.Starts,"Wagering has closed")
  local n=0;for _ in profile.arenaWagers do n+=1 end
  if n>=480 then for key,bet in profile.arenaWagers do if bet.State=="Settled" then profile.arenaWagers[key]=nil end end end
  Rules.place(profile,m.Id,p.fighter,p.amount)
 end)
 busy[id]=nil
 if near(id) then panel(player,if ok then "Wager sealed · winners receive 1.8× the stake." else tostring(err)) end
end
function Service.Start(colosseum: any)
 assert(not running,"WagerService already started");running=true;arena=colosseum
 arena.SpectatorBegin=function(...: any) task.spawn(Service.Begin,...) end
 arena.SpectatorResult=function(...: any) task.spawn(Service.Resolve,...) end
 local folder,connection=Build.make(function(p: Player) if near(p.UserId) then panel(p) end end);root=folder;table.insert(links,connection)
 table.insert(links,remote.OnServerEvent:Connect(handle))
 table.insert(links,Players.PlayerRemoving:Connect(function(p: Player) budgets[p.UserId]=nil;busy[p.UserId]=nil end))
 task.spawn(function()
  while running do
   task.wait(5);if not running then break end
   for _,p in Players:GetPlayers() do task.spawn(Service.Recover,p.UserId) end
  end
 end)
end
function Service.Close(deadline: number?)
 running=false
 deadline=deadline or os.clock()+5
 repeat
  for id in matches do
   local result=outcomes[id] or {Refund=true}
   Service.Resolve(id,result.Winner,result.Refund)
  end
  if next(matches)==nil then break end
  task.wait(0.15)
 until os.clock()>=deadline
end
function Service.Destroy()
 Service.Close();if arena then arena.SpectatorBegin=nil;arena.SpectatorResult=nil end
 for _,c in links do c:Disconnect() end;table.clear(links)
 if root then root:Destroy();root=nil end;table.clear(budgets)
end
return Service
