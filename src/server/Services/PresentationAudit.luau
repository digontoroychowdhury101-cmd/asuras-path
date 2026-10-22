--!strict
-- Read-only Studio inspection. Instance counts are not a measurement of GPU draw calls.
local Audit = {}
function Audit.Run(root: Instance): any
	local result: any = {Parts=0,Meshes=0,Surfaces=0,Decorative=0,Emitters=0,UniqueMeshes=0,UniqueMaps=0,Issues={}}
	local meshes, maps = {}, {}
	for _, item in root:GetDescendants() do
		if item:IsA("BasePart") then
			result.Parts += 1
			if item:GetAttribute("AsuraDecorative") then
				result.Decorative += 1
				if not item.Anchored or item.CanCollide or item.CanTouch or item.CanQuery then
					table.insert(result.Issues,item:GetFullName() .. ": decorative physics enabled")
				end
			end
		end
		if item:IsA("MeshPart") then
			result.Meshes += 1; meshes[item.MeshId]=true
			local s = item:FindFirstChildOfClass("SurfaceAppearance")
			if not s then table.insert(result.Issues,item:GetFullName() .. ": missing SurfaceAppearance")
			else
				result.Surfaces += 1
				for _, key in {"ColorMap","NormalMap","RoughnessMap","MetalnessMap"} do
					local content = (s :: any)[key.."Content"]
					local id = content and content.Uri
					if not id or id == "" then table.insert(result.Issues,item:GetFullName() .. ": missing " .. key) else maps[id]=true end
				end
			end
		elseif item:IsA("ParticleEmitter") then
			result.Emitters += 1
			if item.Enabled and (item.Texture == "" or string.find(item.Texture,"rbxasset://textures/particles",1,true)) then
				table.insert(result.Issues,item:GetFullName() .. ": untextured/stock emitter")
			end
		end
	end
	for _ in meshes do result.UniqueMeshes += 1 end
	for _ in maps do result.UniqueMaps += 1 end
	local ok, memory = pcall(function() return game:GetService("Stats"):GetTotalMemoryUsageMb() end)
	result.TotalMemoryMb = if ok then memory else nil
	result.Uncompressed1024MapEstimateMb = result.UniqueMaps * 4 -- estimate; compression/mips vary by device
	print("[Asura AV Audit] " .. game:GetService("HttpService"):JSONEncode(result))
	return result
end
return Audit
