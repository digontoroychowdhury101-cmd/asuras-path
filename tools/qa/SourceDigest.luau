--!strict
-- Studio Command Bar / execute_luau (Edit) utility; read-only. Prints the script digest that
-- `python3 tools/studio_mcp.py --digest PLACE.rbxlx` computes for a built place.
local roots = { "Lighting", "Players", "ReplicatedFirst", "ReplicatedStorage", "ServerScriptService", "ServerStorage", "StarterPlayer", "Workspace" }
local rows = {}
for _, name in roots do
	for _, inst in game:GetService(name):GetDescendants() do
		local c = inst.ClassName
		if c == "Script" or c == "LocalScript" or c == "ModuleScript" then
			table.insert(rows, { inst:GetFullName(), (string.gsub((inst :: any).Source, "\r", "")) })
		end
	end
end
table.sort(rows, function(a, b) if a[1] ~= b[1] then return a[1] < b[1] end return a[2] < b[2] end)
local h, total = 0, 0
for i, row in rows do
	local s = row[1] .. "\0" .. row[2] .. "\0"
	total += #row[2]
	for j = 1, #s, 4096 do
		local bytes = { string.byte(s, j, math.min(j + 4095, #s)) }
		for _, b in bytes do h = (h * 31 + b) % 2147483647 end
	end
	if i % 40 == 0 then task.wait() end
end
local assets = game:GetService("ServerStorage"):FindFirstChild("AsuraAssets")
local summary = string.format("scripts %d bytes %d digest %d | AsuraAssets children %d | place %s", #rows, total, h, assets and #assets:GetChildren() or -1, game.Name)
print(summary)
return summary
