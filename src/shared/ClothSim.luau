--!strict
--!native
--!optimize 2
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/ClothSim
-- Cosmetic cloth for skinned bosses: particles on a lattice laid over the sculpted robe, hair and sleeves. Pure numbers with no Instances, so the game, the bake that drives the
-- Blender preview (tools/animation/opening_cast/cloth_bake.py) and the tests all run this exact code. It decides nothing about combat.
-- Each particle is pulled toward where the sculpt puts it on the moving body, stiff at the root and loose at the hem, so the designed silhouette survives while gusts, the body's real
-- travel and the legs move the cloth. World space: a root that really travels drags the cloth behind it.
-- Limbs: `limbs` is a flat array of 12 numbers per limb (position, then the rotation by rows): the map from the rest pose, in studs at this scale, to the world.
local Sim = {}

export type Def = { limbs: { string }, particles: { any }, links: { any }, colliders: { any }, hits: { [string]: { number } }, sheets: { any }, grip: any }
export type Wind = { x: number, y: number, z: number, gust: number, flutter: number }

Sim.DefaultWind = table.freeze({ x = 0.55, y = 0.0, z = 0.83, gust = 1.0, flutter = 1.0 } :: Wind) -- a steady breeze; direction in world space, speed in studs per second comes from Air below
local GRAVITY, AIR, BREEZE, MAX_SPEED, DAMP, SLACK, SAG = 26, 4.2, 3.2, 75, 0.992, 0.2, 7
local FINGER_TURN = math.rad(22) -- (2026-11-06) how far the finger curl may turn from the knuckle line to follow a haft lying diagonally in the palm
local TURN_RATE = math.rad(1440) -- (2026-11-07) fastest a cloth bone turns, per second: four turns a second, past any real swing of his robe, far short of a frame-to-frame flip (followFrame)
local SKIN_FLING = 2.5 -- (2026-11-07) most a particle moves per unit its drawn surface is pushed out of the body (skinPass)
local SKIN_PASSES, SKIN_FINAL = 4, 2 -- (2026-11-07) mean pushes converge over passes: four (the first over every sample, the rest over those in contact), the lattice, two more
local SKIN_MARGIN = 0.02 -- (2026-11-07) rig units past a volume that a sample resting outside it is kept
local MIDDLE_HOLD, MIDDLE_WEIGHT = 0.9, 8 -- (2026-11-07, later) in the surface passes a link's middle is held out to this share of its firm clearance, its push weighed like this many samples (skinPass)
local SKIN_STEP = 0.12 -- (2026-11-07) most the surface pass moves a particle in one pass, in rig units (scaled to studs): a deep miss is closed over a few steps, never thrown

-- Compiled once per form and scale; numeric arrays only, indexed from 1.
function Sim.new(def: Def, scale: number): any
	local index: { [string]: number } = {}
	for i, name in def.limbs do index[name] = i end
	local kinds: { [string]: string } = {}
	for _, s in def.sheets do kinds[s.name] = s.kind end
	local n = #def.particles
	local s: any = { n = n, scale = scale, t = 0, isOrb = {}, x = table.create(n, 0), y = table.create(n, 0), z = table.create(n, 0), ox = table.create(n, 0), oy = table.create(n, 0), oz = table.create(n, 0),
		rx = table.create(n, 0), ry = table.create(n, 0), rz = table.create(n, 0), pin = table.create(n, false), a = table.create(n, 0), b = table.create(n, 0), mix = table.create(n, 0),
		shape = table.create(n, 0), reach = table.create(n, 0), drag = table.create(n, 0), phase = table.create(n, 0), hitIds = {}, hitRad = {}, hitFirm = {}, bcap = {}, frames = {}, bones = {}, limbCount = #def.limbs, ready = false }
	-- colliders in studs
	local caps = {}
	for i, c in def.colliders do
		-- (2026-11-07) a volume tapers from radius r at a to rb at b, fitted to the limb's real surface
		caps[i] = { firm = c.firm, limb = index[c.limb], ax = c.a[1] * scale, ay = c.a[2] * scale, az = c.a[3] * scale, bx = c.b[1] * scale, by = c.b[2] * scale, bz = c.b[3] * scale, r = c.r * scale, rb = (c.rb or c.r) * scale }
	end
	s.caps = caps
	local function restDistance(cap: any, px: number, py: number, pz: number): number
		local dx, dy, dz = cap.bx - cap.ax, cap.by - cap.ay, cap.bz - cap.az
		local u = math.clamp(((px - cap.ax) * dx + (py - cap.ay) * dy + (pz - cap.az) * dz) / math.max(dx * dx + dy * dy + dz * dz, 1e-6), 0, 1)
		local qx, qy, qz = px - cap.ax - dx * u, py - cap.ay - dy * u, pz - cap.az - dz * u
		return math.sqrt(qx * qx + qy * qy + qz * qz)
	end
	for i, p in def.particles do
		local px, py, pz = p.at[1] * scale, p.at[2] * scale, p.at[3] * scale
		s.rx[i], s.ry[i], s.rz[i] = px, py, pz
		s.pin[i] = p.pin
		s.a[i] = index[p.anchor]
		s.b[i] = if p.anchor2 then index[p.anchor2] else index[p.anchor]
		s.mix[i] = p.mix or 0
		s.shape[i], s.reach[i], s.drag[i] = p.shape, p.reach * scale, p.drag
		s.phase[i] = p.c * 0.85 + p.r * 1.35 + (if p.sheet == "Hair" then 2.1 elseif p.sheet == "Under" then 4.4 else 0)
		local ids, rad, firm = {}, {}, {}
		if not p.pin and p.hit then
			-- (2026-11-07) clearances worked out for the surface each particle carries (tools/blender/shen_import/skin_rig.py): a firm volume's radius
			-- where the particle is plus what its patch reaches past it, or, for a volume the cloth rests in at rest, the clearance it had then
			for _, h in p.hit do
				table.insert(ids, h[1] + 1)
				table.insert(rad, h[2] * scale)
				table.insert(firm, h[3] == 1)
			end
		elseif not p.pin then
			for _, ci in def.hits[kinds[p.sheet]] or {} do
				local cap = caps[ci + 1]
				-- a robe that already overlaps a collider at rest keeps that clearance: it must not jump off the sculpt
				local d = restDistance(cap, px, py, pz)
				if d > 0.05 * scale then
					table.insert(ids, ci + 1)
					table.insert(rad, if cap.firm then 0 else math.min(cap.r, d * 0.96))
					table.insert(firm, cap.firm)
				end
			end
		end
		s.hitIds[i], s.hitRad[i], s.hitFirm[i] = ids, rad, firm
		-- (2026-11-08) the firm volume on the limb this particle's target partly rides (target), if it avoids one
		if s.mix[i] > 0 and s.b[i] ~= s.a[i] then
			for q, c in ids do
				if firm[q] and caps[c].limb == s.b[i] then
					s.bcap[i] = c
					break
				end
			end
		end
	end
	-- links, as flat arrays
	local L = #def.links
	s.la, s.lb, s.lr, s.lk, s.L = table.create(L, 0), table.create(L, 0), table.create(L, 0), table.create(L, 0), L
	for i, l in def.links do
		s.la[i], s.lb[i], s.lr[i], s.lk[i] = l[1] + 1, l[2] + 1, l[3] * scale, l[4]
	end
	-- (2026-11-06) the cloth between particles is solid too: each link's middle is kept out of every volume both its ends avoid, at the smaller clearance
	s.linkIds, s.linkRad, s.linkFirm = table.create(L), table.create(L), table.create(L)
	for l = 1, L do
		local i, j = s.la[l], s.lb[l]
		local ids, rad, firm = {}, {}, {}
		local ri, fi = {}, {}
		-- only links on the sheet's surface (one row down, one column across, or a quad's diagonal, whose middle is near the quad's centre): a bend link spans a fold and its middle is not on the cloth
		local pa, pb = def.particles[i], def.particles[j]
		local dr = math.abs(pa.r - pb.r)
		if pa.sheet ~= pb.sheet or dr > 1 then
			s.linkIds[l], s.linkRad[l], s.linkFirm[l] = ids, rad, firm
			continue
		end
		for q, c in s.hitIds[i] do ri[c], fi[c] = s.hitRad[i][q], s.hitFirm[i][q] end
		local mx, my, mz = (s.rx[i] + s.rx[j]) * 0.5, (s.ry[i] + s.ry[j]) * 0.5, (s.rz[i] + s.rz[j]) * 0.5
		for q, c in s.hitIds[j] do
			if ri[c] then
				-- like a particle, a link that already crosses a volume at rest keeps that clearance rather than jumping off the sculpt
				local d = restDistance(caps[c], mx, my, mz)
				if d > 0.05 * scale then
					local both = fi[c] and s.hitFirm[j][q]
					table.insert(ids, c)
					-- firm at both ends: the smaller reach added to the radius there; otherwise a clearance no more than the middle had at rest
					table.insert(rad, if both then math.min(ri[c], s.hitRad[j][q]) else math.min(if fi[c] then caps[c].r + ri[c] else ri[c], if s.hitFirm[j][q] then caps[c].r + s.hitRad[j][q] else s.hitRad[j][q], d * 0.96))
					table.insert(firm, both)
				end
			end
		end
		s.linkIds[l], s.linkRad[l], s.linkFirm[l] = ids, rad, firm
	end
	-- (2026-11-07, later) the links' middles in firm volumes, as flat pairs (link, its entry), for the surface passes (skinPass)
	s.midL, s.midQ = {}, {}
	for l = 1, L do
		for q, firm in s.linkFirm[l] do
			if firm then
				table.insert(s.midL, l)
				table.insert(s.midQ, q)
			end
		end
	end
	-- the free particles that drive a bone, and each one's rest frame from its neighbours
	for i, p in def.particles do
		if p.bone then
			local f: any = { i = i, bone = p.bone, ua = p.uA + 1, ub = p.uB + 1, va = p.vA + 1, vb = p.vB + 1, orb = p.orb }
			if p.orb then
				f.ax, f.ay, f.az = p.orb.around[1] * scale, p.orb.around[2] * scale, p.orb.around[3] * scale
				f.radius, f.turn = p.orb.radius * scale, (p.orb.k / p.orb.n) * 2 * math.pi
				s.isOrb[i] = true
			elseif p.finger then
				f.finger = p.finger
				f.ax, f.ay, f.az = p.at[1] * scale, p.at[2] * scale, p.at[3] * scale
				s.isOrb[i] = true -- like an orb, set directly and never simulated
			end
			table.insert(s.bones, f)
		end
	end
	s.R = table.create(#s.bones * 9, 0)
	s.turned = {} -- (2026-11-07) bones whose rotation follows on from the last step (followFrame); a reset clears it
	-- (2026-11-07) samples of the drawn garment surface (def.skin: rest positions, then per sample its weights: a particle index, or -(limb index + 1)
	-- for a body bone, from the game GLB's own skin weights). Each sample avoids every body volume (not the glaive, which stays the particles' alone,
	-- nor the arm a sleeve or rag hangs from), even one its lattice may enter (the beard's roots sit in his chin, and pushed off his chest its
	-- surface rose into his jaw): past the volume by SKIN_MARGIN where it rests outside it, else no deeper in it than it rests.
	-- With def.skin.nc, each sample tests only the volumes listed for it in def.skin.c (those it ever came near in the baked clips, skin_rig.py).
	-- Kept per sample: its cloth bones (particle, rotation slot, weight, rest offset from the particle), limbs (offset into the limb array,
	-- weight), and volumes (collider, clearance, whether added to the radius)
	local skin = def.skin
	if skin and skin.n and #skin.n > 0 then
		local slot = {}
		for k, f in s.bones do slot[f.i] = (k - 1) * 9 end
		local sk = { n = #skin.n, start = {}, count = {}, i = {}, q = {}, w = {}, ox = {}, oy = {}, oz = {}, inv = {}, lstart = {}, lcount = {}, lo = {}, lw = {},
			vx = {}, vy = {}, vz = {}, hstart = {}, hcount = {}, hc = {}, hr = {}, active = {}, nActive = 0,
			wax = {}, way = {}, waz = {}, wdx = {}, wdy = {}, wdz = {}, len2 = {}, cr0 = {}, crb = {}, ccx = {}, ccy = {}, ccz = {}, reach2 = {} }
		local e0, c0 = 0, 0
		for k = 1, sk.n do
			local vx, vy, vz = skin.v[k * 3 - 2] * scale, skin.v[k * 3 - 1] * scale, skin.v[k * 3] * scale
			sk.vx[k], sk.vy[k], sk.vz[k] = vx, vy, vz
			sk.start[k], sk.lstart[k], sk.hstart[k] = #sk.i + 1, #sk.lo + 1, #sk.hc + 1
			local w2, wmax = 0, 0
			local hung: { [string]: boolean } = {}
			for e = e0 + 1, e0 + skin.n[k] do
				local code, w = skin.b[e], skin.w[e]
				if code >= 0 then
					local i = code + 1
					table.insert(sk.i, i)
					table.insert(sk.q, slot[i])
					table.insert(sk.w, w)
					table.insert(sk.ox, vx - s.rx[i])
					table.insert(sk.oy, vy - s.ry[i])
					table.insert(sk.oz, vz - s.rz[i])
					w2 += w * w
					wmax = math.max(wmax, w)
					local p = def.particles[i]
					for _, side in { "Left", "Right" } do
						if string.sub(p.anchor, 1, #side) == side and table.find({ "UpperArm", "LowerArm", "Hand" }, string.sub(p.anchor, #side + 1)) then
							hung[side .. "UpperArm"], hung[side .. "LowerArm"], hung[side .. "Hand"] = true, true, true
						end
					end
				else
					table.insert(sk.lo, (-code - 1) * 12)
					table.insert(sk.lw, w)
				end
			end
			e0 += skin.n[k]
			sk.count[k], sk.lcount[k] = #sk.i + 1 - sk.start[k], #sk.lo + 1 - sk.lstart[k]
			-- a push of m on the sample moves each of its particles by m * weight / (sum of squared weights): the blend then moves by exactly m. A sample
			-- the lattice barely carries would fling its particles, so no particle moves more than SKIN_FLING times the push
			sk.inv[k] = if w2 > 0 then math.min(1 / w2, SKIN_FLING / wmax) else 0
			local listed: { [number]: boolean }? = nil
			if skin.nc then
				listed = {}
				for e = c0 + 1, c0 + skin.nc[k] do (listed :: any)[skin.c[e] + 1] = true end
				c0 += skin.nc[k]
			end
			for ci, c in def.colliders do
				if c.limb == "Glaive" or hung[c.limb] or (listed and not listed[ci]) then continue end
				local cap = caps[ci]
				local dx, dy, dz = cap.bx - cap.ax, cap.by - cap.ay, cap.bz - cap.az
				local u = math.clamp(((vx - cap.ax) * dx + (vy - cap.ay) * dy + (vz - cap.az) * dz) / math.max(dx * dx + dy * dy + dz * dz, 1e-6), 0, 1)
				local qx, qy, qz = vx - cap.ax - dx * u, vy - cap.ay - dy * u, vz - cap.az - dz * u
				local d = math.sqrt(qx * qx + qy * qy + qz * qz)
				if d < 0.05 * scale then continue end
				local rHere = cap.r + (cap.rb - cap.r) * u
				table.insert(sk.hc, ci)
				-- measured from the volume's surface where the sample now is, which follows the limb's taper: a sample resting inside a volume (fatter
				-- than his real thigh there) keeps the depth it rests at, never an absolute distance from the bone (P1 idle: the robe rode up his
				-- right thigh, where it is thicker, and a fixed distance let it 0.18 into the real thigh on every frame)
				table.insert(sk.hr, if d >= rHere then math.min(SKIN_MARGIN * scale, (d - rHere) * 0.985) else d * 0.985 - rHere)
			end
			sk.hcount[k] = #sk.hc + 1 - sk.hstart[k]
		end
		sk.ax, sk.ay, sk.az, sk.an, sk.touched = table.create(n, 0), table.create(n, 0), table.create(n, 0), table.create(n, 0), {}
		-- the first pass of a step goes volume by volume (its fields read once, not once a sample): every sample it tests, with that sample's
		-- clearance; samples that test no volume are never skinned
		sk.check, sk.cstart, sk.ccount, sk.ck, sk.cr = {}, {}, {}, {}, {}
		local byCap: { { number } } = {}
		for c = 1, #caps do byCap[c] = {} end
		for k = 1, sk.n do
			if sk.hcount[k] > 0 then table.insert(sk.check, k) end
			for h = sk.hstart[k], sk.hstart[k] + sk.hcount[k] - 1 do
				table.insert(byCap[sk.hc[h]], k)
				table.insert(byCap[sk.hc[h]], h)
			end
		end
		for c = 1, #caps do
			sk.cstart[c] = #sk.ck + 1
			local list = byCap[c]
			for e = 1, #list, 2 do
				table.insert(sk.ck, list[e])
				table.insert(sk.cr, sk.hr[list[e + 1]])
			end
			sk.ccount[c] = #sk.ck + 1 - sk.cstart[c]
		end
		sk.px, sk.py, sk.pz, sk.mark, sk.tick = table.create(sk.n, 0), table.create(sk.n, 0), table.create(sk.n, 0), table.create(sk.n, 0), 0
		-- the first pass skins every sample with native vectors: each bone's rotation as three columns, each limb's map as a column per axis and
		-- its position, built once a step
		sk.b, sk.l = {}, {}
		for j, q in sk.q do sk.b[j] = q // 9 + 1 end
		for j, o in sk.lo do sk.l[j] = o // 12 + 1 end
		sk.pv, sk.sv = table.create(n, vector.zero), table.create(sk.n, vector.zero)
		sk.c1, sk.c2, sk.c3 = table.create(#s.bones, vector.zero), table.create(#s.bones, vector.zero), table.create(#s.bones, vector.zero)
		sk.lt, sk.l1, sk.l2, sk.l3 = {}, {}, {}, {}
		s.skin = sk
	end
	s.hold = 0
	s.hand, s.glaive = index.LeftHand, index.Glaive
	if def.grip then
		local g = def.grip
		s.palm = { g.palm[1] * scale, g.palm[2] * scale, g.palm[3] * scale }
		s.butt = { g.butt[1] * scale, g.butt[2] * scale, g.butt[3] * scale }
		s.haftTop = { g.socket[1] * scale, g.socket[2] * scale, g.socket[3] * scale }
	end
	for k, f in s.bones do
		local e1x, e1y, e1z, e2x, e2y, e2z, e3x, e3y, e3z = Sim._frame(s, f, s.rx, s.ry, s.rz, nil)
		s.frames[k] = { e1x, e1y, e1z, e2x, e2y, e2z, e3x, e3y, e3z }
	end
	return s
end

-- An orthonormal frame from a particle's neighbours along the fall and across. A one-column strip has no neighbours across and takes its anchor limb's X.
function Sim._frame(s: any, f: any, X: { number }, Y: { number }, Z: { number }, limbs: { number }?): (number, number, number, number, number, number, number, number, number)
	local ax, ay, az = X[f.vb] - X[f.va], Y[f.vb] - Y[f.va], Z[f.vb] - Z[f.va]
	local m = math.sqrt(ax * ax + ay * ay + az * az)
	if m < 1e-6 then ax, ay, az, m = 0, -1, 0, 1 end
	ax, ay, az = ax / m, ay / m, az / m
	local bx, by, bz = X[f.ub] - X[f.ua], Y[f.ub] - Y[f.ua], Z[f.ub] - Z[f.ua]
	if f.ua == f.ub or bx * bx + by * by + bz * bz < 1e-8 then
		if limbs then
			local o = (s.a[f.i] - 1) * 12
			bx, by, bz = limbs[o + 4], limbs[o + 7], limbs[o + 10]
		else
			bx, by, bz = 1, 0, 0
		end
	end
	local cx, cy, cz = ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx
	m = math.sqrt(cx * cx + cy * cy + cz * cz)
	if m < 1e-6 then cx, cy, cz, m = 0, 0, 1, 1 end
	cx, cy, cz = cx / m, cy / m, cz / m
	return ax, ay, az, cy * az - cz * ay, cz * ax - cx * az, cx * ay - cy * ax, cx, cy, cz
end

-- R (rows, at offset o) turned by angle t about the unit axis (kx, ky, kz): R <- turn * R, then squared up
local function turnBy(R: { number }, o: number, kx: number, ky: number, kz: number, t: number)
	local co, si = math.cos(t), math.sin(t)
	local t1 = 1 - co
	local m1, m2, m3 = t1 * kx * kx + co, t1 * kx * ky - si * kz, t1 * kx * kz + si * ky
	local m4, m5, m6 = t1 * ky * kx + si * kz, t1 * ky * ky + co, t1 * ky * kz - si * kx
	local m7, m8, m9 = t1 * kz * kx - si * ky, t1 * kz * ky + si * kx, t1 * kz * kz + co
	local r1, r2, r3, r4, r5, r6, r7, r8, r9 = R[o + 1], R[o + 2], R[o + 3], R[o + 4], R[o + 5], R[o + 6], R[o + 7], R[o + 8], R[o + 9]
	-- columns of the product, then Gram-Schmidt so a long session never drifts off a rotation
	local x1, x2, x3 = m1 * r1 + m2 * r4 + m3 * r7, m4 * r1 + m5 * r4 + m6 * r7, m7 * r1 + m8 * r4 + m9 * r7
	local y1, y2, y3 = m1 * r2 + m2 * r5 + m3 * r8, m4 * r2 + m5 * r5 + m6 * r8, m7 * r2 + m8 * r5 + m9 * r8
	local n = math.sqrt(x1 * x1 + x2 * x2 + x3 * x3)
	x1, x2, x3 = x1 / n, x2 / n, x3 / n
	local d = x1 * y1 + x2 * y2 + x3 * y3
	y1, y2, y3 = y1 - x1 * d, y2 - x2 * d, y3 - x3 * d
	n = math.sqrt(y1 * y1 + y2 * y2 + y3 * y3)
	y1, y2, y3 = y1 / n, y2 / n, y3 / n
	R[o + 1], R[o + 4], R[o + 7] = x1, x2, x3
	R[o + 2], R[o + 5], R[o + 8] = y1, y2, y3
	R[o + 3], R[o + 6], R[o + 9] = x2 * y3 - x3 * y2, x3 * y1 - x1 * y3, x1 * y2 - x2 * y1
end

-- (2026-11-07) A cloth bone turns from where it was toward its lattice frame and never flips. The frame from neighbours reverses when two particles
-- cross (the sheet folds) or its across runs along its fall; a bone that took it outright turned 100-180 degrees in one frame (measured on every
-- garment, idle to flourish), throwing each vertex it carries across the body. The fall is reached by the least swing, at most maxTurn a step,
-- then the twist about it toward the lattice's across, at most maxTurn a step; it holds where the across runs along the fall and says nothing.
-- A flip becomes a quick turn over a few steps. (Taking the across as a line, sign-free, left bones parked half a turn off their lattice.)
local function followFrame(R: { number }, o: number, r: { number }, a1: number, a2: number, a3: number, b1: number, b2: number, b3: number, maxTurn: number)
	local px = R[o + 1] * r[1] + R[o + 2] * r[2] + R[o + 3] * r[3]
	local py = R[o + 4] * r[1] + R[o + 5] * r[2] + R[o + 6] * r[3]
	local pz = R[o + 7] * r[1] + R[o + 8] * r[2] + R[o + 9] * r[3]
	local kx, ky, kz = py * a3 - pz * a2, pz * a1 - px * a3, px * a2 - py * a1
	local sn = math.sqrt(kx * kx + ky * ky + kz * kz)
	local ang = math.atan2(sn, px * a1 + py * a2 + pz * a3)
	if ang > 1e-5 then
		if sn < 1e-7 then -- reversed exactly: about any axis square to it
			kx, ky, kz = py, -px, 0
			if kx * kx + ky * ky < 1e-8 then kx, ky, kz = 0, pz, -py end
			sn = math.sqrt(kx * kx + ky * ky + kz * kz)
		end
		turnBy(R, o, kx / sn, ky / sn, kz / sn, math.min(ang, maxTurn))
	end
	local fx = R[o + 1] * r[1] + R[o + 2] * r[2] + R[o + 3] * r[3]
	local fy = R[o + 4] * r[1] + R[o + 5] * r[2] + R[o + 6] * r[3]
	local fz = R[o + 7] * r[1] + R[o + 8] * r[2] + R[o + 9] * r[3]
	local d = b1 * fx + b2 * fy + b3 * fz
	local bx, by, bz = b1 - fx * d, b2 - fy * d, b3 - fz * d
	local bn = math.sqrt(bx * bx + by * by + bz * bz)
	if bn < 0.3 then return end
	bx, by, bz = bx / bn, by / bn, bz / bn
	local qx = R[o + 1] * r[4] + R[o + 2] * r[5] + R[o + 3] * r[6]
	local qy = R[o + 4] * r[4] + R[o + 5] * r[5] + R[o + 6] * r[6]
	local qz = R[o + 7] * r[4] + R[o + 8] * r[5] + R[o + 9] * r[6]
	local t = math.atan2((qy * bz - qz * by) * fx + (qz * bx - qx * bz) * fy + (qx * by - qy * bx) * fz, qx * bx + qy * by + qz * bz)
	t = math.clamp(t, -maxTurn, maxTurn)
	if math.abs(t) > 1e-6 then turnBy(R, o, fx, fy, fz, t) end
end

local function target(s: any, limbs: { number }, i: number): (number, number, number)
	local o = (s.a[i] - 1) * 12
	local px, py, pz = s.rx[i], s.ry[i], s.rz[i]
	local x = limbs[o + 1] + limbs[o + 4] * px + limbs[o + 5] * py + limbs[o + 6] * pz
	local y = limbs[o + 2] + limbs[o + 7] * px + limbs[o + 8] * py + limbs[o + 9] * pz
	local z = limbs[o + 3] + limbs[o + 10] * px + limbs[o + 11] * py + limbs[o + 12] * pz
	local mix = s.mix[i]
	if mix > 0 then
		o = (s.b[i] - 1) * 12
		local bx = limbs[o + 1] + limbs[o + 4] * px + limbs[o + 5] * py + limbs[o + 6] * pz
		local by = limbs[o + 2] + limbs[o + 7] * px + limbs[o + 8] * py + limbs[o + 9] * pz
		local bz = limbs[o + 3] + limbs[o + 10] * px + limbs[o + 11] * py + limbs[o + 12] * pz
		x, y, z = x + (bx - x) * mix, y + (by - y) * mix, z + (bz - z) * mix
		-- (2026-11-08) never a target buried in that limb. The target rides his hips with a share of the thigh; a thigh flexed past 90 deg (a crouch,
		-- a kneel) rises over the target of the skirt draped on it, and the leash hauled the particle into the thigh each step (to 0.23 of its axis,
		-- the target 0.53 in, on the far side): pushed out wherever was nearest and hauled back by the sheet, it slipped round the leg 1-3 studs a
		-- frame and the lattice split round the thigh (phase 2 DeathblowVictim, under-skirt front: the robe 0.19 deep in his left thigh between
		-- particles all clear of it). Held on the thigh's side where its copy of the sculpt point lies (that copy rides the thigh, and at rest the
		-- two copies are one, so nothing changes there), the target slides toward that copy only as far as the thigh's surface; measured along that
		-- side, so it never jumps when the thigh has swung right past the hip's copy
		local c = s.bcap[i]
		if c then
			local cap = s.caps[c]
			local ax, ay, az = cap.bx - cap.ax, cap.by - cap.ay, cap.bz - cap.az
			local l2 = math.max(ax * ax + ay * ay + az * az, 1e-6)
			-- the side of the limb the thigh's copy lies on: the sculpt point's own direction from the axis, fixed in the limb
			local nx, ny, nz = px - cap.ax, py - cap.ay, pz - cap.az
			local ub = math.clamp((nx * ax + ny * ay + nz * az) / l2, 0, 1)
			nx, ny, nz = nx - ax * ub, ny - ay * ub, nz - az * ub
			local nb = math.sqrt(nx * nx + ny * ny + nz * nz)
			-- how far short of the limb's surface a point falls, measured out along that side (positive: in the limb or past it)
			local function short(wx: number, wy: number, wz: number): number
				local dx, dy, dz = wx - limbs[o + 1], wy - limbs[o + 2], wz - limbs[o + 3]
				local lx = limbs[o + 4] * dx + limbs[o + 7] * dy + limbs[o + 10] * dz - cap.ax
				local ly = limbs[o + 5] * dx + limbs[o + 8] * dy + limbs[o + 11] * dz - cap.ay
				local lz = limbs[o + 6] * dx + limbs[o + 9] * dy + limbs[o + 12] * dz - cap.az
				local u = (lx * ax + ly * ay + lz * az) / l2
				if u <= 0 or u >= 1 then return -1 end -- past the limb's ends: not over it
				return cap.r + (cap.rb - cap.r) * u - ((lx - ax * u) * nx + (ly - ay * u) * ny + (lz - az * u) * nz) / nb
			end
			if nb > cap.r + (cap.rb - cap.r) * ub and short(x, y, z) > 0 then
				local lo, hi = 0, 1
				for _ = 1, 6 do
					local m = (lo + hi) * 0.5
					if short(x + (bx - x) * m, y + (by - y) * m, z + (bz - z) * m) > 0 then lo = m else hi = m end
				end
				x, y, z = x + (bx - x) * hi, y + (by - y) * hi, z + (bz - z) * hi
			end
		end
	end
	return x, y, z
end

-- Puts every particle on the sculpt, at rest, as the body now stands: on spawn, a skin swap, or a teleport.
-- (2026-11-06) the wearer has died: anything held up by his power (phase 2's orbs) falls to the floor at world height floorY and settles. Garments keep simulating on the body.
function Sim.drop(s: any, floorY: number)
	s.dropY = floorY
end

function Sim.reset(s: any, limbs: { number })
	table.clear(s.turned)
	s.placed = false
	for i = 1, s.n do
		local x, y, z = target(s, limbs, i)
		s.x[i], s.y[i], s.z[i], s.ox[i], s.oy[i], s.oz[i] = x, y, z, x, y, z
	end
	s.ready = true
end

-- A blow lands on him: the cloth takes it, loosest at the hem, along (dx, dy, dz) in the world, studs per second.
function Sim.impulse(s: any, dx: number, dy: number, dz: number, speed: number, h: number)
	if not s.ready then return end
	local X, Y, Z, OX, OY, OZ, reach = s.x, s.y, s.z, s.ox, s.oy, s.oz, s.reach
	local top = s.scale * 1.5
	for i = 1, s.n do
		if s.pin[i] or s.isOrb[i] then continue end
		local loose = math.clamp(reach[i] / top, 0.1, 1) * speed * s.scale * h
		OX[i], OY[i], OZ[i] = X[i] - dx * loose, Y[i] - dy * loose, Z[i] - dz * loose
	end
end

-- (2026-11-07) The drawn surface out of the body. The lattice can clear a leg while the garment drawn on it does not: a vertex is the weighted blend of
-- up to four bones, often of both the coat's and the under-skirt's lattices, which wrap a knee from either side, and the blend of points outside a
-- leg can lie inside it. Each sample (tools/blender/shen_import/cloth_skin.py, the game GLB's own weights) is skinned exactly as the game draws it,
-- with this step's bone rotations, and where it is inside a volume it avoids the particles carrying it move out, each by its weight. (Turning the
-- bones as well was tried: in phase 1 the turns it asked fought the lattice frame and the robe stayed in his thigh.)
-- Runs after the bone rotations are taken, so the drawn surface the bones then give is the one this cleared.
local function skinPass(s: any, limbs: { number }, all: boolean)
	local sk = s.skin
	local X, Y, Z, R, caps = s.x, s.y, s.z, s.R, s.caps
	local I, Q, W, SX, SY, SZ = sk.i, sk.q, sk.w, sk.ox, sk.oy, sk.oz
	local VX, VY, VZ, LS, LC, LO, LW, ST, CT, INV = sk.vx, sk.vy, sk.vz, sk.lstart, sk.lcount, sk.lo, sk.lw, sk.start, sk.count, sk.inv
	local PX, PY, PZ = sk.px, sk.py, sk.pz
	-- each particle gathers what every sample it carries asks of it, and moves by their mean (a sprint scissors both legs through the under-skirt,
	-- and samples pushing one particle opposite ways, applied in turn, flung it), at most SKIN_STEP a step
	local AX, AY, AZ, AN, touched = sk.ax, sk.ay, sk.az, sk.an, sk.touched
	local nt = 0
	-- where each sample is drawn now: the limbs and cloth bones it is weighted to, as the game skins it
	local active = sk.active
	local SV = sk.sv
	if all then
		local PV, C1, C2, C3, LT, L1, L2, L3, B, L = sk.pv, sk.c1, sk.c2, sk.c3, sk.lt, sk.l1, sk.l2, sk.l3, sk.b, sk.l
		for i = 1, #X do PV[i] = vector.create(X[i], Y[i], Z[i]) end
		for b = 1, #C1 do
			local q = (b - 1) * 9
			C1[b], C2[b], C3[b] = vector.create(R[q + 1], R[q + 4], R[q + 7]), vector.create(R[q + 2], R[q + 5], R[q + 8]), vector.create(R[q + 3], R[q + 6], R[q + 9])
		end
		for l = 1, #limbs // 12 do
			local o = (l - 1) * 12
			LT[l] = vector.create(limbs[o + 1], limbs[o + 2], limbs[o + 3])
			L1[l], L2[l], L3[l] = vector.create(limbs[o + 4], limbs[o + 7], limbs[o + 10]), vector.create(limbs[o + 5], limbs[o + 8], limbs[o + 11]), vector.create(limbs[o + 6], limbs[o + 9], limbs[o + 12])
		end
		local list = sk.check
		for idx = 1, #list do
			local k = list[idx]
			local vx, vy, vz = VX[k], VY[k], VZ[k]
			local p = vector.zero
			local l0 = LS[k]
			for j = l0, l0 + LC[k] - 1 do
				local l = L[j]
				p += LW[j] * (LT[l] + L1[l] * vx + L2[l] * vy + L3[l] * vz)
			end
			local a0 = ST[k]
			for j = a0, a0 + CT[k] - 1 do
				local b = B[j]
				p += W[j] * (PV[I[j]] + C1[b] * SX[j] + C2[b] * SY[j] + C3[b] * SZ[j])
			end
			SV[k] = p
		end
	else
		for idx = 1, sk.nActive do
			local k = active[idx]
			local vx, vy, vz = VX[k], VY[k], VZ[k]
			local x, y, z = 0, 0, 0
			local l0 = LS[k]
			for j = l0, l0 + LC[k] - 1 do
				local o, w = LO[j], LW[j]
				x += w * (limbs[o + 1] + limbs[o + 4] * vx + limbs[o + 5] * vy + limbs[o + 6] * vz)
				y += w * (limbs[o + 2] + limbs[o + 7] * vx + limbs[o + 8] * vy + limbs[o + 9] * vz)
				z += w * (limbs[o + 3] + limbs[o + 10] * vx + limbs[o + 11] * vy + limbs[o + 12] * vz)
			end
			local a0 = ST[k]
			for j = a0, a0 + CT[k] - 1 do
				local i, q, w = I[j], Q[j], W[j]
				local ox, oy, oz = SX[j], SY[j], SZ[j]
				x += w * (X[i] + R[q + 1] * ox + R[q + 2] * oy + R[q + 3] * oz)
				y += w * (Y[i] + R[q + 4] * ox + R[q + 5] * oy + R[q + 6] * oz)
				z += w * (Z[i] + R[q + 7] * ox + R[q + 8] * oy + R[q + 9] * oz)
			end
			PX[k], PY[k], PZ[k] = x, y, z
		end
	end
	-- a sample inside a volume it avoids asks each particle carrying it to move by its share of the way out
	local function push(k: number, mx: number, my: number, mz: number)
		local inv = INV[k]
		local a0 = ST[k]
		for j = a0, a0 + CT[k] - 1 do
			local g = W[j] * inv
			local i = I[j]
			if AN[i] == 0 then
				nt += 1
				touched[nt] = i
			end
			AX[i], AY[i], AZ[i], AN[i] = AX[i] + mx * g, AY[i] + my * g, AZ[i] + mz * g, AN[i] + 1
		end
	end
	local margin = SKIN_MARGIN * s.scale
	if all then
		-- the first pass of a step tries every sample, volume by volume, and keeps the ones in contact for the later passes, which converge the
		-- shared pushes
		local CS, CN, CK, CR, MARK = sk.cstart, sk.ccount, sk.ck, sk.cr, sk.mark
		local tick = sk.tick + 1
		sk.tick = tick
		local na = 0
		for c = 1, #caps do
			local p0 = CS[c]
			local p1 = p0 + CN[c] - 1
			if p1 < p0 then continue end
			local cap = caps[c]
			local wa, wd, len2 = vector.create(cap.wax, cap.way, cap.waz), vector.create(cap.wdx, cap.wdy, cap.wdz), cap.len2
			local r0, dr = cap.r, cap.rb - cap.r
			local centre = vector.create(cap.cx, cap.cy, cap.cz)
			local reach = math.sqrt(len2) * 0.5 + math.max(cap.r, cap.rb) + margin
			local reach2 = reach * reach
			for p = p0, p1 do
				local k = CK[p]
				local at = SV[k]
				local e = at - centre
				if vector.dot(e, e) > reach2 then continue end
				local pv = at - wa
				local u = math.clamp(vector.dot(pv, wd) / len2, 0, 1)
				local qv = pv - wd * u
				local d = vector.dot(qv, qv)
				local r = CR[p] + r0 + dr * u
				if d < r * r and d > 1e-8 then
					local f = r / math.sqrt(d) - 1
					push(k, qv.x * f, qv.y * f, qv.z * f)
					if MARK[k] ~= tick then
						MARK[k] = tick
						na += 1
						active[na] = k
					end
				end
			end
		end
		sk.nActive = na
	else
		-- the later passes try every volume of the samples found in contact (pushing one side of a thigh out drives the far side's samples into
		-- volumes they were not touching yet; trying only the pairs first in contact left the robe 0.27 in his thigh)
		local HC, HR, HS, HN = sk.hc, sk.hr, sk.hstart, sk.hcount
		-- (2026-11-12) each volume's fields copied to flat arrays once a pass, and the first pass's bounding sphere: the same arithmetic, read faster
		-- (Studio, native: these tests 1.99 -> 1.43 ms a step in phase 1)
		local WAX, WAY, WAZ, WDX, WDY, WDZ, LEN2, CR, CRB = sk.wax, sk.way, sk.waz, sk.wdx, sk.wdy, sk.wdz, sk.len2, sk.cr0, sk.crb
		local CCX, CCY, CCZ, REACH2 = sk.ccx, sk.ccy, sk.ccz, sk.reach2
		for c = 1, #caps do
			local cap = caps[c]
			WAX[c], WAY[c], WAZ[c], WDX[c], WDY[c], WDZ[c], LEN2[c], CR[c], CRB[c] = cap.wax, cap.way, cap.waz, cap.wdx, cap.wdy, cap.wdz, cap.len2, cap.r, cap.rb
			-- the first pass's bounding sphere: a sample's clearance is never more than the margin, so past it no volume can push
			local reach = math.sqrt(cap.len2) * 0.5 + math.max(cap.r, cap.rb) + margin
			CCX[c], CCY[c], CCZ[c], REACH2[c] = cap.cx, cap.cy, cap.cz, reach * reach
		end
		for idx = 1, sk.nActive do
			local k = active[idx]
			local x, y, z = PX[k], PY[k], PZ[k]
			local h0 = HS[k]
			for h = h0, h0 + HN[k] - 1 do
				local c = HC[h]
				local ex, ey, ez = x - CCX[c], y - CCY[c], z - CCZ[c]
				if ex * ex + ey * ey + ez * ez > REACH2[c] then continue end
				local wdx, wdy, wdz, r0 = WDX[c], WDY[c], WDZ[c], CR[c]
				local px, py, pz = x - WAX[c], y - WAY[c], z - WAZ[c]
				local u = math.clamp((px * wdx + py * wdy + pz * wdz) / LEN2[c], 0, 1)
				local qx, qy, qz = px - wdx * u, py - wdy * u, pz - wdz * u
				local d = qx * qx + qy * qy + qz * qz
				local r = HR[h] + r0 + (CRB[c] - r0) * u
				if d < r * r and d > 1e-8 then
					local f = r / math.sqrt(d) - 1
					push(k, qx * f, qy * f, qz * f)
				end
			end
		end
	end
	-- (2026-11-07, later) the lattice's own middles join the same mean: a link whose middle lies in a firm volume both its ends avoid asks both to
	-- move out together, weighed like MIDDLE_WEIGHT samples. Cleared only before these passes, a middle was dragged back in by the samples of a
	-- particle pressed between both thighs (phase 1, the under-skirt at his crotch: 1.02 of its clearance after the middle pass, 0.83 after these;
	-- test_cloth_sim); cleared once more after them, the particles carried their patches round the thigh's far side into it (mesh check: phase 1
	-- run 0.034 -> 0.095 in his right thigh, flourish 0.061 -> 0.127 in the glaive). Soft volumes stay out of it: they kept the robe in his left
	-- thigh 0.02 deeper in the phase 1 flourish
	local function nudge(e: number, ox: number, oy: number, oz: number)
		if AN[e] == 0 then
			nt += 1
			touched[nt] = e
		end
		AX[e], AY[e], AZ[e], AN[e] = AX[e] + ox, AY[e] + oy, AZ[e] + oz, AN[e] + MIDDLE_WEIGHT
	end
	local la, lb, pin, linkIds, linkRad, midL, midQ = s.la, s.lb, s.pin, s.linkIds, s.linkRad, s.midL, s.midQ
	for m = 1, #midL do
		local l, q = midL[m], midQ[m]
		local i, j = la[l], lb[l]
		local pi, pj = pin[i], pin[j]
		if pi and pj then continue end
		local cap = caps[linkIds[l][q]]
		local mx, my, mz = (X[i] + X[j]) * 0.5, (Y[i] + Y[j]) * 0.5, (Z[i] + Z[j]) * 0.5
		local ex, ey, ez = mx - cap.cx, my - cap.cy, mz - cap.cz
		if ex * ex + ey * ey + ez * ez > cap.reach2 then continue end
		local px, py, pz = mx - cap.wax, my - cap.way, mz - cap.waz
		local u = math.clamp((px * cap.wdx + py * cap.wdy + pz * cap.wdz) / cap.len2, 0, 1)
		local qx, qy, qz = px - cap.wdx * u, py - cap.wdy * u, pz - cap.wdz * u
		local d = qx * qx + qy * qy + qz * qz
		local r = (linkRad[l][q] + cap.r + (cap.rb - cap.r) * u) * MIDDLE_HOLD
		if d < r * r and d > 1e-8 then
			local f = (r / math.sqrt(d) - 1) * (if pi or pj then 2 else 1) * MIDDLE_WEIGHT
			if not pi then nudge(i, qx * f, qy * f, qz * f) end
			if not pj then nudge(j, qx * f, qy * f, qz * f) end
		end
	end
	local most = SKIN_STEP * s.scale
	for t = 1, nt do
		local i = touched[t]
		local n = AN[i]
		local dx, dy, dz = AX[i] / n, AY[i] / n, AZ[i] / n
		local m = math.sqrt(dx * dx + dy * dy + dz * dz)
		if m > most then
			m = most / m
			dx, dy, dz = dx * m, dy * m, dz * m
		end
		X[i], Y[i], Z[i] = X[i] + dx, Y[i] + dy, Z[i] + dz
		AX[i], AY[i], AZ[i], AN[i] = 0, 0, 0, 0
	end
end

-- (2026-11-12) One step in the functions below, each block as it stood in Sim.step: as one function, x64 native code generation could not
-- allocate its registers ("internal lowering failure"), so Studio interpreted the whole step on Windows PCs (arm64 compiled it). Split, every
-- function compiles on x64, arm64 and x64_ms, and the cloth comes out bit for bit the same (luau-compile --codegennull; a dump of every particle,
-- bone turn and grip value over 200 moving steps, both phases, 1-3 passes, interpreted and native)

-- the particles: inertia, air, gravity as it differs from the sculpt, back toward the sculpt, never past their reach
local function moveParticles(s: any, limbs: { number }, h: number, wind: Wind)
	local t, scale = s.t, s.scale
	local X, Y, Z, OX, OY, OZ = s.x, s.y, s.z, s.ox, s.oy, s.oz
	local steps = h * 60
	-- gusts: two slow drifts that never line up, so the breeze has no visible period
	local gust = 0.55 + 0.45 * math.sin(t * 0.73) * math.sin(t * 0.31 + 1.1) + 0.28 * math.sin(t * 1.9 + 0.6) * wind.gust
	local wx, wy, wz = wind.x * BREEZE * gust * scale, wind.y * BREEZE * gust * scale, wind.z * BREEZE * gust * scale
	local maxStep = MAX_SPEED * scale * h
	for i = 1, s.n do
		local tx, ty, tz = target(s, limbs, i)
		if s.pin[i] then
			X[i], Y[i], Z[i], OX[i], OY[i], OZ[i] = tx, ty, tz, tx, ty, tz
			continue
		end
		if s.isOrb[i] then continue end -- circling his head, below
		local vx, vy, vz = (X[i] - OX[i]) * DAMP, (Y[i] - OY[i]) * DAMP, (Z[i] - OZ[i]) * DAMP
		local sp = math.sqrt(vx * vx + vy * vy + vz * vz)
		if sp > maxStep then
			local k = maxStep / sp
			vx, vy, vz = vx * k, vy * k, vz * k
		end
		-- air: the cloth is pulled toward the moving air, so his own travel streams it behind him; a wave runs through the sheet so neighbours do not move as one
		local drag = s.drag[i] * AIR
		local ph = s.phase[i]
		local wave = math.sin(t * 2.4 - ph) + 0.55 * math.sin(t * 4.1 - ph * 1.7 + 0.8)
		local flut = wave * wind.flutter * 2.6 * scale * (0.4 + math.abs(gust))
		local ax = drag * (wx + flut * wind.z - vx / h)
		local ay = drag * (wy + flut * 0.8 - vy / h)
		local az = drag * (wz - flut * wind.x - vz / h)
		-- gravity only as it differs from the sculpt's pose, which already hangs: a leaning body lets its cloth fall, an upright one keeps its silhouette
		local o = (s.a[i] - 1) * 12
		local gx, gy, gz = limbs[o + 5], limbs[o + 8] - 1, limbs[o + 11]
		ax, ay, az = ax + gx * GRAVITY * scale, ay + gy * GRAVITY * scale - SAG * scale, az + gz * GRAVITY * scale -- and a little real weight: the loose hem hangs and swings instead of floating on the breeze
		OX[i], OY[i], OZ[i] = X[i], Y[i], Z[i]
		local x, y, z = X[i] + vx + ax * h * h, Y[i] + vy + ay * h * h, Z[i] + vz + az * h * h
		-- back toward the sculpt on the moving body; never farther from it than this row may roam
		local k = 1 - (1 - s.shape[i]) ^ steps
		x, y, z = x + (tx - x) * k, y + (ty - y) * k, z + (tz - z) * k
		local dx, dy, dz = x - tx, y - ty, z - tz
		local d = dx * dx + dy * dy + dz * dz
		local reach = s.reach[i]
		if d > reach * reach then
			local f = reach / math.sqrt(d)
			x, y, z = tx + dx * f, ty + dy * f, tz + dz * f
		end
		X[i], Y[i], Z[i] = x, y, z
	end
end

-- (2026-11-07) each volume is swept from where it stood last step to where it stands now across the link passes: a running leg moves half a
-- stud a step, past a robe particle's whole clearance, and kept out at the end alone the particle was thrown out the leg's far side for a frame
local function placeCap(cap: any, f: number, scale: number)
	cap.wax, cap.way, cap.waz = cap.pax + (cap.nax - cap.pax) * f, cap.pay + (cap.nay - cap.pay) * f, cap.paz + (cap.naz - cap.paz) * f
	cap.wdx, cap.wdy, cap.wdz = cap.pdx + (cap.ndx - cap.pdx) * f, cap.pdy + (cap.ndy - cap.pdy) * f, cap.pdz + (cap.ndz - cap.pdz) * f
	cap.len2 = math.max(cap.wdx * cap.wdx + cap.wdy * cap.wdy + cap.wdz * cap.wdz, 1e-6)
	-- a bounding sphere: most cloth is nowhere near most volumes, and one distance says so
	cap.cx, cap.cy, cap.cz = cap.wax + cap.wdx * 0.5, cap.way + cap.wdy * 0.5, cap.waz + cap.wdz * 0.5
	local reach = math.sqrt(cap.len2) * 0.5 + math.max(cap.r, cap.rb) + 0.5 * scale -- room for a particle's reach past its volume
	cap.reach2 = reach * reach
end

-- a point (x, y, z) in limb frame o
local function limbPoint(limbs: { number }, o: number, x: number, y: number, z: number): (number, number, number)
	return limbs[o + 1] + limbs[o + 4] * x + limbs[o + 5] * y + limbs[o + 6] * z, limbs[o + 2] + limbs[o + 7] * x + limbs[o + 8] * y + limbs[o + 9] * z,
		limbs[o + 3] + limbs[o + 10] * x + limbs[o + 11] * y + limbs[o + 12] * z
end

-- the body: legs push the skirt, the back carries the hair. Volumes are placed once per step and the cloth is kept out of them on every pass, so links never pull it back in
local function placeCaps(s: any, limbs: { number }, iterations: number)
	local caps, scale = s.caps, s.scale
	for c = 1, #caps do
		local cap = caps[c]
		local o = (cap.limb - 1) * 12
		local ax, ay, az = limbPoint(limbs, o, cap.ax, cap.ay, cap.az)
		local bx, by, bz = limbPoint(limbs, o, cap.bx, cap.by, cap.bz)
		local dx, dy, dz = bx - ax, by - ay, bz - az
		if s.placed then
			cap.pax, cap.pay, cap.paz, cap.pdx, cap.pdy, cap.pdz = cap.nax, cap.nay, cap.naz, cap.ndx, cap.ndy, cap.ndz
		else
			cap.pax, cap.pay, cap.paz, cap.pdx, cap.pdy, cap.pdz = ax, ay, az, dx, dy, dz
		end
		cap.nax, cap.nay, cap.naz, cap.ndx, cap.ndy, cap.ndz = ax, ay, az, dx, dy, dz
		placeCap(cap, if iterations > 1 then 1 / iterations else 1, scale)
	end
	s.placed = true
end

-- every particle out of every volume it avoids
local function keepOut(s: any)
	local X, Y, Z, caps = s.x, s.y, s.z, s.caps
	for i = 1, s.n do
		local ids, firm = s.hitIds[i], s.hitFirm[i]
		for q = 1, #ids do
			local cap, r = caps[ids[q]], s.hitRad[i][q]
			local ex, ey, ez = X[i] - cap.cx, Y[i] - cap.cy, Z[i] - cap.cz
			if ex * ex + ey * ey + ez * ez > cap.reach2 then continue end
			local px, py, pz = X[i] - cap.wax, Y[i] - cap.way, Z[i] - cap.waz
			local u = math.clamp((px * cap.wdx + py * cap.wdy + pz * cap.wdz) / cap.len2, 0, 1)
			local qx, qy, qz = px - cap.wdx * u, py - cap.wdy * u, pz - cap.wdz * u
			local d = qx * qx + qy * qy + qz * qz
			if firm[q] then r += cap.r + (cap.rb - cap.r) * u end
			if d < r * r and d > 1e-8 then
				local f = (r / math.sqrt(d) - 1)
				X[i], Y[i], Z[i] = X[i] + qx * f, Y[i] + qy * f, Z[i] + qz * f
			end
		end
	end
end

-- links: the sheet holds together
local function pullLinks(s: any)
	local X, Y, Z = s.x, s.y, s.z
	local la, lb, lr, lk, pin = s.la, s.lb, s.lr, s.lk, s.pin
	for l = 1, s.L do
		local i, j = la[l], lb[l]
		local dx, dy, dz = X[j] - X[i], Y[j] - Y[i], Z[j] - Z[i]
		local d = math.sqrt(dx * dx + dy * dy + dz * dz)
		if d < 1e-6 then continue end
		local c = (d - lr[l]) / d * lk[l]
		if d < lr[l] then c *= SLACK end -- cloth pulls tight but folds under compression: a stiff push here would hold the sheet still
		local pi, pj = pin[i], pin[j]
		if pi and pj then continue end
		if pi then
			X[j], Y[j], Z[j] = X[j] - dx * c, Y[j] - dy * c, Z[j] - dz * c
		elseif pj then
			X[i], Y[i], Z[i] = X[i] + dx * c, Y[i] + dy * c, Z[i] + dz * c
		else
			c *= 0.5
			X[i], Y[i], Z[i] = X[i] + dx * c, Y[i] + dy * c, Z[i] + dz * c
			X[j], Y[j], Z[j] = X[j] - dx * c, Y[j] - dy * c, Z[j] - dz * c
		end
	end
end

-- a link's middle inside a volume moves both its ends out together (a pinned end stays): the sheet cannot slice through a leg between two particles
local function pushMiddles(s: any)
	local X, Y, Z, caps = s.x, s.y, s.z, s.caps
	local la, lb, pin = s.la, s.lb, s.pin
	local linkIds, linkRad, linkFirm = s.linkIds, s.linkRad, s.linkFirm
	for l = 1, s.L do
		local ids = linkIds[l]
		if #ids == 0 then continue end
		local i, j = la[l], lb[l]
		local pi, pj = pin[i], pin[j]
		if pi and pj then continue end
		for q = 1, #ids do
			local cap, r = caps[ids[q]], linkRad[l][q]
			local mx, my, mz = (X[i] + X[j]) * 0.5, (Y[i] + Y[j]) * 0.5, (Z[i] + Z[j]) * 0.5
			local ex, ey, ez = mx - cap.cx, my - cap.cy, mz - cap.cz
			if ex * ex + ey * ey + ez * ez > cap.reach2 then continue end
			local px, py, pz = mx - cap.wax, my - cap.way, mz - cap.waz
			local u = math.clamp((px * cap.wdx + py * cap.wdy + pz * cap.wdz) / cap.len2, 0, 1)
			local qx, qy, qz = px - cap.wdx * u, py - cap.wdy * u, pz - cap.wdz * u
			local d = qx * qx + qy * qy + qz * qz
			if linkFirm[l][q] then r += cap.r + (cap.rb - cap.r) * u end
			if d < r * r and d > 1e-8 then
				local f = (r * 1.02 / math.sqrt(d) - 1) * (if pi or pj then 2 else 1)
				local ox, oy, oz = qx * f, qy * f, qz * f
				if not pi then X[i], Y[i], Z[i] = X[i] + ox, Y[i] + oy, Z[i] + oz end
				if not pj then X[j], Y[j], Z[j] = X[j] + ox, Y[j] + oy, Z[j] + oz end
			end
		end
	end
end

-- a point v in limb frame m
local function onLimb(limbs: { number }, m: number, v: { number }): (number, number, number)
	return limbs[m + 1] + limbs[m + 4] * v[1] + limbs[m + 5] * v[2] + limbs[m + 6] * v[3], limbs[m + 2] + limbs[m + 7] * v[1] + limbs[m + 8] * v[2] + limbs[m + 9] * v[3],
		limbs[m + 3] + limbs[m + 10] * v[1] + limbs[m + 11] * v[2] + limbs[m + 12] * v[3]
end

-- the left hand: fingers close as the palm comes to the haft and open as it leaves
local function gripHaft(s: any, limbs: { number }, steps: number)
	local scale = s.scale
	local o, q = (s.hand - 1) * 12, (s.glaive - 1) * 12
	local px, py, pz = onLimb(limbs, o, s.palm)
	local ax, ay, az = onLimb(limbs, q, s.butt)
	local bx, by, bz = onLimb(limbs, q, s.haftTop)
	local dx, dy, dz = bx - ax, by - ay, bz - az
	local u = ((px - ax) * dx + (py - ay) * dy + (pz - az) * dz) / math.max(dx * dx + dy * dy + dz * dz, 1e-6)
	local qx, qy, qz = px - ax - dx * u, py - ay - dy * u, pz - az - dz * u
	local want = 1 - math.clamp((math.sqrt(qx * qx + qy * qy + qz * qz) / scale - 0.25) / 0.3, 0, 1)
	s.hold += (want - s.hold) * (1 - 0.75 ^ steps)
	-- the haft in the hand's own frame: the fingers close round the wood itself, even where it runs diagonally across the palm
	local n = math.max(math.sqrt(dx * dx + dy * dy + dz * dz), 1e-6)
	s.haftX = (limbs[o + 4] * dx + limbs[o + 7] * dy + limbs[o + 10] * dz) / n
	s.haftY = (limbs[o + 5] * dx + limbs[o + 8] * dy + limbs[o + 11] * dz) / n
	s.haftZ = (limbs[o + 6] * dx + limbs[o + 9] * dy + limbs[o + 12] * dz) / n
end

-- a rigid chain on the hand: the knuckle rides the hand, the middle joint rides the knuckle, each adds its curl about the line of the haft
local function fingerBone(s: any, limbs: { number }, k: number, f: any, lastFinger: any): any
	local X, Y, Z, R = s.x, s.y, s.z, s.R
	local o = (s.a[f.i] - 1) * 12
	local q = (k - 1) * 9
	local ax, ay, az = f.finger.axis[1], f.finger.axis[2], f.finger.axis[3]
	if s.haftX then
		-- curl about the haft's own line (turned at most FINGER_TURN from the knuckles' line), so a diagonal grip still wraps the wood
		local hx, hy, hz = s.haftX, s.haftY, s.haftZ
		local d = hx * ax + hy * ay + hz * az
		if d < 0 then hx, hy, hz, d = -hx, -hy, -hz, -d end
		local cmax = math.cos(FINGER_TURN)
		if d < cmax then
			local px, py, pz = hx - ax * d, hy - ay * d, hz - az * d
			local pn = math.max(math.sqrt(px * px + py * py + pz * pz), 1e-6)
			local sn = math.sin(FINGER_TURN)
			hx, hy, hz = ax * cmax + px / pn * sn, ay * cmax + py / pn * sn, az * cmax + pz / pn * sn
		end
		ax, ay, az = hx, hy, hz
	end
	local base = if lastFinger then lastFinger.Base else { limbs[o + 4], limbs[o + 5], limbs[o + 6], limbs[o + 7], limbs[o + 8], limbs[o + 9], limbs[o + 10], limbs[o + 11], limbs[o + 12] }
	local a = math.rad(f.finger.curl) * s.hold
	local co, si, t1 = math.cos(a), math.sin(a), 1 - math.cos(a)
	local c = { t1 * ax * ax + co, t1 * ax * ay - si * az, t1 * ax * az + si * ay, t1 * ay * ax + si * az, t1 * ay * ay + co, t1 * ay * az - si * ax, t1 * az * ax - si * ay, t1 * az * ay + si * ax, t1 * az * az + co }
	local m = { base[1] * c[1] + base[2] * c[4] + base[3] * c[7], base[1] * c[2] + base[2] * c[5] + base[3] * c[8], base[1] * c[3] + base[2] * c[6] + base[3] * c[9],
		base[4] * c[1] + base[5] * c[4] + base[6] * c[7], base[4] * c[2] + base[5] * c[5] + base[6] * c[8], base[4] * c[3] + base[5] * c[6] + base[6] * c[9],
		base[7] * c[1] + base[8] * c[4] + base[9] * c[7], base[7] * c[2] + base[8] * c[5] + base[9] * c[8], base[7] * c[3] + base[8] * c[6] + base[9] * c[9] }
	local x, y, z
	if lastFinger then
		local dx, dy, dz = f.ax - lastFinger.X, f.ay - lastFinger.Y, f.az - lastFinger.Z
		x = lastFinger.WX + base[1] * dx + base[2] * dy + base[3] * dz
		y = lastFinger.WY + base[4] * dx + base[5] * dy + base[6] * dz
		z = lastFinger.WZ + base[7] * dx + base[8] * dy + base[9] * dz
	else
		x = limbs[o + 1] + limbs[o + 4] * f.ax + limbs[o + 5] * f.ay + limbs[o + 6] * f.az
		y = limbs[o + 2] + limbs[o + 7] * f.ax + limbs[o + 8] * f.ay + limbs[o + 9] * f.az
		z = limbs[o + 3] + limbs[o + 10] * f.ax + limbs[o + 11] * f.ay + limbs[o + 12] * f.az
	end
	X[f.i], Y[f.i], Z[f.i] = x, y, z
	for w = 1, 9 do R[q + w] = m[w] end
	return { Base = m, X = f.ax, Y = f.ay, Z = f.az, WX = x, WY = y, WZ = z }
end

-- (2026-11-06) he is dead: the power that held the orbs is gone. Each falls under its own weight from where it was, strikes the floor, bounces low and rolls to rest
local function dropOrb(s: any, k: number, f: any, h: number)
	local X, Y, Z, R, scale = s.x, s.y, s.z, s.R, s.scale
	local i = f.i
	local st = f.fall
	if not st then
		st = { vx = (X[i] - (f.lastX or X[i])) / math.max(h, 1e-3), vy = 0, vz = (Z[i] - (f.lastZ or Z[i])) / math.max(h, 1e-3), spin = s.t * 1.6 + f.turn }
		f.fall = st
	end
	local r = 0.21 * scale -- an orb's radius
	st.vy -= GRAVITY * scale * 0.55 * h
	local x, y, z = X[i] + st.vx * h, Y[i] + st.vy * h, Z[i] + st.vz * h
	if y < s.dropY + r then
		y = s.dropY + r
		st.vy = if math.abs(st.vy) > 2 * scale then -st.vy * 0.3 else 0
		st.vx, st.vz = st.vx * 0.6, st.vz * 0.6 -- the stone floor takes most of the roll
		st.spin += math.sqrt(st.vx * st.vx + st.vz * st.vz) * h / r
	end
	X[i], Y[i], Z[i] = x, y, z
	local co, si = math.cos(st.spin), math.sin(st.spin)
	local q = (k - 1) * 9
	R[q + 1], R[q + 2], R[q + 3], R[q + 4], R[q + 5], R[q + 6], R[q + 7], R[q + 8], R[q + 9] = co, 0, si, 0, 1, 0, -si, 0, co
end

-- an orb circles the crown on its own uneven path, in the world's frame, and catches up a beat late when he moves: around his head, never strung out behind him
local function circleOrb(s: any, limbs: { number }, k: number, f: any, steps: number)
	local X, Y, Z, R, t, scale = s.x, s.y, s.z, s.R, s.t, s.scale
	f.lastX, f.lastZ = X[f.i], Z[f.i]
	local o = (s.a[f.i] - 1) * 12
	local bx, by, bz = f.ax, f.ay, f.az
	local cx = limbs[o + 1] + limbs[o + 4] * bx + limbs[o + 5] * by + limbs[o + 6] * bz
	local cy = limbs[o + 2] + limbs[o + 7] * bx + limbs[o + 8] * by + limbs[o + 9] * bz
	local cz = limbs[o + 3] + limbs[o + 10] * bx + limbs[o + 11] * by + limbs[o + 12] * bz
	local ang = t * (0.85 + 0.12 * math.sin(t * 0.37)) + f.turn
	local radius = f.radius * (1 + 0.08 * math.sin(t * 0.9 + f.turn * 2))
	local tx, ty, tz = cx + math.cos(ang) * radius, cy + scale * (0.3 * math.sin(ang + f.turn) + 0.1 * math.sin(t * 2.1 + f.turn)), cz + math.sin(ang) * radius
	local follow = 1 - 0.8 ^ steps
	local i = f.i
	X[i], Y[i], Z[i] = X[i] + (tx - X[i]) * follow, Y[i] + (ty - Y[i]) * follow, Z[i] + (tz - Z[i]) * follow
	local spin = t * 1.6 + f.turn
	local co, si = math.cos(spin), math.sin(spin)
	local q = (k - 1) * 9
	R[q + 1], R[q + 2], R[q + 3], R[q + 4], R[q + 5], R[q + 6], R[q + 7], R[q + 8], R[q + 9] = co, 0, si, 0, 1, 0, -si, 0, co
end

-- each bone's rotation: its frame now against its frame at rest
local function turnBones(s: any, limbs: { number }, h: number)
	local X, Y, Z = s.x, s.y, s.z
	local steps = h * 60
	local R, frames = s.R, s.frames
	local lastFinger: any = nil
	for k, f in s.bones do
		if f.finger then
			lastFinger = fingerBone(s, limbs, k, f, lastFinger)
			continue
		end
		if f.orb and s.dropY then
			dropOrb(s, k, f, h)
			continue
		end
		if f.orb then
			circleOrb(s, limbs, k, f, steps)
			continue
		end
		local a1, a2, a3, b1, b2, b3, c1, c2, c3 = Sim._frame(s, f, X, Y, Z, limbs)
		local r = frames[k]
		local o = (k - 1) * 9
		if s.turned[k] then
			followFrame(R, o, r, a1, a2, a3, b1, b2, b3, TURN_RATE * h)
			continue
		end
		s.turned[k] = true -- the first step after a reset takes the lattice's frame outright
		R[o + 1] = a1 * r[1] + b1 * r[4] + c1 * r[7]
		R[o + 2] = a1 * r[2] + b1 * r[5] + c1 * r[8]
		R[o + 3] = a1 * r[3] + b1 * r[6] + c1 * r[9]
		R[o + 4] = a2 * r[1] + b2 * r[4] + c2 * r[7]
		R[o + 5] = a2 * r[2] + b2 * r[5] + c2 * r[8]
		R[o + 6] = a2 * r[3] + b2 * r[6] + c2 * r[9]
		R[o + 7] = a3 * r[1] + b3 * r[4] + c3 * r[7]
		R[o + 8] = a3 * r[2] + b3 * r[5] + c3 * r[8]
		R[o + 9] = a3 * r[3] + b3 * r[6] + c3 * r[9]
	end
end

-- One fixed step. iterations: link passes (a low graphics tier passes fewer).
function Sim.step(s: any, limbs: { number }, h: number, wind: Wind, iterations: number)
	if not s.ready then Sim.reset(s, limbs) end
	s.t += h
	moveParticles(s, limbs, h, wind)
	placeCaps(s, limbs, iterations)
	local caps, scale = s.caps, s.scale
	for pass = 1, iterations do
		if pass > 1 then for c = 1, #caps do placeCap(caps[c], pass / iterations, scale) end end
		pullLinks(s)
		keepOut(s)
		-- Once a step, on the last pass, the middles, then the particles once more: the middles cost the most and the sheet between particles moves least.
		-- (2026-11-07) twice, each push 2% past the surface: once let the particles' own last push sag a middle back into a volume (test_cloth_sim)
		if pass < iterations then continue end
		for _ = 1, 2 do
			pushMiddles(s)
			keepOut(s)
		end
	end
	if s.palm and s.glaive then gripHaft(s, limbs, h * 60) end
	turnBones(s, limbs, h)
	-- (2026-11-07) the drawn surface out of the body, then the lattice once more (a particle pushed into the other leg), then the surface again
	if s.skin then
		skinPass(s, limbs, true)
		for _ = 2, SKIN_PASSES do skinPass(s, limbs, false) end
		keepOut(s)
		for _ = 1, SKIN_FINAL do skinPass(s, limbs, false) end
	end
end

return Sim
