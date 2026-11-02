--!nonstrict
-- Unmapped Studio-only fixture (Windows acceptance W-07, 2026-11-03): makes the server refuse a dash the client
-- already predicted, so the rollback runs against real level geometry. ServerStorage.DashRefusalQA:Invoke(op, ...)
--   "drain", seconds  keep the first player's stamina at 0 for that long (the client, behind an injected
--                     IncomingReplicationLag, still sees full stamina and predicts the dash);
--   "ko"              knock the first player out now; "koOnDash" knock them out once the body moves faster than a
--                     walk (the predicted dash, whose velocity replicates); "where" returns the root position.
-- ReplicatedStorage.DashRefusalRemote:FireServer(op, ...) runs the same ops from the client (QA only).
-- Seeded server state, never an ordinary result. Inject with tools/qa/qa_inject.py during Play; Stop removes it.
if not game:GetService("RunService"):IsStudio() then
	return
end
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Characters = require(game:GetService("ServerScriptService").AsurasPath.Services.CharacterService)

local drainUntil = 0
local koOnSpeed = false
local function knockOut(e)
	-- Any living foe as the (hostile) source of an unblockable area blow larger than the player's health.
	for _, other in Characters.Entities() do
		if other.Kind == "Enemy" and other.Fighter.State ~= "KO" then
			return "ko " .. Characters.ApplyArea(other.Id, e.Id, 10000, 0, true) .. " " .. e.Fighter.State
		end
	end
	return "no foe to strike"
end
RunService.Heartbeat:Connect(function()
	local p = Players:GetPlayers()[1]
	local e = p and Characters.GetEntity(p.UserId)
	if not e then
		return
	end
	if os.clock() < drainUntil then
		e.Fighter.Stamina = 0
	end
	-- KO while the (client-driven) predicted dash is moving: its speed replicates to the server.
	local v = e.Root.AssemblyLinearVelocity
	if koOnSpeed and not e.Respawning and e.Fighter.State ~= "KO" and Vector3.new(v.X, 0, v.Z).Magnitude > 40 then
		koOnSpeed = false
		print("[DashRefusal] mid-dash", knockOut(e))
	end
end)

local fn = game:GetService("ServerStorage"):FindFirstChild("DashRefusalQA") or Instance.new("BindableFunction")
fn.Name = "DashRefusalQA"
fn.Parent = game:GetService("ServerStorage")
local function handle(op, a)
	local p = Players:GetPlayers()[1]
	local e = p and Characters.GetEntity(p.UserId)
	if not e then
		return "no fighter"
	end
	if op == "drain" then
		drainUntil = os.clock() + (a or 1.5)
		e.Fighter.Stamina = 0
		return "drained"
	elseif op == "ko" then
		return knockOut(e)
	elseif op == "koOnDash" then
		koOnSpeed = true
		return "ko armed for the next dash"
	elseif op == "where" then
		local r = e.Root.Position
		return string.format("%.2f,%.2f,%.2f", r.X, r.Y, r.Z)
	end
	return "unknown op"
end
fn.OnInvoke = handle
-- The same ops from the QA client, so a drain and the dash press can be issued ~0.1 s apart.
local remote = game:GetService("ReplicatedStorage"):FindFirstChild("DashRefusalRemote") or Instance.new("RemoteEvent")
remote.Name = "DashRefusalRemote"
remote.Parent = game:GetService("ReplicatedStorage")
remote.OnServerEvent:Connect(function(_, op, a)
	handle(op, a)
end)
print("[DashRefusal] on")
