--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/SanctuaryService
-- The Shrine of the Ascendant: a wuxia sanctuary above the clouds, rebuilt on the lobby kit
-- (assets/models/AsuraLobbyKit.rbxmx, tools/blender/lobby_kit.py; concept 2026-10-21). Builds every
-- piece under Workspace.Sanctuary from the WorldDefinitions layout through small builders:
--   * SanctuaryCourtyard: paved courtyard, reflecting basins, bonfire dais and its altar anchor.
--   * SanctuaryCloisters: halls flanking the stairs, side galleries, covered walks to forge and court.
--   * SanctuaryAscent: the Ascension stairs, landing and gate hall whose portal carries the player
--     to the Monastery Gate (the touch trigger it returns).
--   * SanctuaryForge: the Blacksmith Loggia hall around Master Smith Gao (gameplay stays here).
--   * SanctuaryDuelCourt: the Colosseum Promenade; ColosseumService raises the ring on its anchor.
--   * SanctuaryColossus/Terrace: the Veiled Ascetic's terrace; SanctuaryApproach: optional routes.
--   * SanctuaryHorizon: rock foundations, the sea of clouds and the karst horizon.
-- Start() must run before WorldService.Start(): the region's MapFolder (this folder) suppresses
-- the greybox, and the bonfire's AltarAnchor part receives the altar's rest prompt.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("AsurasPath")
local World = require(Shared.Shared.WorldDefinitions)
local InputMap = require(Shared.Shared.InputMap)
local Animations = require(Shared.Shared.AnimationCatalog)
local Characters = require(script.Parent:WaitForChild("CharacterService") :: ModuleScript)
local Recovery = require(script.Parent:WaitForChild("RecoveryRules") :: ModuleScript)
local WorldService = require(script.Parent:WaitForChild("WorldService") :: ModuleScript)
local Colossus = require(script.Parent:WaitForChild("SanctuaryColossus") :: ModuleScript)
local Approach = require(script.Parent:WaitForChild("SanctuaryApproach") :: ModuleScript)
local Bonfire = require(script.Parent:WaitForChild("SanctuaryBonfire") :: ModuleScript)
local Figures = require(script.Parent:WaitForChild("CastFigures") :: ModuleScript)
local Kit = require(script.Parent:WaitForChild("SanctuaryKit") :: ModuleScript)
local Courtyard = require(script.Parent:WaitForChild("SanctuaryCourtyard") :: ModuleScript)
local Cloisters = require(script.Parent:WaitForChild("SanctuaryCloisters") :: ModuleScript)
local Ascent = require(script.Parent:WaitForChild("SanctuaryAscent") :: ModuleScript)
local Forge = require(script.Parent:WaitForChild("SanctuaryForge") :: ModuleScript)
local DuelCourt = require(script.Parent:WaitForChild("SanctuaryDuelCourt") :: ModuleScript)
local Horizon = require(script.Parent:WaitForChild("SanctuaryHorizon") :: ModuleScript)
local Ecology = require(script.Parent:WaitForChild("SanctuaryEcology") :: ModuleScript)

local SanctuaryService = {}

-------------------------------------------------------------------------------------------------
-- Layout
-------------------------------------------------------------------------------------------------

local LAYOUT = World.Sanctuary
local ORIGIN = Vector3.new(LAYOUT.Origin.X, LAYOUT.Origin.Y, LAYOUT.Origin.Z)
local R = LAYOUT.PlazaRadius
local LOGGIA = Vector3.new(LAYOUT.Loggia.X, LAYOUT.Loggia.Y, LAYOUT.Loggia.Z)
local PROMENADE = Vector3.new(LAYOUT.Promenade.X, LAYOUT.Promenade.Y, LAYOUT.Promenade.Z)
local BALCONY_APOTHEM = 32
local STAIR_START = R - 1
local LANDING_DEPTH = 22
local ARCH_OFFSET = 15 -- arch depth into the landing

local BONFIRE_ALTAR = World.startingAltar()
local DESTINATION = World.Altars[LAYOUT.PortalDestination]

local PORTAL_FADE = 0.5
local PORTAL_COOLDOWN = 4
local CATCH_DEPTH = 40
local CATCH_RADIUS = 1300
local CATCH_LIMITS = { Radius = CATCH_RADIUS, FloorY = ORIGIN.Y - CATCH_DEPTH }
local POLL_INTERVAL = 0.5
local SMITH_RADIUS = 10
local REFILL_RADIUS = 6

local Assets = require(Shared.Shared.PresentationAssets)
local TEXTURE_SPARKS = Assets.Textures.Ember
local STONE = Color3.fromRGB(95, 101, 96)
local DESCENT = Vector3.new(0, 0, 88) -- the Well of Descent pavilion (SanctuaryRoutes), plaza-local

-------------------------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------------------------

local root: Folder? = nil
local spawnCFrame = CFrame.new()
local smithPosition = Vector3.zero
local connections: { RBXScriptConnection } = {}
local disconnectors: { () -> () } = {}
local transit: { [number]: number } = {}
local fallState: { [number]: Recovery.FallState } = {}
local running = false
local accumulator = 0

-------------------------------------------------------------------------------------------------
-- Construction helpers
-------------------------------------------------------------------------------------------------

type PartOptions = {
	Collide: boolean?,
	Query: boolean?,
	Transparency: number?,
	Reflectance: number?,
	Shadow: boolean?,
	Shape: Enum.PartType?,
	Class: string?,
}

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, options: PartOptions?): BasePart
	local o: PartOptions = options or {}
	local p = Instance.new((o.Class or "Part") :: any) :: BasePart
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false
	p.CanCollide = if o.Collide == nil then true else o.Collide
	p.CanQuery = if o.Query == nil then p.CanCollide else o.Query
	p.Transparency = o.Transparency or 0
	p.Reflectance = o.Reflectance or 0
	p.CastShadow = if o.Shadow == nil then true else o.Shadow
	if o.Shape and p:IsA("Part") then
		p.Shape = o.Shape
	end
	p.Parent = parent
	return p
end

local function sequence(points: { { number } }): NumberSequence
	local keys = {}
	for _, point in points do
		table.insert(keys, NumberSequenceKeypoint.new(point[1], point[2]))
	end
	return NumberSequence.new(keys)
end

local function colors(a: Color3, b: Color3): ColorSequence
	return ColorSequence.new(a, b)
end

local function embers(parent: BasePart, rate: number, spread: number, lift: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "Embers"
	e.Texture = TEXTURE_SPARKS;e.Enabled=e.Texture~=""
	e.Rate = rate
	e.Lifetime = NumberRange.new(2.5, 4.5)
	e.Speed = NumberRange.new(3, 7)
	e.SpreadAngle = Vector2.new(spread, spread)
	e.Acceleration = Vector3.new(0.6, lift, 0.4)
	e.Drag = 0.6
	e.Size = sequence({ { 0, 0.22 }, { 1, 0.05 } })
	e.Transparency = sequence({ { 0, 0 }, { 0.8, 0.3 }, { 1, 1 } })
	e.Color = colors(Color3.fromRGB(255, 200, 110), Color3.fromRGB(255, 80, 30))
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Parent = parent
	return e
end

-------------------------------------------------------------------------------------------------
-- Blacksmith Loggia: the hall is SanctuaryForge's; the smith, his prompts and the trough are here.
-------------------------------------------------------------------------------------------------

local function buildSmithFigure(parent: Instance, base: CFrame)
	-- Stone-coloured stand-in used only if the avatar rig cannot be created.
	local model = Instance.new("Model")
	model.Name = "MasterSmithGao"
	model:SetAttribute("AsuraNPC", "Gao") -- DialogueController frames his portrait by this tag
	CollectionService:AddTag(model, "AsuraNPC")
	part(model, "Legs", Vector3.new(2, 2.4, 1), base * CFrame.new(0, 1.2, 0), Color3.fromRGB(40, 34, 30), Enum.Material.Fabric)
	part(model, "Torso", Vector3.new(2.2, 2.4, 1.2), base * CFrame.new(0, 3.6, 0), Color3.fromRGB(70, 48, 36), Enum.Material.Leather)
	part(model, "Head", Vector3.new(1.3, 1.3, 1.3), base * CFrame.new(0, 5.5, 0), Color3.fromRGB(176, 128, 96), Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Ball })
	model.Parent = parent
end

local function spawnSmith(parent: Instance, base: CFrame)
	task.spawn(function()
		local description = Instance.new("HumanoidDescription")
		local skin = Color3.fromRGB(176, 128, 96)
		description.HeadColor = skin
		description.LeftArmColor = skin
		description.RightArmColor = skin
		description.TorsoColor = Color3.fromRGB(70, 48, 36)
		description.LeftLegColor = Color3.fromRGB(40, 34, 30)
		description.RightLegColor = Color3.fromRGB(40, 34, 30)
		local ok, model = pcall(function()
			return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
		end)
		if not running or not parent.Parent then
			if ok and model then
				model:Destroy()
			end
			return
		end
		if not ok or not model then
			warn("[Sanctuary] Blacksmith rig unavailable, using the stone figure: " .. tostring(model))
			buildSmithFigure(parent, base)
			return
		end
		model.Name = "MasterSmithGao"
		model:SetAttribute("AsuraNPC", "Gao") -- DialogueController frames his portrait by this tag
		CollectionService:AddTag(model, "AsuraNPC")
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local rootPart = model:FindFirstChild("HumanoidRootPart")
		if humanoid then
			humanoid.DisplayName = "Master Smith Gao"
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
			humanoid.NameDisplayDistance = 40
			humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		end
		if rootPart and rootPart:IsA("BasePart") then
			rootPart.Anchored = true
		end
		local animate = model:FindFirstChild("Animate")
		if animate then
			animate:Destroy()
		end
		model:PivotTo(base * CFrame.new(0, 3, 0))
		model.Parent = parent
		-- Blindfold, topknot, apron and bracers bind to the live rig itself (LooksCast.Gao).
		local missing = Figures.dress(model, "Gao")
		if #missing > 0 then warn("[Sanctuary] Gao attire unbound: " .. table.concat(missing, ", ")) end
		-- Idle from the catalog keeps the smith out of a bind pose until a custom idle is set.
		if humanoid then
			local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
			animator.Parent = humanoid
			local idle = Animations.weapon("Unarmed", "Idle")
			local animation = Instance.new("Animation")
			animation.AnimationId = Animations.resolve(idle, "R15")
			local loaded, track = pcall(function()
				return (animator :: Animator):LoadAnimation(animation)
			end)
			if loaded and track then
				track.Looped = true
				track.Priority = Enum.AnimationPriority.Idle
				track:Play(0.2, 1, Animations.speed(idle))
			end
		end
	end)
end

local function buildLoggia(parent: Folder): (ProximityPrompt, ProximityPrompt)
	local base = CFrame.new(LOGGIA)
	local loggia = Forge.Build(parent, base, function(mouth: BasePart)
		embers(mouth, 16, 25, 6).EmissionDirection = Enum.NormalId.Right
	end)

	-- The smith stands beside the anvil facing the plaza; prompts live on a fixed anchor so they
	-- work immediately, even while (or if) the avatar rig is still loading.
	local stand = base * CFrame.new(-2, 0, -1)
	local facing = CFrame.lookAt(stand.Position, stand.Position + Vector3.xAxis)
	smithPosition = stand.Position
	spawnSmith(loggia, facing)
	local promptAnchor = part(loggia, "SmithPrompts", Vector3.new(2, 5, 2), facing * CFrame.new(0, 2.5, 0), STONE, Enum.Material.SmoothPlastic,
		{ Collide = false, Query = false, Transparency = 1, Shadow = false })
	local reinforce = Instance.new("ProximityPrompt")
	reinforce.Name = "ReinforcePrompt"
	reinforce.ActionText = "Speak to Master Smith Gao"
	reinforce.ObjectText = "Master Smith Gao"
	InputMap.applyPrompt(reinforce)
	reinforce.HoldDuration = 0.6
	reinforce.MaxActivationDistance = SMITH_RADIUS
	reinforce.RequiresLineOfSight = false
	reinforce.Parent = promptAnchor
	local refill = Instance.new("ProximityPrompt")
	refill.Name = "RefillPrompt"
	refill.ActionText = "Refill Elixir Gourd"
	refill.ObjectText = "Master Smith Gao"
	-- Every prompt shares the Interact key (C was Slide, Start was Heal). The refill sits at the
	-- quench trough by the rack so nearest-prompt ownership decides between it and the smith.
	InputMap.applyPrompt(refill)
	refill.HoldDuration = 0.3
	refill.MaxActivationDistance = REFILL_RADIUS
	refill.RequiresLineOfSight = false
	local trough = Kit.slab(loggia, "QuenchTrough", Vector3.new(2.4, 1.6, 4), base * CFrame.new(-9, 0.8, -8), "StoneDark")
	refill.Parent = trough
	return reinforce, refill
end

local function buildHeroStatueDais(parent: Folder)
	-- The colossus closes the main axis behind the Ascension gate (SanctuaryColossus), so the
	-- plaza's north side stays clear for the stairs and the view up them ends on her.
	Colossus.Build(parent, ORIGIN, LAYOUT.StairSteps * LAYOUT.StairRise, STAIR_START + LAYOUT.StairSteps * LAYOUT.StairRun + LANDING_DEPTH)
end

-------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------
-- Behaviour
-------------------------------------------------------------------------------------------------

local function toCFrame(p: World.Placement): CFrame
	return CFrame.new(p.X, p.Y, p.Z) * CFrame.Angles(0, math.rad(p.Yaw), 0)
end

-- Portal arrival (batch 07, #30) faces the destination altar a few strides ahead, so the first
-- checkpoint is in view rather than behind the player; respawns keep the altar's own facing.
local function arrivalCFrame(altar: World.Altar): CFrame
	local at = Vector3.new(altar.Spawn.X, altar.Spawn.Y, altar.Spawn.Z)
	return CFrame.lookAt(at, Vector3.new(altar.Placement.X, at.Y, altar.Placement.Z))
end

local function result(player: Player, ok: boolean, reason: string)
	player:SetAttribute("AsuraResult", (if ok then "" else "!") .. reason)
end

local function onPortal(hit: BasePart)
	local model = hit:FindFirstAncestorOfClass("Model")
	local player = if model then Players:GetPlayerFromCharacter(model) else nil
	if not player then
		return
	end
	local userId = player.UserId
	local clock = os.clock()
	if (transit[userId] or 0) > clock then
		return
	end
	local e = Characters.GetEntity(userId)
	if not e or e.Model ~= model or e.Fighter.State == "KO" or e.Respawning or Characters.IsInDuel(userId) then
		return
	end
	transit[userId] = clock + PORTAL_COOLDOWN
	Characters.Cinematic(userId, PORTAL_FADE * 2)
	Characters.Cue("PortalTransit", userId, { to = DESTINATION.Id, name = DESTINATION.Name, fade = PORTAL_FADE })
	task.delay(PORTAL_FADE, function()
		local current = Characters.GetEntity(userId)
		if running and current and current.Fighter.State ~= "KO" and not Characters.IsInDuel(userId) then
			Characters.Teleport(userId, arrivalCFrame(DESTINATION))
		end
	end)
end

local function poll()
	for _, player in Players:GetPlayers() do
		local userId = player.UserId
		local e = Characters.GetEntity(userId)
		if e and e.Fighter.State ~= "KO" and not e.Respawning and not Characters.IsInDuel(userId) then
			local position = e.Root.Position
			local flat = Vector3.new(position.X - ORIGIN.X, 0, position.Z - ORIGIN.Z)
			-- Only a body that fell from the Sanctuary is caught; ground regions, the space between
			-- them and respawn placement at a later altar are destinations, not falls from the clouds.
			local region = World.regionAt(position.X, position.Y, position.Z)
			local state = fallState[userId]
			if not state then
				state = { Aloft = false }
				fallState[userId] = state
			end
			if Recovery.sanctuaryFall(state, region, flat.Magnitude, position.Y, Characters.IsSettling(userId), CATCH_LIMITS) then
				-- The clouds return those who fall back to the bonfire.
				Characters.Teleport(userId, spawnCFrame)
				Characters.Cue("SanctuaryCatch", userId, {})
			end
		end
	end
end

-------------------------------------------------------------------------------------------------
-- Lifecycle
-------------------------------------------------------------------------------------------------

function SanctuaryService.Start()
	assert(not running, "SanctuaryService already started")
	assert(BONFIRE_ALTAR.Region == "Sanctuary", "The starting altar must stand in the Sanctuary")
	assert(DESTINATION ~= nil, "Sanctuary portal destination missing")
	running = true
	local existing = Workspace:FindFirstChild(World.Regions.Sanctuary.MapFolder)
	if existing then
		existing:Destroy()
	end
	local sanctuary = Instance.new("Folder")
	sanctuary.Name = World.Regions.Sanctuary.MapFolder
	root = sanctuary
	spawnCFrame = toCFrame(BONFIRE_ALTAR.Spawn)

	local origin = CFrame.new(ORIGIN)
	Courtyard.Build(sanctuary, origin, BONFIRE_ALTAR.Id, LAYOUT.PlinthHeight)
	Cloisters.Build(sanctuary, origin, ORIGIN.X - LOGGIA.X - 18, PROMENADE.X - ORIGIN.X - BALCONY_APOTHEM)
	local trigger = Ascent.Build(sanctuary, origin, { Steps = LAYOUT.StairSteps, Rise = LAYOUT.StairRise, Run = LAYOUT.StairRun,
		Width = LAYOUT.StairWidth, Start = STAIR_START, Landing = LANDING_DEPTH, Gate = ARCH_OFFSET })
	local reinforce, refill = buildLoggia(sanctuary)
	DuelCourt.Build(sanctuary, CFrame.new(PROMENADE), BALCONY_APOTHEM)
	buildHeroStatueDais(sanctuary)
	-- Batch 16: pilgrim walk and Well of Descent, cache routes, reveal points, terrace parapet.
	local okRoutes, routeProblem = pcall(Approach.Build, sanctuary)
	if not okRoutes then
		warn("[Sanctuary] Pilgrim routes skipped: " .. tostring(routeProblem))
	end
	Horizon.Foundations(sanctuary, origin, LOGGIA - ORIGIN, PROMENADE - ORIGIN, DESCENT)
	Horizon.Build(sanctuary, origin)
	Ecology.Build(sanctuary, origin)
	sanctuary.Parent = Workspace

	-- Default checkpoint for anyone without a resolved respawn yet (WorldService's altar hook
	-- supersedes it once a Souls session exists).
	table.insert(disconnectors, Characters.OnEntityAdded(function(id: number, kind: Characters.EntityKind)
		if kind == "Player" then
			Characters.SetRespawnPoint(id, spawnCFrame)
		end
	end))
	table.insert(connections, trigger.Touched:Connect(onPortal))
	table.insert(connections, reinforce.Triggered:Connect(function(player: Player)
		local Dialogue=require(script.Parent.DialogueService)
        Dialogue.Open(player,"Gao")
	end))
	table.insert(connections, refill.Triggered:Connect(function(player: Player)
		local ok, reason = WorldService.RefillElixirs(player.UserId)
		result(player, ok, reason)
	end))
	-- The Interact key beside the smith is the reinforce prompt's own key; acknowledge it quietly.
	table.insert(disconnectors, WorldService.RegisterInteractable(function(_userId: number, position: Vector3): (boolean?, string?)
		if (position - smithPosition).Magnitude <= SMITH_RADIUS + 1 then
			return true, "Smith"
		end
		return nil, nil
	end))
	table.insert(connections, Players.PlayerRemoving:Connect(function(player: Player)
		transit[player.UserId] = nil
		fallState[player.UserId] = nil
	end))
	table.insert(connections, RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator >= POLL_INTERVAL then
			accumulator = 0
			local ok, problem = pcall(poll)
			if not ok then
				warn("[Sanctuary] Poll failed: " .. tostring(problem))
			end
		end
	end))
end

function SanctuaryService.SpawnCFrame(): CFrame
	return spawnCFrame
end

function SanctuaryService.Contains(position: Vector3): boolean
	return World.regionAt(position.X, position.Y, position.Z) == "Sanctuary"
end

function SanctuaryService.Destroy()
	running = false
	for _, disconnect in disconnectors do
		disconnect()
	end
	table.clear(disconnectors)
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	table.clear(transit)
	table.clear(fallState)
	local folderRoot = root
	if folderRoot then
		folderRoot:Destroy()
		root = nil
	end
end

return SanctuaryService
