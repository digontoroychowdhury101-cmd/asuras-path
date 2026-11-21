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
-- Walkable shells and the tunnel floor are precise (a hull per shell slice would fill the bore); crown solids are hulls; roots,
-- gilt trim and rubble never collide (the rubble strip spans the bore, so its hull walled the tunnel, mac-86f).
World.Fidelity = { Shell = PRECISE, Floor = PRECISE, Band = HULL, Bronze = HULL, Eave = HULL }

local function deps()
	World.Kit = World.Kit or require(script.Parent:WaitForChild("VesperholdKit") :: ModuleScript)
	if not (World.Layout and World.Height) then
		local shared = ReplicatedStorage:WaitForChild("AsurasPath"):WaitForChild("Shared")
		World.Layout = World.Layout or require(shared:WaitForChild("LandmarkLayout") :: ModuleScript)
		World.Height = World.Height or (require(shared:WaitForChild("Overworld") :: ModuleScript) :: any).heightAt
	end
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

-- A lantern niche in the bore: a small neon flame on a stone bracket, an always-on shadowless ember (the bore is dark at noon) and
-- the night lantern light, tagged AsuraLanternLight and off, so OverworldAmbience switches it with every other lantern.
local EMBER = Color3.fromRGB(255, 160, 80)
function World.lantern(at: Vector3): Model
	local niche = Instance.new("Model")
	niche.Name = "TunnelLantern"
	local bracket = Instance.new("Part")
	bracket.Name, bracket.Size, bracket.Material, bracket.Color = "Bracket", Vector3.new(1.6, 0.6, 1.6), Enum.Material.Slate, Color3.fromRGB(70, 66, 60)
	bracket.CFrame, bracket.Anchored, bracket.CanCollide, bracket.CastShadow = CFrame.new(at - Vector3.new(0, 0.9, 0)), true, false, false
	bracket.Parent = niche
	local flame = Instance.new("Part")
	flame.Name, flame.Shape, flame.Size, flame.Material, flame.Color = "Flame", Enum.PartType.Ball, Vector3.one * 0.8, Enum.Material.Neon, EMBER
	flame.CFrame, flame.Anchored, flame.CanCollide, flame.CanQuery, flame.CastShadow = CFrame.new(at), true, false, false, false
	flame.Parent = niche
	local ember = Instance.new("PointLight")
	ember.Name, ember.Color, ember.Range, ember.Brightness, ember.Shadows = "Ember", EMBER, 16, 1.1, false
	ember.Parent = flame
	local night = Instance.new("PointLight")
	night.Name, night.Color, night.Range, night.Brightness = "LanternLight", Color3.fromRGB(255, 172, 92), 22, 1.6
	night.Shadows, night.Enabled = false, false
	night:AddTag("AsuraLanternLight")
	night.Parent = flame
	niche.PrimaryPart = flame
	return niche
end

-- Overworld terrain is an 8-stud crust over void (OverworldTerrainCompute SHELL), so the descending bore needs rock round it:
-- level boxes along the centre line, Width + 24 across, from 10 under the walk floor up to Radius + 10 over the centre, cut to 1 stud
-- under the lowest surface at the box's top corners (the ground never rises). Filled with Rock before the carve. Floor = walk floor Y.
World.Height = nil :: ((number, number) -> number)?
function World.packs(lm: any): { { CFrame: CFrame, Size: Vector3, Floor: number } }
	local t, height = lm.Tunnel, World.Height
	local out = {}
	if not (t and t.Path and height) then return out end
	local half = (t.Width + 24) / 2
	for i = 2, #t.Path do
		local a, b = World.kitToWorld(lm, t.Path[i - 1]), World.kitToWorld(lm, t.Path[i])
		local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local n = math.max(1, math.ceil((b - a).Magnitude / World.CarveStep))
		local len = flat.Magnitude / n + 1
		local fwd = flat.Unit
		local right = Vector3.new(-fwd.Z, 0, fwd.X)
		for k = 0, n - 1 do
			local c = a:Lerp(b, (k + 0.5) / n)
			local ground = math.huge
			for _, sx in { -half, half } do for _, sz in { -len / 2, len / 2 } do
				local q = c + right * sx + fwd * sz
				ground = math.min(ground, height(q.X, q.Z))
			end end
			local bottom, top = c.Y - 18, math.min(c.Y + t.Radius + 10, ground - 1)
			if top > bottom + 1 then -- near the mouth this is only the ground under the floor; deeper it walls the whole bore
				local mid = Vector3.new(c.X, (bottom + top) / 2, c.Z)
				table.insert(out, { CFrame = CFrame.lookAt(mid, mid + flat), Size = Vector3.new(half * 2, top - bottom, len), Floor = c.Y - 8 })
			end
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
			if placed > 0 and lm.Tunnel and lm.Tunnel.Lanterns then
				for _, p in lm.Tunnel.Lanterns do World.lantern(World.kitToWorld(lm, p)).Parent = model end
			end
			model.Parent = folders[lm.Region]
			-- No mesh, no hole: the bore is only carved under a placed shell, after the tiles that would refill it are written.
			if placed > 0 and lm.Tunnel and waitReady(lm.Region) then
				for _, p in World.packs(lm) do
					Workspace.Terrain:FillBlock(p.CFrame, p.Size, Enum.Material.Rock)
				end
				for _, c in World.carves(lm) do
					Workspace.Terrain:FillBlock(c.CFrame, c.Size, Enum.Material.Air)
				end
				model:SetAttribute("BoreCarved", true)
			end
		end)
	end
end

return World
