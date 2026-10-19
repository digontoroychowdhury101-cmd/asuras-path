--!strict
-- Procedural silhouettes and phase adornments remain usable before custom rigs are published.
local Characters = require(script.Parent.CharacterService)
local Appearance = {}
local function gear(model: Model, root: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name, part.Size, part.Color = name, size, color
	part.Material, part.CanCollide, part.CanTouch, part.CanQuery = Enum.Material.Neon, false, false, false
	part.Massless, part.CFrame, part.Parent = true, root.CFrame * offset, model
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1, weld.Parent = root, part, part
	return part
end
function Appearance.apply(model: Model, archetype: string?, scale: number?)
	if scale and scale ~= 1 then
		local id = Characters.GetEntityByModel(model)
		if id then Characters.ScaleEnemy(id, scale) end
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end
	if archetype == "Dragon" then
		for side = -1, 1, 2 do
			gear(model, root, "AzureWing", Vector3.new(13, 0.4, 7), CFrame.new(side * 8, 3, 1) * CFrame.Angles(0, 0, side * 0.25), Color3.fromRGB(44, 110, 180))
		end
		gear(model, root, "WyrmTail", Vector3.new(2, 2, 17), CFrame.new(0, 0, 10), Color3.fromRGB(36, 88, 130))
	elseif archetype == "Beast" then
		for side = -1, 1, 2 do
			gear(model, root, "FrostForeleg", Vector3.new(2, 5, 2), CFrame.new(side * 3, -1, -3) * CFrame.Angles(-0.6, 0, 0), Color3.fromRGB(140, 212, 240))
		end
		gear(model, root, "FrostSpine", Vector3.new(4, 2, 8), CFrame.new(0, 2, 2), Color3.fromRGB(100, 160, 190))
	elseif archetype == "Colossus" then
		model:SetAttribute("AsuraVisceralTarget", "Ankles")
		for side = -1, 1, 2 do gear(model, root, "ArmoredAnkle", Vector3.new(4, 2, 4), CFrame.new(side * 2, -6, 0), Color3.fromRGB(96, 78, 48)) end
	elseif archetype == "IronBull" then
		local shield = gear(model, root, "Greatshield", Vector3.new(5, 7, 1), CFrame.new(-3, 0, -3), Color3.fromRGB(72, 68, 54))
		shield.Material = Enum.Material.Metal
		local hand = (model:FindFirstChild("RightHand") or model:FindFirstChild("Right Arm")) :: BasePart?
		if hand then
			local haft = gear(model, hand, "WarhammerHaft", Vector3.new(0.6, 6, 0.6), CFrame.new(0, -1.8, 0), Color3.fromRGB(70, 56, 40))
			local hammer = gear(model, hand, "ColossalWarhammer", Vector3.new(4.5, 2.5, 3), CFrame.new(0, -4, 0), Color3.fromRGB(85, 83, 78))
			haft.Material, hammer.Material = Enum.Material.Wood, Enum.Material.Metal
		end
	end
end
function Appearance.phase(model: Model, animationSet: string?)
	model:SetAttribute("AsuraAnimationSet", animationSet or "Boss")
	if animationSet ~= "DemonicChimera" or model:FindFirstChild("CrimsonQiHorn") then return end
	local head = model:FindFirstChild("Head") :: BasePart?
	if head then
		for side = -1, 1, 2 do gear(model, head, "CrimsonQiHorn", Vector3.new(0.5, 3, 0.5), CFrame.new(side * 0.8, 1.4, 0) * CFrame.Angles(0, 0, -side * 0.4), Color3.fromRGB(220, 20, 40)) end
	end
end
return Appearance
