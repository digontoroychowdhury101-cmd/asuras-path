--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/ColosseumDressing
-- Ash Colosseum silhouettes and storytelling (batch 18; AR01 The Ashen Covenant, 2026-11-07). All decor:
-- champion statues on the road's plinths, the order's spears and shields in the hall, and - from the
-- Covenant kit (tools/blender/covenant_kit.py -> ServerStorage.AsuraCovenantKit) - the blind-arcaded
-- facade, the Champions' low arcade at the fog gate, radial seating fronts over the side cavea, shattered
-- arcades on its crown, Victor's gate, ash banks, silver reeds, votive figures, buried weapons and, on the
-- far horizon, the split cenotaph and ruined bridges over cloud. Collision lives in AshColosseumLayout:
-- dressed layout boxes stay as invisible colliders (Decor.dressBoxes); if the kit is missing they stay visible.
local Kit = require(script.Parent:WaitForChild("MonasteryKit") :: ModuleScript)
local Decor = require(script.Parent:WaitForChild("RegionDecor") :: ModuleScript)
local Pbr = require(script.Parent:WaitForChild("PbrAssets") :: ModuleScript)

local Dressing = {}
local P = Kit.Palette
local M = Enum.Material
local rgb = Color3.fromRGB
local ASH = rgb(92, 88, 86)
local KIT = "AsuraCovenantKit"

-- Bowl geometry, mirrored from AshColosseumLayout (one source of truth for the numbers is that file and
-- WorldDefinitions; these are the dressing's anchors on it).
local AX, AN, AS = 120, -1895, -2085 -- arena floor half-width, north and south edges
local TIER_FRONT, TIER_N, TIER_S = 136, -1879, -2100 -- side cavea front and its north/south ends
local CREST = 172 -- the crown (tier 5) centre line, top y 20
local FACADE_Z, FACADE_X0, FACADE_X1 = -1877, 15, 184
local VG = -2104 -- Victor's gate line
local BAYS = 11
local BAY = (TIER_N - TIER_S) / BAYS -- 20.09: seat-front and crown-arcade bays share one rhythm

local function at(x: number, y: number, z: number, dx: number, dz: number): CFrame
	return CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(x + dx, y, z + dz))
end

local function covenant(parent: Instance, piece: string, foot: CFrame, scale: number?): Model?
	return Decor.han(parent, KIT, piece, foot, scale)
end

-- A kit clone fitted so its widest plan span is `span`, centred on `cf` (lobby clouds have arbitrary pivots).
local function fitted(parent: Instance, kit: string, piece: string, cf: CFrame, span: number): Model?
	local m = Decor.han(parent, kit, piece, CFrame.identity, 1)
	if not m then
		return nil
	end
	local box, size = m:GetBoundingBox()
	m.WorldPivot = box
	m:ScaleTo(span / math.max(size.X, size.Z, 0.01))
	m:PivotTo(cf)
	return m
end

local function statue(parent: Instance, base: CFrame)
	if Pbr.place(parent, "AsuraColossusStatue", base, 11, "Y") then
		return
	end
	Kit.part(parent, "ChampionRobe", Vector3.new(3.4, 7, 2.6), base * CFrame.new(0, 3.5, 0), P.Stone, M.Slate, Kit.decor())
	Kit.part(parent, "ChampionShoulders", Vector3.new(4.6, 1.4, 2.4), base * CFrame.new(0, 7.4, 0), P.Stone, M.Slate, Kit.decor())
	Kit.part(parent, "ChampionHead", Vector3.new(1.6, 1.8, 1.6), base * CFrame.new(0, 9, 0), P.StoneDark, M.Slate, Kit.decor())
	Kit.beam(parent, "ChampionJian", (base * CFrame.new(0.6, 1, -1.4)).Position, (base * CFrame.new(0.6, 8, -1.4)).Position, 0.3, P.StoneDark, M.Slate)
end

-- The approach: road champions, the hall's last stand (unchanged from batch 18).
local function approach(set: Instance, rng: Random)
	statue(set, CFrame.new(-20, 4, -1694) * CFrame.Angles(0, math.rad(200), 0))
	Kit.part(set, "FallenChampion", Vector3.new(8, 3, 3), CFrame.new(24, 1.4, -1702) * CFrame.Angles(0, math.rad(30), math.rad(8)), P.Stone, M.Slate, Kit.decor())
	for _, spot in { { -22, 0, -1828 }, { 22, 0, -1806 } } do
		Decor.brazier(set, CFrame.new(spot[1], spot[2], spot[3]))
	end
	for k = 0, 3 do
		Kit.beam(set, "FallenRafter", Vector3.new(-34, 12 + k * 0.6, -1716 - k * 13), Vector3.new(30 - k * 6, 10.5 - k, -1722 - k * 12), 1.2, P.WoodDark, M.Wood)
	end
	for _ = 1, 18 do
		local x, z = rng:NextNumber(-48, 48), rng:NextNumber(-1782, -1874)
		if math.abs(x) > 10 then
			local tip = Vector3.new(x + rng:NextNumber(-1, 1), rng:NextNumber(4, 6), z + rng:NextNumber(-1, 1))
			Kit.beam(set, "FallenSpear", Vector3.new(x, -0.4, z), tip, 0.2, P.WoodDark, M.Wood)
		end
	end
	for _ = 1, 8 do
		Kit.part(set, "DiscardedShield", Vector3.new(0.4, 3, 3), CFrame.new(rng:NextNumber(-46, 46), 0.1, rng:NextNumber(-1782, -1874))
			* CFrame.Angles(math.rad(rng:NextNumber(-10, 10)), rng:NextNumber(0, math.pi), math.rad(90)), rgb(70, 52, 40), M.Metal,
			{ Collide = false, Query = false, Shadow = true, Shape = Enum.PartType.Cylinder })
	end
end

-- The bowl's built edge. Returns which layout box names the kit now dresses.
local function bowl(set: Instance, rng: Random): { [string]: boolean }
	local dressed: { [string]: boolean } = {}
	local fit = BAY / 20 -- authored bay length 20
	-- Seating fronts over all five side tiers, and a shattered arcade along the crown with gaps in its run.
	local crown = { { 1, 0, 2, 1, 1, 0, 2, 1, 0, 1, 2 }, { 2, 1, 1, 0, 1, 2, 1, 0, 1, 1, 2 } }
	for i, side in { -1, 1 } do
		local cx = side * (TIER_FRONT + 20)
		for k = 0, BAYS - 1 do
			local z = TIER_N - BAY * (k + 0.5)
			local piece = if (k + i) % 3 == 0 then "Covenant_SeatFront_B" else "Covenant_SeatFront_A"
			dressed.Tier = covenant(set, piece, at(cx, 0, z, -side, 0), fit) ~= nil or dressed.Tier
			local kind = crown[i][k + 1]
			if kind > 0 then
				covenant(set, if kind == 2 then "Covenant_ArcadeBay_Broken" else "Covenant_ArcadeBay", at(side * CREST, 20, z, -side, 0), fit)
			end
		end
	end
	-- The facade's blind arcade on both faces, eight bays a side; the Champions' low arcade over the fog gate.
	local span = (FACADE_X1 - FACADE_X0) / 8
	for _, side in { -1, 1 } do
		for k = 0, 7 do
			dressed.Facade = covenant(set, "Covenant_FacadeBay", at(side * (FACADE_X0 + span * (k + 0.5)), 0, FACADE_Z, 0, -1), span / 21.125) ~= nil
				or dressed.Facade
		end
	end
	dressed.GateTower = covenant(set, "Covenant_ChampionGate", at(0, 0, -1874, 0, -1)) ~= nil
	-- Victor's gate faces the arena it is won from.
	dressed.VictorJamb = covenant(set, "Covenant_VictorGate", at(0, 0, VG, 0, 1)) ~= nil
	if not dressed.VictorJamb then
		Kit.part(set, "VictorLintel", Vector3.new(38, 2.4, 4), CFrame.new(0, 21, VG), P.StoneDark, M.Slate, Kit.decor())
	end
	-- Ash banks in the side camera bands and along the south bank (decor only: the camera never meets them).
	for _, side in { -1, 1 } do
		for z = AN - 22, AS + 10, -34 do
			covenant(set, "Covenant_AshBank", at(side * (AX + 9.5), 0, z + rng:NextNumber(-6, 6), -side, 0) * CFrame.new(0, -0.6, 0),
				rng:NextNumber(0.8, 1.05))
		end
		for x = 34, 166, 32 do
			covenant(set, "Covenant_AshBank", at(side * (x + rng:NextNumber(-4, 4)), 0, -2096, 0, 1) * CFrame.new(0, -0.5, 0), rng:NextNumber(0.75, 1.0))
		end
	end
	return dressed
end

-- Votive figures, silver reeds and the order's buried weapons on the ash banks; ember-light at the gates.
local function banks(set: Instance, rng: Random)
	for _, side in { -1, 1 } do
		-- A row of worn votive figures kneeling toward the arena along the south bank, some sunk or missing.
		for x = 30, 170, 14 do
			if rng:NextNumber() > 0.18 then
				local sink = if rng:NextNumber() < 0.3 then -rng:NextNumber(0.4, 1.4) else 0
				covenant(set, "Covenant_VotiveFigure", at(side * x, sink, -2093 + rng:NextNumber(-1.5, 1.5), rng:NextNumber(-0.3, 0.3), 1)
					* CFrame.Angles(math.rad(rng:NextNumber(-6, 6)), 0, math.rad(rng:NextNumber(-8, 8))), rng:NextNumber(1.05, 1.3))
			end
		end
		for _ = 1, 7 do
			covenant(set, "Covenant_ReedClump", at(side * rng:NextNumber(24, 176), 0, rng:NextNumber(-2090, -2102), 0, 1)
				* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), rng:NextNumber(0.8, 1.25))
		end
		for _ = 1, 6 do
			covenant(set, "Covenant_ReedClump", at(side * (AX + rng:NextNumber(5, 14)), 0, rng:NextNumber(AS + 6, AN - 6), 0, 1)
				* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), rng:NextNumber(0.7, 1.1))
		end
		for _ = 1, 5 do
			covenant(set, "Covenant_WeaponFragments", at(side * (AX + rng:NextNumber(4, 12)), 0, rng:NextNumber(AS + 8, AN - 8), 0, 1)
				* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), rng:NextNumber(0.85, 1.15))
		end
		for _ = 1, 3 do
			covenant(set, "Covenant_WeaponFragments", at(side * rng:NextNumber(26, 170), 0, rng:NextNumber(-2091, -2101), 0, 1)
				* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), rng:NextNumber(0.9, 1.2))
		end
		-- Two figures keep watch from crown gaps, small against the sky.
		covenant(set, "Covenant_VotiveFigure", at(side * CREST, 20, TIER_N - BAY * (if side < 0 then 1.5 else 3.5), -side, 0), 1.6)
	end
	-- H01 (Shattered Votive Idol, ~11 studs) is a creator hero asset not yet supplied: a labelled slot,
	-- nothing visible, where it will stand at the head of the south bank's votive row.
	local slot = Instance.new("Part")
	slot.Name, slot.Size, slot.CFrame = "H01_PendingHeroSlot", Vector3.new(4, 11, 4), at(-24, 5.5, -2094, 0, 1)
	slot.Anchored, slot.CanCollide, slot.CanQuery, slot.CanTouch, slot.Transparency, slot.CastShadow = true, false, false, false, 1, false
	slot:SetAttribute("AsuraPendingAsset", "H01 Shattered Votive Idol (creator hero asset; not supplied in this checkout)")
	slot.Parent = set
	-- Tiny ember warmth: braziers on the first seat row and flanking Victor's gate; banners on the facade.
	for _, spot in { { -140, 4.5, -1930 }, { 140, 4.5, -1930 }, { -140, 4.5, -2050 }, { 140, 4.5, -2050 }, { -24, 0, -2099 }, { 24, 0, -2099 } } do
		Decor.brazier(set, CFrame.new(spot[1], spot[2], spot[3]), 20)
	end
	local span = (FACADE_X1 - FACADE_X0) / 8
	for _, k in { 1, 3, 5 } do
		for _, side in { -1, 1 } do
			Decor.banner(set, CFrame.new(side * (FACADE_X0 + span * k), 20.2, FACADE_Z - 2.6), rng:NextNumber(9, 13), if k == 3 and side > 0 then rgb(52, 22, 22) else rgb(58, 40, 36))
		end
	end
	-- Shallow, noncolliding wear on the floor: ash drifts, mostly toward the edges.
	for _ = 1, 22 do
		local x = rng:NextNumber(-AX + 4, AX - 4)
		x = if math.abs(x) < 50 then x * 2 else x
		Kit.part(set, "AshDrift", Vector3.new(rng:NextNumber(8, 20), 0.3, rng:NextNumber(6, 14)), CFrame.new(math.clamp(x, -AX + 4, AX - 4), 0.05, rng:NextNumber(AS + 4, AN - 4))
			* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), ASH, M.Sand, Kit.decor())
	end
end

-- The far side's long view south: the split cenotaph left of the Pagoda, ruined bridges to the right, cloud.
local function horizon(set: Instance, rng: Random)
	local far = Kit.folder("CovenantHorizon", set)
	covenant(far, "Covenant_Cenotaph", at(-210, -64, -2560, 0.35, 1), 1.55)
	-- A broken bridge run: five arcade bays at x3.1 (62 long) stepping along its line, facing the arena.
	local run = Vector3.new(62, 0, -22).Unit
	for k = 0, 4 do
		local p = Vector3.new(196, -24, -2440) + run * (62 * k)
		covenant(far, if k == 2 or k == 4 then "Covenant_ArcadeBay_Broken" else "Covenant_ArcadeBay", at(p.X, p.Y, p.Z, -run.Z, run.X), 3.1)
	end
	for _, c in { { -250, -46, -2470, 260 }, { -140, -58, -2620, 300 }, { 120, -52, -2500, 260 }, { 300, -40, -2440, 240 }, { 420, -48, -2560, 280 }, { -380, -40, -2380, 220 } } do
		fitted(far, "AsuraLobbyKit", if rng:NextNumber() < 0.5 then "Cloud_A" else "Cloud_B", CFrame.new(c[1], c[2], c[3]) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), c[4])
	end
end

function Dressing.Build(map: Instance, _layout: any, rng: Random)
	local set = Kit.folder("ColosseumDressing", map)
	approach(set, rng)
	local dressed = bowl(set, rng)
	banks(set, rng)
	horizon(set, rng)
	-- Dressed boxes stay only as invisible colliders.
	local rules = {}
	for name, ok in dressed do
		if ok then
			rules[name] = function(): boolean return true end
		end
	end
	Decor.dressBoxes(map, rules)
end

return Dressing
