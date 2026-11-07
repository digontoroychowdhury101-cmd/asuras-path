-- Reads mesh and PBR map ids from uploaded Model assets (Studio Edit; nothing is parented or saved).
-- ASSETS_JSON is replaced with {"PieceName": assetId, ...}. Returns JSON: name -> {asset, mesh, size, color, normal, roughness, metalness}.
local HS = game:GetService("HttpService")
local IS = game:GetService("InsertService")
local wanted = HS:JSONDecode([[ASSETS_JSON]])
local out = {}
local function id(content)
	local uri = if typeof(content) == "string" then content else (content and content.Uri) or ""
	return tonumber(string.match(uri, "%d+$"))
end
for name, asset in wanted do
	local ok, model = pcall(function() return IS:LoadAsset(asset) end)
	if not ok then out[name] = { asset = asset, error = tostring(model) } continue end
	local mp = model:FindFirstChildWhichIsA("MeshPart", true)
	local sa = mp and mp:FindFirstChildOfClass("SurfaceAppearance")
	if not mp or not sa then out[name] = { asset = asset, error = "no MeshPart/SurfaceAppearance" } model:Destroy() continue end
	out[name] = { asset = asset, mesh = id(mp.MeshContent) or id(mp.MeshId), size = { mp.Size.X, mp.Size.Y, mp.Size.Z },
		color = id(sa.ColorMapContent) or id(sa.ColorMap), normal = id(sa.NormalMapContent) or id(sa.NormalMap),
		roughness = id(sa.RoughnessMapContent) or id(sa.RoughnessMap), metalness = id(sa.MetalnessMapContent) or id(sa.MetalnessMap),
		pivotOffset = { mp.Position.X - model:GetPivot().Position.X, mp.Position.Y - model:GetPivot().Position.Y, mp.Position.Z - model:GetPivot().Position.Z } }
	model:Destroy()
end
return HS:JSONEncode(out)
