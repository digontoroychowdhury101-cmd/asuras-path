--!strict
-- Server events/cues enter here; no input listeners, remotes or alternate combat simulation.
local Combat = require(script.Parent.SanguineCombat)
local Ghost = require(script.Parent.SanguineGhost)
local Magic = require(script.Parent.SanguineMagic)
local Spells = require(game:GetService("ReplicatedStorage").AsurasPath.Simulation.SpellSchema) :: any
local Dispatch = {}
function Dispatch.event(self: any, event: any)
	local source, target = self.State:Get(event.Source), self.State:Get(event.Target)
	local own = self.State:Own()
	if event.Kind == "Rest" then
		if own and event.Source == own.Id then self:Clear() end
		return
	end
	if event.Kind == "KO" and own and event.Target == own.Id then self:Clear(); return end
	if self:Blocked() then return end
	local point = event.Point or (if target and target.Root then target.Root.Position else nil)
	if not self:Near(point) then return end
	local direction = if source and source.Root and target and target.Root then target.Root.Position - source.Root.Position else Vector3.zAxis
	local kind = event.Kind
	if kind == "DeflectSpark" then Combat.parry(self.Context, point, direction)
	elseif kind == "Hit" or kind == "CounterHit" or kind == "Armored" or kind == "Deathblow" then
		Combat.hit(self.Context, point, kind == "CounterHit" or kind == "Deathblow", kind == "Armored")
	elseif kind == "Block" or kind == "GuardBreak" or kind == "StanceBreak" then
		Combat.hit(self.Context, point, kind ~= "Block", true)
	elseif kind == "Dash" and source then Ghost.dodge(self.Context, source.Model) end
end
function Dispatch.cue(self: any, cue: any)
	local kind, d = cue.Kind, cue.Data
	if kind == "AltarTravel" or kind == "BossReset" or kind == "BossParticipantLeft" then
		local own = self.State:Own()
		if own and (cue.Source == own.Id or (type(d.participants) == "table" and table.find(d.participants, own.Id))) then self:Clear() end
		return
	end
	if self:Blocked() then return end
	local entity = self.State:Get(cue.Source)
	local point = if typeof(d.position) == "Vector3" then d.position
		elseif type(d.x) == "number" and type(d.z) == "number" then Vector3.new(d.x, tonumber(d.y) or 0.3, d.z)
		elseif entity and entity.Root then entity.Root.Position else nil
	if not self:Near(point) then return end
	if kind == "BossPhase" or kind == "BossEnrage" then
		Magic.phase(self.Context, point, if entity and entity.Model then entity.Model:GetExtentsSize().Y else 8)
	elseif kind == "BossDefeated" then Magic.death(self.Context, point)
	elseif kind == "Shockwave" then Magic.impact(self.Context, point, tonumber(d.radius) or 4)
	elseif kind == "SpellStartup" or kind == "SpellRelease" or kind == "SpellPulse" or kind == "ProjectileParry" then
		local spell = if type(d.spell) == "string" then Spells.get(d.spell) else nil
		Magic.spell(self.Context, point, if typeof(d.destination) == "Vector3" then d.destination else nil,
			if spell then spell.Discipline else nil, kind ~= "SpellStartup")
	end
	-- Demo GroundTelegraph/MeteorFall are not replayed: real BossEffects owns the danger footprint/timing.
end
return table.freeze(Dispatch)
