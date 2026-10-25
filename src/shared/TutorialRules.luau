--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/TutorialRules
-- The opening training (batch 10, findings #11-#13, #15, #19). Ten steps taught in order against the
-- Sparring Phantom at the Monastery Gate landing. A step advances only on its own proof of success:
-- authoritative combat events judged on the server (a light attack that landed, a strike blocked,
-- a deflect, an i-frame evade, a Blood Rally, a drink that restored health, a perilous strike
-- deflected or evaded, a deathblow), plus two client-only actions the server cannot see (camera
-- lock-on and an Air Glide held for a moment). Pressing a button is never enough. Pure: shared by
-- TutorialService, TutorialController and the tests.
local Rules = {}

export type Step = { Id: string, Title: string, Do: string, Why: string, Keys: { string } }
-- Do/Why may contain {Command} placeholders filled with the player's live bindings.
Rules.Steps = {
	{ Id = "LockOn", Title = "Lock on", Keys = { "Lock" }, Do = "Face the Sparring Phantom and press {Lock} to lock on.",
		Why = "Locked on, your strikes and the camera follow the foe." },
	{ Id = "Light", Title = "Strike", Keys = { "Light" }, Do = "Land a light attack with {Light}.",
		Why = "Swings that fall short say OUT OF REACH: step in until the blade can touch." },
	{ Id = "Guard", Title = "Guard", Keys = { "Guard" }, Do = "Hold {Guard} and block one of its strikes.",
		Why = "Blocking costs stamina and posture; it keeps your health." },
	{ Id = "Deflect", Title = "Deflect", Keys = { "Guard" }, Do = "Tap {Guard} just as a strike lands to deflect it.",
		Why = "A deflect costs nothing and breaks the attacker's posture." },
	{ Id = "Dodge", Title = "Dodge", Keys = { "Dash" }, Do = "Press {Dash} as a strike lands to pass through it.",
		Why = "The first instant of a dash cannot be hit." },
	{ Id = "Rally", Title = "Blood Rally", Keys = { "Light" }, Do = "Take a hit, then strike back with {Light} while the pale part of your bar remains.",
		Why = "That pale part is recoverable. Heavy blows lower your ceiling (▼) until you rest." },
	{ Id = "Heal", Title = "Heal", Keys = { "Heal" }, Do = "While wounded, drink from the gourd with {Heal}.",
		Why = "Drinking at full health keeps the charge. Resting at an altar refills the gourd." },
	{ Id = "Perilous", Title = "Perilous attack", Keys = { "Guard", "Dash" }, Do = "When ▲ PERILOUS flashes, deflect with {Guard} or dodge with {Dash}.",
		Why = "Perilous attacks break through a held guard. Bosses name the counter on the warning." },
	{ Id = "Deathblow", Title = "Deathblow", Keys = { "Heavy" }, Do = "Break its posture, then finish it with {Heavy}.",
		Why = "Deflects and steady hits fill posture; a broken foe takes a deathblow." },
	{ Id = "Glide", Title = "Air Glide", Keys = { "Jump", "Aim" }, Do = "Jump, jump again in the air, then hold {Jump} or {Aim} to glide.",
		Why = "A boss cue reading \"Counter: Air Glide\" means get airborne over the sweep." },
} :: { Step }

Rules.ClientSignals = table.freeze({ LockOn = true, Glide = true }) :: { [string]: boolean }
Rules.GlideSeconds = 0.6 -- an Air Glide must be held this long to count
Rules.Skipped, Rules.Complete = "Skipped", "Complete"
Rules.Stakes = "Essence you carry is dropped where you fall. Return to your bloodstain to reclaim it; fall again first and it is lost."
	.. " Spend Essence at an altar to keep it safe. The courtyard beyond is not training."

local index: { [string]: number } = {}
for i, step in Rules.Steps do index[step.Id] = i end

-- The first step not yet done, or nil once complete / skipped.
function Rules.current(done: { [string]: boolean }): Step?
	if done[Rules.Skipped] or done[Rules.Complete] then return nil end
	for _, step in Rules.Steps do
		if not done[step.Id] then return step end
	end
	return nil
end

-- Returns the step id this signal completes, or nil (only the current step can advance).
function Rules.advance(done: { [string]: boolean }, signal: string): string?
	local step = Rules.current(done)
	return if step and step.Id == signal then step.Id else nil
end

function Rules.finished(done: { [string]: boolean }): boolean
	return Rules.current(done) == nil
end

-- What the player's fighter was doing when the event fired (TutorialService reads it).
export type Own = { State: string, Move: string? }
-- Combat event (as CombatRules emits it) -> the signal it proves for `player`, or nil.
-- `perilous` says the attacker's strike was unblockable (a perilous attack). F08: CombatRules reports
-- Evade for any invulnerability (Studio logged the player "evading" while lying helpless after a
-- deathblow) and Hit for spells, arts and burn ticks, so a dodge needs a dash and Light an M1 move.
function Rules.signal(kind: string, source: number, target: number, player: number, perilous: boolean, own: Own?): string?
	if kind == "Hit" or kind == "CounterHit" then
		local m1 = own ~= nil and (own.Move == "Light" or own.Move == "RunningAttack")
		return if source == player and m1 then "Light" else nil
	elseif kind == "Block" then
		return if target == player then "Guard" else nil
	elseif kind == "DeflectSpark" or kind == "Evade" then -- Source avoided Target's strike
		if source ~= player or (kind == "Evade" and not (own and own.State == "Dashing")) then return nil end
		if perilous then return "Perilous" end
		return if kind == "DeflectSpark" then "Deflect" else "Dodge"
	elseif kind == "Rally" then
		return if source == player then "Rally" else nil
	elseif kind == "Deathblow" then
		return if source == player then "Deathblow" else nil
	end
	return nil
end

-- Progress travels as the AsuraTutorial attribute: completed ids joined by commas.
function Rules.serialize(done: { [string]: boolean }): string
	if done[Rules.Skipped] then return Rules.Skipped end
	if Rules.finished(done) then return Rules.Complete end
	local list: { string } = {}
	for _, step in Rules.Steps do if done[step.Id] then table.insert(list, step.Id) end end
	return table.concat(list, ",")
end

function Rules.parse(text: any): { [string]: boolean }
	local done: { [string]: boolean } = {}
	if type(text) ~= "string" then return done end
	for id in string.gmatch(text, "[^,]+") do
		if index[id] or id == Rules.Skipped or id == Rules.Complete then done[id] = true end
	end
	if done[Rules.Complete] then for _, step in Rules.Steps do done[step.Id] = true end end
	return done
end

-- Fills {Command} placeholders with live key captions.
function Rules.text(template: string, label: (command: string) -> string): string
	return (string.gsub(template, "{(%a+)}", function(command: string) return "[" .. label(command) .. "]" end))
end

return table.freeze(Rules)
