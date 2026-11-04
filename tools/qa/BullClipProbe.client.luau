--!nonstrict
-- Studio-only sampler of the Iron Bull's authored clips in the running game (Batch 2). Insert into PlayerScripts during Play (never saved), read
-- `Players.LocalPlayer:GetAttribute("BullClipReport")`. Observes only. At each strike's first active moment (the server's own AsuraStrike record) it notes which
-- Bull track is playing, how far that track is from the contact in the manifest, where the maul or shield really is compared with the server's reach, and how far the root moved
-- across the swing. Between strikes it logs which gait the feet play and at what rate against the root's measured speed. Evidence type: live AI, seeded player protection.
if not game:GetService("RunService"):IsStudio() then return end
local Players = game:GetService("Players")
local Run = game:GetService("RunService")
local Rules = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.BossAnimationRules)
local Strike = require(game:GetService("ReplicatedStorage").AsurasPath.Simulation.StrikeGeometry)
local me = Players.LocalPlayer
local TIP = { maul = CFrame.new(0.32, -1.38, -0.75), shield = CFrame.new(-0.2, 0.0, -0.75) } -- in the hand / forearm at scale 1, from rigdef
local function bull()
	for _, m in workspace:GetDescendants() do
		if m:IsA("Model") and m:GetAttribute("AsuraLookKey") == "IronBull" and m:FindFirstChild("AsuraBossSkin") then return m end
	end
end
local names = {}
local rows, gaits, seen = {}, {}, {}
local function nameOf(model, id)
	if names[id] then return names[id] end
	for k, v in model:GetAttributes() do
		if v == id and string.sub(k, 1, 19) == "AsuraBossAnimation_" then names[id] = string.sub(k, 20); return names[id] end
	end
	return id
end
local function farthest(model, striker)
	local root = model.HumanoidRootPart.CFrame
	local skin = model.AsuraBossSkin
	local best, tip = 0, nil
	for _, p in skin:GetChildren() do
		if p:IsA("MeshPart") and string.find(p.Name, striker, 1, true) then
			local half = p.Size / 2
			for _, x in { -1, 1 } do for _, y in { -1, 1 } do for _, z in { -1, 1 } do
				local c = root:PointToObjectSpace((p.CFrame * CFrame.new(half.X * x, half.Y * y, half.Z * z)).Position)
				local r = Vector2.new(c.X, c.Z).Magnitude
				if r > best then best, tip = r, c end
			end end end
		end
	end
	return best, tip
end
local pending = nil
local rootAt = {}
local last, lastAt = nil, os.clock()
Run.RenderStepped:Connect(function()
	local model = bull()
	if not model then return end
	local root = model.HumanoidRootPart
	local now = workspace:GetServerTimeNow()
	local raw = model:GetAttribute("AsuraStrike")
	if type(raw) == "string" and not seen[raw] then
		local f = string.split(raw, "|")
		local at = tonumber(f[5])
		if at and f[10] then
			seen[raw] = true
			pending = { at = at, active = tonumber(f[6]), move = f[10], reach = tonumber(f[2]), lunge = tonumber(f[3]), arc = tonumber(f[1]), root0 = root.Position }
		end
	end
	if pending and now >= pending.at then
		local p = pending
		pending = nil
		local a = model:FindFirstChildOfClass("Humanoid"):FindFirstChildOfClass("Animator")
		local tracks = {}
		local err = "no track"
		for _, t in a:GetPlayingAnimationTracks() do
			local n = nameOf(model, t.Animation.AnimationId)
			table.insert(tracks, n .. "@" .. string.format("%.3f", t.TimePosition))
			local action = string.match(n, "IronBull_P1_Oath_(.+)") or string.match(n, "IronBull_P1_(.+)")
			local contacts = action and Rules.Contacts.IronBull[action]
			if contacts then err = string.format("%+.3f", t.TimePosition - contacts[1]) end
		end
		local striker = if p.move == "IronBullMaul_L2" or p.move == "IronBullMaul_Running" then "Shield" else "Weapon"
		local r, tip = farthest(model, striker)
		local me_ = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
		local target = me_ and (me_.Position - root.Position) * Vector3.new(1, 0, 1)
		table.insert(rows, string.format("%s clipErr %s tip %.2f (%.1f,%.1f,%.1f) reach %.1f+%.2f player %.1f rootMoved %.2f late %.3f [%s]", p.move, err, r, tip and tip.X or 0, tip and tip.Y or 0, tip and tip.Z or 0,
			p.reach, p.lunge * 0.35, target and target.Magnitude or -1, (root.Position - p.root0).Magnitude, now - p.at, table.concat(tracks, ",")))
		me:SetAttribute("BullClipReport", table.concat(rows, "\n") .. "\nGAITS " .. table.concat(gaits, " "))
	end
	local clock = os.clock()
	if clock - lastAt >= 0.5 then
		local speed = if last then ((root.Position - last) * Vector3.new(1, 0, 1)).Magnitude / (clock - lastAt) else 0
		last, lastAt = root.Position, clock
		local a = model:FindFirstChildOfClass("Humanoid"):FindFirstChildOfClass("Animator")
		local best = "none"
		for _, t in a:GetPlayingAnimationTracks() do
			if t.Priority == Enum.AnimationPriority.Movement and t.WeightTarget > 0 then best = string.gsub(nameOf(model, t.Animation.AnimationId), "IronBull_P1_", "") .. string.format("x%.2f", t.Speed) end
		end
		if #gaits < 200 then table.insert(gaits, string.format("%.1f:%s", speed, best)) end
		me:SetAttribute("BullClipReport", table.concat(rows, "\n") .. "\nGAITS " .. table.concat(gaits, " "))
	end
end)
