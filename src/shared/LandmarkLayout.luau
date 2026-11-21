--!strict
-- Open-world landmark layout (LANDMARK-BUILD-SPEC, "Shared rules"). Pure numbers, no Roblox types; tools/test_landmark_layout.luau
-- checks every entry against the real Overworld (region box, 250-stud clearance, roads, rivers, terrain, orientation).
-- Frame per landmark: Origin = kit foot-centre on the terrain (studs, world), Yaw in degrees about +Y. The Blender kits face +Y
-- (tunnel mouth) = glTF -Z, and a Roblox import is glTF turned 180 deg about Y (tools/assets/glb_split.py), so the mouth is model
-- +Z and the front in world XZ is (sin Yaw, cos Yaw) for CFrame.Angles(0, rad(Yaw), 0). Every kit piece of a landmark shares
-- the origin (Offset 0) so the GLBs line up exactly as baked.
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
		Tunnel = { Width = 16.4, Height = 16.4, Length = 150, Descent = 35, Run = 140, End = { X = -24, Y = -80, Z = -35 } },
		Basin = { Back = 260, Width = 350, Depth = 300 }, -- centre Back studs behind the origin, Width across, Depth along the front
		Pieces = {
			Face = { Model = "Bellwood_GiantFace", Offset = { X = 0, Y = 0, Z = 0 } },
			Crown = { Model = "Bellwood_GiantCrown", Offset = { X = 0, Y = 0, Z = 0 } },
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

return Layout
