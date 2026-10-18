--!nonstrict
-- Local Studio benchmark only; production controllers still run from BindToRenderStep.
local RunService=game:GetService("RunService")
assert(RunService:IsStudio(),"Never publish the foreground benchmark place")
local Players=game:GetService("Players")
local Http=game:GetService("HttpService")
local function untilTrue(fn,message,seconds)
 local deadline=os.clock()+seconds
 repeat task.wait(.1) until fn() or os.clock()>deadline
 assert(fn(),message)
end
local ok,err=xpcall(function()
 untilTrue(function() return _G.CageboundDiagnostics~=nil end,"Diagnostics ready",180)
 local d=_G.CageboundDiagnostics
 assert(d.driver=="RenderStep","Heartbeat cannot certify this benchmark")
 local gui=Players.LocalPlayer.PlayerGui
 untilTrue(function() return gui:FindFirstChild("CageboundFrontEnd")~=nil end,"Menu ready",180)
 local front=gui.CageboundFrontEnd
 front.FrontEnd.Visible=false;front.ReturnToLobby.Visible=true
 local shared=game:GetService("ReplicatedStorage").Cagebound
 untilTrue(function() return shared:FindFirstChild("CageboundMovementLab")~=nil end,"Native controller ready",120)
 local context=shared.CageboundMovementLab
 print("[Cagebound Native Benchmark] READY: focus the client viewport; collecting only observed foreground frames")
 untilTrue(function() return d.foreground and context.Enabled end,"Observed client focus",300)
 d:Reset()
 local attempted=0;local started=os.clock();local deadline=started+240
 while attempted<160 and os.clock()<deadline do
  if d.foreground and context.Enabled then
   local action=if attempted%2==0 then context.LeftHand else context.RightHand
   action.Touch:Fire(true);task.wait(.03);action.Touch:Fire(false)
   attempted+=1;task.wait(.7)
  else task.wait(.1) end
 end
 task.wait(1)
 local r=d:Report();r.attempted=attempted;r.kind="normal RenderStep controller; scripted InputBinding actions; Studio foreground; not physical input latency"
 r.sufficient=r.foregroundFrameMs.n>=900 and r.foregroundSampleSeconds>=30 and r.foregroundInputToPreviewMs.n>=100 and r.foregroundServerResolutionMs.n>=100
 r.performancePassed=r.sufficient and r.foregroundFrameMs.p95<=33.3 and r.foregroundInputToPreviewMs.p95<=50 and r.foregroundCorrectionStuds.max<=3
 -- Studio truncates long output lines. Keep a complete snapshot and chunk the JSON.
 _G.CageboundNativeBenchmarkResult=r
 local encoded=Http:JSONEncode(r);local runId=Http:GenerateGUID(false)
 local chunks=math.ceil(#encoded/650)
 print("[Cagebound Native Benchmark] REPORT_BEGIN "..runId.." "..chunks)
 for i=1,chunks do print("[Cagebound Native Benchmark] REPORT_CHUNK "..runId.." "..i.." "..encoded:sub((i-1)*650+1,i*650)) end
 print("[Cagebound Native Benchmark] REPORT_END "..runId)
 assert(r.sufficient,"Insufficient real foreground samples")
 print("[Cagebound Native Benchmark] "..(if r.performancePassed then "PASS" else "FAIL: measured performance exceeds proposed threshold"))
end,debug.traceback)
if not ok then warn("[Cagebound Native Benchmark] FAIL "..tostring(err)) end
