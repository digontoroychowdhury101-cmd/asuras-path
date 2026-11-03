--!nonstrict
-- Unmapped Studio-only probe (Gao prompt check, 2026-11-03): for AsuraPromptSeconds (default 4) it records, every
-- rendered frame, the root position, the camera's flat look direction and which Interact prompts Roblox is
-- showing (PromptShown/PromptHidden), so an approach to Master Smith Gao can be checked for "Speak" versus the
-- Transmutation Seal's "Transmute Remembrance". JSON lands in the player attribute AsuraPromptProbe.
-- Evidence type: Studio diagnostic of real movement input.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ProximityPromptService = game:GetService("ProximityPromptService")
if not RunService:IsStudio() then
	return
end
local player = Players.LocalPlayer
local SECONDS = tonumber(player:GetAttribute("AsuraPromptSeconds")) or 4
player:SetAttribute("AsuraPromptProbe", nil)
local shown: { [ProximityPrompt]: boolean } = {}
local connections = {
	ProximityPromptService.PromptShown:Connect(function(prompt) shown[prompt] = true end),
	ProximityPromptService.PromptHidden:Connect(function(prompt) shown[prompt] = nil end),
}
local function round(v: number): number
	return math.floor(v * 10 + 0.5) / 10
end
local t0, frames = os.clock(), {}
local step
step = RunService.RenderStepped:Connect(function()
	local t = os.clock() - t0
	if t > SECONDS then
		step:Disconnect()
		for _, c in connections do c:Disconnect() end
		player:SetAttribute("AsuraPromptProbe", HttpService:JSONEncode(frames))
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local names = {}
	for prompt in shown do table.insert(names, prompt.ActionText) end
	table.sort(names)
	local look = workspace.CurrentCamera.CFrame.LookVector
	local p = root.Position
	table.insert(frames, { t = round(t), p = { round(p.X), round(p.Z) }, cam = { round(look.X), round(look.Z) },
		shown = table.concat(names, "+") })
end)
