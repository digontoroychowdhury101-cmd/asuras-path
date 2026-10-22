--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/RegionLayout
-- Construction vocabulary for the authored campaign regions (batches 16-21). Every walkable or
-- colliding piece of a region is an engine-free box (centre, size, yaw in degrees about +Y), so the
-- server builds exactly what the offline reachability suite (tools/test_campaign_regions.luau)
-- walks. Builders here only append boxes; materials and colours are chosen per Kind by the server.
local Layout = {}

export type Box = { Name: string, Kind: string, X: number, Y: number, Z: number, SX: number, SY: number, SZ: number, Yaw: number }
export type Return = { Name: string, X0: number, X1: number, Z0: number, Z1: number, Below: number, To: { X: number, Y: number, Z: number, Yaw: number } }
export type Zone = { Id: string, Name: string, X0: number, X1: number, Z0: number, Z1: number, Y0: number?, Y1: number? } -- Y band for stacked levels
export type Door = { A: string, B: string, X: number, Y: number, Z: number, Name: string, OneWay: boolean? } -- OneWay: A -> B only (a drop)
export type Mark = { Name: string, X: number, Y: number, Z: number, Yaw: number }
export type Region = {
	Region: string,
	Solids: { Box },
	Returns: { Return },
	Zones: { Zone },
	Doors: { Door },
	SpawnZones: { [string]: string },
	Marks: { [string]: Mark },
	Groves: { { number } }?, -- {x0, x1, z0, z1, floor, count}: decorative scatter strips (non-colliding)
	Lights: { { number } }, -- {x, y, z}: lantern heads the dressing lights (their posts are Solids)
}

-- Kinds the server renders; "Veil" is an invisible colliding boundary, "Decor" never collides.
Layout.Kinds = table.freeze({
	Path = true, Ground = true, Grass = true, Rock = true, Snow = true, Timber = true, Lacquer = true,
	Stone = true, Ash = true, Basalt = true, Crypt = true, Marble = true, Bone = true, Water = true, Veil = true, Tile = true,
} :: { [string]: boolean })

function Layout.region(id: string): Region
	return { Region = id, Solids = {}, Returns = {}, Zones = {}, Doors = {}, SpawnZones = {}, Marks = {}, Lights = {} }
end

function Layout.box(r: Region, name: string, kind: string, x: number, y: number, z: number, sx: number, sy: number, sz: number, yaw: number?): Box
	assert(Layout.Kinds[kind], "Unknown layout kind " .. kind)
	local b: Box = { Name = name, Kind = kind, X = x, Y = y, Z = z, SX = sx, SY = sy, SZ = sz, Yaw = yaw or 0 }
	table.insert(r.Solids, b)
	return b
end

-- Axis-aligned floor slab by extents, its top at `top`.
function Layout.slab(r: Region, name: string, kind: string, x0: number, x1: number, z0: number, z1: number, top: number, thick: number?): Box
	local t = thick or 4
	return Layout.box(r, name, kind, (x0 + x1) / 2, top - t / 2, (z0 + z1) / 2, math.abs(x1 - x0), t, math.abs(z1 - z0))
end

-- A straight run of solid steps from (ax, az) at height y0 to (bx, bz) at height y1; every step
-- reaches down to the lower floor so nothing can be walked under or fallen through.
function Layout.stairs(r: Region, name: string, kind: string, ax: number, az: number, bx: number, bz: number, y0: number, y1: number, width: number, rise: number?)
	local h = rise or 1
	local count = math.max(1, math.floor(math.abs(y1 - y0) / h + 0.5))
	local dx, dz = (bx - ax) / count, (bz - az) / count
	local yaw = math.deg(math.atan2(-dx, -dz))
	local run = math.sqrt(dx * dx + dz * dz)
	local low, step = math.min(y0, y1), (y1 - y0) / count
	for i = 1, count do
		local top = y0 + step * i
		local height = top - low + 2
		Layout.box(r, name, kind, ax + dx * (i - 0.5), top - height / 2, az + dz * (i - 0.5), width, height, run + 0.05, yaw)
	end
end

-- A wall segment from (ax, az) to (bx, bz), standing on `base`.
function Layout.wall(r: Region, name: string, kind: string, ax: number, az: number, bx: number, bz: number, base: number, height: number, thick: number?): Box
	local dx, dz = bx - ax, bz - az
	return Layout.box(r, name, kind, (ax + bx) / 2, base + height / 2, (az + bz) / 2, thick or 2, height, math.sqrt(dx * dx + dz * dz), math.deg(math.atan2(-dx, -dz)))
end

-- A closed or open polyline of walls (e.g. an invisible boundary veil around a region).
function Layout.fence(r: Region, name: string, kind: string, points: { { number } }, base: number, height: number, thick: number?)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		Layout.wall(r, name, kind, a[1], a[2], b[1], b[2], base, height, thick)
	end
end

-- A standing stone lantern on `floor`: its post is solid (walked around), its head is lit decor.
function Layout.lantern(r: Region, x: number, floor: number, z: number)
	Layout.box(r, "LanternPost", "Stone", x, floor + 1.6, z, 1.4, 3.2, 1.4)
	table.insert(r.Lights, { x, floor + 3.9, z })
end

-- A hanging lantern (beams, galleries): light only, nothing to collide with.
function Layout.light(r: Region, x: number, y: number, z: number)
	table.insert(r.Lights, { x, y, z })
end

function Layout.mark(r: Region, key: string, name: string, x: number, y: number, z: number, yaw: number?)
	r.Marks[key] = { Name = name, X = x, Y = y, Z = z, Yaw = yaw or 0 }
end

function Layout.zone(r: Region, id: string, name: string, x0: number, x1: number, z0: number, z1: number, y0: number?, y1: number?)
	table.insert(r.Zones, { Id = id, Name = name, X0 = math.min(x0, x1), X1 = math.max(x0, x1), Z0 = math.max(z0, z1), Z1 = math.min(z0, z1), Y0 = y0, Y1 = y1 })
end

function Layout.door(r: Region, a: string, b: string, x: number, y: number, z: number, name: string, oneWay: boolean?)
	table.insert(r.Doors, { A = a, B = b, X = x, Y = y, Z = z, Name = name, OneWay = oneWay })
end

-- Falling below `below` inside the rectangle returns the body to `to` (Characters.Teleport).
function Layout.catch(r: Region, name: string, x0: number, x1: number, z0: number, z1: number, below: number, to: { number })
	table.insert(r.Returns, { Name = name, X0 = math.min(x0, x1), X1 = math.max(x0, x1), Z0 = math.max(z0, z1), Z1 = math.min(z0, z1), Below = below,
		To = { X = to[1], Y = to[2], Z = to[3], Yaw = to[4] or 0 } })
end

-- Pure: the return that holds this root position, if any.
function Layout.returnFor(region: Region, x: number, y: number, z: number): Return?
	for _, r in region.Returns do
		if x >= r.X0 and x <= r.X1 and z <= r.Z0 and z >= r.Z1 and y < r.Below then
			return r
		end
	end
	return nil
end

-- Pure: is a point inside a box (yaw-only rotation)?
function Layout.inside(b: Box, x: number, y: number, z: number, margin: number?): boolean
	local m = margin or 0
	local lx, lz = x - b.X, z - b.Z
	local a = math.rad(b.Yaw)
	local c, s = math.cos(a), math.sin(a)
	local ux, uz = lx * c - lz * s, lx * s + lz * c
	return math.abs(ux) <= b.SX / 2 + m and math.abs(y - b.Y) <= b.SY / 2 + m and math.abs(uz) <= b.SZ / 2 + m
end

function Layout.freeze(r: Region): Region
	local function deep(t: any)
		if type(t) == "table" and not table.isfrozen(t) then
			for _, v in t do deep(v) end
			table.freeze(t)
		end
	end
	deep(r)
	return r
end

return table.freeze(Layout)
