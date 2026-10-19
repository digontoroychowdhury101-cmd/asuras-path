--!strict
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Shared = game:GetService("ReplicatedStorage").AsurasPath
local World = require(Shared.Shared.WorldDefinitions)
local Rules = require(Shared.Shared.BossEncounterRules)
local Characters = require(script.Parent.CharacterService)
local Arenas = {}
local walls: { [string]: { Part } } = {}
local function part(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3): Part
	local p = Instance.new("Part")
	p.Name, p.Size, p.Position, p.Color = name, size, position, color
	p.Anchored, p.Material, p.Parent = true, Enum.Material.Slate, parent
	return p
end
function Arenas.seal(gateId: string, sealed: boolean)
	for _, p in walls[gateId] or {} do
		p.CanCollide = sealed
		p.Transparency = if sealed then 0.45 else 1
		p:SetAttribute("Sealed", sealed)
	end
end
local function portal(parent: Instance, name: string, position: Vector3, destination: Vector3)
	local anchor = part(parent, name, Vector3.new(8, 10, 2), position, Color3.fromRGB(170, 148, 80))
	anchor.CanCollide, anchor.Material, anchor.Transparency = false, Enum.Material.ForceField, 0.3
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText, prompt.ObjectText, prompt.HoldDuration = "Traverse", name, 0.4
	prompt.MaxActivationDistance, prompt.Parent = 12, anchor
	prompt.Triggered:Connect(function(player: Player)
		local e = Characters.GetEntity(player.UserId)
		if e and e.Fighter.State ~= "KO" and not Characters.IsInDuel(e.Id) and (e.Root.Position - position).Magnitude <= 15 then
			Characters.Teleport(e.Id, CFrame.new(destination))
		end
	end)
end
function Arenas.build(root: Instance)
	table.clear(walls)
	local old = root:FindFirstChild("BossArenas")
	if old then old:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "BossArenas", root
	for _, boss in World.Bosses do
		local c, s = boss.Arena.Center, boss.Arena.Size
		local center = Vector3.new(c.X, 0, c.Z)
		part(folder, boss.Id .. "Floor", Vector3.new(s.X, 4, s.Z), center - Vector3.new(0, 2, 0), Color3.fromRGB(49, 45, 43))
		part(folder, boss.Id .. "Approach", Vector3.new(30, 4, 40), center + Vector3.new(0, -2, s.Z / 2 + 20), Color3.fromRGB(61, 56, 48))
		local boundary: { Part } = {}
		-- Entrance is on the north face; only the fog aperture remains open there.
		for _, spec in {
			{ Vector3.new(2, 100, s.Z), Vector3.new(-s.X / 2, 48, 0) },
			{ Vector3.new(2, 100, s.Z), Vector3.new(s.X / 2, 48, 0) },
			{ Vector3.new(s.X, 100, 2), Vector3.new(0, 48, -s.Z / 2) },
			{ Vector3.new((s.X - 26) / 2, 100, 2), Vector3.new(-(s.X + 26) / 4, 48, s.Z / 2) },
			{ Vector3.new((s.X - 26) / 2, 100, 2), Vector3.new((s.X + 26) / 4, 48, s.Z / 2) },
		} do
			local wall = part(folder, "AshPerimeter", spec[1], center + spec[2], Color3.fromRGB(198, 163, 81))
			wall.Material = Enum.Material.ForceField
			table.insert(boundary, wall)
		end
		walls[boss.FogGate] = boundary
		Arenas.seal(boss.FogGate, false)
		if boss.Archetype == "Beast" then
			for x = -1, 1, 2 do for z = -1, 1, 2 do
				part(folder, "FrostPillar", Vector3.new(8, 30, 8), center + Vector3.new(x * 60, 15, z * 50), Color3.fromRGB(97, 128, 140))
			end end
		end
	end
	-- Traversable links for the side courtyard and the two northern campaign regions.
	part(folder, "CourtyardRoad", Vector3.new(160, 4, 24), Vector3.new(220, -2, -810), Color3.fromRGB(61, 56, 48))
	part(folder, "PagodaRoad", Vector3.new(30, 4, 130), Vector3.new(0, -2, -2150), Color3.fromRGB(61, 56, 48))
	part(folder, "SummitRoad", Vector3.new(30, 4, 150), Vector3.new(0, -2, -2580), Color3.fromRGB(61, 56, 48))
	portal(folder, "Descend to the Sunken Crypt", Vector3.new(-35, 605, 900), Vector3.new(520, 3, 988))
	portal(folder, "Return to the Shrine", Vector3.new(550, 5, 1015), Vector3.new(-25, 603, 900))
end
function Arenas.loot(position: Vector3, essence: number)
	for _, drop in Rules.loot(essence, 12) do
		local orb = part(workspace, "QiEssence", Vector3.one, position, Color3.fromRGB(244, 196, 91))
		orb.Shape, orb.Material, orb.CanCollide, orb.CanQuery = Enum.PartType.Ball, Enum.Material.Neon, false, false
		orb:SetAttribute("Essence", drop.Amount)
		orb:SetAttribute("CosmeticReward", true)
		TweenService:Create(orb, TweenInfo.new(1.6), { Position = position + Vector3.new(drop.X, 6, drop.Z), Transparency = 1 }):Play()
		Debris:AddItem(orb, 2)
	end
end
return Arenas
