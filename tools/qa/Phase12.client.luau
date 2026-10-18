--!nonstrict
local Players=game:GetService("Players")
if not game:IsLoaded() then game.Loaded:Wait() end
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Cagebound")
local net=Shared.Net.MatchmakingIntent
local function untilTrue(fn,message,timeout)
 local deadline=os.clock()+(timeout or 30)
 repeat task.wait(.02) until fn() or os.clock()>deadline
 assert(fn(),message)
end
untilTrue(function() return _G.CageboundQA~=nil end,"QA hook",120)
local qa=_G.CageboundQA
local input,prediction,ui=qa.input,qa.prediction,qa.ui
local Interface=require(Players.LocalPlayer.PlayerScripts.Cagebound.Controllers.InterfaceController)
local sample=input.Sample
input.Sample=function(self,dt) self.focused=true;return sample(self,dt) end
local function own()
 for _,a in prediction.roster do if a.id==Players.LocalPlayer.UserId then return a end end
end
local function report(command,requestId,ok,result)
 net:FireServer({action="QAReport",command=command,requestId=requestId,ok=ok,result=result})
end
local function run(command,requestId)
 if command=="Ping" then return {userId=Players.LocalPlayer.UserId,viewport=tostring(workspace.CurrentCamera.ViewportSize),inputEnabled=input.enabled}
 elseif command=="Menu" then
  local front=assert(qa.frontEnd)
  front:Open("Customise")
  local original=front.root.Size
  for _,size in {Vector2.new(1440,900),Vector2.new(844,390),Vector2.new(390,844)} do
   front.root.Size=UDim2.fromOffset(size.X,size.Y);task.wait(.15);front:Layout()
   assert(front.PlayNav.AbsoluteSize.Y>=44 and front.CustomiseNav.AbsoluteSize.Y>=44 and front.SettingsNav.AbsoluteSize.Y>=44,"Front-end target")
   assert(front.content.AbsoluteSize.X<=size.X and front.content.AbsoluteSize.Y>0,"Front-end scroll bounds")
  end
  front.root.Size=original;front.root.Visible=false;front.homeButton.Visible=true
  assert(front.homeButton.Parent==front.gui and front.homeButton.AbsoluteSize.Y>=44,"Lobby return button hidden with menu")
  assert(front.gui.DisplayOrder>ui.Gui.DisplayOrder,"Lobby return below combat GUI")
  input:Menu(false);input:RefreshEnabled()
  local response=nil
  local remote=Shared.Net.ShopIntent
  local connection=remote.OnClientEvent:Connect(function(v) if v.action=="SettingsResult" then response=v end end)
  local keys=input:GetKeybinds();keys.LeftHand="Z"
  remote:FireServer({action="SaveSettings",settings={fov=85,sensitivity=1.25,leftHanded=true,keybinds=keys}})
  untilTrue(function() return response~=nil end,"Saved keybind response",30);connection:Disconnect()
  assert(response.ok and response.profile.settings.keybinds.LeftHand=="Z","Keybind persistence")
  input:LoadKeybinds(response.profile.settings.keybinds)
  return {menuLayouts="1440x900,844x390,390x844",savedKeybind=true,storage="Studio mock"}
 elseif command=="Layout" then
  untilTrue(function() return input.enabled end,"Input ready")
  local original=ui.Root.Size
  for _,size in {Vector2.new(1440,900),Vector2.new(844,390),Vector2.new(390,844)} do
   ui.Root.Size=UDim2.fromOffset(size.X,size.Y);task.wait(.05);Interface.Resize(ui);task.wait(.05)
   assert(ui.PlayerHUD.Card.AbsolutePosition.X+ui.PlayerHUD.Card.AbsoluteSize.X<ui.OpponentHUD.Card.AbsolutePosition.X,"Cards overlap")
   assert(ui.ShopModal.AbsoluteSize.X<=size.X and ui.ShopModal.AbsoluteSize.Y<=size.Y,"Modal bounds")
   assert(ui.Buttons.LeftHand.AbsoluteSize.Y>=44,"Touch target")
   assert(ui.SettingsButton.AbsoluteSize.Y>=44 and ui.ShopButton.AbsoluteSize.Y>=44,"Menu touch target")
   assert(not ui.PositionPill.Container.Visible and ui.PlayerHUD.Card.AbsoluteSize.Y<=80,"Compact HUD")
   assert(math.abs(ui.MatchBanner.AbsolutePosition.Y-ui.Root.AbsolutePosition.Y-8)<1,"Timer is not at screen top")
   local function overlaps(a,b)
    return a.AbsolutePosition.X<b.AbsolutePosition.X+b.AbsoluteSize.X and b.AbsolutePosition.X<a.AbsolutePosition.X+a.AbsoluteSize.X and a.AbsolutePosition.Y<b.AbsolutePosition.Y+b.AbsoluteSize.Y and b.AbsolutePosition.Y<a.AbsolutePosition.Y+a.AbsoluteSize.Y
   end
   for _,handed in {false,true} do
    Interface.Layout(ui,handed);task.wait(.05)
    assert(not overlaps(ui.ShopButton,ui.Stick) and not overlaps(ui.SettingsButton,ui.Stick),"Menu overlaps movement control")
    for _,b in ui.Buttons do assert(not overlaps(ui.ShopButton,b) and not overlaps(ui.SettingsButton,b),"Menu overlaps action control") end
   end
   Interface.Layout(ui,false)
   local a,b=ui.Stick,ui.Pad
   assert(a.AbsolutePosition.X+a.AbsoluteSize.X<=b.AbsolutePosition.X or b.AbsolutePosition.X+b.AbsoluteSize.X<=a.AbsolutePosition.X
    or a.AbsolutePosition.Y+a.AbsoluteSize.Y<=b.AbsolutePosition.Y or b.AbsolutePosition.Y+b.AbsoluteSize.Y<=a.AbsolutePosition.Y,"Touch overlap")
  end
  ui.Root.Size=original;Interface.Resize(ui)
  ui.ShopModal.Visible=true;input:RefreshEnabled();assert(not input.enabled,"Modal capture")
  ui.ShopModal.Visible=false;input:RefreshEnabled()
  local context=Shared.CageboundMovementLab
  -- Let the engine finish disabling/re-enabling InputContext after modal capture.
  -- A synthetic press in that same turn can be cleared by the pending reset.
  task.wait(.25)
  context.Guard.Touch:Fire(false);task.wait(.1)
  context.Guard.Touch:Fire(true)
  untilTrue(function() return input.guard end,"Touch guard local state; context="..tostring(context.Enabled)..", enabled="..tostring(input.enabled))
  untilTrue(function() return own() and own().combat.guard end,"Touch guard authoritative state")
  context.Guard.Touch:Fire(false);untilTrue(function() return not own().combat.guard end,"Touch release")
  return {layouts="1440x900,844x390,390x844",touchBindings=true}
 elseif command=="Queue" then net:FireServer({action="Enqueue",mode="Ranked1v1"});return "Enqueued"
 elseif command=="Cancel" then net:FireServer({action="Dequeue"});return "Cancelled"
 elseif command=="Combat" or command=="Rapid" then
  untilTrue(function() return prediction.match and prediction.match.phase=="InRound" and own() end,"Round starts")
  qa.diagnostics:Reset()
  local before=own().combat.serial
  local context=Shared.CageboundMovementLab
  local started=os.clock()
  while os.clock()-started<18 do
   context.Move.Touch:Fire(Vector2.new(if math.floor(os.clock()-started)%6<3 then .45 else -.45,0))
   input:Request("LeftHand","Primary",true)
   if command=="Rapid" then for _=1,80 do input:Request("RightHand","Primary",true) end end
   task.wait(if command=="Rapid" then .15 else .7)
  end
  context.Move.Touch:Fire(Vector2.zero)
  task.wait(1)
  assert(own().combat.serial>before,"No server-confirmed strikes")
  assert(#prediction.pending<=120 and #input.queue<=8,"Input backlog unbounded")
  local result=qa.diagnostics:Report();result.acceptedStrikes=own().combat.serial-before
  return result
 elseif command=="Leave" then
  -- The server kicks only after this report. LeaveTest can put the Studio test
  -- controller into idle/teardown before AddPlayers starts the replacement.
  return "Ready for server-owned disconnect"
 end
 error("Unknown command")
end
local runningCommands,completed,completionOrder={},{},{}
net.OnClientEvent:Connect(function(payload)
 if payload.action~="QACommand" or type(payload.requestId)~="string" then return end
 local requestId=payload.requestId
 if completed[requestId] then
  report(payload.command,requestId,completed[requestId].ok,completed[requestId].result);return
 end
 if runningCommands[requestId] then return end
 print("[Cagebound QA12 Client] Received "..payload.command.." request="..requestId.." user="..Players.LocalPlayer.UserId)
 runningCommands[requestId]=true
 task.spawn(function()
  local ok,result=xpcall(function() return run(payload.command,requestId) end,debug.traceback)
  print("[Cagebound QA12 Client] "..payload.command.." "..(if ok then "PASS " else "FAIL ")..game:GetService("HttpService"):JSONEncode(result))
  runningCommands[requestId]=nil
  completed[requestId]={ok=ok,result=result};table.insert(completionOrder,requestId)
  if #completionOrder>64 then completed[table.remove(completionOrder,1)]=nil end
  report(payload.command,requestId,ok,result)
 end)
end)
untilTrue(function() return prediction.state~=nil and input.enabled end,"Snapshots and controller ready",90)
net:FireServer({action="QAReady"})
print("[Cagebound QA12 Client] Ready sent user="..Players.LocalPlayer.UserId)
