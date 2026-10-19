--!strict
local Characters = require(script.Parent.CharacterService)
local Tactics = require(script.Parent.BossTactics)
local World = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.WorldDefinitions)
local Duo = {}
type Encounter = { Members: { number }, Enraged: boolean, Finished: boolean, Boss: World.BossDef }
local encounters: { [string]: Encounter } = {}
function Duo.register(boss: World.BossDef, members: { number })
	encounters[boss.Id] = { Members = members, Enraged = false, Finished = false, Boss = boss }
end
function Duo.members(bossId: string): { number }
	local encounter = encounters[bossId]
	return if encounter then encounter.Members else {}
end
function Duo.alive(bossId: string): number?
	for _, id in Duo.members(bossId) do
		local e = Characters.GetEntity(id)
		if e and e.Fighter.State ~= "KO" then return id end
	end
	return nil
end
function Duo.onKO(bossId: string, victim: number): boolean
	local encounter = encounters[bossId]
	if not encounter or encounter.Finished then return false end
	Tactics.reset(victim)
	local survivor = Duo.alive(bossId)
	if survivor then
		if #encounter.Members == 2 and not encounter.Enraged then
			encounter.Enraged = true
			local e = Characters.GetEntity(survivor)
			local boss = encounter.Boss
			if e then
				Characters.RestoreFighter(survivor)
				Characters.Cinematic(survivor, 2)
				e.Model:SetAttribute("AsuraBossEnraged", true)
				e.Model:SetAttribute("AsuraAffinity", "Lightning+Iron")
				Tactics.enrage(survivor, if survivor == encounter.Members[1] and boss.Partner then boss.Partner.Attacks else boss.Phases[1].Attacks or {})
				Characters.Cue("BossEnrage", survivor, { boss = bossId, duration = 2, name = "Oath of the Fallen", affinity = "Lightning+Iron", members = encounter.Members, survivor = e.Model.Name })
			end
		end
		return false
	end
	encounter.Finished = true
	return true
end
function Duo.forget(bossId: string)
	for _, id in Duo.members(bossId) do Tactics.reset(id) end
	encounters[bossId] = nil
end
return Duo
