--!nonstrict
-- Unmapped Studio-only local two-client harness. Never shipped in default.project.json.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
local event=RS:WaitForChild("LobbyFinishQA",120)
if not event or not game:GetService("RunService"):IsStudio() then return end
local net=RS:WaitForChild("AsurasPath"):WaitForChild("Net")
local seq=100000
local messages={}
net.ColosseumIntent.OnClientEvent:Connect(function(p)
 table.insert(messages,{action=p.action,phase=p.phase,err=p.err})
 if p.action=="Challenge" then net.ColosseumIntent:FireServer({action="Respond",challenge=p.challenge,accept=true}) end
 event:FireServer("Observed",p)
end)
event.OnClientEvent:Connect(function(op,arg)
 if op=="Challenge" then net.ColosseumIntent:FireServer({action="Challenge",target=arg})
 elseif op=="Position" then if player.Character then player.Character:PivotTo(arg) end
 elseif op=="Attack" then
  for i=1,6 do seq+=1;net.ActionIntent:FireServer({seq=seq,action="Light",time=workspace:GetServerTimeNow()});task.wait(.85) end
 elseif op=="Leave" then game:GetService("StudioTestService"):LeaveTest()
 elseif op=="Report" then
  local seen={}
  for _,p in Players:GetPlayers() do if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then table.insert(seen,{id=p.UserId,at=tostring(p.Character.HumanoidRootPart.Position),duel=p.Character:GetAttribute("AsuraDuel")}) end end
  event:FireServer("Report",{ready=player:GetAttribute("AsuraClientReady"),others=seen,messages=messages,viewport=tostring(workspace.CurrentCamera.ViewportSize),tier=player:GetAttribute("LandscapeTier")})
 end
end)
local deadline=os.clock()+120
repeat task.wait(.2) until player:GetAttribute("AsuraClientReady") or os.clock()>deadline
event:FireServer("Ready",{at=player.Character and tostring(player.Character:GetPivot().Position)})
