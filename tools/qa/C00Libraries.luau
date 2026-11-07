--!strict
-- C00 intake probe (Edit, read-only): every ServerStorage library piece by exact name, class, bounding
-- size (studs, as stored) and part count. Output: JSON.
local HS = game:GetService("HttpService")
local function r2(v: number): number return math.floor(v * 100 + 0.5) / 100 end
local out = {}
for _, lib in game:GetService("ServerStorage"):GetChildren() do
	local items = {}
	for _, c in lib:GetChildren() do
		local size: Vector3? = nil
		if c:IsA("Model") then local _, s = c:GetBoundingBox(); size = s elseif c:IsA("BasePart") then size = c.Size end
		local parts = 0
		for _, d in c:GetDescendants() do if d:IsA("BasePart") then parts += 1 end end
		if c:IsA("BasePart") then parts += 1 end
		table.insert(items, { name = c.Name, class = c.ClassName, size = if size then { r2(size.X), r2(size.Y), r2(size.Z) } else nil, parts = parts })
	end
	table.sort(items, function(a, b) return a.name < b.name end)
	out[lib.Name] = items
end
return HS:JSONEncode(out)
