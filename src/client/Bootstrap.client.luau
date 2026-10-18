--!strict
-- LocalScript: StarterPlayer/StarterPlayerScripts/AsurasPathClient
-- Asura's Path master client entry. Mounts the replication mirror and the presentation stack in
-- dependency order (WorldState -> Camera -> Input -> GameFeel -> Interface -> Colosseum), binds a
-- single render step after the camera, connects the server replication and account receivers, and
-- owns the outgoing ActionIntent sequence.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("AsurasPath", 15)
assert(Shared, "AsurasPath shared folder did not replicate")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript) :: any
local timeout: number = Config.Runtime.DependencyTimeoutSeconds
local root = script.Parent:WaitForChild("AsurasPath", timeout)
assert(root, "Client controller folder did not replicate")
local controllers = root:WaitForChild("Controllers", timeout)
assert(controllers, "Client controllers did not replicate")

local WorldState = require(controllers:WaitForChild("WorldStateController", timeout) :: ModuleScript)
local Camera = require(controllers:WaitForChild("CameraController", timeout) :: ModuleScript)
local Input = require(controllers:WaitForChild("InputController", timeout) :: ModuleScript)
local GameFeel = require(controllers:WaitForChild("GameFeelController", timeout) :: ModuleScript)
local Interface = require(controllers:WaitForChild("InterfaceController", timeout) :: ModuleScript)
local Colosseum = require(controllers:WaitForChild("ColosseumController", timeout) :: ModuleScript)
local Objective = require(controllers:WaitForChild("ObjectiveController", timeout) :: ModuleScript)
local ControlsCard = require(controllers:WaitForChild("ControlsCard", timeout) :: ModuleScript)

local net = Shared:WaitForChild("Net", timeout)
assert(net, "Network folder did not replicate")
local actionRemote = net:WaitForChild("ActionIntent", timeout) :: RemoteEvent
local snapshotRemote = net:WaitForChild("StateSnapshots", timeout) :: RemoteEvent
local shopRemote = net:WaitForChild("ShopIntent", timeout) :: RemoteEvent
assert(actionRemote and snapshotRemote and shopRemote, "Combat remotes did not replicate")

local RENDER_STEP = "AsuraClient"
local MAX_SEQUENCE = 2147483647

local player = Players.LocalPlayer
local sequence = 0
local alive = true
local connections: { RBXScriptConnection } = {}

-- Outgoing intents carry a strictly increasing sequence and the client's server-clock press time;
-- the server reconciles that time against its own tick inside the lag-compensation window.
local function send(action: string, variant: string?, x: number?, z: number?, held: boolean?, time: number?)
	if not alive then
		return
	end
	sequence = if sequence >= MAX_SEQUENCE then 1 else sequence + 1
	local packet: { [string]: any } = {
		seq = sequence,
		action = action,
		time = time or Workspace:GetServerTimeNow(),
	}
	if variant ~= nil then
		packet.variant = string.sub(variant, 1, 32)
	end
	if x ~= nil and z ~= nil then
		packet.x = math.clamp(x, -1, 1)
		packet.z = math.clamp(z, -1, 1)
	end
	if held ~= nil then
		packet.held = held
	end
	actionRemote:FireServer(packet)
end

-- Replication mirror first: every presentation controller reads fighters through it.
local state = WorldState.new(net)
local camera = Camera.new(state)
local input = Input.new(state, camera, send)
local feel = GameFeel.new(state, camera)
local ui = Interface.new(state, camera, input)
local colosseum = Colosseum.new(state, input, ui, net)
local objective = Objective.new(state, ui)
local controls = ControlsCard.new(input, ui)
ui.OnIntent = function(action: string, variant: string?)
	send(action, variant)
end

-- Account receiver: camera preferences arrive with the profile sync and with settings results.
local function applySettings(profile: any)
	if type(profile) ~= "table" or type(profile.settings) ~= "table" then
		return
	end
	local settings = profile.settings
	if type(settings.fov) == "number" then
		camera.Fov = math.clamp(settings.fov, Config.Camera.MinFOV, Config.Camera.MaxFOV)
	end
	if type(settings.sensitivity) == "number" then
		camera.Sensitivity = math.clamp(settings.sensitivity, Config.Camera.SensitivityMin, Config.Camera.SensitivityMax)
	end
end

table.insert(connections, shopRemote.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then
		return
	end
	applySettings(payload.profile)
end))

-- The server may finish booting after this script starts; request the profile once it is ready.
local function requestProfile()
	shopRemote:FireServer({ action = "GetProfile" })
end
if Workspace:GetAttribute("AsuraReady") == true then
	requestProfile()
else
	local pending: RBXScriptConnection? = nil
	pending = Workspace:GetAttributeChangedSignal("AsuraReady"):Connect(function()
		if Workspace:GetAttribute("AsuraReady") == true then
			if pending then
				pending:Disconnect()
			end
			requestProfile()
		end
	end)
	table.insert(connections, pending :: RBXScriptConnection)
end

local function destroy()
	if not alive then
		return
	end
	alive = false
	RunService:UnbindFromRenderStep(RENDER_STEP)
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	controls:Destroy()
	objective:Destroy()
	colosseum:Destroy()
	ui:Destroy()
	feel:Destroy()
	input:Destroy()
	camera:Destroy()
	state:Destroy()
	player:SetAttribute("AsuraClientReady", false)
end

table.insert(connections, script.Destroying:Connect(destroy))

-- One ordered frame after the engine camera: input -> dash execution -> camera -> feel -> HUD.
RunService:BindToRenderStep(RENDER_STEP, Enum.RenderPriority.Camera.Value + 1, function(dt: number)
	if not alive then
		return
	end
	local frame = math.min(dt, Config.Movement.MaxFrameDelta)
	input:Step(frame)
	state:Step(frame)
	camera:Update(frame)
	feel:Update(frame)
	ui:Update(frame)
	colosseum:Update(frame)
	objective:Update(frame)
	controls:Update(frame)
end)

player:SetAttribute("AsuraClientReady", true)
print("[Asura's Path] Client ready: camlock, game feel, Souls HUD and Colosseum online.")
