-- Read-only snapshot for the opening walk: run in the Client datamodel through execute_luau (Studio, local QA only).
-- Reports what the player actually sees: the objective card, marker distance, prompts in reach, purse and milestones.
-- Evidence type: Studio read of the running client. It moves nothing and grants nothing.
local Players = game:GetService("Players")
local p = Players.LocalPlayer
local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
local gui = p:FindFirstChild("PlayerGui")
local out = {}
local function add(k, v) table.insert(out, k .. "=" .. tostring(v)) end
if root then add("pos", string.format("%.0f,%.0f,%.0f", root.Position.X, root.Position.Y, root.Position.Z)) end
for _, a in { "AsuraRegion", "AsuraEssence", "AsuraUnbanked", "AsuraOre", "AsuraOpening", "AsuraTutorial", "AsuraAltars", "AsuraMainhand", "AsuraReinforce", "AsuraBloodstain" } do
	add(string.sub(a, 6), p:GetAttribute(a))
end
local tracker = gui and gui:FindFirstChild("ObjectiveTracker", true)
if tracker then
	local parts = {}
	for _, c in tracker:GetChildren() do
		if c:IsA("TextLabel") and c.Text ~= "" then table.insert(parts, c.Text) end
	end
	add("card", tracker.Visible and table.concat(parts, " | ") or "hidden")
end
local dialogue = gui and gui:FindFirstChild("JadeDialogue")
if dialogue and dialogue.Enabled then
	local lines = {}
	for _, d in dialogue:GetDescendants() do
		if (d:IsA("TextButton") or d:IsA("TextLabel")) and d.Text ~= "" and d.Visible then
			table.insert(lines, (d:IsA("TextButton") and (d.Active and "[B] " or "[off] ") or "") .. string.gsub(d.Text, "\n", " / "))
		end
	end
	add("dialogue", table.concat(lines, " || "))
end
return table.concat(out, "\n")
