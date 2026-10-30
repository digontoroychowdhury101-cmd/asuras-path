-- Read-only composition diagnostic except for temporary camera/LTM changes, always restored.
-- The hidden-hero measurements isolate rendered cost; they are never visual acceptance images.
-- Set _G.AsuraHeroCompositionViews to { {name, eye, target}, ... } before running in Client Play.
local Run = game:GetService("RunService")
local camera = workspace.CurrentCamera
local hero = workspace.Sanctuary.ColossusSanctuary.FusedTreeStatue
local views = assert(_G.AsuraHeroCompositionViews, "supply player-height views")
_G.AsuraHeroCompositionViews = nil
local original = { camera.CameraType, camera.CFrame, camera.FieldOfView }
local parts = {}
for _, p in hero:GetDescendants() do
	if p:IsA("BasePart") then table.insert(parts, { p, p.LocalTransparencyModifier }) end
end
local hidden, pose = false, camera.CFrame
Run:BindToRenderStep("AsuraHeroComposition", Enum.RenderPriority.Last.Value + 50, function()
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame, camera.FieldOfView = pose, 70
	if hidden then for _, row in parts do row[1].LocalTransparencyModifier = 1 end end
end)
local report = { kind = "Studio view-dependent rendered composition; no foreground timing claim", views = {} }
local ok, err = xpcall(function()
	for _, v in views do
		pose = CFrame.lookAt(v[2], v[3])
		local row = { name = v[1] }
		for _, mode in { "present", "hidden" } do
			hidden = mode == "hidden"
			for _, p in parts do p[1].LocalTransparencyModifier = if hidden then 1 else p[2] end
			task.wait(2)
			row[mode] = game:GetService("SceneAnalysisService"):GetTriangleCompositionAsync()
		end
		table.insert(report.views, row)
	end
end, debug.traceback)
Run:UnbindFromRenderStep("AsuraHeroComposition")
for _, row in parts do if row[1].Parent then row[1].LocalTransparencyModifier = row[2] end end
camera.CameraType, camera.CFrame, camera.FieldOfView = original[1], original[2], original[3]
if not ok then report.error = tostring(err) end
return game:GetService("HttpService"):JSONEncode(report)
