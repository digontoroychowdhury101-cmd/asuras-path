local L = game:GetService("Lighting")
local a = L:FindFirstChildOfClass("Atmosphere")
a.Density, a.Haze, a.Offset = 0.1, 0.4, 0.1
local n = 0
for _, d in workspace.Sanctuary:GetDescendants() do
	if d:IsA("BasePart") and d.Name == "StillWater" then
		d.Material = Enum.Material.SmoothPlastic
		d.Color = Color3.fromRGB(38, 86, 82)
		d.Transparency = 0.32
		d.Reflectance = 0.22
		n += 1
	end
end
return "water " .. n
