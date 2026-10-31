-- Unmapped local integration probe. Never calls Claim directly: the driver must hold the real
-- Interact key. Only seeded placement changes; original prompt, rules and stats remain intact.
assert(game:GetService("RunService"):IsStudio(), "Studio only")
local services = game.ServerScriptService.AsurasPath.Services
local persistence = require(services.PersistenceService)
assert(persistence.IsMock, "mock persistence required")
local characters = require(services.CharacterService)
local player = assert(game.Players:GetPlayers()[1], "player required")
local chest = workspace.WorldDiscoveryCaches.SanctuaryReliquary
local prompt = chest:FindFirstChildOfClass("ProximityPrompt")
local origin = player.Character:GetPivot()
local fired = 0
local link = prompt.Triggered:Connect(function(p) if p == player then fired += 1 end end)
local function snapshot()
	local p = assert(persistence.Get(player.UserId), "profile required")
	local i = p.souls.inventory
	return { claimed = i.caches.SanctuaryReliquary == true, catalyst = i.weapons.Catalyst == true,
		ember = i.spells.EmberCataclysm == true, blazingSun = i.spells.BlazingSunAwakening == true,
		promptTriggered = fired, key = prompt.KeyboardKeyCode.Name, promptEnabled = prompt.Enabled,
		holdSeconds = prompt.HoldDuration, requiresLineOfSight = prompt.RequiresLineOfSight,
		proxyPosition = tostring(chest.Position), proxySize = tostring(chest.Size),
		proxyCollides = chest.CanCollide, proxyQueries = chest.CanQuery, mockPersistence = true }
end
local before = snapshot()
local control = Instance.new("BindableFunction")
control.Name = "Control"
control.OnInvoke = function(op)
	if op == "Place" then characters.Teleport(player.UserId, CFrame.new(43, 607.2, 988)) end
	if op == "Restore" then
		characters.Teleport(player.UserId, origin)
		link:Disconnect()
	end
	return game.HttpService:JSONEncode({ before = before, current = snapshot() })
end
control.Parent = script
script:SetAttribute("Ready", true)
