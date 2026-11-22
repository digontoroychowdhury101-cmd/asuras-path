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
	-- hidden 350 x 300 basin directly behind the face, 400+ studs from any road or river.
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
			Passage = { { -24, -80, -27 }, { -28, -104, -27 }, { -30, -132, -27 } } },
		-- Hidden basin (spec): an ellipse Width across x Depth along the front, centre Back studs behind the origin. Bed = lake bed top
		-- relative to Origin.Y, on the 4-stud voxel grid (a bed top inside a voxel ate the water, mac-88) and 1 under the passage floor;
		-- Water = lake depth over it. A rock rim Thick studs wide rings it, RimRise over the
		-- local surface (plus a little wobble), so no road sees in (tools/test_landmark_layout.luau casts from 8 road points).
		-- TempleTop = how high over the floor the temple may stand and stay hidden.
		-- Deep = how much deeper the lake gets Shelf studs in from the shore (mac-89: a 2.5-stud lake showed the bed's voxel ridges
		-- through the water as dark dashes); keeps the deep bed on the 4-stud voxel grid.
		Basin = { Back = 260, Width = 350, Depth = 300, Bed = -36, Water = 2.5, Thick = 28, RimRise = 24, TempleTop = 70, Deep = 8, Shelf = 36,
			-- The Sunken Temple hall (tools/blender/landmarks/bellwood_temple_hall.py, mac-90): its origin (platform centre, foot) stands
			-- Across/Along studs off the basin centre (basin axes: Along = toward the face) and Lift over the lake bed, so the stair
			-- wades in and the deck (Deck over the foot) is just over the water. Radius = footprint half-diagonal, Height = roof top.
			-- It turns to face the passage exit (LandmarkWorld.templeFrame). Foot = GLB foot frame from its manifest (model axes).
			Temple = { Model = "Bellwood_TempleHall", Across = -60, Along = -20, Lift = -1, Radius = 55, Deck = 3.6, Height = 59.4,
				Foot = { X = 0, Y = 0, Z = 4.115 } },
			-- The temple's twin gate towers and moss stair (tools/blender/landmarks/bellwood_gate_towers.py, mac-91; concept bellwood_3,
			-- left third): origin = tower-line centre on the bed, Across/Along/Lift as the temple, front (model +Z) to the basin centre
			-- (LandmarkWorld.gateFrame). Model Z: lowest step front edge at Steps, landing (Width wide, top Landing over the origin) back
			-- to Back; the stair climbs away from the lake to a terrain ledge (LandmarkWorld.gateFills). Height = finial top.
			-- Foot from assets/source/landmarks/bellwood_gate/manifest.json (bbox x -27.06..27.33, y -40.8..13.49, z min -0.58).
			Gate = { Model = "Bellwood_GateTowers", Across = 105, Along = -60, Lift = 0, Radius = 42, Steps = 10, Back = -40.8,
				Width = 15, Landing = 14, Height = 50.2, Foot = { X = -0.135, Y = -0.58, Z = -13.655 } } },
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
