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
local BORE_DEPTH = 8.5 -- below the centre line
-- Walkable shells and the tunnel floor are precise (a hull per shell slice would fill the bore); crown solids are hulls; roots,
-- gilt trim and rubble never collide (the rubble strip spans the bore, so its hull walled the tunnel, mac-86f).
-- Temple hall (mac-90): the stone platform and stair are walked on; the lacquer frame keeps its own shape (a hull would fill the hall);
-- the roofs (Tiles, Soffit) never collide. The gate uses stone collision for the stair. Its root mesh spans both towers,
-- so a convex hull across those roots would block the flight.
World.Fidelity = { Shell = PRECISE, Floor = PRECISE, Band = HULL, Bronze = HULL, Eave = HULL,
	Stone = PRECISE, Lacquer = Enum.CollisionFidelity.Default }

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
	local below, above = BORE_DEPTH, t.Radius + 0.5
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

local function boreFloorAt(lm: any, position: Vector3): number?
	local frame = World.frame(lm)
	local point = frame:PointToObjectSpace(position)
	local path = route(lm.Tunnel)
	local distanceLimit = ((lm.Tunnel.Width + 1.5) / 2) ^ 2
	local floor: number? = nil
	for i = 2, #path do
		local a, b = path[i - 1], path[i]
		local x, z = -point.X - a[1], point.Z - a[2]
		local dx, dz = b[1] - a[1], b[2] - a[2]
		local t = math.clamp((x * dx + z * dz) / (dx * dx + dz * dz), 0, 1)
		local distance = (x - dx * t) ^ 2 + (z - dz * t) ^ 2
		if distance <= distanceLimit then
			distanceLimit = distance
			floor = frame.Y + a[3] + (b[3] - a[3]) * t - BORE_DEPTH
		end
	end
	return floor
end

-- The terrain manifest records the original tile floor. Once a landmark carves below it,
-- allow the authored cavity while still rescuing characters that fall below its floor.
function World.lowerFloorAt(folders: { [string]: Instance }, position: Vector3): number?
	local layout = World.Layout
	if not layout then return nil end
	for id, lm in layout.Landmarks do
		local folder = folders[lm.Region]
		local landmark = folder and folder:FindFirstChild("Landmark_" .. id)
		if not (landmark and landmark:GetAttribute("BoreCarved")) then continue end
		if lm.Basin and landmark:GetAttribute("BasinSculpted") and layout.basinEllipse(lm, position.X, position.Z) <= 1 then
			local bed = layout.basinLevels(lm)
			return bed - lm.Basin.Deep
		end
		local floor = boreFloorAt(lm, position)
		if floor then return floor end
	end
	return nil
end

-- The hidden basin (LandmarkLayout.Basin), as terrain fills in order: the bowl (air strips across the ellipse, floor to over the highest
-- rim), its bed (rock with a mud top, reaching under the rim) and the rim cliffs (rock boxes round the shore, from under the floor to
-- Layout.rimTop). The lake is separate (World.lake) so it goes in after the passage is cut.
-- mac-89: the first rim was one dark rock wall on open meadow. Each of the RimSegments is now a cliff of RimStrata-stud strata
-- (Rim = true; rock, slate and basalt, each stepped in or out a little so the face has ledges), a LeafyGrass cap (Cap = true) set back
-- from the lip, and a grass slope (Wedge = true, a terrain wedge: high edge at +Z on the rim, low edge under the forest floor) so
-- from outside it reads as a wooded ridge. Segment = the rim segment index.
World.BasinStep, World.RimSegments, World.RimStrata, World.RimCap = 6, 128, 6, 3
-- Irregular strata (22 Nov): band thickness and stone come from smooth fields over (band, angle), so the layers wander round the
-- ring (no uniform black stripes) without any segment-to-segment jump (a jump reads as a vertical streak). Dark stone (Slate,
-- Basalt) never sits in two bands in a row and stays under 3.5 studs thick; Ground, Mud and Grass make the ledges.
local DARK = { [Enum.Material.Slate] = true, [Enum.Material.Basalt] = true }
local function stratumMaterial(i: number, tm: number, prevDark: boolean, thick: number): Enum.Material
	local f = 0.5 + 0.25 * math.sin(i * 2.17 + tm * 5.3) + 0.15 * math.sin(i * 0.71 + tm * 2.1 + 1.3) + 0.1 * math.sin(tm * 11 + i * 3.7)
	local m = if f < 0.42 then Enum.Material.Rock elseif f < 0.55 then Enum.Material.Ground -- no Limestone: its pale texture blotched the rim (mac-92)
		elseif f < 0.66 then Enum.Material.Mud elseif f < 0.76 then Enum.Material.Rock elseif f < 0.86 then Enum.Material.Slate
		elseif f < 0.92 then Enum.Material.Basalt else Enum.Material.Grass
	if DARK[m] and (prevDark or thick > 3.5) then return Enum.Material.Rock end -- never a wide or doubled dark stripe
	return m
end
-- Band edges: fixed irregular widths (3.6-7.4 studs, the same on every segment) plus a smooth +-1 stud wander round the ring.
local function stratumWidth(i: number): number
	return 5.5 + 1.9 * math.sin(i * 2.7 + 0.6) * (0.55 + 0.45 * math.sin(i * 1.3))
end
local function stratumWander(i: number, tm: number): number
	return 0.6 * math.sin(i * 1.9 + tm * 3.1) + 0.4 * math.sin(i * 0.8 + tm * 1.7 + 2)
end
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
	local th, n = lm.Basin.Thick, World.RimSegments
	for k = 0, n - 1 do
		local t0, t1 = k / n * 2 * math.pi, (k + 1) / n * 2 * math.pi
		local tm = (t0 + t1) / 2
		local x0, z0 = L.basinRing(lm, t0, th / 2)
		local x1, z1 = L.basinRing(lm, t1, th / 2)
		local along = Vector3.new(x1 - x0, 0, z1 - z0)
		local len = along.Magnitude + 3
		local cx, cz = L.basinRing(lm, tm, th / 2)
		local ox, oz = L.basinRing(lm, tm, th / 2 + 1)
		local outward = Vector3.new(ox - cx, 0, oz - cz).Unit
		local frame = CFrame.lookAt(Vector3.new(cx, 0, cz), Vector3.new(cx, 0, cz) + along) -- X = across the rim, Z = along it
		local toOut = if frame.RightVector:Dot(outward) > 0 then 1 else -1
		local bottom, top = floorY - 16, tops[k]
		local capY = top - World.RimCap
		local z, i, prevDark, edge = bottom, 0, false, bottom
		while z < capY - 0.01 do
			edge += stratumWidth(i)
			local zt = math.min(edge + stratumWander(i, tm), capY)
			if capY - zt < 2 then zt = capY end
			local material = stratumMaterial(i, tm, prevDark, zt - z) -- heights never depend on the stone, so no cascade jumps between segments
			-- deterministic ledges: each stratum steps up to 1.5 studs in or out, varying round the ring
			local step = 1.5 * math.sin(i * 2.3 + tm * 9) * math.sin(tm * 3 + i)
			table.insert(out, { CFrame = frame * CFrame.new(toOut * step, (z + zt) / 2, 0), Size = Vector3.new(th, zt - z, len),
				Material = material, Rim = true, Segment = k })
			z, i, prevDark = zt, i + 1, DARK[material] == true
		end
		-- the cap, set back 2 from the lip so a rock edge shows from the lake
		table.insert(out, { CFrame = frame * CFrame.new(toOut, (capY + top) / 2, 0), Size = Vector3.new(th - 2, top - capY, len),
			Material = Enum.Material.LeafyGrass, Cap = true, Segment = k })
		-- the outer slope: from the rim's outer edge down past the forest floor, run = 1.8 x the drop (about 30 degrees)
		local ex, ez = L.basinRing(lm, tm, th)
		local drop = math.max(4, top - height(ex, ez))
		local run = math.max(8, drop * 1.8)
		local fx2, fz2 = L.basinRing(lm, tm, th + run)
		local base = math.min(height(ex, ez), height(fx2, fz2)) - 6
		local mid = Vector3.new((ex + fx2) / 2, (base + top) / 2, (ez + fz2) / 2)
		table.insert(out, { CFrame = CFrame.lookAt(mid, mid + outward), Size = Vector3.new(len, top - base, run + 1),
			Material = Enum.Material.LeafyGrass, Wedge = true, Segment = k })
	end
	return out
end

-- The lake: water strips 1 stud inside the shore, from the floor to Floor + Water.
function World.lake(lm: any): { any }
	local out = {}
	if not (lm.Basin and World.Layout) then return out end
	local floorY, waterY = World.Layout.basinLevels(lm)
	strips(lm, -1, floorY, waterY, Enum.Material.Water, out)
	-- mac-89: a deeper middle, Deep more, Shelf studs in from the shore, so the bed's voxel relief stops showing through. Water does
	-- not replace solid voxels, so the dish is cut to air (Dish = true) before it is filled.
	local n = #out
	strips(lm, -lm.Basin.Shelf, floorY - lm.Basin.Deep, floorY, Enum.Material.Air, out)
	for i = n + 1, #out do out[i].Dish = true end
	strips(lm, -lm.Basin.Shelf, floorY - lm.Basin.Deep, waterY, Enum.Material.Water, out)
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

-- mac-89: rain fell inside the bore. WeatherController calls a spot sheltered when a part tagged AsuraShelter is within 60 studs
-- straight up; terrain cannot be tagged, so invisible, non-colliding roof slabs sit 2 over the bore crown along the whole route
-- from the second Path point (inside the socket) to the basin.
function World.shelters(lm: any): Model
	local model = Instance.new("Model")
	model.Name = "TunnelShelter"
	local path = route(lm.Tunnel)
	local L = World.Layout
	local width = lm.Tunnel.Width + 8
	-- open sky over the lake: no roof corner reaches into the bowl (a CanQuery slab there catches raycasts over the water)
	local function overBowl(cf: CFrame, len: number): boolean
		if not (L and lm.Basin) then return false end
		for _, sx in { -1, 1 } do for _, sz in { -1, 1 } do
			local q = cf:PointToWorldSpace(Vector3.new(sx * width / 2, 0, sz * len / 2))
			if L.basinEllipse(lm, q.X, q.Z, -2) < 1 then return true end
		end end
		return false
	end
	for i = 2, #path - 1 do
		local a, b = World.kitToWorld(lm, path[i]), World.kitToWorld(lm, path[i + 1])
		local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local y = math.max(a.Y, b.Y) + lm.Tunnel.Radius + 2
		local ahead = flat.Magnitude + 4 -- the slab runs from 4 behind a to ahead along the walk
		local function slab(): (CFrame, number)
			local mid = Vector3.new(a.X, y, a.Z) + flat.Unit * ((ahead - 4) / 2)
			return CFrame.lookAt(mid, mid + flat), ahead + 4
		end
		while ahead > 0 and overBowl(slab()) do ahead -= 1 end
		if ahead <= 0 then continue end
		local cf, len = slab()
		local roof = Instance.new("Part")
		roof.Name, roof.Size, roof.Transparency = "Roof" .. (i - 1), Vector3.new(width, 1, len), 1
		roof.CFrame = cf
		roof.Anchored, roof.CanCollide, roof.CanTouch, roof.CanQuery, roof.CastShadow = true, false, false, true, false
		roof:AddTag("AsuraShelter")
		roof.Parent = model
	end
	return model
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

-- The temple hall's origin frame: at Layout.templeSpot, upright, its front (model +Z) turned to the passage exit.
function World.templeFrame(lm: any): CFrame
	local s = World.Layout.templeSpot(lm)
	local at = Vector3.new(s.X, s.Y, s.Z)
	local exit = World.kitToWorld(lm, lm.Tunnel.Passage[#lm.Tunnel.Passage])
	local away = at - Vector3.new(exit.X - at.X, 0, exit.Z - at.Z) -- lookAt aims -Z, so aim away from the exit
	return CFrame.lookAt(at, away)
end

-- The gate towers' origin frame: at Layout.gateSpot, upright, its front (model +Z) turned to the basin centre.
function World.gateFrame(lm: any): CFrame
	local s, c = World.Layout.gateSpot(lm), World.Layout.basinCentre(lm)
	local at = Vector3.new(s.X, s.Y, s.Z)
	return CFrame.lookAt(at, at + Vector3.new(s.X - c.X, 0, s.Z - c.Z)) -- lookAt aims -Z, so aim away from the centre
end

-- Terrain under the gate, filled after the lake (gate frame axes): a mud footing over the deep dish under the steps and towers, up to
-- the lake bed, and a rock ledge with a grass top from the landing back into the rim, so the stair's top meets walkable ground.
function World.gateFills(lm: any): { any }
	local G = lm.Basin and lm.Basin.Gate
	if not (G and World.Layout) then return {} end
	local frame = World.gateFrame(lm)
	local floorY = World.Layout.basinLevels(lm)
	local function box(w: number, y0: number, y1: number, z0: number, z1: number, material: Enum.Material)
		return { CFrame = frame * CFrame.new(0, (y0 + y1) / 2 - frame.Y, (z0 + z1) / 2), Size = Vector3.new(w, y1 - y0, z0 - z1), Material = material }
	end
	local top, landing = frame.Y + G.Landing, G.Back + 6
	return {
		box(44, floorY - lm.Basin.Deep - 4, floorY, G.Steps + 2, G.Back, Enum.Material.Mud),
		box(G.Width + 6, floorY - 4, top - 2, landing, G.Back - 24, Enum.Material.Rock),
		box(G.Width + 6, top - 2, top, landing, G.Back - 24, Enum.Material.LeafyGrass),
	}
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
			local T = lm.Basin and lm.Basin.Temple
			if T then
				local m = Kit.place(T.Model, World.templeFrame(lm) * CFrame.new(T.Foot.X, T.Foot.Y, T.Foot.Z), Vector3.one, { Fidelity = World.Fidelity })
				if m then m.Parent = model else warn("[LandmarkWorld] " .. id .. ": kit piece " .. T.Model .. " is not available") end
			end
			local G, gatePlaced = lm.Basin and lm.Basin.Gate, false
			if G then
				local m = Kit.place(G.Model, World.gateFrame(lm) * CFrame.new(G.Foot.X, G.Foot.Y, G.Foot.Z), Vector3.one, { Fidelity = World.Fidelity })
				if m then m.Parent, gatePlaced = model, true else warn("[LandmarkWorld] " .. id .. ": kit piece " .. G.Model .. " is not available") end
			end
			if placed > 0 and lm.Tunnel and lm.Tunnel.Lanterns then
				for _, p in lm.Tunnel.Lanterns do World.lantern(World.kitToWorld(lm, p)).Parent = model end
			end
			if placed > 0 and lm.Tunnel and lm.Tunnel.Path then
				World.tunnelFx(lm).Parent = model
				World.shelters(lm).Parent = model
			end
			model.Parent = folders[lm.Region]
			-- No mesh, no hole: the bore is only carved under a placed shell, after the tiles that would refill it are written.
			if placed > 0 and lm.Tunnel and waitReady(lm.Region) then
				local terrain = Workspace.Terrain
				for _, p in World.packs(lm) do terrain:FillBlock(p.CFrame, p.Size, Enum.Material.Rock) end
				for _, f in World.basin(lm) do
					if f.Wedge then terrain:FillWedge(f.CFrame, f.Size, f.Material) else terrain:FillBlock(f.CFrame, f.Size, f.Material) end
				end
				for _, c in World.carves(lm) do terrain:FillBlock(c.CFrame, c.Size, Enum.Material.Air) end -- the passage cuts the rim
				for _, f in World.lake(lm) do terrain:FillBlock(f.CFrame, f.Size, f.Material) end
				if gatePlaced then -- no ledge in the lake without its stair
					for _, f in World.gateFills(lm) do terrain:FillBlock(f.CFrame, f.Size, f.Material) end
				end
				model:SetAttribute("BoreCarved", true)
				model:SetAttribute("BasinSculpted", #World.lake(lm) > 0)
			end
		end)
	end
end

return World
