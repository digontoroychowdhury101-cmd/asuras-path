--!strict
-- Sanctuary-only visual finish. Original ring geometry, collision, barriers, threshold identifiers
-- and every matchmaking/duel rule remain owned by ColosseumService.
local Kit = require(script.Parent:WaitForChild("SanctuaryKit") :: ModuleScript)

local Finish = {}
local BRONZE = Color3.fromRGB(138, 117, 82)
local Y = Vector3.yAxis

local function surface(part: BasePart, key: string)
	local s = Kit.Surface[key]
	part.Material, part.MaterialVariant, part.Color = s.Material, s.Variant, s.Color
end

local function sealLine(group: Instance, a: Vector3, b: Vector3, width: number)
	local line = Kit.slab(group, "BronzeSeal", Vector3.new(width, 0.025, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), "Bronze", Kit.decor())
	line.Color = BRONZE
end

local function seal(group: Instance, frame: CFrame)
	for _, radius in { 6.8, 5.9, 2.5 } do
		for k = 0, 7 do
			local a, b = math.rad(k * 45 + 22.5), math.rad((k + 1) * 45 + 22.5)
			sealLine(group, (frame * CFrame.new(math.cos(a) * radius, 0.485, math.sin(a) * radius)).Position,
				(frame * CFrame.new(math.cos(b) * radius, 0.485, math.sin(b) * radius)).Position, if radius == 6.8 then 0.1 else 0.055)
		end
	end
	for k = 0, 3 do
		local a = math.rad(k * 90 + 45)
		local radial = Vector3.new(math.cos(a), 0, math.sin(a))
		local across = radial:Cross(Y)
		local c = radial * 4.2
		local points = { c + radial * 1, c + across * 0.65, c - radial * 1, c - across * 0.65 }
		for i = 1, 4 do
			sealLine(group, (frame * CFrame.new(points[i] + Y * 0.485)).Position,
				(frame * CFrame.new(points[i % 4 + 1] + Y * 0.485)).Position, 0.07)
		end
	end
end

local function lanternPost(group: Instance, cf: CFrame)
	Kit.place(group, "Column_Base", cf, 0.8)
	Kit.place(group, "Column_Lacquer", cf * CFrame.new(0, 0.72, 0), Vector3.new(0.5, 0.55, 0.5))
	Kit.slab(group, "LanternArm", Vector3.new(2, 0.23, 0.32), cf * CFrame.new(0.7, 6.45, 0), "Timber", Kit.decor())
	Kit.slab(group, "LanternPostCap", Vector3.new(0.85, 0.17, 0.85), cf * CFrame.new(0, 6.5, 0), "Bronze", Kit.decor()).Color = BRONZE
	Kit.place(group, "Lantern_Hanging", cf * CFrame.new(1.1, 6.5, 0))
	Kit.glow(group, cf * CFrame.new(1.1, 5.2, 0), Vector3.new(0.92, 0.95, 0.92), 15, 0.65)
end

function Finish.Dress(model: Model)
	local floor = model:FindFirstChild("Floor0")
	if not floor or not floor:IsA("BasePart") then return end
	local frame, apothem = floor.CFrame, floor.Size.X / 2
	local previous = model:FindFirstChild("SanctuaryRingFinish")
	if previous then previous:Destroy() end
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			local name = child.Name
			if name:match("^Floor%d+$") then
				surface(child, "PavingPath")
			elseif name:match("^Threshold%d+$") then
				surface(child, "Stone")
			elseif name:match("^Ember%d+$") then
				surface(child, "Bronze")
				child.Color, child.Transparency = BRONZE, 0
			elseif name:match("^Wall%d+$") or name:match("^Pillar%d+$") or name == "Sigil" or name == "SigilCore" then
				child.Transparency = 1
			elseif name:match("^Brazier%d+$") then
				child.Transparency = 1
				for _, light in child:GetChildren() do
					if light:IsA("PointLight") then light.Enabled = false end
				end
			end
		end
	end
	local group = Kit.folder("SanctuaryRingFinish", model)
	Kit.place(group, "Paving_Medallion", frame * CFrame.new(0, 0.42, 0), 1.25)
	seal(group, frame)
	local length = apothem * 2 * math.tan(math.rad(22.5))
	for k = 0, 7 do
		local edge = frame * CFrame.Angles(0, math.rad(k * 45), 0) * CFrame.new(0, 0.4, -apothem - 0.5)
		for bay = -1, 1, 2 do
			Kit.place(group, "Pool_Rim", edge * CFrame.new(bay * length / 4, 0, 0), Vector3.new((length / 2 - 0.025) / 8, 1, 1))
		end
		if k % 2 == 0 then
			local vertex = frame * CFrame.Angles(0, math.rad(k * 45 + 22.5), 0) * CFrame.new(0, 0.4, -(apothem / math.cos(math.rad(22.5)) + 0.6))
			lanternPost(group, vertex)
		end
	end
	local sign = model:FindFirstChild("Sign")
	if sign then
		local gui = sign:FindFirstChildOfClass("BillboardGui")
		if gui then
			gui.MaxDistance, gui.Size, gui.LightInfluence = 40, UDim2.fromScale(13, 2.7), 0.35
			for _, label in gui:GetChildren() do
				if label:IsA("TextLabel") and label.Text:find("threshold", 1, true) then
					label.Text, label.TextColor3 = "Step upon the stone threshold to duel", Color3.fromRGB(190, 170, 133)
				end
			end
		end
	end
end

return table.freeze(Finish)
