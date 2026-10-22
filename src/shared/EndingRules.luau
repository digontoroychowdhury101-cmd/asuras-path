--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/EndingRules
-- The six-sovereign ending (batch 22, #10). The story stage comes from the server-owned defeated-boss
-- flags plus the persisted story flags (souls.world.story). Flags only ever gain entries and the
-- ending grants nothing, so repeating a choice, dying, rejoining or an interrupted scene cannot
-- duplicate a reward or lose progress. Crossing is made in person beside Lin's bonfire; her altar
-- projection only summons the Emissary home. Pure: read by DialogueService, Objectives, CodexView
-- and EndingController.
local Ending = {}

export type Stage = "Bound" | "Release" | "Remained" | "Crossed"
export type Story = { [string]: boolean }

Ending.Sovereigns = table.freeze({ "GrandmasterShen", "VenerableBaize", "SlumberingTitan", "SovereignWu", "TwinSentinels", "AzureWyrm" })
Ending.Flags = table.freeze({ Released = "Released", Crossed = "Crossed", Remained = "Remained" })
-- Lady Lin beside the Primal Bonfire (NarrativeCatalog.NPCs.Lin; checked by the runtime test).
Ending.Lin = Vector3.new(8, 603, 918)
-- Portals that already lead home from a region (SunkenCryptLayout / SkyCitadelLayout ReturnPortal marks).
Ending.HomePortals = table.freeze({ -- region -> portal

	SanctuaryDepths = { Position = Vector3.new(520, 30, 1074), Name = "the crypt's return portal" },
	SkyCitadel = { Position = Vector3.new(44, 0, -2690), Name = "the bastion's return portal" },
})

function Ending.rested(bosses: { [string]: boolean }?): number
	local count = 0
	for _, id in Ending.Sovereigns do
		if bosses and bosses[id] == true then count += 1 end
	end
	return count
end

function Ending.stage(bosses: { [string]: boolean }?, story: Story?): Stage
	if Ending.rested(bosses) < #Ending.Sovereigns then return "Bound" end
	local s: Story = story or {}
	if s.Crossed then return "Crossed" end
	if s.Remained then return "Remained" end
	return "Release"
end

-- Lin's opening node: before six she greets; after, in person she offers the choice, as a
-- projection she calls the Emissary home; once crossed she welcomes the returned Emissary.
function Ending.linNode(stage: Stage, projection: boolean): string
	if stage == "Bound" then return "Greeting" end
	if stage == "Crossed" then return "Postgame" end
	return if projection then "Summons" else "Release"
end

-- Applies a choice to the story flags in place. Returns ok, refusal reason, and whether this was
-- the first time (the scene still replays; nothing is granted either way).
function Ending.decide(story: Story, stage: Stage, choice: string, projection: boolean): (boolean, string?, boolean)
	if stage == "Bound" then return false, "The six chains still bind you", false end
	if projection then return false, "Cross beside Lady Lin at the Primal Bonfire", false end
	if choice == "Cross" then
		local first = story.Crossed ~= true
		story.Released, story.Crossed = true, true
		return true, nil, first
	elseif choice == "Remain" then
		local first = story.Remained ~= true and story.Crossed ~= true
		story.Released, story.Remained = true, true
		return true, nil, first
	end
	return false, "Choice unavailable", false
end

function Ending.serialize(story: Story?): string
	local list: { string } = {}
	for id, on in story or {} do
		if on then table.insert(list, id) end
	end
	table.sort(list)
	return table.concat(list, ",")
end

export type Objective = { Key: string, Title: string, Detail: string, Target: any }

-- The post-six objective. `homeAltar` is a kindled altar in the current region (travel leg).
-- PvP stays an optional mention, never the conclusion.
function Ending.objective(stage: Stage, region: string?, homeAltar: string?): Objective?
	if stage == "Bound" then return nil end
	if stage == "Crossed" then
		return { Key = "Postgame", Title = "The Asura's Path is walked",
			Detail = "Roam, forge and read as you wish · replay the crossing with Lady Lin · Colosseum duels are optional", Target = nil }
	end
	if stage == "Remained" then
		return { Key = "Ending:Remain", Title = "Carry their names",
			Detail = "Roam freely · Lady Lin opens the crossing at the Primal Bonfire · Colosseum duels are optional", Target = nil }
	end
	local title = "Return to Lady Lin"
	if region == "Sanctuary" or region == nil then
		return { Key = "Ending:Return", Title = title, Detail = "Six chains are silent · she waits beside the Primal Bonfire",
			Target = { Kind = "Point", Position = Ending.Lin } }
	end
	local portal = if region then (Ending.HomePortals :: { [string]: { Position: Vector3, Name: string } })[region] else nil
	if portal then
		return { Key = "Ending:Return", Title = title, Detail = "Take " .. portal.Name .. " to the Primal Bonfire",
			Target = { Kind = "Point", Position = portal.Position } }
	end
	if homeAltar then
		return { Key = "Ending:Return", Title = title, Detail = "Rest at this region's altar and travel to the Primal Bonfire",
			Target = { Kind = "Altar", Id = homeAltar } }
	end
	return { Key = "Ending:Return", Title = title, Detail = "Rest at any altar and travel to the Primal Bonfire", Target = nil }
end

-- The crossing scene: world-fixed Sanctuary shots (Lin and the bonfire, the colossus, the dawn
-- beyond the tree), then the completion card, credits and the return. Lines reuse the authored
-- narrative (lore IV and VIII, Lin's Release). Kind "Card"/"Credits"/"Return" draw over a veil.
export type Beat = { Kind: string, Duration: number, From: Vector3?, To: Vector3?, Look: Vector3?, Line: string, Sub: string }
Ending.Scene = table.freeze({
	{ Kind = "Shot", Duration = 6, From = Vector3.new(26, 610, 944), To = Vector3.new(18, 608, 932), Look = Vector3.new(8, 605, 918),
		Line = "Six chains have fallen silent.", Sub = "The incense remembers every name the Emissary carried home." },
	{ Kind = "Shot", Duration = 7, From = Vector3.new(0, 612, 880), To = Vector3.new(0, 640, 840), Look = Vector3.new(0, 700, 705),
		Line = "\"Return them to rest,\" he said, \"and I shall return for you.\"", Sub = "The ferryman keeps his word." },
	{ Kind = "Shot", Duration = 7, From = Vector3.new(0, 660, 820), To = Vector3.new(0, 700, 790), Look = Vector3.new(0, 760, 560),
		Line = "Beyond the jade dawn, the river of souls lies open.", Sub = "Some endings must be chosen by the dead." },
	{ Kind = "Card", Duration = 6, Line = "THE ASURA'S PATH", Sub = "Six sovereigns at rest · the crossing is made" },
	{ Kind = "Credits", Duration = 14, Line = "CREDITS", Sub = "" },
	{ Kind = "Return", Duration = 5, Line = "THE EMISSARY RETURNS",
		Sub = "Everything you earned remains · the world, the forge and the Colosseum stay open" },
} :: { Beat })
Ending.CardBeat = 4 -- a skip jumps here once; a second skip ends the scene
Ending.SkipGuard = 0.8 -- seconds before input can skip (the choosing click must not skip)

-- Camera frame for a beat at `t` seconds in; reduced motion holds the beat's final framing.
function Ending.frame(beat: Beat, t: number, reducedMotion: boolean): (Vector3?, Vector3?)
	if not beat.From or not beat.To or not beat.Look then return nil, nil end
	local alpha = if reducedMotion then 1 else math.clamp(t / beat.Duration, 0, 1)
	alpha = alpha * alpha * (3 - 2 * alpha)
	return beat.From + (beat.To - beat.From) * alpha, beat.Look
end

return table.freeze(Ending)
