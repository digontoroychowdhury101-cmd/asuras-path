--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/WorldService
-- Story Mode world rules: Incense Altar checkpoints, elixir gourd, death penalty bloodstains and
-- boss fog gates. Live session state (unbanked essence, gourd charges) is committed to the profile
-- through a per-player serial queue so progression writes never overlap or race a release.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")

local Shared = ReplicatedStorage:WaitForChild("AsurasPath")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript) :: any
local World = require(Shared.Shared.WorldDefinitions)
local Settings = require(Shared.Shared.CombatSettings) :: any
local Weapons = require(Shared.Simulation.WeaponSchema) :: any
local Characters = require(script.Parent:WaitForChild("CharacterService") :: ModuleScript)
local AI = require(script.Parent:WaitForChild("AIService") :: ModuleScript)
local BossArenas = require(script.Parent.BossArenas)
local BossRules = require(Shared.Shared.BossEncounterRules)
local Progression = require(Shared.Shared.ProgressionRules)
local Persistence = require(script.Parent:WaitForChild("PersistenceService") :: ModuleScript) :: any
local ProfileStore = require(script.Parent:WaitForChild("ProfileStore") :: ModuleScript)

type Altar = World.Altar
type FogGate = World.FogGate
type Souls = ProfileStore.Souls

type Commit = { Label: string, Run: (engine: any) -> (boolean, string?) }

type Session = {
	UserId: number,
	Player: Player,
	Elixirs: number,
	MaxElixirs: number,
	Potency: number,
	ElixirsDirty: boolean,
	Unbanked: number,
	ActiveAltar: string,
	Altars: { [string]: boolean },
	Bosses: { [string]: boolean },
	Region: string?,
	Fight: string?,
	Stain: BasePart?,
	StainDeath: number,
	Queue: { Commit },
	Processing: boolean,
	LastFlush: number,
}

type Fight = {
	Gate: FogGate,
	BossId: string,
	BossEntity: number,
	Participants: { [number]: boolean },
	StartedAt: number,
}

local WorldService = {}

local TAG_ALTAR = "AsuraAltar"
local TAG_STAIN = "AsuraBloodstain"
local INTERACT_RADIUS = 6
local FLUSH_INTERVAL = 20
local GATE_INTERVAL = 6 -- ticks (10 Hz)
local BUSY_RETRIES = 40
local POTENCY_STEP = 0.04
-- Static level geometry joins WorldGeometry; CameraProbe collides with nothing else, so client
-- camera spherecasts cast as CameraProbe see walls and floors but never characters or effects.
local WORLD_GROUP = "WorldGeometry"
local PROBE_GROUP = "CameraProbe"

local sessions: { [number]: Session } = {}
local fights: { [string]: Fight } = {}
local altarParts: { [string]: BasePart } = {}
local gateParts: { [string]: BasePart } = {}
local connections: { RBXScriptConnection } = {}
local disconnectors: { () -> () } = {}
local worldFolder: Folder? = nil
-- Other services' interactables (e.g. the Sanctuary blacksmith) answer the Interact intent so a
-- press beside them is acknowledged instead of reporting "nothing nearby".
type Interactable = (userId: number, position: Vector3) -> (boolean?, string?)
local interactables: { Interactable } = {}
local tickCounter = 0
local running = false

-------------------------------------------------------------------------------------------------
-- Geometry helpers
-------------------------------------------------------------------------------------------------

local function toCFrame(p: World.Placement): CFrame
	return CFrame.new(p.X, p.Y, p.Z) * CFrame.Angles(0, math.rad(p.Yaw), 0)
end

local function vec(v: World.Vec3): Vector3
	return Vector3.new(v.X, v.Y, v.Z)
end

local function inBounds(bounds: World.Bounds, position: Vector3): boolean
	return World.contains(bounds, position.X, position.Y, position.Z)
end

local function material(name: string): Enum.Material
	local ok, value = pcall(function()
		return (Enum.Material :: any)[name]
	end)
	return if ok and value then value else Enum.Material.Slate
end

local function folder(name: string, parent: Instance): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = name
	created.Parent = parent
	return created
end

local function entityPosition(userId: number): Vector3?
	local e = Characters.GetEntity(userId)
	return if e then e.Root.Position else nil
end

-------------------------------------------------------------------------------------------------
-- Sessions and the serial commit queue
-------------------------------------------------------------------------------------------------

local function engine(): any
	return Persistence.Engine
end

local function souls(userId: number): Souls?
	local profile = Persistence.Get(userId)
	return if profile then profile.souls else nil
end

local function session(userId: number): Session?
	local existing = sessions[userId]
	if existing then
		return existing
	end
	local player = Players:GetPlayerByUserId(userId)
	local record = souls(userId)
	if not player or not record then
		return nil
	end
	local created: Session = {
		UserId = userId,
		Player = player,
		Elixirs = record.inventory.elixirs.charges,
		MaxElixirs = record.inventory.elixirs.max,
		Potency = record.inventory.elixirs.potency,
		ElixirsDirty = false,
		Unbanked = 0,
		ActiveAltar = record.world.activeAltar,
		Altars = table.clone(record.world.altars),
		Bosses = table.clone(record.world.bosses),
		Region = nil,
		Fight = nil,
		Stain = nil,
		StainDeath = 0,
		Queue = {},
		Processing = false,
		LastFlush = os.clock(),
	}
	sessions[userId] = created
	player:SetAttribute("AsuraElixirs", created.Elixirs)
	player:SetAttribute("AsuraElixirsMax", created.MaxElixirs)
	player:SetAttribute("AsuraUnbanked", 0)
	return created
end

local function publish(s: Session)
	local record = souls(s.UserId)
	local player = s.Player
	if not player.Parent then
		return
	end
	player:SetAttribute("AsuraElixirs", s.Elixirs)
	player:SetAttribute("AsuraElixirsMax", s.MaxElixirs)
	player:SetAttribute("AsuraUnbanked", s.Unbanked)
	if record then
		player:SetAttribute("AsuraEssence", record.essence)
		player:SetAttribute("AsuraLevel", record.level)
  player:SetAttribute("AsuraMaxQi",ProfileStore.DeriveStats(record).MaxQi)
		player:SetAttribute("AsuraLevelCost", ProfileStore.LevelCost(record.level))
		player:SetAttribute("AsuraActiveAltar", record.world.activeAltar)
		player:SetAttribute("AsuraMainhand", record.inventory.mainhand)
		player:SetAttribute("AsuraOffhand", record.inventory.offhand)
		local forged = ProfileStore.ReinforceLevel(record, record.inventory.mainhand)
		player:SetAttribute("AsuraReinforce", forged)
		player:SetAttribute("AsuraReinforceCost", if forged >= ProfileStore.ReinforceMax then 0 else ProfileStore.ReinforceCost(forged))
		local altars: { string } = {}
		for id in record.world.altars do
			table.insert(altars, id)
		end
		table.sort(altars)
		player:SetAttribute("AsuraAltars", table.concat(altars, ","))
		-- Read-only progress mirror for the client objective tracker; never read back by the server.
		local bosses: { string } = {}
		for id, defeated in s.Bosses do
			if defeated then table.insert(bosses, id) end
		end
		table.sort(bosses)
		player:SetAttribute("AsuraBosses", table.concat(bosses, ","))
		for _, name in ProfileStore.Attributes do
			player:SetAttribute("Asura" .. name, record.attributes[name])
		end
	end
end

local function processQueue(s: Session)
	if s.Processing then
		return
	end
	s.Processing = true
	task.spawn(function()
		while #s.Queue > 0 do
			local commit = table.remove(s.Queue, 1) :: Commit
			local ok, err = false, "Profile is busy"
			for _ = 1, BUSY_RETRIES do
				ok, err = commit.Run(engine())
				if ok or err ~= "Profile is busy" then
					break
				end
				task.wait(0.25)
			end
			if not ok then
				warn(string.format("[WorldService] %s for %d failed: %s", commit.Label, s.UserId, tostring(err)))
			end
		end
		s.Processing = false
		if s.Player.Parent then
			publish(s)
		elseif sessions[s.UserId] == s then
			sessions[s.UserId] = nil
		end
	end)
end

local function enqueue(s: Session, label: string, run: (engine: any) -> (boolean, string?))
	table.insert(s.Queue, { Label = label, Run = run })
	processQueue(s)
end

-- Banks unbanked essence and gourd charges. Returns immediately; work is serialised per player.
local function flush(s: Session)
	s.LastFlush = os.clock()
	if s.Unbanked > 0 then
		local amount = s.Unbanked
		s.Unbanked = 0
		enqueue(s, "BankEssence", function(store: any): (boolean, string?)
			local ok, err = store:GrantEssence(s.UserId, amount)
			if not ok and err ~= "Profile is busy" then
				s.Unbanked += amount
			end
			return ok, err
		end)
	end
	if s.ElixirsDirty then
		s.ElixirsDirty = false
		local charges = s.Elixirs
		enqueue(s, "Elixirs", function(store: any): (boolean, string?)
			return store:SetElixirCharges(s.UserId, charges)
		end)
	end
end

-- Blocking flush used on leave/shutdown before the profile lease is released.
function WorldService.Flush(userId: number, timeout: number?)
	local s = sessions[userId]
	if not s then
		return
	end
	flush(s)
	local deadline = os.clock() + (timeout or 8)
	while (s.Processing or #s.Queue > 0) and os.clock() < deadline do
		task.wait(0.05)
	end
end

function WorldService.FlushAll(timeout: number?)
	local deadline = os.clock() + (timeout or 10)
	for _, s in sessions do
		flush(s)
	end
	repeat
		local busy = false
		for _, s in sessions do
			if s.Processing or #s.Queue > 0 then
				busy = true
			end
		end
		if busy then
			task.wait(0.05)
		end
	until not busy or os.clock() >= deadline
end

-------------------------------------------------------------------------------------------------
-- World construction
-------------------------------------------------------------------------------------------------

local function registerGroups()
	for _, name in { WORLD_GROUP, PROBE_GROUP } do
		if not PhysicsService:IsCollisionGroupRegistered(name) then
			PhysicsService:RegisterCollisionGroup(name)
		end
	end
	for _, group in PhysicsService:GetRegisteredCollisionGroups() do
		PhysicsService:CollisionGroupSetCollidable(PROBE_GROUP, group.name, group.name == WORLD_GROUP)
	end
end

local function markGeometry(container: Instance)
	local function mark(instance: Instance)
		if instance:IsA("BasePart") and instance.Anchored and instance:FindFirstAncestorOfClass("Model") == nil then
			instance.CollisionGroup = WORLD_GROUP
		elseif instance:IsA("BasePart") and instance.Anchored then
			local model = instance:FindFirstAncestorOfClass("Model")
			if model and model:FindFirstChildOfClass("Humanoid") == nil then
				instance.CollisionGroup = WORLD_GROUP
			end
		end
	end
	for _, descendant in container:GetDescendants() do
		mark(descendant)
	end
	table.insert(connections, container.DescendantAdded:Connect(mark))
end

local function buildGreybox(root: Folder)
	local greybox = folder("Greybox", root)
	for _, id in World.RegionOrder do
		local region = World.Regions[id]
		if Workspace:FindFirstChild(region.MapFolder, true) == nil and greybox:FindFirstChild(id) == nil then
			local bounds = region.Bounds
			local floor = Instance.new("Part")
			floor.Name = id
			floor.Anchored = true
			floor.Size = Vector3.new(bounds.Size.X, 4, bounds.Size.Z)
			floor.CFrame = CFrame.new(bounds.Center.X, -2, bounds.Center.Z)
			floor.Material = material(region.Greybox.Material)
			floor.Color = Color3.fromRGB(region.Greybox.Color[1], region.Greybox.Color[2], region.Greybox.Color[3])
			floor.TopSurface = Enum.SurfaceType.Smooth
			floor:SetAttribute("AsuraRegion", id)
			floor.Parent = greybox
		end
	end
end

-- An authored part named AltarAnchor_<id> (e.g. the Sanctuary bonfire plinth) replaces the stock
-- censer: the rest prompt mounts on it and it becomes the altar's reference point.
local function anchoredAltar(altar: Altar): ProximityPrompt?
	local anchor = Workspace:FindFirstChild("AltarAnchor_" .. altar.Id, true)
	if not anchor or not anchor:IsA("BasePart") then
		return nil
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RestPrompt"
	prompt.ActionText = "Rest"
	prompt.ObjectText = altar.Name
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = altar.Radius
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	anchor:SetAttribute("AltarId", altar.Id)
	CollectionService:AddTag(anchor, TAG_ALTAR)
	altarParts[altar.Id] = anchor
	return prompt
end

local function buildAltar(altar: Altar, parent: Folder): ProximityPrompt
	local authored = anchoredAltar(altar)
	if authored then
		return authored
	end
	local model = Instance.new("Model")
	model.Name = "IncenseAltar_" .. altar.Id
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Anchored = true
	base.Size = Vector3.new(4, 1.5, 4)
	base.CFrame = toCFrame(altar.Placement) * CFrame.new(0, 0.75, 0)
	base.Material = Enum.Material.Slate
	base.Color = Color3.fromRGB(64, 58, 54)
	base.Parent = model
	local censer = Instance.new("Part")
	censer.Name = "Censer"
	censer.Anchored = true
	censer.CanCollide = false
	censer.Shape = Enum.PartType.Cylinder
	censer.Size = Vector3.new(0.8, 1.6, 1.6)
	censer.CFrame = base.CFrame * CFrame.new(0, 1.15, 0) * CFrame.Angles(0, 0, math.rad(90))
	censer.Material = Enum.Material.Metal
	censer.Color = Color3.fromRGB(122, 92, 46)
	censer.Parent = model
	local incense = Instance.new("Part")
	incense.Name = "Incense"
	incense.Anchored = true
	incense.CanCollide = false
	incense.Size = Vector3.new(0.12, 1.8, 0.12)
	incense.CFrame = base.CFrame * CFrame.new(0, 2.4, 0)
	incense.Material = Enum.Material.Neon
	incense.Color = Color3.fromRGB(255, 140, 60)
	incense.Parent = model
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 80)
	light.Range = 14
	light.Brightness = 1.6
	light.Parent = incense
	local smoke = Instance.new("Smoke")
	smoke.Size = 0.4
	smoke.RiseVelocity = 2
	smoke.Opacity = 0.08
	smoke.Color = Color3.fromRGB(200, 196, 190)
	smoke.Parent = incense
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RestPrompt"
	prompt.ActionText = "Rest"
	prompt.ObjectText = altar.Name
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = altar.Radius
	prompt.RequiresLineOfSight = false
	prompt.Parent = base
	model.PrimaryPart = base
	model:SetAttribute("AltarId", altar.Id)
	CollectionService:AddTag(model, TAG_ALTAR)
	model.Parent = parent
	altarParts[altar.Id] = base
	return prompt
end

local function buildGate(gate: FogGate, parent: Folder)
	local wall = Instance.new("Part")
	wall.Name = "FogGate_" .. gate.Id
	wall.Anchored = true
	wall.CanCollide = false
	wall.CanQuery = false
	wall.CanTouch = false
	wall.Size = vec(gate.Size)
	wall.CFrame = toCFrame(gate.Placement)
	wall.Material = Enum.Material.ForceField
	wall.Color = Color3.fromRGB(220, 214, 200)
	wall.Transparency = 0.45
	wall:SetAttribute("Sealed", false)
	wall:SetAttribute("Boss", gate.Boss)
	wall.Parent = parent
	gateParts[gate.Id] = wall
end

local function setGate(gateId: string, sealed: boolean)
	BossArenas.seal(gateId, sealed)
	local wall = gateParts[gateId]
	if not wall then
		return
	end
	wall.CanCollide = sealed
	wall.Transparency = if sealed then 0.1 else 0.45
	wall.Color = if sealed then Color3.fromRGB(218, 181, 88) else Color3.fromRGB(220, 214, 200)
	wall:SetAttribute("Sealed", sealed)
end

-------------------------------------------------------------------------------------------------
-- Bloodstains
-------------------------------------------------------------------------------------------------

local function destroyStain(s: Session)
	if s.Stain then
		s.Stain:Destroy()
		s.Stain = nil
	end
	s.StainDeath = 0
	s.Player:SetAttribute("AsuraBloodstain", nil)
end

local recoverStain: (s: Session) -> (boolean, string)

local function placeStain(s: Session, stain: ProfileStore.Bloodstain)
	destroyStain(s)
	local root = worldFolder
	if not root then
		return
	end
	local part = Instance.new("Part")
	part.Name = "Bloodstain_" .. s.UserId
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.15, 4, 4)
	part.CFrame = CFrame.new(stain.x, stain.y - 2.8, stain.z) * CFrame.Angles(0, 0, math.rad(90))
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(150, 12, 18)
	part.Transparency = 0.25
	part:SetAttribute("Owner", s.UserId)
	part:SetAttribute("Essence", stain.essence)
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(200, 30, 30)
	glow.Range = 10
	glow.Parent = part
 local attachment=Instance.new("Attachment");attachment.Parent=part
 local wraith=Instance.new("ParticleEmitter");wraith.Name="CrimsonWraith";wraith.Texture=require(Shared.Shared.PresentationAssets).Textures.Smoke;wraith.Enabled=wraith.Texture~=""
 wraith.Color=ColorSequence.new(Color3.fromRGB(205,24,42));wraith.Lifetime=NumberRange.new(1.2,2.2);wraith.Rate=12
 wraith.Speed=NumberRange.new(1,2);wraith.LightEmission=0.7;wraith.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.4),NumberSequenceKeypoint.new(0.5,1.5),NumberSequenceKeypoint.new(1,0)})
 wraith.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.4),NumberSequenceKeypoint.new(1,1)});wraith.Parent=attachment
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Recover Essence"
	prompt.ObjectText = s.Player.DisplayName .. "'s Bloodstain"
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = INTERACT_RADIUS
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	table.insert(connections, prompt.Triggered:Connect(function(player: Player)
		if player.UserId == s.UserId then
			recoverStain(s)
		end
	end))
	CollectionService:AddTag(part, TAG_STAIN)
	part.Parent = folder("Bloodstains", root)
	s.Stain = part
	s.StainDeath = stain.death
	s.Player:SetAttribute("AsuraBloodstain", Vector3.new(stain.x, stain.y, stain.z))
end

recoverStain = function(s: Session): (boolean, string)
	local part = s.Stain
	local position = entityPosition(s.UserId)
	if not part or not position or (position - part.Position).Magnitude > INTERACT_RADIUS + 3 then
		return false, "NoBloodstain"
	end
	local death = s.StainDeath
	destroyStain(s)
	enqueue(s, "RecoverBloodstain", function(store: any): (boolean, string?)
		local ok, err, amount = store:RecoverBloodstain(s.UserId, death)
		if ok then
			Characters.Cue("EssenceRecovered", s.UserId, { amount = amount })
		end
		return ok, err
	end)
	return true, "Recovered"
end

local function onPlayerDeath(s: Session)
	local e = Characters.GetEntity(s.UserId)
	if not e then
		return
	end
	local position = e.Root.Position
	local region = World.regionAt(position.X, position.Y, position.Z) or s.Region or World.startingAltar().Region
	local unbanked = s.Unbanked
	s.Unbanked = 0
	-- The previous bloodstain is forfeit the moment a new death occurs.
	destroyStain(s)
	enqueue(s, "RecordDeath", function(store: any): (boolean, string?)
		local ok, err, dropped = store:RecordDeath(s.UserId, region, position.X, position.Y, position.Z, unbanked)
		if ok then
			local record = souls(s.UserId)
			local stain = record and record.world.bloodstain
			if stain and dropped > 0 then
				placeStain(s, stain)
			end
			Characters.Cue("EssenceLost", s.UserId, { amount = dropped })
		end
		return ok, err
	end)
	s.Elixirs = s.MaxElixirs
	s.ElixirsDirty = true
	local altar = World.Altars[s.ActiveAltar] or World.startingAltar()
	task.delay(Settings.Respawn.PlayerDelay, function()
		if running then
			AI.RespawnRegion(altar.Region, true)
		end
	end)
end

-------------------------------------------------------------------------------------------------
-- Altars, elixirs, progression
-------------------------------------------------------------------------------------------------

local function nearestAltar(position: Vector3): (Altar?, number)
	local best: Altar? = nil
	local bestDistance = math.huge
	for id, altar in World.Altars do
		local part = altarParts[id]
		if part then
			local distance = (part.Position - position).Magnitude
			if distance < bestDistance then
				best, bestDistance = altar, distance
			end
		end
	end
	return best, bestDistance
end

local function restAt(s: Session, altar: Altar): (boolean, string)
	if s.Fight then
		return false, "InBossFight"
	end
	if Characters.IsInDuel(s.UserId) then
		return false, "InDuel"
	end
	if AI.IsHunting(s.UserId) then
		return false, "EnemiesNearby"
	end
	local position = entityPosition(s.UserId)
	local part = altarParts[altar.Id]
	if not position or not part or (position - part.Position).Magnitude > altar.Radius + 2 then
		return false, "TooFar"
	end
	-- The proximity prompt and the Interact intent can both fire for one press; resting is idempotent.
	local fighter = Characters.GetFighter(s.UserId)
	if fighter and fighter.State == "RestingAtShrine" then
		return true, "Resting"
	end
	local ok, reason = Characters.Rest(s.UserId)
	if not ok or reason == "Rose" then
		return ok, reason
	end
	s.ActiveAltar = altar.Id
	s.Altars[altar.Id] = true
	s.Elixirs = s.MaxElixirs
	s.ElixirsDirty = false
	Characters.SetRespawnPoint(s.UserId, toCFrame(altar.Spawn))
	AI.RespawnRegion(altar.Region, true)
	Characters.Cue("AltarRest", s.UserId, { altar = altar.Id, name = altar.Name })
 if (WorldService :: any).OnAltarRest then (WorldService :: any).OnAltarRest(s.Player,altar.Id) end
	flush(s)
	enqueue(s, "ActivateAltar", function(store: any): (boolean, string?)
		return store:ActivateAltar(s.UserId, altar.Id, true, true)
	end)
	return true, "Rest"
end

local function nearAltar(s: Session): Altar?
	local position = entityPosition(s.UserId)
	if not position then
		return nil
	end
	local altar, distance = nearestAltar(position)
	if altar and distance <= altar.Radius + 2 and s.Altars[altar.Id] then
		return altar
	end
	return nil
end

local function drink(s: Session): (boolean, string)
	if s.Elixirs <= 0 then
		return false, "GourdEmpty"
	end
	local ok, reason = Characters.TryHeal(s.UserId, Settings.Elixir.HealFraction + s.Potency * POTENCY_STEP)
	if not ok then
		return false, reason
	end
	s.Elixirs -= 1
	s.ElixirsDirty = true
	s.Player:SetAttribute("AsuraElixirs", s.Elixirs)
	return true, "Drink"
end

local function refreshStats(userId: number)
	local record = souls(userId)
	if record then
		local stats = ProfileStore.DeriveStats(record)
		Characters.ApplyStats(userId, stats, false)
	end
end

local function levelUp(s: Session, attribute: string): (boolean, string)
	if table.find(ProfileStore.Attributes, attribute :: any) == nil then
		return false, "UnknownAttribute"
	end
	if not nearAltar(s) then
		return false, "NotAtAltar"
	end
	flush(s)
	enqueue(s, "LevelUp", function(store: any): (boolean, string?)
		local ok, err = store:LevelAttribute(s.UserId, attribute)
		if ok then
			refreshStats(s.UserId)
			Characters.Cue("LevelUp", s.UserId, { attribute = attribute })
		elseif err == "Not enough essence" or err == "Attribute at maximum" or err == "Level refused" then
			Characters.Cue("LevelRefused", s.UserId, { reason = err })
			return true, nil
		end
		return ok, err
	end)
	return true, "LevelQueued"
end

-- Travel between activated altars: only while at an activated altar, then rest at the destination.
local function travel(s: Session, altarId: string): (boolean, string)
	local destination = World.Altars[altarId]
	if not destination or not s.Altars[altarId] then
		return false, "AltarNotKindled"
	end
	if s.Fight then
		return false, "InBossFight"
	end
	if AI.IsHunting(s.UserId) then
		return false, "EnemiesNearby"
	end
	local origin = nearAltar(s)
	if not origin then
		return false, "NotAtAltar"
	end
	if origin.Id == altarId then
		return false, "AlreadyHere"
	end
	Characters.Teleport(s.UserId, toCFrame(destination.Spawn))
	Characters.Cue("AltarTravel", s.UserId, { from = origin.Id, to = altarId })
	local fighter = Characters.GetFighter(s.UserId)
	if fighter and fighter.State == "RestingAtShrine" then
		fighter.State = "Idle"
		fighter.StateEnd = math.huge
	end
	return restAt(s, destination)
end

local function swap(s: Session): (boolean, string)
	local record = souls(s.UserId)
	if not record then
		return false, "Unavailable"
	end
	local inventory = record.inventory
	if inventory.offhand == "None" then
		return false, "NoOffhand"
	end
	local main, off = inventory.offhand, inventory.mainhand
	local ok, reason = Characters.EquipWeapon(s.UserId, main :: any)
	if not ok then
		return false, reason
	end
	enqueue(s, "Swap", function(store: any): (boolean, string?)
		local ok, err = store:EquipLoadout(s.UserId, main, off)
		if ok then
			-- Reinforcement follows the weapon in hand.
			Characters.RefreshProgression(s.UserId)
		end
		return ok, err
	end)
	return true, main
end

-------------------------------------------------------------------------------------------------
-- Boss fog gates
-------------------------------------------------------------------------------------------------

local function endFight(gateId: string, victory: boolean)
	local fight = fights[gateId]
	if not fight then
		return
	end
	fights[gateId] = nil
	setGate(gateId, false)
	local boss = World.Bosses[fight.BossId]
	for userId in fight.Participants do
		local s = sessions[userId]
		if s then
			s.Fight = nil
			s.Player:SetAttribute("AsuraEncounter", nil)
			if victory then
				s.Bosses[fight.BossId] = true
				publish(s)
				flush(s)
				enqueue(s, "BossDefeat", function(store: any): (boolean, string?)
					return store:RecordBossDefeat(userId, fight.BossId, boss.Essence)
				end)
			end
		end
	end
	local participants = {}
	for userId in fight.Participants do table.insert(participants, userId) end
	if victory then BossArenas.loot(Vector3.new(boss.Arena.Center.X, 3, boss.Arena.Center.Z), boss.Essence) end
	Characters.Cue(if victory then "BossDefeated" else "BossReset", fight.BossEntity,
		{ boss = fight.BossId, gate = gateId, participants = participants, banner = boss.Victory or "GREAT FOE VANQUISHED", essence = boss.Essence })
	if not victory then
		AI.DespawnBoss(fight.BossId)
	end
end

local function startFight(gate: FogGate, entrants: { number })
	local boss = World.Bosses[gate.Boss]
	local participants: { [number]: boolean } = {}
	local list: { number } = {}
	for _, userId in entrants do
		participants[userId] = true
		table.insert(list, userId)
	end
	for userId, s in sessions do
		local position = entityPosition(userId)
		local e = Characters.GetEntity(userId)
		if not participants[userId] and e and e.Fighter.State ~= "KO" and not e.Respawning and not Characters.IsInDuel(userId)
			and position and inBounds(boss.Arena, position) and not s.Bosses[boss.Id] and not s.Fight then
			participants[userId] = true
			table.insert(list, userId)
		end
	end
	local entity = AI.SpawnBoss(boss.Id, list)
	if not entity then
		return
	end
	fights[gate.Id] = { Gate = gate, BossId = boss.Id, BossEntity = entity, Participants = participants, StartedAt = Characters.Now() }
	for userId in participants do
		local s = sessions[userId]
		if s then
			s.Fight = gate.Id
			s.Player:SetAttribute("AsuraEncounter", boss.Id)
		end
	end
	setGate(gate.Id, true)
	Characters.Cue("FogGateSealed", entity, { gate = gate.Id, boss = boss.Id, title = boss.Title, participants = list })
end

local function traverseGate(userId: number, gate: FogGate): (boolean, string)
	local s, e = session(userId), Characters.GetEntity(userId)
	if not s or not e or e.Fighter.State == "KO" or e.Respawning then return false, "Unavailable" end
	if s.Fight or Characters.IsInDuel(userId) then return false, "InBossFight" end
	if s.Bosses[gate.Boss] then return false, "BossFelled" end
	if fights[gate.Id] then return false, "ArenaOccupied" end
	if (e.Root.Position - toCFrame(gate.Placement).Position).Magnitude > 28 then return false, "TooFar" end
	Characters.Teleport(userId, toCFrame(gate.Inside))
	startFight(gate, { userId })
	if not fights[gate.Id] then
		Characters.Teleport(userId, toCFrame(gate.Outside))
		return false, "Unavailable"
	end
	return true, "FogTraversed"
end

local function updateGates()
	for gateId, gate in World.FogGates do
		local boss = World.Bosses[gate.Boss]
		local fight = fights[gateId]
		if fight == nil then
			local entrants: { number } = {}
			for userId, s in sessions do
				local e = Characters.GetEntity(userId)
				if e and e.Fighter.State ~= "KO" and not s.Bosses[boss.Id] and not s.Fight and not Characters.IsInDuel(userId)
					and inBounds(gate.Trigger, e.Root.Position) then
					table.insert(entrants, userId)
				end
			end
			if #entrants > 0 then
				startFight(gate, entrants)
			end
		else
			local living = 0
			for userId in fight.Participants do
				local e = Characters.GetEntity(userId)
				local s = sessions[userId]
				if not s or not e or e.Fighter.State == "KO" or e.Respawning then
					fight.Participants[userId] = nil
					if s then
						s.Fight = nil
						s.Player:SetAttribute("AsuraEncounter", nil)
						Characters.Cue("BossParticipantLeft", userId, { boss = boss.Id })
					end
				else
					living += 1
					if not inBounds(boss.Arena, e.Root.Position) then
						Characters.Teleport(userId, toCFrame(gate.Inside))
					end
				end
			end
			for userId, s in sessions do
				if not fight.Participants[userId] then
					local position = entityPosition(userId)
					if position and inBounds(boss.Arena, position) and s.Fight == nil then
						Characters.Teleport(userId, toCFrame(gate.Outside))
					end
				end
			end
			local remaining: { number } = {}
			for userId in fight.Participants do
				table.insert(remaining, userId)
			end
			AI.SetBossTargets(fight.BossId, remaining)
			if BossRules.lifecycle(living, false, AI.GetBossEntity(fight.BossId) ~= nil) == "Reset" then
				endFight(gateId, false)
			end
		end
	end
end

-------------------------------------------------------------------------------------------------
-- Event wiring
-------------------------------------------------------------------------------------------------

local function onEvent(event: any, _point: Vector3?)
	if event.Kind ~= "KO" then
		return
	end
	local victimSession = sessions[event.Target]
	if victimSession then
		if not Characters.IsInDuel(event.Target) then
			onPlayerDeath(victimSession)
		end
		return
	end
 local agent = AI.GetAgent(event.Target)
 if not agent then return end
 local killer=sessions[event.Source]
 if killer then
  local fighter=Characters.GetFighter(event.Source)
  local weapon=if fighter then fighter.Weapon else "Jian"
  enqueue(killer,"WeaponMastery",function(store: any): (boolean,string?)
   local unlocked=false
   local ok,err=store:Transaction(killer.UserId,function(p: any)
    local rank=Progression.masteryRank(p.weaponMastery[weapon] or 0)
    Progression.mastery(p,weapon,if agent.Kind=="Mob" then 30 else 250)
    unlocked=rank<5 and Progression.masteryRank(p.weaponMastery[weapon] or 0)>=5
    local m=p.inventory.Materials;m.SpiritIronOre=math.min(9007199254740991,(m.SpiritIronOre or 0)+1)
   end)
   if ok then
    Characters.RefreshProgression(killer.UserId)
    if unlocked then Characters.Cue("SignatureUnlocked",killer.UserId,{weapon=weapon}) end
   end
   return ok,err
  end)
  if agent.Kind=="Mob" then
   killer.Unbanked+=agent.Essence;killer.Player:SetAttribute("AsuraUnbanked",killer.Unbanked)
  end
 end
end

local function onBossDefeated(bossId: string, _entityId: number)
	for gateId, fight in fights do
		if fight.BossId == bossId then
			endFight(gateId, true)
		end
	end
end

local function onPlayerAdded(id: number, kind: Characters.EntityKind)
	if kind ~= "Player" then
		return
	end
	local s = session(id)
	if not s then
		return
	end
	local record = souls(id)
	local stain = record and record.world.bloodstain
	if stain and s.Stain == nil then
		placeStain(s, stain)
	end
	publish(s)
end

local function hooks(): Characters.Hooks
	return {
		RespawnPoint = function(userId: number): CFrame?
			local s = session(userId)
			local altar = if s then World.Altars[s.ActiveAltar] else nil
			return toCFrame((altar or World.startingAltar()).Spawn)
		end,
		Stats = function(userId: number): any
			local record = souls(userId)
			return if record then ProfileStore.DeriveStats(record) else nil
		end,
		Loadout = function(userId: number): (string?, string?)
			local record = souls(userId)
			if not record then
				return nil, nil
			end
			return record.inventory.mainhand, record.inventory.offhand
		end,
		CanEquip = function(userId: number, weapon: string): boolean
			local record = souls(userId)
			return record ~= nil and record.inventory.weapons[weapon] == true and Weapons.Weapons[weapon] ~= nil
		end,
		Rest = function(userId: number): (boolean, string)
			local s = session(userId)
			local position = entityPosition(userId)
			if not s or not position then
				return false, "Unavailable"
			end
			local altar = nearestAltar(position)
			if not altar then
				return false, "NoAltar"
			end
			return restAt(s, altar)
		end,
		Heal = function(userId: number): (boolean, string)
			local s = session(userId)
			if not s then
				return false, "Unavailable"
			end
			return drink(s)
		end,
		Interact = function(userId: number): (boolean, string)
			local s = session(userId)
			local position = entityPosition(userId)
			if not s or not position then
				return false, "Unavailable"
			end
			local part = s.Stain
			if part and (position - part.Position).Magnitude <= INTERACT_RADIUS + 3 then
				return recoverStain(s)
			end
			for _, gate in World.FogGates do
				if (position - toCFrame(gate.Placement).Position).Magnitude <= 24 then return traverseGate(userId, gate) end
			end
			local altar, distance = nearestAltar(position)
			if altar and distance <= altar.Radius + 2 then
				return restAt(s, altar)
			end
			for _, handler in interactables do
				local ok, handled, reason = pcall(handler, userId, position)
				if ok and handled ~= nil then
					return handled, reason or "Interacted"
				end
			end
			return false, "NothingNearby"
		end,
		LevelUp = function(userId: number, attribute: string): (boolean, string)
			local s = session(userId)
			if not s then
				return false, "Unavailable"
			end
			return levelUp(s, attribute)
		end,
		Swap = function(userId: number): (boolean, string)
			local s = session(userId)
			if not s then
				return false, "Unavailable"
			end
			return swap(s)
		end,
		Travel = function(userId: number, altarId: string): (boolean, string)
			local s = session(userId)
			if not s then
				return false, "Unavailable"
			end
			return travel(s, altarId)
		end,
	}
end

-------------------------------------------------------------------------------------------------
-- Lifecycle
-------------------------------------------------------------------------------------------------

function WorldService.Start()
	assert(not running, "WorldService already started")
	running = true
	local root = Workspace:FindFirstChild(Config.Names.Root) or Instance.new("Folder")
	if not root.Parent then
		root.Name = Config.Names.Root
		root.Parent = Workspace
	end
	local worldRoot = folder("World", root)
	worldFolder = worldRoot
	registerGroups()
	buildGreybox(worldRoot)
	local altarsFolder = folder("Altars", worldRoot)
	for id, altar in World.Altars do
		local prompt = buildAltar(altar, altarsFolder)
		table.insert(connections, prompt.Triggered:Connect(function(player: Player)
			local s = session(player.UserId)
			if s then
				local ok, reason = restAt(s, World.Altars[id])
				player:SetAttribute("AsuraResult", (if ok then "" else "!") .. reason)
			end
		end))
	end
	BossArenas.build(worldRoot)
	local gatesFolder = folder("FogGates", worldRoot)
	for _, gate in World.FogGates do
		buildGate(gate, gatesFolder)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText, prompt.ObjectText, prompt.HoldDuration = "Traverse the Mist", World.Bosses[gate.Boss].Name, 0.35
		prompt.MaxActivationDistance, prompt.Parent = 18, gateParts[gate.Id]
		table.insert(connections, prompt.Triggered:Connect(function(player: Player) traverseGate(player.UserId, gate) end))
	end
	markGeometry(worldRoot)
	local arena = root:FindFirstChild(Config.Names.Arena)
	if arena then
		markGeometry(arena)
	end
	for _, id in World.RegionOrder do
		local map = Workspace:FindFirstChild(World.Regions[id].MapFolder, true)
		if map then
			markGeometry(map)
		end
	end
	pcall(function()
		(Workspace.Terrain :: any).CollisionGroup = WORLD_GROUP
	end)

	Characters.SetHooks(hooks())
	table.insert(disconnectors, Characters.Subscribe(onEvent))
	table.insert(disconnectors, Characters.OnEntityAdded(onPlayerAdded))
	table.insert(disconnectors, AI.OnBossDefeated(onBossDefeated))
	table.insert(disconnectors, Characters.OnStep(function(_now: number, _dt: number)
		tickCounter += 1
		if tickCounter % GATE_INTERVAL == 0 then
			updateGates()
		end
		if tickCounter % 60 == 0 then
			local clock = os.clock()
			for userId, s in sessions do
				local position = entityPosition(userId)
				if position then
					local region = World.regionAt(position.X, position.Y, position.Z)
					if region ~= s.Region then
						s.Region = region
						s.Player:SetAttribute("AsuraRegion", region)
					end
				end
				if clock - s.LastFlush >= FLUSH_INTERVAL then
					flush(s)
				end
			end
		end
	end))
	table.insert(connections, Players.PlayerRemoving:Connect(function(player: Player)
		local s = sessions[player.UserId]
		if not s then
			return
		end
		for gateId, fight in fights do
			if fight.Participants[player.UserId] then
				fight.Participants[player.UserId] = nil
				if next(fight.Participants) == nil then
					endFight(gateId, false)
				end
			end
		end
		task.defer(function()
			if s.Stain then
				s.Stain:Destroy()
				s.Stain = nil
			end
			if not s.Processing and #s.Queue == 0 then
				sessions[player.UserId] = nil
			end
		end)
	end))

	-- Rig creation yields on asset loads; populate regions off the startup path.
	task.spawn(function()
		for _, id in World.RegionOrder do
			for _, entry in World.spawnsIn(id) do
				if running then
					AI.SpawnMob(entry.Id)
				end
			end
		end
	end)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player.UserId, "Player")
	end
end

function WorldService.Destroy()
	running = false
	for _, disconnect in disconnectors do
		disconnect()
	end
	table.clear(disconnectors)
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	for gateId in fights do
		endFight(gateId, false)
	end
	for _, s in sessions do
		if s.Stain then
			s.Stain:Destroy()
		end
	end
	table.clear(sessions)
	local root = worldFolder
	if root then
		root:Destroy()
		worldFolder = nil
	end
	table.clear(altarParts)
	table.clear(gateParts)
end

-- Blacksmith: reinforce the equipped weapon with banked essence (unbanked essence is banked first).
function WorldService.Refresh(userId: number)
 local s=session(userId);if s then publish(s) end
end

function WorldService.Reinforce(userId: number): (boolean, string)
	local s = session(userId)
	local record = souls(userId)
	if not s or not record then
		return false, "Unavailable"
	end
	if Characters.IsInDuel(userId) then
		return false, "InDuel"
	end
	local weapon = record.inventory.mainhand
	flush(s)
	enqueue(s, "Reinforce", function(store: any): (boolean, string?)
		local ok, err, level = store:ReinforceWeapon(userId, weapon)
		if ok then
			Characters.RefreshProgression(userId)
			Characters.Cue("WeaponReinforced", userId, { weapon = weapon, level = level })
		elseif err ~= "Profile is busy" and err ~= "Profile session unavailable" then
			local current = souls(userId)
			Characters.Cue("ReinforceRefused", userId, {
				reason = err,
				weapon = weapon,
				cost = if current then ProfileStore.ReinforceCost(ProfileStore.ReinforceLevel(current, weapon)) else 0,
			})
			return true, nil
		end
		return ok, err
	end)
	return true, "ReinforceQueued"
end

-- Blacksmith: refill the gourd outside the rest ritual (no enemy respawn, no checkpoint change).
function WorldService.RefillElixirs(userId: number): (boolean, string)
	local s = session(userId)
	if not s then
		return false, "Unavailable"
	end
	if s.Elixirs >= s.MaxElixirs then
		return false, "GourdFull"
	end
	s.Elixirs = s.MaxElixirs
	s.ElixirsDirty = true
	s.Player:SetAttribute("AsuraElixirs", s.Elixirs)
	flush(s)
	Characters.Cue("GourdRefilled", userId, { charges = s.Elixirs })
	return true, "Refilled"
end

function WorldService.RegisterInteractable(handler: Interactable): () -> ()
	table.insert(interactables, handler)
	return function()
		local index = table.find(interactables, handler)
		if index then
			table.remove(interactables, index)
		end
	end
end

function WorldService.GetSession(userId: number): any
	return sessions[userId]
end

function WorldService.IsInBossFight(userId: number): boolean
	local s = sessions[userId]
	return s ~= nil and s.Fight ~= nil
end

return WorldService
