--!strict
-- Vesperhold layout data (mac-41 plan, mac-43 pass 1, mac-48 pass 2). Pure numbers, no Roblox types: GothicCitadel / GothicMarch
-- build Part massing from it and tools/test_vesperhold_massing.luau checks it. Local frame: origin = Overworld.Vesperhold,
-- +X across the gate, +Z toward the approach (castle at -Z), Y 0 = gate threshold. Kit slots face +Z at Yaw 0; a slot's
-- X/Y/Z is the foot-centre of the piece on the plane it cladded and the body projects toward +Z (outward).
-- Pass 2 sprawl: P1 (the tiered citadel, T0..T3) + P2 (west chapter-house/belfry keep) + P3 (east ossuary/watch keep) +
-- three crag outposts, three viaducts (V1 road, V2 +150, V3 +280), a grand stair, waterfalls and the ruined-arch viewpoint.
local Layout = {}

-- View 01 (Codex's Snow Refuge eye, work/vesperhold/document_views.py), Roblox FieldOfView is vertical.
Layout.Eye = { X = -15, Y = -24, Z = 548 }
Layout.Aim = { X = 0, Y = 213, Z = -228 }
Layout.Fov = 70
Layout.Aspect = 16 / 9
-- View 02 (pilgrim road), same document.
Layout.Eye02 = { X = -13, Y = -36, Z = 305 }
Layout.Aim02 = { X = 0, Y = 192, Z = -228 }
Layout.Fov02 = 74

Layout.Tiers = {
	T0 = { FrontZ = -12, BackZ = -110, X = 340, Top = 0, Bay = 40, MinDrop = 150 },
	T1 = { FrontZ = -30, BackZ = -70, X = 330, CloseZ0 = -72, CloseZ1 = -110, FloorY = 12, Top = 190 },
	T2 = { FrontZ = -110, BackZ = -180, X = 260, FloorY = 190, Top = 260 },
	T3 = { FrontZ = -180, BackZ = -330, X = 200, FloorY = 260, Top = 330 },
}
Layout.Gate = { Half = 13, Height = 26, Lintel = 30 }
-- Warm light for the gate (view 04) and the close (view 06): { kind, x, y, z, range, brightness? }. Lanterns flank the great
-- portal in front of its face (it projects to z -23.9), hang in the gallery arches above it and line the passage; braziers
-- light the portal from the apron and stand on the close paving between the T1 back wall and the close walk.
Layout.Firelight = {
	{ "Lantern", -12, 16, -21, 26, 1.6 }, { "Lantern", 12, 16, -21, 26, 1.6 },
	{ "Lantern", -20, 85, -24, 40, 2.5 }, { "Lantern", 20, 85, -24, 40, 2.5 },
	{ "Lantern", -20, 145, -24, 40, 2.5 }, { "Lantern", 20, 145, -24, 40, 2.5 },
	{ "Brazier", -16, 0, -12, 30 }, { "Brazier", 16, 0, -12, 30 },
	{ "Lantern", -11.5, 12, -40, 22 }, { "Lantern", 11.5, 12, -40, 22 },
	{ "Lantern", -11.5, 17, -62, 22 }, { "Lantern", 11.5, 17, -62, 22 },
	{ "Brazier", -40, 12, -74.5, 30 }, { "Brazier", 40, 12, -74.5, 30 }, { "Brazier", 100, 12, -74.5, 30 },
	{ "Brazier", 160, 12, -74.5, 30 }, { "Brazier", 220, 12, -74.5, 30 },
}
Layout.Rose = { X = 0, Y = 312, Z = -180, Diameter = 48 }
Layout.Tower = { X = 120, Z = -212, BaseY = 330, Foot = 60 } -- west towers sit on the T3 front corners
-- Native piece sizes in studs { width, height, depth } = the generator's bounding box in assets/source/vesperhold/{kit,props,trees}/manifest.json
-- (size_studs_xyz is Blender x, y, z-up, so width = x, height = z, depth = y; trees average their _A/_B variants; Flying_Buttress_40 is rotated 90 degrees: it runs along X in the kit, along Z here). Slots carry scale factors
-- relative to these, so a kit mesh and its stand-in fill the same box. tools/test_vesperhold_loader.luau compares them with the manifests.
Layout.Piece = {
	Arcade_Bay_60 = { 43.6, 89.9, 15.8 }, Arcade_Bay_50 = { 43.6, 79.9, 15.8 }, Arcade_Bay_40 = { 43.6, 69.9, 15.8 },
	Bastion_Face = { 40, 96.6, 15.1 }, Buttress_Pier = { 13.1, 71.1, 25.5 }, Balustrade_20 = { 20.3, 16.2, 2.3 },
	Flying_Buttress_40 = { 10.1, 27, 46.5 }, Pinnacle_Crocket_S = { 4, 12.8, 4 }, Pinnacle_Crocket_M = { 8.4, 25.6, 8.4 },
	Pinnacle_Crocket_L = { 12.6, 42.7, 12.6 }, Spire_Base_Oct = { 29.9, 27.5, 29.9 }, Spire_Belfry_Stage = { 27.4, 40.1, 27.4 },
	Spire_Lucarne_Mid = { 30.9, 44.1, 30.9 }, Spire_Needle_Tip = { 11.3, 55.7, 11.3 }, Spire_Broken_Top = { 11.3, 27, 11.3 },
	Lancet_Tall = { 14.8, 46.2, 6.9 }, Rose_Window_Great = { 57.7, 76, 12.2 }, Portal_Great = { 61, 93.1, 21.8 },
	Statue_Veiled_Scan = { 5, 18, 5 }, -- placeholder until its manifest lands (graveyard / niche statue)
	Viaduct_Bay = { 35.2, 120.1, 29 }, Statue_Plinth = { 9.2, 12, 9.2 }, Hooded_Statue_A = { 7.3, 22.8, 7.3 },
	Hooded_Statue_B = { 5.4, 19.6, 5.1 }, Candle_Cluster_A = { 6.5, 5.8, 6.5 }, Banner_Torn_A = { 8.4, 31, 2 },
	-- pass 2 additions (mac-44 builds these meshes)
	Viaduct_Balustrade_30 = { 30.3, 19.3, 3 }, Pedestal_Statue_Staff = { 6, 23.3, 6 }, Brazier_Post = { 4.5, 10.5, 4 },
	Banner_Pole = { 12.4, 39.3, 5.2 }, Banner_Torn_B = { 9, 30.8, 1.8 }, Ruined_Arch = { 36.4, 30.4, 19.7 },
	Dead_Oak_Gnarled = { 79.6, 81.8, 79.6 }, Dead_Pine_Snapped = { 24.6, 70.2, 31.7 }, Thorn_Twisted = { 39.4, 36.8, 34 },
	Gravestone_A = { 4.4, 6.4, 1.9 }, Gravestone_B = { 4.1, 6, 2.3 }, Tomb_Slab = { 12.5, 4.5, 7.3 }, Iron_Fence_10 = { 10.4, 8.5, 1.6 },
	Gibbet_Cage = { 3.4, 16, 2.2 }, Waterfall_Sheet_A = { 22.2, 82.4, 12.2 }, Waterfall_Sheet_B = { 33.6, 162.5, 12.3 }, Mist_Anchor = { 1, 1, 1 },
}

-- The pilgrims' deck: unchanged path, but now 30-stud bays on tall piers. Level is the deck top at z.
Layout.Viaduct = { Z0 = 4, Z1 = 157, Bay = 30, Width = 19.5, Rail = 9.4 }
function Layout.viaductLevel(z: number): number
	return -18 * (z - 4) / 153
end

-- The pilgrim road from Snow Refuge to the viaduct, { x, z } (GothicMarch lays the deck, the layout plants trees along it).
Layout.Lane = {
	{ 0, 585 }, { 0, 568 }, { -17, 550 }, { -19, 538 }, { -31, 504 }, { -34, 468 }, { -6, 431 }, { 18, 404 }, { 28, 368 },
	{ 15, 335 }, { -13, 305 }, { -27, 269 }, { -25, 240 }, { -12, 210 }, { 0, 183 }, { 0, 157 },
}

-- GRAND STAIR (ref_03): 61 steps (rise 1.15, tread 2.55, 24 wide) climb T2 (y 190) to the T3 portal landing (y 260). T2 is
-- only 70 deep, so the stair runs 18 degrees off the wall: its axis ends dead on the portal door (0, -181). Foot on the west
-- of T2, where the cloister ramp lands; landings after steps 20 and 40; stations (brazier + statue) every 20 studs.
local function buildStair()
	local flights = { 20, 20, 21 }
	local width, tread, landing, base, top, door, lead = 24, 2.55, 4, 190, 260, { 0, -181 }, 22
	local count = 0
	for _, n in flights do count += n end
	local rise = (top - base) / count
	local th = math.rad(18)
	local ux, uz = math.cos(th), -math.sin(th) -- unit axis, climbing toward +X / -Z
	local length = count * tread + (#flights - 1) * landing
	local b = { door[1] - ux * lead, door[2] - uz * lead }
	local s = { b[1] - ux * length, b[2] - uz * length }
	local steps, landings = {}, {}
	local at, idx = 0, 0
	for f, n in flights do
		for _ = 1, n do
			idx += 1
			table.insert(steps, { Index = idx, S0 = at, Len = tread, Top = base + idx * rise,
				CX = s[1] + ux * (at + tread / 2), CZ = s[2] + uz * (at + tread / 2) })
			at += tread
		end
		if f < #flights then
			table.insert(landings, { S0 = at, Len = landing, Top = base + idx * rise,
				CX = s[1] + ux * (at + landing / 2), CZ = s[2] + uz * (at + landing / 2) })
			at += landing
		end
	end
	return { Steps = steps, Landings = landings, Count = count, Rise = rise, Tread = tread, Width = width, Base = base, TopY = top,
		Length = length, UX = ux, UZ = uz, Yaw = math.atan2(ux, uz), S = { s[1], base, s[2] }, B = { b[1], top, b[2] },
		Door = { door[1], top, door[2] } }
end
Layout.Stair = buildStair()

-- Surface height of the stair at distance s along its axis (landings are flat at the previous step's top).
function Layout.stairY(s: number): number
	local st = Layout.Stair
	if s <= 0 then return st.Base end
	for _, step in st.Steps do
		if s <= step.S0 + step.Len then return step.Top end
	end
	return st.TopY
end

-- Walk route from the pilgrim road to the nave. Each segment's top surface runs A -> B; Kind "march" is built by
-- GothicMarch, "core" lies on a masonry core top, "slab" is a deck GothicCitadel lays from this data, "stair" is Layout.Stair.
-- Mirrored from pass 1: the cloister ramp now lands on the WEST end of T2, so the stair foot and the V2 spur never cross.
local SB, SS = Layout.Stair.B, Layout.Stair.S
Layout.Route = {
	{ Name = "Viaduct", Kind = "march", Width = 19.5, A = { 0, -18, 157 }, B = { 0, 0, 4 } },
	{ Name = "GateApron", Kind = "slab", Width = 26, Slab = 40, Thick = 4, A = { 0, 0, 4 }, B = { 0, 0, -48 } },
	{ Name = "PassageRamp", Kind = "slab", Width = 26, Slab = 26, Thick = 16, A = { 0, 0, -48 }, B = { 0, 12, -72 } },
	{ Name = "CloseCross", Kind = "core", Width = 26, A = { 0, 12, -72 }, B = { 0, 12, -84 } },
	{ Name = "CloseWalk", Kind = "core", Width = 14, A = { 0, 12, -84 }, B = { 250, 12, -84 } },
	{ Name = "CloseTurn", Kind = "core", Width = 14, A = { 250, 12, -84 }, B = { 250, 12, -101 } },
	{ Name = "CloisterRamp", Kind = "slab", Width = 14, Slab = 14, Thick = 3, Base = 12, A = { 250, 12, -101 }, B = { -250, 190, -101 } },
	{ Name = "CloisterLanding", Kind = "slab", Width = 14, Slab = 14, Thick = 3, Base = 12, A = { -250, 190, -101 }, B = { -250, 190, -130 } },
	{ Name = "StairApproach", Kind = "core", Width = 14, A = { -250, 190, -130 }, B = { SS[1], 190, SS[3] } },
	{ Name = "GrandStair", Kind = "stair", Width = Layout.Stair.Width, A = { SS[1], SS[2], SS[3] }, B = { SB[1], SB[2], SB[3] } },
	{ Name = "PortalLanding", Kind = "slab", Width = 14, Slab = 14, Thick = 3, Base = 190, A = { SB[1], 260, SB[3] }, B = { 0, 260, -181 } },
	{ Name = "PortalThreshold", Kind = "slab", Width = 26, Slab = 26, Thick = 3, Base = 190, A = { 0, 260, -181 }, B = { 0, 260, -196 } },
	{ Name = "Nave", Kind = "core", Width = 40, A = { 0, 260, -196 }, B = { 0, 260, -290 } },
}
-- Alternates kept from pass 1: the long ramp along the T3 front.
Layout.Alternates = {
	{ Name = "CloisterWalk", Kind = "core", Width = 14, A = { -250, 190, -130 }, B = { -190, 190, -172 } },
	{ Name = "CathedralRamp", Kind = "slab", Width = 14, Slab = 14, Thick = 3, Base = 190, A = { -190, 190, -172 }, B = { SB[1], 260, SB[3] } },
}
-- Spurs to the other pinnacles; each chain starts on the main route (From) and ends on its pinnacle terrace.
Layout.Spurs = {
	V2 = { From = { -250, 190, -130 }, Segs = {
		{ Name = "T2WestWalk", Kind = "core", Width = 14, A = { -250, 190, -130 }, B = { -260, 190, -130 } },
		{ Name = "V2Ramp", Kind = "span", Width = 16, Thick = 3, A = { -260, 190, -130 }, B = { -315, 150, -130 } },
		{ Name = "V2Deck", Kind = "span", Viaduct = "V2", Width = 16, Thick = 3, A = { -315, 150, -130 }, B = { -470, 150, -130 } },
		{ Name = "P2Terrace", Kind = "core", Width = 16, A = { -470, 150, -130 }, B = { -570, 150, -130 } },
	} },
	-- Through a 10-wide door in the east nave wall onto the T3 roof terrace, then up and across.
	V3 = { From = { 0, 260, -277 }, Segs = {
		{ Name = "NaveDoorWalk", Kind = "core", Width = 10, A = { 0, 260, -277 }, B = { 200, 260, -277 } },
		{ Name = "V3Rise", Kind = "span", Width = 16, Thick = 3, A = { 200, 260, -277 }, B = { 255, 280, -277 } },
		{ Name = "V3Deck", Kind = "span", Viaduct = "V3", Width = 16, Thick = 3, A = { 255, 280, -277 }, B = { 470, 280, -277 } },
		{ Name = "P3Terrace", Kind = "core", Width = 16, A = { 470, 280, -277 }, B = { 570, 280, -277 } },
	} },
}
Layout.NaveDoor = { Z0 = -282, Z1 = -272 } -- gap in the east NaveWall

-- Viaducts: V1 is the existing processional (Layout.Viaduct); V2/V3 run along X at deck height Level.
Layout.Viaducts = {
	V1 = { Level = -9 },
	V2 = { Level = 150, X0 = -315, X1 = -470, Z = -130, Width = 16 },
	V3 = { Level = 280, X0 = 255, X1 = 470, Z = -277, Width = 16 },
}

-- Cliff pinnacles built as massive rock Part courses (the terrain support of vesperholdWeight is |x| < 260, wholly P1's; the
-- carving there stays checksum-identical and the weather weight is untouched). P1 itself is the existing ridge + T0..T3.
Layout.Pinnacles = {
	P2 = { X = -640, Z = -230, HX = 170, HZ = 130, Top = 150, Shrink = 0.09 },
	P3 = { X = 660, Z = -300, HX = 190, HZ = 130, Top = 280, Shrink = 0.08 },
}
-- Distant crags carrying spire-stack outposts, 1100-1400 studs from the gate. Skyline only: no collision, no walk.
Layout.Crags = {
	O1 = { X = -1000, Z = -650, HX = 62, HZ = 56, Top = 140, Shrink = 0.12 },
	O2 = { X = 1100, Z = -800, HX = 66, HZ = 58, Top = 60, Shrink = 0.12 },
	O3 = { X = -250, Z = -1100, HX = 64, HZ = 58, Top = 190, Shrink = 0.12 },
}
-- Keep masonry cores: { name, x0, x1, y0, y1, z0, z1 }, collidable.
Layout.KeepCores = {
	{ "P2Chapter", -790, -500, 150, 230, -330, -150 }, { "P2Upper", -740, -540, 230, 300, -300, -200 },
	{ "P2Belfry", -700, -580, 300, 380, -285, -215 },
	{ "P3Ossuary", 530, 830, 280, 350, -420, -320 }, { "P3Watch", 660, 740, 350, 430, -400, -340 },
}

local function hash(n: number): number
	local s = math.sin(n * 12.9898) * 43758.5453
	return s - math.floor(s)
end

-- Courses of a rock column from the lowest terrain under it up to Top: battered (wider at the foot), the top course square.
-- ground(x, z) is the terrain top in the local frame.
function Layout.rock(r: { [string]: number }, ground: (number, number) -> number): { { [string]: number } }
	local low = math.huge
	for i = 0, 4 do
		for j = 0, 4 do
			low = math.min(low, ground(r.X + r.HX * (i / 2 - 1) * 1.4, r.Z + r.HZ * (j / 2 - 1) * 1.4))
		end
	end
	low -= 10
	local k = math.max(1, math.ceil((r.Top - low) / 90))
	local out = {}
	for c = 0, k - 1 do
		local grow = (k - 1 - c) * r.Shrink
		local top = c == k - 1
		table.insert(out, { CX = r.X + if top then 0 else (hash(c + r.X) - 0.5) * 24, CZ = r.Z + if top then 0 else (hash(c + r.Z) - 0.5) * 24,
			HX = r.HX * (1 + grow), HZ = r.HZ * (1 + grow), Y0 = low + (r.Top - low) * c / k, Y1 = low + (r.Top - low) * (c + 1) / k,
			Yaw = if top then 0 else (hash(c * 3 + r.X) - 0.5) * 0.17 })
	end
	return out
end

local function spireList(): { { any } }
	-- Spire tops (above the gate road): { x, z, baseY, top, width, tag }.
	local s: { { any } } = {
		{ -120, -212, 330, 690, 56, "WestTower" }, { 120, -212, 330, 640, 52, "WestTower" },
		{ 0, -255, 330, 560, 40, "Crossing" },
	}
	for i, p in { { -26, -229 }, { 26, -229 }, { -26, -281 }, { 26, -281 } } do
		table.insert(s, { p[1], p[2], 330, 420 + (i % 2) * 24, 12, "CrossingNeedle" })
	end
	for _, c in { { -326, -34, 0, 300 }, { 326, -34, 0, 312 }, { -252, -116, 190, 380 }, { 252, -116, 190, 362 },
		{ -192, -186, 260, 450 }, { 192, -186, 260, 430 } } do
		table.insert(s, { c[1], c[2], c[3], c[4], 34, if c[1] == 192 and c[2] == -186 then "BrokenCorner" else "CornerTower" })
	end
	for i, x in { -245, -170, 170, 245 } do
		table.insert(s, { x, -150, 190, 220 + i * 7, 14, "ButtressTower" })
	end
	for i, x in { -84, -56, 56, 84 } do
		table.insert(s, { x, -150, 260, 282 + i * 4, 12, "ButtressTower" })
	end
	for i = 1, 14 do
		local x = ((i - 1) % 7 + 1) * 40 * (if i <= 7 then -1 else 1)
		table.insert(s, { x, -22, 0, 150 + ((i * 37) % 101), 10, "GalleryNeedle" })
	end
	-- P2 chapter-house / belfry keep (west): belfry spire over the third tier, corner towers, needles.
	table.insert(s, { -640, -250, 380, 560, 44, "Belfry" })
	for i, c in { { -790, -150, 230, 330 }, { -500, -150, 230, 300 }, { -790, -330, 230, 350 }, { -500, -330, 230, 320 } } do
		table.insert(s, { c[1], c[2], c[3], c[4], 26, "KeepCorner" })
	end
	for i, c in { { -740, -200, 300, 380 }, { -540, -200, 300, 350 }, { -740, -300, 300, 405 }, { -540, -300, 300, 365 } } do
		table.insert(s, { c[1], c[2], c[3], c[4], 18, "KeepTower" })
	end
	for i, x in { -740, -690, -590, -540 } do
		table.insert(s, { x, -152, 230, 262 + (i * 17) % 30, 10, "KeepNeedle" })
	end
	-- P3 ossuary / watch keep (east).
	table.insert(s, { 700, -370, 430, 610, 40, "WatchTower" })
	for i, c in { { 530, -320, 350, 430 }, { 830, -320, 350, 410 }, { 530, -420, 350, 455 }, { 830, -420, 350, 420 } } do
		table.insert(s, { c[1], c[2], c[3], c[4], 26, "KeepCorner" })
	end
	for i = 1, 6 do
		table.insert(s, { 570 + (i - 1) * 40, -322, 350, 392 + (i * 23) % 40, 10, "KeepNeedle" })
	end
	for i, c in { { 600, -380, 350, 395 }, { 800, -380, 350, 388 }, { 700, -420, 350, 412 } } do
		table.insert(s, { c[1], c[2], c[3], c[4], 14, "KeepTower" })
	end
	-- Distant outposts: main tower plus two flankers on each crag (baseY = the crag's Top).
	for _, o in { { "O1", 140, 470, 380, 330 }, { "O2", 60, 430, 360, 310 }, { "O3", 190, 520, 400, 350 } } do
		local c = Layout.Crags[o[1]]
		table.insert(s, { c.X, c.Z, o[2], o[3], 36, "OutpostTower" })
		table.insert(s, { c.X - 26, c.Z + 14, o[2], o[4], 16, "OutpostNeedle" })
		table.insert(s, { c.X + 24, c.Z - 12, o[2], o[5], 14, "OutpostNeedle" })
	end
	return s
end
Layout.Spires = spireList()

-- Does a canopy (sphere at x, y, z, radius r) noticeably cover the middle of reveal view 01 or 02? Noticeable = at least
-- RevealMinSize of the frame height across and reaching above RevealFloor (ground litter stays). Roblox FieldOfView is vertical.
Layout.RevealBand, Layout.RevealFloor, Layout.RevealMinSize = 0.5, -0.3, 0.15
function Layout.blocksReveal(x: number, y: number, z: number, r: number): boolean
	for _, v in { { Layout.Eye, Layout.Aim, Layout.Fov }, { Layout.Eye02, Layout.Aim02, Layout.Fov02 } } do
		local e, a = v[1], v[2]
		local fx, fy, fz = a.X - e.X, a.Y - e.Y, a.Z - e.Z
		local fl = math.sqrt(fx * fx + fy * fy + fz * fz)
		fx, fy, fz = fx / fl, fy / fl, fz / fl
		local rl = math.sqrt(fx * fx + fz * fz)
		local rx, rz = -fz / rl, fx / rl -- right = forward x world up
		local ux, uy, uz = -rz * fy, rz * fx - rx * fz, rx * fy -- up = right x forward
		local dx, dy, dz = x - e.X, y - e.Y, z - e.Z
		local depth = dx * fx + dy * fy + dz * fz
		if depth > -r then
			local zc = math.max(depth, r) -- a canopy beside the eye projects as if it touched the near plane
			local ty = math.tan(math.rad(v[3] / 2))
			local tx = ty * Layout.Aspect
			local sx, sy, ry = (dx * rx + dz * rz) / zc / tx, (dx * ux + dy * uy + dz * uz) / zc / ty, r / zc / ty
			if ry >= Layout.RevealMinSize and math.abs(sx) - r / zc / tx < Layout.RevealBand and sy + ry > Layout.RevealFloor and sy - ry < 1 then
				return true
			end
		end
	end
	return false
end

-- Review cameras off the reveal line (view 05 on the gorge flank by the graveyard): canopies keep their crowns clear of them.
Layout.ReviewEyes = { { X = -305, Z = 100 } }
function Layout.crowdsEye(x: number, z: number, r: number): boolean
	for _, e in Layout.ReviewEyes do
		if math.sqrt((x - e.X) ^ 2 + (z - e.Z) ^ 2) < r + 12 then return true end
	end
	return false
end

-- Ruined-arch viewpoint (ref_04): the main arch on the east rim and a broken stub on the west, both in view 01.
Layout.Arches = {
	{ X = 48, Z = 470, Scale = 1.3, Yaw = 0 },
	{ X = -72, Z = 455, Scale = 1.0, Yaw = 0 },
}

-- Every place a kit piece goes. ground(x, z) returns the terrain top in the local frame (Y 0 = gate threshold).
function Layout.slots(ground: (number, number) -> number): { { [string]: any } }
	local out: { { [string]: any } } = {}
	local function add(piece: string, group: string, x: number, y: number, z: number, yaw: number?, sx: number?, sy: number?, sz: number?, extra: { [string]: any }?)
		local s: { [string]: any } = { Id = #out + 1, Piece = piece, Group = group, X = x, Y = y, Z = z, Yaw = yaw or 0, SX = sx or 1, SY = sy or 1, SZ = sz or 1 }
		if extra then
			for k, v in extra do s[k] = v end
		end
		table.insert(out, s)
	end
	local T0, T1, T2, T3 = Layout.Tiers.T0, Layout.Tiers.T1, Layout.Tiers.T2, Layout.Tiers.T3

	-- T0 bastions: battered faces down to terrain, stacked in 80-stud courses, a buttress at every joint.
	for i = 1, 17 do
		local cx = (i - 9) * T0.Bay
		local low = math.huge
		for _, dx in { -20, 0, 20 } do
			for _, z in { T0.FrontZ, T0.FrontZ - 30 } do low = math.min(low, ground(cx + dx, z)) end
		end
		low -= 8
		local drop = -low
		local P = Layout.Piece
		local n = math.ceil(drop / 80)
		for k = 0, n - 1 do
			add("Bastion_Face", "Bastion", cx, low + k * drop / n, T0.FrontZ, 0, 1, drop / n / P.Bastion_Face[2], 1, { Drop = drop })
		end
	end
	for i = 0, 17 do
		local x = (i - 8.5) * T0.Bay
		local low = math.min(ground(x, T0.FrontZ), ground(x, T0.FrontZ - 30)) - 8
		add("Buttress_Pier", "Buttress", x, low, T0.FrontZ + 6, 0, 1, (-low + 24) / Layout.Piece.Buttress_Pier[2], 1)
	end
	-- T1: three stacked arcade galleries (arches 60/60/50) under a 20-stud frieze, then the balustrade and pinnacle row on the wall top. The gate bay is open at level 0.
	for lvl, band in { { 0, 60, "Arcade_Bay_60" }, { 60, 120, "Arcade_Bay_60" }, { 120, 170, "Arcade_Bay_50" } } do
		for i = 1, 16 do
			local cx = (i - 8.5) * 40
			if not (lvl == 1 and math.abs(cx) < 30) then
				add(band[3], "Arcade", cx, band[1], T1.FrontZ, 0, 1, (band[2] - band[1]) / Layout.Piece[band[3]][2], 1, { Tier = "T1", Level = lvl })
			end
		end
	end
	for i = 1, 33 do
		local x = (i - 17) * 20
		add("Balustrade_20", "Balustrade", x, T1.Top, T1.FrontZ + 1, 0, 1, 1, 1, { Tier = "T1" })
	end
	for i = 0, 16 do add("Pinnacle_Crocket_S", "Pinnacle", (i - 8) * 40, T1.Top + 8, T1.FrontZ + 2, 0, 1, 1, 1, { Tier = "T1" }) end
	-- T2 cloister gallery, two levels (40 then 30 tall), on the back wall of the terrace.
	for lvl = 1, 2 do
		for i = 1, 13 do
			add("Arcade_Bay_40", "Arcade", (i - 7) * 40, T2.FloorY + (lvl - 1) * 40, -124, 0, 1, (if lvl == 1 then 40 else 30) / Layout.Piece.Arcade_Bay_40[2], 1, { Tier = "T2", Level = lvl })
		end
	end
	-- T2 -> T3: eight pairs of flying buttresses springing from piers on the terrace to the T3 front wall.
	for _, x in { 28, 42, 56, 70, 84, 162, 176, 190 } do
		for _, s in { -1, 1 } do
			add("Buttress_Pier", "Buttress", s * x, T2.FloorY, -150, 0, 1, 1, 1, { Tier = "T2" })
			add("Flying_Buttress_40", "Flyer", s * x, 250, -150, 0, 1, 35 / Layout.Piece.Flying_Buttress_40[2], 30 / Layout.Piece.Flying_Buttress_40[3], { Tier = "T2", Pair = x })
			add("Pinnacle_Crocket_L", "Pinnacle", s * x, 260, -150, 0, 1, 1, 1, { Tier = "T2" })
		end
	end
	-- T3 west front: dominant rose window over a deep portal, lancet rows.
	add("Rose_Window_Great", "Rose", Layout.Rose.X, Layout.Rose.Y - 24, Layout.Rose.Z, 0, 1, 1, 1)
	add("Portal_Great", "Portal", 0, 0, T1.FrontZ, 0, Layout.Gate.Height / Layout.Piece.Portal_Great[2], Layout.Gate.Height / Layout.Piece.Portal_Great[2], 1, { Height = Layout.Gate.Height })
	add("Portal_Great", "Portal", 0, T3.FloorY, T3.FrontZ, 0, 28 / Layout.Piece.Portal_Great[2], 28 / Layout.Piece.Portal_Great[2], 1, { Height = 28 })
	for _, x in { -190, -170, -60, 60, 170, 190 } do add("Lancet_Tall", "Lancet", x, 262, T3.FrontZ, 0, 1, 1, 1) end

	-- Bays of a wall piece along an axis: a0..a1 along "x" (facing +/-Z) or "z" (facing +/-X), `fixed` on the other axis.
	local function wall(piece: string, group: string, along: string, a0: number, a1: number, fixed: number, y: number, yaw: number, sy: number, extra: { [string]: any }?)
		local w = Layout.Piece[piece][1]
		local n = math.max(1, math.floor((a1 - a0) / w + 0.5))
		local step = (a1 - a0) / n
		for i = 0, n - 1 do
			local c = a0 + step * (i + 0.5)
			add(piece, group, if along == "x" then c else fixed, y, if along == "x" then fixed else c, yaw, step / w, sy, 1, extra)
		end
	end
	local PI = math.pi
	-- P2 chapter-house keep on the west pinnacle: two arcade levels on the south and east faces, a buttress run, balustrade.
	for lvl = 1, 2 do
		wall("Arcade_Bay_40", "Arcade", "x", -790, -500, -150, 150 + (lvl - 1) * 40, 0, 1, { Tier = "P2", Level = lvl })
		wall("Arcade_Bay_40", "Arcade", "z", -330, -150, -500, 150 + (lvl - 1) * 40, PI / 2, 1, { Tier = "P2", Level = lvl })
	end
	wall("Arcade_Bay_50", "Arcade", "x", -740, -540, -200, 230, 0, 1.4, { Tier = "P2", Level = 3 })
	for i = 0, 7 do add("Buttress_Pier", "Buttress", -790 + i * 41.4, 150, -144, 0, 1, 1.15, 1, { Tier = "P2" }) end
	wall("Balustrade_20", "Balustrade", "x", -790, -500, -149, 230, 0, 1, { Tier = "P2" })
	wall("Balustrade_20", "Balustrade", "z", -330, -150, -499, 230, PI / 2, 1, { Tier = "P2" })
	wall("Lancet_Tall", "Lancet", "x", -700, -580, -214, 300, 0, 1, { Tier = "P2" })
	for i = 0, 7 do add("Pinnacle_Crocket_S", "Pinnacle", -790 + i * 41.4, 238, -148, 0, 1, 1, 1, { Tier = "P2" }) end
	-- P3 ossuary / watch keep on the east pinnacle.
	for lvl = 1, 2 do
		wall("Arcade_Bay_40", "Arcade", "x", 530, 830, -320, 280 + (lvl - 1) * 40, 0, if lvl == 1 then 1 else 0.75, { Tier = "P3", Level = lvl })
		wall("Arcade_Bay_40", "Arcade", "z", -420, -320, 530, 280 + (lvl - 1) * 40, -PI / 2, if lvl == 1 then 1 else 0.75, { Tier = "P3", Level = lvl })
	end
	for i = 0, 7 do add("Buttress_Pier", "Buttress", 530 + i * 42.9, 280, -314, 0, 1, 1.0, 1, { Tier = "P3" }) end
	wall("Balustrade_20", "Balustrade", "x", 530, 830, -319, 350, 0, 1, { Tier = "P3" })
	wall("Lancet_Tall", "Lancet", "x", 660, 740, -339, 350, 0, 1, { Tier = "P3" })
	for i = 0, 7 do add("Pinnacle_Crocket_S", "Pinnacle", 530 + i * 42.9, 358, -318, 0, 1, 1, 1, { Tier = "P3" }) end

	-- Spires: stacks of base / belfry / lucarne modules under a needle tip (the broken one ends in a stump).
	for n, sp in Layout.Spires do
		local x, z, y0, top, w, tag = sp[1], sp[2], sp[3], sp[4], sp[5], sp[6]
		local broken = tag == "BrokenCorner"
		local h = top - y0
		local tip = math.min(h, if broken then 20 else 30)
		local base = if h >= 100 then 60 else 0
		local mid = h - base - tip
		local count = if mid > 0 then math.max(1, math.floor(mid / 45 + 0.5)) else 0
		local y = y0
		local function module(piece: string, height: number, width: number)
			local d = Layout.Piece[piece]
			add(piece, "Spire", x, y, z, 0, width / d[1], height / d[2], width / d[3], { Spire = n, Tag = tag, Top = top })
			y += height
		end
		if base > 0 then module("Spire_Base_Oct", base, w) end
		for i = 1, count do
			module(if i % 2 == 1 then "Spire_Belfry_Stage" else "Spire_Lucarne_Mid", mid / count, w * (0.85 - 0.45 * i / count))
		end
		module(if broken then "Spire_Broken_Top" else "Spire_Needle_Tip", tip, w * 0.4)
	end
	-- Viaduct: bays every 30 studs, hooded statues on plinths every 30 studs both sides, candles at each plinth.
	local V = Layout.Viaduct
	for i = 0, 4 do
		local zc = V.Z0 + V.Bay * (i + 0.5)
		local base = ground(0, zc) - 5
		add("Viaduct_Bay", "Viaduct", 0, base, zc, 0, 1, (Layout.viaductLevel(zc) - 3.5 - base) / Layout.Piece.Viaduct_Bay[2], 1, { Level = Layout.viaductLevel(zc) })
		for _, s in { -1, 1 } do
			local top = Layout.viaductLevel(zc)
			-- Every kit statue carries its own __Plinth sub: the Part-era plinth slot is dropped by the loader when the statue mesh exists
			-- (Carries), and the mesh then stands on the deck (Base) instead of on top of that plinth.
			local statue = if i % 2 == 0 then "Hooded_Statue_A" else "Hooded_Statue_B"
			add("Statue_Plinth", "Statue", s * V.Rail, top, zc, 0, 1, 1, 1, { Carries = statue })
			add(statue, "Statue", s * V.Rail, top + Layout.Piece.Statue_Plinth[2], zc, if s > 0 then math.pi * 0.5 else -math.pi * 0.5, 1, 1, 1, { Side = s, Base = top })
			add("Candle_Cluster_A", "Candle", s * V.Rail, top, zc + 5, 0, 1, 1, 1)
		end
	end
	-- Torn crimson banners on the near gate tower.
	for _, b in { { -40, 150 }, { 40, 150 }, { -40, 100 } } do add("Banner_Torn_A", "Banner", b[1], b[2], T1.FrontZ + 15, 0, 1, 1, 1) end

	-- V2 (+150, P1 T2 <-> P2) and V3 (+280, P1 T3 <-> P3): arched bays down to terrain, balustrade, a pedestal statue per pier
	-- every ~30 studs on both sides, candles at each, a torn banner on alternate piers. Both run along X.
	for name, v in { V2 = Layout.Viaducts.V2, V3 = Layout.Viaducts.V3 } do
		local span = math.abs(v.X1 - v.X0)
		local n = math.max(1, math.floor(span / 30 + 0.5))
		local bay = span / n
		local dir = if v.X1 > v.X0 then 1 else -1
		for i = 0, n - 1 do
			local xc = v.X0 + dir * bay * (i + 0.5)
			local base = ground(xc, v.Z) - 5
			add("Viaduct_Bay", "ViaductHigh", xc, base, v.Z, 0, bay / Layout.Piece.Viaduct_Bay[1], (v.Level - 3.5 - base) / Layout.Piece.Viaduct_Bay[2], 1, { Viaduct = name, Level = v.Level, Bay = i + 1 })
			for _, s in { -1, 1 } do
				local zz = v.Z + s * (v.Width / 2 - 0.9)
				add("Viaduct_Balustrade_30", "Balustrade", xc, v.Level, zz, if s > 0 then 0 else PI, bay / Layout.Piece.Viaduct_Balustrade_30[1], 1, 1, { Viaduct = name })
				add("Pedestal_Statue_Staff", "Pedestal", xc, v.Level, zz + s * 1.5, if s > 0 then PI else 0, 1, 1, 1, { Viaduct = name, Side = s, Along = xc })
				add("Candle_Cluster_A", "Candle", xc + bay * 0.25, v.Level, zz, 0, 1, 1, 1, { Viaduct = name })
				if (i + (if s > 0 then 1 else 0)) % 2 == 0 then
					add("Banner_Torn_B", "Banner", xc - dir * bay * 0.5, v.Level - 3, v.Z + s * (v.Width / 2 + 2), 0, 1, 1, 1, { Viaduct = name })
				end
			end
		end
	end

	-- GRAND STAIR stations: a brazier post and a staff-bearing pedestal statue every 20 studs on both sides, banner-pole pairs
	-- on the three landings (two between flights, one at the top).
	local St = Layout.Stair
	local perpX, perpZ = -St.UZ, St.UX
	local function onStair(s: number, lateral: number): (number, number)
		return St.S[1] + St.UX * s + perpX * lateral, St.S[3] + St.UZ * s + perpZ * lateral
	end
	for k = 0, 7 do
		local s = 8 + 20 * k
		for _, side in { -1, 1 } do
			local lat = side * (St.Width / 2 + 2.5)
			local bx, bz = onStair(s, lat)
			local px, pz = onStair(s + 4, lat)
			add("Brazier_Post", "Brazier", bx, Layout.stairY(s), bz, 0, 1, 1, 1, { Track = "Stair", Side = side, Along = s })
			add("Pedestal_Statue_Staff", "Pedestal", px, Layout.stairY(s + 4), pz, math.atan2(-side * perpX, -side * perpZ), 1, 1, 1, { Track = "Stair", Side = side, Along = s + 4 })
		end
	end
	for _, s in { St.Landings[1].S0 + 2, St.Landings[2].S0 + 2, St.Length + 10 } do
		for _, side in { -1, 1 } do
			local bx, bz = onStair(s, side * (St.Width / 2 + 1))
			add("Banner_Pole", "BannerPole", bx, Layout.stairY(s), bz, math.atan2(-side * perpX, -side * perpZ), 1, 1, 1, { Track = "Stair", Side = side, Along = s })
		end
	end

	-- WATERFALLS on the gorge walls: two off the P1 bastion line, two off the P2 pinnacle face; a mist anchor at every base.
	local p2 = Layout.rock(Layout.Pinnacles.P2, ground)
	local p2Face = p2[1].CZ + p2[1].HZ + 2
	for _, f in { { "Waterfall_Sheet_B", -135, 0.5, 0, "P1" }, { "Waterfall_Sheet_A", 150, 0.5, 0, "P1" },
		{ "Waterfall_Sheet_B", -570, p2Face, Layout.Pinnacles.P2.Top, "P2" }, { "Waterfall_Sheet_A", -715, p2Face, Layout.Pinnacles.P2.Top, "P2" } } do
		local d = Layout.Piece[f[1]]
		local low = ground(f[2], f[3])
		local h = math.clamp(f[4] - low, 80, 200)
		add(f[1], "Waterfall", f[2], f[4] - h, f[3], 0, 1, h / d[2], 1, { Owner = f[5], Top = f[4], Height = h })
		add("Mist_Anchor", "Mist", f[2], f[4] - h, f[3] + 6, 0, 1, 1, 1, { Owner = f[5], Radius = 40 })
	end

	-- RUINED-ARCH viewpoint at the 01/02 reveal, tattered banners on the main arch, and dead trees.
	for i, a in Layout.Arches do
		add("Ruined_Arch", "Arch", a.X, ground(a.X, a.Z) - 1, a.Z, a.Yaw, a.Scale, a.Scale, a.Scale, { Index = i })
	end
	local main = Layout.Arches[1]
	local archY = ground(main.X, main.Z) - 1
	for _, k in { -1, 1 } do
		add("Banner_Torn_A", "Banner", main.X + k * 15 * main.Scale * 0.9, archY + 36 * main.Scale * 0.8, main.Z + 5, 0, 1, 1, 1, { Arch = true })
	end
	local species = { { "Dead_Oak_Gnarled", 0.9 }, { "Dead_Pine_Snapped", 1.1 }, { "Thorn_Twisted", 1.3 } }
	local nTree = 0
	local function tree(x: number, z: number, scale: number, towardX: number, towardZ: number, tag: string)
		local sp = species[(nTree + 1) % 3 + 1]
		local lean = 0.12 + 0.2 * hash(nTree + 1)
		local yaw, s, d = math.atan2(towardX - x, towardZ - z), scale * sp[2], Layout.Piece[sp[1]]
		local y, reach = ground(x, z) - 1, d[2] * s * 0.6 -- canopy centre: 60% up the leaning trunk
		-- A canopy over the middle of reveal 01/02 (or on a review eye) steps sideways until it frames the shot instead.
		local side, r = if x >= -8 then 1 else -1, math.max(d[1], d[3]) * s / 2
		for _ = 1, 12 do
			local lx = math.sin(lean) * reach
			yaw = math.atan2(towardX - x, towardZ - z)
			local cx, cz = x + math.sin(yaw) * lx, z + math.cos(yaw) * lx
			if not Layout.blocksReveal(cx, y + math.cos(lean) * reach, cz, r) and not Layout.crowdsEye(cx, cz, r) then break end
			x += side * 12
			y = ground(x, z) - 1
		end
		local lx = math.sin(lean) * reach
		yaw = math.atan2(towardX - x, towardZ - z) -- x may have stepped once more after the last check
		local cx, cz = x + math.sin(yaw) * lx, z + math.cos(yaw) * lx
		if Layout.blocksReveal(cx, y + math.cos(lean) * reach, cz, r) or Layout.crowdsEye(cx, cz, r) then return end
		nTree += 1
		add(sp[1], "Tree", x, y, z, yaw, s, s, s, { Lean = lean, Cluster = tag })
	end
	local function cluster(cx: number, cz: number, count: number, spread: number, towardX: number, towardZ: number, tag: string, seed: number)
		for i = 1, count do
			local a = (i / count + hash(seed + i)) * 2 * PI
			tree(cx + math.cos(a) * spread * (0.5 + hash(seed * 3 + i)), cz + math.sin(a) * spread * (0.5 + hash(seed * 5 + i)),
				0.8 + 0.5 * hash(seed + i * 7), towardX, towardZ, tag)
		end
	end
	-- Around the arch (east rim) and the west stub, leaning in over the road.
	cluster(80, 462, 5, 24, 0, 460, "Arch", 1)
	cluster(-96, 450, 4, 20, 0, 455, "Arch", 2)
	-- Along the pilgrim road: a cluster per ninth of its length, alternating sides, leaning over it.
	local lane = Layout.Lane
	local cum, total = { 0 }, 0
	for i = 2, #lane do
		total += math.sqrt((lane[i][1] - lane[i - 1][1]) ^ 2 + (lane[i][2] - lane[i - 1][2]) ^ 2)
		cum[i] = total
	end
	for c = 1, 8 do
		local d = total * c / 9
		for i = 2, #lane do
			if d <= cum[i] then
				local t = (d - cum[i - 1]) / (cum[i] - cum[i - 1])
				local a, b = lane[i - 1], lane[i]
				local dx, dz = b[1] - a[1], b[2] - a[2]
				local l = math.sqrt(dx * dx + dz * dz)
				local px, pz = a[1] + dx * t, a[2] + dz * t
				local side = if c % 2 == 0 then 1 else -1
				local off = 38 + 10 * hash(c)
				cluster(px - dz / l * side * off, pz + dx / l * side * off, 3, 12, px, pz, "Road", 10 + c)
				break
			end
		end
	end
	-- Gorge rim, both shoulders; lower terrace graveyard below P1's walls.
	for i, p in { { -128, 350 }, { -124, 405 }, { 132, 332 }, { 138, 388 } } do cluster(p[1], p[2], 2, 14, 0, p[2], "Rim", 30 + i) end
	for i, p in { { -265, 40 }, { -175, 52 } } do cluster(p[1], p[2], 2, 14, p[1], 70, "Graveyard", 40 + i) end
	-- Gibbets on the gorge rim.
	for _, p in { { -132, 330 }, { -122, 372 }, { -118, 412 }, { 126, 344 }, { 136, 382 }, { 112, 418 } } do
		add("Gibbet_Cage", "Gibbet", p[1], ground(p[1], p[2]) - 1, p[2], math.atan2(-p[1], 0), 1, 1, 1, { Rim = true })
	end
	-- Graveyard on the lower terrace under the T0 bastions: gravestones in rows, tomb slabs, an iron-fence boundary.
	for row = 1, 4 do
		for col = 1, 9 do
			local seed = row * 20 + col
			local x = -320 + (col - 1) * 21 + (hash(seed) - 0.5) * 6
			local z = 24 + (row - 1) * 20 + (hash(seed + 3) - 0.5) * 6
			add(if (row + col) % 2 == 0 then "Gravestone_A" else "Gravestone_B", "Grave", x, ground(x, z) - 0.5, z, (hash(seed + 7) - 0.5) * 0.5, 1, 0.8 + 0.5 * hash(seed + 9), 1, { Row = row })
		end
	end
	-- Veiled statues at the graveyard's front edge (each with its own plinth).
	for _, x in { -300, -240, -180, -130 } do
		add("Statue_Veiled_Scan", "Statue", x, ground(x, 12) - 0.5, 12, math.rad(180), 1, 1, 1, { Graveyard = true })
	end
	for i = 1, 6 do
		local x = -300 + (i - 1) * 32
		add("Tomb_Slab", "Grave", x, ground(x, 100) - 0.5, 100, 0, 1, 1, 1, { Tomb = true })
	end
	for i = 0, 20 do
		local x = -330 + i * 10 + 5
		add("Iron_Fence_10", "Fence", x, ground(x, 108), 108, 0, 1, 1, 1)
	end
	for i = 0, 7 do
		local z = 16 + i * 10 + 5
		add("Iron_Fence_10", "Fence", -335, ground(-335, z), z, PI / 2, 1, 1, 1)
	end
	return out
end

return table.freeze(Layout)
