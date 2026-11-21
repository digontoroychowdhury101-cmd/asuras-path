--!strict
-- Open-world landmarks (LANDMARK-BUILD-SPEC): the uploaded kit pieces (LandmarkKitRegistry, placed by VesperholdKit's rules)
-- at their LandmarkLayout frames, and the terrain carved out of walk-in bores once that region's terrain is written.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = {}
World.Kit = nil :: any
World.Layout = nil :: any
World.CarveStep = 3

local PRECISE, HULL = Enum.CollisionFidelity.PreciseConvexDecomposition, Enum.CollisionFidelity.Hull
-- Walkable shells and the tunnel floor are precise (a hull per shell slice would fill the bore); crown solids are hulls; roots
-- and gilt trim never collide.
World.Fidelity = { Shell = PRECISE, Floor = PRECISE, Rubble = HULL, Band = HULL, Bronze = HULL, Eave = HULL }

local function deps()
	World.Kit = World.Kit or require(script.Parent:WaitForChild("VesperholdKit") :: ModuleScript)
	World.Layout = World.Layout
		or require(ReplicatedStorage:WaitForChild("AsurasPath"):WaitForChild("Shared"):WaitForChild("LandmarkLayout") :: ModuleScript)
	return World.Kit, World.Layout
end

function World.frame(lm: any): CFrame
	local o = lm.Origin
	return CFrame.new(o.X, o.Y, o.Z) * CFrame.Angles(0, math.rad(lm.Yaw), 0)
end

-- Kit point (Blender: Z up, +Y = tunnel mouth) -> world. Blender (x, y, z) is Roblox model (-x, z, y).
function World.kitToWorld(lm: any, p: { number }): Vector3
	return World.frame(lm):PointToWorldSpace(Vector3.new(-p[1], p[3], p[2]))
end

-- Level air boxes along the bore centre line, from just under the walk floor (centre - 8) to over the crown (centre + Radius).
function World.carves(lm: any): { { CFrame: CFrame, Size: Vector3 } }
	local t = lm.Tunnel
	local out = {}
	if not (t and t.Path) then return out end
	local below, above = 8.5, t.Radius + 0.5
	for i = 2, #t.Path do
		local a, b = World.kitToWorld(lm, t.Path[i - 1]), World.kitToWorld(lm, t.Path[i])
		local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local n = math.max(1, math.ceil((b - a).Magnitude / World.CarveStep))
		for k = 0, n - 1 do
			local c = a:Lerp(b, (k + 0.5) / n)
			local mid = c + Vector3.new(0, (above - below) / 2, 0)
			table.insert(out, { CFrame = CFrame.lookAt(mid, mid + flat), Size = Vector3.new(t.Width + 1.5, above + below, flat.Magnitude / n + 1) })
		end
	end
	return out
end

-- folders: region id -> Map_Overworld region folder. waitReady(region) blocks until that region's terrain is written.
function World.build(folders: { [string]: Instance }, waitReady: (string) -> boolean)
	local Kit, Layout = deps()
	for id, lm in Layout.Landmarks do
		task.spawn(function()
			local model = Instance.new("Model")
			model.Name = "Landmark_" .. id
			model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- never a face without its crown
			model:SetAttribute("AsuraLandmark", id)
			local base, placed = World.frame(lm), 0
			for _, piece in lm.Pieces do
				local f = piece.Foot
				local m = Kit.place(piece.Model, base * CFrame.new(f.X, f.Y, f.Z), Vector3.one, { Fidelity = World.Fidelity })
				if m then
					m.Parent, placed = model, placed + 1
				else
					warn("[LandmarkWorld] " .. id .. ": kit piece " .. piece.Model .. " is not available")
				end
			end
			model.Parent = folders[lm.Region]
			-- No mesh, no hole: the bore is only carved under a placed shell, after the tiles that would refill it are written.
			if placed > 0 and lm.Tunnel and waitReady(lm.Region) then
				for _, c in World.carves(lm) do
					Workspace.Terrain:FillBlock(c.CFrame, c.Size, Enum.Material.Air)
				end
				model:SetAttribute("BoreCarved", true)
			end
		end)
	end
end

return World
