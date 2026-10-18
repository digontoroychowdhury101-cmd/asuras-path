--!nonstrict
-- Instrumented device build ONLY. Local on-screen evidence; no remote telemetry.
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local deadline=os.clock()+120
repeat task.wait(.05) until _G.CageboundDiagnostics or os.clock()>deadline
local metrics=assert(_G.CageboundDiagnostics,"Diagnostics hook missing")
local gui=Instance.new("ScreenGui");gui.Name="CageboundDeviceMeasurements";gui.ResetOnSpawn=false;gui.DisplayOrder=100
local toggle=Instance.new("TextButton");toggle.Size=UDim2.fromOffset(112,44);toggle.Position=UDim2.new(.5,-56,0,110)
toggle.Text="METRICS";toggle.BackgroundColor3=Color3.fromRGB(20,25,30);toggle.TextColor3=Color3.new(1,1,1);toggle.Parent=gui
local panel=Instance.new("TextLabel");panel.Size=UDim2.fromOffset(300,145);panel.Position=UDim2.new(.5,-150,0,155)
panel.BackgroundColor3=Color3.fromRGB(10,14,18);panel.BackgroundTransparency=.1;panel.TextColor3=Color3.new(1,1,1)
panel.Font=Enum.Font.Code;panel.TextSize=13;panel.TextWrapped=true;panel.Parent=gui
local reset=Instance.new("TextButton");reset.Size=UDim2.fromOffset(112,44);reset.Position=UDim2.new(.5,-56,0,300)
reset.Text="RESET SAMPLE";reset.BackgroundColor3=Color3.fromRGB(20,25,30);reset.TextColor3=Color3.new(1,1,1);reset.Parent=gui
local visible=true
local sample=Instance.new("TextButton");sample.Size=UDim2.fromOffset(112,44);sample.Position=UDim2.new(.5,64,0,110)
sample.Text="ACTION SAMPLE";sample.BackgroundColor3=Color3.fromRGB(20,25,30);sample.TextColor3=Color3.new(1,1,1);sample.Parent=gui
local running=false;local sampleStatus="";local showWindows=false
local warm=Instance.new("TextButton");warm.Size=UDim2.fromOffset(112,44);warm.Text="WARM 10 MIN"
warm.BackgroundColor3=Color3.fromRGB(20,25,30);warm.TextColor3=Color3.new(1,1,1);warm.Parent=gui
local lastBegan="none"
UIS.InputBegan:Connect(function(input,processed) lastBegan=input.UserInputType.Name..(if processed then " UI" else " world") end)
local function runSample(isWarm)
 if running then return end
 local context=game:GetService("ReplicatedStorage").Cagebound:FindFirstChild("CageboundMovementLab")
 if not context or not context.Enabled then sampleStatus="Enter practice with controls enabled first";return end
 running=true;sample.Text="SAMPLING…";sampleStatus="Scripted InputBinding actions; no physical-touch claim"
 _G.CageboundDeviceBenchmarkResult=nil;showWindows=false
 task.spawn(function()
  metrics:Reset();local started=os.clock();local attempted=0;local windows={};local nextWindow=60;local lastFrames=0
  local target=if isWarm then 600 else 120
  while (if isWarm then os.clock()-started<target else attempted<160) and os.clock()-started<target+120 and gui.Parent do
   if context.Enabled then
    local action=if attempted%2==0 then context.LeftHand else context.RightHand
    action.Touch:Fire(true);task.wait(.03);action.Touch:Fire(false)
    attempted+=1;sample.Text=if isWarm then tostring(math.floor(os.clock()-started)).." / 600s" else tostring(attempted).." / 160";task.wait(.7)
   else task.wait(.1) end
   if isWarm and os.clock()-started>=nextWindow then
    local snap=metrics:Report()
    table.insert(windows,{seconds=os.clock()-started,freshFrames=snap.totalFrames-lastFrames,frameP95=snap.frameMs.p95,memoryMb=snap.memoryMb,previewN=snap.inputToPreviewMs.n,resolutionN=snap.serverResolutionMs.n})
    lastFrames=snap.totalFrames;nextWindow+=60
   end
  end
  task.wait(1)
  local r=metrics:Report();r.durationSeconds=os.clock()-started;r.attempted=attempted
  r.minuteWindows=windows;r.warm=isWarm
  r.kind="Scripted InputBinding actions on this client; not physical finger/display latency"
  r.sufficient=r.frameMs.n>=1800 and r.inputToPreviewMs.n>=100 and r.serverResolutionMs.n>=100
  if isWarm then
   r.sufficient=r.sufficient and #windows>=10
   for _,window in windows do r.sufficient=r.sufficient and window.freshFrames>=1800 end
  end
  _G.CageboundDeviceBenchmarkResult=r
  local Http=game:GetService("HttpService");local encoded=Http:JSONEncode(r);local run=Http:GenerateGUID(false)
  print("[Cagebound Device Sample] REPORT_BEGIN "..run.." "..math.ceil(#encoded/650))
  for i=1,math.ceil(#encoded/650) do print("[Cagebound Device Sample] REPORT_CHUNK "..run.." "..i.." "..encoded:sub((i-1)*650+1,i*650)) end
  print("[Cagebound Device Sample] REPORT_END "..run)
  sampleStatus=if r.sufficient then "Scripted sample complete; physical touch/heat still unverified" else "INSUFFICIENT sample — no pass"
  running=false;sample.Text="ACTION SAMPLE"
  if isWarm then warm.Text="MINUTE RESULTS" end
 end)
end
sample.Activated:Connect(function() runSample(false) end)
warm.Activated:Connect(function()
 local result=_G.CageboundDeviceBenchmarkResult
 if not running and result and result.warm then showWindows=not showWindows else runSample(true) end
end)
toggle.Activated:Connect(function() visible=not visible;panel.Visible=visible;reset.Visible=visible;warm.Visible=visible end)
reset.Activated:Connect(function() if not running then metrics:Reset();_G.CageboundDeviceBenchmarkResult=nil;showWindows=false;warm.Text="WARM 10 MIN" end end)
gui.Parent=Players.LocalPlayer:WaitForChild("PlayerGui")
local function value(distribution,key)
 if distribution.n==0 then return "N/A" end
 return string.format("%.1f",distribution[key])
end
while gui.Parent do
 task.wait(3)
 local frozen=not running and _G.CageboundDeviceBenchmarkResult
 local r=frozen or metrics:Report()
 local context=game:GetService("ReplicatedStorage").Cagebound:FindFirstChild("CageboundMovementLab")
 local panelY=math.min(155,math.max(68,workspace.CurrentCamera.ViewportSize.Y-310))
 panel.Position=UDim2.new(.5,-150,0,panelY);panel.Size=UDim2.fromOffset(300,175);panel.TextSize=11
 toggle.Position=UDim2.new(.5,-56,0,panelY-45);sample.Position=UDim2.new(.5,64,0,panelY-45)
 reset.Position=UDim2.new(.5,-56,0,panelY+175)
 warm.Position=UDim2.new(.5,64,0,panelY+175)
 panel.Text=string.format("%s | %s\nFrame p50/p95: %s / %s ms\nPreview p95: %s ms (%d)\nServer resolution p95: %s ms (%d)\nCorrection p95/max: %s / %s studs\nRoblox memory: %.0f MB | frames %d\nInput: %s / enabled=%s\n%s",
  if r.studio then "STUDIO CLIENT" else "ROBLOX CLIENT",r.viewport,value(r.frameMs,"p50"),value(r.frameMs,"p95"),
  value(r.inputToPreviewMs,"p95"),r.inputToPreviewMs.n,value(r.serverResolutionMs,"p95"),r.serverResolutionMs.n,
  value(r.correctionStuds,"p95"),value(r.correctionStuds,"max"),r.memoryMb,r.frameMs.n,lastBegan,tostring(context and context.Enabled),sampleStatus)
 if frozen then panel.Text="FROZEN SAMPLE / "..string.format("%.1fs",r.durationSeconds).."\n"..panel.Text end
 if showWindows and frozen then
  local lines={"10 MINUTE SAMPLE / rolling frame p95","Each row: seconds / ms / MB / new frames"}
  for _,window in r.minuteWindows do table.insert(lines,string.format("%ds / %.1f / %.0f / %d",window.seconds,window.frameP95 or -1,window.memoryMb,window.freshFrames)) end
  panel.Text=table.concat(lines,"\n")
 end
end
