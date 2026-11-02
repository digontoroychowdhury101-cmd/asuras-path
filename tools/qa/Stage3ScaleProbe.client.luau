--!nonstrict
-- Unmapped Studio-only probe (combat recovery Stage 3A closure). Insert with tools/qa/qa_inject.py during Play, never save. Measures how far
-- the body moves for a Motor6D.Transform of one stud at model scale 1 and 2, which decides whether a presented step must be multiplied by
-- the model's scale. Scales the local character on this client only; restores it. Result in the LocalPlayer attribute AsuraStage3ScaleProbe.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local root = character:WaitForChild("HumanoidRootPart")
local pelvis = character:WaitForChild("LowerTorso")
local motor = pelvis:WaitForChild("Root")

local function offset(step)
	local written
	local connection = RunService.PreSimulation:Connect(function()
		motor.Transform = CFrame.new(0, 0, -step) * motor.Transform
	end)
	for _ = 1, 8 do
		RunService.PostSimulation:Wait()
	end
	written = root.CFrame:ToObjectSpace(pelvis.CFrame).Position.Z
	connection:Disconnect()
	return written
end

local rows = {}
for _, scale in { 1, 2 } do
	character:ScaleTo(scale)
	for _ = 1, 10 do
		RunService.PostSimulation:Wait()
	end
	local still = offset(0)
	local moved = offset(1)
	table.insert(rows, string.format("scale %d: 1-stud Transform moved the pelvis %.3f studs", scale, still - moved))
end
character:ScaleTo(1)
player:SetAttribute("AsuraStage3ScaleProbe", table.concat(rows, "; "))
