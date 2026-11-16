--!nonstrict
-- Regression for the M world map maths and data filters (open-world ticket 05). Run from the project root:
--   work/bin/luau/luau.exe tools/test_world_map.luau   (plain Luau CLI; no Lune APIs needed)
-- Pure checks only: transforms, heading arrow, waypoint bearing, discovered altars, POI levels, raster
-- pixel mapping. Studio remains the acceptance for the rendered picture.
local O = require("../src/shared/Overworld")
local W = require("../src/shared/WorldMap")

local passed, failed = 0, 0
local function check(name, condition)
	if condition then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-6) end

-- 1. world -> map -> world at the five region centres, the four frame corners and near-edge points.
local points = {}
for _, id in O.RegionIds do
	local c = O.Regions[id].Bounds.Center
	points[#points + 1] = { id .. " centre", c.X, c.Z }
end
local f = O.Frame
for _, p in { { "NW", f.MinX, f.MinZ }, { "NE", f.MaxX, f.MinZ }, { "SW", f.MinX, f.MaxZ }, { "SE", f.MaxX, f.MaxZ },
	{ "west edge", f.MinX + 3, -5000 }, { "east edge", f.MaxX - 3, -5000 }, { "north edge", -5800, f.MinZ + 3 }, { "south edge", -5800, f.MaxZ - 3 } } do
	points[#points + 1] = p
end
for _, p in points do
	local u, v = O.toMap(p[2], p[3])
	local x, z = O.fromMap(u, v)
	check("world>map>world " .. p[1], math.abs(x - p[2]) < 1 and math.abs(z - p[3]) < 1)
	for _, zoom in { 1, 2.2, 8 } do
		local view = W.clampView({ W = 960, H = 540, Zoom = zoom, U = u, V = v })
		local px, py = W.toPane(view, p[2], p[3])
		local rx, rz = W.fromPane(view, px, py)
		check(string.format("world>pane>world %s zoom %.1f", p[1], zoom), math.abs(rx - p[2]) < 1 and math.abs(rz - p[3]) < 1)
	end
end
local square = W.clampView({ W = 1000, H = 1000, Zoom = 1, U = 0.5, V = 0.5 })
local nx, nz = W.toPane(square, f.MinX, f.MinZ)
local sx, sz = W.toPane(square, f.MaxX, f.MaxZ)
check("zoom 1 puts the frame corners on the pane corners", near(nx, 0) and near(nz, 0) and near(sx, 1000) and near(sz, 1000))
local ex, ez = W.toPane(square, -7200, -8250) -- summit: north is up
check("north is the top of the pane", ez < 500 and ex < 500 and select(2, W.toPane(square, -5800, -1000)) > 500)

-- 2. Pan, clamp and zoom about a point keep the picture covering the pane and the pointer fixed.
local view = W.clampView({ W = 960, H = 540, Zoom = 4, U = 0.5, V = 0.5 })
W.pan(view, 1e6, 1e6)
local left, top, size = W.layout(view)
check("pan clamps to the frame", near(left, 0, 1e-6) and near(top, 0, 1e-6) and left + size >= 960 and top + size >= 540)
for _, at in { { 100, 80 }, { 480, 270 }, { 900, 500 } } do
	local v = W.clampView({ W = 960, H = 540, Zoom = 2, U = 0.4, V = 0.55 })
	local wx, wz = W.fromPane(v, at[1], at[2])
	W.zoomAbout(v, 1.6, at[1], at[2])
	local px, py = W.toPane(v, wx, wz)
	check("zoom keeps the pointer's world point fixed", near(px, at[1], 1e-6) and near(py, at[2], 1e-6))
end
local out = W.zoomAbout({ W = 960, H = 540, Zoom = 7, U = 0.5, V = 0.5 }, 100, 480, 270)
check("zoom clamps to the maximum", out.Zoom == W.MaxZoom)
check("zoom clamps to the minimum", W.zoomAbout({ W = 960, H = 540, Zoom = 2, U = 0.5, V = 0.5 }, 0.001, 480, 270).Zoom == W.MinZoom)

-- 3. Heading arrow: 0 = world -Z, clockwise; a GuiObject rotation is the heading itself.
for _, case in { { "N", 0, -1, 0 }, { "E", 1, 0, 90 }, { "S", 0, 1, 180 }, { "W", -1, 0, 270 } } do
	check("arrow " .. case[1], near(W.arrowRotation(W.bearing(case[2], case[3])), case[4]))
end
check("arrow 359.9999 stays below 360", W.arrowRotation(359.9999) < 360 and W.arrowRotation(359.9999) > 359)
check("arrow 360 is 0", W.arrowRotation(360) == 0)
check("arrow -1 is 359", near(W.arrowRotation(-1), 359))
check("tiny negative heading is 0 not 360", W.bearing(-1e-17, -1) == 0)
local d = math.abs(W.arrowRotation(359) - W.arrowRotation(0))
check("359 -> 0 is one degree on the wheel", near(math.min(d, 360 - d), 1))

-- 4. Waypoint bearing N / E / S / W / diagonal (matches Compass.bearing's convention).
check("waypoint north", near(W.waypointBearing(0, 0, 0, -500), 0))
check("waypoint east", near(W.waypointBearing(0, 0, 500, 0), 90))
check("waypoint south", near(W.waypointBearing(0, 0, 0, 500), 180))
check("waypoint west", near(W.waypointBearing(0, 0, -500, 0), 270))
check("waypoint north-east", near(W.waypointBearing(100, 100, 600, -400), 45))

-- 5. Altars: only lit ones, never retired ones.
local all = {}
for id in O.Altars do all[id] = true end
for id in O.RetiredAltars do all[id] = true end
local listed = W.discoveredAltars(all, O.Altars, O.RetiredAltars)
check("every active altar listed once", #listed == 9)
local seen = {}
for _, altar in listed do
	check("listed altar is not retired: " .. altar.Id, O.RetiredAltars[altar.Id] == nil)
	check("altar listed once: " .. altar.Id, not seen[altar.Id])
	seen[altar.Id] = true
end
check("undiscovered altars are not listed", #W.discoveredAltars({ Altar_MonasteryGate = true }, O.Altars, O.RetiredAltars) == 1)
check("nothing discovered lists nothing", #W.discoveredAltars({}, O.Altars, O.RetiredAltars) == 0)
local legacy = { Altar_SanctuaryDepths = { Id = "Altar_SanctuaryDepths" }, Altar_MonasteryGate = O.Altars.Altar_MonasteryGate }
local guarded = W.discoveredAltars({ Altar_SanctuaryDepths = true, Altar_MonasteryGate = true }, legacy, O.RetiredAltars)
check("a retired altar left in the table is still dropped", #guarded == 1 and guarded[1].Id == "Altar_MonasteryGate")

-- 6. POIs: hidden ones need a find; levels filter.
local surface = W.visiblePois(O.POIs, "Surface", {})
local underground = W.visiblePois(O.POIs, "Underground", {})
local hiddenShown = false
for _, poi in surface do hiddenShown = hiddenShown or poi.Hidden end
for _, poi in underground do hiddenShown = hiddenShown or poi.Hidden end
check("hidden POIs are not listed", not hiddenShown)
check("no cache on the map before it is found", (function() for _, p in surface do if p.Kind == "Cache" then return false end end return true end)())
check("surface level has no underground POI", (function() for _, p in surface do if p.Level ~= "Surface" then return false end end return true end)())
check("underground level lists only caves", #underground == 3 and (function() for _, p in underground do if p.Level ~= "Underground" or p.Kind ~= "Cave" then return false end end return true end)())
check("a found hidden POI appears on its level", #W.visiblePois(O.POIs, "Underground", { UnderCrossingGrotto = true }) == 4)
check("a found cache appears on the surface", #W.visiblePois(O.POIs, "Surface", { Cache_WaterfallAlcove = true }) == #surface + 1)
check("level from depth below the surface", W.levelAt(100, 200) == "Underground" and W.levelAt(195, 200) == "Surface" and W.levelAt(250, 200) == "Surface")

-- 7. Landmarks are sighted by distance (client-side only) or found.
local tower = O.Landmarks.BrokenBellTower
check("a landmark is sighted from within 20 heights", W.sighted(tower.Position.X + 1500, tower.Position.Z, tower))
check("a landmark is hidden from far away", not W.sighted(tower.Position.X + 5000, tower.Position.Z, tower))
check("far landmarks are listed once found", #W.visibleLandmarks(O.Landmarks, -2200, -1400, { SummitTemple = true }) == 1)
check("nothing sighted at the gateway glade", #W.visibleLandmarks(O.Landmarks, -2200, -1400, {}) == 0)

-- 8. Region names match the ruling.
local names = {}
for _, label in W.regionLabels() do names[label.Id] = label.Name end
check("display names follow the ruling", names.Forest == "The Bellwood" and names.GoldenRavine == "Amberfall Ravine" and names.AridBasin == "The Saltreach"
	and names.Snowfields == "Frostmere Heads" and names.MountainAscent == "The Ashen Stair" and names.AshColosseum == "Ash Colosseum")

-- 9. Lobby rule.
check("sanctuary and a missing region are the lobby", W.isLobby("Sanctuary") and W.isLobby(nil) and W.isLobby(""))
check("overworld regions are not the lobby", not W.isLobby("Forest") and not W.isLobby("MountainAscent") and not W.isLobby("DesecratedMonastery"))
check("inside the frame with no region box is not the lobby; the lobby itself still is", not W.isLobby(nil, -9900, -5000) and not W.isLobby("", -2200, -1408) and W.isLobby(nil, 0, 920) and W.isLobby("Sanctuary", 0, 920))

-- 10. Raster: a pixel centre lies within half a pixel of the true point; rows paint opaque and read the terrain.
local RES = W.Resolution
for _, id in O.RegionIds do
	local c = O.Regions[id].Bounds.Center
	local u, v = O.toMap(c.X, c.Z)
	local col, row = math.floor(u * RES), math.floor(v * RES)
	local px, pz = O.fromMap((col + 0.5) / RES, (row + 0.5) / RES)
	local half = (f.MaxX - f.MinX) / RES / 2 + 1e-6
	check("raster pixel centre within half a pixel at " .. id, math.abs(px - c.X) <= half and math.abs(pz - c.Z) <= half)
end
local buf = buffer.create(RES * RES * 4)
local lakeU, lakeV = 0.5, 0.5 -- the first open-water pixel the terrain has (the gateway lake or the sea), found rather than hard-coded
do
	local found = false
	for row = 0, RES - 1 do
		for col = 0, RES - 1 do
			local x, z = O.fromMap((col + 0.5) / RES, (row + 0.5) / RES)
			local h, _, _, chasm = O.sampleAt(x, z)
			if not found and h < f.WaterY and chasm == 0 then found, lakeU, lakeV = true, (col + 0.5) / RES, (row + 0.5) / RES end
		end
	end
	check("the terrain has open water to paint", found)
end
local lakeRow = math.floor(lakeV * RES)
local snowU, snowV = O.toMap(-7200, -8250)
local snowRow = math.floor(snowV * RES)
for _, row in { lakeRow, snowRow } do W.paintRow(buf, RES, row) end
local lr, lg, lb = W.readPixel(buf, RES, math.floor(lakeU * RES), lakeRow)
check("open water paints as water", lb > lr and lb > 90 and buffer.readu8(buf, (lakeRow * RES + math.floor(lakeU * RES)) * 4 + 3) == 255)
local sr, sg, sb = W.readPixel(buf, RES, math.floor(snowU * RES), snowRow)
check("the summit paints bright", sr + sg + sb > 330)
-- C3 ravine: the chasm floor is below Frame.WaterY but dry; the bake must not paint it as water.
local floorChecks, floorBelow = 0, 0
for _, p in O.TerrainDef.Chasm.Points do
	local cu, cv = O.toMap(p[1], p[2])
	local crow = math.floor(cv * RES)
	W.paintRow(buf, RES, crow)
	local ccol = math.floor(cu * RES)
	local h = O.sampleAt((ccol + 0.5) / RES * (f.MaxX - f.MinX) + f.MinX, (crow + 0.5) / RES * (f.MaxZ - f.MinZ) + f.MinZ)
	local cr, cg, cb = W.readPixel(buf, RES, ccol, crow)
	floorChecks += 1
	floorBelow += if h < f.WaterY then 1 else 0
	check(string.format("chasm floor pixel at (%d,%d) is not water blue", p[1], p[2]), not (cb > cr and cb > 90))
end
check("at least one chasm centreline pixel lies below WaterY (the case this guards)", floorChecks > 0 and floorBelow > 0)

-- 11. Restyle (lane 5): painted from the same data, parchment, no speckle, contours, clean strokes, coast.
local function isColor(r, g, b, c) return r == c[1] and g == c[2] and b == c[3] end
local full = buffer.create(RES * RES * 4)
local t0 = os.clock()
for row = 0, RES - 1 do W.paintRow(full, RES, row) end
local t1 = os.clock()
local pre = buffer.create(RES * RES * 4)
buffer.copy(pre, 0, full, 0, RES * RES * 4)
W.paintRoutes(full, RES)
print(string.format("bake: rows %.3fs, routes %.3fs (old bake on this machine: about 1.7s rows)", t1 - t0, os.clock() - t1))
-- a row painted alone equals the same row inside a full bake (the row cache never changes a pixel)
local same = true
for _, p in { { lakeU, lakeV }, { snowU, snowV } } do
	local col, row = math.floor(p[1] * RES), math.floor(p[2] * RES)
	local a1, a2, a3 = W.readPixel(pre, RES, col, row)
	W.paintRow(buf, RES, row)
	local b1, b2, b3 = W.readPixel(buf, RES, col, row)
	same = same and a1 == b1 and a2 == b2 and a3 == b3
end
check("a row painted alone equals the same row in a full bake", same)

-- flat ground (an 11 x 11 pixel window whose heights span under 12 studs, all dry): adjacent pixels differ by a few
-- levels at most, i.e. no per-pixel material speckle. Windows are found from the terrain, not hard-coded.
local flatWindows, worst, sum, n = 0, 0, 0, 0
for wr = 2, RES - 9, 7 do
	for wc = 2, RES - 9, 7 do
		local lo, hi, dry = math.huge, -math.huge, true
		for row = wr - 2, wr + 8 do -- the shading reads two pixels either side, so flatness is judged over 11 x 11
			for col = wc - 2, wc + 8 do
				local x, z = O.fromMap((col + 0.5) / RES, (row + 0.5) / RES)
				local h, _, _, chasm = O.sampleAt(x, z)
				lo, hi, dry = math.min(lo, h), math.max(hi, h), dry and h > f.WaterY + 2 and chasm == 0
			end
		end
		if hi - lo < 12 and dry then
			flatWindows += 1
			for row = wr, wr + 5 do
				for col = wc, wc + 5 do
					local r1, g1, b1 = W.readPixel(pre, RES, col, row)
					for _, d in { { 1, 0 }, { 0, 1 } } do
						local r2, g2, b2 = W.readPixel(pre, RES, col + d[1], row + d[2])
						local diff = math.max(math.abs(r1 - r2), math.abs(g1 - g2), math.abs(b1 - b2))
						worst, sum, n = math.max(worst, diff), sum + diff, n + 1
					end
				end
			end
		end
	end
end
check(string.format("flat ground has no speckle (%d windows, worst adjacent step %d, mean %.2f)", flatWindows, worst, n > 0 and sum / n or -1), flatWindows >= 1 and worst <= 12 and sum / n <= 3)

-- contours: classification rule, then the raster draws them
check("contour rule: flat none, minor, index, steep keeps index only",
	W.contourClass(95, 95.5, 95, 0.2) == 0 and W.contourClass(110, 130, 110, 0.2) == 1 and W.contourClass(190, 210, 190, 0.2) == 2
	and W.contourClass(110, 130, 110, 0.01) == 0 and W.contourClass(110, 130, 110, 0.9) == 0 and W.contourClass(190, 210, 190, 0.9) == 2)
local lined, plain, lineLum, plainLum = 0, 0, 0, 0
local cu0, cv0 = O.toMap(-7600, -7400)
local cu1, cv1 = O.toMap(-6800, -6600)
local cellW, cellH = (f.MaxX - f.MinX) / RES, (f.MaxZ - f.MinZ) / RES
for row = math.floor(cv0 * RES), math.floor(cv1 * RES) do
	for col = math.floor(cu0 * RES), math.floor(cu1 * RES) do
		local x, z = O.fromMap((col + 0.5) / RES, (row + 0.5) / RES)
		local h = O.heightAt(x, z)
		local c = W.contourClass(h, O.heightAt(x + cellW, z), O.heightAt(x, z + cellH), 0.3) -- a mid slope
		local r, g, b = W.readPixel(pre, RES, col, row)
		if c > 0 then lined += 1; lineLum += r + g + b else plain += 1; plainLum += r + g + b end
	end
end
check("mountain slope carries contour lines", lined >= 20)
check("contour pixels are darker than the ground between them", lined > 0 and plain > 0 and lineLum / lined < plainLum / plain)

-- strokes: every road edge's midpoint pixel is a road core; the wet river is drawn in its own colour
local edges, onRoad = 0, 0
for _, rd in O.terrainData().Roads do
	for k = 2, #rd.Points do
		local p, q = rd.Points[k - 1], rd.Points[k]
		local mu, mv = O.toMap((p[1] + q[1]) / 2, (p[2] + q[2]) / 2)
		local hit = 0
		for dy = -1, 1 do -- a thin line can clip a corner of the midpoint pixel, so the 3 x 3 around it counts
			for dx = -1, 1 do
				local r, g, b = W.readPixel(full, RES, math.floor(mu * RES) + dx, math.floor(mv * RES) + dy)
				hit += if isColor(r, g, b, W.Colors.RoadMain) or isColor(r, g, b, W.Colors.RoadMinor) then 1 else 0
			end
		end
		edges += 1
		onRoad += if hit > 0 then 1 else 0
	end
end
check(string.format("road pixels lie along every route edge (%d/%d)", onRoad, edges), edges > 0 and onRoad == edges)
local riverSeen = false
for _, river in O.TerrainDef.Rivers do
	if river.Wet then
		for k = 2, #river.Points do
			local mu, mv = O.toMap((river.Points[k - 1][1] + river.Points[k][1]) / 2, (river.Points[k - 1][2] + river.Points[k][2]) / 2)
			local r, g, b = W.readPixel(full, RES, math.floor(mu * RES), math.floor(mv * RES))
			riverSeen = riverSeen or isColor(r, g, b, W.Colors.River)
		end
	end
end
check("the wet river is drawn as a river stroke", riverSeen)

-- coast: open water paints flat blue with a coast outline
local coastSeen, waterSeen = false, false
for row = 0, RES - 1 do
	for col = 0, RES - 1 do
		local r, g, b = W.readPixel(pre, RES, col, row)
		coastSeen = coastSeen or isColor(r, g, b, W.Colors.Coast)
		waterSeen = waterSeen or (b > r + 20 and b > 140)
	end
end
check("water has a coast line and open water", coastSeen and waterSeen)

-- 12. Marker inset and follow rules (small, medium and large panes; the old finding: marker hidden behind "You").
local ARROW = 13 -- half of the 26 px arrow glyph
local function clearOf(px, py, rect) -- the whole arrow glyph, not just its centre, is outside the rect
	return rect == nil or px + ARROW <= rect.L or px - ARROW >= rect.R or py + ARROW <= rect.T or py - ARROW >= rect.B
end
local targets = {}
for _, id in O.RegionIds do targets[#targets + 1] = { id, O.Regions[id].Bounds.Center.X, O.Regions[id].Bounds.Center.Z } end
for _, p in { { "NE", f.MaxX, f.MinZ }, { "SE", f.MaxX, f.MaxZ }, { "E edge", f.MaxX - 10, -5000 }, { "N edge", -5800, f.MinZ + 10 }, { "SW", f.MinX, f.MaxZ } } do
	targets[#targets + 1] = p
end
-- Lane 5c: the safe area is derived from the real Tools / Legend rects at each pane size. Every frame edge and corner, opened
-- fresh and reached by walking there (follow), leaves the whole arrow clear of both rects.
local frameEdges = { { "NE", f.MaxX, f.MinZ }, { "SE", f.MaxX, f.MaxZ }, { "NW", f.MinX, f.MinZ }, { "SW", f.MinX, f.MaxZ },
	{ "E edge", f.MaxX, -5000 }, { "W edge", f.MinX, -5000 }, { "N edge", -5800, f.MinZ }, { "S edge", -5800, f.MaxZ } }
for _, pane in { { 443, 199 }, { 996, 550 }, { 1040, 660 }, { 640, 360 } } do
	local tools, legend = W.controlRects(pane[1], pane[2])
	check(string.format("%dx%d legend shows only on a tall pane", pane[1], pane[2]), (legend ~= nil) == (pane[2] >= W.Layout.LegendMinHeight))
	local list = {}
	for _, p in targets do list[#list + 1] = p end
	for _, p in frameEdges do list[#list + 1] = p end
	for _, p in list do
		local fresh = { W = pane[1], H = pane[2], Zoom = 2.2, U = 0.5, V = 0.5, Inset = W.insetFor(pane[1], pane[2]) }
		local v = W.centreOn(fresh, p[2], p[3])
		local walked = W.centreOn({ W = pane[1], H = pane[2], Zoom = 2.2, U = 0.5, V = 0.5, Inset = W.insetFor(pane[1], pane[2]) }, -5800, -5000)
		W.follow(walked, p[2], p[3], 0)
		for how, view in { opened = v, followed = walked } do
			local px, py = W.toPane(view, p[2], p[3])
			local l, t, r, b = W.safeRect(view)
			check(string.format("%dx%d marker %s (%s) sits in the safe rect", pane[1], pane[2], p[1], how),
				px >= l - 1e-6 and px <= r + 1e-6 and py >= t - 1e-6 and py <= b + 1e-6)
			check(string.format("%dx%d marker %s (%s) clears Tools and Legend", pane[1], pane[2], p[1], how), clearOf(px, py, tools) and clearOf(px, py, legend))
		end
	end
	-- the picture itself still covers the safe rect, so no marker is ever scrolled out of reach
	local cov = W.clampView({ W = pane[1], H = pane[2], Zoom = 2.2, U = 0.5, V = 0.5, Inset = W.insetFor(pane[1], pane[2]) })
	local cl, ct, cs = W.layout(cov)
	local sl, st, sr, sb = W.safeRect(cov)
	check(string.format("%dx%d picture covers the safe rect", pane[1], pane[2]), cl <= sl + 1e-6 and ct <= st + 1e-6 and cl + cs >= sr - 1e-6 and ct + cs >= sb - 1e-6)
end
local inset = W.insetFor(996, 550)
local mid = W.centreOn({ W = 996, H = 550, Zoom = 2.2, U = 0.5, V = 0.5, Inset = inset }, -5800, -5000)
local mx, my = W.toPane(mid, -5800, -5000)
check("opening centres the player in the safe rect", near(mx, (996 - inset.Right) / 2, 1e-6) and near(my, inset.Top + (550 - inset.Top - inset.Bottom) / 2, 1e-6))
local plainView = W.clampView({ W = 960, H = 540, Zoom = 4, U = 0, V = 1 }) -- no inset: the picture covers the whole pane, as before
local pl, pt, ps = W.layout(plainView)
check("without an inset the picture still covers the pane", near(pl, 0, 1e-6) and near(pt + ps, 540, 1e-6))

-- follow: walking east pans just enough to keep the marker inside; a manual pan is not fought; nothing moves while inside
local fv = W.centreOn({ W = 996, H = 550, Zoom = 2.2, U = 0.5, V = 0.5, Inset = inset }, -6000, -5000)
local sx, sy, moved, kept = -6000, -5000, false, true
while sx < f.MaxX - 60 do
	local nx = sx + 20
	if W.markerInside(fv, sx, sy, 16) and not W.markerInside(fv, nx, sy, 16) then
		moved = W.follow(fv, nx, sy, 16) or moved
	end
	sx = nx
	local px = W.toPane(fv, sx, sy)
	kept = kept and px <= 996 - inset.Right + 1e-6 -- never under the buttons
end
check("walking east, the marker never goes under the controls and the view followed", kept and moved)
local still = W.centreOn({ W = 996, H = 550, Zoom = 2.2, U = 0.5, V = 0.5, Inset = inset }, -3000, -5000)
local u0, v0 = still.U, still.V
check("follow does nothing while the marker is inside", W.follow(still, -3000, -5000, 16) == false and still.U == u0 and still.V == v0)
W.pan(still, 4000, 0) -- the user drags the picture far away: the marker is outside, and following only fires on a crossing
check("a manual pan can leave the marker outside", not W.markerInside(still, -3000, -5000, 16))

-- 13. Lane 5c: the biome tint is continuous across every region border (no straight seam). Walk one pixel at a time over
-- each side of each region box at a fixed height (so only the biome weights can change) and bound the step.
local cell = (f.MaxX - f.MinX) / RES
local TINT_STEP_MAX = 16 -- measured worst 13 over a ~12 px ramp; the old six-pixel ramp with a height filter stepped far more
local worstTint, tintWalks = 0, 0
for _, id in O.RegionIds do
	local b = O.Regions[id].Bounds
	for _, side in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		local bx, bz = b.Center.X + side[1] * b.Size.X / 2, b.Center.Z + side[2] * b.Size.Z / 2
		local pr, pg, pb = W.tintAt(bx - side[1] * 20 * cell, bz - side[2] * 20 * cell, 150)
		for step = -19, 20 do
			local r, g, bl = W.tintAt(bx + side[1] * step * cell, bz + side[2] * step * cell, 150)
			worstTint = math.max(worstTint, math.abs(r - pr), math.abs(g - pg), math.abs(bl - pb))
			pr, pg, pb = r, g, bl
		end
		tintWalks += 1
	end
end
print(string.format("tint: %d border walks, worst adjacent-pixel step %.2f /255", tintWalks, worstTint))
check("biome tint adjacent-pixel step stays under the bound across every region border", tintWalks == 20 and worstTint <= TINT_STEP_MAX)

print(string.format("world map: %d passed, %d failed", passed, failed))
if failed > 0 then error("world map regression failed") end
