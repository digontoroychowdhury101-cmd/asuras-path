--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/WorldMap
-- Engine-free maths and data filters for the M world map (open-world brief section 12). The one
-- source of truth stays Overworld: positions go through Overworld.toMap / fromMap, the picture is
-- painted from Overworld.surfaceAt and the route/river data, markers come from its altar, landmark
-- and POI tables. Nothing here touches Instances, so tools/test_world_map.luau runs it directly.
local hasScript = pcall(function() return script.Parent end)
local Overworld: any = if hasScript then require(script.Parent.Overworld) else require("./Overworld")

local WorldMap = {}

WorldMap.Resolution = 256 -- raster edge in pixels (8400 studs / 256 = ~33 studs per pixel)
WorldMap.MinZoom, WorldMap.MaxZoom = 1, 8
WorldMap.SightFactor = 20 -- a landmark is "sighted" within this many times its height
WorldMap.UndergroundDepth = 12 -- studs below the terrain surface that count as the Underground level

-- View: pane size in pixels, zoom (1 = the whole frame fits the short side) and the UV under the pane centre.
-- Inset (optional, pixels) is the strip the pane's controls cover: the picture always covers the pane minus it, so a
-- marker can be scrolled clear of the controls even at the frame edge. nil behaves as no inset.
export type Inset = { Left: number, Top: number, Right: number, Bottom: number }
export type View = { W: number, H: number, Zoom: number, U: number, V: number, Inset: Inset? }

-- The lobby (Sanctuary) keeps its radar and has no map; a missing region is treated as the lobby too.
-- Standing inside Overworld.Frame is never the lobby even when no region box holds the player (box heights leave gaps on
-- the western slope, found by the T05 survey): the map must stay and the radar must stay off there.
function WorldMap.isLobby(region: any, x: number?, z: number?): boolean
	local F = Overworld.Frame
	if x and z and x >= F.MinX and x <= F.MaxX and z >= F.MinZ and z <= F.MaxZ then
		return false
	end
	return region == nil or region == "" or region == "Sanctuary"
end

-- Bearing in degrees, 0 = world -Z (north), clockwise: the SakuraCompass convention.
function WorldMap.bearing(dx: number, dz: number): number
	local degrees = math.deg(math.atan2(dx, -dz)) % 360
	return if degrees >= 360 then 0 else degrees -- a tiny negative angle rounds up to exactly 360
end

-- GuiObject.Rotation is clockwise, so an up-pointing arrow glyph turns by the heading itself.
function WorldMap.arrowRotation(heading: number): number
	local r = heading % 360
	return if r >= 360 then 0 else r
end

function WorldMap.waypointBearing(px: number, pz: number, wx: number, wz: number): number
	return WorldMap.bearing(wx - px, wz - pz)
end

-- View geometry -------------------------------------------------------------------------------

local function sizeOf(view: View): number
	return math.min(view.W, view.H) * view.Zoom
end

-- Pane controls (pixels, pane space), the one source for the controller's frames and for the marker's safe area: the Tools
-- column (zoom buttons and You) sits top-right, the Legend bottom-left (shown only on a pane at least LegendMinHeight tall),
-- the hint across the top. Gap keeps the whole arrow glyph (26 px) clear of a control, not just its centre.
WorldMap.Layout = table.freeze({
	ToolsW = 60, ToolsH = 150, ToolsMargin = 8, LegendW = 190, LegendH = 128, LegendMargin = 8, LegendMinHeight = 340,
	HintBottom = 24, Gap = 24,
})

export type Rect = { L: number, T: number, R: number, B: number }

-- The Tools and (when shown) Legend rects for a pane of w x h.
function WorldMap.controlRects(w: number, h: number): (Rect, Rect?)
	local k = WorldMap.Layout
	local tools = { L = w - k.ToolsMargin - k.ToolsW, T = k.ToolsMargin, R = w - k.ToolsMargin, B = k.ToolsMargin + k.ToolsH }
	local legend = if h >= k.LegendMinHeight
		then { L = k.LegendMargin, T = h - k.LegendMargin - k.LegendH, R = k.LegendMargin + k.LegendW, B = h - k.LegendMargin } else nil
	return tools, legend
end

-- Strip insets that keep a marker out of the real controls at any pane size: right of the Tools column, under the hint,
-- above the Legend. (A strip, not the exact rect, keeps the safe area one rectangle; the picture still covers it.)
function WorldMap.insetFor(w: number, h: number): Inset
	local k = WorldMap.Layout
	local tools, legend = WorldMap.controlRects(w, h)
	return { Left = 0, Top = k.HintBottom + k.Gap / 2, Right = w - tools.L + k.Gap, Bottom = if legend then h - legend.T + k.Gap else 0 }
end

-- The pane minus the inset as (left, top, right, bottom) pixel bounds; an inset that would leave nothing is ignored.
function WorldMap.safeRect(view: View): (number, number, number, number)
	local i = view.Inset
	if i == nil or i.Left + i.Right >= view.W - 8 or i.Top + i.Bottom >= view.H - 8 then
		return 0, 0, view.W, view.H
	end
	return i.Left, i.Top, view.W - i.Right, view.H - i.Bottom
end

-- One axis of the clamp: the picture (`size` long, `centre` = the pane centre on that axis) covers [lo, hi], or is
-- centred in it when smaller.
local function clampAxis(c: number, size: number, centre: number, lo: number, hi: number): number
	local before, after = (centre - lo) / size, (hi - centre) / size -- UV span from the centre to each bound
	if before + after >= 1 then
		return (centre - (lo + (hi - lo - size) / 2)) / size
	end
	return math.clamp(c, before, 1 - after)
end

-- Keeps the picture covering the safe rect (the whole pane without an inset), centred when it is smaller.
function WorldMap.clampView(view: View): View
	view.Zoom = math.clamp(view.Zoom, WorldMap.MinZoom, WorldMap.MaxZoom)
	local size = sizeOf(view)
	local l, t, r, b = WorldMap.safeRect(view)
	view.U = clampAxis(view.U, size, view.W / 2, l, r)
	view.V = clampAxis(view.V, size, view.H / 2, t, b)
	return view
end

-- Pane-space top-left of the (square) picture and its edge length.
function WorldMap.layout(view: View): (number, number, number)
	local size = sizeOf(view)
	return view.W / 2 - view.U * size, view.H / 2 - view.V * size, size
end

function WorldMap.toPane(view: View, x: number, z: number): (number, number)
	local left, top, size = WorldMap.layout(view)
	local u, v = Overworld.toMap(x, z)
	return left + u * size, top + v * size
end

function WorldMap.fromPane(view: View, px: number, py: number): (number, number)
	local left, top, size = WorldMap.layout(view)
	return Overworld.fromMap((px - left) / size, (py - top) / size)
end

function WorldMap.pan(view: View, dx: number, dy: number): View
	local size = sizeOf(view)
	view.U -= dx / size
	view.V -= dy / size
	return WorldMap.clampView(view)
end

-- Zooms by `factor` keeping the world point under pane pixel (px, py) where it is.
function WorldMap.zoomAbout(view: View, factor: number, px: number, py: number): View
	local wx, wz = WorldMap.fromPane(view, px, py)
	local u, v = Overworld.toMap(wx, wz)
	view.Zoom = math.clamp(view.Zoom * factor, WorldMap.MinZoom, WorldMap.MaxZoom)
	local size = sizeOf(view)
	view.U = (view.W / 2 - px + u * size) / size
	view.V = (view.H / 2 - py + v * size) / size
	return WorldMap.clampView(view)
end

-- Puts world point (x, z) at the centre of the safe rect (as far as the clamp allows).
function WorldMap.centreOn(view: View, x: number, z: number): View
	local l, t, r, b = WorldMap.safeRect(view)
	local u, v = Overworld.toMap(x, z)
	local size = sizeOf(view)
	view.U = (view.W / 2 - (l + r) / 2) / size + u
	view.V = (view.H / 2 - (t + b) / 2) / size + v
	return WorldMap.clampView(view)
end

-- True while (x, z) is at least `margin` pixels inside the safe rect.
function WorldMap.markerInside(view: View, x: number, z: number, margin: number): boolean
	local l, t, r, b = WorldMap.safeRect(view)
	local px, py = WorldMap.toPane(view, x, z)
	local eps = 0.01 -- a marker that follow() just placed on the boundary still counts as inside
	return px >= l + margin - eps and px <= r - margin + eps and py >= t + margin - eps and py <= b - margin + eps
end

-- Pans just enough to bring (x, z) back inside the margin of the safe rect; true when it moved.
function WorldMap.follow(view: View, x: number, z: number, margin: number): boolean
	local l, t, r, b = WorldMap.safeRect(view)
	local px, py = WorldMap.toPane(view, x, z)
	local dx = if px < l + margin then l + margin - px elseif px > r - margin then r - margin - px else 0
	local dy = if py < t + margin then t + margin - py elseif py > b - margin then b - margin - py else 0
	if dx == 0 and dy == 0 then return false end
	WorldMap.pan(view, dx, dy)
	return true
end

-- Marker data --------------------------------------------------------------------------------

-- Altars the player has lit (`unlocked` is the AsuraAltars set), in id order. Retired altars stay in
-- saved profiles but are never markers, whatever the set says.
function WorldMap.discoveredAltars(unlocked: { [string]: boolean }, altars: { [string]: any }, retired: { [string]: any }): { any }
	local list: { any } = {}
	for id, altar in altars do
		if unlocked[id] and retired[id] == nil then
			table.insert(list, altar)
		end
	end
	table.sort(list, function(a: any, b: any) return a.Id < b.Id end)
	return list
end

-- POIs on `level`; a Hidden POI (every cache, the under-crossing grotto) only once `found` holds its id.
function WorldMap.visiblePois(pois: { any }, level: string, found: { [string]: boolean }): { any }
	local list: { any } = {}
	for _, poi in pois do
		if poi.Level == level and (not poi.Hidden or found[poi.Id]) then
			table.insert(list, poi)
		end
	end
	return list
end

-- Level of a body at height y over ground height `surface` (kept simple: well below the terrain is Underground).
function WorldMap.levelAt(y: number, surface: number): string
	return if y < surface - WorldMap.UndergroundDepth then "Underground" else "Surface"
end

function WorldMap.sighted(px: number, pz: number, landmark: any): boolean
	local dx, dz = landmark.Position.X - px, landmark.Position.Z - pz
	return math.sqrt(dx * dx + dz * dz) <= landmark.Height * WorldMap.SightFactor
end

-- Landmarks the player has sighted (client-side only) or whose id is in `found`.
function WorldMap.visibleLandmarks(landmarks: { [string]: any }, px: number, pz: number, found: { [string]: boolean }): { any }
	local list: { any } = {}
	for id, landmark in landmarks do
		if found[id] or WorldMap.sighted(px, pz, landmark) then
			table.insert(list, landmark)
		end
	end
	table.sort(list, function(a: any, b: any) return a.Id < b.Id end)
	return list
end

-- Region title anchors in UV, display names straight from Overworld.Regions[...].Name.
function WorldMap.regionLabels(): { { Id: string, Name: string, U: number, V: number } }
	local labels = {}
	local ids = table.clone(Overworld.RegionIds)
	table.insert(ids, "AshColosseum")
	for _, id in ids do
		local region = Overworld.Regions[id]
		local u, v = Overworld.toMap(region.Bounds.Center.X, region.Bounds.Center.Z)
		table.insert(labels, { Id = id, Name = region.Name, U = u, V = v })
	end
	return labels
end

-- Raster -------------------------------------------------------------------------------------

-- Parchment style: a muted tint per biome (mixed by Overworld.blendAt, so borders are soft, never per-pixel material
-- noise) that runs from `Low` at sea level to `High` at `Top` studs (`Curve` > 1 holds it back until high), laid over
-- parchment, lit from the north-west by the height gradient, with contour lines. Water, the coast, roads and rivers
-- are flat colours so they read as clean strokes.
local PARCHMENT, PARCHMENT_MIX = { 226, 208, 170 }, 0.3
local BIOME: { [string]: { Low: { number }, High: { number }, Top: number, Curve: number } } = {
	Forest = { Low = { 142, 156, 102 }, High = { 120, 134, 88 }, Top = 400, Curve = 1 },
	GoldenRavine = { Low = { 212, 172, 104 }, High = { 190, 140, 80 }, Top = 500, Curve = 1 },
	AridBasin = { Low = { 226, 206, 158 }, High = { 212, 184, 132 }, Top = 300, Curve = 1 },
	Snowfields = { Low = { 222, 228, 226 }, High = { 236, 240, 242 }, Top = 900, Curve = 1 },
	MountainAscent = { Low = { 150, 146, 112 }, High = { 240, 238, 232 }, Top = 1650, Curve = 2.2 },
}
local WATER_SHALLOW, WATER_DEEP, COAST = { 156, 182, 192 }, { 126, 158, 176 }, { 88, 116, 132 }
local UMBER = { 112, 84, 58 } -- chasm floor: depth, never water
WorldMap.Colors = table.freeze({
	Coast = COAST, RoadMain = { 238, 214, 150 }, RoadMinor = { 206, 178, 118 }, RoadCasing = { 116, 90, 60 },
	River = { 104, 146, 176 }, RiverDry = { 150, 112, 70 },
})
local SHADE_STEPS = 24 -- the light is quantised so a gentle slope never shimmers
local LIGHT_GAIN, LIGHT_MIN, LIGHT_MAX, LIGHT_BASE = 1.1, -0.4, 0.2, 0.92 -- LIGHT_BASE keeps pale biomes from clipping to white
local CONTOUR = 40 -- studs between contour lines; every INDEX_EVERY-th line is an index contour
local INDEX_EVERY = 5
local FLAT_BELOW, STEEP_ABOVE = 0.04, 0.7 -- no contours on flat ground; only index contours on cliffs (slope = rise / run)

-- 0 none, 1 minor, 2 index: does a contour pass between this pixel's height `h` and its east / south neighbours
-- (`he`, `hs`) on ground whose gradient magnitude is `g`?
local function crossing(a: number, other: number): number
	local b = math.floor(other / CONTOUR)
	if a == b then return 0 end
	return if math.max(a, b) % INDEX_EVERY == 0 then 2 else 1
end

function WorldMap.contourClass(h: number, he: number, hs: number, g: number): number
	if g < FLAT_BELOW then return 0 end
	local a = math.floor(h / CONTOUR)
	local best = math.max(crossing(a, he), crossing(a, hs))
	return if g > STEEP_ABOVE and best < 2 then 0 else best
end

function WorldMap.pixel(buf: buffer, res: number, col: number, row: number, color: { number })
	if col < 0 or row < 0 or col >= res or row >= res then
		return
	end
	local offset = (row * res + col) * 4
	buffer.writeu8(buf, offset, color[1])
	buffer.writeu8(buf, offset + 1, color[2])
	buffer.writeu8(buf, offset + 2, color[3])
	buffer.writeu8(buf, offset + 3, 255)
end

function WorldMap.readPixel(buf: buffer, res: number, col: number, row: number): (number, number, number)
	local offset = (row * res + col) * 4
	return buffer.readu8(buf, offset), buffer.readu8(buf, offset + 1), buffer.readu8(buf, offset + 2)
end

-- Row cache: height and chasm weight per pixel, one Overworld.sampleAt each. A row's shading and contours read rows
-- up to two either side, so a sequential bake samples every pixel once. Bounded; random-order callers just refill it.
type Samples = { H: { number }, C: { number } }
local cacheRes, cacheRows, cacheCount = 0, {} :: { [number]: Samples }, 0

local function samplesAt(res: number, row: number): Samples
	if res ~= cacheRes or cacheCount > 64 then
		cacheRes, cacheRows, cacheCount = res, {}, 0
	end
	local hit = cacheRows[row]
	if hit then return hit end
	local f = Overworld.Frame
	local z = f.MinZ + (row + 0.5) / res * (f.MaxZ - f.MinZ)
	local H: { number }, C: { number } = table.create(res, 0), table.create(res, 0)
	for col = 0, res - 1 do
		local h, _, _, chasm = Overworld.sampleAt(f.MinX + (col + 0.5) / res * (f.MaxX - f.MinX), z)
		H[col + 1], C[col + 1] = h, chasm
	end
	local made = { H = H, C = C }
	cacheRows[row], cacheCount = made, cacheCount + 1
	return made
end

local function put(buf: buffer, offset: number, r: number, g: number, b: number)
	buffer.writeu8(buf, offset, math.clamp(math.floor(r + 0.5), 0, 255))
	buffer.writeu8(buf, offset + 1, math.clamp(math.floor(g + 0.5), 0, 255))
	buffer.writeu8(buf, offset + 2, math.clamp(math.floor(b + 0.5), 0, 255))
	buffer.writeu8(buf, offset + 3, 255)
end

-- Parchment-laid biome tint at (x, z) for ground height h. Weights come from Overworld.blendAt with no height filter (a
-- band filter flips a weight outright, which is a straight seam) and are averaged over a plus-shaped set of taps so the
-- ramp is about TINT_SPREAD * 2 + Blend studs wide: borders fade over a dozen pixels instead of six. Colour uses the pixel's
-- own h, so nothing steps.
local TINT_SPREAD = 90 -- studs
local TAPS = { { 0, 0 }, { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
function WorldMap.tintAt(x: number, z: number, h: number): (number, number, number)
	local mix: { [string]: number } = {}
	for _, tap in TAPS do
		for id, weight in Overworld.blendAt(x + tap[1] * TINT_SPREAD, z + tap[2] * TINT_SPREAD) do
			mix[id] = (mix[id] or 0) + weight / #TAPS
		end
	end
	local r, g, b = 0, 0, 0
	for id, weight in mix do
		local p = BIOME[id] or BIOME.Forest
		local t = math.clamp(h / p.Top, 0, 1) ^ p.Curve
		r += weight * (p.Low[1] + (p.High[1] - p.Low[1]) * t)
		g += weight * (p.Low[2] + (p.High[2] - p.Low[2]) * t)
		b += weight * (p.Low[3] + (p.High[3] - p.Low[3]) * t)
	end
	return r + (PARCHMENT[1] - r) * PARCHMENT_MIX, g + (PARCHMENT[2] - g) * PARCHMENT_MIX, b + (PARCHMENT[3] - b) * PARCHMENT_MIX
end

-- Paints one raster row: parchment biome tint, north-west hill shading from the height gradient, contour lines,
-- flat water with a coast outline. The Amberfall chasm floor lies below Frame.WaterY but is dry (OverworldTerrain
-- writes no water inside the chasm): it paints as umber, darker with depth, never as water. Roads and rivers are
-- strokes added afterwards by paintRoutes.
function WorldMap.paintRow(buf: buffer, res: number, row: number)
	local f = Overworld.Frame
	local cellX, cellZ = (f.MaxX - f.MinX) / res, (f.MaxZ - f.MinZ) / res
	local z = f.MinZ + (row + 0.5) * cellZ
	local here, north, south = samplesAt(res, row), samplesAt(res, math.max(row - 1, 0)), samplesAt(res, math.min(row + 1, res - 1))
	local ra, rb = math.max(row - 2, 0), math.min(row + 2, res - 1)
	local far0, far1 = samplesAt(res, ra), samplesAt(res, rb)
	local H, C = here.H, here.C
	local waterY = f.WaterY
	for col = 0, res - 1 do
		local i = col + 1
		local h, chasm = H[i], C[i]
		local r, g, b
		if h < waterY and chasm == 0 then
			local w, e = math.max(col - 1, 0) + 1, math.min(col + 1, res - 1) + 1
			local coast = (H[w] >= waterY or C[w] > 0) or (H[e] >= waterY or C[e] > 0)
				or (north.H[i] >= waterY or north.C[i] > 0) or (south.H[i] >= waterY or south.C[i] > 0)
			if coast then
				r, g, b = COAST[1], COAST[2], COAST[3]
			else
				local d = math.floor(math.clamp((waterY - h) / 20, 0, 1) * 4) / 4
				r, g, b = WATER_SHALLOW[1] + (WATER_DEEP[1] - WATER_SHALLOW[1]) * d, WATER_SHALLOW[2] + (WATER_DEEP[2] - WATER_SHALLOW[2]) * d,
					WATER_SHALLOW[3] + (WATER_DEEP[3] - WATER_SHALLOW[3]) * d
			end
		else
			local x = f.MinX + (col + 0.5) * cellX
			r, g, b = WorldMap.tintAt(x, z, h)
			r, g, b = r + (UMBER[1] - r) * 0.6 * chasm, g + (UMBER[2] - g) * 0.6 * chasm, b + (UMBER[3] - b) * 0.6 * chasm
			-- gradient over +-2 pixels (a wide baseline ignores the fine noise); light from the north-west
			local ca, cb = math.max(col - 2, 0), math.min(col + 2, res - 1)
			local gx = (H[cb + 1] - H[ca + 1]) / ((cb - ca) * cellX)
			local gz = (far1.H[i] - far0.H[i]) / ((rb - ra) * cellZ)
			local lit = math.clamp(-(gx + gz) * 0.7071 * LIGHT_GAIN, LIGHT_MIN, LIGHT_MAX)
			local shade = LIGHT_BASE * math.floor((1 + lit) * SHADE_STEPS + 0.5) / SHADE_STEPS * (1 - 0.3 * chasm)
			local contour = WorldMap.contourClass(h, H[math.min(col + 1, res - 1) + 1], south.H[i], math.sqrt(gx * gx + gz * gz))
			if contour > 0 then
				shade *= if contour == 2 then 0.72 else 0.86
			end
			r, g, b = r * shade, g * shade, b * shade
		end
		put(buf, (row * res + col) * 4, r, g, b)
	end
	if cacheRows[row - 3] then -- a sequential bake never looks back further than the +-2 rows it just used
		cacheRows[row - 3], cacheCount = nil, cacheCount - 1
	end
end

-- Strokes: `pad` widens the square brush on every side (used for the dark casing under a road).
local function line(buf: buffer, res: number, x0: number, y0: number, x1: number, y1: number, thick: number, color: { number }, pad: number?)
	local steps = math.max(1, math.ceil(math.max(math.abs(x1 - x0), math.abs(y1 - y0)) * 2))
	local p = pad or 0
	for i = 0, steps do
		local t = i / steps
		local cx, cy = math.floor(x0 + (x1 - x0) * t), math.floor(y0 + (y1 - y0) * t)
		for dy = -p, thick - 1 + p do
			for dx = -p, thick - 1 + p do
				WorldMap.pixel(buf, res, cx + dx, cy + dy, color)
			end
		end
	end
end

local function stroke(buf: buffer, res: number, points: { any }, thick: number, color: { number }, pad: number?)
	for k = 2, #points do
		local u0, v0 = Overworld.toMap(points[k - 1][1], points[k - 1][2])
		local u1, v1 = Overworld.toMap(points[k][1], points[k][2])
		line(buf, res, u0 * res, v0 * res, u1 * res, v1 * res, thick, color, pad)
	end
end

-- Draws the river channels (TerrainDef.Rivers) and the road centrelines (Overworld.terrainData) over the raster as
-- clean strokes: rivers first, then every road casing, then the cores (minor before main) so junctions merge and a
-- road crosses a river as a bridge.
function WorldMap.paintRoutes(buf: buffer, res: number)
	local C = WorldMap.Colors
	for _, river in Overworld.TerrainDef.Rivers do
		stroke(buf, res, river.Points, if river.Wet then 2 else 1, if river.Wet then C.River else C.RiverDry)
	end
	local roads = Overworld.terrainData().Roads
	for _, main in { false, true } do
		for _, road in roads do
			if (road.Kind == "main") == main then stroke(buf, res, road.Points, if main then 2 else 1, C.RoadCasing, 1) end
		end
	end
	for _, main in { false, true } do
		for _, road in roads do
			if (road.Kind == "main") == main then stroke(buf, res, road.Points, if main then 2 else 1, if main then C.RoadMain else C.RoadMinor) end
		end
	end
end

return table.freeze(WorldMap)
