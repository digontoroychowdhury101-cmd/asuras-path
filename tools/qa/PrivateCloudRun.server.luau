--!nonstrict
-- Opt-in private fixture runner. No combat hooks, client commands or purchase prompts.
local expected=require(script.Parent.PrivateValidationUniverse)
assert(expected>0 and game.GameId==expected,"Private cloud run universe mismatch")
if game:GetService("RunService"):IsStudio() or game.JobId=="" then return end
local Config=require(game:GetService("ReplicatedStorage").Cagebound.Config)
assert(not Config.Features.PaidPurchases and not Config.Release.PurchasesIntegrationPassed,"Purchases must stay disabled")
task.spawn(function()
 local ok,err=pcall(function() require(script.Parent.PrivateBackendValidation).Run(expected) end)
 workspace:SetAttribute("PrivateCloudRunFinished",true)
 workspace:SetAttribute("PrivateCloudRunPassed",ok)
 if not ok then warn("[Cagebound Cloud] LIVE RUN FAIL "..tostring(err)) end
end)
