--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/CharacterService
-- Authoritative entity coordinator for player characters and PvE humanoids. Runs CombatRules on a
-- fixed 60 Hz clock, resolves weapon contact through LagCompensation and replicates each fighter as
-- a packed base64 attribute plus a batched event stream. Behaviour (AI) and world rules (altars,
-- bloodstains, progression) attach through step listeners, event subscriptions and hooks.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("AsurasPath")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript) :: any
local Settings = require(Shared.Shared.CombatSettings) :: any
local Schema = require(Shared.Simulation.MoveSchema) :: any
local Weapons = require(Shared.Simulation.WeaponSchema) :: any
local Combat = require(Shared.Simulation.CombatRules)
local InputBuffer = require(Shared.Simulation.InputBuffer)
local Tempo = require(Shared.Simulation.Tempo) :: any
local Protocol = require(Shared.Shared.IntentProtocol)
local Lag = require(script.Parent:WaitForChild("LagCompensation") :: ModuleScript)

local Persistence: any = nil
pcall(function()
	Persistence = require(script.Parent:WaitForChild("PersistenceService", 5) :: ModuleScript)
end)

type Fighter = Combat.Fighter
type Event = Combat.Event
type History = Lag.History
type Bucket = Protocol.Bucket
type WeaponType = Combat.WeaponType
export type EntityKind = "Player" | "Enemy"

export type EnemySpec = {
	Name: string,
	Weapon: WeaponType,
	CFrame: CFrame,
	Template: Model?,
	Stats: Combat.Stats?,
	Definition: string?,
	BodyColor: { number }?,
	Boss: boolean?,
}

export type Hooks = {
	RespawnPoint: ((userId: number) -> CFrame?)?,
	Stats: ((userId: number) -> Combat.Stats?)?,
	Loadout: ((userId: number) -> (string?, string?))?,
	CanEquip: ((userId: number, weapon: string) -> boolean)?,
	Rest: ((userId: number) -> (boolean, string))?,
	Heal: ((userId: number) -> (boolean, string))?,
	Interact: ((userId: number) -> (boolean, string))?,
	LevelUp: ((userId: number, attribute: string) -> (boolean, string))?,
	Swap: ((userId: number) -> (boolean, string))?,
	Travel: ((userId: number, altarId: string) -> (boolean, string))?,
}

export type Entity = {
	Id: number,
	Kind: EntityKind,
	Player: Player?,
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Fighter: Fighter,
	History: History,
	Buffer: InputBuffer.Buffer,
	Eligible: InputBuffer.Filter,
	Actions: Bucket,
	LastSeq: number,
	Scratch: buffer,
	Packed: string,
	MirroredHealth: number,
	WalkSpeed: number,
	JumpHeight: number,
	AppliedDashSeq: number,
	WeaponPart: BasePart?,
	Connections: { RBXScriptConnection },
	RespawnAt: number,
	DespawnAt: number,
	Respawning: boolean,
	Shrine: CFrame?,
	Duel: string?,
	SpawnOverride: CFrame?,
	Definition: string?,
	Boss: boolean,
	LastMoveTo: Vector3,
	Style: string,
	Elo: number,
	Vip: boolean,
	Cosmetics: any,
}

type Duel = {
	Id: string,
	Mode: string,
	A: number,
	B: number,
	Complete: (string, number?, boolean, number, { [number]: number }) -> any,
	Finished: boolean,
	Spawns: { CFrame }?,
	Xp: { [number]: number },
}

type EventListener = (event: Event, point: Vector3?) -> ()
type StepListener = (now: number, dt: number) -> ()
type EntityListener = (id: number, kind: EntityKind) -> ()

local Service = {}
local Appearance = require(script.Parent:WaitForChild("FighterAppearance") :: ModuleScript)
local EnemyAppearance = require(script.Parent:WaitForChild("EnemyAppearance") :: ModuleScript)

local TICK: number = Tempo.TickSeconds
local MAX_CATCHUP: number = Config.Movement.MaxCatchupSteps
local MAX_FRAME_DELTA: number = Config.Movement.MaxFrameDelta
local SNAPSHOT_INTERVAL = math.max(1, math.floor(Tempo.TickRate / Config.Network.SnapshotRate + 0.5))
local STATE_ATTRIBUTE = "AsuraState"
local ID_ATTRIBUTE = "AsuraId"
local ENEMY_TAG = "AsuraEnemy"
local FACING_DOT = 0.15
local PROTOCOL_TAG = "Asura1"
local MAX_SEQUENCE_GAP = 4096
local DEFAULT_JUMP = 7.2

local INTENT_ACTIONS: { [string]: boolean } = {
	Light = true,
	Heavy = true,
	WeaponArt = true,
	Roll = true,
	Dash = true,
	Deflect = true,
	Block = true,
	Sprint = true,
	Feint = true,
	Equip = true,
	Swap = true,
	Rest = true,
	Heal = true,
	Interact = true,
	LevelUp = true,
	Travel = true,
}
local BUFFERED: { [string]: boolean } = { Light = true, Heavy = true, WeaponArt = true, Roll = true, Dash = true, Deflect = true }
local INTENT_KEYS: { [string]: string } = {
	seq = "number",
	action = "string",
	time = "number",
	variant = "string",
	x = "number",
	z = "number",
	held = "boolean",
}

local WEAPON_VISUALS: { [string]: { Size: Vector3, Color: Color3, Material: Enum.Material } } = {
	Jian = { Size = Vector3.new(0.12, 0.28, 4.2), Color = Color3.fromRGB(196, 202, 210), Material = Enum.Material.Metal },
	Dao = { Size = Vector3.new(0.16, 0.5, 3.6), Color = Color3.fromRGB(170, 160, 150), Material = Enum.Material.Metal },
	Guandao = { Size = Vector3.new(0.22, 0.22, 8.5), Color = Color3.fromRGB(92, 70, 52), Material = Enum.Material.Wood },
}

local entities: { [number]: Entity } = {}
local byModel: { [Model]: Entity } = {}
local playerConnections: { [number]: { RBXScriptConnection } } = {}
local pendingSpawn: { [number]: boolean } = {}
local retryAt: { [number]: number } = {}
local connections: { RBXScriptConnection } = {}
local frameEvents: { Event } = {}
local eventPoints: { [Event]: Vector3 } = {}
local stepTimes: { number } = {}
local eventListeners: { EventListener } = {}
local stepListeners: { StepListener } = {}
local addedListeners: { EntityListener } = {}
local removedListeners: { EntityListener } = {}
local hooks: Hooks = {}
local stepTimeIndex = 0
local droppedSteps = 0
local running = false
local accumulator = 0
local tickCount = 0
local simTime = 0
local nextEnemyId = -1
local duels: { [string]: Duel } = {}

local net = Shared:WaitForChild("Net")
local actionRemote = net:WaitForChild("ActionIntent") :: RemoteEvent
local eventRemote = net:WaitForChild("StateSnapshots") :: RemoteEvent

local function rootFolder(name: string): Folder
	local root = Workspace:FindFirstChild(Config.Names.Root)
	if not root then
		local folder = Instance.new("Folder")
		folder.Name = Config.Names.Root
		folder.Parent = Workspace
		root = folder
	end
	local child = (root :: Instance):FindFirstChild(name)
	if not child then
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = root
		child = folder
	end
	return child :: Folder
end

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function notify(list: { EntityListener }, id: number, kind: EntityKind)
	for _, listener in table.clone(list) do
		local ok, problem = pcall(listener, id, kind)
		if not ok then
			warn("[CharacterService] Entity listener failed: " .. tostring(problem))
		end
	end
end

local function subscribe<T>(list: { T }, listener: T): () -> ()
	table.insert(list, listener)
	return function()
		local index = table.find(list, listener)
		if index then
			table.remove(list, index)
		end
	end
end

local function awardXp(e: Entity, amount: number)
	local duelId = e.Duel
	local active = if duelId then duels[duelId] else nil
	if not active or active.Finished or active.Mode ~= "Ranked1v1" or e.Kind ~= "Player" then
		return
	end
	active.Xp[e.Id] = (active.Xp[e.Id] or 0) + amount
end

local function hostile(a: Entity, b: Entity): boolean
	if a.Id == b.Id then
		return false
	end
	-- Duelists are sealed inside their match: nothing outside it can strike in, nor they out.
	if (a.Duel ~= nil) ~= (b.Duel ~= nil) then
		return false
	end
	if a.Kind ~= b.Kind then
		return true
	end
	if a.Kind == "Enemy" then
		return false
	end
	if a.Duel ~= nil and a.Duel == b.Duel then
		return true
	end
	return Workspace:GetAttribute("AsuraOpenPvP") == true and a.Duel == nil and b.Duel == nil
end

local function flatUnit(v: Vector3): Vector3
	local flat = Vector3.new(v.X, 0, v.Z)
	local magnitude = flat.Magnitude
	if magnitude < 1e-5 then
		return Vector3.zero
	end
	return flat / magnitude
end

local function facingDot(from: Entity, toward: Entity): number
	local look = flatUnit(from.Root.CFrame.LookVector)
	local direction = flatUnit(toward.Root.Position - from.Root.Position)
	return look:Dot(direction)
end

local function alive(e: Entity): boolean
	return e.Model.Parent ~= nil and e.Humanoid.Parent ~= nil and e.Root.Parent ~= nil
end

-------------------------------------------------------------------------------------------------
-- Weapon visuals, tint and procedural weapon volumes
-------------------------------------------------------------------------------------------------

local function attachWeapon(e: Entity)
	if e.WeaponPart then
		e.WeaponPart:Destroy()
		e.WeaponPart = nil
	end
	local visual = WEAPON_VISUALS[e.Fighter.Weapon]
	e.Model:SetAttribute("AsuraWeapon", e.Fighter.Weapon)
	if visual == nil then
		return
	end
	local hand = e.Model:FindFirstChild("RightHand") or e.Model:FindFirstChild("Right Arm")
	if not hand or not hand:IsA("BasePart") then
		return
	end
	local part = Instance.new("Part")
	part.Name = "AsuraWeapon"
	part.Size = visual.Size
	part.Color = visual.Color
	part.Material = visual.Material
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.Anchored = false
	part.CFrame = hand.CFrame * CFrame.new(0, -hand.Size.Y * 0.5, -visual.Size.Z * 0.5 + 0.4)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = part
	weld.Parent = part
	part.Parent = e.Model
	e.WeaponPart = part
end

local function tint(model: Model, rgb: { number })
	local color = Color3.fromRGB(rgb[1] or 255, rgb[2] or 255, rgb[3] or 255)
	local attire = model:FindFirstChild("AsuraAttire")
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" and descendant.Name ~= "AsuraWeapon"
			and not (attire and descendant:IsDescendantOf(attire)) then
			descendant.Color = color
		end
	end
end

-- World-space weapon segment for a move at `progress` through its active frames. Slashes sweep the
-- authored arc around the root; thrusts extend along the facing. Lunge and fighter reach bonus are
-- folded into the tip.
local function weaponSegment(rootCFrame: CFrame, move: Combat.MoveData, progress: number, bonus: number): (Vector3, Vector3)
	local reach = move.Reach + bonus + move.Lunge * 0.35 * progress
	if move.Arc > 40 then
		local angle = math.rad(move.Arc) * (progress - 0.5)
		local direction = Vector3.new(math.sin(angle), 0, -math.cos(angle))
		local shoulder = Vector3.new(0, 0.6, 0)
		return rootCFrame:PointToWorldSpace(shoulder + direction * 0.8), rootCFrame:PointToWorldSpace(shoulder + direction * reach)
	end
	local extension = reach * (0.55 + 0.45 * progress)
	return rootCFrame:PointToWorldSpace(Vector3.new(0, 0.6, -0.8)), rootCFrame:PointToWorldSpace(Vector3.new(0, 0.6, -extension))
end

local function weaponRadius(f: Fighter): number
	return if f.Weapon == "Unarmed" then 0.55 else 0.3
end

-------------------------------------------------------------------------------------------------
-- Entity construction
-------------------------------------------------------------------------------------------------

local function eligibleFor(e: Entity): InputBuffer.Filter
	return function(action: InputBuffer.BufferedAction, _variant: string): boolean
		local f = e.Fighter
		local now = simTime
		if action == "Light" then
			local kind: Combat.MoveKind = if f.Sprinting and f.State == "Idle" then "RunningAttack" else "Light"
			local move = Combat.selectMove(f, kind, now)
			return (Schema.canAct(f.State, kind, f.Stamina, f.Posture, Combat.context(f, now, { StaminaCost = move.StaminaCost })))
		elseif action == "Heavy" or action == "WeaponArt" then
			local move = Combat.selectMove(f, action :: Combat.MoveKind, now)
			local extra = { StaminaCost = move.StaminaCost, QiCost = if move.QiCost > 0 then move.QiCost else nil, TargetDeathblowable = true }
			return (Schema.canAct(f.State, action, f.Stamina, f.Posture, Combat.context(f, now, extra)))
				or (action == "Heavy" and (Schema.canAct(f.State, "Deathblow", f.Stamina, f.Posture, Combat.context(f, now, extra))))
		end
		return (Schema.canAct(f.State, action, f.Stamina, f.Posture, Combat.context(f, now)))
	end
end

local function disconnectAll(list: { RBXScriptConnection })
	for _, connection in list do
		connection:Disconnect()
	end
	table.clear(list)
end

local function mirrorHealth(e: Entity)
	local f = e.Fighter
	local health = if f.State == "KO" then 0 else math.max(f.ActiveHP, 0.01)
	local maximum = f.MaxHP
	if math.abs(e.Humanoid.MaxHealth - maximum) > 0.005 then
		e.Humanoid.MaxHealth = maximum
	end
	if math.abs(health - e.MirroredHealth) > 0.005 then
		e.MirroredHealth = health
		e.Humanoid.Health = health
	end
end

local function bindModel(e: Entity)
	local humanoid = e.Humanoid
	humanoid.MaxHealth = e.Fighter.MaxHP
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = DEFAULT_JUMP
	humanoid.WalkSpeed = Settings.Movement.WalkSpeed
	e.WalkSpeed = Settings.Movement.WalkSpeed
	e.JumpHeight = DEFAULT_JUMP
	e.MirroredHealth = -1
	mirrorHealth(e)
	local regen = e.Model:FindFirstChild("Health")
	if regen and regen:IsA("Script") then
		regen:Destroy()
	end
	e.Model:SetAttribute(ID_ATTRIBUTE, e.Id)
	e.Model:SetAttribute("AsuraKind", e.Kind)
	e.Model:SetAttribute("AsuraStyle", e.Style)
	if e.Definition then
		e.Model:SetAttribute("AsuraDefinition", e.Definition)
	end
	byModel[e.Model] = e
	if e.Kind == "Player" then
		Appearance.Apply(e.Model, e.Connections)
		local player = e.Player
		local model = e.Model
		if player then
			table.insert(e.Connections, player.CharacterAppearanceLoaded:Connect(function(loaded: Model)
				if loaded == model and e.Model == model then
					Appearance.Apply(model, e.Connections)
					attachWeapon(e)
				end
			end))
		end
	end
	table.insert(e.Connections, humanoid.HealthChanged:Connect(function(health: number)
		-- Health only falls below the mirror through outside sources (void, hazards, scripts).
		if health < e.MirroredHealth - 0.5 and e.Fighter.State ~= "KO" then
			local loss = e.MirroredHealth - health
			e.MirroredHealth = health
			Combat.applyExternalDamage(e.Fighter, loss, simTime, frameEvents)
		end
	end))
	table.insert(e.Connections, humanoid.Died:Connect(function()
		Combat.knockOut(e.Fighter, simTime, frameEvents)
	end))
	attachWeapon(e)
	e.Packed = ""
end

local function newEntity(id: number, kind: EntityKind, player: Player?, model: Model, humanoid: Humanoid, root: BasePart, weapon: WeaponType): Entity
	local e: Entity = {
		Id = id,
		Kind = kind,
		Player = player,
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Fighter = Combat.new(id, weapon, simTime),
		History = Lag.newHistory(),
		Buffer = InputBuffer.new(),
		Eligible = function()
			return false
		end,
		Actions = { tokens = Config.Network.ActionBurst, time = os.clock() },
		LastSeq = 0,
		Scratch = buffer.create(Combat.PACKET_SIZE),
		Packed = "",
		MirroredHealth = -1,
		WalkSpeed = 0,
		JumpHeight = 0,
		AppliedDashSeq = 0,
		WeaponPart = nil,
		Connections = {},
		RespawnAt = math.huge,
		DespawnAt = math.huge,
		Respawning = false,
		Shrine = nil,
		Duel = nil,
		SpawnOverride = nil,
		Definition = nil,
		Boss = false,
		LastMoveTo = Vector3.new(math.huge, 0, 0),
		Style = "Unarmed",
		Elo = 1000,
		Vip = false,
		Cosmetics = nil,
	}
	e.Eligible = eligibleFor(e)
	return e
end

local function releaseModel(e: Entity)
	disconnectAll(e.Connections)
	byModel[e.Model] = nil
	if e.WeaponPart then
		e.WeaponPart:Destroy()
		e.WeaponPart = nil
	end
end

local function removeEntity(id: number, destroyModel: boolean)
	local e = entities[id]
	if not e then
		return
	end
	releaseModel(e)
	entities[id] = nil
	if destroyModel and e.Model.Parent then
		e.Model:Destroy()
	end
	for _, other in entities do
		if other.Fighter.DeathblowPartner == id then
			other.Fighter.DeathblowPartner = 0
		end
	end
	notify(removedListeners, id, e.Kind)
end

-------------------------------------------------------------------------------------------------
-- Spawning: players, enemies, duels
-------------------------------------------------------------------------------------------------

local function defaultSpawn(): CFrame
	local spawn = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawn then
		return spawn.CFrame * CFrame.new(0, spawn.Size.Y * 0.5 + 3, 0)
	end
	return CFrame.new(0, Config.Movement.RootHeight + 2, 0)
end

local function duelSpawn(slot: number): CFrame
	local z = if slot == 1 then Config.Arena.SpawnDistance else -Config.Arena.SpawnDistance
	local position = Vector3.new(0, Config.Movement.RootHeight, z)
	return CFrame.lookAt(position, Vector3.new(0, Config.Movement.RootHeight, 0))
end

local function spawnCFrameFor(e: Entity): CFrame
	local override = e.SpawnOverride
	if override then
		e.SpawnOverride = nil
		return override
	end
	local duelId = e.Duel
	local active = if duelId then duels[duelId] else nil
	if active then
		local slot = if e.Id == active.A then 1 else 2
		local spawns = active.Spawns
		return if spawns and spawns[slot] then spawns[slot] else duelSpawn(slot)
	end
	local resolver = hooks.RespawnPoint
	if resolver and e.Kind == "Player" then
		local ok, point = pcall(resolver, e.Id)
		if ok and point then
			return point
		end
	end
	return e.Shrine or defaultSpawn()
end

local function loadProfile(e: Entity)
	local player = e.Player
	if not player or not Persistence then
		return
	end
	local ok, profile = pcall(Persistence.Get, player.UserId)
	if not ok or not profile then
		return
	end
	e.Elo = profile.elo or e.Elo
	e.Vip = profile.ownedCosmetics ~= nil and profile.ownedCosmetics.VIP_Pass == true
	e.Style = if type(profile.activeStyle) == "string" and profile.activeStyle ~= "" then profile.activeStyle else e.Style
	e.Cosmetics = profile.equippedCosmetics
end

local function applyPlayerProgression(e: Entity)
	local statsHook = hooks.Stats
	if statsHook then
		local ok, stats = pcall(statsHook, e.Id)
		if ok and stats then
			Combat.applyStats(e.Fighter, stats, true)
		end
	end
	local loadoutHook = hooks.Loadout
	if loadoutHook then
		local ok, mainhand = pcall(loadoutHook, e.Id)
		if ok and type(mainhand) == "string" and Weapons.Weapons[mainhand] then
			Combat.forceWeapon(e.Fighter, mainhand :: WeaponType)
		end
	end
end

local function onCharacter(player: Player, model: Model)
	local humanoid = model:WaitForChild("Humanoid", 10)
	local root = model:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not humanoid:IsA("Humanoid") or not root or not root:IsA("BasePart") or not player.Parent then
		return
	end
	-- CharacterAdded can precede the body assembly. The outfit and held weapon need the limbs.
	local r15 = humanoid.RigType == Enum.HumanoidRigType.R15
	local head = model:WaitForChild("Head", 10)
	local torso = model:WaitForChild(if r15 then "UpperTorso" else "Torso", 10)
	local hand = model:WaitForChild(if r15 then "RightHand" else "Right Arm", 10)
	if not head or not torso or not hand or player.Character ~= model then return end
	local id = player.UserId
	local existing = entities[id]
	local created = existing == nil
	local e: Entity
	if existing then
		releaseModel(existing)
		existing.Model = model
		existing.Humanoid = humanoid
		existing.Root = root
		e = existing
	else
		e = newEntity(id, "Player", player, model, humanoid, root, "Unarmed")
		entities[id] = e
		loadProfile(e)
	end
	Combat.restore(e.Fighter, simTime, true)
	applyPlayerProgression(e)
	Combat.restore(e.Fighter, simTime, true)
	e.Fighter.State = "Idle"
	e.Fighter.StateStart = simTime
	e.Fighter.StateEnd = math.huge
	e.RespawnAt = math.huge
	e.Respawning = false
	Lag.clear(e.History)
	InputBuffer.clear(e.Buffer)
	bindModel(e)
	model:SetAttribute("AsuraDuel", e.Duel)
	model:PivotTo(spawnCFrameFor(e))
	if e.Cosmetics then
		model:SetAttribute("Trunks", e.Cosmetics.Trunks)
		model:SetAttribute("Gloves", e.Cosmetics.Gloves)
	end
	if created then
		notify(addedListeners, id, "Player")
	end
end

local function requestCharacter(player: Player)
	local id = player.UserId
	if pendingSpawn[id] or not player.Parent then
		return
	end
	pendingSpawn[id] = true
	task.spawn(function()
		local ok, problem = pcall(function()
			player:LoadCharacter()
			-- Avatar assembly may replace early cosmetic parts while applying its description.
			local current = entities[id]
			if current and current.Model == player.Character then
				Appearance.Apply(current.Model, current.Connections)
				attachWeapon(current)
			end
		end)
		pendingSpawn[id] = nil
		if not ok then
			warn("[CharacterService] LoadCharacter failed for " .. tostring(id) .. ": " .. tostring(problem))
			retryAt[id] = os.clock() + 2
			local e = entities[id]
			if e then
				e.Respawning = false
			end
		end
	end)
end

local function trackPlayer(player: Player)
	local id = player.UserId
	if playerConnections[id] then
		return
	end
	local list: { RBXScriptConnection } = {}
	playerConnections[id] = list
	table.insert(list, player.CharacterAdded:Connect(function(model: Model)
		onCharacter(player, model)
	end))
	table.insert(list, player.CharacterRemoving:Connect(function(model: Model)
		local e = entities[id]
		if e and e.Model == model then
			releaseModel(e)
		end
	end))
end

local function profileReady(player: Player): boolean
	if not Persistence then
		return true
	end
	local ok, profile = pcall(Persistence.Get, player.UserId)
	return ok and profile ~= nil
end

local function ensurePlayer(player: Player)
	trackPlayer(player)
	local e = entities[player.UserId]
	if e and alive(e) then
		return
	end
	if player.Character and player.Character.Parent then
		task.spawn(onCharacter, player, player.Character)
		return
	end
	requestCharacter(player)
end

local function buildEnemyModel(spec: EnemySpec): Model?
	if spec.Template then
		return spec.Template:Clone()
	end
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if not ok then
		warn("[CharacterService] Enemy rig creation failed: " .. tostring(model))
		return nil
	end
	return model
end

local function spawnEnemy(spec: EnemySpec, existing: Model?): number?
	local model = existing or buildEnemyModel(spec)
	if not model then
		return nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		warn("[CharacterService] Enemy model lacks Humanoid/HumanoidRootPart: " .. spec.Name)
		if not existing then
			model:Destroy()
		end
		return nil
	end
	local id = nextEnemyId
	nextEnemyId -= 1
	model.Name = spec.Name
	humanoid.DisplayName = spec.Name
	-- Authored enemy looks (EnemyAppearance) replace the flat body tint for known mobs.
	local dressed = model:FindFirstChild("AsuraAttire") ~= nil or EnemyAppearance.Apply(model, spec.Definition)
	if spec.BodyColor and not dressed then
		tint(model, spec.BodyColor)
	end
	if not existing then
		model.Parent = rootFolder("Entities")
	end
	model:PivotTo(spec.CFrame)
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	local e = newEntity(id, "Enemy", nil, model, humanoid, root, spec.Weapon)
	e.Style = spec.Weapon
	e.Definition = spec.Definition
	e.Boss = spec.Boss == true
	if spec.Stats then
		Combat.applyStats(e.Fighter, spec.Stats, true)
	end
	entities[id] = e
	bindModel(e)
	model:SetAttribute("AsuraBoss", e.Boss)
	notify(addedListeners, id, "Enemy")
	return id
end

local function registerTagged(instance: Instance)
	if not instance:IsA("Model") or byModel[instance] or not instance:IsDescendantOf(Workspace) then
		return
	end
	local weaponName = instance:GetAttribute("Weapon")
	local weapon: WeaponType = if type(weaponName) == "string" and Weapons.Weapons[weaponName] then weaponName :: WeaponType else "Unarmed"
	local definition = instance:GetAttribute("Definition")
	spawnEnemy({
		Name = instance.Name,
		Weapon = weapon,
		CFrame = instance:GetPivot(),
		Definition = if type(definition) == "string" then definition else nil,
	}, instance)
end

-------------------------------------------------------------------------------------------------
-- Intent handling
-------------------------------------------------------------------------------------------------

local function validIntent(packet: any, lastSeq: number): boolean
	if type(packet) ~= "table" then
		return false
	end
	local count = 0
	for key, value in packet do
		count += 1
		if count > 7 or type(key) ~= "string" then
			return false
		end
		local expected = INTENT_KEYS[key]
		if expected == nil or type(value) ~= expected then
			return false
		end
		if expected == "number" and (value ~= value or math.abs(value) == math.huge) then
			return false
		end
	end
	local seq, action = packet.seq, packet.action
	if type(seq) ~= "number" or seq % 1 ~= 0 or seq <= lastSeq or seq > lastSeq + MAX_SEQUENCE_GAP then
		return false
	end
	if type(action) ~= "string" or not INTENT_ACTIONS[action] or type(packet.time) ~= "number" then
		return false
	end
	if packet.variant ~= nil and #packet.variant > 32 then
		return false
	end
	if packet.x ~= nil and math.abs(packet.x) > 1.001 then
		return false
	end
	if packet.z ~= nil and math.abs(packet.z) > 1.001 then
		return false
	end
	return true
end

local function report(e: Entity, seq: number, ok: boolean, reason: string)
	local player = e.Player
	if player then
		player:SetAttribute("AsuraAck", seq)
		player:SetAttribute("AsuraResult", (if ok then "" else "!") .. reason)
	end
end

local function findDeathblowTarget(attacker: Entity, now: number): Entity?
	local best: Entity? = nil
	local bestDistance = math.huge
	for _, other in entities do
		if other.Fighter.State == "StanceBroken" and hostile(attacker, other) and alive(other) then
			local distance = (other.Root.Position - attacker.Root.Position).Magnitude
			if distance < bestDistance then
				local ok = Combat.canDeathblow(attacker.Fighter, other.Fighter, distance, facingDot(attacker, other), now)
				if ok then
					best, bestDistance = other, distance
				end
			end
		end
	end
	return best
end

local function applyDash(e: Entity)
	local f = e.Fighter
	if f.DashSeq == e.AppliedDashSeq then
		return
	end
	e.AppliedDashSeq = f.DashSeq
	if e.Kind ~= "Enemy" or f.DashDuration <= 0 then
		-- Players own their assembly; the client executes the granted displacement from the replicated record.
		return
	end
	local direction = Vector3.new(f.DashDirX, 0, f.DashDirZ)
	if direction.Magnitude < 1e-3 then
		direction = -flatUnit(e.Root.CFrame.LookVector)
	end
	local velocity = direction * (f.DashDistance / f.DashDuration)
	e.Root.AssemblyLinearVelocity = Vector3.new(velocity.X, e.Root.AssemblyLinearVelocity.Y, velocity.Z)
end

local function perform(e: Entity, action: string, pressTime: number, dirX: number, dirZ: number): (boolean, string)
	local f = e.Fighter
	local now = simTime
	if action == "Light" then
		local kind: Combat.MoveKind = if f.Sprinting and f.State == "Idle" then "RunningAttack" else "Light"
		return Combat.tryAttack(f, kind, now)
	elseif action == "Heavy" then
		local victim = findDeathblowTarget(e, now)
		if victim then
			local dealt = Combat.executeDeathblow(f, victim.Fighter, now, frameEvents)
			eventPoints[frameEvents[#frameEvents]] = victim.Root.Position
			awardXp(e, 60)
			local look = flatUnit(victim.Root.Position - e.Root.Position)
			if e.Kind == "Enemy" and look.Magnitude > 0 then
				e.Root.CFrame = CFrame.lookAt(e.Root.Position, e.Root.Position + look)
			end
			return true, "Deathblow:" .. string.format("%.1f", dealt)
		end
		return Combat.tryAttack(f, "Heavy", now)
	elseif action == "WeaponArt" then
		return Combat.tryAttack(f, "WeaponArt", now)
	elseif action == "Roll" or action == "Dash" then
		local grant, reason = Combat.tryDash(f, action :: "Roll" | "Dash", now, dirX, dirZ, frameEvents)
		if grant then
			applyDash(e)
			return true, reason
		end
		return false, reason
	elseif action == "Deflect" then
		return Combat.tryDeflect(f, now, pressTime)
	end
	return false, "UnknownAction"
end

local function callHook(name: string, ...: any): (boolean, string)
	local hook = (hooks :: any)[name]
	if hook == nil then
		return false, "Unavailable"
	end
	local ok, accepted, reason = pcall(hook, ...)
	if not ok then
		warn("[CharacterService] " .. name .. " hook failed: " .. tostring(accepted))
		return false, "Error"
	end
	return accepted == true, if type(reason) == "string" then reason else name
end

local function immediate(e: Entity, packet: any): (boolean, string)
	local f = e.Fighter
	local now = simTime
	local action: string = packet.action
	if action == "Block" then
		return Combat.setGuard(f, packet.held == true, now)
	elseif action == "Sprint" then
		local ok = Combat.setSprint(f, packet.held == true, now)
		return ok, if ok then "Sprint" else "SprintRefused"
	elseif action == "Feint" then
		return Combat.tryFeint(f, now, frameEvents)
	elseif action == "Equip" then
		local weapon = packet.variant
		if type(weapon) ~= "string" or Weapons.Weapons[weapon] == nil then
			return false, "UnknownWeapon"
		end
		local guard = hooks.CanEquip
		if guard and not guard(e.Id, weapon) then
			return false, "WeaponLocked"
		end
		local ok, reason = Combat.tryEquip(f, weapon :: WeaponType, now)
		if ok then
			attachWeapon(e)
		end
		return ok, reason
	elseif action == "Swap" then
		return callHook("Swap", e.Id)
	elseif action == "Rest" then
		if e.Duel then
			return false, "InDuel"
		end
		return callHook("Rest", e.Id)
	elseif action == "Heal" then
		return callHook("Heal", e.Id)
	elseif action == "Interact" then
		return callHook("Interact", e.Id)
	elseif action == "LevelUp" then
		return callHook("LevelUp", e.Id, packet.variant or "")
	elseif action == "Travel" then
		if e.Duel then
			return false, "InDuel"
		end
		return callHook("Travel", e.Id, packet.variant or "")
	end
	return false, "UnknownAction"
end

local function onIntent(player: Player, packet: any)
	if not running then
		return
	end
	local e = entities[player.UserId]
	if not e or e.Respawning then
		return
	end
	if not Protocol.Take(e.Actions, os.clock(), 1, Config.Network.ActionsPerSecond, Config.Network.ActionBurst) then
		return
	end
	if not validIntent(packet, e.LastSeq) then
		return
	end
	e.LastSeq = packet.seq
	local action: string = packet.action
	if BUFFERED[action] then
		local pressTime = Tempo.reconcile(packet.time, simTime, Lag.MAX_REWIND)
		InputBuffer.push(e.Buffer, action :: InputBuffer.BufferedAction, pressTime, packet.variant, packet.x, packet.z)
		report(e, packet.seq, true, "Buffered")
		return
	end
	local ok, reason = immediate(e, packet)
	report(e, packet.seq, ok, reason)
end

local function drainBuffer(e: Entity)
	if InputBuffer.count(e.Buffer) == 0 then
		return
	end
	local action, pressTime, _variant, dirX, dirZ = InputBuffer.pop(e.Buffer, simTime, e.Eligible)
	if action == nil then
		return
	end
	local ok, reason = perform(e, action, pressTime or simTime, dirX or 0, dirZ or 0)
	local player = e.Player
	if player then
		player:SetAttribute("AsuraResult", (if ok then "" else "!") .. reason)
	end
end

-------------------------------------------------------------------------------------------------
-- Simulation step
-------------------------------------------------------------------------------------------------

local function resolveContacts(attacker: Entity, now: number)
	local f = attacker.Fighter
	local move = f.Move
	local progress = Combat.activeProgress(f, now)
	if move == nil or progress == nil then
		return
	end
	local previous = math.max(0, progress - TICK / math.max(move.Timing.ActiveSeconds, TICK))
	local rootCFrame = attacker.Root.CFrame
	local prevA, prevB = weaponSegment(rootCFrame, move, previous, f.ReachBonus)
	local curA, curB = weaponSegment(rootCFrame, move, progress, f.ReachBonus)
	local radius = weaponRadius(f)
	local player = attacker.Player
	local rewindTo = if player then Lag.rewindTime(now, nil, player:GetNetworkPing()) else now
	for _, defender in entities do
		if defender ~= attacker and not f.HitRegistry[defender.Id] and defender.Fighter.State ~= "KO" and alive(defender) and hostile(attacker, defender) then
			local hit = Lag.queryHit(prevA, prevB, curA, curB, radius, defender.History, rewindTo, TICK)
			if hit then
				local before = #frameEvents
				local outcome = Combat.resolveHit(f, defender.Fighter, now, {
					Facing = facingDot(defender, attacker) >= FACING_DOT,
					Region = hit.Region :: any,
				}, frameEvents)
				for index = before + 1, #frameEvents do
					eventPoints[frameEvents[index]] = hit.Point
				end
				if outcome == "Deflected" then
					awardXp(defender, 15)
				elseif outcome == "Hit" or outcome == "CounterHit" or outcome == "Armored" then
					awardXp(attacker, if outcome == "CounterHit" then 20 else 10)
				elseif outcome == "KO" then
					awardXp(attacker, 100)
				end
			end
		end
	end
end

local function finishDuel(loser: Entity)
	local duelId = loser.Duel
	local active = if duelId then duels[duelId] else nil
	if not active or active.Finished then
		return
	end
	active.Finished = true
	local winner = if loser.Id == active.A then active.B else active.A
	local results = table.clone(active.Xp)
	local complete = active.Complete
	local matchId = active.Id
	task.spawn(function()
		local ok, problem = pcall(complete, matchId, winner, false, 1, results)
		if not ok then
			warn("[CharacterService] Duel completion failed: " .. tostring(problem))
		end
	end)
end

local function handleDefeat(e: Entity, now: number)
	local f = e.Fighter
	if f.State ~= "KO" then
		return
	end
	if e.Kind == "Enemy" then
		if e.DespawnAt == math.huge then
			e.DespawnAt = now + Settings.Respawn.EnemyCorpseTime
			e.Humanoid:MoveTo(e.Root.Position)
		elseif now >= e.DespawnAt then
			removeEntity(e.Id, true)
		end
		return
	end
	if e.Duel then
		finishDuel(e)
		return
	end
	if e.RespawnAt == math.huge then
		e.RespawnAt = now + Settings.Respawn.PlayerDelay
	elseif now >= e.RespawnAt and not e.Respawning then
		local player = e.Player
		if player and player.Parent then
			e.Respawning = true
			requestCharacter(player)
		end
	end
end

local function applyLocomotion(e: Entity)
	local f = e.Fighter
	local speed = Settings.Movement.WalkSpeed * Combat.speedMultiplier(f)
	if math.abs(speed - e.WalkSpeed) > 0.01 then
		e.WalkSpeed = speed
		e.Humanoid.WalkSpeed = speed
	end
	local jump = if speed > 0 and (f.State == "Idle" or f.State == "Blocking") then DEFAULT_JUMP else 0
	if jump ~= e.JumpHeight then
		e.JumpHeight = jump
		e.Humanoid.JumpHeight = jump
	end
end

local function replicate(e: Entity, now: number)
	local packed = Combat.packString(e.Fighter, now, e.Scratch)
	if packed ~= e.Packed then
		e.Packed = packed
		e.Model:SetAttribute(STATE_ATTRIBUTE, packed)
	end
end

local function flushEvents(now: number)
	if #frameEvents == 0 then
		return
	end
	local batch = table.create(#frameEvents)
	for index, event in frameEvents do
		local point = eventPoints[event]
		for _, listener in eventListeners do
			local ok, problem = pcall(listener, event, point)
			if not ok then
				warn("[CharacterService] Event listener failed: " .. tostring(problem))
			end
		end
		batch[index] = {
			k = Combat.EventCodes[event.Kind],
			s = event.Source,
			t = event.Target,
			v = math.floor(event.Value * 100 + 0.5) / 100,
			r = event.Region,
			p = point,
		}
	end
	table.clear(frameEvents)
	table.clear(eventPoints)
	eventRemote:FireAllClients({ v = PROTOCOL_TAG, t = now, e = batch })
end

local function step()
	tickCount += 1
	simTime += TICK
	local drift = serverNow() - simTime
	if math.abs(drift) > 0.25 then
		simTime += drift
	end
	local now = simTime

	local live: { Entity } = {}
	local clock = os.clock()
	for _, e in entities do
		if alive(e) then
			table.insert(live, e)
			Lag.record(e.History, now, e.Root.CFrame, e.Root.AssemblyLinearVelocity)
		elseif e.Kind == "Player" and not e.Respawning and not pendingSpawn[e.Id] and clock >= (retryAt[e.Id] or 0) then
			-- Character vanished outside the combat flow (destroyed, reset): restore one.
			local player = e.Player
			if player and player.Parent then
				e.Respawning = true
				requestCharacter(player)
			end
		end
	end
	table.sort(live, function(a: Entity, b: Entity): boolean
		return a.Id > b.Id
	end)

	for _, listener in stepListeners do
		local ok, problem = pcall(listener, now, TICK)
		if not ok then
			warn("[CharacterService] Step listener failed: " .. tostring(problem))
		end
	end

	for _, e in live do
		if entities[e.Id] == e then
			local f = e.Fighter
			Combat.step(f, now, TICK, frameEvents)
			if f.GuardHeld and f.State == "Idle" then
				Combat.setGuard(f, true, now)
			end
			drainBuffer(e)
		end
	end

	for _, e in live do
		if entities[e.Id] == e and e.Fighter.State == "Active" then
			resolveContacts(e, now)
		end
	end

	local replicateNow = tickCount % SNAPSHOT_INTERVAL == 0
	for _, e in live do
		if entities[e.Id] == e then
			handleDefeat(e, now)
		end
		if entities[e.Id] == e then
			applyDash(e)
			applyLocomotion(e)
			mirrorHealth(e)
			if replicateNow then
				replicate(e, now)
			end
		end
	end

	flushEvents(now)
end

-------------------------------------------------------------------------------------------------
-- Lifecycle
-------------------------------------------------------------------------------------------------

function Service.Start()
	assert(not running, "CharacterService already started")
	running = true
	accumulator = 0
	tickCount = 0
	simTime = serverNow()
	Players.CharacterAutoLoads = false
	rootFolder("Entities")

	table.insert(connections, Players.PlayerAdded:Connect(function(player: Player)
		trackPlayer(player)
		if not Persistence then
			ensurePlayer(player)
		end
	end))
	table.insert(connections, Players.PlayerRemoving:Connect(function(player: Player)
		local id = player.UserId
		removeEntity(id, false)
		pendingSpawn[id] = nil
		retryAt[id] = nil
		local list = playerConnections[id]
		if list then
			disconnectAll(list)
			playerConnections[id] = nil
		end
	end))
	for _, player in Players:GetPlayers() do
		trackPlayer(player)
		if profileReady(player) then
			ensurePlayer(player)
		end
	end

	for _, instance in CollectionService:GetTagged(ENEMY_TAG) do
		registerTagged(instance)
	end
	table.insert(connections, CollectionService:GetInstanceAddedSignal(ENEMY_TAG):Connect(registerTagged))
	table.insert(connections, actionRemote.OnServerEvent:Connect(onIntent))
	table.insert(connections, RunService.Heartbeat:Connect(function(dt: number)
		accumulator += math.min(dt, MAX_FRAME_DELTA)
		local steps = 0
		while accumulator >= TICK and steps < MAX_CATCHUP do
			accumulator -= TICK
			steps += 1
			local started = os.clock()
			step()
			stepTimeIndex = stepTimeIndex % 7200 + 1
			stepTimes[stepTimeIndex] = (os.clock() - started) * 1000
		end
		if accumulator >= TICK then
			droppedSteps += math.floor(accumulator / TICK)
			accumulator %= TICK
		end
	end))
end

function Service.Destroy()
	running = false
	disconnectAll(connections)
	for id, e in entities do
		removeEntity(id, e.Kind == "Enemy")
	end
	for id, list in playerConnections do
		disconnectAll(list)
		playerConnections[id] = nil
	end
	table.clear(frameEvents)
	table.clear(eventPoints)
	table.clear(duels)
end

-------------------------------------------------------------------------------------------------
-- Extension points
-------------------------------------------------------------------------------------------------

function Service.SetHooks(newHooks: Hooks)
	hooks = newHooks
end

function Service.GetHooks(): Hooks
	return hooks
end

function Service.Subscribe(listener: EventListener): () -> ()
	return subscribe(eventListeners, listener)
end

function Service.OnStep(listener: StepListener): () -> ()
	return subscribe(stepListeners, listener)
end

function Service.OnEntityAdded(listener: EntityListener): () -> ()
	return subscribe(addedListeners, listener)
end

function Service.OnEntityRemoved(listener: EntityListener): () -> ()
	return subscribe(removedListeners, listener)
end

function Service.Now(): number
	return simTime
end

function Service.GetEntity(id: number): Entity?
	local e = entities[id]
	if e and alive(e) then
		return e
	end
	return nil
end

function Service.Entities(): { [number]: Entity }
	return entities
end

function Service.IsHostile(a: number, b: number): boolean
	local first, second = entities[a], entities[b]
	return first ~= nil and second ~= nil and hostile(first, second)
end

function Service.IsInDuel(id: number): boolean
	local e = entities[id]
	return e ~= nil and e.Duel ~= nil
end

function Service.GetDuel(id: number): string?
	local e = entities[id]
	return if e then e.Duel else nil
end

-------------------------------------------------------------------------------------------------
-- Control surface for AI and world services
-------------------------------------------------------------------------------------------------

function Service.PushIntent(id: number, action: InputBuffer.BufferedAction, variant: string?, dirX: number?, dirZ: number?): boolean
	local e = entities[id]
	if not e or not alive(e) then
		return false
	end
	return InputBuffer.push(e.Buffer, action, simTime, variant, dirX, dirZ)
end

function Service.SetGuard(id: number, held: boolean): boolean
	local e = entities[id]
	if not e then
		return false
	end
	return (Combat.setGuard(e.Fighter, held, simTime))
end

function Service.SetSprint(id: number, on: boolean): boolean
	local e = entities[id]
	if not e then
		return false
	end
	return Combat.setSprint(e.Fighter, on, simTime)
end

function Service.MoveTo(id: number, position: Vector3)
	local e = entities[id]
	if not e or not alive(e) or e.Kind ~= "Enemy" then
		return
	end
	if (position - e.LastMoveTo).Magnitude > 0.75 then
		e.LastMoveTo = position
		e.Humanoid:MoveTo(position)
	end
end

function Service.StopMoving(id: number)
	local e = entities[id]
	if e and alive(e) and e.Kind == "Enemy" then
		e.LastMoveTo = e.Root.Position
		e.Humanoid:MoveTo(e.Root.Position)
	end
end

function Service.Face(id: number, position: Vector3)
	local e = entities[id]
	if not e or not alive(e) or e.Kind ~= "Enemy" then
		return
	end
	local f = e.Fighter
	if f.State == "Dashing" or f.State == "Active" or Schema.isStunned(f.State) or Schema.isLocked(f.State) then
		return
	end
	local origin = e.Root.Position
	local direction = flatUnit(position - origin)
	if direction.Magnitude > 0 then
		e.Root.CFrame = CFrame.lookAt(origin, origin + direction)
	end
end

function Service.Teleport(id: number, cframe: CFrame)
	local e = entities[id]
	if e and alive(e) then
		e.Model:PivotTo(cframe)
		e.Root.AssemblyLinearVelocity = Vector3.zero
		e.LastMoveTo = Vector3.new(math.huge, 0, 0)
		Lag.clear(e.History)
	end
end

function Service.SetRespawnPoint(id: number, cframe: CFrame)
	local e = entities[id]
	if e then
		e.Shrine = cframe
	end
end

function Service.ApplyStats(id: number, stats: Combat.Stats, refill: boolean?)
	local e = entities[id]
	if e then
		Combat.applyStats(e.Fighter, stats, refill)
		mirrorHealth(e)
	end
end

function Service.ForceWeapon(id: number, weapon: WeaponType)
	local e = entities[id]
	if e then
		Combat.forceWeapon(e.Fighter, weapon)
		attachWeapon(e)
		e.Style = weapon
	end
end

function Service.Tint(id: number, rgb: { number })
	local e = entities[id]
	if e and alive(e) then
		tint(e.Model, rgb)
	end
end

-- Full restore outside the shrine flow (leash reset, encounter reset).
function Service.RestoreFighter(id: number)
	local e = entities[id]
	if not e or e.Fighter.State == "KO" then
		return
	end
	Combat.restore(e.Fighter, simTime, true)
	e.Fighter.State = "Idle"
	e.Fighter.StateStart = simTime
	e.Fighter.StateEnd = math.huge
	InputBuffer.clear(e.Buffer)
end

function Service.Rest(id: number): (boolean, string)
	local e = entities[id]
	if not e or not alive(e) then
		return false, "Unavailable"
	end
	return Combat.tryRest(e.Fighter, simTime, true, frameEvents)
end

function Service.TryHeal(id: number, fraction: number?): (boolean, string)
	local e = entities[id]
	if not e or not alive(e) then
		return false, "Unavailable"
	end
	return Combat.tryHeal(e.Fighter, simTime, fraction)
end

function Service.Cinematic(id: number, duration: number)
	local e = entities[id]
	if e then
		Combat.cinematic(e.Fighter, simTime, duration)
		InputBuffer.clear(e.Buffer)
		if e.Kind == "Enemy" and alive(e) then
			e.Humanoid:MoveTo(e.Root.Position)
		end
	end
end

function Service.ApplyArea(sourceId: number, targetId: number, damage: number, posture: number, unblockable: boolean): string
	local source, target = entities[sourceId], entities[targetId]
	if not source or not target or not alive(target) or not hostile(source, target) then
		return "Ignored"
	end
	local before = #frameEvents
	local outcome = Combat.applyArea(source.Fighter, target.Fighter, simTime, damage, posture, unblockable, facingDot(target, source) >= FACING_DOT, frameEvents)
	for index = before + 1, #frameEvents do
		eventPoints[frameEvents[index]] = target.Root.Position
	end
	return outcome
end

-- Broadcast a presentation cue (telegraph, boss phase, fog gate) on the shared event stream.
function Service.Cue(kind: string, sourceId: number, payload: { [string]: any })
	eventRemote:FireAllClients({ v = PROTOCOL_TAG, t = simTime, cue = kind, s = sourceId, d = payload })
end

function Service.SpawnEnemy(spec: EnemySpec): number?
	assert(Weapons.Weapons[spec.Weapon] ~= nil, "Unknown enemy weapon")
	return spawnEnemy(spec, nil)
end

function Service.DespawnEnemy(id: number)
	local e = entities[id]
	if e and e.Kind == "Enemy" then
		removeEntity(id, true)
	end
end

function Service.EquipWeapon(id: number, weapon: WeaponType): (boolean, string)
	local e = entities[id]
	if not e then
		return false, "Entity not found"
	end
	local ok, reason = Combat.tryEquip(e.Fighter, weapon, simTime)
	if ok then
		attachWeapon(e)
	end
	return ok, reason
end

function Service.GetFighter(id: number): Fighter?
	local e = entities[id]
	return if e then e.Fighter else nil
end

function Service.GetActor(id: number): any
	return entities[id]
end

function Service.GetEntityByModel(model: Model): number?
	local e = byModel[model]
	return if e then e.Id else nil
end

-------------------------------------------------------------------------------------------------
-- Account, progression and match API used by Bootstrap and Matchmaking
-------------------------------------------------------------------------------------------------

function Service.RefreshRoster()
	for id, e in entities do
		local player = e.Player
		if e.Kind == "Player" and player and not profileReady(player) then
			removeEntity(id, false)
			if player.Character then
				player.Character:Destroy()
			end
		end
	end
	for _, player in Players:GetPlayers() do
		if profileReady(player) then
			ensurePlayer(player)
		end
	end
end

function Service.RefreshProgression(id: number)
	local e = entities[id]
	if not e or not Persistence then
		return
	end
	loadProfile(e)
	e.Model:SetAttribute("AsuraStyle", e.Style)
	local statsHook = hooks.Stats
	if statsHook and e.Kind == "Player" then
		local ok, stats = pcall(statsHook, id)
		if ok and stats then
			Combat.applyStats(e.Fighter, stats, false)
		end
	end
end

function Service.UpdateCosmetics(userId: number, trunks: string?, gloves: string?, cosmetics: any?)
	local e = entities[userId]
	if not e then
		return
	end
	if cosmetics then
		e.Cosmetics = cosmetics
	end
	if trunks then
		e.Model:SetAttribute("Trunks", trunks)
	end
	if gloves then
		e.Model:SetAttribute("Gloves", gloves)
	end
end

function Service.CanSetStyle(id: number): boolean
	local e = entities[id]
	return e == nil or (e.Duel == nil and (e.Fighter.State == "Idle" or e.Fighter.State == "RestingAtShrine"))
end

-- Profile style is kept as an identity tag; combat moves come from the equipped weapon.
function Service.SetPlayerStyle(userId: number, styleName: string): (boolean, string?)
	local e = entities[userId]
	if not e then
		return false, "Player entity not found"
	end
	local profile = if Persistence then Persistence.Get(userId) else nil
	if Persistence and (not profile or not profile.styles or not profile.styles[styleName] or not profile.styles[styleName].unlocked) then
		return false, "Style is locked"
	end
	e.Style = styleName
	e.Model:SetAttribute("AsuraStyle", styleName)
	return true, nil
end

function Service.GetPerformance()
	local times = table.clone(stepTimes)
	table.sort(times)
	local count = 0
	for _ in entities do
		count += 1
	end
	return {
		samples = #times,
		p95StepMs = times[math.max(1, math.ceil(#times * 0.95))] or 0,
		maxStepMs = times[#times] or 0,
		droppedSteps = droppedSteps,
		entities = count,
	}
end

function Service.GetMatchXp(id: string?): { [number]: number }
	local active = if id then duels[id] else nil
	return if active then table.clone(active.Xp) else {}
end

function Service.GetRound(): number
	return 1
end

-- Seals two players into a duel. `spawns` places them (slot 1, slot 2); duels run concurrently.
function Service.StartAllocatedMatch(id: string, p1: number, p2: number, mode: string, complete: any, spawns: { CFrame }?): boolean
	if duels[id] or p1 == p2 then
		return false
	end
	local a, b = entities[p1], entities[p2]
	if not a or not b or a.Kind ~= "Player" or b.Kind ~= "Player" or a.Duel ~= nil or b.Duel ~= nil then
		return false
	end
	if not alive(a) or not alive(b) or a.Respawning or b.Respawning then
		return false
	end
	if Persistence and (not Persistence.Get(p1) or not Persistence.Get(p2)) then
		return false
	end
	duels[id] = { Id = id, Mode = mode, A = p1, B = p2, Complete = complete, Finished = false, Spawns = spawns, Xp = {} }
	for _, e in { a, b } do
		e.Duel = id
		e.SpawnOverride = nil
		Combat.restore(e.Fighter, simTime, true)
		e.Fighter.State = "Idle"
		e.Fighter.StateStart = simTime
		e.Fighter.StateEnd = math.huge
		InputBuffer.clear(e.Buffer)
		Lag.clear(e.History)
		e.RespawnAt = math.huge
		e.Model:SetAttribute("AsuraDuel", id)
		e.Model:PivotTo(spawnCFrameFor(e))
		e.Root.AssemblyLinearVelocity = Vector3.zero
	end
	return true
end

-- Releases a duel. Standing fighters are restored and moved to `returns[userId]`; fallen ones
-- respawn there (or at their respawn point when no destination is given).
function Service.EndAllocatedMatch(id: string, returns: { [number]: CFrame }?)
	local active = duels[id]
	if not active then
		return
	end
	duels[id] = nil
	for _, userId in { active.A, active.B } do
		local e = entities[userId]
		if e and e.Duel == id then
			e.Duel = nil
			e.Model:SetAttribute("AsuraDuel", nil)
			local destination = if returns then returns[userId] else nil
			local player = e.Player
			if destination and alive(e) and e.Fighter.State ~= "KO" then
				Combat.restore(e.Fighter, simTime, true)
				e.Fighter.State = "Idle"
				e.Fighter.StateStart = simTime
				e.Fighter.StateEnd = math.huge
				InputBuffer.clear(e.Buffer)
				e.RespawnAt = math.huge
				e.Model:PivotTo(destination)
				e.Root.AssemblyLinearVelocity = Vector3.zero
				e.LastMoveTo = Vector3.new(math.huge, 0, 0)
				Lag.clear(e.History)
			elseif player and player.Parent then
				e.SpawnOverride = destination
				e.Respawning = true
				requestCharacter(player)
			end
		end
	end
end

return Service
