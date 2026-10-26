--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/CameraClearance
-- Post-F26 Step 4. A hostile body that stands between the lens and the player (nearer the camera
-- than the player, and not the locked target) is drawn see-through on this client only. Studio: with
-- the Iron Bull locked, General Zhao flanked beside the lens and covered 35% of the frame (62% peak).
-- The camera spherecast ignores fighters by design, so this fade is the clearance for bodies. Purely
-- visual: hurtboxes, telegraphs and the server are untouched; the faded body keeps its silhouette.
local Clearance = {}

Clearance.Fade = 0.6 -- LocalTransparencyModifier for a body in the lens's near field
Clearance.Margin = 1.5 -- studs nearer the camera than the player before a body counts as in front
Clearance.Range = 30 -- only bodies this close to the player (the fight, not the far arena)

-- Whether a body fades: nearer the lens than the player by Margin, near the player, not locked.
function Clearance.shouldFade(cameraToBody: number, cameraToPlayer: number, bodyToPlayer: number, locked: boolean): boolean
	return not locked and bodyToPlayer <= Clearance.Range and cameraToBody < cameraToPlayer - Clearance.Margin
end

local faded: { [Model]: { BasePart } } = {}

local function setFade(model: Model, value: number)
	local parts = faded[model]
	if not parts then
		parts = {}
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 1 then table.insert(parts, d) end
		end
		faded[model] = parts
	end
	for _, part in parts do
		if part.Parent then part.LocalTransparencyModifier = value end
	end
	if value == 0 then faded[model] = nil end
end

-- Called once per camera frame with the hostile, living bodies the camera knows about.
function Clearance.step(bodies: { { Model: Model, Root: BasePart, Locked: boolean } }, cameraPosition: Vector3, playerPosition: Vector3)
	local keep: { [Model]: boolean } = {}
	local toPlayer = (playerPosition - cameraPosition).Magnitude
	for _, body in bodies do
		local position = body.Root.Position
		if Clearance.shouldFade((position - cameraPosition).Magnitude, toPlayer, (position - playerPosition).Magnitude, body.Locked) then
			keep[body.Model] = true
			setFade(body.Model, Clearance.Fade)
		end
	end
	for model in faded do
		if not keep[model] then setFade(model, 0) end
	end
end

function Clearance.clear()
	for model in faded do setFade(model, 0) end
end

-- Post-F26 step 6. Crane: the extra downward pitch (radians) for a boom squeezed to `ratio` of its
-- length by world geometry, so a wall behind the player lifts the lens instead of pressing it into
-- their back (Studio: the sealed Twins fog gate held it 4.5 studs off the head, ratio 0.43).
Clearance.CraneMax, Clearance.CraneFrom, Clearance.CraneFull = math.rad(35), 0.8, 0.35
function Clearance.crane(ratio: number): number
	return Clearance.CraneMax * math.clamp((Clearance.CraneFrom - ratio) / (Clearance.CraneFrom - Clearance.CraneFull), 0, 1)
end

-- Own body: see-through once the lens is within OwnNear studs of the pivot (a squeezed boom).
Clearance.OwnNear = 4
function Clearance.ownFade(lensToPivot: number): number
	return 0.7 * math.clamp((Clearance.OwnNear - lensToPivot) / 2.5, 0, 1)
end
local ownModel: Model?, ownValue = nil, 0
function Clearance.own(model: Model, lensToPivot: number)
	local value = math.floor(Clearance.ownFade(lensToPivot) * 20 + 0.5) / 20
	if model == ownModel and value == ownValue then return end
	ownModel, ownValue = model, value
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then d.LocalTransparencyModifier = value end
	end
end

-- Roofs over walkable lofts are decor the camera probe passes through (Rafters drum tower). A folder
-- tagged AsuraCameraFade fades while the lens-to-head line crosses, or the lens sits inside, its box.
Clearance.RoofFade, Clearance.RoofMargin = 0.8, 1.5
type Box = { Min: Vector3, Max: Vector3, Parts: { BasePart } }
local boxes: { [Instance]: Box } = {}
local roofs: { [Instance]: boolean } = {}
local function boxOf(folder: Instance): Box
	local box = boxes[folder]
	if box then return box end
	local lo, hi, parts = Vector3.one * math.huge, -Vector3.one * math.huge, {}
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			local cf, h = d.CFrame, d.Size * 0.5
			local a, b, c = cf.RightVector * h.X, cf.UpVector * h.Y, cf.LookVector * h.Z
			local ext = Vector3.new(math.abs(a.X) + math.abs(b.X) + math.abs(c.X), math.abs(a.Y) + math.abs(b.Y) + math.abs(c.Y), math.abs(a.Z) + math.abs(b.Z) + math.abs(c.Z))
			lo, hi = lo:Min(d.Position - ext), hi:Max(d.Position + ext)
		end
	end
	box = { Min = lo, Max = hi, Parts = parts }
	boxes[folder] = box
	return box
end
-- Slab test: does the segment a->b cross the box (or start inside it)?
function Clearance.crosses(a: Vector3, b: Vector3, lo: Vector3, hi: Vector3): boolean
	local t0, t1, d = 0, 1, b - a
	for _, axis in { "X", "Y", "Z" } do
		local o, v, l, h = (a :: any)[axis], (d :: any)[axis], (lo :: any)[axis], (hi :: any)[axis]
		if math.abs(v) < 1e-9 then
			if o < l or o > h then return false end
		else
			local u0, u1 = (l - o) / v, (h - o) / v
			if u0 > u1 then u0, u1 = u1, u0 end
			t0, t1 = math.max(t0, u0), math.min(t1, u1)
			if t0 > t1 then return false end
		end
	end
	return true
end
function Clearance.roofs(lens: Vector3, head: Vector3)
	-- Resolve the engine service here so the pure clearance rules still load in offline regressions.
	local CollectionService = game:GetService("CollectionService")
	for _, folder in CollectionService:GetTagged("AsuraCameraFade") do
		local box = boxOf(folder)
		local hide = (box.Min + box.Max) * 0.5 - head
		local pad = Vector3.one * Clearance.RoofMargin -- a lens tucked just under the eave counts too
		local near = hide.Magnitude < 60 and Clearance.crosses(lens, head, box.Min - pad, box.Max + pad)
		if near ~= (roofs[folder] == true) then
			roofs[folder] = near or nil
			for _, part in box.Parts do if part.Parent then part.LocalTransparencyModifier = if near then Clearance.RoofFade else 0 end end
		end
	end
end

return Clearance
