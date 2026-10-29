-- Studio Client diagnostic only. Temporary tagged plant is always destroyed. No saved settings,
-- gameplay, geometry, quality or wind changes. Test with the normal FoliageWind controller running.
local player = game.Players.LocalPlayer
local tags = game:GetService("CollectionService")
local initial, cached = player:GetAttribute("FoliageRegistered"), player:GetAttribute("FoliageCachedParts")
assert(type(initial) == "number" and type(cached) == "number", "wait for foliage controller metrics")
local model = Instance.new("Model")
model.Name = "TemporaryWindLifecycleDiagnostic"
local camera = workspace.CurrentCamera
local base = CFrame.new(camera.CFrame.Position + camera.CFrame.LookVector * 20)
model:SetAttribute("WindBase", base)
model:SetAttribute("WindHeight", 4)
model:SetAttribute("WindKind", "Bamboo")
model.Parent = workspace
tags:AddTag(model, "AsuraWindPlant")
local result = { initial = initial, cachedBefore = cached }
local ok, err = xpcall(function()
	task.wait(0.35) -- tag arrives before parts
	local function latePart(name, x)
		local p = Instance.new("Part")
		p.Name, p.Size, p.CanCollide = name, Vector3.new(0.2, 4, 0.2), false
		p.CFrame = base * CFrame.new(x, 2, 0)
		p.Parent = model
		task.wait(0.3) -- Anchored arrives after the part
		p.Anchored = true
		task.wait(1.2)
		return p
	end
	local a = latePart("LateCulmA", 0)
	local b = latePart("LateCulmB", 1) -- existing ready parts must not mask another late property
	result.added, result.cachedAdded = player:GetAttribute("FoliageRegistered"), player:GetAttribute("FoliageCachedParts")
	local af, bf = a.CFrame, b.CFrame
	task.wait(1.3)
	result.firstPositionDelta, result.secondPositionDelta = (a.Position - af.Position).Magnitude, (b.Position - bf.Position).Magnitude
	assert(result.added == initial + 1 and result.cachedAdded == cached + 2, "late parts were not registered")
	assert(result.firstPositionDelta > 0.00001 and result.secondPositionDelta > 0.00001, "late parts stayed static")
	for i = 1, 2 do
		model.Parent = nil
		task.wait(1.2)
		result["removed" .. i] = player:GetAttribute("FoliageRegistered")
		assert(result["removed" .. i] == initial, "exit accumulated a registration")
		model.Parent = workspace
		task.wait(1.2)
		result["reentered" .. i] = player:GetAttribute("FoliageRegistered")
		assert(result["reentered" .. i] == initial + 1, "reentry duplicated or lost a registration")
	end
	a:Destroy(); b:Destroy()
	task.wait(1.2)
	result.cachedAfterPartRemoval = player:GetAttribute("FoliageCachedParts")
	assert(result.cachedAfterPartRemoval == cached, "removed parts stayed cached")
end, debug.traceback)
model:Destroy()
task.wait(1.2)
result.final, result.cachedFinal = player:GetAttribute("FoliageRegistered"), player:GetAttribute("FoliageCachedParts")
result.ok, result.error = ok, err
assert(result.final == initial and result.cachedFinal == cached, "cleanup changed registry size")
return game:GetService("HttpService"):JSONEncode(result)
