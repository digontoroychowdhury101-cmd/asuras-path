--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/WorldStateController
-- Client mirror of the authoritative combat world: decodes every fighter's replicated AsuraState
-- record, relays the server event/cue stream to presentation controllers, and executes the local
-- player's server-granted dash displacement (the client owns its character assembly).
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("AsurasPath")
local Combat = require(Shared:WaitForChild("Simulation"):WaitForChild("CombatRules") :: ModuleScript)

export type Snapshot = Combat.Snapshot

export type Entity = {
	Id: number,
	Model: Model,
	Humanoid: Humanoid?,
	Root: BasePart?,
	Kind: string,
	Boss: boolean,
	Name: string,
	Snapshot: Snapshot?,
	Previous: Snapshot?,
	UpdatedAt: number,
	Connections: { RBXScriptConnection },
}

export type CombatEvent = {
	Kind: string,
	Source: number,
	Target: number,
	Value: number,
	Region: string?,
	Point: Vector3?,
	Time: number,
}

export type Cue = { Kind: string, Source: number, Data: { [string]: any }, Time: number }

type EventListener = (event: CombatEvent) -> ()
type CueListener = (cue: Cue) -> ()
type EntityListener = (entity: Entity) -> ()

local Controller = {}
Controller.__index = Controller

type Fields = {
	Player: Player,
	LocalId: number,
	Entities: { [number]: Entity },
	ByModel: { [Model]: Entity },
	EventListeners: { EventListener },
	CueListeners: { CueListener },
	AddedListeners: { EntityListener },
	RemovedListeners: { EntityListener },
	Connections: { RBXScriptConnection },
	Pending: { [Model]: RBXScriptConnection }, -- models waiting for their AsuraId (batch 26: no unbounded list)
	DashSeq: number,
	DashEnds: number,
	DashVelocity: Vector3,
}

export type WorldState = typeof(setmetatable({} :: Fields, Controller))

local PROTOCOL_TAG = "Asura1"
local ENEMY_TAG = "AsuraEnemy"

local function fire<T>(list: { (T) -> () }, value: T)
	for _, listener in table.clone(list) do
		local ok, problem = pcall(listener, value)
		if not ok then
			warn("[WorldState] Listener failed: " .. tostring(problem))
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

function Controller.new(net: Instance): WorldState
	local player = Players.LocalPlayer
	local fields: Fields = {
		Player = player,
		LocalId = player.UserId,
		Entities = {},
		ByModel = {},
		EventListeners = {},
		CueListeners = {},
		AddedListeners = {},
		RemovedListeners = {},
		Connections = {},
		DashSeq = -1,
		DashEnds = 0,
		DashVelocity = Vector3.zero,
		Pending = setmetatable({}, { __mode = "k" }) :: any,
	}
	local self = setmetatable(fields, Controller)

	local remote = net:WaitForChild("StateSnapshots") :: RemoteEvent
	table.insert(self.Connections, remote.OnClientEvent:Connect(function(payload: any)
		self:Receive(payload)
	end))

	local function watchCharacter(other: Player)
		if other.Character then
			self:Track(other.Character)
		end
		table.insert(self.Connections, other.CharacterAdded:Connect(function(model: Model)
			self:Track(model)
		end))
	end
	for _, other in Players:GetPlayers() do
		watchCharacter(other)
	end
	table.insert(self.Connections, Players.PlayerAdded:Connect(watchCharacter))

	local function watchFolder(folder: Instance)
		for _, child in folder:GetChildren() do
			if child:IsA("Model") then
				self:Track(child)
			end
		end
		table.insert(self.Connections, folder.ChildAdded:Connect(function(child: Instance)
			if child:IsA("Model") then
				self:Track(child)
			end
		end))
	end
	task.spawn(function()
		local root = Workspace:WaitForChild("AsurasPath", 30)
		local entities = root and root:WaitForChild("Entities", 30)
		if entities then
			watchFolder(entities)
		end
	end)
	for _, tagged in CollectionService:GetTagged(ENEMY_TAG) do
		if tagged:IsA("Model") then
			self:Track(tagged)
		end
	end
	table.insert(self.Connections, CollectionService:GetInstanceAddedSignal(ENEMY_TAG):Connect(function(tagged: Instance)
		if tagged:IsA("Model") then
			self:Track(tagged)
		end
	end))
	return self
end

function Controller.Track(self: WorldState, model: Model)
	if self.ByModel[model] then
		return
	end
	local id = model:GetAttribute("AsuraId")
	if type(id) ~= "number" then
		if self.Pending[model] then
			return
		end
		-- One waiter per model, dropped once the id arrives (or with the model): every enemy respawn
		-- used to append a spent connection to self.Connections for the rest of the session.
		self.Pending[model] = model:GetAttributeChangedSignal("AsuraId"):Connect(function()
			local waiting = self.Pending[model]
			self.Pending[model] = nil
			if waiting then
				waiting:Disconnect()
			end
			self:Track(model)
		end)
		return
	end
	local previous = self.Entities[id]
	if previous then
		self:Untrack(previous)
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	local entity: Entity = {
		Id = id,
		Model = model,
		Humanoid = humanoid,
		Root = if root and root:IsA("BasePart") then root else nil,
		Kind = tostring(model:GetAttribute("AsuraKind") or "Enemy"),
		Boss = model:GetAttribute("AsuraBoss") == true,
		Name = if humanoid and humanoid.DisplayName ~= "" then humanoid.DisplayName else model.Name,
		Snapshot = nil,
		Previous = nil,
		UpdatedAt = 0,
		Connections = {},
	}
	self.Entities[id] = entity
	self.ByModel[model] = entity
	local function decode()
		local text = model:GetAttribute("AsuraState")
		if type(text) == "string" then
			local snapshot = Combat.unpackString(text)
			if snapshot then
				entity.Previous = entity.Snapshot
				entity.Snapshot = snapshot
				entity.UpdatedAt = os.clock()
			end
		end
	end
	decode()
	table.insert(entity.Connections, model:GetAttributeChangedSignal("AsuraState"):Connect(decode))
	table.insert(entity.Connections, model:GetAttributeChangedSignal("AsuraBoss"):Connect(function()
		entity.Boss = model:GetAttribute("AsuraBoss") == true
	end))
	table.insert(entity.Connections, model.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Humanoid") then
			entity.Humanoid = child
		elseif child.Name == "HumanoidRootPart" and child:IsA("BasePart") then
			entity.Root = child
		end
	end))
	table.insert(entity.Connections, model.AncestryChanged:Connect(function(_, parent: Instance?)
		if parent == nil then
			self:Untrack(entity)
		end
	end))
	fire(self.AddedListeners, entity)
end

function Controller.Untrack(self: WorldState, entity: Entity)
	if self.Entities[entity.Id] ~= entity then
		return
	end
	for _, connection in entity.Connections do
		connection:Disconnect()
	end
	table.clear(entity.Connections)
	self.Entities[entity.Id] = nil
	self.ByModel[entity.Model] = nil
	fire(self.RemovedListeners, entity)
end

function Controller.Receive(self: WorldState, payload: any)
	if type(payload) ~= "table" or payload.v ~= PROTOCOL_TAG then
		return
	end
	local time = if type(payload.t) == "number" then payload.t else Workspace:GetServerTimeNow()
	if type(payload.cue) == "string" then
		fire(self.CueListeners, {
			Kind = payload.cue,
			Source = if type(payload.s) == "number" then payload.s else 0,
			Data = if type(payload.d) == "table" then payload.d else {},
			Time = time,
		} :: Cue)
		return
	end
	if type(payload.e) ~= "table" then
		return
	end
	for _, item in payload.e do
		if type(item) == "table" and type(item.k) == "number" then
			local kind = Combat.EventNames[item.k]
			if kind then
				fire(self.EventListeners, {
					Kind = kind,
					Source = if type(item.s) == "number" then item.s else 0,
					Target = if type(item.t) == "number" then item.t else 0,
					Value = if type(item.v) == "number" then item.v else 0,
					Region = if type(item.r) == "string" then item.r else nil,
					Point = if typeof(item.p) == "Vector3" then item.p else nil,
					Time = time,
				} :: CombatEvent)
			end
		end
	end
end

function Controller.Get(self: WorldState, id: number): Entity?
	local entity = self.Entities[id]
	if entity and entity.Model.Parent then
		return entity
	end
	return nil
end

function Controller.Own(self: WorldState): Entity?
	return self:Get(self.LocalId)
end

function Controller.OwnSnapshot(self: WorldState): Snapshot?
	local own = self:Own()
	return if own then own.Snapshot else nil
end

function Controller.IsAlive(_self: WorldState, entity: Entity): boolean
	local snapshot = entity.Snapshot
	-- A dissolving enemy (server-pinned corpse) is dead at once, even before its KO snapshot arrives,
	-- so plates, lock-on and minimap dots drop the moment it falls.
	return entity.Model.Parent ~= nil and entity.Root ~= nil and (snapshot == nil or snapshot.State ~= "KO")
		and entity.Model:GetAttribute("AsuraDissolve") == nil
end

function Controller.IsHostile(self: WorldState, entity: Entity): boolean
	if entity.Id == self.LocalId then
		return false
	end
	local own = self:Own()
	local duel = entity.Model:GetAttribute("AsuraDuel")
	local ownDuel = if own then own.Model:GetAttribute("AsuraDuel") else nil
	if type(duel) == "string" or type(ownDuel) == "string" then
		return duel == ownDuel
	end
	if entity.Kind == "Enemy" then
		return true
	end
	return Workspace:GetAttribute("AsuraOpenPvP") == true
end

function Controller.OnEvent(self: WorldState, listener: EventListener): () -> ()
	return subscribe(self.EventListeners, listener)
end

function Controller.OnCue(self: WorldState, listener: CueListener): () -> ()
	return subscribe(self.CueListeners, listener)
end

function Controller.OnEntityAdded(self: WorldState, listener: EntityListener): () -> ()
	return subscribe(self.AddedListeners, listener)
end

function Controller.OnEntityRemoved(self: WorldState, listener: EntityListener): () -> ()
	return subscribe(self.RemovedListeners, listener)
end

-- Executes the server's dash grant on the locally owned root for the granted duration.
function Controller.Step(self: WorldState, _dt: number)
	local own = self:Own()
	local snapshot = own and own.Snapshot
	local root = own and own.Root
	if not own or not snapshot or not root then
		return
	end
	if snapshot.DashSeq ~= self.DashSeq then
		local first = self.DashSeq < 0
		self.DashSeq = snapshot.DashSeq
		if not first and snapshot.State == "Dashing" and snapshot.DashDuration > 0 then
			local direction = Vector3.new(snapshot.DashDirX, 0, snapshot.DashDirZ)
			if direction.Magnitude < 1e-3 then
				local look = root.CFrame.LookVector
				direction = -Vector3.new(look.X, 0, look.Z).Unit
			end
			local remaining = math.max(snapshot.DashDuration - snapshot.StateElapsed, 0.05)
			self.DashVelocity = direction * (snapshot.DashDistance / snapshot.DashDuration)
			self.DashEnds = os.clock() + remaining
		end
	end
	if os.clock() < self.DashEnds then
		if snapshot.State ~= "Dashing" and snapshot.State ~= "Idle" then
			self.DashEnds = 0
			return
		end
		local velocity = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(self.DashVelocity.X, velocity.Y, self.DashVelocity.Z)
	end
end

function Controller.Destroy(self: WorldState)
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	table.clear(self.Connections)
	for _, waiting in self.Pending do
		waiting:Disconnect()
	end
	table.clear(self.Pending)
	for _, entity in self.Entities do
		for _, connection in entity.Connections do
			connection:Disconnect()
		end
	end
	table.clear(self.Entities)
	table.clear(self.ByModel)
end

return Controller
