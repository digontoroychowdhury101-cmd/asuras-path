-- AR00 measured prototypes (Studio Edit, temporary place only; never saved). Builds, at each arena's
-- planned coordinates, two UNTEXTURED blockouts (A ~0.8, B 1.0): floor, a low visible boundary cue,
-- the north gate, a far landmark, the boss at roster scale (real template where present, a labelled
-- proxy box where the model file is missing) and an R15 player at the fog gate's inside point.
-- Remove with: workspace.AR00_Prototypes:Destroy()
local Players = game:GetService("Players")
local HS = game:GetService("HttpService")
local lib = game:GetService("ServerStorage"):FindFirstChild("AsuraAssets")
local plan = HS:JSONDecode([[PLAN_JSON]])
local old = workspace:FindFirstChild("AR00_Prototypes")
if old then old:Destroy() end
local root = Instance.new("Folder")
root.Name = "AR00_Prototypes"
root.Parent = workspace

local function part(parent, name, size, cf, color, transp)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color
	p.Anchored, p.Material, p.TopSurface, p.BottomSurface = true, Enum.Material.SmoothPlastic, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Transparency = transp or 0
	p:SetAttribute("AR00Prototype", "UNTEXTURED BLOCKOUT")
	p.Parent = parent
	return p
end
local function label(parent, text, at, h)
	local a = part(parent, "Label", Vector3.new(1, 1, 1), CFrame.new(at), Color3.new(1, 1, 1), 1)
	a.CanCollide = false
	local g = Instance.new("BillboardGui")
	g.Size, g.AlwaysOnTop, g.LightInfluence = UDim2.fromOffset(360, h or 40), true, 0
	g.Parent = a
	local t = Instance.new("TextLabel")
	t.Size, t.BackgroundTransparency, t.Text, t.TextScaled = UDim2.fromScale(1, 1), 0.35, text, true
	t.BackgroundColor3, t.TextColor3, t.Font = Color3.new(0, 0, 0), Color3.new(1, 1, 1), Enum.Font.GothamBold
	t.Parent = g
end
local proxies = {
	VenerableBaize = { Vector3.new(5.4, 6.3, 10.8), "Baize PROXY (Beast box x1.5; model file missing)" },
	AzureWyrm = { Vector3.new(9.2, 10.6, 21.6), "Wyrm PROXY (Dragon box x2.2, no wings; model file missing)" },
	SlumberingTitan = { Vector3.new(11, 17.7, 8), "Titan PROXY (x3 humanoid estimate; model file missing)" },
	SovereignWu = { Vector3.new(3, 7, 2.4), "Wu PROXY (x1.2 humanoid estimate; model file missing)" },
}
local templates = {
	GrandmasterShen = { { "AsuraBoss_GrandmasterShen_P1", 1.3, 0 } },
	TwinSentinels = { { "AsuraBoss_GeneralZhao", 1.2, -8 }, { "AsuraBoss_IronBull", 1.7, 8 } },
}
local report = {}
for bid, a in plan do
	for _, v in { "A", "B" } do
		local c = a.variants[v]
		local cx, cz, sx, sz = c.centre[1], c.centre[3], c.size[1], c.size[2]
		local folder = Instance.new("Folder")
		folder.Name = bid .. "_" .. v
		local tone = if v == "B" then Color3.fromRGB(150, 146, 140) else Color3.fromRGB(120, 128, 140)
		local dz = if v == "A" then 0 else 0
		part(folder, "Floor", Vector3.new(sx, 1, sz), CFrame.new(cx, -0.5 + (if v == "A" then 0.05 else 0), cz), tone, if v == "A" then 0.55 else 0)
		if v == "B" then
			for _, e in { { sx + 2, 3, 1, cx, cz - sz / 2 }, { 1, 3, sz, cx - sx / 2, cz }, { 1, 3, sz, cx + sx / 2, cz } } do
				part(folder, "EdgeCue", Vector3.new(e[1], e[2], e[3]), CFrame.new(e[4], 1.5, e[5]), Color3.fromRGB(70, 66, 64))
			end
			for _, side in { -1, 1 } do
				part(folder, "NorthEdge", Vector3.new((sx - 30) / 2, 3, 1), CFrame.new(cx + side * (sx + 30) / 4, 1.5, cz + sz / 2), Color3.fromRGB(70, 66, 64))
			end
			part(folder, "Landmark", Vector3.new(16, 90, 16), CFrame.new(cx - sx * 0.3, 45, cz - sz / 2 - 60), Color3.fromRGB(30, 30, 34))
			part(folder, "GateMarker", Vector3.new(26, 20, 1.5), CFrame.new(a.gateX, 10, cz + sz / 2 + 2), Color3.fromRGB(230, 200, 90), 0.5)
		end
		local gate = Vector3.new(a.gateX, 3, cz + sz / 2 - 15)
		local spawn = Vector3.new(a.gateX, 0, cz + sz / 2 - 60)
		if v == "B" then
			local ok, rig = pcall(function() return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15) end)
			if ok and rig then
				for _, d in rig:GetDescendants() do if d:IsA("BasePart") then d.Anchored = true; d.Color = Color3.fromRGB(60, 120, 220) end end
				rig:PivotTo(CFrame.new(gate) * CFrame.Angles(0, 0, 0))
				rig.Parent = folder
			end
			local list = templates[bid]
			if list and lib then
				for _, t in list do
					local src = lib:FindFirstChild(t[1])
					if src then
						local m = src:Clone()
						m:ScaleTo(t[2])
						for _, d in m:GetDescendants() do if d:IsA("BasePart") then d.Anchored = true end end
						local bcf, bs = m:GetBoundingBox()
						m:PivotTo(CFrame.new(spawn + Vector3.new(t[3], bs.Y / 2, 0)) * CFrame.Angles(0, math.pi, 0) * (CFrame.new(bcf.Position):Inverse() * m:GetPivot()))
						m.Parent = folder
					end
				end
				label(folder, a.title .. " B " .. sx .. "x" .. sz, spawn + Vector3.new(0, 16, 0))
			else
				local p = proxies[bid]
				part(folder, "BossProxy", p[1], CFrame.new(spawn + Vector3.new(0, p[1].Y / 2, 0)), Color3.fromRGB(200, 60, 60))
				label(folder, p[2] .. " | " .. a.title .. " B " .. sx .. "x" .. sz, spawn + Vector3.new(0, p[1].Y + 10, 0), 60)
			end
		end
		folder.Parent = root
		table.insert(report, bid .. v)
		task.wait()
	end
end
return table.concat(report, " ")
