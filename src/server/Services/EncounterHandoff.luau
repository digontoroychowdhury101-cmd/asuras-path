--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/EncounterHandoff
-- Server side of the shared boss-entry contract (BossHandoff, #16). Opening a handoff locks and
-- protects every participant for exactly the camera shot plus its return blend (Combat cinematic:
-- no actions, no damage), holds the boss for the same window (AIService.Hold) and records the
-- window so the first impact can be deferred to readable control. A participant's Skip intent cuts
-- their own lock to the blend; once every participant has skipped, the boss hold shortens with
-- them. Death, reset and leaving release the player's lock immediately.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath").Shared
local HandoffRules = require(Shared.BossHandoff)
local Characters = require(script.Parent.CharacterService)

local Service = {}
type Open = { Window: HandoffRules.Window, Participants: { [number]: boolean }, Skipped: { [number]: boolean }, Members: { number } }
local open: { [string]: Open } = {}
local holdBoss: ((bossId: string, untilTime: number) -> ())? = nil

-- AIService registers how to hold a boss's agents (avoids a require cycle).
function Service.SetHolder(holder: (bossId: string, untilTime: number) -> ())
	holdBoss = holder
end

-- Opens a handoff of `kind` for `participants`; `members` (boss actors) are locked with them when
-- given (an entry); a phase transition keeps its own longer boss cinematic. Returns the window.
function Service.begin(bossId: string, kind: string, participants: { number }, members: { number }?): HandoffRules.Window
	local now = Characters.Now()
	local window = HandoffRules.window(kind, now)
	local set: { [number]: boolean } = {}
	for _, id in participants do
		local e = Characters.GetEntity(id)
		if e and e.Fighter.State ~= "KO" then
			set[id] = true
			Characters.Cinematic(id, HandoffRules.remaining(window, now))
		end
	end
	local actors: { number } = members or {}
	for _, id in actors do Characters.Cinematic(id, HandoffRules.remaining(window, now)) end
	open[bossId] = { Window = window, Participants = set, Skipped = {}, Members = actors }
	if holdBoss then (holdBoss :: any)(bossId, window.Ends) end
	return window
end

function Service.window(bossId: string): HandoffRules.Window?
	local entry = open[bossId]
	return if entry then entry.Window else nil
end

-- Defers an impact time against the boss's open handoff (no-op once it has passed).
function Service.defer(bossId: string, impact: number): number
	local entry = open[bossId]
	return if entry then HandoffRules.defer(impact, entry.Window) else impact
end

local function find(userId: number): (string?, Open?)
	for bossId, entry in open do
		if entry.Participants[userId] then return bossId, entry end
	end
	return nil, nil
end

function Service.skip(userId: number): (boolean, string)
	local bossId, entry = find(userId)
	local now = Characters.Now()
	if not bossId or not entry or now >= entry.Window.Lock or entry.Skipped[userId] then return false, "NoCinematic" end
	entry.Skipped[userId] = true
	Characters.Cinematic(userId, HandoffRules.Blend)
	for id in entry.Participants do
		if not entry.Skipped[id] then return true, "CinematicSkipped" end
	end
	-- Everyone has skipped: the boss's hold ends with theirs and the lead counts from now.
	entry.Window = HandoffRules.skip(entry.Window, now)
	for _, id in entry.Members do Characters.Cinematic(id, HandoffRules.Blend) end
	if holdBoss then (holdBoss :: any)(bossId, entry.Window.Ends) end
	return true, "CinematicSkipped"
end

-- Death, leaving or reset: the player's lock ends now (a KO keeps its own state).
function Service.release(userId: number)
	local _, entry = find(userId)
	if not entry then return end
	entry.Participants[userId] = nil
	local e = Characters.GetEntity(userId)
	if e and e.Fighter.State ~= "KO" and Characters.Now() < entry.Window.Ends then Characters.Cinematic(userId, 0) end
end

function Service.forget(bossId: string)
	local entry = open[bossId]
	if not entry then return end
	local everyone: { [number]: boolean } = table.clone(entry.Participants)
	for id in everyone do Service.release(id) end
	open[bossId] = nil
end

function Service.isProtected(userId: number): boolean
	local _, entry = find(userId)
	return entry ~= nil and not entry.Skipped[userId] and HandoffRules.protected(entry.Window, Characters.Now())
end

return Service
