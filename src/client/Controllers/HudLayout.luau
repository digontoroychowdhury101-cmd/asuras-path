--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/HudLayout
-- Reserved HUD regions (authored at the 900 px reference height, scaled like HudKit.bindScale) so
-- panels can be checked for overlap at any viewport. The controls reference lives in its own
-- centre band between the top strip and the action bar; its pill sits in the left utility column
-- with the Codex button, never in the bottom-centre combat row.
local Layout = {}

Layout.ReferenceHeight, Layout.MinFactor, Layout.MaxFactor = 900, 0.7, 1.35 -- mirrors HudKit.factor
Layout.ActionBarBottom = 16
Layout.ActionBarSize, Layout.ActionBarBase = { 496, 52 }, 0.88
Layout.ActionBarMinScale = 0.84
Layout.SpellSize, Layout.SpellBase = { 306, 112 }, 0.85
Layout.Margin = 12

export type Rect = { X: number, Y: number, W: number, H: number }
-- Anchor/At: scale terms; Offset: pixels; Size: authored pixels; Base: UIScale base (0 = unscaled).
-- WidthScale/MinWidth/MaxWidth model size-constrained strips (compass, boss bar).
export type Region = {
	Anchor: { number }, At: { number }, Offset: { number }, Size: { number }, Base: number,
	WidthScale: number?, MinWidth: number?, MaxWidth: number?,
	MinScale: number?, -- desktop floor on Base * factor (survival plates)
}
local function region(anchor: { number }, at: { number }, offset: { number }, size: { number }, base: number): Region
	return { Anchor = anchor, At = at, Offset = offset, Size = size, Base = base }
end

Layout.Regions = {
	ActionBar = region({ 0.5, 1 }, { 0.5, 1 }, { 0, -Layout.ActionBarBottom }, Layout.ActionBarSize, Layout.ActionBarBase),
	Vitals = region({ 0.5, 1 }, { 0.5, 1 }, { 0, 0 }, { 480, 118 }, 0.88),
	Spells = region({ 1, 1 }, { 1, 1 }, { -24, -24 }, Layout.SpellSize, Layout.SpellBase),
	Minimap = region({ 0, 0 }, { 0, 0 }, { 20, 66 }, { 190, 190 }, 0.82),
	Objective = region({ 1, 0 }, { 1, 0 }, { -20, 64 }, { 360, 98 }, 0.8),
	Codex = region({ 0, 0 }, { 0, 0.55 }, { 14, 0 }, { 92, 30 }, 0),
	ControlsPill = region({ 0, 0 }, { 0, 0.55 }, { 14, -40 }, { 150, 30 }, 0.85),
	-- The training card (unscaled, grows with its text): right column, below the objective and above
	-- the spell slots. F08: in the left column it covered the Codex button and the Controls pill.
	Training = region({ 1, 0 }, { 1, 0 }, { -20, 172 }, { 360, 170 }, 0),
}
-- Health, flask, essence and weapon stay at least ~12 px on a 1096x604 window (F03 Studio view).
Layout.Regions.Vitals.MinScale = 0.66
Layout.Regions.ActionBar.MinScale = Layout.ActionBarMinScale
Layout.Regions.Compass ={ Anchor = { 0.5, 0 }, At = { 0.5, 0 }, Offset = { 0, 8 }, Size = { 520, 60 }, Base = 0, WidthScale = 0.36, MinWidth = 240, MaxWidth = 520 }
Layout.Regions.Boss = { Anchor = { 0.5, 0 }, At = { 0.5, 0 }, Offset = { 0, 74 }, Size = { 900, 148 }, Base = 0, WidthScale = 0.5, MinWidth = 300, MaxWidth = 900 }

-- The general toast (InterfaceController): centred above the action bar, as wide as the band left
-- between two side columns (the training card is 360 wide at 20 from the edge), wrapping to two lines.
Layout.Toast = { Bottom = 200, Side = 400, Height = 48, MaxWidth = 640 }
function Layout.toastRect(width: number, height: number): Rect
	local t = Layout.Toast
	local available = math.max(0, width - 2 * Layout.Margin)
	local compact = math.min(264, available)
	local w = math.clamp(width - 2 * t.Side, compact, t.MaxWidth)
	return { X = (width - w) / 2, Y = height - Layout.toastBottom(height) - t.Height, W = w, H = t.Height }
end

-- Post-F26 step 6: a centre warning banner outranks the toast. While one is up, the toast's slot
-- steps down to just under the banner's text (screen pixels; 0 when the two already clear).
function Layout.toastShift(slotTop: number, bannerBottom: number?): number
	return if bannerBottom then math.max(0, bannerBottom + 6 - slotTop) else 0
end

function Layout.factor(height: number): number
	if height <= 1 then return 1 end
	return math.clamp(height / Layout.ReferenceHeight, Layout.MinFactor, Layout.MaxFactor)
end

function Layout.vitalsBottom(height: number): number
	local scale = math.max(Layout.ActionBarBase * Layout.factor(height), Layout.ActionBarMinScale)
	return Layout.ActionBarBottom + Layout.ActionBarSize[2] * scale + 10
end

function Layout.toastBottom(height: number): number
	local r = Layout.Regions.Vitals
	return math.max(Layout.Toast.Bottom, Layout.vitalsBottom(height) + r.Size[2] * math.max(r.Base * Layout.factor(height), r.MinScale or 0) + 8)
end

-- On-screen rectangle of a region (UIScale scales about the anchor point).
function Layout.rect(name: string, width: number, height: number): Rect
	local r = (Layout.Regions :: any)[name] :: Region
	local scale = if r.Base > 0 then math.max(r.Base * Layout.factor(height), r.MinScale or 0) else 1
	local w = r.Size[1] * scale
	if r.WidthScale then w = math.clamp(width * r.WidthScale, r.MinWidth or 0, r.MaxWidth or math.huge) end
	local h = r.Size[2] * scale
	local x = width * r.At[1] + r.Offset[1] - w * r.Anchor[1]
	local offsetY = if name == "Vitals" then -Layout.vitalsBottom(height) else r.Offset[2]
	local y = height * r.At[2] + offsetY - h * r.Anchor[2]
	return { X = x, Y = y, W = w, H = h }
end

function Layout.overlaps(a: Rect, b: Rect): boolean
	return a.X < b.X + b.W and b.X < a.X + a.W and a.Y < b.Y + b.H and b.Y < a.Y + a.H
end

-- The controls reference: centred in the band below the compass and above the action bar,
-- clear of the minimap and objective columns. Returns its UIScale and on-screen rect. On touch it
-- is a full-screen modal over its backdrop (the HUD columns would leave it unreadably small).
function Layout.modal(width: number, height: number, cardW: number, cardH: number, touch: boolean?): (number, Rect)
	local m = Layout.Margin
	if touch then
		local scale = math.max(math.min(Layout.factor(height), (width - 2 * m) / cardW, (height - 2 * m) / cardH), 0.5)
		return scale, { X = (width - cardW * scale) / 2, Y = (height - cardH * scale) / 2, W = cardW * scale, H = cardH * scale }
	end
	local top = Layout.rect("Compass", width, height)
	local plate = Layout.rect("Vitals", width, height)
	local map = Layout.rect("Minimap", width, height)
	local objective = Layout.rect("Objective", width, height)
	local side = math.max(map.X + map.W, width - objective.X) + m
	local bandTop, bandBottom = top.Y + top.H + m, plate.Y - m
	local scale = math.min(Layout.factor(height), (width - 2 * side) / cardW, (bandBottom - bandTop) / cardH)
	scale = math.max(scale, 0.5)
	local w, h = cardW * scale, cardH * scale
	return scale, { X = (width - w) / 2, Y = bandTop + (bandBottom - bandTop - h) / 2, W = w, H = h }
end

-- Touch profile (batch 25): phones and tablets in landscape, measured inside the device safe area.
-- The bottom-left square is the thumbstick's and holds nothing; the combat buttons own the
-- bottom-right; the action bar is hidden (the buttons are the action bar). Vitals take the
-- freed bottom centre, the spell slots the top-right corner above the buttons, the objective
-- sits beside the minimap (whose blossom buttons carry Respite, controls and the Codex), and the
-- target plate and boss bar fill the top band between the minimap and the right-hand column.
Layout.Touch = { Cluster = { 340, 360 }, Thumb = 0.42, VitalsBase = 1.06, MinTarget = 240, MinBoss = 240, BossHeight = 110 }
function Layout.touch(width: number, height: number): { [string]: Rect }
	local f, m, t = Layout.factor(height), Layout.Margin, Layout.Touch
	local map = Layout.rect("Minimap", width, height)
	local cluster = { X = width - t.Cluster[1] * f, Y = height - t.Cluster[2] * f, W = t.Cluster[1] * f, H = t.Cluster[2] * f }
	local thumb = { X = 0, Y = height - height * t.Thumb, W = height * t.Thumb, H = height * t.Thumb }
	local left, right = thumb.W + m, cluster.X - m
	local vitalsSize = Layout.Regions.Vitals.Size
	local vs = math.min(t.VitalsBase * f, math.max(0, right - left) / vitalsSize[1])
	local vw, vh = vitalsSize[1] * vs, vitalsSize[2] * vs
	local vitals = { X = left + math.max(0, (right - left - vw) / 2), Y = height - m - vh, W = vw, H = vh }
	local sw, sh = Layout.SpellSize[1] * Layout.SpellBase * f, Layout.SpellSize[2] * Layout.SpellBase * f
	local spells = { X = width - 16 - sw, Y = math.max(2, cluster.Y - sh - 2), W = sw, H = sh }
	local objectiveSize = Layout.Regions.Objective.Size
	local ow, oh = objectiveSize[1] * 0.8 * f, objectiveSize[2] * 0.8 * f
	local objective = { X = map.X + map.W + m, Y = 72, W = ow, H = oh }
	local spanL, spanR = map.X + map.W + m, math.min(cluster.X, spells.X) - m
	local tw = math.clamp(math.min(width * 0.4, spanR - spanL), t.MinTarget, 520)
	local target = { X = spanL + math.max(0, (spanR - spanL - tw) / 2), Y = objective.Y + objective.H + 8, W = tw, H = 52 }
	local bw = math.clamp(math.min(width * 0.5, spanR - spanL), t.MinBoss, 900)
	local boss = { X = spanL + math.max(0, (spanR - spanL - bw) / 2), Y = 74, W = bw, H = t.BossHeight }
	-- Warnings sit between the thumb and the buttons, midway between the top band and the vitals.
	local cw = math.min(520, right - left)
	local cy = (target.Y + target.H + vitals.Y) / 2 - 24
	return { Minimap = map, Compass = Layout.rect("Compass", width, height), Cluster = cluster, Thumb = thumb, Vitals = vitals,
		Spells = spells, Objective = objective, Target = target, Boss = boss,
		Callout = { X = left + (right - left - cw) / 2, Y = cy, W = cw, H = 48 } }
end

return table.freeze(Layout)
