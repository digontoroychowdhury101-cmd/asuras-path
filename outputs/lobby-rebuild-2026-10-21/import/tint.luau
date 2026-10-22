local tints = { Stone = Color3.new(0.68, 0.7, 0.73), Lacquer = Color3.new(0.6, 0.4, 0.38), Paving = Color3.new(0.8, 0.82, 0.85),
	Rock = Color3.new(0.86, 0.84, 0.82), Roof = Color3.new(0.94, 0.95, 1), Timber = Color3.new(1, 1, 1), Bronze = Color3.new(1, 1, 1), Foliage = Color3.new(0.8, 0.62, 0.6) }
local n = 0
for _, d in game:GetService("ServerStorage").AsuraLobbyKit:GetDescendants() do
	if d:IsA("SurfaceAppearance") then
		local material = string.match(d.Parent.Name, "__(%a+)$")
		if material and tints[material] then d.Color = tints[material]; n += 1 end
	end
end
return "tinted " .. n
