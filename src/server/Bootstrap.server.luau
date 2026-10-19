--!strict
-- Script: ServerScriptService/AsurasPath/Bootstrap
-- Asura's Path master server entry. Brings services up in dependency order:
--   Environment -> LagCompensation -> ProfileStore (Persistence) -> CharacterService -> AIService
--   -> SanctuaryService -> MonasteryService -> WorldService -> ColosseumService
-- SanctuaryService and MonasteryService precede WorldService: their map folders suppress greybox
-- and their altar anchors receive the rest prompts.
-- then owns the player lifecycle: leased profile hydration, durable ranked-result recovery,
-- character admission, death/respawn telemetry and an ordered, deadline-bounded shutdown save.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("AsurasPath")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript) :: any
local Validator = require(Shared.Shared.ConfigValidator) :: any
local Protocol = require(Shared.Shared.IntentProtocol)
local ShopCatalog = require(Shared.ShopCatalog) :: any
local Services = script.Parent:WaitForChild("Services")

local READY_ATTRIBUTE: string = Config.Names.ReadyAttribute
Workspace:SetAttribute(READY_ATTRIBUTE, false)
Workspace:SetAttribute("AsuraReady", false)

-- Dependency order. Each require is a hard dependency of the next layer.
local Environment = require(Services:WaitForChild("EnvironmentService") :: ModuleScript)
local Lag = require(Services:WaitForChild("LagCompensation") :: ModuleScript)
local ProfileStore = require(Services:WaitForChild("ProfileStore") :: ModuleScript)
local Persistence = require(Services:WaitForChild("PersistenceService") :: ModuleScript) :: any
local Characters = require(Services:WaitForChild("CharacterService") :: ModuleScript)
local AI = require(Services:WaitForChild("AIService") :: ModuleScript)
local Sanctuary = require(Services:WaitForChild("SanctuaryService") :: ModuleScript)
local Monastery = require(Services:WaitForChild("MonasteryService") :: ModuleScript)
local WorldService = require(Services:WaitForChild("WorldService") :: ModuleScript)
local Colosseum = require(Services:WaitForChild("ColosseumService") :: ModuleScript)
local Shop = require(Services:WaitForChild("ShopService") :: ModuleScript) :: any

local Magic = require(Services:WaitForChild("MagicService") :: ModuleScript)
local Loot = require(Services:WaitForChild("LootService") :: ModuleScript)
local Dialogue = require(Services:WaitForChild("DialogueService") :: ModuleScript)
local Wagering = require(Services:WaitForChild("WagerService") :: ModuleScript)
local WeaponEffects = require(Services:WaitForChild("WeaponEffects") :: ModuleScript)

type Bucket = Protocol.Bucket

local SHUTDOWN_BUDGET = 25
local FLUSH_BUDGET = 8
local LOAD_RETRY_DELAY = 2

local connections: { RBXScriptConnection } = {}
local disconnectors: { () -> () } = {}
local shopBudgets: { [number]: Bucket } = {}
local shopBusy: { [number]: boolean } = {}
local loading: { [number]: boolean } = {}
local started: { [string]: boolean } = {}
local shuttingDown = false

local net = Shared:WaitForChild("Net")
local shopRemote = net:WaitForChild("ShopIntent") :: RemoteEvent

local MarketplaceService: any = nil
pcall(function()
	MarketplaceService = game:GetService("MarketplaceService")
	MarketplaceService.ProcessReceipt = Shop.ProcessReceipt
end)

local function trace(problem: any): string
	return debug.traceback(tostring(problem), 2)
end

local function teardown()
 if started.Narrative then pcall(Dialogue.Destroy);pcall(Wagering.Destroy) end
	for _, disconnect in disconnectors do
		pcall(disconnect)
	end
	table.clear(disconnectors)
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	if started.Arsenal then
		pcall(WeaponEffects.Destroy); pcall(Loot.Destroy); pcall(Magic.Destroy)
	end
	if started.Colosseum then
		pcall(Colosseum.Destroy)
	end
	if started.World then
		pcall(WorldService.Destroy)
	end
	if started.Monastery then
		pcall(Monastery.Destroy)
	end
	if started.Sanctuary then
		pcall(Sanctuary.Destroy)
	end
	if started.AI then
		pcall(AI.Destroy)
	end
	if started.Characters then
		pcall(Characters.Destroy)
	end
	table.clear(started)
end

local function syncProfile(player: Player)
	if player.Parent and player:GetAttribute("AsuraClientReady") == true then
		shopRemote:FireClient(player, { action = "ProfileSync", profile = Persistence.PublicProfile(player.UserId) })
		Loot.Sync(player)
	end
end

-------------------------------------------------------------------------------------------------
-- Player lifecycle
-------------------------------------------------------------------------------------------------

-- Hydrates the leased profile (Souls section included), settles ranked results that finished
-- while the player was away, then admits their character to the world.
local function hydrate(player: Player)
	local userId = player.UserId
	if loading[userId] or shuttingDown then
		return
	end
	loading[userId] = true
	local loaded, problem = pcall(Persistence.Load, userId)
	if not loaded then
		loading[userId] = nil
		warn("[Asura] Profile load refused for " .. userId .. ": " .. tostring(problem))
		if player.Parent then
			player:Kick("Your warrior's record could not be safely loaded. Please rejoin shortly.")
		end
		return
	end
	if not player.Parent then
		loading[userId] = nil
		Persistence.Unload(userId)
		return
	end
	local profile = Persistence.Get(userId)
	if not profile or type(profile.souls) ~= "table" then
		loading[userId] = nil
		warn("[Asura] Profile for " .. userId .. " has no Souls record")
		Persistence.Unload(userId)
		player:Kick("Your warrior's record is incomplete. Please rejoin.")
		return
	end
	-- Ranked inbox: a result committed elsewhere is applied exactly once before play resumes.
	local recovered = false
	for _ = 1, 3 do
		recovered = Colosseum.Recover(userId)
		if recovered or not player.Parent then
			break
		end
		task.wait(LOAD_RETRY_DELAY)
	end
	if not recovered then
		warn("[Asura] Ranked recovery deferred for " .. userId .. "; it retries at the next queue entry")
	end
	loading[userId] = nil
	if not player.Parent then
		return
	end
	Characters.RefreshRoster()
	syncProfile(player)
end

local function release(player: Player)
	local userId = player.UserId
	Colosseum.Disconnect(userId)
	WorldService.Flush(userId, FLUSH_BUDGET)
	local ok, problem = Persistence.Unload(userId)
	if not ok and problem then
		warn("[Asura] Release for " .. userId .. ": " .. tostring(problem))
	end
	shopBudgets[userId] = nil
	shopBusy[userId] = nil
	loading[userId] = nil
end

-- Death and respawn: penalties live in WorldService and timing in CharacterService; the
-- bootstrap publishes the lifecycle so clients and analytics see one consistent record.
local function onCombatEvent(event: any, _point: Vector3?)
	if event.Kind ~= "KO" then
		return
	end
	local player = Players:GetPlayerByUserId(event.Target)
	if not player then
		return
	end
	player:SetAttribute("AsuraDowned", true)
	if not Characters.IsInDuel(event.Target) then
		player:SetAttribute("AsuraDeaths", (tonumber(player:GetAttribute("AsuraDeaths")) or 0) + 1)
	end
end

local function onEntityAdded(id: number, kind: Characters.EntityKind)
	if kind ~= "Player" then
		return
	end
	local player = Players:GetPlayerByUserId(id)
	if player then
		player:SetAttribute("AsuraDowned", false)
	end
end

local function watchCharacters(player: Player)
	table.insert(connections, player.CharacterAdded:Connect(function()
		player:SetAttribute("AsuraDowned", false)
	end))
end

-------------------------------------------------------------------------------------------------
-- Account remote (settings, cosmetics, style rolls, receipts)
-------------------------------------------------------------------------------------------------

local function onShop(player: Player, payload: any)
	if not Protocol.Shop(payload) then
		return
	end
	local userId = player.UserId
	if payload.action == "GetProfile" then
		player:SetAttribute("AsuraClientReady", true)
	end
	if not Persistence.Get(userId) then
		shopRemote:FireClient(player, { action = "ShopError", err = "Profile unavailable" })
		return
	end
	local clock = os.clock()
	local budget = shopBudgets[userId]
	if not budget then
		budget = { tokens = Config.Network.ShopBurst, time = clock }
		shopBudgets[userId] = budget
	end
	if shopBusy[userId] or not Protocol.Take(budget, clock, 1, Config.Network.ShopPerSecond, Config.Network.ShopBurst) then
		return
	end
	shopBusy[userId] = true
	local handled, problem = xpcall(function(): boolean
		local action: string = payload.action
		if action == "GetProfile" then
			syncProfile(player)
		elseif action == "SaveSettings" then
			local saved, err = Shop.SaveSettings(userId, payload.settings)
			shopRemote:FireClient(player, { action = "SettingsResult", ok = saved, err = err, profile = Persistence.PublicProfile(userId) })
		elseif action == "RollStyle" then
			local ok, err, drop, duplicate = Shop.RollStyle(userId, payload.useToken == true)
			shopRemote:FireClient(player, {
				action = "RollResult",
				ok = ok,
				err = err,
				drop = drop,
				isDuplicate = duplicate,
				profile = Persistence.PublicProfile(userId),
			})
		elseif action == "RollCrate" then
			local ok, err, itemId, duplicate = Shop.RollCrate(userId, payload.crateId)
			shopRemote:FireClient(player, {
				action = "CrateResult",
				ok = ok,
				err = err,
				itemId = itemId,
				isDuplicate = duplicate,
				crateId = payload.crateId,
				profile = Persistence.PublicProfile(userId),
			})
		elseif action == "BuyCosmetic" then
			local ok, err = Shop.BuyCosmetic(userId, payload.itemId)
			shopRemote:FireClient(player, { action = "BuyResult", ok = ok, err = err, profile = Persistence.PublicProfile(userId) })
		elseif action == "EquipCosmetic" then
			local ok, err = Shop.EquipCosmetic(userId, payload.itemId)
			local profile = Persistence.PublicProfile(userId)
			shopRemote:FireClient(player, { action = "EquipResult", ok = ok, err = err, profile = profile })
			if ok and profile and profile.equippedCosmetics then
				Characters.UpdateCosmetics(userId, profile.equippedCosmetics.Trunks, profile.equippedCosmetics.Gloves, profile.equippedCosmetics)
			end
		elseif action == "EquipStyle" then
			local ok, err = false, "Finish your duel and leave the queue before changing style"
			if Colosseum.CanEquip(userId) and Characters.CanSetStyle(userId) then
				ok, err = Shop.EquipStyle(userId, payload.styleName)
				if ok then
					Characters.SetPlayerStyle(userId, payload.styleName)
				end
			end
			shopRemote:FireClient(player, { action = "EquipStyleResult", ok = ok, err = err, profile = Persistence.PublicProfile(userId) })
		elseif action == "BuyBundle" then
			if not Config.Features.PaidPurchases or not Config.Release.PurchasesIntegrationPassed then
				shopRemote:FireClient(player, { action = "BuyBundleResult", ok = false, err = "Purchases are not enabled" })
				return false
			end
			local bundle = ShopCatalog.Bundles[payload.bundleId]
			if bundle and MarketplaceService and not RunService:IsStudio() then
				pcall(function()
					MarketplaceService:PromptProductPurchase(player, bundle.productId)
				end)
			end
		end
		return true
	end, trace)
	shopBusy[userId] = nil
	Characters.RefreshProgression(userId)
	if not handled then
		warn("[Asura] Account operation failed: " .. tostring(problem))
		shopRemote:FireClient(player, { action = "ShopError", err = "Your record is unavailable. Please retry shortly." })
	end
end

-------------------------------------------------------------------------------------------------
-- Shutdown
-------------------------------------------------------------------------------------------------

-- Ordered so nothing is lost: duels settle (ranked journals close), live world state (essence,
-- gourd charges, bloodstains) commits through the serial queues, then every lease is released.
local function shutdown()
	if shuttingDown then
		return
	end
	shuttingDown = true
	Workspace:SetAttribute(READY_ATTRIBUTE, false)
	Workspace:SetAttribute("AsuraReady", false)
	local deadline = os.clock() + SHUTDOWN_BUDGET
	local steps: { { Name: string, Run: () -> () } } = {
		{ Name = "Colosseum", Run = function()
			Colosseum.Close(deadline)
		end },
		{ Name = "Spectator wagers", Run = function()
   Wagering.Close(deadline)
  end },
		{ Name = "World", Run = function()
			WorldService.FlushAll(math.min(FLUSH_BUDGET, math.max(deadline - os.clock(), 1)))
		end },
		{ Name = "Persistence", Run = function()
			Persistence.Close(deadline)
		end },
	}
	for _, item in steps do
		local ok, problem = xpcall(function(): boolean
			item.Run()
			return true
		end, trace)
		if not ok then
			warn("[Asura] Shutdown step " .. item.Name .. " failed: " .. tostring(problem))
		end
	end
end

-------------------------------------------------------------------------------------------------
-- Startup
-------------------------------------------------------------------------------------------------

local ok, problem = xpcall(function(): boolean
	Validator.Validate(Config)
	Environment.Apply()
	assert(type(Lag.MAX_REWIND) == "number" and Lag.MAX_REWIND > 0, "LagCompensation rewind budget missing")
	assert(getmetatable(Persistence.Engine) == ProfileStore, "Persistence must run on the ProfileStore engine")

	Persistence.Start()
	Characters.Start()
	started.Characters = true
	AI.Start()
	started.AI = true
	Sanctuary.Start()
	started.Sanctuary = true
	Monastery.Start()
	started.Monastery = true
	WorldService.Start()
	started.World = true
	started.Arsenal = true
	Magic.Start(); Loot.Start(); WeaponEffects.Start()
	Colosseum.Start()
 Dialogue.Start();Wagering.Start(Colosseum)
 started.Narrative=true
	started.Colosseum = true

	table.insert(disconnectors, Characters.Subscribe(onCombatEvent))
	table.insert(disconnectors, Characters.OnEntityAdded(onEntityAdded))
	table.insert(connections, Players.PlayerAdded:Connect(function(player: Player)
		watchCharacters(player)
		hydrate(player)
	end))
	table.insert(connections, Players.PlayerRemoving:Connect(release))
	table.insert(connections, shopRemote.OnServerEvent:Connect(onShop))
	game:BindToClose(shutdown)
	for _, player in Players:GetPlayers() do
		watchCharacters(player)
		task.spawn(hydrate, player)
	end

	Workspace:SetAttribute(READY_ATTRIBUTE, true)
	Workspace:SetAttribute("AsuraReady", true)
	local rings = Colosseum.GetRings()
	print(string.format(
		"[Asura's Path] Server ready: 60 Hz authority, %.0f ms rewind budget, %d Colosseum rings; ranked league %s.",
		Lag.MAX_REWIND * 1000,
		#rings,
		if not Colosseum.RankedOpen() then "sealed (release gate)"
			elseif RunService:IsStudio() and not (Config.Features.Matchmaking and Config.Release.RankedIntegrationPassed) then "open (development)"
			else "open"
	))
	return true
end, trace)

if not ok then
	Workspace:SetAttribute(READY_ATTRIBUTE, false)
	Workspace:SetAttribute("AsuraReady", false)
	teardown()
	error("[Asura's Path] Server startup failed.\n" .. tostring(problem), 0)
end

script.Destroying:Connect(teardown)
