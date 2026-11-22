local points = game.HttpService:JSONDecode(assert(workspace:GetAttribute("SolBasinRoutePoints")))
local player = assert(game.Players:GetPlayers()[1])
local character = assert(player.Character)
local humanoid = assert(character:FindFirstChildWhichIsA("Humanoid"))
local root = assert(character:FindFirstChild("HumanoidRootPart"))
local first = points[1]
local pos = Vector3.new(first.X, first.Y + humanoid.HipHeight + root.Size.Y / 2 + .3, first.Z)
root.Anchored = true
root.CFrame = CFrame.lookAt(pos, pos + Vector3.new(points[2].X - first.X, 0, points[2].Z - first.Z))
root.AssemblyLinearVelocity = Vector3.zero
root.AssemblyAngularVelocity = Vector3.zero
root.Anchored = false
return { points = #points, start = tostring(root.Position) }
