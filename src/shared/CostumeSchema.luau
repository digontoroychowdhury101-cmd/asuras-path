--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/CostumeSchema
-- Data contract for authored character looks (batches 11-14). A Look is a list of welded pieces,
-- each bound to one rig limb (R15 name) or, for creatures, to the HumanoidRootPart; offsets are
-- studs from that limb's centre at scale 1 (CostumeKit builds before Model:ScaleTo, so a boss
-- scales with its costume). `Fit` pieces grow the live limb's size; `Face` places a piece on the
-- live limb's surface. Phase-tagged pieces show only in that phase; Joint names the procedural
-- role a creature controller animates. Production skins replace a look through BossSkin using the
-- template names below; the look stays as the diagnosed fallback.
local Schema = {}

export type Piece = {
	Name: string, Bone: string, Size: { number }, At: { number }?, Rot: { number }?, Face: { number }?,
	Color: { number }, Material: string, Shape: string?, Phase: number?, Joint: string?, Glow: number?,
	Fit: boolean?, Role: string?, Transparency: number?, Pivot: { number }?, Pivot2: { number }?, -- hinge (and parent hinge for a wing tip), same space as At
}
export type Look = {
	Key: string, Rig: string, HideBody: boolean?, OwnWeapon: boolean?, Phases: number?, Pieces: { Piece },
	Hull: { number }?, Budget: number?, Body: { { number } }?, Body2: { { number } }?, -- { skin, cloth } per phase
	Look: { number }?, -- standing figures: the ground point (x, z) they face
}

Schema.Bones = table.freeze({ "Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm",
	"RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot", "HumanoidRootPart" })
Schema.Materials = table.freeze({ "Fabric", "Metal", "Wood", "SmoothPlastic", "Neon", "Slate", "Rock", "Basalt", "Granite", "Marble", "Leather",
	"Ice", "Glass", "Foil", "DiamondPlate", "CorrodedMetal", "Pebble", "Sand", "Limestone", "Plastic", "Cobblestone", "Grass", "LeafyGrass", "CrackedLava" })
Schema.Shapes = table.freeze({ "Block", "Ball", "Cylinder", "Wedge" })
Schema.Joints = table.freeze({ "LegFL", "LegFR", "LegHL", "LegHR", "WingL", "WingR", "WingTipL", "WingTipR", "Tail1", "Tail2", "Tail3",
	"Tail4", "Tail5", "Neck", "Jaw", "Mane", "Orbit", "Sleeve" })
-- What a production skin must cover before it may hide the rig (BossSkin hides every rig limb, so a
-- humanoid skin must cover all fifteen or the uncovered hands/feet/forearms would vanish).
Schema.RequiredBones = table.freeze({
	Humanoid = table.freeze({ "Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm",
		"RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" }),
	Creature = table.freeze({ "HumanoidRootPart" }),
})
Schema.DefaultBudget = 160 -- welded pieces per actor; normal enemies and NPCs set lower budgets

-- Nominal default-R15 limb sizes and rest centres relative to the root (scale 1); offline checks
-- use them, the live kit reads the real limbs. Feet rest on Schema.Ground below the root.
Schema.Ground = -3
Schema.R15 = table.freeze({
	HumanoidRootPart = { Size = { 2, 2, 1 }, At = { 0, 0, 0 } }, Head = { Size = { 1.2, 1.2, 1.2 }, At = { 0, 1.8, 0 } },
	UpperTorso = { Size = { 2, 1.6, 1 }, At = { 0, 0.6, 0 } }, LowerTorso = { Size = { 2, 0.4, 1 }, At = { 0, -0.4, 0 } },
	LeftUpperArm = { Size = { 1, 1.17, 1 }, At = { -1.5, 0.75, 0 } }, RightUpperArm = { Size = { 1, 1.17, 1 }, At = { 1.5, 0.75, 0 } },
	LeftLowerArm = { Size = { 1, 1.05, 1 }, At = { -1.5, -0.25, 0 } }, RightLowerArm = { Size = { 1, 1.05, 1 }, At = { 1.5, -0.25, 0 } },
	LeftHand = { Size = { 1, 0.3, 1 }, At = { -1.5, -0.95, 0 } }, RightHand = { Size = { 1, 0.3, 1 }, At = { 1.5, -0.95, 0 } },
	LeftUpperLeg = { Size = { 1, 1.22, 1 }, At = { -0.5, -1.2, 0 } }, RightUpperLeg = { Size = { 1, 1.22, 1 }, At = { 0.5, -1.2, 0 } },
	LeftLowerLeg = { Size = { 1, 1.19, 1 }, At = { -0.5, -2.2, 0 } }, RightLowerLeg = { Size = { 1, 1.19, 1 }, At = { 0.5, -2.2, 0 } },
	LeftFoot = { Size = { 1, 0.3, 1 }, At = { -0.5, -2.85, 0 } }, RightFoot = { Size = { 1, 0.3, 1 }, At = { 0.5, -2.85, 0 } },
})

-- Compact constructor for look tables: P(name, bone, {sx,sy,sz}, {x,y,z}, color, material, extra).
function Schema.P(name: string, bone: string, size: { number }, at: { number }?, color: { number }, material: string, extra: { [string]: any }?): Piece
	local piece: any = { Name = name, Bone = bone, Size = size, At = at, Color = color, Material = material }
	local options: { [string]: any } = extra or {}
	for key, value in options do piece[key] = value end
	return piece :: Piece
end

function Schema.visible(piece: Piece, phase: number): boolean
	return piece.Phase == nil or piece.Phase == phase
end

-- Production template names, most specific first. `key` is the actor's look key (each Twin has
-- its own); legacy encounter/animation-set names stay accepted.
function Schema.templates(key: string, phase: number, encounter: string?, set: string?): { string }
	local names = { "AsuraBoss_" .. key .. "_P" .. phase, "AsuraBoss_" .. key }
	if encounter and encounter ~= key then
		if set then table.insert(names, "AsuraBoss_" .. encounter .. "_" .. set) end
		table.insert(names, "AsuraBoss_" .. encounter)
	end
	return names
end

-- Offline size of a piece: Fit pieces grow the nominal limb.
function Schema.size(piece: Piece): { number }
	if not piece.Fit then return piece.Size end
	local limb = Schema.R15[piece.Bone]
	local base = if limb then limb.Size else { 1, 1, 1 }
	return { base[1] + piece.Size[1], base[2] + piece.Size[2], base[3] + piece.Size[3] }
end

-- Offline centre of a piece relative to the root at scale 1 (rotation about its own centre only).
function Schema.centre(piece: Piece): { number }
	local limb = Schema.R15[piece.Bone]
	local base, half = limb.At, { limb.Size[1] / 2, limb.Size[2] / 2, limb.Size[3] / 2 }
	local at, face = piece.At or { 0, 0, 0 }, piece.Face or { 0, 0, 0 }
	return { base[1] + at[1] + face[1] * half[1], base[2] + at[2] + face[2] * half[2], base[3] + at[3] + face[3] * half[3] }
end

local function member(list: { string }, value: string?): boolean
	return value ~= nil and table.find(list, value) ~= nil
end

function Schema.validate(look: Look): (boolean, { string })
	local problems: { string } = {}
	local function fail(text: string) table.insert(problems, look.Key .. ": " .. text) end
	if look.Rig ~= "Humanoid" and look.Rig ~= "Creature" then fail("unknown rig " .. tostring(look.Rig)) end
	if look.Rig == "Creature" and not look.HideBody then fail("creature looks must hide the humanoid body") end
	if #look.Pieces > (look.Budget or Schema.DefaultBudget) then fail(string.format("%d pieces over budget %d", #look.Pieces, look.Budget or Schema.DefaultBudget)) end
	for _, piece in look.Pieces do
		local label = piece.Name
		if not member(Schema.Bones, piece.Bone) then fail(label .. " has unknown bone " .. tostring(piece.Bone)) end
		if look.Rig == "Creature" and piece.Bone ~= "HumanoidRootPart" then fail(label .. " must bind to the root") end
		if not member(Schema.Materials, piece.Material) then fail(label .. " has unknown material " .. tostring(piece.Material)) end
		if piece.Shape and not member(Schema.Shapes, piece.Shape) then fail(label .. " has unknown shape") end
		if piece.Joint and not member(Schema.Joints, piece.Joint) then fail(label .. " has unknown joint " .. piece.Joint) end
		if piece.Phase and (piece.Phase < 1 or piece.Phase > (look.Phases or 1)) then fail(label .. " phase out of range") end
		local size = Schema.size(piece)
		for axis = 1, 3 do
			if type(size[axis]) ~= "number" or size[axis] < 0.04 or size[axis] > 60 then fail(label .. " has an invalid size") end
		end
		for channel = 1, 3 do
			local c = piece.Color[channel]
			if type(c) ~= "number" or c < 0 or c > 255 then fail(label .. " has an invalid colour") end
		end
	end
	return #problems == 0, problems
end

return table.freeze(Schema)
