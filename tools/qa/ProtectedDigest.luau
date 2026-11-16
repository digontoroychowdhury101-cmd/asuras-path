--!strict
-- Studio Command Bar / execute_luau (Edit) utility; strictly read-only (no writes, no Play, no save).
-- PROPERTY digest of the protected collections: ServerStorage.AsuraLobbyKit, ServerStorage.AsuraAssets, MaterialService.
-- Prints and returns one line per collection: "<name> instances N digest D" (N includes the root).
--
-- Method (v1, 2026-11-16; Mac+Windows comparable; NOT the unrecorded Windows method 129/308331669, 1443/442941466, 13/306913035):
--  * Traversal: root + GetDescendants, sorted by (GetFullName, ClassName, sibling index among the parent's children).
--  * Record per instance, fields joined by "|": full name, class, sibling index, then "key=value" pairs in the fixed order below.
--      all:             Name (in full name), ClassName, sorted attributes "@name=type:value"
--      BasePart:        Size, CFrame (12 comps), Material, Color, Transparency, Reflectance, Anchored, CanCollide, MaterialVariant
--      MeshPart:        MeshId, TextureID, TextureContent (Uri), RenderFidelity, CollisionFidelity
--      SpecialMesh:     MeshId, TextureId, Scale, Offset, MeshType
--      Decal/Texture:   Texture, Color3, Transparency, Face (+ StudsPerTile for Texture)
--      SurfaceAppearance: ColorMap, NormalMap, MetalnessMap, RoughnessMap, AlphaMode, Color
--      MaterialVariant: BaseMaterial, ColorMap, NormalMap, MetalnessMap, RoughnessMap, StudsPerTile, MaterialPattern
--      MaterialService: Use2022Materials
--      Model:           PrimaryPart full name; ValueBase: Value
--    Numbers use "%.3f" (-0 -> 0); Color3 as 0-255 ints; unreadable/inapplicable properties are skipped (not hashed).
--  * Hash: h = (h*31 + byte) % 2147483647 over record .. "\n" for each instance in order (same rolling hash as SourceDigest.luau).
-- Usage: run unchanged in execute_luau, datamodel Edit. Compare the three printed lines between machines.
local function n(x: number): string
	local s = string.format("%.3f", x)
	return if s == "-0.000" then "0.000" else s
end
local function val(v: any): string
	local t = typeof(v)
	if t == "number" then return n(v)
	elseif t == "Vector3" then return n(v.X) .. "," .. n(v.Y) .. "," .. n(v.Z)
	elseif t == "Vector2" then return n(v.X) .. "," .. n(v.Y)
	elseif t == "Color3" then return string.format("%d,%d,%d", math.round(v.R * 255), math.round(v.G * 255), math.round(v.B * 255))
	elseif t == "CFrame" then
		local c = { v:GetComponents() }
		for i, x in c do c[i] = n(x) end
		return table.concat(c, ",")
	elseif t == "Content" then return tostring(v.Uri or "")
	elseif t == "Instance" then return v:GetFullName()
	end
	return tostring(v)
end

local LISTS: { { any } } = {
	{ "BasePart", { "Size", "CFrame", "Material", "Color", "Transparency", "Reflectance", "Anchored", "CanCollide", "MaterialVariant" } },
	{ "MeshPart", { "MeshId", "TextureID", "TextureContent", "RenderFidelity", "CollisionFidelity" } },
	{ "SpecialMesh", { "MeshId", "TextureId", "Scale", "Offset", "MeshType" } },
	{ "Decal", { "Texture", "Color3", "Transparency", "Face" } },
	{ "Texture", { "StudsPerTileU", "StudsPerTileV" } },
	{ "SurfaceAppearance", { "ColorMap", "NormalMap", "MetalnessMap", "RoughnessMap", "AlphaMode", "Color" } },
	{ "MaterialVariant", { "BaseMaterial", "ColorMap", "NormalMap", "MetalnessMap", "RoughnessMap", "StudsPerTile", "MaterialPattern" } },
	{ "MaterialService", { "Use2022Materials" } },
	{ "Model", { "PrimaryPart" } },
	{ "ValueBase", { "Value" } },
}

local function record(inst: Instance, idx: number): string
	local parts = { inst:GetFullName(), inst.ClassName, tostring(idx) }
	for _, e in LISTS do
		if inst:IsA(e[1]) then
			for _, p in e[2] do
				local ok, v = pcall(function() return (inst :: any)[p] end)
				if ok then table.insert(parts, p .. "=" .. val(v)) end
			end
		end
	end
	local attrs = inst:GetAttributes()
	local names = {}
	for k in attrs do table.insert(names, k) end
	table.sort(names)
	for _, k in names do table.insert(parts, "@" .. k .. "=" .. typeof(attrs[k]) .. ":" .. val(attrs[k])) end
	return table.concat(parts, "|")
end

local function digest(label: string, root: Instance?): string
	if not root then return label .. " MISSING" end
	local items: { Instance } = { root }
	for _, d in root:GetDescendants() do table.insert(items, d) end
	local rows = {}
	for i, inst in items do
		local idx = 0
		if inst.Parent then idx = table.find(inst.Parent:GetChildren(), inst) or 0 end
		table.insert(rows, { inst:GetFullName(), inst.ClassName, idx, record(inst, idx) })
		if i % 100 == 0 then task.wait() end
	end
	table.sort(rows, function(a, b)
		if a[1] ~= b[1] then return a[1] < b[1] end
		if a[2] ~= b[2] then return a[2] < b[2] end
		return a[3] < b[3]
	end)
	local h = 0
	for i, row in rows do
		local s: string = row[4] .. "\n"
		for j = 1, #s, 4096 do
			for _, b in { string.byte(s, j, math.min(j + 4095, #s)) } do h = (h * 31 + b) % 2147483647 end
		end
		if i % 100 == 0 then task.wait() end
	end
	return string.format("%s instances %d digest %d", label, #rows, h)
end

local SS = game:GetService("ServerStorage")
local out = {
	digest("ServerStorage.AsuraLobbyKit", SS:FindFirstChild("AsuraLobbyKit")),
	digest("ServerStorage.AsuraAssets", SS:FindFirstChild("AsuraAssets")),
	digest("MaterialService", game:GetService("MaterialService")),
}
local summary = table.concat(out, "\n")
print(summary)
return summary
