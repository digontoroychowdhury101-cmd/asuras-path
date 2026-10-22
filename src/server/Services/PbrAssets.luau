--!strict
-- Static dressing shares uploaded meshes/maps. Missing/invalid imports preserve existing geometry.
local ServerStorage = game:GetService("ServerStorage")
local Pbr = {}
function Pbr.validate(model: Model): (boolean, string?)
	local count = 0
	for _, item in model:GetDescendants() do
		if not item:IsA("MeshPart") then continue end
		count += 1
		local surface = item:FindFirstChildOfClass("SurfaceAppearance")
		if not surface then return false, item.Name .. ": missing SurfaceAppearance" end
		-- Legacy *Map strings require Plugin security; *MapContent is readable in live servers.
		for _, key in {"ColorMapContent","NormalMapContent","RoughnessMapContent","MetalnessMapContent"} do
			local content = (surface :: any)[key]
			if not content or not content.Uri or content.Uri == "" then return false, item.Name .. ": incomplete PBR maps" end
		end
	end
	return count > 0, if count == 0 then "no MeshParts" else nil
end
function Pbr.place(parent: Instance, name: string, floor: CFrame, target: number, axis: string?, proxy: Instance?): Model?
	local library = ServerStorage:FindFirstChild("AsuraAssets")
	local template = library and library:FindFirstChild(name)
	if not template or not template:IsA("Model") then return nil end
	local ok, reason = Pbr.validate(template)
	if not ok then warn("[Asura PBR] " .. name .. " skipped: " .. tostring(reason)); return nil end
	local model = template:Clone()
	local size = model:GetExtentsSize()
	local current = if axis == "Longest" then math.max(size.X,size.Y,size.Z) elseif axis == "X" then size.X elseif axis == "Z" then size.Z else size.Y
	if current < 0.001 then model:Destroy(); return nil end
	model:ScaleTo(model:GetScale() * target / current)
	model:PivotTo(floor)
	local box, extents = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + Vector3.yAxis * (floor.Position.Y - box.Position.Y + extents.Y/2))
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored, item.CanCollide, item.CanQuery, item.CanTouch = true, false, false, false
			item:SetAttribute("AsuraDecorative", true)
			-- RenderFidelity is authored on the imported template; runtime writes are restricted.
		end
	end
	model:SetAttribute("AsuraPbr", true); model.Parent = parent
	-- Preserve movement surfaces as invisible, simple collision proxies.
	if proxy then
		local parts = proxy:GetDescendants()
		if proxy:IsA("BasePart") then table.insert(parts, proxy) end
		for _, item in parts do
			if item:IsA("BasePart") then item.Transparency = 1; item.CastShadow = false end
		end
	end
	return model
end
return Pbr
