--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/CoreGuiPolicy
-- One source for each value: the Roblox health bar duplicates the vitals plate and the player
-- list covers the objective tracker, so both are switched off. Chat, the Roblox menu (whose People
-- tab still lists players), emotes and the backpack stay as they are. Fighters tracked by the HUD
-- also lose the default overhead name/health, which EnemyBars and the boss bar replace.
local StarterGui = game:GetService("StarterGui")

local Policy = {}
Policy.Disabled = table.freeze({ Enum.CoreGuiType.Health, Enum.CoreGuiType.PlayerList })

local function setAll(enabled: boolean)
	for _, kind in Policy.Disabled do
		pcall(function() StarterGui:SetCoreGuiEnabled(kind, enabled) end)
	end
end

local function quiet(entity: any)
	local humanoid = entity.Humanoid :: Humanoid?
	if not humanoid then return end
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	if entity.Kind == "Enemy" or entity.Boss then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

-- Applies the policy and keeps it on newly tracked fighters. Returns the undo function.
function Policy.start(state: any): () -> ()
	setAll(false)
	for _, entity in state.Entities do quiet(entity) end
	local stop = state:OnEntityAdded(quiet)
	return function()
		stop()
		setAll(true)
	end
end

return table.freeze(Policy)
