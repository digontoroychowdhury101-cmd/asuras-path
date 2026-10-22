--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/SanctuaryFrame
-- Timber-frame assemblies from the lobby kit: lacquered columns on carved stone bases, architraves,
-- bracket sets, hip-and-gable pavilions and covered galleries. Only the columns collide (one invisible
-- box each); beams, brackets and roofs are overhead and never stop a body or a camera.
local Kit = require(script.Parent:WaitForChild("SanctuaryKit") :: ModuleScript)

local Frame = {}

local BASE = 0.9 -- Column_Base height
local COLUMN = 10 -- Column_Lacquer authored height
local BRACKET = 2.79 -- Bracket_Set height
local HALL = Vector3.new(30, 7.5, 18) -- Roof_Hall eave footprint and rise as authored
local SQUARE = Vector3.new(14, 5.6, 14) -- Roof_Square
local GALLERY = Vector3.new(8.8, 1, 10) -- Roof_Gallery bay length, rise scale, eave depth
local Y = Vector3.yAxis
local M = Enum.Material

export type Options = { Lanterns: boolean?, Rise: number?, CapStart: boolean?, CapEnd: boolean?, Skip: { [number]: boolean }?, Xs: { number }?, Square: boolean?, Collide: boolean? }

-- `collide` false when a layout box already stands there (SanctuaryRoutes), for the offline suites.
function Frame.column(parent: Instance, foot: Vector3, height: number, collide: boolean?)
	if collide ~= false then
		Kit.part(parent, "ColumnCollision", Vector3.new(1.3, height, 1.3), CFrame.new(foot + Y * height * 0.5), Color3.new(), M.SmoothPlastic,
			{ Collide = true, Query = false, Transparency = 1, Shadow = false })
	end
	if Kit.place(parent, "Column_Base", CFrame.new(foot)) then
		Kit.place(parent, "Column_Lacquer", CFrame.new(foot + Y * BASE), Vector3.new(1, (height - BASE) / COLUMN, 1))
		return
	end
	Kit.slab(parent, "ColumnFoot", Vector3.new(2.1, 0.9, 2.1), CFrame.new(foot + Y * 0.45), "Stone", Kit.decor())
	Kit.slab(parent, "LacquerColumn", Vector3.new(1.2, height - 0.9, 1.2), CFrame.new(foot + Y * (height + 0.9) * 0.5), "Lacquer", Kit.decor())
end

-- Architrave between two column tops at the same height (its top is flush with them).
function Frame.beam(parent: Instance, a: Vector3, b: Vector3)
	local length = (Vector3.new(b.X, 0, b.Z) - Vector3.new(a.X, 0, a.Z)).Magnitude
	local cf = Kit.along(a, b) * CFrame.new(0, -2.02, 0)
	if not Kit.place(parent, "Beam_Architrave", cf, Vector3.new(length / 8, 1, 1)) then
		Kit.slab(parent, "Architrave", Vector3.new(length, 1.6, 0.8), cf * CFrame.new(0, 1.2, 0), "Timber", Kit.decor())
	end
end

function Frame.hanging(parent: Instance, hook: Vector3, range: number?)
	Kit.place(parent, "Lantern_Hanging", CFrame.new(hook))
	Kit.glow(parent, CFrame.new(hook - Y * 1.3), Vector3.new(0.95, 1.0, 0.95), range or 16)
end

-- Pavilion on `cf` (floor centre; X = width). Columns every <= 11 studs along the width.
function Frame.pavilion(parent: Instance, cf: CFrame, width: number, depth: number, height: number, options: Options?): Model?
	local o: Options = options or {}
	local bays = math.max(1, math.ceil(width / 11))
	local xs = o.Xs or {}
	if #xs == 0 then
		for i = 0, bays do
			table.insert(xs, -width / 2 + width * i / bays)
		end
	end
	local skip = o.Skip or {}
	for side = -1, 1, 2 do
		local tops = {}
		for i, x in xs do
			local foot = (cf * CFrame.new(x, 0, side * depth / 2)).Position
			if not skip[(side + 1) * 50 + i - 1] then
				Frame.column(parent, foot, height, o.Collide)
				Kit.place(parent, "Bracket_Set", CFrame.fromMatrix(foot + Y * height, cf.XVector, Y))
			end
			table.insert(tops, foot + Y * height)
		end
		for i = 1, #tops - 1 do
			Frame.beam(parent, tops[i], tops[i + 1])
		end
		local a = (cf * CFrame.new(side * width / 2, height, -depth / 2)).Position
		local b = (cf * CFrame.new(side * width / 2, height, depth / 2)).Position
		Frame.beam(parent, a, b)
	end
	local dims = if o.Square then SQUARE else HALL
	local scale = Vector3.new((width + 8) / dims.X, o.Rise or 1, (depth + 8) / dims.Z)
	local eave = if o.Square then height + 2.2 else height + 3.67 - 2.0 * scale.Y
	if o.Lanterns ~= false then
		Frame.hanging(parent, (cf * CFrame.new(0, height - 0.2, 0)).Position)
	end
	local roof = Kit.place(parent, if o.Square then "Roof_Square" else "Roof_Hall", cf * CFrame.new(0, eave, 0), scale)
	if not roof then
		Kit.slab(parent, "PavilionRoof", Vector3.new(width + 6, 1.2, depth + 6), cf * CFrame.new(0, height + 1.2, 0), "RoofTile", Kit.decor())
	end
	return roof
end

-- Covered gallery along floor points a -> b (centre line), columns both sides every ~7.5 studs.
function Frame.gallery(parent: Instance, a: Vector3, b: Vector3, width: number, height: number, options: Options?)
	local o: Options = options or {}
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local length = flat.Magnitude
	local dir = flat.Unit
	local side = dir:Cross(Y).Unit
	local n = math.max(1, math.round(length / 7.5))
	local step = length / n
	local skip = o.Skip or {}
	for s = -1, 1, 2 do
		local previous: Vector3? = nil
		for i = 0, n do
			local foot = a + dir * step * i + side * s * width / 2
			if not skip[(s + 1) * 50 + i] then
				Frame.column(parent, foot, height)
			end
			local top = foot + Y * height
			if previous then
				Frame.beam(parent, previous, top)
			end
			previous = top
		end
	end
	local scale = Vector3.new(step / GALLERY.X, 1, (width + 2.6) / GALLERY.Z)
	for i = 1, n do
		local mid = a + dir * step * (i - 0.5) + Y * (height + 0.2)
		if not Kit.place(parent, "Roof_Gallery", CFrame.fromMatrix(mid, dir, Y), scale) then
			Kit.slab(parent, "GalleryRoof", Vector3.new(step, 1, width + 2.6), CFrame.fromMatrix(mid + Y, dir, Y), "RoofTile", Kit.decor())
		end
		if o.Lanterns ~= false and i % 2 == 1 then
			Frame.hanging(parent, mid - Y * 0.5, 14)
		end
	end
	local capScale = Vector3.new(1, 1, scale.Z)
	if o.CapStart ~= false then
		Kit.place(parent, "Roof_GalleryEnd", CFrame.fromMatrix(a + Y * (height + 0.2), dir, Y), capScale)
	end
	if o.CapEnd ~= false then
		Kit.place(parent, "Roof_GalleryEnd", CFrame.fromMatrix(b + Y * (height + 0.2), -dir, Y), capScale)
	end
end

return table.freeze(Frame)
