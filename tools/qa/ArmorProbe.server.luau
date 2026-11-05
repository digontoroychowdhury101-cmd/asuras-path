--!nonstrict
-- Unmapped Studio-only probe for the armour batch. Lives only in the private copy tools/qa/qa_place.py builds (never publish or save back);
-- answers ServerStorage.ArmorQA:Invoke(op, ...). "grant" seeds a suit into the record: a labelled diagnostic, not earned play.
-- Every other op only reads, or drives the same service paths the game uses.
local Run = game:GetService("RunService")
if not Run:IsStudio() then return end
local SSS = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local Characters = require(SSS.AsurasPath.Services.CharacterService)
local Persistence = require(SSS.AsurasPath.Services.PersistenceService)
local Armor = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.ArmorRules)

local function me()
	local p = Players:GetPlayers()[1]
	return p, p and Characters.GetEntity(p.UserId)
end
local ops = {}
function ops.info()
	local p, e = me()
	if not e then return "no entity" end
	local f, m = e.Fighter, e.Model
	local rec = Persistence.Get(p.UserId)
	local folder = m:FindFirstChild("AsuraArmor")
	local visible, parts, welds = 0, 0, 0
	for _, c in m:GetChildren() do
		if c:IsA("BasePart") and c.Name ~= "HumanoidRootPart" and c.Transparency < 1 then visible += 1 end
	end
	local anchored, solid, massy = 0, 0, 0
	if folder then
		for _, c in folder:GetChildren() do
			parts += 1
			if c:FindFirstChildOfClass("WeldConstraint") then welds += 1 end
			if c.Anchored then anchored += 1 end
			if c.CanCollide or c.CanQuery or c.CanTouch then solid += 1 end
			if not c.Massless then massy += 1 end
		end
	end
	local attire = m:FindFirstChild("AsuraAttire")
	return string.format("worn=%s owned=%s attr=%s prot=%.3f speedx=%.3f posture=%s walk=%.2f hp=%s/%s folder=%s parts=%d welds=%d anchored=%d solid=%d massy=%d visibleLimbs=%d attire=%d weapon=%s state=%s",
		tostring(rec and rec.equippedLoadout.ArmorSet), game:GetService("HttpService"):JSONEncode(rec and rec.inventory.Armor or {}), tostring(m:GetAttribute("AsuraArmorSet")),
		f.Protection, f.ArmorSpeed, tostring(f.PostureCapacity), m:FindFirstChildOfClass("Humanoid").WalkSpeed, tostring(f.ActiveHP), tostring(f.MaxHP),
		tostring(folder and folder:GetAttribute("Set")), parts, welds, anchored, solid, massy, visible, attire and #attire:GetChildren() or -1, tostring(m:FindFirstChild("AsuraWeapon") ~= nil), tostring(f.State))
end
function ops.grant(set, level) -- SEEDED
	local p = me()
	local ok, err = Persistence.Transaction(p.UserId, function(r)
		r.inventory.Armor[set] = { Level = level or 0 }
		r.equippedLoadout.ArmorSet = set
	end)
	if ok then Characters.ApplyArmor(p.UserId) end
	return tostring(ok) .. " " .. tostring(err)
end
function ops.unlock(kind, id) -- SEEDED: an altar rested at or a boss beaten, for the panel's requirement gates
	local p = me()
	return tostring((Persistence.Transaction(p.UserId, function(r)
		if kind == "altar" then r.unlockedAltars[id] = true else r.defeatedBosses[id] = true end
	end)))
end
function ops.place(x, y, z, lx, lz) -- SEEDED: test setup only, moves the rig
	local _, e = me()
	e.Model:PivotTo(CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(lx or x, y, lz or z + 1)))
	return "placed"
end
function ops.foes(radius) -- nearby hostile rigs, nearest first
	local _, e = me()
	local at, out = e.Model:GetPivot().Position, {}
	for _, m in workspace:GetDescendants() do
		if m:IsA("Model") and m ~= e.Model and m:FindFirstChildOfClass("Humanoid") and m:FindFirstChild("HumanoidRootPart") then
			local d = (m:GetPivot().Position - at).Magnitude
			if d < (radius or 400) then table.insert(out, { d, m.Name, m:GetPivot().Position }) end
		end
	end
	table.sort(out, function(a, b) return a[1] < b[1] end)
	local s = {}
	for i = 1, math.min(12, #out) do s[i] = string.format("%.0f %s %.0f,%.0f,%.0f", out[i][1], out[i][2], out[i][3].X, out[i][3].Y, out[i][3].Z) end
	return table.concat(s, "\n")
end
function ops.watch(seconds) -- every health loss the fighter takes in the window, as the combat rules applied it
	local _, e = me()
	local f, last, t0, log = e.Fighter, nil, os.clock(), {}
	last = f.ActiveHP
	while os.clock() - t0 < (seconds or 10) do
		task.wait()
		if f.ActiveHP < last - 0.001 then
			table.insert(log, string.format("t=%.1f -%.2f (prot=%.2f state=%s)", os.clock() - t0, last - f.ActiveHP, f.Protection, tostring(f.State)))
		end
		last = f.ActiveHP
	end
	return #log .. " hits: " .. table.concat(log, "; ") .. " | hp=" .. tostring(f.ActiveHP)
end
function ops.fund(qi, ore, shard) -- SEEDED
	local p = me()
	return tostring((Persistence.Transaction(p.UserId, function(r)
		r.qiEssence = qi; r.inventory.Materials.SpiritIronOre = ore; r.inventory.Materials.StarfallShard = shard
	end)))
end
function ops.wear(set)
	local p = me()
	local ok = Persistence.Transaction(p.UserId, function(r) r.equippedLoadout.ArmorSet = set end)
	Characters.ApplyArmor(p.UserId)
	return tostring(ok)
end
function ops.weapon(id) -- SEEDED: hands the fighter a weapon through the same path a swap ends in
	local _, e = me()
	Characters.ForceWeapon(e.Id, id)
	return tostring(e.Fighter.Weapon)
end
function ops.die()
	local _, e = me()
	e.Model:FindFirstChildOfClass("Humanoid").Health = 0
	return "killed"
end
function ops.tracks()
	local _, e = me()
	local out = {}
	for _, t in e.Model:FindFirstChildOfClass("Humanoid"):FindFirstChildOfClass("Animator"):GetPlayingAnimationTracks() do
		table.insert(out, string.format("%s %s w=%.2f t=%.2f/%.2f", t.Name, t.Animation and t.Animation.AnimationId or "?", t.WeightCurrent, t.TimePosition, t.Length))
	end
	return table.concat(out, "\n")
end
function ops.limbcheck() -- the suit against the rig: every piece on its limb, every hurtbox still as it was
	local _, e = me()
	local m = e.Model
	local folder = m:FindFirstChild("AsuraArmor")
	if not folder then return "no suit" end
	local worst, n = 0, 0
	for _, c in folder:GetChildren() do
		local limb = m:FindFirstChild(c:GetAttribute("AsuraBone"))
		local bind = c:FindFirstChild("AsuraBind")
		local err = (c.CFrame.Position - (limb.CFrame * bind.CFrame:Inverse()).Position).Magnitude
		worst = math.max(worst, err); n += 1
	end
	local sizes = {}
	for _, name in { "UpperTorso", "LowerTorso", "RightUpperArm", "LeftUpperLeg", "Head" } do
		local l = m:FindFirstChild(name)
		table.insert(sizes, name .. "=" .. tostring(l.Size) .. "/collide=" .. tostring(l.CanCollide) .. "/query=" .. tostring(l.CanQuery))
	end
	return string.format("pieces=%d worstWeldDrift=%.4f %s", n, worst, table.concat(sizes, " "))
end
-- Newer Studio builds will not let the MCP thread invoke this script, so the private QA copy runs one fixed sequence and prints it.
local function say(...) print("[ArmorQA]", ...) end
local function waitReady()
	while true do
		local p, e = me()
		if p and e and e.Model.Parent and Persistence.Get(p.UserId) then return p, e end
		task.wait(.25)
	end
end
local function suit(label)
	local _, e = me()
	local m = e.Model
	local n, bad, f = 0, 0, m:FindFirstChild("AsuraArmor")
	if f then
		for _, c in f:GetChildren() do
			n += 1
			local w = c:FindFirstChildOfClass("WeldConstraint")
			if not w or not w.Part0 or w.Part0.Parent ~= m then bad += 1 end
		end
	end
	local weaponParts = 0
	for _, c in m:GetDescendants() do
		if c:IsA("BasePart") and (c.Name:find("Weapon") or c.Name:find("Jian") or c.Name:find("Dao") or c.Name:find("Blade")) then weaponParts += 1 end
	end
	local folders = 0
	for _, c in m:GetChildren() do if c.Name == "AsuraArmor" then folders += 1 end end
	say(label, string.format("weapon=%s(%s) weaponParts=%d set=%s folders=%d pieces=%d badWelds=%d handHidden=%s prot=%.2f speedx=%.2f posture=%s walk=%.2f",
		tostring(m:GetAttribute("AsuraWeapon")), tostring(e.Fighter.Weapon), weaponParts, tostring(m:GetAttribute("AsuraArmorSet")), folders, n, bad,
		tostring(m.RightHand.Transparency == 1), e.Fighter.Protection, e.Fighter.ArmorSpeed, tostring(e.Fighter.PostureCapacity), m:FindFirstChildOfClass("Humanoid").WalkSpeed))
end
task.spawn(function()
	waitReady()
	task.wait(4)
	say("start: every value below is a SEEDED diagnostic in a private QA copy")
	ops.grant("IronOath", 0)
	ops.grant("CinnabarGuard", 5)
	suit("worn cinnabar+5")
	-- weapon switching with the suit on
	for _, w in { "Dao", "Spear", "Jian", "Dao", "Jian" } do
		local ok, err = pcall(ops.weapon, w)
		task.wait(.4)
		say("weapon", w, ok, ok and "" or err)
		suit("after " .. w)
	end
	-- a real avatar description applied late: the engine replaces the limbs under the suit
	local _, e = me()
	local hum = e.Model:FindFirstChildOfClass("Humanoid")
	local ok, err = pcall(function()
		local d = Instance.new("HumanoidDescription")
		d.HeightScale, d.WidthScale, d.DepthScale, d.HeadScale = 1, 1, 1, 1
		d.Torso, d.RightArm, d.LeftArm, d.RightLeg, d.LeftLeg = 27112025, 27112039, 27112056, 27112052, 27112068
		hum:ApplyDescription(d)
	end)
	say("late avatar description applied", ok, ok and "" or tostring(err))
	task.wait(1.5)
	suit("after late avatar")
	say("sizes", ops.limbcheck())
	-- cinnabar +5 against the same monk cadence as the bare and Iron Oath rounds
	ops.place(0, 4, -778, 0, -786)
	task.wait(.5)
	say("cinnabar round", ops.watch(12))
	ops.die()
	task.wait(9)
	suit("respawned in cinnabar")
	ops.wear("IronOath")
	task.wait(1)
	suit("iron oath left on for pose captures")
	say("done")
end)
