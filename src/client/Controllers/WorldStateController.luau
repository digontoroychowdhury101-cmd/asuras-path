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
-- A refused dash's correction follows a height change up to this many studs (a slope or step); a larger one was a
-- fall or a jump, and only the horizontal travel is undone.
local STEP_FOLLOW = 3
-- The states an unconfirmed action is shown over. Anything else (hit, stagger, break, KO) is the server overriding it.
local CALM = { Idle = true, Startup = true, Active = true, Recovery = true, Deflecting = true, Blocking = true }

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
-- refusal or timeout, or ended once the server executed it and moved on (Step). `Started` may lie ahead for a
-- combo link pressed before its swing's Recovery: nothing shows it until then, and its timeout counts from then.
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
	DirX: number?, -- a predicted dash's direction, for its animation
	DirZ: number?,
	Cost: number, -- stamina this prediction will spend (later follow-ups must afford it too)
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
	DashDriven: number, -- distance this dash's drive has commanded so far (a refusal undoes no more than this)
	DashCommand: Vector3, -- planar velocity last commanded (a refusal removes no more velocity than this)
	DashDriveAt: number?, -- clock of that command: `dt` is capped at low frame rates, the drive keeps running
	LastDashAt: number,
	Predicted: Predicted?, -- the oldest unconfirmed action
	FollowUps: { Predicted }, -- combo links predicted on top of it, oldest first
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
		DashDriven = 0,
		DashCommand = Vector3.zero,
		DashDriveAt = nil,
		LastDashAt = -math.huge,
		Predicted = nil,
		FollowUps = {},
		GuardPredicted = false,
		Pending = setmetatable({}, { __mode = "k" }) :: any,
	}
	local self = setmetatable(fields, Controller)
	table.insert(self.Connections, player:GetAttributeChangedSignal("AsuraIntent"):Connect(function()
		local records = player:GetAttribute("AsuraIntent")
		-- A link that was refused takes the links after it with it, not the swing it followed.
		for index, link in self.FollowUps do
			local status, tick = Prediction.terminal(records, link.Seq)
			if status == "Executed" then
				link.ExecutedTick = tick or 0
			elseif status then
				self:DropFollowUps(nil, index)
				break
			end
		end
		local predicted = self.Predicted
		if not predicted then
			return
		end
		local status, tick = Prediction.terminal(records, predicted.Seq)
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
	self.DashDriven, self.DashCommand, self.DashDriveAt = 0, Vector3.zero, nil
	self.LastDashAt = os.clock()
end

-- Adds the distance the last command has driven since it was issued (real time: the constraint holds it between frames).
local function closeDrive(self: WorldState)
	local at = self.DashDriveAt
	if at then
		local now = math.min(os.clock(), self.DashEnds)
		self.DashDriven += self.DashCommand.Magnitude * math.max(now - at, 0)
		self.DashDriveAt = now
	end
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
	if not own or not snapshot or not root or os.clock() < self.DashEnds then
		Prediction.trace(seq, "Unpredicted", kind)
		return false
	end
	local now = os.clock()
	local predicted: Predicted = { Seq = seq, Kind = kind, Base = snapshot.ActionSeq, Started = now, Model = own.Model, Cost = 0 }
	local link = kind == "Light" and self:LatestSwing(snapshot, now) or nil
	if link then
		local spent = (self.Predicted and self.Predicted.Cost or 0)
		for _, follow in self.FollowUps do
			spent += follow.Cost
		end
		local move, start = Prediction.followUp(snapshot, kind, link, now, spent)
		if not move then
			move, start = Prediction.restart(snapshot, kind, link, now, spent)
		end
		if not move or not start then
			Prediction.trace(seq, "Unpredicted", kind)
			return false
		end
		predicted.Move, predicted.Started, predicted.Cost = move, start, Prediction.costOf(move)
	elseif self.Predicted then
		Prediction.trace(seq, "Unpredicted", kind)
		return false
	elseif kind == "Dash" or kind == "Roll" then
		local distance, duration = Prediction.dash(snapshot, kind, now - self.LastDashAt)
		if not distance or not duration or self.DashSeq < 0 then
			Prediction.trace(seq, "Unpredicted", kind)
			return false
		end
		predicted.DashSeq = (self.DashSeq + 1) % 256
		startDash(self, root, Vector3.new(x or 0, 0, z or 0), distance, duration, duration)
		local line = self.DashVelocity.Unit
		predicted.DirX, predicted.DirZ = line.X, line.Z
	else
		local move = Prediction.attack(snapshot, kind)
		if not move then
			Prediction.trace(seq, "Unpredicted", kind)
			return false
		end
		predicted.Move, predicted.Cost = move, Prediction.costOf(move)
	end
	if self.Predicted then
		table.insert(self.FollowUps, predicted)
	else
		self.Predicted = predicted
	end
	Prediction.trace(seq, "Predicted", kind)
	return true
end

-- The swing a light press would chain from: the newest unconfirmed one, else the one the snapshot shows (placed on
-- the owner's clock by its elapsed time). nil when no swing is under way, so the press is an opener.
function Controller.LatestSwing(self: WorldState, snapshot: Snapshot, now: number): any
	local latest = self.FollowUps[#self.FollowUps] or self.Predicted
	if latest then
		return if latest.Move then latest else nil
	end
	local timing = Prediction.timingOf(snapshot.Move)
	if not timing or (snapshot.State ~= "Startup" and snapshot.State ~= "Active" and snapshot.State ~= "Recovery") then
		return nil
	end
	local own = self:Own()
	local into = snapshot.StateElapsed + (own and (own.Age + math.max(now - own.UpdatedAt, 0)) or 0)
	if snapshot.State == "Active" then
		into += timing.StartupSeconds
	elseif snapshot.State == "Recovery" then
		into += timing.StartupSeconds + timing.ActiveSeconds
	end
	return { Move = snapshot.Move, Started = now - into }
end

-- The newest unconfirmed action that has started, while the snapshot's state leaves it standing. Presentation only;
-- the animation layer reads it, nothing authoritative does.
function Controller.Presented(self: WorldState, snapshot: Snapshot): Predicted?
	if not CALM[snapshot.State] then
		return nil
	end
	local own = self:Own()
	local now = os.clock()
	local shown: Predicted? = nil
	local first = self.Predicted
	if first and first.Started <= now then
		shown = first
	end
	for _, follow in self.FollowUps do
		if follow.Started <= now then
			shown = follow
		end
	end
	return if shown and own and shown.Model == own.Model then shown else nil
end

-- Drops predicted links from `from` on: a link depends on the action before it. Nothing to undo; none is a dash.
function Controller.DropFollowUps(self: WorldState, _predicted: Predicted?, from: number?)
	local list = self.FollowUps
	for index = #list, from or 1, -1 do
		Prediction.trace(list[index].Seq, "RolledBack", list[index].Kind)
		table.remove(list, index)
	end
end

-- Guard is shown as a pose from Idle while held; it never opens a deflect window locally.
function Controller.PredictGuard(self: WorldState, held: boolean)
	local snapshot = self:OwnSnapshot()
	self.GuardPredicted = held and snapshot ~= nil and Prediction.guard(snapshot)
end

-- Undoes an unconfirmed prediction: a predicted dash stops and only the travel its own drive produced is taken
-- back (Prediction.dashTravel), and only the velocity it commanded comes off (Prediction.residualVelocity), so a
-- refused dash grants no displacement while knockback or a walk that happened meanwhile continues. The correction
-- is swept with the root's box along the actual line back, climbing or descending with the dash when the height
-- change is a slope or step (STEP_FOLLOW), so it stops short of a wall or the ground instead of passing through,
-- and it never floats the body far off the ground. A character that has since respawned, died or been replaced is
-- never moved. A predicted swing or guard pose simply falls back to the server's state.
function Controller.Rollback(self: WorldState)
	local predicted = self.Predicted
	self.Predicted = nil
	if predicted then
		Prediction.trace(predicted.Seq, "RolledBack", predicted.Kind)
	end
	self:DropFollowUps(predicted)
	if not predicted or not predicted.DashSeq then
		return
	end
	local own = self:Own()
	local root = own and own.Root
	local running = os.clock() < self.DashEnds
	closeDrive(self)
	self.DashEnds, self.DashDriveAt = 0, nil
	local drive = self.DashDrive
	if drive then
		drive.Enabled = false
	end
	if not own or not root or own.Model ~= predicted.Model or (own.Snapshot and own.Snapshot.State == "KO") then
		return
	end
	local command = self.DashCommand
	local velocity = root.AssemblyLinearVelocity
	local vx, vz = Prediction.residualVelocity(velocity.X, velocity.Z, command.X, command.Z, running)
	root.AssemblyLinearVelocity = Vector3.new(vx, velocity.Y, vz)
	local stop = if running then root.Position else (predicted.DashStop or root.Position)
	local line = self.DashVelocity
	local speed = line.Magnitude
	if speed < 1e-6 then
		return
	end
	local unit = line / speed
	local distance = Prediction.dashTravel(self.DashFrom.X, self.DashFrom.Z, stop.X, stop.Z, unit.X, unit.Z, self.DashDriven)
	if distance < 1e-3 then
		return
	end
	-- Height the dash gained or lost, in proportion to the travel undone; a fall off a ledge is not followed back up.
	local whole = Vector3.new(stop.X - self.DashFrom.X, 0, stop.Z - self.DashFrom.Z).Magnitude
	local rise = stop.Y - self.DashFrom.Y
	local climb = if whole > 1e-3 and math.abs(rise) <= STEP_FOLLOW then -rise * math.min(distance / whole, 1) else 0
	local back = -unit * distance + Vector3.new(0, climb, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { own.Model }
	local hit = Workspace:Blockcast(root.CFrame, root.Size, back, params)
	local allowed = if hit then math.max(hit.Distance - 0.05, 0) else back.Magnitude
	root.CFrame = root.CFrame + back.Unit * allowed
end

local function stopDash(self: WorldState, root: BasePart)
	closeDrive(self)
	self.DashEnds, self.DashDriveAt = 0, nil
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
	-- A snapshot naming a link settles everything before it: the earlier actions ran and were left behind unseen.
	for index, link in self.FollowUps do
		if snapshot.IntentSeq == link.Seq then
			if self.Predicted then
				Prediction.trace(self.Predicted.Seq, "Ended", self.Predicted.Kind)
			end
			for earlier = 1, index - 1 do
				Prediction.trace(self.FollowUps[earlier].Seq, "Ended", self.FollowUps[earlier].Kind)
			end
			self.Predicted = link
			for _ = 1, index do
				table.remove(self.FollowUps, 1)
			end
			break
		end
	end
	local predicted = self.Predicted
	local mine = predicted ~= nil and snapshot.IntentSeq == predicted.Seq
	if predicted then
		local waited = os.clock() - predicted.Started
		if mine then
			self.Predicted = table.remove(self.FollowUps, 1) -- the snapshot shows the action this intent started: authority takes over
			Prediction.trace(predicted.Seq, "Confirmed", predicted.Kind)
		elseif predicted.ExecutedTick and (snapshot.SampleTick >= predicted.ExecutedTick or waited > 2 * Prediction.CONFIRM_TIMEOUT) then
			-- Executed, but by this sample the server had already left that action (hit, cancel): nothing to undo.
			self.Predicted = table.remove(self.FollowUps, 1)
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
		closeDrive(self)
		self.DashCommand, self.DashDriveAt = planar, os.clock()
		local velocity = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(planar.X, velocity.Y, planar.Z)
		drive = dashDrive(self, root)
		drive.PlaneVelocity = Vector2.new(planar.X, planar.Z)
		drive.Enabled = true
	elseif drive and drive.Enabled then
		closeDrive(self)
		self.DashDriveAt = nil
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
