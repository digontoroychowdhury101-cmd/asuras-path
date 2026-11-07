-- AR01 capture setup (Studio Play, Server datamodel, mock profile only). Seeded, not earned play.
-- execute_luau's own require() gets fresh module copies, so this installs a real server Script that uses
-- the game's live services: every boss is marked defeated for this session (walking into the Ash arena
-- starts no fight), the first player is made invulnerable and stood at STAND (the Hall of Champions,
-- outside the fog gate) so the Ash environment profile applies. Stop Play to discard everything.
local src = [==[
local S = game.ServerScriptService.AsurasPath.Services
local C = require(S.CharacterService)
local W = require(S.WorldService)
local P = require(S.PersistenceService)
local D = require(game.ReplicatedStorage.AsurasPath.Shared.WorldDefinitions)
local p, e, s
for _ = 1, 60 do
	p = game.Players:GetPlayers()[1]
	e = p and C.GetEntity(p.UserId)
	s = p and W.GetSession(p.UserId)
	if e and s then break end
	task.wait(1)
end
if not (game:GetService("RunService"):IsStudio() and P.IsMock and e and s) then script:SetAttribute("Result", "not ready / not mock Studio") return end
for id in D.Bosses do s.Bosses[id] = true end
e.Fighter.InvulnerableUntil = math.huge
C.Teleport(p.UserId, CFrame.new(script:GetAttribute("Stand")) * CFrame.Angles(0, math.pi, 0))
task.wait(1)
local a = D.Bosses.GrandmasterShen.Arena
script:SetAttribute("Result", string.format("ready at %.0f %.0f %.0f; Shen arena %s / %s", e.Root.Position.X, e.Root.Position.Y, e.Root.Position.Z, tostring(a.Center), tostring(a.Size)))
]==]
local old = game.ServerScriptService:FindFirstChild("AR01CaptureSetup")
if old then old:Destroy() end
local sc = Instance.new("Script")
sc.Name = "AR01CaptureSetup"
sc.Source = src
sc:SetAttribute("Stand", Vector3.new(STAND_X, STAND_Y, STAND_Z))
sc.Parent = game.ServerScriptService
for _ = 1, 140 do
	if sc:GetAttribute("Result") then break end
	task.wait(0.5)
end
return tostring(sc:GetAttribute("Result"))
