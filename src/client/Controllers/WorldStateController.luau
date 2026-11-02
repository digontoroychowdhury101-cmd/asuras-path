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
local Prediction = require(Shared:WaitForChild("Simulation"):WaitForChild("LocalPrediction") :: ModuleScript)

export type Snapshot = Combat.Snapshot

-- Transit age correction is capped (TIMING_CONTRACT §4): beyond this a remote action is shown late rather than
-- fast-forwarded, so a lag spike never skips a windup. Equal to the server's 150 ms rewind envelope.
local MAX_SAMPLE_AGE = 0.15

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
	Age: number, -- seconds the snapshot had already aged in transit when it arrived (capped, see MAX_SAMPLE_AGE)
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

-- One unconfirmed local action (LocalPrediction): the intent seq that names it, the owner's ActionSeq it was
-- predicted on top of, and what is being shown. Confirmed by a snapshot naming its IntentSeq, rolled back on a
-- refusal or timeout, or ended once the server executed it and moved on (Step).
export type Predicted = {
	Seq: number,
	Kind: string, -- "Light" | "Heavy" | "Dash" | "Roll"
	Move: string?,
	Base: number,
	Started: number,
	DashSeq: number?,
	ExecutedTick: number?, -- server tick of the Executed record, once seen
	Model: Model, -- the character that made the prediction: a respawned one is never corrected
	DashStop: Vector3?, -- where the predicted dash's own drive stopped (rollback undoes only that travel)
}

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
	DashDrive: LinearVelocity?,
	DashFrom: Vector3,
	DashLength: number,
	LastDashAt: number,
	Predicted: Predicted?,
	GuardPredicted: boolean,
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
		DashDrive = nil,
		DashFrom = Vector3.zero,
		DashLength = 0,
		LastDashAt = -math.huge,
		Predicted = nil,
		GuardPredicted = false,
		Pending = setmetatable({}, { __mode = "k" }) :: any,
	}
	local self = setmetatable(fields, Controller)
	table.insert(self.Connections, player:GetAttributeChangedSignal("AsuraIntent"):Connect(function()
		local predicted = self.Predicted
		if not predicted then
			return
		end
		local status, tick = Prediction.terminal(player:GetAttribute("AsuraIntent"), predicted.Seq)
		if status == "Executed" then
			predicted.ExecutedTick = tick or 0
		elseif status then
			self:Rollback()
		end
	end))

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
		Age = 0,
		Connections = {},
	}
	self.Entities[id] = entity
	self.ByModel[model] = entity
	local function decode()
		local text = model:GetAttribute("AsuraState")
		if type(text) == "string" then
			local snapshot = Combat.unpackString(text)
			local last = entity.Snapshot
			-- A sample older than the one applied (reordered delivery) is dropped, never applied over it.
			if snapshot and not (last and snapshot.SampleTick > 0 and snapshot.SampleTick < last.SampleTick) then
				entity.Previous = entity.Snapshot
				entity.Snapshot = snapshot
				entity.UpdatedAt = os.clock()
				entity.Age = if snapshot.SampleStamp > 0
					then math.clamp(Workspace:GetServerTimeNow() - snapshot.SampleStamp, 0, MAX_SAMPLE_AGE)
					else 0
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
	-- so plates, lock-on and minimap dots drop the moment it falls. F07: so is the victim of a killing
	-- deathblow, whose KO waits out the 1.6 s execution (its plate sat at 0 HP until then).
	local executed = snapshot ~= nil and snapshot.State == "DeathblowVictim" and snapshot.ActiveHP <= 0
	return entity.Model.Parent ~= nil and entity.Root ~= nil and (snapshot == nil or snapshot.State ~= "KO") and not executed
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

-- Horizontal-plane LinearVelocity on the owned root. A per-frame velocity write lost most of the
-- dash to the humanoid's braking (WalkSpeed is 0 while Dashing): a 14-stud dash covered ~6 studs in
-- Studio (post-F26 step 2). The constraint holds the granted speed every physics step; gravity stays free.
local function dashDrive(self: WorldState, root: BasePart): LinearVelocity
	local drive = self.DashDrive
	if drive and drive.Parent == root then
		return drive
	end
	local attachment = root:FindFirstChild("RootAttachment")
	if not attachment or not attachment:IsA("Attachment") then
		attachment = Instance.new("Attachment")
		attachment.Name = "AsuraDashAttachment"
		attachment.Parent = root
	end
	local made = Instance.new("LinearVelocity")
	made.Name = "AsuraDashDrive"
	made.Attachment0 = attachment :: Attachment
	made.RelativeTo = Enum.ActuatorRelativeTo.World
	made.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	made.PrimaryTangentAxis = Vector3.xAxis
	made.SecondaryTangentAxis = Vector3.zAxis
	made.MaxForce = 1e7
	made.Enabled = false
	made.Parent = root
	self.DashDrive = made
	return made
end

local function startDash(self: WorldState, root: BasePart, direction: Vector3, distance: number, duration: number, remaining: number)
	if direction.Magnitude < 1e-3 then
		local look = root.CFrame.LookVector
		direction = -Vector3.new(look.X, 0, look.Z)
	end
	self.DashVelocity = direction.Unit * (distance / duration)
	self.DashEnds = os.clock() + remaining
	self.DashFrom, self.DashLength = root.Position, distance * remaining / duration
	self.LastDashAt = os.clock()
end

-- Diagnostic trace of an outgoing intent (no-op unless a QA probe enabled LocalPrediction.Trace).
function Controller.Sent(_self: WorldState, seq: number, action: string)
	Prediction.trace(seq, "Sent", action)
end

-- Shows a pressed action before the server confirms it, when LocalPrediction allows (combat recovery
-- Stage 2). A dash starts the one local executor at once; the server's grant for the expected DashSeq is
-- then adopted rather than applied again. Returns whether a prediction was made.
function Controller.Predict(self: WorldState, seq: number, kind: string, x: number?, z: number?): boolean
	local own = self:Own()
	local snapshot = own and own.Snapshot
	local root = own and own.Root
	if not own or not snapshot or not root or self.Predicted or os.clock() < self.DashEnds then
		Prediction.trace(seq, "Unpredicted", kind)
		return false
	end
	local predicted: Predicted = { Seq = seq, Kind = kind, Base = snapshot.ActionSeq, Started = os.clock(), Model = own.Model }
	if kind == "Dash" or kind == "Roll" then
		local distance, duration = Prediction.dash(snapshot, kind, os.clock() - self.LastDashAt)
		if not distance or not duration or self.DashSeq < 0 then
			Prediction.trace(seq, "Unpredicted", kind)
			return false
		end
		predicted.DashSeq = (self.DashSeq + 1) % 256
		startDash(self, root, Vector3.new(x or 0, 0, z or 0), distance, duration, duration)
	else
		local move = Prediction.attack(snapshot, kind)
		if not move then
			Prediction.trace(seq, "Unpredicted", kind)
			return false
		end
		predicted.Move = move
	end
	self.Predicted = predicted
	Prediction.trace(seq, "Predicted", kind)
	return true
end

-- Guard is shown as a pose from Idle while held; it never opens a deflect window locally.
function Controller.PredictGuard(self: WorldState, held: boolean)
	local snapshot = self:OwnSnapshot()
	self.GuardPredicted = held and snapshot ~= nil and Prediction.guard(snapshot)
end

-- Undoes an unconfirmed prediction: a predicted dash stops and only the travel its own drive produced is taken
-- back, so a refused dash grants no displacement while any later motion (knockback, walking) is kept. The
-- correction is horizontal and swept with the root's box: it stops short at a wall or rising ground instead of
-- passing through. A character that has since respawned, died or been replaced is never moved. A predicted
-- swing or guard pose simply falls back to the server's state.
function Controller.Rollback(self: WorldState)
	local predicted = self.Predicted
	self.Predicted = nil
	if predicted then
		Prediction.trace(predicted.Seq, "RolledBack", predicted.Kind)
	end
	if not predicted or not predicted.DashSeq then
		return
	end
	local own = self:Own()
	local root = own and own.Root
	local running = os.clock() < self.DashEnds
	self.DashEnds = 0
	local drive = self.DashDrive
	if drive then
		drive.Enabled = false
	end
	if not own or not root or own.Model ~= predicted.Model or (own.Snapshot and own.Snapshot.State == "KO") then
		return
	end
	local stop = if running then root.Position else (predicted.DashStop or root.Position)
	local back = Vector3.new(self.DashFrom.X - stop.X, 0, self.DashFrom.Z - stop.Z)
	local distance = back.Magnitude
	if distance < 1e-3 then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { own.Model }
	local hit = Workspace:Blockcast(root.CFrame, root.Size, back, params)
	local allowed = if hit then math.max(hit.Distance - 0.05, 0) else distance
	root.CFrame = root.CFrame + back.Unit * allowed
	root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
end

local function stopDash(self: WorldState, root: BasePart)
	self.DashEnds = 0
	local drive = self.DashDrive
	if drive then
		drive.Enabled = false
	end
	local predicted = self.Predicted
	if predicted and predicted.DashSeq then
		predicted.DashStop = root.Position
	end
end

-- Executes the server's dash grant on the locally owned root for the granted duration.
function Controller.Step(self: WorldState, dt: number)
	local own = self:Own()
	local snapshot = own and own.Snapshot
	local root = own and own.Root
	if not own or not snapshot or not root then
		return
	end
	local predicted = self.Predicted
	local mine = predicted ~= nil and snapshot.IntentSeq == predicted.Seq
	if predicted then
		local waited = os.clock() - predicted.Started
		if mine then
			self.Predicted = nil -- the snapshot shows the action this intent started: authority takes over
			Prediction.trace(predicted.Seq, "Confirmed", predicted.Kind)
		elseif predicted.ExecutedTick and (snapshot.SampleTick >= predicted.ExecutedTick or waited > 2 * Prediction.CONFIRM_TIMEOUT) then
			-- Executed, but by this sample the server had already left that action (hit, cancel): nothing to undo.
			self.Predicted = nil
			Prediction.trace(predicted.Seq, "Ended", predicted.Kind)
		elseif predicted.ExecutedTick == nil and waited > Prediction.CONFIRM_TIMEOUT then
			self:Rollback()
		end
	end
	if self.GuardPredicted and snapshot.State ~= "Idle" then
		self.GuardPredicted = false
	end
	if snapshot.DashSeq ~= self.DashSeq then
		local first = self.DashSeq < 0
		self.DashSeq = snapshot.DashSeq
		if mine and predicted and predicted.DashSeq then
			-- The grant for the predicted dash: already executing locally, so it is adopted, not applied again.
			-- The predicted distance is exact (LocalPrediction only predicts when nothing scales it).
			self.DashLength = math.min(self.DashLength, snapshot.DashDistance)
		elseif not first and snapshot.State == "Dashing" and snapshot.DashDuration > 0 then
			local direction = Vector3.new(snapshot.DashDirX, 0, snapshot.DashDirZ)
			local remaining = math.max(snapshot.DashDuration - snapshot.StateElapsed, 0.05)
			startDash(self, root, direction, snapshot.DashDistance, snapshot.DashDuration, remaining)
		end
	end
	local drive = self.DashDrive
	if os.clock() < self.DashEnds then
		-- An interruption the server shows (hit, stagger) ends the dash; a predicted dash still waiting for its
		-- grant sees the pre-dash Idle snapshot, which does not.
		if snapshot.State ~= "Dashing" and snapshot.State ~= "Idle" then
			stopDash(self, root)
			return
		end
		-- Stop on the granted distance, not a frame boundary: at low frame rates the last frame is slowed
		-- so the dash lands on its length instead of overshooting by a frame of full speed.
		local moved = Vector3.new(root.Position.X - self.DashFrom.X, 0, root.Position.Z - self.DashFrom.Z).Magnitude
		local left = self.DashLength - moved
		local full = self.DashVelocity.Magnitude
		if left <= 0.05 or full < 1e-3 then
			stopDash(self, root)
			return
		end
		local planar = self.DashVelocity * math.min(1, left / (full * math.max(dt, 1 / 240)))
		local velocity = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(planar.X, velocity.Y, planar.Z)
		drive = dashDrive(self, root)
		drive.PlaneVelocity = Vector2.new(planar.X, planar.Z)
		drive.Enabled = true
	elseif drive and drive.Enabled then
		drive.Enabled = false
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
