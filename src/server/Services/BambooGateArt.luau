--!strict
-- Framed cedar panels for the ridge shortcut. Reuses the uploaded Blender plaque's bevelled wood.
-- Collision and hinge frames belong to the layout/RouteGates; this module owns only static visuals.
local Storage = game:GetService("ServerStorage")

local Art = {}

function Art.Panel(parent: Instance, frame: CFrame, size: Vector3, name: string, hinges: boolean?): Model?
	local kit = Storage:FindFirstChild("AsuraLobbyKit")
	local plaque = kit and kit:FindFirstChild("Gate_Plaque")
	local source = plaque and plaque:FindFirstChild("Gate_Plaque__Timber")
	if not source or not source:IsA("MeshPart") or not source:FindFirstChildOfClass("SurfaceAppearance")
		or size.X <= 1.2 or size.Y <= 1.2 or size.Z <= 0 then return nil end
	local model = Instance.new("Model")
	model.Name = name
	model.WorldPivot = frame
	local function piece(label: string, length: number, width: number, depth: number, at: CFrame)
		local p = source:Clone()
		p.Name, p.Size = label, Vector3.new(length, width, depth)
		p.CFrame = frame * at
		p.Color = Color3.new(1, 1, 1)
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p:SetAttribute("AsuraDecorative", true)
		p.Parent = model
		return p
	end
	local border, inset = 0.6, 0.08
	local inner = size.X - border * 2
	local count = math.max(3, math.ceil(inner / 1.4))
	local pitch = inner / count
	for i = 1, count do
		-- Source grain runs along X. Rotate the same bevelled mesh upright for vertical boards.
		local x = -inner / 2 + pitch * (i - 0.5)
		piece("CedarBoard", size.Y - border * 2, pitch - inset, size.Z * 0.42,
			CFrame.new(x, 0, 0) * CFrame.Angles(0, 0, math.pi / 2))
	end
	for _, side in { -1, 1 } do
		piece("CedarStile", size.Y, border, size.Z * 0.86,
			CFrame.new(side * (size.X - border) / 2, 0, 0) * CFrame.Angles(0, 0, math.pi / 2))
		piece("CedarRail", size.X - border * 2, border, size.Z * 0.86,
			CFrame.new(0, side * (size.Y - border) / 2, 0))
	end
	local dx, dy = inner - 0.2, size.Y - border * 2 - 0.2
	local direction = if frame.Position.X < 0 then 1 else -1
	for _, face in { -1, 1 } do
		piece("CedarBrace", math.sqrt(dx * dx + dy * dy), 0.42, size.Z * 0.18,
			CFrame.new(0, 0, face * size.Z * 0.4) * CFrame.Angles(0, 0, direction * math.atan2(dy, dx)))
	end
	if hinges then
		local column = kit and kit:FindFirstChild("Column_Lacquer")
		local bronze = column and column:FindFirstChild("Column_Lacquer__Bronze")
		local surface = bronze and bronze:FindFirstChildOfClass("SurfaceAppearance")
		if surface then
			local side = if frame.Position.X < 0 then -1 else 1
			for _, face in { -1, 1 } do for _, level in { -1, 1 } do
				local p = piece("BronzeHingeStrap", 1.3, 0.28, size.Z * 0.08,
					CFrame.new(side * (size.X / 2 - 0.75), level * size.Y * 0.28, face * size.Z * 0.45))
				local previous = p:FindFirstChildOfClass("SurfaceAppearance")
				if previous then previous:Destroy() end
				surface:Clone().Parent = p
				p.Material = Enum.Material.Metal
			end end
		end
	end
	model.Parent = parent
	return model
end

-- Stone sills and piers divide the arena boundary into bays. The existing wall owns
-- collision and camera queries. The plank material tiles along the reused bevelled mesh.
function Art.Palisade(parent: Instance, wall: BasePart): Model?
	local kit = Storage:FindFirstChild("AsuraLobbyKit")
	local plaque = kit and kit:FindFirstChild("Gate_Plaque")
	local rim = kit and kit:FindFirstChild("Pool_Rim")
	local post = kit and kit:FindFirstChild("Rail_Post")
	local timber = plaque and plaque:FindFirstChild("Gate_Plaque__Timber")
	local sill = rim and rim:FindFirstChild("Pool_Rim__Stone")
	local pier = post and post:FindFirstChild("Rail_Post__Stone")
	if not timber or not timber:IsA("MeshPart") or not sill or not sill:IsA("MeshPart")
		or not pier or not pier:IsA("MeshPart") then return nil end

	local model = Instance.new("Model")
	model.Name = "StoneAndCedarPalisade"
	local frame = wall.CFrame * CFrame.Angles(0, math.pi / 2, 0)
	model.WorldPivot = frame
	local function piece(source: MeshPart, name: string, size: Vector3, offset: Vector3, tone: Color3?)
		local p = source:Clone()
		p.Name, p.Size, p.CFrame = name, size, frame * CFrame.new(offset)
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		if tone then
			local surface = p:FindFirstChildOfClass("SurfaceAppearance")
			if surface then surface:Destroy() end
			p.TextureID = ""
			p.Material, p.MaterialVariant, p.Color = Enum.Material.WoodPlanks, "", tone
		end
		p:SetAttribute("AsuraDecorative", true)
		p.Parent = model
	end

	local bays = math.ceil(wall.Size.Z / 12)
	local width = wall.Size.Z / bays
	local halfHeight, depth = wall.Size.Y / 2, wall.Size.X
	for i = 1, bays do
		local x = -wall.Size.Z / 2 + width * (i - 0.5)
		local upper = if i % 3 == 0 then Color3.fromRGB(124, 102, 75) else Color3.fromRGB(113, 93, 68)
		piece(sill, "StoneSill", Vector3.new(width, 1.35, depth), Vector3.new(x, 0.63 - halfHeight, 0))
		piece(timber, "LowerCedar", Vector3.new(width - 0.03, 2.64, depth * 0.52),
			Vector3.new(x, 2.57 - halfHeight, 0), Color3.fromRGB(101, 84, 63))
		piece(timber, "UpperCedar", Vector3.new(width - 0.03, 2.74, depth * 0.48),
			Vector3.new(x, 5.22 - halfHeight, 0), upper)
		piece(timber, "CopingRail", Vector3.new(width, 0.48, depth * 0.88),
			Vector3.new(x, 6.73 - halfHeight, 0), Color3.fromRGB(87, 71, 52))
	end
	local endInset = depth * 0.45
	for i = 0, bays do
		local x = math.clamp(-wall.Size.Z / 2 + width * i, -wall.Size.Z / 2 + endInset, wall.Size.Z / 2 - endInset)
		piece(pier, "StonePier", Vector3.new(depth * 0.9, wall.Size.Y, depth), Vector3.new(x, 0, 0))
	end
	model.Parent = parent
	return model
end

return table.freeze(Art)
