--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/CombatCallouts
-- Readable combat feedback: damage numbers (pale yours, gold counters/deathblows, red taken, grey
-- chip), centre calls for PARRY / BLOCKED / GUARD BROKEN / COUNTER / DEATHBLOW, contact calls from
-- ContactCues (MISSED / OUT OF REACH / EVADED / DODGED / FEINT) and a guard emblem with posture.
-- Priority: a perilous warning (shape-marked "▲") outranks critical calls (PARRY!, DEATHBLOW,
-- breaks), which outrank info calls; damage numbers shrink and fade while a warning is up.
local TweenService = game:GetService("TweenService")
local HudKit = require(script.Parent:WaitForChild("HudKit") :: ModuleScript)
local Sakura = require(script.Parent:WaitForChild("SakuraKit") :: ModuleScript)
local Icons = require(script.Parent:WaitForChild("MoveIcons") :: ModuleScript)
local Contact = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.ContactCues)
local DuoBars = require(script.Parent:WaitForChild("DuoBars") :: ModuleScript)
local Callouts = {}
local C = Sakura.Colors
-- Customization ------------------------------------------------------------------------------
local MAX_POPUPS, POPUP_TIME, CALLOUT_TIME, GREY = 16, 0.85, 0.75, Color3.fromRGB(190, 170, 182)
local DAMAGE_KINDS = { Hit = true, CounterHit = true, BleedProc = true, Deathblow = true }
local WARNING, CRITICAL, INFO = 3, 2, 1

export type View = {
	Gui: ScreenGui, State: any, Text: TextLabel, Pop: UIScale, Until: number, Live: number, Priority: number, WarnUntil: number,
	Guard: Frame, GuardStroke: UIStroke, GuardFill: Frame, OwnState: string,
}

function Callouts.new(gui: ScreenGui, state: any): View
	local text = HudKit.label(gui, "", 40, Enum.Font.Garamond, C.Gold, {
		Name = "CombatCallout", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.34),
		Size = UDim2.fromOffset(520, 48), TextStrokeTransparency = 0.1, TextTransparency = 1,
	})
	local pop = HudKit.make("UIScale", text, {}) :: UIScale
	local guard = Sakura.medallion(gui, 44, UDim2.fromScale(0.5, 0.62), false)
	guard.Name, guard.Visible = "GuardEmblem", false
	Icons.draw(guard, "Block", 44)
	local track = HudKit.make("Frame", guard, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 8), Size = UDim2.fromOffset(90, 5),
		BackgroundColor3 = C.Ink, BackgroundTransparency = 0.2, BorderSizePixel = 0,
	}) :: Frame
	local fill = HudKit.make("Frame", track, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Gold, BorderSizePixel = 0,
	}) :: Frame
	return {
		Gui = gui, State = state, Text = text, Pop = pop, Until = 0, Live = 0, Priority = 0, WarnUntil = 0, OwnState = "Idle",
		Guard = guard, GuardStroke = guard:FindFirstChildOfClass("UIStroke") :: UIStroke, GuardFill = fill,
	}
end

local function shout(view: View, text: string, color: Color3, size: number?, priority: number?, hold: number?)
	local rank = priority or INFO
	if os.clock() < view.Until and rank < view.Priority then return end
	view.Priority = rank
	view.Text.Position = DuoBars.below(view.Gui) or UDim2.fromScale(0.5, 0.34) -- under the Twins' strip
	view.Text.Text, view.Text.TextColor3, view.Text.TextSize = text, color, size or 40
	view.Text.TextTransparency, view.Text.TextStrokeTransparency = 0, 0.1
	view.Until = os.clock() + (hold or CALLOUT_TIME)
	view.Pop.Scale = 1.35
	TweenService:Create(view.Pop, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

local function popup(view: View, entity: any?, text: string, color: Color3, size: number)
	local root = entity and entity.Root
	if not root or view.Live >= MAX_POPUPS then return end
	view.Live += 1
	if os.clock() < view.WarnUntil then size = math.floor(size * 0.7) end
	local start = Vector3.new(math.random(-12, 12) / 10, 2.6, 0)
	local billboard = HudKit.make("BillboardGui", view.Gui, {
		Name = "DamageNumber", Adornee = root, Size = UDim2.fromOffset(120, 40), StudsOffsetWorldSpace = start,
		AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 120, ResetOnSpawn = false,
	}) :: BillboardGui
	local label = HudKit.label(billboard, text, size, Enum.Font.GothamBlack, color, { Size = UDim2.fromScale(1, 1), TextStrokeTransparency = 0.15 })
	local info = TweenInfo.new(POPUP_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(billboard, info, { StudsOffsetWorldSpace = start + Vector3.new(0, 2.2, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(POPUP_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(POPUP_TIME, function()
		view.Live -= 1
		billboard:Destroy()
	end)
end

-- Whiff / evade / feint (ContactCues): grey popups over the foe, or a quiet centre call.
local function contact(view: View, event: any, own: number): boolean
	if event.Kind == "Evade" and event.Source == own and view.OwnState ~= "Dashing" then return false end -- F08: not while helpless
	local source, me = view.State:Get(event.Source), view.State:Get(own)
	local near = source and source.Root and me and me.Root and (source.Root.Position - me.Root.Position).Magnitude < 30
	local cue = Contact.describe(event.Kind, event.Source, event.Target, event.Value, own, near == true)
	if not cue then return false end
	local color = if cue.Tone == "Ivory" then C.Ivory else GREY
	if cue.Over then popup(view, view.State:Get(if cue.Over == "Source" then event.Source else event.Target), cue.Text, color, 17)
	else shout(view, cue.Text, color, 26) end
	return true
end

-- Returns the id of the opponent involved when the local player dealt or took the blow.
function Callouts.event(view: View, event: any): number?
	local own = view.State.LocalId
	if event.Kind == "Whiff" or event.Kind == "Evade" or event.Kind == "Feint" then
		return if contact(view, event, own) and event.Source == own and event.Target ~= own and event.Target ~= 0 then event.Target else nil
	end
	local mine, onMe = event.Source == own and event.Target ~= own, event.Target == own and event.Source ~= own
	if not mine and not onMe then return nil end
	local target = view.State:Get(event.Target)
	local amount = tostring(math.max(1, math.floor(event.Value + 0.5)))
	if DAMAGE_KINDS[event.Kind] then
		local special = event.Kind == "CounterHit" or event.Kind == "Deathblow"
		popup(view, target, amount, if onMe then C.Crimson elseif special then C.Gold else C.Ivory, if special then 30 else 24)
		if mine and event.Kind == "CounterHit" then shout(view, "COUNTER", C.Gold, 34) end
		if mine and event.Kind == "Deathblow" then shout(view, "DEATHBLOW", C.Crimson, 46, CRITICAL) end
	elseif event.Kind == "Block" then
		popup(view, target, if event.Value >= 1 then amount else "Blocked", GREY, 18)
		if onMe then shout(view, "BLOCKED", C.Ivory, 30) end
	elseif event.Kind == "DeflectSpark" then -- Source deflected Target's attack
		if mine then shout(view, "PARRY!", C.Gold, 46, CRITICAL) else shout(view, "DEFLECTED", GREY, 30) end
	elseif event.Kind == "GuardBreak" then
		if onMe then shout(view, "GUARD BROKEN", C.Crimson, 40, CRITICAL) else shout(view, "GUARD BREAK", C.Gold, 36) end
	elseif event.Kind == "StanceBreak" and mine then
		shout(view, "POSTURE BROKEN — DEATHBLOW!", C.Gold, 34, CRITICAL)
	elseif event.Kind == "KO" and mine then
		shout(view, "DEFEATED", C.Blossom, 34)
	end
	return if mine then event.Target else event.Source
end

-- A boss's perilous attack: the counter is named in the centre until impact, above everything else.
function Callouts.warn(view: View, counter: string, seconds: number, hint: string?)
	local hold = math.clamp(seconds, 0.4, 3)
	view.WarnUntil = os.clock() + hold
	shout(view, "▲ PERILOUS — " .. string.upper(counter) .. (if hint then "  ·  " .. hint else "") .. " ▲", C.Crimson, if hint then 30 else 38, WARNING, hold)
end

function Callouts.step(view: View, dt: number, snapshot: any?, hidden: boolean)
	if hidden then -- nothing from the fight survives into death, prologue or dialogue
		view.Until, view.WarnUntil, view.Priority = 0, 0, 0
		view.Text.TextTransparency, view.Text.TextStrokeTransparency = 1, 1
	end
	if os.clock() > view.Until and view.Text.TextTransparency < 1 then
		view.Text.TextTransparency = math.min(1, view.Text.TextTransparency + dt * 4)
		view.Text.TextStrokeTransparency = math.max(view.Text.TextTransparency, 0.1)
	end
	local state = if snapshot then snapshot.State else "Idle"; view.OwnState = state
	local guarding = snapshot ~= nil and not hidden and (snapshot.Blocking or state == "Blocking" or state == "Blockstun" or state == "Deflecting")
	view.Guard.Visible = guarding
	if guarding and snapshot then
		local p = math.clamp(snapshot.Posture / math.max(snapshot.PostureCapacity, 1), 0, 1)
		view.GuardFill.Size = UDim2.fromScale(p, 1)
		view.GuardFill.BackgroundColor3 = if p > 0.75 then C.Crimson else C.Gold
		view.GuardStroke.Color = if state == "Deflecting" then C.Gold elseif state == "Blockstun" then C.Ivory else C.Sakura
	end
end
return table.freeze(Callouts)
