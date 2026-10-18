-- Launch body for a temporary local Studio plugin (tools/build_studio_plugin.py).
-- Command Bar launch is retained for diagnostics; idle child editors are a known host failure.
-- Open the unpublished QA place in edit mode. No purchases and no publishing.
-- StudioTestService launches real server/client processes. Startup allowance is 10 minutes.
local network=settings().Network
local fields={"InboundNetworkMinDelayMs","OutboundNetworkMinDelayMs","InboundNetworkJitterMs","OutboundNetworkJitterMs","InboundNetworkLossPercent","OutboundNetworkLossPercent"}
local original={}
for _,field in fields do original[field]=network[field] end
task.spawn(function()
 local ok,err=xpcall(function()
  local failures={}
  for _,scenario in {{label="normal",delay=0,jitter=0,loss=0},{label="latency",delay=100,jitter=20,loss=1}} do
   network.InboundNetworkMinDelayMs=scenario.delay;network.OutboundNetworkMinDelayMs=scenario.delay
   network.InboundNetworkJitterMs=scenario.jitter;network.OutboundNetworkJitterMs=scenario.jitter
   network.InboundNetworkLossPercent=scenario.loss;network.OutboundNetworkLossPercent=scenario.loss
   local applied={}
   for _,field in fields do applied[field]=network[field] end
   print("[Cagebound QA12 Network]",game:GetService("HttpService"):JSONEncode({requested=scenario,applied=applied}))
   assert(applied.InboundNetworkMinDelayMs==scenario.delay and applied.OutboundNetworkMinDelayMs==scenario.delay,"Network delay not applied")
   assert(applied.InboundNetworkJitterMs==scenario.jitter and applied.OutboundNetworkJitterMs==scenario.jitter,"Network jitter not applied")
   -- Network Simulator caps loss at 0.5%. Run the supported impairment for useful
   -- evidence, but retain a failed requested-condition check in the final result.
   if applied.InboundNetworkLossPercent~=scenario.loss or applied.OutboundNetworkLossPercent~=scenario.loss then
    local mismatch=scenario.label..": requested loss "..scenario.loss.."%, applied "..applied.InboundNetworkLossPercent.."% inbound / "..applied.OutboundNetworkLossPercent.."% outbound"
    table.insert(failures,mismatch);warn("[Cagebound QA12 Network] "..mismatch)
   end
   local result=game:GetService("StudioTestService"):ExecuteMultiplayerTestAsync(2,{scenario=scenario,appliedNetwork=applied})
   print("[Cagebound QA12 ScenarioResult]",scenario.label,result)
   -- A failed/nil launch may leave an orphan child. Do not start another test
   -- or change its network conditions underneath it.
   assert(result=="QA12 PASS",scenario.label..": incomplete test result "..tostring(result).."; end leftover test windows before retrying")
   task.wait(15) -- Studio ends tests asynchronously; allow child teardown before the next launch.
  end
  assert(#failures==0,table.concat(failures,"\n"))
 end,debug.traceback)
 for _,field in fields do network[field]=original[field] end
 print("[Cagebound QA12 Settings] Network settings restored")
 if not ok then warn(err) end
end)
