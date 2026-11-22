--!nonstrict
-- Landmark placement (LANDMARK-BUILD-SPEC "Shared rules"): src/shared/LandmarkLayout against the real Overworld.
-- Run: python3 tools/lune_compat.py tools/test_landmark_layout.luau
local O = require("../../src/shared/Overworld")
local L = require("../../src/shared/LandmarkLayout")

local passed, failed = 0, 0
local function check(name: string, ok: any)
	if ok then passed += 1 else failed += 1; print("FAIL " .. name) end
end

-- Everything the spec says a landmark must keep clear of.
local points = {}
local function add(kind, p) if p then table.insert(points, { kind = kind, x = p.X, z = p.Z }) end end
for id, a in O.Altars do add("altar " .. id, a.Placement or a.Position) end
for id, n in O.Nodes do add("node " .. id, n.Position) end
for _, p in O.POIs do add("poi " .. p.Id, p.Position) end
for id, l in O.Landmarks do add("landmark " .. id, l.Position) end
for id, c in O.Caches do add("cache " .. id, c.Position) end
for id, l in O.Lore do add("lore " .. id, l.Position) end
for id, r in O.Rings do add("ring " .. id, r) end
for id, m in O.Minibosses do add("miniboss " .. id, m.Placement) end
for _, s in O.EncounterSpots do add("encounter " .. s.Spawn, s.Placement) end
add("Vesperhold", O.Vesperhold)

local D = O.terrainData()
local roads, rivers = {}, {}
for _, r in D.Roads do for k = 2, #r.Points do table.insert(roads, { r.Points[k - 1], r.Points[k] }) end end
for _, rv in O.TerrainDef.Rivers do for k = 2, #rv.Points do table.insert(rivers, { rv.Points[k - 1], rv.Points[k] }) end end
local function segDist(x, z, segs)
	local best, bx, bz = math.huge, 0, 0
	for _, s in segs do
		local a, b = s[1], s[2]
		local dx, dz = b[1] - a[1], b[2] - a[2]
		local t = math.clamp(((x - a[1]) * dx + (z - a[2]) * dz) / math.max(dx * dx + dz * dz, 1e-6), 0, 1)
		local px, pz = a[1] + t * dx, a[2] + t * dz
		local d = math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)
		if d < best then best, bx, bz = d, px, pz end
	end
	return best, bx, bz
end



local lm = table.clone(L.Landmarks.Bellwood)
lm.Basin = table.clone(lm.Basin)
local b = lm.Basin
b.Back, b.Width, b.Depth, b.Thick = 750, 1400, 1120, 76
b.Bed = -84 -- World Y 100.
local cx = L.basinCentre(lm)
local fx, fz = L.front(lm)
local rx, rz = -fz, fx
local roadEyes, candidates = {}, {}
for _, seg in roads do
	local a,c = seg[1],seg[2]
	local dx,dz = c[1]-a[1], c[2]-a[2]
	local n = math.max(1, math.ceil(math.sqrt(dx*dx + dz*dz)/20))
	for i=0,n do
		local x,z = a[1]+dx*i/n, a[2]+dz*i/n
		table.insert(candidates,{x,z,(x-cx.X)^2+(z-cx.Z)^2})
	end
end
table.sort(candidates,function(a,c) return a[3]<c[3] end)
for _, c in candidates do
	local separate = true
	for _, eye in roadEyes do
		if (c[1]-eye[1])^2+(c[2]-eye[2])^2 < 80^2 then separate=false; break end
	end
	if separate then table.insert(roadEyes,c) end
	if #roadEyes==8 then break end
end
local floorY,xz = L.basinLevels(lm)
local temple,gate = {-230,35},{520,-200}
local target = {
	{"hall centre",temple[1],temple[2], floorY+155},
	{"hall east eave",temple[1]+160,temple[2], floorY+100},
	{"hall west eave",temple[1]-160,temple[2], floorY+100},
	{"maple",temple[1]-8,temple[2]-28, floorY+250},
	{"gate",gate[1],gate[2],floorY+155},
}
for _, rise in {65,85,105,125} do
	b.RimRise = rise
	local unblocked, heightMin, heightMax = {}, math.huge, -math.huge
	for i=0,63 do
		local h=L.rimTop(lm,2*math.pi*i/64,O.heightAt)
		heightMin,heightMax=math.min(heightMin,h),math.max(heightMax,h)
	end
	local function height(x,z)
		if L.basinEllipse(lm,x,z)<1 then return floorY end
		if L.basinEllipse(lm,x,z,b.Thick)<1 then
			local dx,dz = x-cx.X,z-cx.Z
			local angle = math.atan2((dx*fx+dz*fz)/(b.Depth/2), (dx*rx+dz*rz)/(b.Width/2))
			return L.rimTop(lm,angle,O.heightAt)
		end
		return O.heightAt(x,z)
	end
	for _, eye in roadEyes do
		for _, t in target do
			local x,z = cx.X+rx*t[2]+fx*t[3],cx.Z+rz*t[2]+fz*t[3]
			local y=O.heightAt(eye[1],eye[2])+7.5
			local hidden = false
			for q=1,199 do
				local k=q/200
				if height(eye[1]+(x-eye[1])*k,eye[2]+(z-eye[2])*k) >= y+(t[4]-y)*k then
					hidden=true
					break
				end
			end
			if not hidden then table.insert(unblocked,t[1]) end
		end
	end
	print(string.format("Rim lift %d | crest Y %.0f..%.0f | visible %d/%d",rise,heightMin,heightMax,#unblocked,#target*#roadEyes),table.concat(unblocked,", "))
end
print("Gate footprint centre within basin", L.basinEllipse(lm,cx.X+rx*gate[1]+fx*gate[2],cx.Z+rz*gate[1]+fz*gate[2]))
