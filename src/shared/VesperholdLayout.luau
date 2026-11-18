--!strict
-- Vesperhold layout data (mac-41 plan, mac-43 build). Pure numbers, no Roblox types: GothicCitadel / GothicMarch
-- build Part massing from it and tools/test_vesperhold_massing.luau checks it. Local frame: origin = Overworld.Vesperhold,
-- +X across the gate, +Z toward the approach (castle at -Z), Y 0 = gate threshold. Kit slots face +Z at Yaw 0; a slot's
-- X/Y/Z is the foot-centre of the piece on the plane it cladded and the body projects toward +Z (outward).
local Layout = {}

-- View 01 (Codex's Snow Refuge eye, work/vesperhold/document_views.py), Roblox FieldOfView is vertical.
Layout.Eye = { X = -15, Y = -24, Z = 548 }
Layout.Aim = { X = 0, Y = 213, Z = -228 }
Layout.Fov = 70
Layout.Aspect = 16 / 9

Layout.Tiers = {
	T0 = { FrontZ = -12, BackZ = -110, X = 340, Top = 0, Bay = 40, MinDrop = 150 },
	T1 = { FrontZ = -30, BackZ = -70, X = 330, CloseZ0 = -72, CloseZ1 = -110, FloorY = 12, Top = 190 },
	T2 = { FrontZ = -110, BackZ = -180, X = 260, FloorY = 190, Top = 260 },
	T3 = { FrontZ = -180, BackZ = -330, X = 200, FloorY = 260, Top = 330 },
}
Layout.Gate = { Half = 13, Height = 26, Lintel = 30 }
Layout.Rose = { X = 0, Y = 312, Z = -180, Diameter = 48 }
Layout.Tower = { X = 120, Z = -212, BaseY = 330, Foot = 60 } -- west towers sit on the T3 front corners
-- Stand-in sizes are native piece sizes in studs: { width, height, depth }; slots carry scale factors.
Layout.Piece = {
	Arcade_Bay_60 = { 40, 60, 14 }, Arcade_Bay_50 = { 40, 50, 14 }, Arcade_Bay_40 = { 40, 40, 14 },
	Bastion_Face = { 40, 80, 10 }, Buttress_Pier = { 12, 70, 12 }, Balustrade_20 = { 20, 8, 2 },
	Flying_Buttress_40 = { 6, 30, 40 }, Pinnacle_Crocket_S = { 6, 12, 6 }, Pinnacle_Crocket_M = { 8, 24, 8 },
	Pinnacle_Crocket_L = { 10, 40, 10 }, Spire_Base_Oct = { 24, 60, 24 }, Spire_Belfry_Stage = { 20, 50, 20 },
	Spire_Lucarne_Mid = { 16, 40, 16 }, Spire_Needle_Tip = { 10, 30, 10 }, Spire_Broken_Top = { 10, 20, 10 },
	Lancet_Tall = { 8, 40, 4 }, Rose_Window_Great = { 48, 48, 6 }, Portal_Great = { 44, 28, 12 },
	Viaduct_Bay = { 30, 120, 22 }, Statue_Plinth = { 6, 4, 6 }, Hooded_Statue_A = { 3, 10, 3 },
	Hooded_Statue_B = { 3, 10, 3 }, Candle_Cluster_A = { 2, 2, 2 }, Banner_Torn_A = { 8, 30, 1 },
}

-- The pilgrims' deck: unchanged path, but now 30-stud bays on tall piers. Level is the deck top at z.
Layout.Viaduct = { Z0 = 4, Z1 = 157, Bay = 30, Width = 19.5, Rail = 9.4 }
function Layout.viaductLevel(z: number): number
	return -18 * (z - 4) / 153
end

-- Walk route from the pilgrim road to the nave. Each segment's top surface runs A -> B; Kind "march" is built by
-- GothicMarch, "core" lies on a masonry core top and "slab" is a deck GothicCitadel lays from this data.
Layout.Route = {
	{ Name = "Viaduct", Kind = "march", Width = 19.5, A = { 0, -18, 157 }, B = { 0, 0, 4 } },
	{ Name = "GateApron", Kind = "slab", Width = 26, Slab = 40, Thick = 4, A = { 0, 0, 4 }, B = { 0, 0, -48 } },
	{ Name = "PassageRamp", Kind = "slab", Width = 26, Slab = 26, Thick = 16, A = { 0, 0, -48 }, B = { 0, 12, -72 } },
	{ Name = "CloseCross", Kind = "core", Width = 26, A = { 0, 12, -72 }, B = { 0, 12, -84 } },
	{ Name = "CloseWalk", Kind = "core", Width = 14, A = { 0, 12, -84 }, B = { -250, 12, -84 } },
	{ Name = "CloseTurn", Kind = "core", Width = 14, A = { -250, 12, -84 }, B = { -250, 12, -101 } },
	{ Name = "CloisterRamp", Kind = "slab", Width = 14, Slab = 14, Thick = 3, Base = 12, A = { -250, 12, -101 }, B = { 250, 190, -101 } },
	{ Name = "CloisterLanding", Kind = "slab", Width = 14, Slab = 14, Thick = 3, Base = 12, A = { 250, 190, -101 }, B = { 250, 190, -130 } },
	{ Name = "CloisterWalk", Kind = "core", Width = 14, A = { 250, 190, -130 }, B = { 190, 190, -172 } },
	{ Name = "CathedralRamp", Kind = "slab", Width = 14, Slab = 14, Thick = 3, Base = 190, A = { 190, 190, -172 }, B = { 20, 260, -172 } },
	{ Name = "PortalLanding", Kind = "slab", Width = 14, Slab = 14, Thick = 3, Base = 190, A = { 20, 260, -172 }, B = { 0, 260, -172 } },
	{ Name = "PortalThreshold", Kind = "slab", Width = 26, Slab = 26, Thick = 3, Base = 190, A = { 0, 260, -172 }, B = { 0, 260, -196 } },
	{ Name = "Nave", Kind = "core", Width = 40, A = { 0, 260, -196 }, B = { 0, 260, -290 } },
}

local function spireList(): { { number } }
	-- Spire tops (above the gate road): { x, z, baseY, top, width, tag }.
	local s = {
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
	return s
end
Layout.Spires = spireList()

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
		local n = math.ceil(drop / 80)
		for k = 0, n - 1 do
			add("Bastion_Face", "Bastion", cx, low + k * drop / n, T0.FrontZ, 0, 1, drop / n / 80, 1, { Drop = drop })
		end
	end
	for i = 0, 17 do
		local x = (i - 8.5) * T0.Bay
		local low = math.min(ground(x, T0.FrontZ), ground(x, T0.FrontZ - 30)) - 8
		add("Buttress_Pier", "Buttress", x, low, T0.FrontZ + 6, 0, 1, (-low + 24) / 70, 1)
	end
	-- T1: three stacked arcade galleries (arches 60/60/50), balustrade, pinnacle row. The gate bay is open at level 0.
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
		add("Balustrade_20", "Balustrade", x, 170, T1.FrontZ + 1, 0, 1, 1, 1, { Tier = "T1" })
	end
	for i = 0, 16 do add("Pinnacle_Crocket_S", "Pinnacle", (i - 8) * 40, 178, T1.FrontZ + 2, 0, 1, 1, 1, { Tier = "T1" }) end
	-- T2 cloister gallery, two levels (40 then 30 tall), on the back wall of the terrace.
	for lvl = 1, 2 do
		for i = 1, 13 do
			add("Arcade_Bay_40", "Arcade", (i - 7) * 40, T2.FloorY + (lvl - 1) * 40, -124, 0, 1, if lvl == 1 then 1 else 0.75, 1, { Tier = "T2", Level = lvl })
		end
	end
	-- T2 -> T3: eight pairs of flying buttresses springing from piers on the terrace to the T3 front wall.
	for _, x in { 28, 42, 56, 70, 84, 162, 176, 190 } do
		for _, s in { -1, 1 } do
			add("Buttress_Pier", "Buttress", s * x, T2.FloorY, -150, 0, 1, 1, 1, { Tier = "T2" })
			add("Flying_Buttress_40", "Flyer", s * x, 250, -150, 0, 1, 35 / 30, 30 / 40, { Tier = "T2", Pair = x })
			add("Pinnacle_Crocket_L", "Pinnacle", s * x, 260, -150, 0, 1, 1, 1, { Tier = "T2" })
		end
	end
	-- T3 west front: dominant rose window over a deep portal, lancet rows.
	add("Rose_Window_Great", "Rose", Layout.Rose.X, Layout.Rose.Y - 24, Layout.Rose.Z, 0, 1, 1, 1)
	add("Portal_Great", "Portal", 0, 0, T1.FrontZ, 0, Layout.Gate.Height / 28, Layout.Gate.Height / 28, 1, { Height = Layout.Gate.Height })
	add("Portal_Great", "Portal", 0, T3.FloorY, T3.FrontZ, 0, 1, 1, 1, { Height = 28 })
	for _, x in { -190, -170, -60, 60, 170, 190 } do add("Lancet_Tall", "Lancet", x, 262, T3.FrontZ, 0, 1, 1, 1) end
	-- Spires: stacks of base / belfry / lucarne modules under a needle tip (the broken one ends in a stump).
	for n, sp in Layout.Spires do
		local x, z, y0, top, w, tag = sp[1], sp[2], sp[3], sp[4], sp[5], sp[6]
		local broken = tag == "BrokenCorner"
		local tip = if broken then 20 else 30
		local h = top - y0
		local base = if h >= 100 then 60 else 0
		local mid = h - base - tip
		local count = math.max(1, math.floor(mid / 45 + 0.5))
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
		add("Viaduct_Bay", "Viaduct", 0, base, zc, 0, 1, (Layout.viaductLevel(zc) - 3.5 - base) / 120, 1, { Level = Layout.viaductLevel(zc) })
		for _, s in { -1, 1 } do
			local top = Layout.viaductLevel(zc)
			add("Statue_Plinth", "Statue", s * V.Rail, top, zc, 0, 1, 1, 1)
			add(if i % 2 == 0 then "Hooded_Statue_A" else "Hooded_Statue_B", "Statue", s * V.Rail, top + 4, zc, if s > 0 then math.pi * 0.5 else -math.pi * 0.5, 1, 1, 1, { Side = s })
			add("Candle_Cluster_A", "Candle", s * V.Rail, top, zc + 5, 0, 1, 1, 1)
		end
	end
	-- Torn crimson banners on the near gate tower.
	for _, b in { { -40, 150 }, { 40, 150 }, { -40, 100 } } do add("Banner_Torn_A", "Banner", b[1], b[2], T1.FrontZ + 15, 0, 1, 1, 1) end
	return out
end

return table.freeze(Layout)
