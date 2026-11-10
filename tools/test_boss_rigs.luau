--!nonstrict
-- Boss rig pivots (src/shared/BossRigs.luau) on emulated AnimationConstraint rigs: Lune's datatypes through tools/roblox_shim.luau, so
-- this checks the attachment arithmetic, not the engine's joint solver or a Studio view. Every template's joint points land where it
-- says with the limbs left where they were, its helper bones sit on their points, a repeat apply changes nothing, and a form change
-- re-points a helper the earlier form built. (2026-11-11) Grandmaster Shen's phase 2 kept phase 1's glaive point: apply() skipped the
-- helper phase 1 had built, so the weapon sat 0.17 off his grip in every phase 2 clip (Studio playback of the exported clips against
-- the solver, outputs/grandmaster-shen-2026-11-05/repair/windows-pass-2026-11-09/REPORT.md).
local roblox = require("@lune/roblox")
local Scene = require("./rig_scene")
local Rigs = Scene.load("src/shared/BossRigs.luau", {})
local CF, Instance = Scene.CF, roblox.Instance

local passed, failed = 0, 0
local function check(name: string, condition: any)
	if condition then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local function near(a, b) return a ~= nil and b ~= nil and (a - b).Magnitude <= 1e-4 end

-- A default-proportioned R15 rig whose joints are AnimationConstraints at stock points (halfway between the two parts' centres).
local function rig(def)
	local actor = Scene.rig("Boss")
	for _, joint in def.Joints do
		local limb, parent = actor:FindFirstChild(joint.Bone), actor:FindFirstChild(joint.Parent)
		local pivot = CF.new((limb.Position + parent.Position) * 0.5)
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Name, a1.Name = joint.Motor .. "RigAttachment", joint.Motor .. "RigAttachment"
		a0.CFrame, a0.Parent = parent.CFrame:ToObjectSpace(pivot), parent
		a1.CFrame, a1.Parent = limb.CFrame:ToObjectSpace(pivot), limb
		local constraint = Instance.new("AnimationConstraint")
		constraint.Name, constraint.Attachment0, constraint.Attachment1 = joint.Motor, a0, a1
		constraint.Parent = limb
	end
	return actor
end

local function count(actor, name)
	local n = 0
	for _, child in actor:GetChildren() do if child.Name == name then n += 1 end end
	return n
end

-- A helper's joint point in root space, read from its parent's side, as the clips are made about it.
local function helperAt(actor, rest, helper)
	local part = actor:FindFirstChild(helper.Bone)
	local joint = part and part:FindFirstChild(helper.Bone)
	return joint and joint.Attachment0 and rest[helper.Parent] and (rest[helper.Parent] * joint.Attachment0.CFrame).Position
end

-- Every joint's pivot seen from both its parts, and every helper's, against the template's points at this scale.
local function pivotsAt(actor, def, scale, label)
	local rest = Rigs.rest(actor, def)
	local worst = 0
	for _, joint in def.Joints do
		local c = actor:FindFirstChild(joint.Bone):FindFirstChild(joint.Motor)
		local p0 = (rest[joint.Parent] * c.Attachment0.CFrame).Position
		local p1 = (rest[joint.Bone] * c.Attachment1.CFrame).Position
		worst = math.max(worst, (p0 - joint.At * scale).Magnitude, (p1 - joint.At * scale).Magnitude)
	end
	check(string.format("%s: every joint pivot on its declared point (worst %.2g)", label, worst), worst < 1e-4)
	for _, helper in def.Helpers do
		check(label .. ": one " .. helper.Bone .. " helper", count(actor, helper.Bone) == 1)
		check(label .. ": the " .. helper.Bone .. " joint on its declared point", near(helperAt(actor, rest, helper), helper.At * scale))
	end
	return rest
end

local function unmoved(before, after)
	for bone, frame in before do
		if not after[bone] or not frame:FuzzyEq(after[bone], 1e-4) then return false end
	end
	return true
end

-- Every template on its own rig: pivots and helpers where declared, no limb moved, and a second apply changes nothing.
local names = {}
for name in Rigs.ByTemplate do table.insert(names, name) end
table.sort(names)
for _, name in names do
	local def = Rigs.ByTemplate[name]
	local actor = rig(def)
	local stock = Rigs.rest(actor, def)
	local ok, why = Rigs.apply(actor, def)
	check(name .. " applies (" .. tostring(why) .. ")", ok)
	local rest = pivotsAt(actor, def, 1, name)
	check(name .. ": no limb moved (rest frames read back unchanged)", unmoved(stock, rest))
	Rigs.apply(actor, def)
	pivotsAt(actor, def, 1, name .. " applied twice")
end

-- Grandmaster Shen's form change: phase 2 applies over the actor phase 1 built. The glaive helper keeps its part and joint (what is welded
-- to it stays welded) and its joint moves to phase 2's glaive point; a later phase 1 apply moves it back.
local P1, P2 = Rigs.ByTemplate.AsuraBoss_GrandmasterShen_P1, Rigs.ByTemplate.AsuraBoss_GrandmasterShen_P2
local glaive1, glaive2 = P1.Helpers[1], P2.Helpers[1]
check("Shen: both forms carry the glaive helper on the same parent", glaive1.Bone == "Glaive" and glaive2.Bone == "Glaive" and glaive1.Parent == glaive2.Parent)
check("Shen: the two forms' glaive points differ (else this test proves nothing)", (glaive2.At - glaive1.At).Magnitude > 0.05)
local function shen(scale)
	local label = "Shen at scale " .. scale
	local actor = rig(P1)
	if scale ~= 1 then actor:ScaleTo(scale) end
	local stock = Rigs.rest(actor, P1)
	check(label .. ": phase 1 applies", (Rigs.apply(actor, P1)))
	pivotsAt(actor, P1, scale, label .. ", phase 1")
	local part = actor:FindFirstChild("Glaive")
	local joint = part and part:FindFirstChild("Glaive")
	local a0 = joint and joint.Attachment0
	check(label .. ": phase 2 applies over phase 1", (Rigs.apply(actor, P2)))
	local rest2 = pivotsAt(actor, P2, scale, label .. ", phase 2 after phase 1")
	check(label .. ": phase 2 keeps phase 1's glaive part, joint and attachment", part ~= nil and actor:FindFirstChild("Glaive") == part
		and part:FindFirstChild("Glaive") == joint and joint.Attachment0 == a0)
	check(label .. ": phase 2's glaive is not left on phase 1's point", not near(helperAt(actor, rest2, glaive2), glaive1.At * scale))
	check(label .. ": no limb moved through the form change", unmoved(stock, rest2))
	check(label .. ": phase 1 again", (Rigs.apply(actor, P1)))
	pivotsAt(actor, P1, scale, label .. ", phase 1 after phase 2")
end
shen(1)
shen(1.5)

print(string.format("boss rigs: %d passed, %d failed (emulated attachments; the engine's solver and Studio playback are separate)", passed, failed))
if failed > 0 then error("boss rigs regression failed") end
