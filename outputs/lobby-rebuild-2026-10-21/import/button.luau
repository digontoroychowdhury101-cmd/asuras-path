local pg = game:GetService("Players").LocalPlayer.PlayerGui
local out = {}
for _, b in pg:GetDescendants() do
	if b:IsA("GuiButton") then
		local text = if b:IsA("TextButton") then b.Text else (b:FindFirstChildWhichIsA("TextLabel") and b:FindFirstChildWhichIsA("TextLabel").Text or "")
		if text == "Leave" or text == "Goodbye" or string.find(text, "Farewell") then
			table.insert(out, b:GetFullName())
		end
	end
end
return table.concat(out, "\n")
