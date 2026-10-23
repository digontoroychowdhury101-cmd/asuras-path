--!nonstrict
-- Seeded Studio diagnostic: actual local clients, production challenge/accept/action remotes,
-- observed replication, authoritative damage and disconnect cleanup. No profile/cloud publication.
local Run=game:GetService("RunService")
if not Run:IsStudio() then return end
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local STS=game:GetService("StudioTestService")
local Http=game:GetService("HttpService")
local event=RS:WaitForChild("LobbyFinishQA",15)
if not event then return end
local ready,observed,reports={},{},{}
event.OnServerEvent:Connect(function(p,op,data)
 if op=="Ready" then ready[p.UserId]=data elseif op=="Observed" then observed[p.UserId]=observed[p.UserId] or {};table.insert(observed[p.UserId],data) elseif op=="Report" then reports[p.UserId]=data end
end)
local result={kind="Seeded Studio local two-client diagnostic; no physical input or published-service claim",checks={}}
local function check(ok,name,details)
 table.insert(result.checks,{name=name,passed=ok==true,details=details});assert(ok,name..": "..tostring(details))
end
local function untilTrue(fn,seconds,label)
 local deadline=os.clock()+seconds
 repeat if fn() then return end task.wait(.2) until os.clock()>deadline
 error("Timed out: "..label)
end
local ok,err=xpcall(function()
 untilTrue(function()return workspace:GetAttribute("AsuraReady") and #Players:GetPlayers()==2 end,150,"two players and server")
 local services=game.ServerScriptService.AsurasPath.Services
 local C=require(services.CharacterService);local Coliseum=require(services.ColosseumService)
 local p=Players:GetPlayers();table.sort(p,function(a,b)return a.UserId<b.UserId end)
 untilTrue(function()return ready[p[1].UserId] and ready[p[2].UserId] end,240,"both client bootstraps")
 check(true,"Two real clients booted",ready)
 for i,player in p do
  local e=C.GetEntity(player.UserId)
  check(e and e.Humanoid.Health>0 and e.Root.Position.Y>600,"Player "..i.." spawned above cloud sea",tostring(e and e.Root.Position))
 end
 local center=Coliseum.GetRings()[1].Center
 for i,player in p do local frame=CFrame.lookAt(center+Vector3.new(if i==1 then 3 else -3,3.2,if i==1 then 20 else -20),center+Vector3.new(0,3.2,0));C.Teleport(player.UserId,frame);event:FireClient(player,"Position",frame) end
 task.wait(2)
 event:FireClient(p[1],"Challenge",p[2].UserId)
 untilTrue(function()return Coliseum.IsInMatch(p[1].UserId) and Coliseum.IsInMatch(p[2].UserId) end,20,"challenge and acceptance through remotes")
 check(true,"Challenge / accept allocated both duelists")
 untilTrue(function()
  for _,player in p do local found=false for _,m in observed[player.UserId] or {} do if m.phase=="Fighting" then found=true end end if not found then return false end end return true
 end,30,"countdown to fighting on both clients")
 check(true,"Both clients received Fighting phase")
 local allow,why=C.GetHooks().Heal(p[1].UserId)
 check(allow==false and why=="InColosseum","Story healing remains locked during duel",why)
 local a,b=C.GetEntity(p[1].UserId),C.GetEntity(p[2].UserId)
 local y=center.Y+3.4
 C.Teleport(p[1].UserId,CFrame.lookAt(Vector3.new(center.X,y,center.Z+1.65),Vector3.new(center.X,y,center.Z-1.65)))
 C.Teleport(p[2].UserId,CFrame.lookAt(Vector3.new(center.X,y,center.Z-1.65),Vector3.new(center.X,y,center.Z+1.65)))
 task.wait(.7)
 event:FireClient(p[1],"Position",a.Root.CFrame);event:FireClient(p[2],"Position",b.Root.CFrame)
 task.wait(.7)
 local before=b.Fighter.ActiveHP
 event:FireClient(p[1],"Attack")
 untilTrue(function()return b.Fighter.ActiveHP<before end,12,"authoritative melee damage")
 check(true,"Client attacks caused authoritative opponent damage",{before=before,after=b.Fighter.ActiveHP})
 event:FireAllClients("Report");untilTrue(function()return reports[p[1].UserId] and reports[p[2].UserId] end,8,"replication reports")
 for _,player in p do check(#reports[player.UserId].others==2,"Client "..player.Name.." sees both characters",reports[player.UserId]) end
 event:FireClient(p[2],"Leave")
 untilTrue(function()return #Players:GetPlayers()==1 and not Coliseum.IsInMatch(p[1].UserId) end,20,"disconnect release")
 check(p[1]:GetAttribute("AsuraColosseum")==nil,"Survivor restored after disconnect",tostring(C.GetEntity(p[1].UserId).Root.Position))
end,debug.traceback)
result.players={}
for _,p in Players:GetPlayers() do table.insert(result.players,{id=p.UserId,attrs=p:GetAttributes(),character=p.Character~=nil})end
result.passed=ok;result.error=if ok then nil else err;result.observed=observed
local encoded=Http:JSONEncode(result)
_G.LobbyFinishMultiplayerResult=result
print("[LobbyFinish Multiplayer] "..encoded)
local ended,endErr=pcall(function()STS:EndTest(encoded)end)
if not ended then warn("[LobbyFinish Multiplayer] "..tostring(endErr)) end
