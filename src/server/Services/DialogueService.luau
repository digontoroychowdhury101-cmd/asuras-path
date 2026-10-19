--!strict
local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage").AsurasPath
local Catalog=require(Shared.Shared.NarrativeCatalog)
local Rules=require(Shared.Shared.DialogueRules)
local Budget=require(Shared.Shared.IntentProtocol)
local Definitions=require(Shared.Shared.WorldDefinitions)
local Characters=require(script.Parent.CharacterService)
local AI=require(script.Parent.AIService)
local World=require(script.Parent.WorldService)
local Actions=require(script.Parent.DialogueActions)
local Build=require(script.Parent.NarrativeWorld)
local remote=Shared.Net:WaitForChild("DialogueIntent") :: RemoteEvent
local Service={}
local sessions: {[number]: any}={}
local buckets: {[number]: Budget.Bucket}={}
local busy: {[number]: boolean}={}
local links: {RBXScriptConnection}={}
local root: Folder?=nil
local serial=0
local function nearby(player: Player,point: Vector3): boolean
 local e=Characters.GetActor(player.UserId)
 return e~=nil and not e.Duel and (e.Fighter.State=="Idle" or e.Fighter.State=="RestingAtShrine")
  and not World.IsInBossFight(player.UserId) and not AI.IsHunting(player.UserId) and (e.Root.Position-point).Magnitude<=18
end
local function valid(player: Player,s: any): boolean
 return sessions[player.UserId]==s and os.clock()<s.Expires and nearby(player,s.Point)
end
local function send(player: Player,s: any,message: string?)
 serial+=1;s.Revision=serial
 remote:FireClient(player,{action="Dialogue",npc=s.NPC,node=s.Node,panel=s.Panel,revision=s.Revision,
  point=s.Point,view=Actions.view(player.UserId),message=message})
end
function Service.Open(player: Player,npc: string,altarId: string?)
 local n=Catalog.NPCs[npc];if not n or busy[player.UserId] then return end
 local point=Vector3.new(n.X,n.Y,n.Z)
 if altarId then
  local a=Definitions.Altars[altarId];if not a then return end;point=Vector3.new(a.Placement.X,a.Placement.Y,a.Placement.Z)
 end
 if not nearby(player,point) or not Actions.view(player.UserId) then return end
 World.Flush(player.UserId,3)
 if not nearby(player,point) then return end
 local s={NPC=npc,Node=n.Start,Panel=nil,Point=point,Expires=os.clock()+120,Revision=0}
 sessions[player.UserId]=s;send(player,s)
end
local function lore(player: Player,id: string)
 local l=Catalog.Lore[id];if not l or busy[player.UserId] then return end
 local point=Vector3.new(l.X,l.Y,l.Z)
 if not nearby(player,point) then return end
 busy[player.UserId]=true
 local ok,err=Actions.lore(player,id,function() return nearby(player,point) end);busy[player.UserId]=nil
 if ok then Actions.refresh(player.UserId);remote:FireClient(player,{action="Lore",id=id,view=Actions.view(player.UserId)})
 else remote:FireClient(player,{action="Result",message=tostring(err)}) end
end
local function handle(player: Player,p: any)
 if not Rules.valid(p) then return end
 local id=player.UserId;local now=os.clock();local b=buckets[id] or {tokens=6,time=now};buckets[id]=b
 if not Budget.Take(b,now,1,3,6) or busy[id] then return end
 if p.action=="Close" then sessions[id]=nil;return end
 if p.action=="Codex" then remote:FireClient(player,{action="Codex",view=Actions.view(id)});return end
 local s=sessions[id];if not s or not valid(player,s) or p.revision~=s.Revision then return end
 if p.action=="Choose" then
  local choice=Rules.choose(s.NPC,s.Node,p.index);if not choice then return end
  if choice.Close then sessions[id]=nil;remote:FireClient(player,{action="Close"});return end
  s.Node=choice.Next;s.Panel=choice.Action
  if s.Panel=="Arsenal" then
   sessions[id]=nil;remote:FireClient(player,{action="Close"});Actions.panel(player,s.Panel);return
  end
  send(player,s);return
 end
 busy[id]=true
 local success,ok,err=pcall(Actions.run,player,s,p,function() return valid(player,s) end)
 busy[id]=nil
 if success and ok then Actions.refresh(id) end
 if valid(player,s) then send(player,s,if success and ok then "The path remembers." else tostring(if success then err else ok)) end
end
function Service.Start()
 assert(not root,"DialogueService already started")
 local folder,connections=Build.build(function(p: Player,id: string) Service.Open(p,id) end,lore);root=folder;links=connections;
 (World :: any).OnAltarRest=function(p: Player,id: string) task.spawn(Service.Open,p,"Lin",id) end
 table.insert(links,remote.OnServerEvent:Connect(handle))
 local elapsed=0
 table.insert(links,Run.Heartbeat:Connect(function(dt: number)
  elapsed+=dt;if elapsed<0.5 then return end;elapsed=0
  for id,s in sessions do
   local player=Players:GetPlayerByUserId(id)
   if not player or not valid(player,s) then sessions[id]=nil;if player then remote:FireClient(player,{action="Close"}) end end
  end
 end))
 table.insert(links,Players.PlayerRemoving:Connect(function(p: Player) sessions[p.UserId]=nil;buckets[p.UserId]=nil;busy[p.UserId]=nil end))
end
function Service.Destroy()
 (World :: any).OnAltarRest=nil
 for _,c in links do c:Disconnect() end;table.clear(links)
 if root then root:Destroy();root=nil end;table.clear(sessions);table.clear(buckets);table.clear(busy)
end
return Service
