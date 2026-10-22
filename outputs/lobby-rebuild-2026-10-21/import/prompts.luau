local pp = game:GetService("ProximityPromptService")
local player = game:GetService("Players").LocalPlayer
local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
local out = {}
for _, d in workspace:GetDescendants() do
	if d:IsA("ProximityPrompt") and d.Enabled and d.Parent:IsA("BasePart") and root then
		local dist = (d.Parent.Position - root.Position).Magnitude
		if dist < 20 then table.insert(out, string.format("%s[%s] d=%.1f max=%.0f key=%s", d.ActionText, d.Parent.Name, dist, d.MaxActivationDistance, d.KeyboardKeyCode.Name)) end
	end
end
local open = {}
for _, g in player.PlayerGui:GetDescendants() do
	if g:IsA("GuiObject") and g.Visible and (string.find(g.Name, "Altar") or string.find(g.Name, "Dialogue") or string.find(g.Name, "Menu")) then
		local anc, vis = g, true
		while anc and anc:IsA("GuiObject") do if not anc.Visible then vis = false end anc = anc.Parent end
		if vis and #open < 6 then table.insert(open, (g:GetFullName():gsub("Players%.%w+%.PlayerGui%.", ""))) end
	end
end
return table.concat(out, " | ") .. " || GUI: " .. table.concat(open, ", ")
