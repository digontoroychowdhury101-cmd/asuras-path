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

-- The bore centre line and, past the mesh End, the terrain passage into the basin.
local function route(t: any): { { number } }
	local out = table.clone(t.Path)
	for i = 2, #(t.Passage or {}) do table.insert(out, t.Passage[i]) end
	return out
end

-- Level air boxes along the bore centre line, from just under the walk floor (centre - 8) to over the crown (centre + Radius).
function World.carves(lm: any): { { CFrame: CFrame, Size: Vector3 } }
	local t = lm.Tunnel
	local out = {}
	if not (t and t.Path) then return out end
	local below, above = 8.5, t.Radius + 0.5
	local path = route(t)
	for i = 2, #path do
		local a, b = World.kitToWorld(lm, path[i - 1]), World.kitToWorld(lm, path[i])
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

-- The hidden basin (LandmarkLayout.Basin), as terrain fills in order: the bowl (air strips across the ellipse, floor to over the highest
-- rim), its bed (rock with a mud top, reaching under the rim) and the rim cliffs (rock boxes round the shore, from under the floor to
-- Layout.rimTop). The lake is separate (World.lake) so it goes in after the passage is cut. Rim = true marks a cliff box.
World.BasinStep, World.RimSegments = 6, 128
local function strips(lm: any, grow: number, bottom: number, top: number, material: Enum.Material, out: { any })
	local L = World.Layout
	local c, fx, fz = L.basinCentre(lm), L.front(lm)
	local front = Vector3.new(fx, 0, fz)
	local a, b = lm.Basin.Width / 2 + grow, lm.Basin.Depth / 2 + grow
	local step = World.BasinStep
	for u = -b, b - step, step do
		local edge = math.max(math.abs(u), math.abs(u + step)) / b -- the outer edge of the strip keeps every corner inside
		local w = a * math.sqrt(math.max(0, 1 - edge * edge))
		if w > 1 then
			local p = Vector3.new(c.X, (bottom + top) / 2, c.Z) + front * (u + step / 2)
			table.insert(out, { CFrame = CFrame.lookAt(p, p + front), Size = Vector3.new(2 * w, top - bottom, step), Material = material })
		end
	end
end

function World.basin(lm: any): { any }
	local L, height = World.Layout, World.Height
	local out = {}
	if not (lm.Basin and L and height) then return out end
	local floorY = L.basinLevels(lm)
	local tops, maxTop = {}, -math.huge
	for k = 0, World.RimSegments - 1 do
		tops[k] = L.rimTop(lm, k / World.RimSegments * 2 * math.pi, height)
		maxTop = math.max(maxTop, tops[k])
	end
	strips(lm, 0, floorY, maxTop + 4, Enum.Material.Air, out)
	strips(lm, lm.Basin.Thick, floorY - 16, floorY - 4, Enum.Material.Rock, out)
	strips(lm, lm.Basin.Thick, floorY - 4, floorY, Enum.Material.Mud, out)
	local th = lm.Basin.Thick
	for k = 0, World.RimSegments - 1 do
		local t0, t1 = k / World.RimSegments * 2 * math.pi, (k + 1) / World.RimSegments * 2 * math.pi
		local x0, z0 = L.basinRing(lm, t0, th / 2)
		local x1, z1 = L.basinRing(lm, t1, th / 2)
		local bottom, top = floorY - 16, tops[k]
		local mid = Vector3.new((x0 + x1) / 2, (bottom + top) / 2, (z0 + z1) / 2)
		local along = Vector3.new(x1 - x0, 0, z1 - z0)
		table.insert(out, { CFrame = CFrame.lookAt(mid, mid + along), Size = Vector3.new(th, top - bottom, along.Magnitude + 3), Material = Enum.Material.Rock, Rim = true })
	end
	return out
end

-- The lake: water strips 1 stud inside the shore, from the floor to Floor + Water.
function World.lake(lm: any): { any }
	local out = {}
	if not (lm.Basin and World.Layout) then return out end
	local floorY, waterY = World.Layout.basinLevels(lm)
	strips(lm, -1, floorY, waterY, Enum.Material.Water, out)
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

-- Spec: dripping water and drifting moss spores in the bore. An invisible box under the roof at each inner Path point (the ends
-- are the open mouth and the terrain passage) carries both emitters; the sprite is OverworldAmbience's procedural Glow (win-80).
local GLOW = "rbxassetid://84933589518173"
function World.tunnelFx(lm: any): Model
	local fx = Instance.new("Model")
	fx.Name = "TunnelFx"
	local path = lm.Tunnel.Path
	for i = 2, #path - 1 do
		local c, nxt = World.kitToWorld(lm, path[i]), World.kitToWorld(lm, path[i + 1])
		local at = c + Vector3.new(0, lm.Tunnel.Radius - 1.5, 0)
		local box = Instance.new("Part")
		box.Name, box.Size, box.Transparency = "Drip" .. (i - 1), Vector3.new(lm.Tunnel.Width - 4, 0.3, 8), 1
		box.CFrame = CFrame.lookAt(at, Vector3.new(nxt.X, at.Y, nxt.Z))
		box.Anchored, box.CanCollide, box.CanQuery, box.CanTouch, box.CastShadow = true, false, false, false, false
		local drips = Instance.new("ParticleEmitter")
		drips.Name, drips.Texture, drips.Rate, drips.Lifetime = "Drips", GLOW, 3, NumberRange.new(0.5, 0.8)
		drips.Speed, drips.Acceleration, drips.EmissionDirection = NumberRange.new(0), Vector3.new(0, -70, 0), Enum.NormalId.Bottom
		drips.Size, drips.Squash = NumberSequence.new(0.12), NumberSequence.new(-1.5) -- stretched along the fall
		drips.Orientation, drips.Color = Enum.ParticleOrientation.VelocityParallel, ColorSequence.new(Color3.fromRGB(170, 196, 200))
		drips.Transparency, drips.LightEmission = NumberSequence.new(0.35), 0.3
		drips.Parent = box
		local motes = Instance.new("ParticleEmitter")
		motes.Name, motes.Texture, motes.Rate, motes.Lifetime = "Motes", GLOW, 1.2, NumberRange.new(6, 9)
		motes.Speed, motes.SpreadAngle, motes.EmissionDirection = NumberRange.new(0.3, 0.8), Vector2.new(180, 180), Enum.NormalId.Bottom
		motes.Acceleration, motes.Drag = Vector3.new(0, -0.15, 0), 0.5
		motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.16), NumberSequenceKeypoint.new(1, 0) })
		motes.Color, motes.LightEmission = ColorSequence.new(Color3.fromRGB(176, 214, 120)), 0.7
		motes.Parent = box
		box.Parent = fx
	end
	return fx
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
	local path = route(t)
	for i = 2, #path do
		local a, b = World.kitToWorld(lm, path[i - 1]), World.kitToWorld(lm, path[i])
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
			if placed > 0 and lm.Tunnel and lm.Tunnel.Path then World.tunnelFx(lm).Parent = model end
			model.Parent = folders[lm.Region]
			-- No mesh, no hole: the bore is only carved under a placed shell, after the tiles that would refill it are written.
			if placed > 0 and lm.Tunnel and waitReady(lm.Region) then
				local terrain = Workspace.Terrain
				for _, p in World.packs(lm) do terrain:FillBlock(p.CFrame, p.Size, Enum.Material.Rock) end
				for _, f in World.basin(lm) do terrain:FillBlock(f.CFrame, f.Size, f.Material) end
				for _, c in World.carves(lm) do terrain:FillBlock(c.CFrame, c.Size, Enum.Material.Air) end -- the passage cuts the rim
				for _, f in World.lake(lm) do terrain:FillBlock(f.CFrame, f.Size, f.Material) end
				model:SetAttribute("BoreCarved", true)
				model:SetAttribute("BasinSculpted", #World.lake(lm) > 0)
			end
		end)
	end
end

return World
