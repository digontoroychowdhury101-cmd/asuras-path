--!strict
-- Vesperhold massing. Local +Z faces the approach; origin is the top of the gate threshold. Everything here is built from
-- src/shared/VesperholdLayout: solid cores and decks carry collision and the walk route, soot/charcoal stone only. Every
-- kit slot gets a plain-Part stand-in Model marked VespKitSlot / VespSlotId; when VesperholdKit has the piece (uploaded kit) the
-- mesh Model is placed at the same CFrame instead and the stand-in is not built (no registry = every stand-in stays).
local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath").Shared
local Overworld = require(Shared.Overworld)
local Layout = require(Shared.VesperholdLayout)
local Kit = require(script.Parent:WaitForChild("SanctuaryKit") :: ModuleScript)
local Props = require(script.Parent:WaitForChild("SanctuaryProps") :: ModuleScript)
local VespKit = require(script.Parent:WaitForChild("VesperholdKit") :: ModuleScript) :: any
local Citadel = {}

local V, C, A = Vector3.new, CFrame.new, CFrame.Angles
local rgb, M = Color3.fromRGB, Enum.Material
local soot, charcoal, wet, iron = rgb(31, 32, 35), rgb(52, 54, 59), rgb(42, 45, 50), rgb(36, 35, 36)
local crimson, ember, wax = rgb(92, 28, 36), rgb(214, 128, 64), rgb(78, 70, 60)
local decor = { Collide = false, Query = false }

local function section(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

local function part(p: Instance, name: string, cf: CFrame, w: number, h: number, d: number, color: Color3, material: Enum.Material?, solid: boolean?): BasePart
	return Kit.part(p, name, V(w, h, d), cf, color, material or M.Slate, if solid then nil else decor)
end

-- Solid masonry block in local coordinates.
local function core(p: Instance, name: string, origin: CFrame, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number): BasePart
	return part(p, name, origin * C((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), x1 - x0, y1 - y0, z1 - z0, charcoal, M.Slate, true)
end

-- Blind-arcade relief on a flat wall: a string course and a row of dark recesses per band. frame sits on the face, +Z outward.
local function blindBands(p: Instance, frame: CFrame, width: number, height: number)
	local rows = math.max(1, math.floor(height / 46))
	local rh = height / rows
	local n = math.max(1, math.floor(width / 16))
	for r = 0, rows - 1 do
		part(p, "StringCourse", frame * C(0, r * rh, 1), width + 2, 2.4, 3, soot)
		for i = 1, n do
			part(p, "BlindArch", frame * C((i - 0.5) / n * width - width / 2, r * rh + rh * 0.5, 0.35), width / n * 0.5, rh * 0.62, 0.7, iron)
		end
	end
end

-- Deck whose top surface runs exactly A -> B (as GothicMarch.deck), thickness t.
local function deck(p: Instance, name: string, a: Vector3, b: Vector3, width: number, t: number): BasePart
	return Kit.part(p, name, V(width, t, (a - b).Magnitude + 0.5), CFrame.lookAt((a + b) / 2, b) * C(0, -t / 2, 0), charcoal, M.Slate)
end

-- Wall-cladding pieces project outward from the slot (stand-in z = depth / 2); the flying buttress runs along X in the kit, along Z here.
local CLAD = { Arcade = true, Bastion = true, Balustrade = true, Lancet = true, Rose = true, Portal = true }

-- Kit mesh for one slot (same frame and per-axis scale as its stand-in). Returns false when the registry lacks the piece.
local function kitMesh(parent: Instance, s: { [string]: any }, origin: CFrame): boolean
	local d = Layout.Piece[s.Piece]
	local f = origin * C(s.X, s.Y, s.Z) * A(0, s.Yaw, 0)
	if s.Lean then f = f * A(s.Lean, 0, 0) end
	local offset = if CLAD[s.Group] then C(0, 0, d[3] * s.SZ / 2) elseif s.Group == "Flyer" then A(0, math.pi / 2, 0) else nil
	local scale = if s.Group == "Flyer" then V(s.SZ, s.SY, s.SX) else V(s.SX, s.SY, s.SZ) -- the offset turns the kit's X onto the layout's Z
	local m = VespKit.place(s.Piece, f, scale, { Group = s.Group, Seed = s.Id, Offset = offset })
	if not m then return false end
	m:SetAttribute("VespSlotId", s.Id)
	m:SetAttribute("VespGroup", s.Group)
	m.Parent = parent
	return true
end

local function standIn(parent: Instance, s: { [string]: any }, origin: CFrame)
	local d = Layout.Piece[s.Piece]
	local w, h, dp = d[1] * s.SX, d[2] * s.SY, d[3] * s.SZ
	local m = section(parent, s.Piece)
	m:SetAttribute("VespKitSlot", s.Piece)
	m:SetAttribute("VespSlotId", s.Id)
	m:SetAttribute("VespGroup", s.Group)
	local f = origin * C(s.X, s.Y, s.Z) * A(0, s.Yaw, 0)
	if s.Lean then f = f * A(s.Lean, 0, 0) end -- dead trees lean toward their yaw
	local g, piece = s.Group, s.Piece
	-- b: box centred (x, y, z) in the slot frame; wall-cladding pieces project outward (z = dp/2), the rest centre on the slot.
	local function b(name: string, x: number, y: number, z: number, sx: number, sy: number, sz: number, color: Color3?, mat: Enum.Material?): BasePart
		return part(m, name, f * C(x, y, z), sx, sy, sz, color or soot, mat)
	end
	local cz = if g == "Arcade" or g == "Bastion" or g == "Balustrade" or g == "Lancet" or g == "Rose" or g == "Portal" then dp / 2 else 0
	if g == "Arcade" then
		for _, k in { -1, 1 } do b("Pier", k * (w / 2 - 3.5), h / 2, cz, 7, h, dp, charcoal) end
		b("Spandrel", 0, h - 5, cz, w - 14, 10, dp, soot)
		b("Keystone", 0, h - 11, dp - 1, 6, 4, 2.4, charcoal)
		b("Recess", 0, (h - 10) / 2, 1, w - 14, h - 10, 2, iron)
	elseif g == "Bastion" then
		b("Battered", 0, h / 2, cz, w, h, dp, soot)
		for k = -1, 1 do b("BlindArch", k * 12, h * 0.35, dp + 0.2, 8, h * 0.5, 0.6, iron) end
		b("StringCourse", 0, h * 0.78, dp, w + 1, 3, 2.4, charcoal)
	elseif g == "Balustrade" then
		b("Plinth", 0, 1.5, cz, w, 3, 2.6, charcoal)
		b("Rail", 0, 6.5, cz, w, 3, 2, charcoal)
		for k = -1, 1 do b("Baluster", k * 7, 4, cz, 1.6, 2.5, 1.6, soot) end
	elseif g == "Flyer" then
		local a, c = V(0, 0, 0), V(0, h, -dp)
		for k, r in { { 0, 4 }, { -5, 3 } } do
			local lift = V(0, r[1], 0)
			part(m, "FlyingRib", CFrame.lookAt(f * ((a + c) / 2 + lift), f * (c + lift)), w, r[2], (c - a).Magnitude, if k == 1 then charcoal else soot)
		end
	elseif piece:find("^Spire") then
		if piece == "Spire_Needle_Tip" or piece == "Spire_Broken_Top" then
			for k, fr in { { 1, 0.5 }, { 0.6, 0.3 }, { 0.28, 0.2 } } do
				local y = if k == 1 then h * 0.25 elseif k == 2 then h * 0.65 else h * 0.9
				b("NeedleStep", 0, y, 0, w * fr[1], h * fr[2], dp * fr[1], if k == 2 then charcoal else soot)
			end
		else
			b("Stage", 0, h / 2, 0, w, h, dp, if piece == "Spire_Base_Oct" then soot else charcoal)
			b("StageCornice", 0, h - 1, 0, w * 1.12, 2, dp * 1.12, wet)
		end
	elseif g == "Pinnacle" or g == "Buttress" then
		b("Shaft", 0, h * 0.45, 0, w, h * 0.9, dp, charcoal)
		b("Cap", 0, h * 0.94, 0, w * 1.2, h * 0.12, dp * 1.2, soot)
		if g == "Pinnacle" then b("Finial", 0, h * 1.05, 0, w * 0.3, h * 0.2, dp * 0.3, soot) end
	elseif g == "Lancet" then
		b("Recess", 0, h / 2, cz, w, h, dp, iron)
		b("Pane", 0, h * 0.4, dp, w * 0.5, h * 0.6, 0.4, ember, M.Neon)
	elseif g == "Rose" then
		local function disc(name: string, dia: number, thick: number, z: number, color: Color3, mat: Enum.Material)
			local p = Kit.part(m, name, V(thick, dia, dia), f * C(0, h / 2, z) * A(0, math.pi / 2, 0), color, mat, { Collide = false, Query = false, Shape = Enum.PartType.Cylinder })
			return p
		end
		disc("Ring", w, 4, 2, charcoal, M.Slate)
		disc("Glass", w * 0.84, 1, 4.2, ember, M.Neon)
		for i = 0, 1 do b("Spoke", 0, h / 2, 4.8, w * 0.84, 1.4, 0.8, iron, M.Metal) end
		b("SpokeV", 0, h / 2, 4.9, 1.4, h * 0.84, 0.8, iron, M.Metal)
	elseif g == "Portal" then
		for _, k in { -1, 1 } do b("Jamb", k * (w / 2 - 8), h / 2, cz, 16, h, dp, charcoal) end
		b("Lintel", 0, h - 3, cz, w, 6, dp, soot)
		b("Archivolt", 0, h - 9, dp - 1, w - 16, 4, 2.4, charcoal)
	elseif g == "Statue" then
		if piece == "Statue_Plinth" then
			b("Plinth", 0, h / 2, 0, w, h, dp, charcoal)
		else
			b("Robe", 0, h * 0.35, 0, w, h * 0.7, dp, wet)
			b("Hood", 0, h * 0.85, 0, w * 0.65, h * 0.3, dp * 0.65, charcoal)
		end
	elseif g == "Candle" then
		b("Wax", 0, 0.9, 0, 0.6, 1.8, 0.6, wax)
		b("Flame", 0, 2.1, 0, 0.4, 0.6, 0.4, ember, M.Neon)
	elseif g == "Banner" then
		b("Pole", 0, 0, 1, w + 2, 0.5, 0.5, iron, M.Metal)
		b("Cloth", 0, -h / 2, 1, w, h, 0.2, crimson, M.Fabric)
	elseif g == "ViaductHigh" then
		for _, k in { -1, 1 } do b("Pier", k * (w / 2 - 2.5), h / 2, 0, 5, h, dp, charcoal) end
		b("Spandrel", 0, h - 8, 0, w - 5, 10, dp, soot)
		for _, k in { -1, 1 } do b("Haunch", k * (w / 2 - 7), h - 20, 0, 6, 14, dp * 0.9, charcoal) end
	elseif g == "Pedestal" then
		b("Plinth", 0, 2, 0, w, 4, dp, charcoal)
		b("Robe", 0, 4 + (h - 4) * 0.4, 0, w * 0.7, (h - 4) * 0.8, dp * 0.7, wet)
		b("Hood", 0, h - 2.2, 0, w * 0.5, 4, dp * 0.5, charcoal)
		b("Staff", w * 0.4, h * 0.55, dp * 0.3, 0.4, h * 0.9, 0.4, iron, M.Metal)
	elseif g == "Brazier" then
		b("Post", 0, h * 0.4, 0, 0.8, h * 0.8, 0.8, iron, M.Metal)
		b("Bowl", 0, h * 0.85, 0, w, 1.6, dp, iron, M.Metal)
		b("Flame", 0, h * 0.85 + 1.8, 0, w * 0.5, 2.4, dp * 0.5, ember, M.Neon)
	elseif g == "BannerPole" then
		b("Pole", 0, h / 2, 0, 0.6, h, 0.6, iron, M.Metal)
		b("Cloth", 0, h - 14, 0.6, 7, 24, 0.2, crimson, M.Fabric)
	elseif g == "Tree" then
		local bark = rgb(46, 40, 36)
		b("Trunk", 0, h * 0.45, 0, w * 0.16, h * 0.9, dp * 0.16, bark, M.Wood)
		for k = 1, 3 do
			b("Limb", (k - 2) * w * 0.18, h * (0.5 + 0.13 * k), 0, w * 0.5, h * 0.03, dp * 0.05, bark, M.Wood)
		end
	elseif g == "Arch" then
		for _, k in { -1, 1 } do b("Pier", k * (w / 2 - 4), h * 0.35, 0, 8, h * 0.7, dp, soot) end
		b("CrownLeft", -w / 4, h * 0.8, 0, w / 2 - 2, h * 0.3, dp, charcoal)
		b("CrownStub", w / 4 + 2, h * 0.76, 0, w / 5, h * 0.18, dp, soot)
	elseif g == "Grave" then
		b("Stone", 0, h / 2, 0, w, h, dp, charcoal)
	elseif g == "Fence" then
		b("Rails", 0, h * 0.6, 0, w, 0.5, dp, iron, M.Metal)
		b("Spikes", 0, h * 0.4, 0, w, h * 0.8, 0.3, iron, M.Metal)
	elseif g == "Gibbet" then
		b("Post", -w / 2, h / 2, 0, 0.6, h, 0.6, iron, M.Metal)
		b("Cage", 0, h * 0.4, 0, w * 0.6, h * 0.45, dp * 0.6, iron, M.Metal)
	elseif g == "Waterfall" then
		b("Sheet", 0, h / 2, dp / 2, w, h, dp, rgb(62, 72, 84), M.Glass).Transparency = 0.5
	elseif g == "Mist" then
		local a = Kit.part(m, "MistAnchor", V(1, 1, 1), f, soot, M.SmoothPlastic, decor)
		a.Transparency = 1
	end
end

local function massing(castle: Model, origin: CFrame, ground: (number, number) -> number)
	local m = section(castle, "Massing")
	local T, G = Layout.Tiers, Layout.Gate
	local T0, T1, T2, T3 = T.T0, T.T1, T.T2, T.T3
	local function low(x0: number, x1: number, z0: number, z1: number): number
		local lo = math.huge
		for i = 0, 4 do
			for j = 0, 2 do lo = math.min(lo, ground(x0 + (x1 - x0) * i / 4, z0 + (z1 - z0) * j / 2)) end
		end
		return lo - 8
	end
	local function ends(x: number, y0: number, y1: number, z0: number, z1: number)
		local sign = if x > 0 then 1 else -1
		blindBands(m, origin * C(x, y0, (z0 + z1) / 2) * A(0, sign * math.pi / 2, 0), z1 - z0, y1 - y0)
	end
	-- T0 bastions fall into the gorge; their top (road level) is also the gate apron and passage floor.
	for i = 1, 17 do
		local cx = (i - 9) * T0.Bay
		local base = low(cx - 20, cx + 20, T0.BackZ, T0.FrontZ)
		core(m, "BastionCore", origin, cx - 20, cx + 20, base, T0.Top, T0.BackZ, T0.FrontZ)
		if i == 1 or i == 17 then ends((if i == 1 then -1 else 1) * T0.X, base, T0.Top, T0.BackZ, T0.FrontZ) end
	end
	-- T1: the arcaded gate wall (passage cut through it), the close behind it, low parapets round the close.
	core(m, "T1WallWest", origin, -T1.X, -G.Half, 0, T1.Top, T1.BackZ, T1.FrontZ)
	core(m, "T1WallEast", origin, G.Half, T1.X, 0, T1.Top, T1.BackZ, T1.FrontZ)
	CollectionService:AddTag(core(m, "GateLintel", origin, -G.Half, G.Half, G.Lintel, T1.Top, T1.BackZ, T1.FrontZ), "AsuraShelter")
	core(m, "ClosePaving", origin, -T1.X, T1.X, 0, T1.FloorY, T1.CloseZ1, -68)
	for _, s in { -1, 1 } do
		core(m, "CloseParapet", origin, if s < 0 then -T1.X else T1.X - 3, if s < 0 then -T1.X + 3 else T1.X, T1.FloorY, T1.FloorY + 6, T1.CloseZ1, T1.CloseZ0)
		ends(s * T1.X, 0, T1.Top, T1.BackZ, T1.FrontZ)
	end
	-- T2 cloister terrace: its 178-stud front wall faces the close and carries the cloister ramp.
	local b2 = low(-T2.X, T2.X, T2.BackZ, T2.FrontZ)
	core(m, "T2Core", origin, -T2.X, T2.X, b2, T2.FloorY, T2.BackZ, T2.FrontZ)
	core(m, "T2Parapet", origin, -T2.X + 28, T2.X, T2.FloorY, T2.FloorY + 6, T2.FrontZ - 2, T2.FrontZ)
	blindBands(m, origin * C(0, T1.FloorY, T2.FrontZ), 2 * T2.X, T2.FloorY - T1.FloorY)
	for _, s in { -1, 1 } do ends(s * T2.X, math.max(b2, -30), T2.FloorY, T2.BackZ, T2.FrontZ) end
	-- T3 cathedral terrace: core, west front with the portal opening, tower feet, nave shell and vault.
	local b3 = low(-T3.X, T3.X, T3.BackZ, T3.FrontZ)
	core(m, "T3Core", origin, -T3.X, T3.X, b3, T3.FloorY, T3.BackZ, T3.FrontZ)
	blindBands(m, origin * C(0, T2.FloorY, T3.FrontZ), 2 * T3.X, T3.FloorY - T2.FloorY)
	for _, s in { -1, 1 } do ends(s * T3.X, math.max(b3, -30), T3.FloorY, T3.BackZ, T3.FrontZ) end
	blindBands(m, origin * C(0, math.max(b3, -30), T3.BackZ) * A(0, math.pi, 0), 2 * T3.X, T3.FloorY - math.max(b3, -30))
	local y0, y1, zf = T3.FloorY, T3.Top, T3.FrontZ - 12
	for _, s in { -1, 1 } do
		core(m, "WestFront", origin, if s < 0 then -90 else G.Half, if s < 0 then -G.Half else 90, y0, y1, zf, T3.FrontZ)
		core(m, "OuterFront", origin, if s < 0 then -T3.X else 150, if s < 0 then -150 else T3.X, y0, y1, zf, T3.FrontZ)
		core(m, "WestTowerFoot", origin, s * Layout.Tower.X - 30, s * Layout.Tower.X + 30, y0, Layout.Tower.BaseY, Layout.Tower.Z - 30, Layout.Tower.Z + 30)
		local nx0, nx1 = if s < 0 then -48 else 40, if s < 0 then -40 else 48
		if s < 0 then
			core(m, "NaveWall", origin, nx0, nx1, y0, y0 + 45, T3.BackZ + 8, zf)
		else -- east wall has a door onto the T3 roof terrace (the V3 spur)
			core(m, "NaveWall", origin, nx0, nx1, y0, y0 + 45, T3.BackZ + 8, Layout.NaveDoor.Z0)
			core(m, "NaveWall", origin, nx0, nx1, y0, y0 + 45, Layout.NaveDoor.Z1, zf)
		end
		local tilt = -s * math.atan2(25, 48)
		local vault = part(m, "NaveVault", origin * C(s * 24, y0 + 57.5, (T3.BackZ + 8 + zf) / 2) * A(0, 0, tilt),
			math.sqrt(48 ^ 2 + 25 ^ 2) + 1, 3, zf - T3.BackZ - 8, wet, M.Slate, true)
		CollectionService:AddTag(vault, "AsuraShelter")
	end
	core(m, "GatePortalLintel", origin, -G.Half, G.Half, y0 + G.Lintel, y1, zf, T3.FrontZ)
	core(m, "Apse", origin, -48, 48, y0, y1, T3.BackZ, T3.BackZ + 8)
	-- Nave furnishing: dais and votive table at the east end, braziers and benches down the hall.
	part(m, "Dais", origin * C(0, y0 + 2, -306), 30, 4, 16, wet, M.Slate, true)
	part(m, "VotiveTable", origin * C(0, y0 + 6, -312), 10, 4, 3.5, charcoal, M.Slate, true)
	for _, s in { -1, 1 } do
		Props.brazier(m, origin * C(s * 34, y0, -250), 40)
		Props.brazier(m, origin * C(s * 17, 0, 4), 21)
		for _, z in { -215, -240, -265, -290 } do Props.bench(m, origin * C(s * 22, y0, z)) end
	end
	-- Decks from the route data: gate apron, passage ramp, cloister ramp, landings, grand stair, alternates, spurs.
	local routes = section(castle, "WalkRoute")
	local function slabSeg(r: { [string]: any })
		local a, bb = origin * V(r.A[1], r.A[2], r.A[3]), origin * V(r.B[1], r.B[2], r.B[3])
		deck(routes, r.Name, a, bb, r.Slab, r.Thick)
		if r.Base then
			local n = math.max(1, math.ceil((a - bb).Magnitude / 36))
			for i = 0, n do
				local p = a:Lerp(bb, i / n)
				local top = p.Y - origin.Y - r.Thick
				if top - r.Base > 1 then
					part(routes, "RampPier", C(p.X, origin.Y + (top + r.Base) / 2, p.Z), 6, top - r.Base, 6, charcoal, M.Slate, true)
				end
			end
		end
	end
	local function spanSeg(r: { [string]: any })
		local a, bb = origin * V(r.A[1], r.A[2], r.A[3]), origin * V(r.B[1], r.B[2], r.B[3])
		local len = (a - bb).Magnitude
		deck(routes, r.Name, a, bb, r.Width, r.Thick)
		for _, s in { -1, 1 } do -- collidable parapets keep walkers on the deck
			local off = (bb - a).Unit:Cross(V(0, 1, 0)) * (s * (r.Width / 2 - 0.9)) + V(0, 1.7, 0)
			Kit.part(routes, r.Name .. "Parapet", V(1.8, 3.4, len), CFrame.lookAt((a + bb) / 2 + off, bb + off), soot, M.Slate)
		end
		local n = math.max(1, math.ceil(len / 30))
		for i = 0, n do -- masonry piers down to terrain (the Viaduct_Bay stand-ins are decor)
			local t = i / n
			local px, py, pz = r.A[1] + (r.B[1] - r.A[1]) * t, r.A[2] + (r.B[2] - r.A[2]) * t, r.A[3] + (r.B[3] - r.A[3]) * t
			local g = ground(px, pz) - 5
			if py - r.Thick - g > 2 then
				part(routes, "SpanPier", origin * C(px, (g + py - r.Thick) / 2, pz), 7, py - r.Thick - g, 7, charcoal, M.Slate, true)
			end
		end
	end
	for _, r in Layout.Route do
		if r.Kind == "slab" then slabSeg(r) end
	end
	for _, r in Layout.Alternates do
		if r.Kind == "slab" then slabSeg(r) end
	end
	for _, spur in Layout.Spurs do
		for _, r in spur.Segs do
			if r.Kind == "span" then spanSeg(r) end
		end
	end
	-- Grand stair: every tread a solid block from the T2 floor up, flat landings, decor cheek walls.
	local St = Layout.Stair
	for _, step in St.Steps do
		part(routes, "StairStep", origin * C(step.CX, (step.Top + St.Base) / 2, step.CZ) * A(0, St.Yaw, 0), St.Width, step.Top - St.Base, step.Len + 0.02, charcoal, M.Slate, true)
	end
	for _, l in St.Landings do
		part(routes, "StairLanding", origin * C(l.CX, (l.Top + St.Base) / 2, l.CZ) * A(0, St.Yaw, 0), St.Width, l.Top - St.Base, l.Len + 0.02, charcoal, M.Slate, true)
	end
	for _, s in { -1, 1 } do
		local off = V(-St.UZ, 0, St.UX) * (s * (St.Width / 2 + 1))
		local a, bb = origin * (V(St.S[1], St.S[2] + 2, St.S[3]) + off), origin * (V(St.B[1], St.B[2] + 2, St.B[3]) + off)
		part(routes, "StairCheek", CFrame.lookAt((a + bb) / 2, bb), 2, 4, (a - bb).Magnitude, soot)
	end
	-- Pinnacles P2/P3 (collidable rock courses), distant crags (decor), and the keep masonry.
	local rock = section(castle, "Rock")
	local function course(name: string, r: { [string]: number }, solid: boolean)
		for _, c in Layout.rock(r, ground) do
			part(rock, name, origin * C(c.CX, (c.Y0 + c.Y1) / 2, c.CZ) * A(0, c.Yaw, 0), 2 * c.HX, c.Y1 - c.Y0, 2 * c.HZ, wet, M.Slate, solid)
		end
	end
	for id, r in Layout.Pinnacles do course("Pinnacle" .. id, r, true) end
	for id, r in Layout.Crags do course("Crag" .. id, r, false) end
	for _, k in Layout.KeepCores do core(m, k[1], origin, k[2], k[3], k[4], k[5], k[6], k[7]) end
end

function Citadel.build(parent: Instance, origin: CFrame): Model
	local castle = Instance.new("Model")
	castle.Name = "Vesperhold"
	castle.WorldPivot = origin
	local function ground(x: number, z: number): number
		local w = origin * V(x, 0, z)
		return Overworld.surfaceAt(w.X, w.Z) - origin.Y
	end
	massing(castle, origin, ground)
	local stand = section(castle, "KitStandIns")
	local meshes = section(castle, "KitMeshes")
	for _, s in Layout.slots(ground) do
		if s.Group == "Viaduct" then
			kitMesh(meshes, s, origin) -- GothicMarch builds the stand-in bays (and skips them when the kit has Viaduct_Bay)
		elseif not kitMesh(meshes, s, origin) then
			standIn(stand, s, origin)
		end
	end
	castle.Parent = parent
	return castle
end

return table.freeze(Citadel)
