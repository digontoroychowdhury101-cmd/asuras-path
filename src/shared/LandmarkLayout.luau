--!strict
-- Open-world landmark layout (LANDMARK-BUILD-SPEC, "Shared rules"). Pure numbers, no Roblox types; tools/test_landmark_layout.luau
-- checks every entry against the real Overworld (region box, 250-stud clearance, roads, rivers, terrain, orientation).
-- Frame per landmark: Origin = kit foot-centre on the terrain (studs, world), Yaw in degrees about +Y. The Blender kits face +Y
-- (tunnel mouth) = glTF -Z, and a Roblox import is glTF turned 180 deg about Y (tools/assets/glb_split.py), so the mouth is model
-- +Z and the front in world XZ is (sin Yaw, cos Yaw) for CFrame.Angles(0, rad(Yaw), 0). Every kit piece of a landmark shares
-- the origin; Foot places each GLB's own foot frame back on it so the pieces line up exactly as baked.
local Layout = {}

export type Vec = { X: number, Y: number, Z: number }

Layout.Landmarks = {
	-- Bellwood: the Fallen Giant's Face (tools/blender/landmarks/bellwood_giant_face.py + bellwood_giant_crown.py). Chosen by a
	-- site search (mac-85): flat forest floor 149 studs off the Bell Terrace > Hermit Hut road, mouth toward the road, the
	-- hidden basin directly behind the face, with clearances checked against roads and rivers.
	Bellwood = {
		Region = "Forest",
		Origin = { X = -3430, Y = 184, Z = -2350 },
		Yaw = 94,
		FootprintRadius = 82, -- face bbox 126 x 104 half-diagonal
		MinClearance = 250,
		-- The eye leads underground (creator 2026-11-22): level into the lower eye socket, then a bending descent of 35 studs over
		-- 150 (kit, Blender axes: +Y = mouth, Z up). The mesh bore ends at End; terrain carves the rest of the passage to the basin.
		-- Path = the bore centre line (TUNNEL in bellwood_giant_face.py, radius Radius); the walk floor runs 8 below it.
		Tunnel = { Width = 16.4, Height = 16.4, Length = 150, Descent = 35, Run = 140, End = { X = -24, Y = -80, Z = -35 }, Radius = 8.2,
			Path = { { -4, 60, 8 }, { -4, 34, 8 }, { 2, 14, 3 }, { 8, -8, -5 }, { 4, -32, -13 }, { -8, -56, -21 }, { -24, -80, -27 } },
			-- Two warm lantern niches (spec): kit points 5 studs off the centre line toward the wall, 1.5 under it.
			Lanterns = { { 4, 24, 4 }, { 2.5, -46, -18.5 } },
			-- Terrain passage on from the mesh End, level at the basin floor, out through the rim into the basin (kit axes, centre line).
			-- Enlarged basin (22 Nov, BELLWOOD_EXPANSION_PLAN): the front shore is 190 behind the origin, so the level passage runs on to
			-- kit y -215 (24 studs inside the bowl, ellipse 0.92) and the exit opens at the shore.
			Passage = { { -24, -80, -27 }, { -28, -104, -27 }, { -30, -132, -27 }, { -34, -165, -27 }, { -38, -195, -27 }, { -41, -215, -27 } } },
		-- Hidden basin (spec): an ellipse Width across x Depth along the front, centre Back studs behind the origin. Bed = lake bed top
		-- relative to Origin.Y, on the 4-stud voxel grid (a bed top inside a voxel ate the water, mac-88) and 1 under the passage floor;
		-- Water = lake depth over it. A rock rim Thick studs wide rings it, RimRise over the
		-- local surface (plus a little wobble), so no road sees in (tools/test_landmark_layout.luau casts from 8 road points).
		-- TempleTop = how high over the floor the temple may stand and stay hidden.
		-- Deep = how much deeper the lake gets Shelf studs in from the shore (mac-89: a 2.5-stud lake showed the bed's voxel ridges
		-- through the water as dark dashes); keeps the deep bed on the 4-stud voxel grid.
		-- Enlarged 22 Nov 2026 to 1400 x 1120, centre 750 behind the origin (BELLWOOD_EXPANSION_PLAN.md, survey.luau): Thick 40, RimRise 60,
		-- Shelf 60, Segments 320 rim chords (~27 studs each). Along/Across in Temple, Gate and Route are this file's basin axes (Along toward the
		-- face, Across to the left in the exit view); the plan writes both with the opposite sign.
		Basin = { Back = 750, Width = 1400, Depth = 1120, Bed = -36, Water = 2.5, Thick = 40, RimRise = 60, Segments = 320, TempleTop = 70, Deep = 8, Shelf = 60,
			-- Keep the steep apron above the eye passage open from the back of the giant face to the basin's front shore.
			Apron = { Back = 76, HalfWidth = 144 },
			-- The Sunken Temple hall (tools/blender/landmarks/bellwood_temple_hall.py, mac-90): its origin (platform centre, foot) stands
			-- Across/Along studs off the basin centre (basin axes: Along = toward the face) and Lift over the lake bed, so the stair
			-- wades in and the deck (Deck over the foot) is just over the water. Radius = footprint half-diagonal, Height = roof top.
			-- It turns to face the passage exit (LandmarkWorld.templeFrame). Foot = GLB foot frame from its manifest (model axes).
			Temple = { Model = "Bellwood_TempleHall", Across = -110, Along = 20, Lift = -1, Radius = 55, Deck = 3.6, Height = 59.4,
				Foot = { X = 0, Y = 0, Z = 4.115 } },
			-- The temple's twin gate towers and moss stair (tools/blender/landmarks/bellwood_gate_towers.py, mac-91; concept bellwood_3,
			-- left third): origin = tower-line centre on the bed, Across/Along/Lift as the temple, front (model +Z) to the basin centre
			-- (LandmarkWorld.gateFrame). Model Z: lowest step front edge at Steps, landing (Width wide, top Landing over the origin) back
			-- to Back; the stair climbs away from the lake to a terrain ledge (LandmarkWorld.gateFills). Height = finial top.
			-- Foot from assets/source/landmarks/bellwood_gate/manifest.json (bbox x -27.06..27.33, y -40.8..13.49, z min -0.58).
			Gate = { Model = "Bellwood_GateTowers", Across = 150, Along = 140, Lift = 0, Radius = 42, Steps = 10, Back = -40.8,
				Width = 15, Landing = 14, Height = 50.2, Foot = { X = -0.135, Y = -0.58, Z = -13.655 } },
			-- Walkable route gate landing -> rim -> forest (plan section 3; Layout.route builds it, LandmarkWorld.routeFills writes it): a
			-- Width-wide causeway from the landing to the left shore at Theta (degrees on the ring, Layout.basinRing's angle), a switchback of
			-- legs rising Rise each at slope Slope (rise/run, 22 deg) with Pad-long landings, parked Margin off the cliff, topping out on the rim
			-- segment's own cap, across it and down the outer slope, then Forest studs on into the forest. Max = hard gradient limit (deg).
			Route = { Theta = 60, Width = 14, Rise = 22, Slope = 0.4, Pad = 16, Margin = 10, Forest = 90, Step = 4, Max = 35 } },
		-- Grove (SliceDressing): forest scatter in R round the origin. Nothing tall within Clear (the face), and a lane LaneHalf wide from
		-- the mouth out LaneTo studs along the front (the road sightline) stays open. Ferns and grass hug the base from Clear - 12.
		Grove = { R = 150, Clear = 70, LaneHalf = 16, LaneTo = 170 },
		-- Foot = where each GLB's foot (bbox centre X/Z, bbox minimum Y: tools/assets/glb_split.py) sits relative to the shared
		-- kit origin, in Roblox model axes (Blender x, y, z -> -x, z, y), from assets/source/landmarks/bellwood_face/manifest.json.
		Pieces = {
			Face = { Model = "Bellwood_GiantFace", Foot = { X = -3.34, Y = -39.23, Z = -18.56 } },
			Crown = { Model = "Bellwood_GiantCrown", Foot = { X = -0.495, Y = -0.65, Z = -6.705 } },
		},
	},
}

-- World XZ unit vector the landmark faces (the tunnel mouth for Bellwood).
function Layout.front(lm: any): (number, number)
	local a = math.rad(lm.Yaw)
	return math.sin(a), math.cos(a)
end

function Layout.basinCentre(lm: any): Vec
	local fx, fz = Layout.front(lm)
	local o = lm.Origin
	return { X = o.X - fx * lm.Basin.Back, Y = o.Y, Z = o.Z - fz * lm.Basin.Back }
end

function Layout.basinCorners(lm: any): { Vec }
	local fx, fz = Layout.front(lm)
	local rx, rz = -fz, fx
	local c = Layout.basinCentre(lm)
	local w, d = lm.Basin.Width / 2, lm.Basin.Depth / 2
	local out = {}
	for _, s in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
		table.insert(out, { X = c.X + rx * w * s[1] + fx * d * s[2], Y = c.Y, Z = c.Z + rz * w * s[1] + fz * d * s[2] })
	end
	return out
end

-- Basin frame: centre XZ, the front axis (along) and the side axis (across).
local function basinAxes(lm: any): (Vec, number, number, number, number)
	local fx, fz = Layout.front(lm)
	return Layout.basinCentre(lm), fx, fz, -fz, fx
end

-- Ellipse value of a world XZ point: < 1 inside the basin (pad studs grows both semi-axes).
function Layout.basinEllipse(lm: any, x: number, z: number, pad: number?): number
	local c, fx, fz, rx, rz = basinAxes(lm)
	local dx, dz = x - c.X, z - c.Z
	local across, along = dx * rx + dz * rz, dx * fx + dz * fz
	local a, b = lm.Basin.Width / 2 + (pad or 0), lm.Basin.Depth / 2 + (pad or 0)
	return (across / a) ^ 2 + (along / b) ^ 2
end

-- Basin grade weight at a world XZ (0..1, max over every landmark with a basin): 1 inside the shore, easing to 0 a little past it
-- (30 studs wide on the short semi-axis, 18 of them outside), so the grade is gone before the forest beyond the rim.
function Layout.basinWeight(x: number, z: number): number
	local w = 0
	for _, lm in Layout.Landmarks do
		if not lm.Basin then continue end
		-- the blend is a fixed 30 studs wide whatever the basin's size: 1 from 12 studs inside the shore (on the short axis) to 0 at 18 past it
		local short = math.min(lm.Basin.Width, lm.Basin.Depth) / 2
		local t = math.clamp((1 + 18 / short - math.sqrt(Layout.basinEllipse(lm, x, z))) / (30 / short), 0, 1)
		w = math.max(w, t * t * (3 - 2 * t))
	end
	return w
end

-- World XZ of the ellipse at angle theta, pushed out studs past the shore (along the semi-axes).
function Layout.basinRing(lm: any, theta: number, out: number): (number, number)
	local c, fx, fz, rx, rz = basinAxes(lm)
	local across, along = math.cos(theta) * (lm.Basin.Width / 2 + out), math.sin(theta) * (lm.Basin.Depth / 2 + out)
	return c.X + rx * across + fx * along, c.Z + rz * across + fz * along
end

-- Rim cliff top at angle theta: RimRise over the surface at the rim's middle, with a deterministic wobble (+-7).
function Layout.rimTop(lm: any, theta: number, heightAt: (number, number) -> number): number
	local x, z = Layout.basinRing(lm, theta, lm.Basin.Thick / 2)
	return heightAt(x, z) + lm.Basin.RimRise + 4 * math.sin(3 * theta) + 3 * math.sin(7 * theta + 1)
end

-- The final ground height at x, z once a sunken basin is carved (lake bed in the bowl, cap top on the rim, the outer grass slope past
-- it), or nil away from every basin. Dressing placed before the carve lands on this, not on the pre-carve ground (it floated).
-- The slope mirrors LandmarkWorld.basin: top at the rim's outer edge, run 1.8 x drop, never under the forest floor + 2.
function Layout.carvedSurface(x: number, z: number, heightAt: (number, number) -> number): number?
	for _, lm in Layout.Landmarks do
		if not lm.Basin then continue end
		if Layout.basinEllipse(lm, x, z) < 1 then return (Layout.basinLevels(lm)) end
		if Layout.basinEllipse(lm, x, z, lm.Basin.Thick + 300) >= 1 then continue end -- past the slope's longest run
		local c, fx, fz, rx, rz = basinAxes(lm)
		local dx, dz = x - c.X, z - c.Z
		local across, along = dx * rx + dz * rz, dx * fx + dz * fz
		local a, b = lm.Basin.Width / 2, lm.Basin.Depth / 2
		-- The ring angle of this point: the ellipse grown by `out` that passes through it (Layout.basinRing pushes along the semi-axes, so the
		-- angle atan2 gives on the bare ellipse drifts by whole chords out on the slope).
		local lo, hi = 0, lm.Basin.Thick + 300
		for _ = 1, 16 do
			local mid = (lo + hi) / 2
			if (across / (a + mid)) ^ 2 + (along / (b + mid)) ^ 2 < 1 then hi = mid else lo = mid end
		end
		local theta = math.atan2(along / (b + hi), across / (a + hi))
		-- World.basin builds each rim chord with its start-angle rim top and its mid-angle slope, so quantise to the chord (a 320-chord ring
		-- changes ground by several studs across one chord)
		local n = lm.Basin.Segments
		local seg = math.floor((theta % (2 * math.pi)) / (2 * math.pi) * n)
		local top = Layout.rimTop(lm, seg / n * 2 * math.pi, heightAt)
		theta = (seg + 0.5) / n * 2 * math.pi
		if Layout.basinEllipse(lm, x, z, lm.Basin.Thick) < 1 then return top end
		local ex, ez = Layout.basinRing(lm, theta, lm.Basin.Thick)
		local drop = math.max(4, top - heightAt(ex, ez))
		local run = math.max(8, drop * 1.8)
		local fx2, fz2 = Layout.basinRing(lm, theta, lm.Basin.Thick + run)
		local slopeX, slopeZ = fx2 - ex, fz2 - ez
		local s = math.max(0, ((x - ex) * slopeX + (z - ez) * slopeZ) / math.sqrt(slopeX ^ 2 + slopeZ ^ 2))
		if s > run + 0.5 then continue end
		local base = math.min(heightAt(ex, ez), heightAt(fx2, fz2)) - 6
		return math.max(heightAt(x, z) + 2, top - (top - base) * s / (run + 1))
	end
	return nil
end

-- The walkable route gate landing -> rim -> forest (Basin.Route, BELLWOOD_EXPANSION_PLAN section 3). Pure numbers:
--   Frame = the shore frame at the middle of rim segment Route.Theta falls in: P (shore point), T (chord direction), N (outward), all XZ;
--           local (t, n) = P + T t - N n, n = studs in from the shore.
--   Causeway = { A, B } deck centre line from the gate landing to the first leg (constant Y = gate landing top).
--   Legs = { Lane (n of the centre), T0, T1 (start, end along T), Z0, Z1 (surface Y at each end) }; Landings = { T0, T1, N0, N1, Z } (one per
--   leg: after the last, the top landing, Rim = true, reaches back into the cap).
--   Points = the whole centre line every Step studs { X, Y, Z, Kind }: causeway, leg, landing, crest (flat across the rim cap), slope (the outer
--   grass slope, as World.basin writes it) and forest (natural ground, Route.Forest studs past the slope's foot). Crest = the segment's cap top.
function Layout.route(lm: any, heightAt: (number, number) -> number): any
	local B = lm.Basin
	local R = B.Route
	local th, n, W = B.Thick, B.Segments, R.Width
	local function unit(x: number, z: number): (number, number)
		local l = math.sqrt(x * x + z * z)
		return x / l, z / l
	end
	local k = math.floor(math.rad(R.Theta) / (2 * math.pi) * n) % n
	local t0, t1, tm = k / n * 2 * math.pi, (k + 1) / n * 2 * math.pi, (k + 0.5) / n * 2 * math.pi
	local x0, z0 = Layout.basinRing(lm, t0, th / 2)
	local x1, z1 = Layout.basinRing(lm, t1, th / 2)
	local cx, cz = Layout.basinRing(lm, tm, th / 2)
	local ox, oz = Layout.basinRing(lm, tm, th / 2 + 1)
	local Tx, Tz = unit(x1 - x0, z1 - z0)
	local Nx, Nz = Tz, -Tx
	if Nx * (ox - cx) + Nz * (oz - cz) < 0 then Nx, Nz = -Nx, -Nz end
	local Px, Pz = cx - Nx * th / 2, cz - Nz * th / 2
	local function at(t: number, nn: number): (number, number)
		return Px + Tx * t - Nx * nn, Pz + Tz * t - Nz * nn
	end
	local crest = Layout.rimTop(lm, t0, heightAt) -- World.basin: tops[k] = rimTop at the segment's start angle
	local gate = Layout.gateSpot(lm)
	local deck = gate.Y + B.Gate.Landing
	local L = math.max(1, math.ceil((crest - deck) / R.Rise))
	local per = (crest - deck) / L
	local run = per / R.Slope
	local legs, landings = {}, {}
	local points: { any } = {}
	local function push(x: number, y: number, z: number, kind: string)
		table.insert(points, { X = x, Y = y, Z = z, Kind = kind })
	end
	-- straight stretch from the last point to (x, y, z), a point every Step studs
	local function to(x: number, y: number, z: number, kind: string)
		local a = points[#points]
		local len = math.sqrt((x - a.X) ^ 2 + (z - a.Z) ^ 2)
		local m = math.max(1, math.ceil(len / R.Step))
		for i = 1, m do push(a.X + (x - a.X) * i / m, a.Y + (y - a.Y) * i / m, a.Z + (z - a.Z) * i / m, kind) end
	end
	-- causeway start: the gate stair's landing, 12 studs into its ledge (gate frame: front = toward the basin centre)
	local c = Layout.basinCentre(lm)
	local ux, uz = unit(c.X - gate.X, c.Z - gate.Z)
	local ax, az = gate.X + ux * (B.Gate.Back - 12), gate.Z + uz * (B.Gate.Back - 12)
	local lane = function(i: number): number return R.Margin + W / 2 + (L - i) * W end
	local dir = function(i: number): number return if (L - i) % 2 == 0 then 1 else -1 end
	-- every leg spans [lo, hi] along T; the top leg ends Pad / 2 short of the segment's middle so its landing is centred on it (the
	-- crossing then runs through the middle of the rim segment, whose cap is the crest)
	local tEnd = -dir(L) * R.Pad / 2
	local lo = if dir(L) == 1 then tEnd - run else tEnd
	local hi = lo + run
	local startT = if dir(1) == 1 then lo else hi
	local sx, sz = at(startT, lane(1))
	push(ax, deck, az, "causeway")
	to(sx, deck, sz, "causeway")
	local causeway = { A = { X = ax, Z = az }, B = { X = sx, Z = sz }, Y = deck }
	for i = 1, L do
		local d = dir(i)
		local tA, tB = if d == 1 then lo else hi, if d == 1 then hi else lo
		local zA, zB = deck + (i - 1) * per, deck + i * per
		table.insert(legs, { Lane = lane(i), T0 = tA, T1 = tB, Z0 = zA, Z1 = zB })
		local ex, ez = at(tB, lane(i))
		to(ex, zB, ez, "leg")
		local mid = tB + d * R.Pad / 2
		local landing = { T0 = math.min(tB, tB + d * R.Pad), T1 = math.max(tB, tB + d * R.Pad),
			N0 = lane(i + 1) - W / 2, N1 = lane(i) + W / 2, Z = zB, Rim = false }
		if i == L then
			landing.N0, landing.Rim = -2, true -- the top landing reaches back into the rim cap
			landing.N1 = lane(i) + W / 2
		end
		table.insert(landings, landing)
		local px1, pz1 = at(mid, lane(i))
		to(px1, zB, pz1, "landing")
		if i < L then
			local px2, pz2 = at(mid, lane(i + 1))
			to(px2, zB, pz2, "landing")
			local sx2, sz2 = at(tB, lane(i + 1))
			to(sx2, zB, sz2, "landing")
		end
	end
	-- across the rim cap (flat at the crest), then the outer slope exactly as World.basin builds it
	local gx, gz = at(0, -th)
	to(gx, crest, gz, "crest")
	local rx, rz = Layout.basinRing(lm, tm, th)
	local drop = math.max(4, crest - heightAt(rx, rz))
	local slopeRun = math.max(8, drop * 1.8)
	local fx2, fz2 = Layout.basinRing(lm, tm, th + slopeRun)
	local base = math.min(heightAt(rx, rz), heightAt(fx2, fz2)) - 6
	local vx, vz = unit(ox - cx, oz - cz)
	local reach = slopeRun + R.Forest
	local steps = math.ceil(reach / R.Step)
	for i = 1, steps do
		local s = i * reach / steps
		local x, z = gx + Nx * s, gz + Nz * s
		local sd = math.max(0, (x - rx) * vx + (z - rz) * vz)
		local y = math.max(heightAt(x, z), crest - (crest - base) * math.min(sd, slopeRun + 1) / (slopeRun + 1))
		push(x, y, z, if s <= slopeRun then "slope" else "forest")
	end
	return { Frame = { X = Px, Z = Pz, Tx = Tx, Tz = Tz, Nx = Nx, Nz = Nz }, Crest = crest, Deck = deck, Rise = per, Run = run, Segment = k,
		Causeway = causeway, Legs = legs, Landings = landings, Points = points, SlopeRun = slopeRun }
end

-- World XZ of a route frame point: P + T t - N n.
function Layout.routeAt(route: any, t: number, nn: number): (number, number)
	local f = route.Frame
	return f.X + f.Tx * t - f.Nx * nn, f.Z + f.Tz * t - f.Nz * nn
end

-- The outer slope and forest stretch as one lane segment { X0, Z0, X1, Z1 }.
function Layout.routeLane(route: any): { number }
	local pts = route.Points
	local first = pts[#pts]
	for _, p in pts do if p.Kind == "slope" then first = p break end end
	return { first.X, first.Z, pts[#pts].X, pts[#pts].Z }
end

-- World position of a basin piece's origin (Across / Along off the basin centre, Lift over the lake bed).
local function basinSpot(lm: any, P: any): Vec
	local c, fx, fz, rx, rz = basinAxes(lm)
	return { X = c.X + rx * P.Across + fx * P.Along, Y = lm.Origin.Y + lm.Basin.Bed + P.Lift, Z = c.Z + rz * P.Across + fz * P.Along }
end

-- World position of the temple hall's origin (platform centre, on its foot).
function Layout.templeSpot(lm: any): Vec
	return basinSpot(lm, lm.Basin.Temple)
end

-- World position of the gate towers' origin (tower-line centre, on the lake bed).
function Layout.gateSpot(lm: any): Vec
	return basinSpot(lm, lm.Basin.Gate)
end

-- World Y of the lake bed and the water surface.
function Layout.basinLevels(lm: any): (number, number)
	local f = lm.Origin.Y + lm.Basin.Bed
	return f, f + lm.Basin.Water
end

return Layout
