--!strict
-- Script: ServerScriptService/TikTokVFX_Server
-- Owns cooldowns, casting state, timing and damage for the two showcase skills, then tells every
-- client when each phase happens. Clients render all VFX locally; nothing a client sends can pick
-- a victim, a damage amount or skip a cooldown.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage:WaitForChild("TikTokVFX_Config")) :: any

local remote = Instance.new("RemoteEvent")
remote.Name = Config.RemoteName
remote.Parent = ReplicatedStorage

type Cast = { Id: number, Skill: string, Character: Model, Humanoid: Humanoid, Walk: number, Jump: number, JumpHeight: number,
	Alive: boolean, Died: RBXScriptConnection?, Track: AnimationTrack? }
local cooldowns: { [Player]: { [string]: number } } = {}
local casting: { [Player]: Cast } = {}
local lastRequest: { [Player]: number } = {}
local serial = 0

local function broadcast(packet: { [string]: any })
	packet.t = Workspace:GetServerTimeNow()
	remote:FireAllClients(packet)
end

local function excluding(character: Model): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	return params
end

-- Floor under the caster (the pillar stands on it even while the caster levitates).
local function ground(origin: Vector3, character: Model): Vector3
	local hit = Workspace:Raycast(origin, Vector3.new(0, -60, 0), excluding(character))
	return if hit then hit.Position else origin - Vector3.new(0, 3, 0)
end

-- Living humanoids (players or NPCs) whose root is within `radius` horizontally of `floor`.
local function victims(caster: Model, floor: Vector3, radius: number, height: number): { Humanoid }
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { caster }
	local box = CFrame.new(floor + Vector3.new(0, height / 2 - 2, 0))
	local found: { [Humanoid]: boolean } = {}
	local list: { Humanoid } = {}
	for _, part in Workspace:GetPartBoundsInBox(box, Vector3.new(radius * 2, height, radius * 2), overlap) do
		local model = part:FindFirstAncestorOfClass("Model")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		local root = model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
		if humanoid and root and root:IsA("BasePart") and not found[humanoid] and humanoid.Health > 0 then
			local flat = Vector3.new(root.Position.X - floor.X, 0, root.Position.Z - floor.Z)
			if flat.Magnitude <= radius then
				found[humanoid] = true
				table.insert(list, humanoid)
			end
		end
	end
	return list
end

local function strike(cast: Cast, floor: Vector3, column: boolean)
	local skill = Config.Skills[cast.Skill]
	for _, humanoid in victims(cast.Character, floor, skill.Radius, if column then 80 else 12) do
		humanoid:TakeDamage(skill.Damage)
		if skill.Burn > 0 then
			for tick = 1, 3 do
				task.delay(tick, function()
					if humanoid.Parent and humanoid.Health > 0 then humanoid:TakeDamage(skill.Burn) end
				end)
			end
		end
	end
end

local function finish(player: Player, cast: Cast)
	if casting[player] ~= cast then return end
	casting[player] = nil
	if cast.Died then cast.Died:Disconnect() end
	if cast.Track then cast.Track:Stop(0.2) end
	if cast.Humanoid.Parent and cast.Humanoid.Health > 0 then
		cast.Humanoid.WalkSpeed, cast.Humanoid.JumpPower, cast.Humanoid.JumpHeight = cast.Walk, cast.Jump, cast.JumpHeight
	end
end

local function cast(player: Player, id: string)
	local skill = Config.Skills[id]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then return end
	local now = os.clock()
	local mine = cooldowns[player] or {}
	cooldowns[player] = mine
	if (mine[id] or 0) > now then
		remote:FireClient(player, { kind = "Denied", skill = id, remaining = mine[id] - now })
		return
	end
	mine[id] = now + skill.Cooldown
	serial += 1
	local c: Cast = { Id = serial, Skill = id, Character = character, Humanoid = humanoid, Walk = humanoid.WalkSpeed,
		Jump = humanoid.JumpPower, JumpHeight = humanoid.JumpHeight, Alive = true }
	casting[player] = c
	humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight = 0, 0, 0 -- rooted, never anchored
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator and skill.Animation and skill.Animation ~= "" then
		local animation = Instance.new("Animation")
		animation.AnimationId = skill.Animation
		c.Track = animator:LoadAnimation(animation)
		if c.Track then c.Track:Play(0.15) end
	end
	c.Died = humanoid.Died:Connect(function()
		c.Alive = false
		broadcast({ kind = "Interrupt", skill = id, character = character, id = c.Id })
		finish(player, c)
	end)
	broadcast({ kind = "Startup", skill = id, character = character, id = c.Id, windup = skill.Windup, position = root.Position })
	task.delay(skill.Windup, function()
		if not c.Alive or not root.Parent then return end
		local origin = root.Position
		local floor = ground(origin, character)
		broadcast({ kind = "Release", skill = id, character = character, id = c.Id, position = origin, ground = floor })
		for n = 1, skill.Pulses do
			task.delay((n - 1) * skill.PulseDelay, function()
				if not c.Alive or humanoid.Health <= 0 then return end
				strike(c, if id == "Supernova" then floor else origin - Vector3.new(0, 3, 0), id == "Supernova")
				broadcast({ kind = "Pulse", skill = id, character = character, id = c.Id, n = n, position = origin, ground = floor })
			end)
		end
		task.delay(skill.Lock, function() finish(player, c) end)
	end)
end

remote.OnServerEvent:Connect(function(player: Player, request: any)
	if type(request) ~= "table" or type(request.skill) ~= "string" or Config.Skills[request.skill] == nil then return end
	local now = os.clock()
	if (lastRequest[player] or 0) > now - 0.2 or casting[player] then return end -- spam guard, one cast at a time
	lastRequest[player] = now
	cast(player, request.skill)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	local c = casting[player]
	if c then c.Alive = false; finish(player, c) end
	cooldowns[player], lastRequest[player] = nil, nil
end)
