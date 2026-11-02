--!nonstrict
-- Unmapped Studio-only control (combat recovery Stage 3). Insert with tools/qa/qa_inject.py during Play, never save. Turns off
-- ActorPose's pose transition for this Play session, so a Stage2Timing run shows the clip's own first motion: the gap between
-- that run and an ordinary run is what the transition adds, and what is left is authored windup. Stop removes it.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end
local Pose = require(game:GetService("Players").LocalPlayer.PlayerScripts:WaitForChild("AsurasPath"):WaitForChild("Controllers"):WaitForChild("ActorPose"))
Pose.Transition = function() end
print("[QA] ActorPose transitions off for this Play session")
