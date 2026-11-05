--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/RouteGates
-- The ridge gate at the head of Bamboo Pass's stairs: barred from the crest side, lifted once by a player standing on the crest, saved on that
-- profile. The world has one gate, so it stands open while anyone present has opened it; a passer-by gains a walk, never a reward. The server
-- checks where the player stands. Nothing here pays anything, so reopening or a reset cannot grant twice.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath").Shared
local Rules = require(Shared.RouteGates)
local Campaign = require(Shared.CampaignZones)
local InputMap = require(Shared.InputMap)
local Characters = require(script.Parent:WaitForChild("CharacterService") :: ModuleScript)
local Persistence = require(script.Parent:WaitForChild("PersistenceService") :: ModuleScript) :: any
local Kit = require(script.Parent:WaitForChild("MonasteryKit") :: ModuleScript)

local Service = {}
local ID = "BambooRidge"
local LIFT_RANGE = 10
local connections: { RBXScriptConnection } = {}
local running = false
local leaves: { { Part: BasePart, Closed: CFrame, Open: CFrame } } = {}
local bar: BasePart? = nil
local lift: ProximityPrompt? = nil
local barred: ProximityPrompt? = nil
local isOpen = false

-- Server-side and pure on position: standing on the crest, at the gate, on its south (barred) side.
function Service.canLift(p: Vector3, gate: Vector3): boolean
	return p.Y >= gate.Y - 7 and p.Z < gate.Z and (p - gate).Magnitude <= LIFT_RANGE
end

local function setOpen(open: boolean)
	if open == isOpen then return end
	isOpen = open
	for _, leaf in leaves do
		leaf.Part.CFrame = if open then leaf.Open else leaf.Closed
		leaf.Part.CanCollide = not open
	end
	if bar then bar.Transparency = if open then 1 else 0 end
	if lift then lift.Enabled = not open end
	if barred then barred.Enabled = not open end
end

local function refresh()
	local any = false
	for _, player in Players:GetPlayers() do
		local profile = Persistence.Get(player.UserId)
		if profile then
			player:SetAttribute("AsuraOpenGates", Rules.encode(profile))
			if Rules.isOpen(profile, ID) then any = true end
		end
	end
	setOpen(any)
end

local function onLift(player: Player, gate: Vector3)
	local e = Characters.GetActor(player.UserId)
	-- A monk may be on you up here: the bar lifts in a fight, as a rest does, because the flag only opens a known way down.
	if not e or e.Fighter.State == "KO" or e.Respawning or e.Duel or not Service.canLift(e.Root.Position, gate) then return end
	local ok = Persistence.Transaction(player.UserId, function(p: any)
		p.routeFlags[ID] = true
	end)
	if ok then
		refresh()
		Characters.Cue("RouteOpened", player.UserId, { place = "the ridge stairs" })
	end
end

local function build(parent: Instance, box: any)
	local folder = Kit.folder("RidgeGate", parent)
	local P = Kit.Palette
	local gate = Vector3.new(box.X, box.Y, box.Z)
	for _, side in { -1, 1 } do
		local hinge = CFrame.new(box.X + side * box.SX / 2, box.Y, box.Z)
		local closed = hinge * CFrame.new(-side * box.SX / 4, 0, 0)
		local open = hinge * CFrame.Angles(0, side * math.rad(-100), 0) * CFrame.new(-side * box.SX / 4, 0, 0)
		local leaf = Kit.part(folder, "GateLeaf", Vector3.new(box.SX / 2, box.SY, box.SZ), closed, P.WoodDark, Enum.Material.Wood)
		leaf.CanCollide = true
		table.insert(leaves, { Part = leaf, Closed = closed, Open = open })
	end
	local beam = Kit.part(folder, "GateBar", Vector3.new(box.SX + 1, 0.9, 0.7), CFrame.new(box.X, box.Y + 0.4, box.Z - 1), P.Lacquer, Enum.Material.Wood, Kit.decor())
	bar = beam
	local crest = Instance.new("ProximityPrompt")
	crest.ActionText, crest.ObjectText, crest.HoldDuration, crest.MaxActivationDistance = "Lift the Bar", "Ridge Gate", 0.6, 8
	crest.RequiresLineOfSight = false
	InputMap.applyPrompt(crest)
	local anchorCrest = Kit.part(folder, "GateLiftPoint", Vector3.new(1, 1, 1), CFrame.new(box.X, box.Y - 1.5, box.Z - 2.5), P.WoodDark, Enum.Material.Wood, Kit.decor())
	anchorCrest.Transparency = 1
	crest.Parent = anchorCrest
	lift = crest
	table.insert(connections, crest.Triggered:Connect(function(player: Player) onLift(player, gate) end))
	-- From below it only says what it is; the marker already points to the way round.
	local below = Instance.new("ProximityPrompt")
	below.ActionText, below.ObjectText, below.HoldDuration, below.MaxActivationDistance = "Barred from the far side", "Ridge Gate", 0, 7
	below.RequiresLineOfSight = false
	InputMap.applyPrompt(below)
	local anchorBelow = Kit.part(folder, "GateFacePoint", Vector3.new(1, 1, 1), CFrame.new(box.X, box.Y - 1.5, box.Z + 2.5), P.WoodDark, Enum.Material.Wood, Kit.decor())
	anchorBelow.Transparency = 1
	below.Parent = anchorBelow
	barred = below
end

-- After CampaignWorld: the gate stands in Bamboo Pass's map.
function Service.Start()
	if running then return end
	running = true
	local parent = workspace:FindFirstChild("Map_BambooPass")
	local layout = Campaign.Layouts[1]
	if not parent or not layout.Gates then return end
	build(parent, layout.Gates[ID])
	task.spawn(function()
		while running do
			refresh()
			task.wait(1)
		end
	end)
end

function Service.Stop()
	running = false
	for _, c in connections do c:Disconnect() end
	table.clear(connections)
end

return Service
