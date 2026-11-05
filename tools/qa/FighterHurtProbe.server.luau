--!nonstrict
-- Unmapped Studio-only probe. Lives only in the private copy tools/qa/qa_place.py builds (never publish or save back);
-- watches a ServerStorage attribute. "hurt" lowers the player's authoritative ActiveHP; "ko" runs the rule the game uses for a knockout.
-- It exists so a reaction to being hit can be watched where no foe will swing, such as a dialogue beside an NPC. Evidence type: seeded Studio diagnostic.
if not game:GetService("RunService"):IsStudio() then return end
local SS = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local Characters = require(game:GetService("ServerScriptService").AsurasPath.Services.CharacterService)
local Rules = require(game:GetService("ReplicatedStorage").AsurasPath.Simulation.CombatRules)
-- The MCP thread may not invoke a BindableFunction, so the request is an attribute: ServerStorage FighterHurtQA = "hurt:20:<seq>" or "ko:0:<seq>".
SS:GetAttributeChangedSignal("FighterHurtQA"):Connect(function()
	local op, n = string.match(SS:GetAttribute("FighterHurtQA") or "", "^(%a+):(%d+)")
	local p = Players:GetPlayers()[1]
	local e = p and Characters.GetEntity(p.UserId)
	if not e then return end
	if op == "hurt" then e.Fighter.ActiveHP = math.max(1, e.Fighter.ActiveHP - tonumber(n)) end
	if op == "ko" then Rules.knockOut(e.Fighter, os.clock()) end
	SS:SetAttribute("FighterHurtResult", string.format("hp=%.1f state=%s", e.Fighter.ActiveHP, tostring(e.Fighter.State)))
end)
