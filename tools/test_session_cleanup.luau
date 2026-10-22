--!nonstrict
-- Batch 26: long-session cleanup on the real client controllers and region builder (emulated on the
-- datatype shim). Before the fix WorldStateController appended a spent attribute waiter to its
-- connection list for every model that appeared before its id (every enemy respawn), and the
-- dialogue and ending controllers kept one Died connection per respawn (CampaignWorld's Start/Destroy
-- cycle is checked in tools/test_campaign_build.py). Counts only: no frame time, memory profiler or Studio.
-- Run: lune run tools/test_session_cleanup.luau (locally: python3 tools/lune_compat.py tools/test_session_cleanup.luau)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox") :: any
local task = require("@lune/task")

local passed, failed = 0, 0
local function check(name: string, ok: any)
	if ok then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local Instance, V3 = roblox.Instance, roblox.Vector3
local function signal()
	local s = { Links = {} }
	function s:Connect(fn) local l = { Connected = true }; function l:Disconnect() self.Connected = false end; table.insert(self.Links, { L = l, F = fn }); return l end
	function s:Fire(...) for _, e in table.clone(self.Links) do if e.L.Connected then e.F(...) end end end
	function s:live() local n = 0; for _, e in self.Links do if e.L.Connected then n += 1 end end; return n end
	return s
end
local function finder(t) return setmetatable(t, { __index = { WaitForChild = function(self, n) return rawget(self, n) end } }) end
local function env(extra)
	local e = { task = task, Vector3 = V3, Vector2 = roblox.Vector2, CFrame = roblox.CFrame, Color3 = roblox.Color3, Enum = roblox.Enum, Instance = Instance,
		UDim2 = roblox.UDim2, UDim = roblox.UDim, require = function(m) return m end, warn = function() end }
	for k, v in extra do e[k] = v end
	return e
end

-- 1. WorldState: 400 enemy respawns, each model arriving before its id, then leaving.
local Combat = require("../src/simulation/CombatRules")
local player = { UserId = 1, Name = "Tester", CharacterAdded = signal(), Character = nil }
local Players = { LocalPlayer = player, PlayerAdded = signal(), GetPlayers = function() return { player } end }
local tagged = signal()
local services = { Players = Players, Workspace = Instance.new("Workspace"),
	CollectionService = { GetTagged = function() return {} end, GetInstanceAddedSignal = function() return tagged end },
	ReplicatedStorage = finder({ AsurasPath = finder({ Simulation = finder({ CombatRules = Combat }) }) }) }
local game = { GetService = function(_, n) return assert(services[n], n) end }
local World = luau.load(fs.readFile("src/client/Controllers/WorldStateController.luau"), { debugName = "WorldState", environment = env({ game = game, os = os }) })()
local net = finder({ StateSnapshots = { OnClientEvent = signal() } })
local state = World.new(net)
local baseline = #state.Connections
local folder = Instance.new("Folder")
for n = 1, 400 do
	local model = Instance.new("Model"); model.Name = "Monk"; model.Parent = folder
	Instance.new("Humanoid").Parent = model
	tagged:Fire(model) -- tagged before the server stamps its id
	model:SetAttribute("AsuraId", 10000 + n)
	if n % 2 == 0 then model:Destroy() end -- half die and despawn; the rest are replaced by id
end
local tracked = 0
for _ in state.Entities do tracked += 1 end
local pending = 0
for _ in state.Pending do pending += 1 end
check(string.format("400 respawns leave the connection list at its baseline (%d -> %d)", baseline, #state.Connections), #state.Connections == baseline)
check("no attribute waiter survives its id", pending == 0)
check(string.format("despawned enemies are untracked (%d live)", tracked), tracked == 200)
state:Destroy()
check("Destroy clears entities, waiters and links", next(state.Entities) == nil and next(state.Pending) == nil and #state.Connections == 0)

-- 2. Ending controller: 200 respawns keep one Died link; Stop is idempotent across interrupts.
local function character()
	local model = Instance.new("Model")
	local humanoid = Instance.new("Humanoid"); humanoid.Parent = model
	return model, humanoid
end
player.Character = character()
player.CharacterAdded, player.CharacterRemoving = signal(), signal()
player.WaitForChild = function() return Instance.new("PlayerGui") end
local remote = { OnClientEvent = signal() }
local AsurasPath = { Net = finder({ DialogueIntent = remote }), Shared = {
	EndingRules = luau.load(fs.readFile("src/shared/EndingRules.luau"), { debugName = "EndingRules", environment = env({}) })(),
	EndingCredits = require("../src/shared/EndingCredits"),
	EffectsPreference = luau.load(fs.readFile("src/shared/EffectsPreference.luau"), { debugName = "Effects", environment = env({}) })() } }
services.ReplicatedStorage = { AsurasPath = AsurasPath }
services.UserInputService = { InputBegan = signal(), GamepadEnabled = false }
local kit = { Palette = {}, TitleFont = "Title", BodyFont = "Body" }
function kit.make(class, parent, props) local i = Instance.new(class); for k, v in props do i[k] = v end; i.Parent = parent; return i end
function kit.label(parent, text, _, _, _, props) local l = kit.make("TextLabel", parent, props or {}); l.Text = text; return l end
local Ending = luau.load(fs.readFile("src/client/Controllers/EndingController.luau"), { debugName = "Ending", environment = env({ game = game,
	script = { Parent = { HudKit = kit } } }) })()
local camera, input, banners = {}, { SetMenu = function(self, open) self.Menu = open end }, 0
local ui = { ShowBanner = function() banners += 1 end }
local scene = Ending.new(camera, input, ui)
for _ = 1, 200 do
	local model, humanoid = character()
	player.Character = model
	player.CharacterAdded:Fire(model)
	if math.random() < 0.3 then scene:Play(); humanoid.Died:Fire() end
end
check(string.format("200 respawns keep a fixed link count (%d)", #scene.Links), #scene.Links == 3 and scene.DiedLink ~= nil)
check("every interrupted crossing restored camera and input", not scene.Active and camera.DialogueFrame == nil and input.Menu == false and ui.EndingActive == false)
scene:Destroy()
check("Destroy drops the Died link", scene.DiedLink == nil and #scene.Links == 0)

print(string.format("session cleanup: %d passed, %d failed (emulated counts; no profiler or Studio session)", passed, failed))
if failed > 0 then error("session cleanup regression failed") end
