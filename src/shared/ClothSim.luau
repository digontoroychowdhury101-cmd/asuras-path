--!strict
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

-- Compiled once per form and scale; numeric arrays only, indexed from 1.
function Sim.new(def: Def, scale: number): any
	local index: { [string]: number } = {}
	for i, name in def.limbs do index[name] = i end
	local kinds: { [string]: string } = {}
	for _, s in def.sheets do kinds[s.name] = s.kind end
	local n = #def.particles
	local s: any = { n = n, scale = scale, t = 0, isOrb = {}, x = table.create(n, 0), y = table.create(n, 0), z = table.create(n, 0), ox = table.create(n, 0), oy = table.create(n, 0), oz = table.create(n, 0),
		rx = table.create(n, 0), ry = table.create(n, 0), rz = table.create(n, 0), pin = table.create(n, false), a = table.create(n, 0), b = table.create(n, 0), mix = table.create(n, 0),
		shape = table.create(n, 0), reach = table.create(n, 0), drag = table.create(n, 0), phase = table.create(n, 0), hitIds = {}, hitRad = {}, frames = {}, bones = {}, limbCount = #def.limbs, ready = false }
	-- colliders in studs
	local caps = {}
	for i, c in def.colliders do
		caps[i] = { firm = c.firm, limb = index[c.limb], ax = c.a[1] * scale, ay = c.a[2] * scale, az = c.a[3] * scale, bx = c.b[1] * scale, by = c.b[2] * scale, bz = c.b[3] * scale, r = c.r * scale }
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
		local ids, rad = {}, {}
		if not p.pin then
			for _, ci in def.hits[kinds[p.sheet]] or {} do
				local cap = caps[ci + 1]
				-- a robe that already overlaps a collider at rest keeps that clearance: it must not jump off the sculpt
				local d = restDistance(cap, px, py, pz)
				if d > 0.05 * scale then
					table.insert(ids, ci + 1)
					table.insert(rad, if cap.firm then cap.r else math.min(cap.r, d * 0.96))
				end
			end
		end
		s.hitIds[i], s.hitRad[i] = ids, rad
	end
	-- links, as flat arrays
	local L = #def.links
	s.la, s.lb, s.lr, s.lk, s.L = table.create(L, 0), table.create(L, 0), table.create(L, 0), table.create(L, 0), L
	for i, l in def.links do
		s.la[i], s.lb[i], s.lr[i], s.lk[i] = l[1] + 1, l[2] + 1, l[3] * scale, l[4]
	end
	-- (2026-11-06) the cloth between particles is solid too: each link's middle is kept out of every volume both its ends avoid, at the smaller clearance
	s.linkIds, s.linkRad = table.create(L), table.create(L)
	for l = 1, L do
		local i, j = s.la[l], s.lb[l]
		local ids, rad = {}, {}
		local ri = {}
		-- only links on the sheet's surface (one row down, one column across, or a quad's diagonal, whose middle is near the quad's centre): a bend link spans a fold and its middle is not on the cloth
		local pa, pb = def.particles[i], def.particles[j]
		local dr = math.abs(pa.r - pb.r)
		if pa.sheet ~= pb.sheet or dr > 1 then
			s.linkIds[l], s.linkRad[l] = ids, rad
			continue
		end
		for q, c in s.hitIds[i] do ri[c] = s.hitRad[i][q] end
		local mx, my, mz = (s.rx[i] + s.rx[j]) * 0.5, (s.ry[i] + s.ry[j]) * 0.5, (s.rz[i] + s.rz[j]) * 0.5
		for q, c in s.hitIds[j] do
			if ri[c] then
				-- like a particle, a link that already crosses a volume at rest keeps that clearance rather than jumping off the sculpt
				local d = restDistance(caps[c], mx, my, mz)
				if d > 0.05 * scale then
					table.insert(ids, c)
					table.insert(rad, math.min(ri[c], s.hitRad[j][q], d * 0.96))
				end
			end
		end
		s.linkIds[l], s.linkRad[l] = ids, rad
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

local function target(s: any, limbs: { number }, i: number): (number, number, number)
	local o = (s.a[i] - 1) * 12
	local px, py, pz = s.rx[i], s.ry[i], s.rz[i]
	local x = limbs[o + 1] + limbs[o + 4] * px + limbs[o + 5] * py + limbs[o + 6] * pz
	local y = limbs[o + 2] + limbs[o + 7] * px + limbs[o + 8] * py + limbs[o + 9] * pz
	local z = limbs[o + 3] + limbs[o + 10] * px + limbs[o + 11] * py + limbs[o + 12] * pz
	local mix = s.mix[i]
	if mix > 0 then
		o = (s.b[i] - 1) * 12
		x += (limbs[o + 1] + limbs[o + 4] * px + limbs[o + 5] * py + limbs[o + 6] * pz - x) * mix
		y += (limbs[o + 2] + limbs[o + 7] * px + limbs[o + 8] * py + limbs[o + 9] * pz - y) * mix
		z += (limbs[o + 3] + limbs[o + 10] * px + limbs[o + 11] * py + limbs[o + 12] * pz - z) * mix
	end
	return x, y, z
end

-- Puts every particle on the sculpt, at rest, as the body now stands: on spawn, a skin swap, or a teleport.
-- (2026-11-06) the wearer has died: anything held up by his power (phase 2's orbs) falls to the floor at world height floorY and settles. Garments keep simulating on the body.
function Sim.drop(s: any, floorY: number)
	s.dropY = floorY
end

function Sim.reset(s: any, limbs: { number })
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

-- One fixed step. iterations: link passes (a low graphics tier passes fewer).
function Sim.step(s: any, limbs: { number }, h: number, wind: Wind, iterations: number)
	if not s.ready then Sim.reset(s, limbs) end
	s.t += h
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
	-- the body: legs push the skirt, the back carries the hair. Volumes are placed once per step and the cloth is kept out of them on every pass, so links never pull it back in
	local caps = s.caps
	for c = 1, #caps do
		local cap = caps[c]
		local o = (cap.limb - 1) * 12
		cap.wax = limbs[o + 1] + limbs[o + 4] * cap.ax + limbs[o + 5] * cap.ay + limbs[o + 6] * cap.az
		cap.way = limbs[o + 2] + limbs[o + 7] * cap.ax + limbs[o + 8] * cap.ay + limbs[o + 9] * cap.az
		cap.waz = limbs[o + 3] + limbs[o + 10] * cap.ax + limbs[o + 11] * cap.ay + limbs[o + 12] * cap.az
		cap.wdx = limbs[o + 1] + limbs[o + 4] * cap.bx + limbs[o + 5] * cap.by + limbs[o + 6] * cap.bz - cap.wax
		cap.wdy = limbs[o + 2] + limbs[o + 7] * cap.bx + limbs[o + 8] * cap.by + limbs[o + 9] * cap.bz - cap.way
		cap.wdz = limbs[o + 3] + limbs[o + 10] * cap.bx + limbs[o + 11] * cap.by + limbs[o + 12] * cap.bz - cap.waz
		cap.len2 = math.max(cap.wdx * cap.wdx + cap.wdy * cap.wdy + cap.wdz * cap.wdz, 1e-6)
		-- a bounding sphere: most cloth is nowhere near most volumes, and one distance says so
		cap.cx, cap.cy, cap.cz = cap.wax + cap.wdx * 0.5, cap.way + cap.wdy * 0.5, cap.waz + cap.wdz * 0.5
		local reach = math.sqrt(cap.len2) * 0.5 + cap.r
		cap.reach2 = reach * reach
	end
	-- links: the sheet holds together
	local la, lb, lr, lk, pin = s.la, s.lb, s.lr, s.lk, s.pin
	local linkIds, linkRad = s.linkIds, s.linkRad
	-- every particle out of every volume it avoids
	local function keepOut()
		for i = 1, s.n do
			local ids = s.hitIds[i]
			for q = 1, #ids do
				local cap, r = caps[ids[q]], s.hitRad[i][q]
				local ex, ey, ez = X[i] - cap.cx, Y[i] - cap.cy, Z[i] - cap.cz
				if ex * ex + ey * ey + ez * ez > cap.reach2 then continue end
				local px, py, pz = X[i] - cap.wax, Y[i] - cap.way, Z[i] - cap.waz
				local u = math.clamp((px * cap.wdx + py * cap.wdy + pz * cap.wdz) / cap.len2, 0, 1)
				local qx, qy, qz = px - cap.wdx * u, py - cap.wdy * u, pz - cap.wdz * u
				local d = qx * qx + qy * qy + qz * qz
				if d < r * r and d > 1e-8 then
					local f = (r / math.sqrt(d) - 1)
					X[i], Y[i], Z[i] = X[i] + qx * f, Y[i] + qy * f, Z[i] + qz * f
				end
			end
		end
	end
	for pass = 1, iterations do
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
		keepOut()
		-- a link's middle inside a volume moves both its ends out together (a pinned end stays): the sheet cannot slice through a leg between two particles.
		-- Once a step, on the last pass, then the particles once more: the middles cost the most and the sheet between particles moves least
		if pass < iterations then continue end
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
				if d < r * r and d > 1e-8 then
					local f = (r / math.sqrt(d) - 1) * (if pi or pj then 2 else 1)
					local ox, oy, oz = qx * f, qy * f, qz * f
					if not pi then X[i], Y[i], Z[i] = X[i] + ox, Y[i] + oy, Z[i] + oz end
					if not pj then X[j], Y[j], Z[j] = X[j] + ox, Y[j] + oy, Z[j] + oz end
				end
			end
		end
		keepOut()
	end
	-- the left hand: fingers close as the palm comes to the haft and open as it leaves
	if s.palm and s.glaive then
		local o, q = (s.hand - 1) * 12, (s.glaive - 1) * 12
		local function on(m: number, v: { number }): (number, number, number)
			return limbs[m + 1] + limbs[m + 4] * v[1] + limbs[m + 5] * v[2] + limbs[m + 6] * v[3], limbs[m + 2] + limbs[m + 7] * v[1] + limbs[m + 8] * v[2] + limbs[m + 9] * v[3],
				limbs[m + 3] + limbs[m + 10] * v[1] + limbs[m + 11] * v[2] + limbs[m + 12] * v[3]
		end
		local px, py, pz = on(o, s.palm)
		local ax, ay, az = on(q, s.butt)
		local bx, by, bz = on(q, s.haftTop)
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
	-- each bone's rotation: its frame now against its frame at rest
	local R, frames = s.R, s.frames
	local lastFinger: any = nil
	for k, f in s.bones do
		if f.finger then
			-- a rigid chain on the hand: the knuckle rides the hand, the middle joint rides the knuckle, each adds its curl about the line of the haft
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
			lastFinger = { Base = m, X = f.ax, Y = f.ay, Z = f.az, WX = x, WY = y, WZ = z }
			continue
		end
		if f.orb and s.dropY then
			-- (2026-11-06) he is dead: the power that held the orbs is gone. Each falls under its own weight from where it was, strikes the floor, bounces low and rolls to rest
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
			continue
		end
		if f.orb then
			f.lastX, f.lastZ = X[f.i], Z[f.i]
			-- an orb circles the crown on its own uneven path, in the world's frame, and catches up a beat late when he moves: around his head, never strung out behind him
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
			continue
		end
		local a1, a2, a3, b1, b2, b3, c1, c2, c3 = Sim._frame(s, f, X, Y, Z, limbs)
		local r = frames[k]
		local o = (k - 1) * 9
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

return Sim
