--!strict
-- Routes server spell cues to the showcase sorcery timelines. The server owns cooldowns, Qi, timing
-- and every hit; this module only renders. One live cast per source; an interrupt, KO or a newer
-- cast tears the old one down through its trove. Returns true when it handled the cue so the
-- generic SpellVfx ring/seal does not stack on top.
local Kit = require(script.Parent.SkillKit)
local Cinema = require(script.Parent.SkillCinema)
local Supernova = require(script.Parent.SupernovaShow)
local BlazingSun = require(script.Parent.BlazingSunShow)
local Showcase = {}

export type Cast = { Trove: Kit.Trove, Entity: any, Own: boolean, Cinema: Cinema.Director, Windup: number, Pulses: number, Bag: { [string]: any } }
export type Showcase = { State: any, Cinema: Cinema.Director, Casts: { [number]: Cast } }

local SHOWS: { [string]: any } = { CelestialSupernova = Supernova, BlazingSunAwakening = BlazingSun }
local RANGE = 220 -- the pillar reads from far away; past this nothing is built

function Showcase.handles(id: any): boolean
	return type(id) == "string" and SHOWS[id] ~= nil
end

function Showcase.new(state: any, camera: any): Showcase
	return { State = state, Cinema = Cinema.new(camera), Casts = {} }
end

local function stop(self: Showcase, source: number)
	local cast = self.Casts[source]
	if not cast then return end
	self.Casts[source] = nil
	if cast.Own then Cinema.release(self.Cinema, 0.3) end
	Kit.clean(cast.Trove)
end

local function begin(self: Showcase, source: number, entity: any, windup: number): Cast
	stop(self, source)
	local own = self.State:Own()
	local cast: Cast = { Trove = Kit.trove(), Entity = entity, Own = own ~= nil and own.Id == entity.Id, Cinema = self.Cinema,
		Windup = math.clamp(windup, 0.3, 6), Pulses = 0, Bag = {} }
	self.Casts[source] = cast
	-- Forget the cast once its own trove is cleaned (end of timeline), unless a newer one replaced it.
	Kit.add(cast.Trove, function() if self.Casts[source] == cast then self.Casts[source] = nil end end)
	if entity.Humanoid then
		Kit.add(cast.Trove, entity.Humanoid.Died:Connect(function() stop(self, source) end))
	end
	return cast
end

function Showcase.cue(self: Showcase, cue: any): boolean
	local d = cue.Data
	if type(d) ~= "table" then return false end
	if cue.Kind == "SpellInterrupted" then
		if not Showcase.handles(d.spell) then return false end
		stop(self, cue.Source)
		return true
	end
	if not Showcase.handles(d.spell) then return false end
	local show = SHOWS[d.spell]
	local entity = self.State:Get(cue.Source)
	local own = self.State:Own()
	local point = if typeof(d.position) == "Vector3" then d.position else nil
	if not entity or not entity.Model or not point then return true end
	if own and own.Root and (own.Root.Position - point).Magnitude > RANGE then return true end
	if cue.Kind == "SpellStartup" then
		local windup = (tonumber(d.release) or cue.Time + 1) - cue.Time
		show.startup(begin(self, cue.Source, entity, windup))
	elseif cue.Kind == "SpellRelease" then
		local cast = self.Casts[cue.Source] or begin(self, cue.Source, entity, 0.3)
		local ground = if typeof(d.destination) == "Vector3" and d.spell == "CelestialSupernova" then d.destination else point
		show.release(cast, ground)
	elseif cue.Kind == "SpellPulse" then
		local cast = self.Casts[cue.Source]
		if cast then
			cast.Pulses += 1
			if show.pulse then show.pulse(cast, point) end
			if show.whiteout and cast.Pulses >= 2 then show.whiteout(cast) end
		end
	elseif cue.Kind == "SpellHit" then
		return false -- the shared hit ring still marks who was struck
	end
	return true
end

function Showcase.destroy(self: Showcase)
	for source in self.Casts do stop(self, source) end
	Cinema.destroy(self.Cinema)
end

return table.freeze(Showcase)
