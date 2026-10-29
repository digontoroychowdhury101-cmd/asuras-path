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
local parent = script.Parent
assert(parent, "Client bootstrap has no parent")
local root = parent:WaitForChild("AsurasPath", timeout)
assert(root, "Client controller folder did not replicate")
local controllers = root:WaitForChild("Controllers", timeout)
assert(controllers, "Client controllers did not replicate")

local WorldState = require(controllers:WaitForChild("WorldStateController", timeout) :: ModuleScript)
local Camera = require(controllers:WaitForChild("CameraController", timeout) :: ModuleScript)
local Input = require(controllers:WaitForChild("InputController", timeout) :: ModuleScript)
local Movement = require(controllers:WaitForChild("MovementController", timeout) :: ModuleScript)
local Environment = require(controllers:WaitForChild("EnvironmentController", timeout) :: ModuleScript)
local Soundscape = require(controllers:WaitForChild("SoundscapeController", timeout) :: ModuleScript)
local GameFeel = require(controllers:WaitForChild("GameFeelController", timeout) :: ModuleScript)
local Sanguine = require(controllers:WaitForChild("SanguineController", timeout) :: ModuleScript)
local Interface = require(controllers:WaitForChild("InterfaceController", timeout) :: ModuleScript)
local Colosseum = require(controllers:WaitForChild("ColosseumController", timeout) :: ModuleScript)
local Objective = require(controllers:WaitForChild("ObjectiveController", timeout) :: ModuleScript)
local ControlsCard = require(controllers:WaitForChild("ControlsCard", timeout) :: ModuleScript)
local SpellController = require(controllers:WaitForChild("SpellController", timeout) :: ModuleScript)
local Dialogue = require(controllers:WaitForChild("DialogueController", timeout) :: ModuleScript)
local Wagers = require(controllers:WaitForChild("WagerController", timeout) :: ModuleScript)
local Mastery = require(controllers:WaitForChild("MasteryEffects", timeout) :: ModuleScript)
local Prologue = require(controllers:WaitForChild("PrologueController", timeout) :: ModuleScript)
local EndingScene = require(controllers:WaitForChild("EndingController", timeout) :: ModuleScript)
local PauseMenu = require(controllers:WaitForChild("PauseMenu", timeout) :: ModuleScript)
local SakuraHud = require(controllers:WaitForChild("SakuraHud", timeout) :: ModuleScript)
local CoreGuiPolicy = require(controllers:WaitForChild("CoreGuiPolicy", timeout) :: ModuleScript)
local CombatHud = require(controllers:WaitForChild("CombatHud", timeout) :: ModuleScript)
local Tutorial = require(controllers:WaitForChild("TutorialController", timeout) :: ModuleScript)
local Handoff = require(controllers:WaitForChild("EncounterHandoffController", timeout) :: ModuleScript)
local CreatureMotion = require(controllers:WaitForChild("CreatureMotion", timeout) :: ModuleScript)
local DeviceLayout = require(controllers:WaitForChild("DeviceLayout", timeout) :: ModuleScript)
local LandscapeBudget = require(controllers:WaitForChild("LandscapeBudget", timeout) :: ModuleScript)
local FoliageWind = require(controllers:WaitForChild("FoliageWind", timeout) :: ModuleScript)
local Effects = require(Shared:WaitForChild("Shared"):WaitForChild("EffectsPreference") :: ModuleScript) :: any

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
local movement = Movement.new(state, camera)
local input = Input.new(state, camera, send, movement)
local feel = GameFeel.new(state, camera)
local environment = Environment.new(state)
local soundscape = Soundscape.new(state, movement)
local ui = Interface.new(state, camera, input)
local sanguine = Sanguine.new(state, ui) -- VFX-place visuals only; existing gameplay/camera/HUD stay authoritative.
local spells = SpellController.new(state, ui, net, camera)
local colosseum = Colosseum.new(state, input, ui, net)
local dialogue = Dialogue.new(camera,input,ui)
local ending = EndingScene.new(camera, input, ui) -- batch 22: the crossing, after the server records it
local wagers = Wagers.new(ui)
local mastery = Mastery.new(state,camera,ui)
local objective = Objective.new(state, ui)
local controls = ControlsCard.new(input, ui)
local pause = PauseMenu.new(camera, input, ui, shopRemote, controls, spells.Panel.Root)
local sakura = SakuraHud.new(state, ui, pause, controls)
local combatHud = CombatHud.new(state, camera, input, ui)
local tutorial = Tutorial.new(state, camera, movement, input, ui) -- sets ui.OnTraining (Respite: replay training)
local handoff = Handoff.new(state, camera, input, ui, function(action: string) send(action) end) -- boss cutscene lock + skip
local creatures = CreatureMotion.new(state) -- procedural gait/wings/tail for creature bosses
-- Batch 25: touch/desktop HUD placement, safe-area insets, 44-pt touch targets, controller route to Respite.
local landscape = LandscapeBudget.new()
local foliageWind = FoliageWind.new()
local devices = DeviceLayout.new(ui, input, { input.TouchGui, dialogue.View.Gui },
	{ Window = spells.Panel.Window, Hint = spells.Panel.Hint }, pause)
ui.OnPrologue = function() task.spawn(Prologue.Play, ui, input, camera, true) end -- Respite: replay opening
local restoreCoreGui = CoreGuiPolicy.start(state) -- default health bar and player list off
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
	if type(settings.comfort) == "table" then
		Effects.set(Effects.sanitize(settings.comfort)) -- reduced effects/motion/flashes and text size (batch 25)
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
	ending:Destroy()
	devices:Destroy()
	landscape:Destroy()
	foliageWind:Destroy()
	dialogue:Destroy();wagers:Destroy();mastery:Destroy()
	spells:Destroy()
	sakura:Destroy()
	combatHud:Destroy()
	tutorial:Destroy()
	handoff:Destroy(); creatures:Destroy()
	restoreCoreGui()
	pause:Destroy()
	controls:Destroy()
	objective:Destroy()
	colosseum:Destroy()
	ui:Destroy()
	soundscape:Destroy(); environment:Destroy()
	feel:Destroy()
	sanguine:Destroy()
	input:Destroy()
	movement:Destroy()
	camera:Destroy()
	state:Destroy()
	player:SetAttribute("AsuraClientReady", false)
end

table.insert(connections, script.Destroying:Connect(destroy))
table.insert(connections, RunService.PreSimulation:Connect(function(dt: number)
	if alive then movement:Step(math.min(dt, Config.Movement.MaxFrameDelta)) end
end))

-- One ordered frame after the engine camera: input -> dash execution -> camera -> feel -> HUD.
RunService:BindToRenderStep(RENDER_STEP, Enum.RenderPriority.Camera.Value + 1, function(dt: number)
	if not alive then
		return
	end
	local frame = math.min(dt, Config.Movement.MaxFrameDelta)
	input:Step(frame)
	spells:Step()
	state:Step(frame)
	camera:Update(frame)
	feel:Update(frame)
	sanguine:Update(frame)
	environment:Update(frame); soundscape:Update(frame)
	ui:Update(frame)
	colosseum:Update(frame)
 wagers:Update()
	objective:Update(frame)
	controls:Update(frame)
	sakura:Update(frame)
	combatHud:Update(frame)
	tutorial:Update(frame)
	handoff:Update()
	ending:Update(frame)
	creatures:Update(frame)
end)

player:SetAttribute("AsuraClientReady", true)
task.spawn(Prologue.Play, ui, input, camera)
print("[Asura's Path] Client ready: camlock, game feel, Souls HUD and Colosseum online.")
