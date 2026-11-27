--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/VitalsTags
-- Explains the three health layers on the vitals plate with shape, motion and short words, not
-- colour alone:
--   ↺ recoverable damage: during the Blood Rally window it pulses with a countdown ("strike back");
--     afterwards the flask restores it first.
--   ▼ lowered ceiling: a notch on the bar where max health currently stops, "rest restores".
local HudKit = require(script.Parent:WaitForChild("HudKit") :: ModuleScript)
local C = require(script.Parent:WaitForChild("CombatHudStyle") :: ModuleScript)

local Tags = {}

Tags.Health = table.freeze({ X = 38, Y = 32, W = 404, H = 16 })
Tags.StatusY = 59

export type View = { Notch: Frame, Rally: TextLabel, RallyScale: UIScale, Ceiling: TextLabel }

function Tags.build(frame: Frame): View
	local h = Tags.Health
	local notch = HudKit.make("Frame", frame, {
		Name = "CeilingNotch", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(h.X + h.W, h.Y + h.H / 2),
		Size = UDim2.fromOffset(3, h.H + 10), BackgroundColor3 = C.Ivory, BorderSizePixel = 0, ZIndex = 6, Visible = false,
	}) :: Frame
	HudKit.make("Frame", notch, { Position = UDim2.fromScale(0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(6, 6), Rotation = 45, BackgroundColor3 = C.Ivory, BorderSizePixel = 0, ZIndex = 6 })
	local rally = HudKit.label(frame, "", 13, Enum.Font.GothamBold, C.Gold, {
		Name = "RallyTag", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(h.X, Tags.StatusY), Size = UDim2.fromOffset(184, 15),
		TextXAlignment = Enum.TextXAlignment.Left, TextStrokeTransparency = 0.3, Visible = false,
	})
	local rallyScale = HudKit.make("UIScale", rally, {}) :: UIScale
	local ceiling = HudKit.label(frame, "", 12, Enum.Font.GothamMedium, C.Ivory, {
		Name = "CeilingTag", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromOffset(h.X + h.W, Tags.StatusY), Size = UDim2.fromOffset(186, 15),
		TextXAlignment = Enum.TextXAlignment.Right, TextStrokeTransparency = 0.3, Visible = false,
	})
	return { Notch = notch, Rally = rally, RallyScale = rallyScale, Ceiling = ceiling }
end

-- Pure text rules (tested in tools/test_hud_layout.luau).
function Tags.texts(s: { MaxHP: number, ActiveHP: number, RecoverableHP: number, PermanentDeficit: number, RallyActive: boolean, RallyRemaining: number }): (string, string)
	local recoverable = math.floor(s.RecoverableHP + 0.5)
	local rally = ""
	if recoverable > 0 then
		rally = if s.RallyActive then string.format("RALLY %.1fs · strike back", math.max(s.RallyRemaining, 0))
			else string.format("+%d recoverable · flask", recoverable)
	end
	local lost = math.floor(s.PermanentDeficit + 0.5)
	local ceiling = if lost > 0 then string.format("▼ max −%d · rest restores", lost) else ""
	return rally, ceiling
end

function Tags.update(view: View, s: any, clock: number)
	local rally, ceiling = Tags.texts(s)
	view.Rally.Text, view.Rally.Visible = rally, rally ~= ""
	view.Rally.TextColor3 = if s.RallyActive then C.Gold else C.Bone
	view.RallyScale.Scale = if s.RallyActive then 1 + 0.08 * math.abs(math.sin(clock * 6)) else 1
	view.Ceiling.Text, view.Ceiling.Visible = ceiling, ceiling ~= ""
	local maxHP = math.max(s.MaxHP, 1)
	local fraction = math.clamp((maxHP - s.PermanentDeficit) / maxHP, 0, 1)
	view.Notch.Visible = ceiling ~= ""
	view.Notch.Position = UDim2.fromOffset(Tags.Health.X + Tags.Health.W * fraction, Tags.Health.Y + Tags.Health.H / 2)
end

-- Flask charges as shapes: filled ◆ per charge, hollow ◇ per spent charge.
function Tags.flask(charges: number, maximum: number): string
	local total = math.max(maximum, charges)
	if total <= 0 then return "FLASK —" end
	return "FLASK " .. string.rep("◆", charges) .. string.rep("◇", total - charges)
end

return table.freeze(Tags)
