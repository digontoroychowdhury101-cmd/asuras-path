-- Running Client diagnostic: rendered triangle/draw-call composition of the v9 Bamboo slice additions
-- (present vs hidden client-side) at the moon-gate and arena capture cameras. Composition does not
-- depend on frame pacing, so it stays valid when Studio is background-throttled. Restores everything.
local Run = game:GetService("RunService")
local map = workspace:FindFirstChild("Map_BambooPass")
assert(map, "Bamboo map missing")
local NEW = { MoonCoping = true, MoonJambShell = true, MoonPlinth = true, MoonImpost = true, ParapetCoping = true }
local stash = Instance.new("Folder")
local moved = {}
local function hide()
	local south = map:FindFirstChild("LivingBambooSouth", true)
	if south then table.insert(moved, { south, south.Parent }) south.Parent = stash end
	for _, d in map.PassDressing:GetChildren() do
		if NEW[d.Name] then table.insert(moved, { d, map.PassDressing }) d.Parent = stash end
	end
end
local function show()
	for i = #moved, 1, -1 do moved[i][1].Parent = moved[i][2] end
	table.clear(moved)
end
local function flat(node, prefix, out)
	out[prefix .. node.Name] = node.Sizes
	for _, child in node.Children or {} do flat(child, prefix .. node.Name .. "/", out) end
end
local cam = workspace.CurrentCamera
local saved = { cam.CameraType, cam.CFrame, cam.FieldOfView }
local result = {}
local ok, err = pcall(function()
	for _, view in { { "moon_gate", Vector3.new(1.8, 6.5, -1550), Vector3.new(0, 12, -1597) },
		{ "arena", Vector3.new(1.8, 6.5, -1374), Vector3.new(0, 6, -1460) } } do
		local frame = CFrame.lookAt(view[2], view[3])
		Run:BindToRenderStep("AsuraSliceComposition", Enum.RenderPriority.Last.Value + 50, function()
			cam.CameraType = Enum.CameraType.Scriptable cam.FieldOfView = 70 cam.CFrame = frame
		end)
		for _, state in { "present", "hidden" } do
			if state == "hidden" then hide() end
			task.wait(2.5)
			local out = {}
			flat(game:GetService("SceneAnalysisService"):GetTriangleCompositionAsync(), "", out)
			result[view[1] .. "_" .. state] = out
			show()
		end
		Run:UnbindFromRenderStep("AsuraSliceComposition")
	end
end)
show()
Run:UnbindFromRenderStep("AsuraSliceComposition")
cam.CameraType, cam.CFrame, cam.FieldOfView = saved[1], saved[2], saved[3]
stash:Destroy()
assert(ok, err)
return game:GetService("HttpService"):JSONEncode(result)
