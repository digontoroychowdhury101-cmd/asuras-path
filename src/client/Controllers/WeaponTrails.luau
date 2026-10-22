--!strict
local Assets = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.PresentationAssets)
local Controller = {}
Controller.__index = Controller
local COLORS = { CalamityBoneCleaver=Color3.fromRGB(215,33,27), HeavenPiercingGuandao=Color3.fromRGB(74,222,255),
	TwinShadowSai=Color3.fromRGB(139,66,221), JadeCatalyst=Color3.fromRGB(83,241,208) }
local function clear(record: any) for _, item in record.Items do item:Destroy() end end
local function blade(e: any): BasePart?
	local basic = e.Model:FindFirstChild("AsuraWeapon")
	if basic and basic:IsA("BasePart") then return basic end
	local folder = e.Model:FindFirstChild("ArsenalWeapon")
	if folder then
		for _, name in {"GreatBlade","ShadowSai","SickleBlade","FanRib","JadeStaff","BronzeCenser"} do
			local p = folder:FindFirstChild(name)
			if p and p:IsA("BasePart") then return p end
		end
	end
	-- Boss looks carry their own weapons (CostumeKit): trail the longest visible weapon piece.
	local attire, best, length = e.Model:FindFirstChild("AsuraAttire"), nil :: BasePart?, 0
	for _, p in if attire then attire:GetChildren() else {} do
		if p:IsA("BasePart") and p:GetAttribute("AsuraRole") == "Weapon" and p.Transparency < 1 and p.Size.Z > length then best, length = p, p.Size.Z end
	end
	return best
end
function Controller.new(state: any): any return setmetatable({State=state, Records={}, Tick=0},Controller) end
function Controller.Update(self: any, dt: number)
	self.Tick += dt
	if self.Tick < 1/30 then return end
	self.Tick = 0
	local own = self.State:Own(); local admitted = 0
	for id, record in self.Records do
		record.Trail.Enabled = false
		local e = self.State:Get(id)
		if not e or not record.Part.Parent or not own or not own.Root or not e.Root or (own.Root.Position-e.Root.Position).Magnitude>85 then
			clear(record); self.Records[id]=nil
		end
	end
	if not own or not own.Root then return end
	for id, e in self.State.Entities do
		if not e.Root or (own.Root.Position-e.Root.Position).Magnitude>80 then continue end
		admitted += 1; if admitted > Assets.Limits.TrailActors then break end
		local p = blade(e); local record = self.Records[id]
		if record and record.Part ~= p then clear(record); self.Records[id]=nil; record=nil end
		if not p then continue end
		if not record then
			local a, b = Instance.new("Attachment"), Instance.new("Attachment")
			a.Name,b.Name = "AsuraHilt","AsuraTip"
			local axis = if p.Size.Y > p.Size.Z then Vector3.yAxis else Vector3.zAxis
			local length = math.max(p.Size.Y,p.Size.Z)
			a.Position,b.Position = axis*length*0.35, -axis*length*0.5
			a.Parent,b.Parent = p,p
			local trail = Instance.new("Trail")
			trail.Name, trail.Attachment0, trail.Attachment1 = "ElementRibbon",a,b
			trail.Lifetime,trail.MinLength,trail.FaceCamera = 0.15,0.04,true
			trail.Color = ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),
				ColorSequenceKeypoint.new(0.22,(COLORS :: any)[e.Model:GetAttribute("AsuraWeapon")] or Color3.fromRGB(237,192,118)),
				ColorSequenceKeypoint.new(1,Color3.fromRGB(45,19,42))})
			trail.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0.08),NumberSequenceKeypoint.new(1,1)})
			trail.WidthScale,trail.LightEmission = NumberSequence.new(1,0),0.85
			trail.Texture,trail.Enabled,trail.Parent = Assets.Textures.Ribbon,false,p
			local items: {Instance}={trail,a,b}
			record={Part=p,Trail=trail,Items=items}; self.Records[id]=record
		end
		local snapshot=e.Snapshot
		record.Trail.Enabled = snapshot ~= nil and snapshot.State == "Active"
	end
end
function Controller.Destroy(self: any)
	for _, record in self.Records do clear(record) end
	table.clear(self.Records)
end
return Controller
