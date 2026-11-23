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
-- mac-89: the first rim was one dark rock wall on open meadow. Each of the Basin.Segments (320 since the 22 Nov enlargement) is now a cliff of RimStrata-stud strata
-- (Rim = true; rock, slate and basalt, each stepped in or out a little so the face has ledges), a LeafyGrass cap (Cap = true) set back
-- from the lip, and a grass slope (Wedge = true, a terrain wedge: high edge at +Z on the rim, low edge under the forest floor) so
-- from outside it reads as a wooded ridge. Segment = the rim segment index.
World.BasinStep, World.RimStrata, World.RimCap = 6, 6, 3
-- The enlarged basin is ~5x the volume and ~2.5x the rim, so build() hands the frame back every YieldEvery fills or YieldVolume studs^3 of fill.
World.YieldEvery, World.YieldVolume = 40, 4e6
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
	for k = 0, lm.Basin.Segments - 1 do
		tops[k] = L.rimTop(lm, k / lm.Basin.Segments * 2 * math.pi, height)
		maxTop = math.max(maxTop, tops[k])
	end
	strips(lm, 0, floorY, maxTop + 4, Enum.Material.Air, out)
	strips(lm, lm.Basin.Thick, floorY - 16, floorY - 4, Enum.Material.Rock, out)
	strips(lm, lm.Basin.Thick, floorY - 4, floorY, Enum.Material.Mud, out)
	local th, n = lm.Basin.Thick, lm.Basin.Segments
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
function World.templeFrame(lm: any, temple: any?): CFrame
	local s = World.Layout.templeSpot(lm, temple)
	local at = Vector3.new(s.X, s.Y, s.Z)
	local exit = World.kitToWorld(lm, lm.Tunnel.Passage[#lm.Tunnel.Passage])
	local away = at - Vector3.new(exit.X - at.X, 0, exit.Z - at.Z) -- lookAt aims -Z, so aim away from the exit
	return CFrame.lookAt(at, away)
end

-- Invisible solid treads follow the art recipe in Blender +Y. They avoid cooking collision for the decorative mesh kit.
function World.colossalTempleCollision(frame: CFrame): Folder
	local folder = Instance.new("Folder")
	folder.Name = "ColossalTempleCollision"
	local function add(name: string, run: number, top: number, width: number, depth: number, thickness: number)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = Vector3.new(width, thickness, depth)
		part.CFrame = frame * CFrame.new(0, top - thickness / 2, run)
		part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, true, true, false
		part.Transparency, part.CastShadow = 1, false
		part.Parent = folder
	end
	-- The 128-tread stair collides as a smooth ramp through the tread middles (rise 0.88, run 2.35): per-tread boxes made the walk
	-- hitch at every riser (mac-96 Play log: speed 22 -> 9). The stair mesh keeps the look; feet sit within 0.44 of a tread.
	-- Eight segments of 16 treads, each as wide as its middle tread (the stair narrows 77 -> 44 as it climbs).
	local function treadMid(i: number): Vector3
		return frame * Vector3.new(0, 0.60 + i * 0.88, 257 - i * 2.35)
	end
	for s = 0, 7 do
		local a, b = treadMid(s * 16 - 0.5), treadMid(s * 16 + 15.5)
		local part = Instance.new("Part")
		part.Name = string.format("StairRamp%d", s)
		part.Size = Vector3.new(77 - 33 * (s * 16 + 8) / 128, 2, (b - a).Magnitude + 0.2)
		part.CFrame = CFrame.lookAt((a + b) / 2, b, frame.UpVector) * CFrame.new(0, -1, 0)
		part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, true, true, false
		part.Transparency, part.CastShadow = 1, false
		part.Parent = folder
	end
	add("HallFloor", -84, 113, 144, 88, 2)
	return folder
end

function World.colossalRidgeFills(lm: any): { any }
	local L = World.Layout
	local centre, fx, fz = L.basinCentre(lm), L.front(lm)
	local floor = L.basinLevels(lm)
	local front = Vector3.new(fx, 0, fz)
	local across = Vector3.new(-fz, 0, fx)
	local out = {}
	for x = -620, 420, 20 do
		for z = 574, 728, 14 do
			local centreline = Vector3.new(centre.X, 0, centre.Z) + across * x + front * z
			local top = L.colossalRidgeHeight(lm, centreline.X, centreline.Z)
			if not top or top - floor < 8 then continue end
			local mid = centreline + Vector3.new(0, (top + floor) / 2 - 6, 0)
			table.insert(out, { CFrame = CFrame.lookAt(mid, mid + front),
				Size = Vector3.new(20, top - floor + 12, 14), Material = Enum.Material.Rock })
		end
	end
	return out
end

-- The level runs sit on a rock footing from below the deep dish. Low steps join the passage and the two stair toes.
function World.colossalApproach(lm: any, frame: CFrame): { any }
	local entry = World.kitToWorld(lm, lm.Tunnel.Passage[#lm.Tunnel.Passage]) - Vector3.new(0, 8, 0)
	local stair = frame * Vector3.new(0, .60, 258)
	local gate = World.gateFrame(lm) * Vector3.new(0, .4, lm.Basin.Gate.Steps + 4)
	local floor, water = World.Layout.basinLevels(lm)
	local bed = floor - lm.Basin.Deep - 3
	local out = {}
	local function path(a: Vector3, b: Vector3, width: number)
		local flat = (b - a) * Vector3.new(1, 0, 1)
		local segments = math.max(1, math.ceil(flat.Magnitude / 16))
		for i = 1, segments do
			local sample = a:Lerp(b, (i - .5) / segments)
			-- The passage and the stair toe sit at the lake surface; a run along that line left the avatar swimming and snagged.
			local top = math.max(sample.Y, water + 1)
			local mid = Vector3.new(sample.X, (top + bed) / 2, sample.Z)
			table.insert(out, { CFrame = CFrame.lookAt(mid, mid + flat),
				Size = Vector3.new(width, top - bed, flat.Magnitude / segments + .8), Material = Enum.Material.Rock })
		end
	end
	path(entry, stair, 16)
	path(stair:Lerp(entry, .24), gate, 12)
	return out
end

-- The gate towers' origin frame: at Layout.gateSpot, upright, its front (model +Z) turned to the basin centre.
function World.gateFrame(lm: any): CFrame
	local s, c = World.Layout.gateSpot(lm), World.Layout.basinCentre(lm)
	local at = Vector3.new(s.X, s.Y, s.Z)
	return CFrame.lookAt(at, at + Vector3.new(s.X - c.X, 0, s.Z - c.Z)) -- lookAt aims -Z, so aim away from the centre
end

-- Warm accent lights (noon rain left the hall and the gate towers as near-black silhouettes): { x, y, z, range, brightness } in each
-- model's origin frame (+Z = its front, toward the viewer / basin centre). Hall: doorway and two eave lines. Gate: both arch niches,
-- the lintel and the upper tower faces. 10 lights in all (budget 12), no shadows. Always on, like the bore's ember.
local ACCENT = Color3.fromRGB(255, 170, 90)
World.Accents = {
	Temple = { { 0, 12, 34, 32, 1.6 }, { -26, 24, 36, 38, 1.5 }, { 26, 24, 36, 38, 1.5 }, { -14, 40, 30, 30, 1.2 }, { 14, 40, 30, 30, 1.2 } },
	Gate = { { -24, 10, 6, 26, 1.5 }, { 24, 10, 6, 26, 1.5 }, { 0, 26, 8, 32, 1.5 }, { -26, 34, 6, 28, 1.2 }, { 26, 34, 6, 28, 1.2 } },
}

-- Invisible anchored non-colliding anchors, one PointLight each. which = { Temple = bool, Gate = bool } (the pieces that placed).
function World.accents(lm: any, which: { [string]: boolean }, temple: any?): Model
	local model = Instance.new("Model")
	model.Name = "BasinLights"
	for kind, frame in { Temple = World.templeFrame(lm, temple), Gate = World.gateFrame(lm) } do
		if not which[kind] then continue end
		for i, a in (if kind == "Temple" and temple and temple.Accents then temple.Accents else World.Accents[kind]) do
			local part = Instance.new("Part")
			part.Name, part.Size, part.Transparency = kind .. "Accent" .. i, Vector3.one, 1
			part.CFrame = frame * CFrame.new(a[1], a[2], a[3])
			part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
			part:SetAttribute("For", kind)
			local light = Instance.new("PointLight")
			light.Name, light.Color, light.Range, light.Brightness, light.Shadows = "Accent", ACCENT, a[4], a[5], false
			light.Parent = part
			part.Parent = model
		end
	end
	return model
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

-- The walkable route gate landing -> rim (Layout.route; the rim cap, the outer slope and the forest are already terrain): a rock causeway
-- over the lake, then a switchback of ramps against the cliff. Boxes and wedges in order: Rock footings from under the lake dish up to the
-- tread, a 2-stud Ground top (Ground is the path, the dish keeps the footing from hanging). A wedge's high edge is +Z (see World.basin).
function World.routeFills(lm: any): { any }
	local L = World.Layout
	if not (lm.Basin and lm.Basin.Route and L and World.Height) then return {} end
	local r = L.route(lm, World.Height)
	local floorY = L.basinLevels(lm)
	local foot = floorY - lm.Basin.Deep - 4
	local W = lm.Basin.Route.Width
	local out = {}
	local function block(cx: number, cz: number, dx: number, dz: number, across: number, along: number, y0: number, y1: number, material: Enum.Material)
		if y1 - y0 < 0.01 then return end
		local p = Vector3.new(cx, (y0 + y1) / 2, cz)
		table.insert(out, { CFrame = CFrame.lookAt(p, p + Vector3.new(dx, 0, dz)), Size = Vector3.new(across, y1 - y0, along), Material = material })
	end
	-- a footing plus its path-coloured top, over a rectangle (centre, long axis direction, across x along)
	local function slab(cx: number, cz: number, dx: number, dz: number, across: number, along: number, top: number)
		block(cx, cz, dx, dz, across, along, foot, top - 2, Enum.Material.Rock)
		block(cx, cz, dx, dz, across, along, top - 2, top, Enum.Material.Ground)
	end
	local a, b = r.Causeway.A, r.Causeway.B
	local len = math.sqrt((b.X - a.X) ^ 2 + (b.Z - a.Z) ^ 2)
	slab((a.X + b.X) / 2, (a.Z + b.Z) / 2, b.X - a.X, b.Z - a.Z, W, len + W, r.Causeway.Y)
	local f = r.Frame
	for _, leg in r.Legs do
		local cx, cz = L.routeAt(r, (leg.T0 + leg.T1) / 2, leg.Lane)
		local up = if leg.T1 > leg.T0 then 1 else -1 -- along +T the leg climbs when up = 1; the wedge looks downhill
		block(cx, cz, f.Tx, f.Tz, W, r.Run, foot, leg.Z0, Enum.Material.Rock)
		local p = Vector3.new(cx, (leg.Z0 + leg.Z1) / 2, cz)
		table.insert(out, { CFrame = CFrame.lookAt(p, p - Vector3.new(f.Tx, 0, f.Tz) * up), Size = Vector3.new(W, leg.Z1 - leg.Z0, r.Run),
			Material = Enum.Material.Ground, Wedge = true })
	end
	for _, ld in r.Landings do
		local cx, cz = L.routeAt(r, (ld.T0 + ld.T1) / 2, (ld.N0 + ld.N1) / 2)
		slab(cx, cz, f.Tx, f.Tz, ld.N1 - ld.N0, ld.T1 - ld.T0, ld.Z)
	end
	return out
end

-- A lantern on each switchback landing's outer corner (the plan's rail/lantern per landing; the rail itself is not built).
function World.routeLanterns(lm: any): { Model }
	local L = World.Layout
	if not (lm.Basin and lm.Basin.Route and L and World.Height) then return {} end
	local r = L.route(lm, World.Height)
	local out = {}
	for i = 1, #r.Landings - 1 do
		local ld = r.Landings[i]
		local x, z = L.routeAt(r, if (ld.T0 + ld.T1) / 2 < 0 then ld.T0 else ld.T1, ld.N0 + 1.5)
		local lantern = World.lantern(Vector3.new(x, ld.Z + 4, z))
		lantern.Name = "RouteLantern"
		table.insert(out, lantern)
	end
	return out
end

-- The Hollow (LandmarkLayout.Basin.Cavern): the colossal temple's basin is underground, so a vault closes over it. Inner surface at
-- angle theta and height fraction t: the ring Inset studs past the shore, scaled toward the centre by s(t) = (1 - t^Power)^(1/Power),
-- t running 0 at the spring (rim top - 6) to 1 at Apex. Near-vertical walls, a broad flat-ish ceiling.
local function cavernScale(V: any, t: number): number
	t = math.clamp(t, 0, 1)
	return (1 - t ^ V.Power) ^ (1 / V.Power)
end

-- One column of the vault: centre, the unit direction out from it, the spring ring's distance R and the spring height.
local function cavernColumn(lm: any, theta: number): (Vector3, Vector3, number, number)
	local L, V = World.Layout, lm.Basin.Cavern
	local c = L.basinCentre(lm)
	local x, z = L.basinRing(lm, theta, V.Inset)
	local centre, ring = Vector3.new(c.X, 0, c.Z), Vector3.new(x, 0, z)
	return centre, (ring - centre).Unit, (ring - centre).Magnitude, L.rimTop(lm, theta, World.Height) - 6
end

-- The vault as terrain boxes: Columns slabs round the ring, a course every Step studs. Each slab reaches radially from just inside the
-- course above (so no step leaves a gap) out to Shell past its own course, and Step + 4 high; the outer 6 studs are a Rock skin.
-- Basalt inside with Slate bands that follow height (a band per column would read as vertical streaks). Vault = true on each.
function World.cavernShell(lm: any): { any }
	local V = lm.Basin and lm.Basin.Cavern
	if not (V and World.Layout and World.Height) then return {} end
	local out, n = {}, V.Columns
	local columns = {}
	for k = 0, n - 1 do
		local centre, dir, R, y0 = cavernColumn(lm, (k + 0.5) / n * 2 * math.pi)
		columns[k] = { Centre = centre, Dir = dir, R = R, Y0 = y0 }
	end
	for k = 0, n - 1 do
		local col = columns[k]
		-- half the angle to the wider neighbour gap (the rays from the centre are uneven round an ellipse)
		local gap = math.max(math.acos(math.clamp(col.Dir:Dot(columns[(k + 1) % n].Dir), -1, 1)),
			math.acos(math.clamp(col.Dir:Dot(columns[(k - 1) % n].Dir), -1, 1))) / 2
		local H = V.Apex - col.Y0
		local y = col.Y0
		while y < V.Apex - 0.01 do
			local y1 = math.min(y + V.Step, V.Apex)
			local inner = math.max(0, cavernScale(V, (y1 - col.Y0) / H) * col.R - 2)
			local outer = cavernScale(V, (y - col.Y0) / H) * col.R + V.Shell
			local width = 2 * outer * math.tan(gap) + 4
			local banded = math.sin(y / 37 + 1.5 * math.sin(k / n * 6 * math.pi)) > 0.72
			local function slab(r0: number, r1: number, material: Enum.Material)
				local mid = col.Centre + col.Dir * ((r0 + r1) / 2) + Vector3.new(0, (y + y1) / 2, 0)
				table.insert(out, { CFrame = CFrame.lookAt(mid, mid + col.Dir), Size = Vector3.new(width, y1 - y + 4, r1 - r0),
					Material = material, Vault = true })
			end
			slab(inner, outer - 6, if banded then Enum.Material.Slate else Enum.Material.Basalt)
			slab(outer - 6, outer, Enum.Material.Rock)
			y = y1
		end
	end
	return out
end

-- Where the walking route crosses the vault wall (Layout.route's crest over the rim), an air doorway Route.Width + 6 wide from 2 studs over
-- the tread to 26, one box per route point inside the wall band, so the way out of the basin stays open.
function World.cavernExit(lm: any): { any }
	local L, V = World.Layout, lm.Basin and lm.Basin.Cavern
	if not (V and lm.Basin.Route and L and World.Height) then return {} end
	local pts = L.route(lm, World.Height).Points
	local out = {}
	for i, p in pts do
		local inWall = L.basinEllipse(lm, p.X, p.Z, V.Inset - 8) >= 1 and L.basinEllipse(lm, p.X, p.Z, V.Inset + V.Shell + 8) < 1
		local nxt = pts[math.min(i + 1, #pts)]
		local prev = pts[math.max(i - 1, 1)]
		local along = Vector3.new(nxt.X - prev.X, 0, nxt.Z - prev.Z)
		if inWall and along.Magnitude > 0.1 then
			local mid = Vector3.new(p.X, p.Y + 14, p.Z)
			table.insert(out, { CFrame = CFrame.lookAt(mid, mid + along), Size = Vector3.new(lm.Basin.Route.Width + 6, 24, 8),
				Material = Enum.Material.Air, Doorway = true })
		end
	end
	return out
end

-- Light inside the Hollow, placed on the built terrain by raycasts (so nothing floats), with every light anchored, non-colliding and
-- unqueryable. Returns the model and the stalactite terrain fills (FillBall rows, Ball = true). Without Workspace.Raycast it returns an
-- empty model (the test mock). Pieces:
--   veins: kintsugi-style amber Neon cracks climbing the walls and across the ceiling, each with forks, meeting at the iris
--   iris: an eye in the ceiling over the basin centre (the eye of the head leads here): an amber ring, fibre spokes and a light shaft
--   stalactites: Basalt rows hanging over the crown, tips no lower than TipFloor, a glowing crystal on each tip
--   glowstones: teal crystal clusters in the shallows round the shore, a few with a small light
--   motes: slow rising amber sparks over the lake
local AMBER, TEAL = Color3.fromRGB(255, 176, 90), Color3.fromRGB(90, 220, 210)
-- Warm fill up the pilgrim stair (five pairs over the rails) and onto the side tiers (two pairs), from the stair ramp's tread line
-- (rise 0.88, run 2.35). win-83 Studio check: the temple's dark stone read as a black mass under the vault light alone.
function World.stairFill(frame: CFrame): { Vector3 }
	local spots = {}
	for _, i in { 4, 34, 64, 94, 124 } do
		for _, x in { -34, 34 } do table.insert(spots, frame * Vector3.new(x, 10.6 + i * 0.88, 257 - i * 2.35)) end
	end
	for _, i in { 20, 60 } do
		for _, x in { -105, 105 } do table.insert(spots, frame * Vector3.new(x, 14.6 + i * 0.88, 271 - i * 2.35)) end
	end
	return spots
end
function World.cavernLights(lm: any): (Model, { any })
	local model = Instance.new("Model")
	model.Name = "HollowLights"
	local fills = {}
	local L, V = World.Layout, lm.Basin and lm.Basin.Cavern
	if not (V and L and World.Height and (Workspace :: any).Raycast) then return model, fills end
	local rays = RaycastParams.new()
	rays.FilterType = Enum.RaycastFilterType.Include
	rays.FilterDescendantsInstances = { Workspace.Terrain }
	rays.IgnoreWater = true
	local rng = Random.new(9061)
	local function glow(name: string, cf: CFrame, size: Vector3, color: Color3, shape: Enum.PartType?): Part
		local part = Instance.new("Part")
		part.Name, part.Size, part.CFrame, part.Material, part.Color = name, size, cf, Enum.Material.Neon, color
		if shape then part.Shape = shape end
		part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
		part.Parent = model
		return part
	end
	local function light(part: Part, color: Color3, range: number, brightness: number)
		local l = Instance.new("PointLight")
		l.Color, l.Range, l.Brightness, l.Shadows = color, range, brightness, false
		l.Parent = part
	end
	-- the vault's inner surface at (theta, t) found on the terrain: cast outward along the surface normal from 30 studs inside it
	local function onVault(theta: number, t: number): (Vector3?, Vector3?)
		local centre, dir, R, y0 = cavernColumn(lm, theta)
		local H = V.Apex - y0
		t = math.clamp(t, 0, 0.995)
		local s = cavernScale(V, t)
		local slope = R * t ^ (V.Power - 1) * (1 - t ^ V.Power) ^ (1 / V.Power - 1) -- -dr/dt
		local inward = (-dir * H - Vector3.yAxis * slope).Unit
		local p = centre + dir * (s * R) + Vector3.new(0, y0 + t * H, 0)
		local hit = Workspace:Raycast(p + inward * 30, -inward * 80, rays)
		if not hit then return nil, nil end
		return hit.Position, hit.Normal
	end
	local function crack(a: Vector3, b: Vector3, n: Vector3, width: number, name: string)
		local mid = (a + b) / 2 + n * 0.3
		if (b - a).Magnitude < 0.5 then return end
		glow(name, CFrame.lookAt(mid, mid + (b - a), n), Vector3.new(width, width * 0.5, (b - a).Magnitude + width * 0.6), AMBER)
	end
	-- a vein: theta wanders (two slow sines and a jitter per joint) while t climbs; arc steps of ~24 studs; stops at the iris ring
	-- drift: radians of theta per unit t, so a fork leaves its parent at an angle
	local function vein(theta: number, t: number, tEnd: number, width: number, forks: number, drift: number, name: string)
		local prev
		local _, _, R, y0 = cavernColumn(lm, theta)
		local H = V.Apex - y0
		local phase = rng:NextNumber(0, 2 * math.pi)
		local base, t0 = theta, t
		local joints = 0
		while t < tEnd do
			local s = cavernScale(V, t)
			if s * R < V.Iris + 4 then break end
			local th = base + drift * (t - t0) + 0.06 * math.sin(t * 9 + phase) + 0.035 * math.sin(t * 23 + 2 * phase) + rng:NextNumber(-0.008, 0.008)
			local at, n = onVault(th, t)
			if at and prev then crack(prev, at, n, width * (1 + 0.8 * t), name) end
			prev = at
			joints += 1
			if at and forks > 0 and joints % 9 == 0 then
				local side = if joints % 18 == 0 then 1 else -1
				vein(th, t, math.min(1, t + rng:NextNumber(0.08, 0.2)), width * 0.55, forks - 1, side * rng:NextNumber(0.4, 0.9), name .. "Fork")
			end
			local slope = R * t ^ (V.Power - 1) * (1 - t ^ V.Power) ^ (1 / V.Power - 1)
			t += 24 / math.sqrt(H * H + slope * slope)
		end
	end
	for i = 1, V.Veins do
		vein((i - 1) / V.Veins * 2 * math.pi + rng:NextNumber(-0.12, 0.12), rng:NextNumber(0.02, 0.1), 1, 2.4, 2, rng:NextNumber(-0.15, 0.15), "Vein")
	end
	-- the iris: the ceiling straight over the basin centre
	local c = L.basinCentre(lm)
	local function ceiling(x: number, z: number): RaycastResult?
		return Workspace:Raycast(Vector3.new(x, V.TipFloor, z), Vector3.new(0, V.Apex - V.TipFloor + 80, 0), rays)
	end
	local fx, fz = L.front(lm)
	local across, front = Vector3.new(-fz, 0, fx), Vector3.new(fx, 0, fz)
	local ringAt = function(r: number, a: number): Vector3? -- a point on the ceiling at radius r, angle a round the centre
		local hit = ceiling(c.X + (across.X * math.cos(a) + front.X * math.sin(a)) * r, c.Z + (across.Z * math.cos(a) + front.Z * math.sin(a)) * r)
		return hit and hit.Position - Vector3.yAxis * 0.4
	end
	local spokes, last = 32, nil
	for i = 0, spokes do
		local p = ringAt(V.Iris, i / spokes * 2 * math.pi)
		if p and last then crack(last, p, -Vector3.yAxis, 7, "IrisRing") end
		last = p
	end
	last = nil
	for i = 0, spokes do
		local p = ringAt(V.Iris * 0.42, i / spokes * 2 * math.pi)
		if p and last then crack(last, p, -Vector3.yAxis, 3.5, "IrisPupil") end
		last = p
	end
	for i = 0, 23 do
		local a = (i + 0.5) / 24 * 2 * math.pi
		local p0, p1 = ringAt(V.Iris * 0.46, a), ringAt(V.Iris * (0.92 - 0.12 * (i % 2)), a + 0.05 * math.sin(i * 1.7))
		if p0 and p1 then crack(p0, p1, -Vector3.yAxis, 1.8, "IrisFibre") end
	end
	local pupil = ceiling(c.X, c.Z)
	if pupil then
		-- the shaft: a soft additive beam from the pupil down to the lake by the tree
		local top = glow("IrisPupilCore", CFrame.new(pupil.Position - Vector3.yAxis * 1.5), Vector3.new(4, 1, 4), AMBER)
		top.Transparency = 1
		light(top, AMBER, 60, 2)
		local frame = World.templeFrame(lm, lm.Basin.ColossalTemple)
		local _, water = L.basinLevels(lm)
		local foot = Instance.new("Part")
		foot.Name, foot.Size, foot.Transparency = "IrisShaftFoot", Vector3.one, 1
		foot.CFrame = CFrame.new(Vector3.new(frame.X, water + 2, frame.Z))
		foot.Anchored, foot.CanCollide, foot.CanQuery, foot.CanTouch = true, false, false, false
		foot.Parent = model
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Parent, a1.Parent = top, foot
		local beam = Instance.new("Beam")
		beam.Name, beam.Attachment0, beam.Attachment1 = "IrisShaft", a0, a1
		beam.Width0, beam.Width1, beam.FaceCamera, beam.Segments = 26, 150, true, 1
		beam.LightEmission, beam.LightInfluence, beam.Brightness = 1, 0, 1.4
		beam.Color = ColorSequence.new(AMBER, Color3.fromRGB(255, 226, 170))
		beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.6, 0.86), NumberSequenceKeypoint.new(1, 1) })
		beam.Parent = top
	end
	-- stalactites over the crown: a row of shrinking terrain balls from the ceiling down, then a crystal tip (every fourth one lit)
	local count = 0
	for i = 1, V.Stalactites * 3 do
		if count >= V.Stalactites then break end
		local a = rng:NextNumber(0, 2 * math.pi)
		local f = rng:NextNumber(0.12, 0.72)
		local x = c.X + (across.X * math.cos(a) * lm.Basin.Width / 2 + front.X * math.sin(a) * lm.Basin.Depth / 2) * f
		local z = c.Z + (across.Z * math.cos(a) * lm.Basin.Width / 2 + front.Z * math.sin(a) * lm.Basin.Depth / 2) * f
		local hit = ceiling(x, z)
		if not hit or hit.Position.Y - V.TipFloor < 30 then continue end
		count += 1
		local len = math.min(hit.Position.Y - V.TipFloor, rng:NextNumber(36, 130))
		local top, tip = hit.Position.Y + 6, hit.Position.Y - len
		local thick = 5 + len * 0.13
		local balls = math.ceil((top - tip) / 6)
		for b = 0, balls - 1 do
			local u = b / balls
			local y = top - (top - tip) * u
			table.insert(fills, { CFrame = CFrame.new(x + math.sin(u * 4 + i) * u * 2, y, z), Size = Vector3.one * 2 * (2 + (thick - 2) * (1 - u) ^ 1.4),
				Material = if b % 5 == 4 then Enum.Material.Slate else Enum.Material.Basalt, Ball = true })
		end
		local color = if count % 3 == 0 then AMBER else TEAL
		local crystal = glow("StalactiteTip", CFrame.new(x, tip - 2.5, z) * CFrame.Angles(0, a, 0) * CFrame.Angles(0, 0, math.rad(45)),
			Vector3.new(2.4, 2.4, 2.4), color)
		local spike = glow("StalactiteTip", CFrame.new(x, tip - 6, z) * CFrame.Angles(0, a, 0), Vector3.new(1.4, 7, 1.4), color)
		if count % 4 == 0 then light(crystal, color, 50, 1.6) end
		spike.Name = "StalactiteSpike"
	end
	-- glowstones: clusters of three tilted teal prisms in the shallows inside the shore
	local floorY, waterY = L.basinLevels(lm)
	for k = 1, V.Glowstones do
		local theta = (k - 0.5) / V.Glowstones * 2 * math.pi + rng:NextNumber(-0.03, 0.03)
		local x, z = L.basinRing(lm, theta, -rng:NextNumber(4, 34))
		local hit = Workspace:Raycast(Vector3.new(x, waterY + 40, z), Vector3.new(0, -80, 0), rays)
		if not hit or hit.Position.Y > waterY + 4 or hit.Position.Y < floorY - lm.Basin.Deep - 2 then continue end
		local up = CFrame.lookAt(hit.Position, hit.Position + hit.Normal) * CFrame.Angles(-math.pi / 2, 0, 0) -- Y along the normal
		local first
		for j = 1, 3 do
			local h = rng:NextNumber(2.5, 6.5)
			local lean = CFrame.Angles(rng:NextNumber(-0.45, 0.45), j * 2.1, rng:NextNumber(-0.45, 0.45))
			local cf = up * CFrame.new(rng:NextNumber(-1.2, 1.2), 0, rng:NextNumber(-1.2, 1.2)) * lean * CFrame.new(0, h / 2 - 0.6, 0)
			local p = glow("Glowstone", cf, Vector3.new(rng:NextNumber(1, 1.9), h, rng:NextNumber(1, 1.9)), TEAL)
			first = first or p
		end
		if k % 8 == 0 then light(first, TEAL, 40, 1.3) end
	end
	for _, at in World.stairFill(World.templeFrame(lm, lm.Basin.ColossalTemple)) do
		local spot = glow("StairFill", CFrame.new(at), Vector3.one, AMBER)
		spot.Transparency = 1
		light(spot, AMBER, 60, 2.6)
	end
	-- motes over the lake, emitted from a thin invisible slab across the basin
	local field = Instance.new("Part")
	field.Name, field.Transparency = "HollowMotes", 1
	field.Size = Vector3.new(lm.Basin.Width * 0.9, 2, lm.Basin.Depth * 0.9)
	field.CFrame = CFrame.lookAt(Vector3.new(c.X, waterY + 24, c.Z), Vector3.new(c.X, waterY + 24, c.Z) + front)
	field.Anchored, field.CanCollide, field.CanQuery, field.CanTouch = true, false, false, false
	local motes = Instance.new("ParticleEmitter")
	motes.Name, motes.Shape, motes.ShapeStyle, motes.EmissionDirection = "Motes", Enum.ParticleEmitterShape.Box, Enum.ParticleEmitterShapeStyle.Volume, Enum.NormalId.Top
	motes.Rate, motes.Lifetime, motes.Speed = 140, NumberRange.new(14, 24), NumberRange.new(1.2, 3)
	motes.Acceleration, motes.SpreadAngle, motes.LightEmission, motes.Brightness = Vector3.new(0, 0.3, 0), Vector2.new(20, 20), 1, 2
	motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.15, 0.55), NumberSequenceKeypoint.new(0.8, 0.4), NumberSequenceKeypoint.new(1, 0) })
	motes.Color = ColorSequence.new(AMBER, TEAL)
	motes.Transparency = NumberSequence.new(0.15)
	motes.Parent = field
	field.Parent = model
	return model, fills
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
			local T, templePlaced = lm.Basin and lm.Basin.Temple, false
			local candidate = lm.Basin and lm.Basin.ColossalTemple
			local colossalFrame: CFrame? = nil
			if candidate and #candidate.Pieces > 0 then
				local frame = World.templeFrame(lm, candidate)
				local pack = Instance.new("Model")
				pack.Name = candidate.Model
				-- LandscapeBudget hid the crown past 900 studs and faded the eaves and windows by size, leaving bare black tiers
				pack:SetAttribute("AsuraKeepFar", true)
				for _, piece in candidate.Pieces do
					local pose = frame * CFrame.new(piece.X, piece.Y, piece.Z)
						* CFrame.Angles(0, piece.Yaw or 0, 0) * CFrame.new(piece.Foot.X, piece.Foot.Y, piece.Foot.Z)
					local placedPiece = Kit.place(piece.Model, pose, Vector3.one, { Fidelity = {}, Omit = candidate.Omit })
					if not placedPiece then break end
					placedPiece.Parent = pack
				end
				if #pack:GetChildren() == #candidate.Pieces then
					local collision = World.colossalTempleCollision(frame)
					collision.Parent = pack
					colossalFrame, templePlaced, T = frame, true, candidate
					pack.Parent = model
				else
					pack:Destroy()
				end
			end
			if T and not templePlaced then
				local m = Kit.place(T.Model, World.templeFrame(lm) * CFrame.new(T.Foot.X, T.Foot.Y, T.Foot.Z), Vector3.one, { Fidelity = World.Fidelity })
				if m then m.Parent, templePlaced = model, true else warn("[LandmarkWorld] " .. id .. ": kit piece " .. T.Model .. " is not available") end
			end
			local G, gatePlaced = lm.Basin and lm.Basin.Gate, false
			if G then
				local m = Kit.place(G.Model, World.gateFrame(lm) * CFrame.new(G.Foot.X, G.Foot.Y, G.Foot.Z), Vector3.one, { Fidelity = World.Fidelity })
				if m then m.Parent, gatePlaced = model, true else warn("[LandmarkWorld] " .. id .. ": kit piece " .. G.Model .. " is not available") end
			end
			if lm.Basin and (templePlaced or gatePlaced) then
				World.accents(lm, { Temple = templePlaced, Gate = gatePlaced }, T).Parent = model
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
				local sinceWait, volumeSinceWait = 0, 0
				local function fill(f: any) -- one terrain write, then hand the frame back often enough that the server keeps ticking
					if f.Wedge then terrain:FillWedge(f.CFrame, f.Size, f.Material)
					elseif f.Ball then terrain:FillBall(f.CFrame.Position, f.Size.X / 2, f.Material)
					else terrain:FillBlock(f.CFrame, f.Size, f.Material) end
					sinceWait += 1
					volumeSinceWait += f.Size.X * f.Size.Y * f.Size.Z
					if sinceWait >= World.YieldEvery or volumeSinceWait >= World.YieldVolume then
						sinceWait, volumeSinceWait = 0, 0
						task.wait()
					end
				end
				for _, p in World.packs(lm) do fill({ CFrame = p.CFrame, Size = p.Size, Material = Enum.Material.Rock }) end
				for _, f in World.basin(lm) do fill(f) end
				if colossalFrame then
					for _, f in World.colossalRidgeFills(lm) do fill(f) end
				end
				for _, c in World.carves(lm) do fill({ CFrame = c.CFrame, Size = c.Size, Material = Enum.Material.Air }) end -- the passage cuts the rim
				local lake = World.lake(lm)
				for _, f in lake do fill(f) end
				if colossalFrame then
					for _, f in World.colossalApproach(lm, colossalFrame) do fill(f) end
					model:SetAttribute("ColossalTemplePlayableTop", colossalFrame.Y + 122)
					if T.Chimes then
						model:SetAttribute("ColossalTempleChimes", colossalFrame * Vector3.new(T.Chimes.X, T.Chimes.Y, T.Chimes.Z))
					end
				end
				if gatePlaced then -- no ledge in the lake without its stair
					for _, f in World.gateFills(lm) do fill(f) end
					for _, f in World.routeFills(lm) do fill(f) end
					for _, lantern in World.routeLanterns(lm) do lantern.Parent = model end
				end
				if colossalFrame and lm.Basin.Cavern then -- the Hollow closes over the colossal temple only; the doorway is cut after the vault
					for _, f in World.cavernShell(lm) do fill(f) end
					for _, f in World.cavernExit(lm) do fill(f) end
					local lights, stalactites = World.cavernLights(lm)
					for _, f in stalactites do fill(f) end
					lights.Parent = model
					model:SetAttribute("Cavern", true)
					Workspace:SetAttribute("AsuraCavern", true) -- clients grade the basin as a cave (EnvironmentProfiles Cavern)
				end
				model:SetAttribute("BoreCarved", true)
				model:SetAttribute("BasinSculpted", #lake > 0)
			end
		end)
	end
end

return World
