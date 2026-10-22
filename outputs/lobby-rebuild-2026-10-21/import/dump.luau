local HttpService = game:GetService("HttpService")
local m = workspace:FindFirstChild("AsuraLobbyK") or workspace:FindFirstChild("AsuraLobbyKit")
local rows = {}
for _, d in m:GetDescendants() do
	if d:IsA("MeshPart") then
		local s = d:FindFirstChildOfClass("SurfaceAppearance")
		local p = d.Position
		table.insert(rows, {
			name = d.Name, parent = d.Parent.Name, parentClass = d.Parent.ClassName,
			mesh = d.MeshId, texture = d.TextureID,
			size = { d.Size.X, d.Size.Y, d.Size.Z }, pos = { p.X, p.Y, p.Z },
			rot = { d.CFrame:ToOrientation() },
			sa = s and { Color = s.ColorMap, Normal = s.NormalMap, Roughness = s.RoughnessMap, Metalness = s.MetalnessMap } or nil,
			fidelity = d.RenderFidelity.Name, collision = d.CollisionFidelity.Name, double = d.DoubleSided,
		})
	end
end
local pivot = m:GetPivot().Position
return HttpService:JSONEncode({ model = m.Name, pivot = { pivot.X, pivot.Y, pivot.Z }, parts = rows })
