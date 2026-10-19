--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/ColosseumController
-- Colosseum matchmaking surface: the threshold panel (ranked queue, casual spar roster), incoming
-- challenge prompts, the duel countdown/clock and spectator notices. All authority stays on the
-- server; this controller only renders ColosseumIntent payloads and sends bounded requests.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local WorldState = require(script.Parent:WaitForChild("WorldStateController") :: ModuleScript)
local InputController = require(script.Parent:WaitForChild("InputController") :: ModuleScript)
local InterfaceController = require(script.Parent:WaitForChild("InterfaceController") :: ModuleScript)

type WorldState = WorldState.WorldState
type Cue = WorldState.Cue
type InputController = InputController.InputController
type Interface = InterfaceController.Interface

local Controller = {}
Controller.__index = Controller

local INK = Color3.fromRGB(14, 10, 9)
local IVORY = Color3.fromRGB(236, 226, 206)
local MUTED = Color3.fromRGB(150, 140, 126)
local EMBER = Color3.fromRGB(232, 132, 52)
local BLOOD = Color3.fromRGB(176, 22, 24)
local JADE = Color3.fromRGB(86, 168, 92)
local BORDER = Color3.fromRGB(120, 40, 32)

local TITLE_FONT = Enum.Font.Antique
local BODY_FONT = Enum.Font.Garamond
local NUMBER_FONT = Enum.Font.GothamMedium

local SPECTATOR_RADIUS = 110
local MAX_ROSTER = 24

local REASONS: { [string]: string } = {
	StepOnThreshold = "Stand upon the ember threshold.",
	AlreadyQueued = "You already await a ranked rival.",
	HighLatency = "Your connection is too slow for ranked duels.",
	RecoveryPending = "A previous duel is still being settled. Try again shortly.",
	AlreadyAssigned = "You have already been matched.",
	ProfileBusy = "Your record is busy. Try again.",
	RankedClosed = "The ranked league has not opened yet.",
	ColosseumClosed = "The Colosseum is closing.",
	InDuel = "Already in a duel.",
	Fallen = "Rise before you duel.",
	InBossFight = "The fog binds you to a fight.",
	EnemiesNearby = "Enemies still hunt you.",
	Unavailable = "Unavailable right now.",
	TargetInDuel = "They are already dueling.",
	TargetFallen = "They have fallen.",
	TargetInBossFight = "They are bound in a boss fight.",
	TargetEnemiesNearby = "They are being hunted.",
	TargetUnavailable = "They are unavailable.",
	TargetColosseumClosed = "The Colosseum is closing.",
	ChallengeExpired = "The challenge has lapsed.",
	ChallengeDeclined = "Your challenge was declined.",
	RingsOccupied = "Every ring is occupied. Try again soon.",
	RingOccupied = "The ring is occupied.",
	StartRefused = "The duel could not begin.",
	JournalUnavailable = "The ranked ledger is unavailable. Try again.",
	AlreadyChallenged = "They have already challenged you.",
	InvalidTarget = "Choose another opponent.",
}

local STATUS_TEXT: { [string]: string } = {
	Ready = "Ready",
	InDuel = "Dueling",
	Fallen = "Fallen",
	InBossFight = "In a boss fight",
	EnemiesNearby = "Hunted",
	Unavailable = "Away",
	ColosseumClosed = "Away",
}

type Row = { Frame: Frame, Name: TextLabel, Detail: TextLabel, Button: TextButton, Id: number }

type Fields = {
	State: WorldState,
	Input: InputController,
	Interface: Interface,
	Remote: RemoteEvent,
	Player: Player,
	Gui: ScreenGui,
	Panel: Frame,
	PanelTitle: TextLabel,
	PanelGlyph: TextLabel,
	PanelStatus: TextLabel,
	RankedButton: TextButton,
	RankedDetail: TextLabel,
	Roster: ScrollingFrame,
	RosterEmpty: TextLabel,
	Rows: { Row },
	Prompt: Frame,
	PromptText: TextLabel,
	PromptTimer: TextLabel,
	MatchFrame: Frame,
	MatchNames: TextLabel,
	MatchClock: TextLabel,
	MatchMode: TextLabel,
	Countdown: TextLabel,
	PanelOpen: boolean,
	MenuHeld: boolean,
	RankedOpen: boolean,
	Queued: boolean,
	QueuedAt: number,
	ChallengeId: string?,
	ChallengeExpires: number,
	MatchId: string?,
	MatchStarts: number,
	MatchEnds: number,
	LastCount: number,
	Connections: { RBXScriptConnection },
	Disconnects: { () -> () },
}

export type ColosseumController = typeof(setmetatable({} :: Fields, Controller))

-------------------------------------------------------------------------------------------------
-- Instance helpers
-------------------------------------------------------------------------------------------------

local function make<T>(className: string, parent: Instance?, properties: { [string]: any }): T
	local instance = Instance.new(className :: any)
	for key, value in properties do
		(instance :: any)[key] = value
	end
	if parent then
		instance.Parent = parent
	end
	return instance :: any
end

local function label(parent: Instance, text: string, size: number, font: Enum.Font, color: Color3, properties: { [string]: any }?): TextLabel
	local result = make("TextLabel", parent, {
		Text = text,
		TextSize = size,
		Font = font,
		TextColor3 = color,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		TextStrokeTransparency = 0.6,
		TextStrokeColor3 = INK,
		TextXAlignment = Enum.TextXAlignment.Left,
	}) :: TextLabel
	if properties then
		for key, value in properties do
			(result :: any)[key] = value
		end
	end
	return result
end

local function decorate(frame: GuiObject, radius: number, thickness: number)
	make("UICorner", frame, { CornerRadius = UDim.new(0, radius) })
	make("UIStroke", frame, { Color = BORDER, Thickness = thickness, Transparency = 0.1 })
end

local function button(parent: Instance, text: string, size: UDim2, callback: () -> ()): TextButton
	local result = make("TextButton", parent, {
		Text = text,
		Font = BODY_FONT,
		TextSize = 20,
		TextColor3 = IVORY,
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.2,
		AutoButtonColor = true,
		Size = size,
		BorderSizePixel = 0,
		Selectable = true,
	}) :: TextButton
	decorate(result, 4, 1)
	result.Activated:Connect(callback)
	return result
end

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function clockText(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

-------------------------------------------------------------------------------------------------
-- Construction
-------------------------------------------------------------------------------------------------

function Controller.new(state: WorldState, input: InputController, ui: Interface, net: Instance): ColosseumController
	local player = Players.LocalPlayer
	local remote = net:WaitForChild("ColosseumIntent") :: RemoteEvent
	local gui = make("ScreenGui", player:WaitForChild("PlayerGui"), {
		Name = "AsuraColosseum",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 11,
	}) :: ScreenGui

	-- Threshold panel
	local panel = make("Frame", gui, {
		Name = "ColosseumPanel",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -60, 0.5, 0),
		Size = UDim2.fromOffset(400, 500),
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.12,
		Visible = false,
	}) :: Frame
	decorate(panel, 6, 2)
	make("UIPadding", panel, {
		PaddingLeft = UDim.new(0, 18),
		PaddingRight = UDim.new(0, 18),
		PaddingTop = UDim.new(0, 14),
		PaddingBottom = UDim.new(0, 14),
	})
	local panelTitle = label(panel, "Colosseum", 26, TITLE_FONT, IVORY, {
		Size = UDim2.new(1, -40, 0, 32),
		TextWrapped = true,
		TextScaled = true,
	})
	local panelGlyph = label(panel, "", 30, TITLE_FONT, EMBER, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(36, 32),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local panelStatus = label(panel, "", 16, BODY_FONT, MUTED, {
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 20),
	})
	label(panel, "Ranked Normalized", 20, TITLE_FONT, EMBER, {
		Position = UDim2.fromOffset(0, 66),
		Size = UDim2.new(1, 0, 0, 24),
	})
	local rankedDetail = label(panel, "", 15, BODY_FONT, MUTED, {
		Position = UDim2.fromOffset(0, 90),
		Size = UDim2.new(1, 0, 0, 34),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	local rankedButton: TextButton = nil :: any -- built below once `self` exists

	label(panel, "Open Arena", 20, TITLE_FONT, EMBER, {
		Position = UDim2.fromOffset(0, 184),
		Size = UDim2.new(1, 0, 0, 24),
	})
	local roster = make("ScrollingFrame", panel, {
		Name = "Roster",
		Position = UDim2.fromOffset(0, 212),
		Size = UDim2.new(1, 0, 1, -270),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = BORDER,
	}) :: ScrollingFrame
	make("UIListLayout", roster, { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
	local rosterEmpty = label(roster, "No other warriors walk these lands.", 16, BODY_FONT, MUTED, {
		Size = UDim2.new(1, 0, 0, 24),
		LayoutOrder = 0,
	})

	-- Incoming challenge prompt
	local prompt = make("Frame", gui, {
		Name = "ChallengePrompt",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 120),
		Size = UDim2.fromOffset(460, 132),
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.1,
		Visible = false,
	}) :: Frame
	decorate(prompt, 6, 2)
	make("UIPadding", prompt, {
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 16),
		PaddingTop = UDim.new(0, 12),
	})
	local promptText = label(prompt, "", 20, BODY_FONT, IVORY, {
		Size = UDim2.new(1, -60, 0, 52),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	local promptTimer = label(prompt, "", 22, NUMBER_FONT, EMBER, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(56, 28),
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	-- Duel clock
	local matchFrame = make("Frame", gui, {
		Name = "DuelClock",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 24),
		Size = UDim2.fromOffset(520, 76),
		BackgroundTransparency = 1,
		Visible = false,
	}) :: Frame
	local matchMode = label(matchFrame, "", 16, TITLE_FONT, EMBER, {
		Size = UDim2.new(1, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local matchNames = label(matchFrame, "", 22, TITLE_FONT, IVORY, {
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, 0, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local matchClock = label(matchFrame, "", 26, NUMBER_FONT, IVORY, {
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local countdown = label(gui, "", 120, TITLE_FONT, IVORY, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(600, 140),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.3,
		TextTransparency = 1,
	})

	local fields: Fields = {
		State = state,
		Input = input,
		Interface = ui,
		Remote = remote,
		Player = player,
		Gui = gui,
		Panel = panel,
		PanelTitle = panelTitle,
		PanelGlyph = panelGlyph,
		PanelStatus = panelStatus,
		RankedButton = rankedButton,
		RankedDetail = rankedDetail,
		Roster = roster,
		RosterEmpty = rosterEmpty,
		Rows = {},
		Prompt = prompt,
		PromptText = promptText,
		PromptTimer = promptTimer,
		MatchFrame = matchFrame,
		MatchNames = matchNames,
		MatchClock = matchClock,
		MatchMode = matchMode,
		Countdown = countdown,
		PanelOpen = false,
		MenuHeld = false,
		RankedOpen = false,
		Queued = false,
		QueuedAt = 0,
		ChallengeId = nil,
		ChallengeExpires = 0,
		MatchId = nil,
		MatchStarts = 0,
		MatchEnds = 0,
		LastCount = -1,
		Connections = {},
		Disconnects = {},
	}
	local self = setmetatable(fields, Controller)

	self.RankedButton = button(panel, "Enter the Ranked Queue", UDim2.new(1, 0, 0, 42), function()
		if not self.RankedOpen then
			self.Interface:ShowToast(REASONS.RankedClosed)
			return
		end
		self:Send({ action = if self.Queued then "Dequeue" else "Enqueue" })
	end)
	self.RankedButton.Position = UDim2.fromOffset(0, 130)
	button(panel, "Step Away", UDim2.new(1, 0, 0, 40), function()
		self:Send({ action = "Dismiss" })
		self:ClosePanel()
	end).Position = UDim2.new(0, 0, 1, -44)

	local accept = button(prompt, "Accept", UDim2.new(0.5, -6, 0, 40), function()
		self:Respond(true)
	end)
	accept.Position = UDim2.fromOffset(0, 70)
	accept.TextColor3 = JADE
	local decline = button(prompt, "Decline", UDim2.new(0.5, -6, 0, 40), function()
		self:Respond(false)
	end)
	decline.Position = UDim2.new(0.5, 6, 0, 70)

	table.insert(self.Connections, remote.OnClientEvent:Connect(function(payload: any)
		if type(payload) == "table" and type(payload.action) == "string" then
			self:Receive(payload)
		end
	end))
	table.insert(self.Disconnects, state:OnCue(function(cue: Cue)
		self:OnCue(cue)
	end))
	return self
end

-------------------------------------------------------------------------------------------------
-- Requests
-------------------------------------------------------------------------------------------------

function Controller.Send(self: ColosseumController, payload: { [string]: any })
	self.Remote:FireServer(payload)
end

function Controller.Respond(self: ColosseumController, accept: boolean)
	local id = self.ChallengeId
	if id then
		self:Send({ action = "Respond", challenge = id, accept = accept })
	end
	self.ChallengeId = nil
	self.Prompt.Visible = false
	self:HoldMenu(self.PanelOpen)
end

function Controller.Toast(self: ColosseumController, reason: any)
	local text = if type(reason) == "string" then REASONS[reason] or reason else nil
	if text then
		self.Interface:ShowToast(text)
	end
end

-------------------------------------------------------------------------------------------------
-- Panel
-------------------------------------------------------------------------------------------------

function Controller.HoldMenu(self: ColosseumController, held: boolean)
	if self.MenuHeld ~= held then
		self.MenuHeld = held
		self.Input:SetMenu(held)
	end
end

function Controller.OpenPanel(self: ColosseumController)
	if self.MatchId then
		return
	end
	self.PanelOpen = true
	self.Panel.Visible = true
	self:HoldMenu(true)
end

function Controller.ClosePanel(self: ColosseumController)
	self.PanelOpen = false
	self.Panel.Visible = false
	self:HoldMenu(self.Prompt.Visible)
end

function Controller.RefreshRanked(self: ColosseumController)
	local rankedButton = self.RankedButton
	if not self.RankedOpen then
		rankedButton.Text = "Ranked League Sealed"
		rankedButton.TextColor3 = MUTED
	elseif self.Queued then
		rankedButton.Text = "Leave the Queue  ·  " .. clockText(os.clock() - self.QueuedAt)
		rankedButton.TextColor3 = EMBER
	else
		rankedButton.Text = "Enter the Ranked Queue"
		rankedButton.TextColor3 = IVORY
	end
end

function Controller.Populate(self: ColosseumController, payload: any)
	self.PanelTitle.Text = tostring(payload.name or "Colosseum")
	self.PanelGlyph.Text = tostring(payload.glyph or "")
	self.RankedOpen = payload.rankedOpen == true
	local queued = payload.queued == true
	if queued and not self.Queued then
		self.QueuedAt = os.clock()
	end
	self.Queued = queued
	local ping = tonumber(payload.ping) or 0
	local limit = tonumber(payload.pingLimit) or 0
	local elo = tonumber(payload.elo)
	self.PanelStatus.Text = string.format(
		"%sLatency %d ms%s",
		if elo then string.format("%s · %d  ·  ", tostring(payload.rank or "Unranked"),elo) else "",
		ping,
		if payload.occupied == true then "  ·  Ring in use" else ""
	)
	self.PanelStatus.TextColor3 = if limit > 0 and ping > limit then BLOOD else MUTED
	self.RankedDetail.Text = string.format(
		"Equal attributes, +0 steel and no infusions · Soul Level %d. Latency under %d ms.",
		tonumber(payload.level) or 1,
		limit
	)
	self:RefreshRanked()

	local players = if type(payload.players) == "table" then payload.players else {}
	local count = math.min(#players, MAX_ROSTER)
	self.RosterEmpty.Visible = count == 0
	for index = 1, count do
		local entry = players[index]
		local row = self.Rows[index]
		if not row then
			local frame = make("Frame", self.Roster, {
				Size = UDim2.new(1, -8, 0, 44),
				BackgroundColor3 = INK,
				BackgroundTransparency = 0.4,
				LayoutOrder = index,
			}) :: Frame
			make("UICorner", frame, { CornerRadius = UDim.new(0, 4) })
			local nameLabel = label(frame, "", 18, BODY_FONT, IVORY, {
				Position = UDim2.fromOffset(10, 2),
				Size = UDim2.new(1, -120, 0, 22),
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
			local detail = label(frame, "", 14, BODY_FONT, MUTED, {
				Position = UDim2.fromOffset(10, 22),
				Size = UDim2.new(1, -120, 0, 18),
			})
			local created: Row = { Frame = frame, Name = nameLabel, Detail = detail, Button = nil :: any, Id = 0 }
			created.Button = button(frame, "Challenge", UDim2.fromOffset(100, 32), function()
				if created.Id ~= 0 then
					self:Send({ action = "Challenge", target = created.Id })
				end
			end)
			created.Button.AnchorPoint = Vector2.new(1, 0.5)
			created.Button.Position = UDim2.new(1, -6, 0.5, 0)
			created.Button.TextSize = 16
			row = created
			self.Rows[index] = created
		end
		local ready = entry.status == "Ready"
		row.Id = tonumber(entry.id) or 0
		row.Name.Text = tostring(entry.name or "?")
		row.Detail.Text = string.format("Soul Level %d  ·  %s", tonumber(entry.level) or 1, STATUS_TEXT[tostring(entry.status)] or "Away")
		row.Detail.TextColor3 = if ready then JADE else MUTED
		row.Button.Visible = ready
		row.Frame.Visible = true
	end
	for index = count + 1, #self.Rows do
		self.Rows[index].Frame.Visible = false
		self.Rows[index].Id = 0
	end
end

-------------------------------------------------------------------------------------------------
-- Duel presentation
-------------------------------------------------------------------------------------------------

function Controller.Pulse(self: ColosseumController, text: string, color: Color3)
	local countdown = self.Countdown
	countdown.Text = text
	countdown.TextColor3 = color
	countdown.TextTransparency = 0
	countdown.TextStrokeTransparency = 0.3
	countdown.Size = UDim2.fromOffset(660, 160)
	TweenService:Create(countdown, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Size = UDim2.fromOffset(600, 140),
	}):Play()
end

function Controller.BeginMatch(self: ColosseumController, payload: any)
	self.Prompt.Visible = false
	self.ChallengeId = nil
	self:ClosePanel()
	self.Queued = false
	self.MatchId = tostring(payload.matchId)
	self.MatchStarts = tonumber(payload.starts) or serverNow()
	self.MatchEnds = tonumber(payload.ends) or (self.MatchStarts + 120)
	self.LastCount = -1
	local ranked = payload.mode == "Ranked1v1"
	self.MatchMode.Text = if ranked then "RANKED DUEL" else "CASUAL SPAR"
	local opponent = tostring(payload.opponentName or "Rival")
	if ranked and payload.opponentElo then
		opponent ..= string.format("  (%d)", tonumber(payload.opponentElo) or 0)
	end
	self.MatchNames.Text = string.format("%s   VS   %s", self.Player.DisplayName, opponent)
	self.MatchClock.Text = ""
	self.MatchFrame.Visible = true
	self.Interface:ShowBanner(string.upper(tostring(payload.name or "The Colosseum")), if ranked
		then string.format("Balanced to Soul Level %d", tonumber(payload.level) or 1)
		else "A spar between warriors", 2.6)
end

function Controller.EndMatch(self: ColosseumController, payload: any)
	self.MatchId = nil
	self.MatchFrame.Visible = false
	local outcome = tostring(payload.outcome or "")
	local opponent = tostring(payload.opponentName or "your rival")
	local delta = tonumber(payload.eloDelta)
	local subtitle = if delta then string.format("Rating %s%d", if delta >= 0 then "+" else "", delta) else ""
	if payload.reason == "Forfeit" then
		subtitle = (if subtitle ~= "" then subtitle .. "  ·  " else "") .. "by forfeit"
	elseif payload.reason == "Time" then
		subtitle = (if subtitle ~= "" then subtitle .. "  ·  " else "") .. "on time"
	end
	if outcome == "Win" then
		self.Interface:ShowBanner("VICTORY", if subtitle ~= "" then subtitle else "over " .. opponent, 4)
	elseif outcome == "Loss" then
		self.Interface:ShowBanner("DEFEAT", if subtitle ~= "" then subtitle else "to " .. opponent, 4)
	elseif outcome == "Draw" then
		self.Interface:ShowBanner("STALEMATE", subtitle, 4)
	else
		self.Interface:ShowBanner("DUEL ABANDONED", "", 3)
	end
end

-------------------------------------------------------------------------------------------------
-- Network
-------------------------------------------------------------------------------------------------

function Controller.Receive(self: ColosseumController, payload: any)
	local action: string = payload.action
	if action == "Open" then
		self:Populate(payload)
		self:OpenPanel()
	elseif action == "Roster" then
		self:Populate(payload)
	elseif action == "Close" then
		self:ClosePanel()
	elseif action == "Queue" then
		local queued = payload.queued == true
		if queued and not self.Queued then
			self.QueuedAt = os.clock()
		end
		self.Queued = queued
		if type(payload.rankedOpen) == "boolean" then
			self.RankedOpen = payload.rankedOpen
		end
		self:RefreshRanked()
		if payload.ok ~= true then
			self:Toast(payload.err)
		elseif queued then
			self.Interface:ShowToast("You await a worthy rival.")
		end
	elseif action == "Challenge" then
		self.ChallengeId = tostring(payload.challenge)
		self.ChallengeExpires = tonumber(payload.expires) or (serverNow() + 15)
		self.PromptText.Text = string.format("%s challenges you to a spar at %s.", tostring(payload.fromName or "A warrior"), tostring(payload.name or "the Colosseum"))
		self.Prompt.Visible = true
		self:HoldMenu(true)
	elseif action == "ChallengeWithdrawn" then
		if self.ChallengeId == payload.challenge then
			self.ChallengeId = nil
			self.Prompt.Visible = false
			if not self.PanelOpen then
				self:HoldMenu(false)
			end
		end
	elseif action == "ChallengeResult" then
		if payload.ok == true and payload.sent == true then
			self.Interface:ShowToast(string.format("Challenge sent to %s.", tostring(payload.name or "your rival")))
		elseif payload.ok ~= true then
			self:Toast(payload.err)
		end
	elseif action == "MatchFound" then
		self:BeginMatch(payload)
	elseif action == "MatchState" then
		if type(payload.ends) == "number" then
			self.MatchEnds = payload.ends
		end
	elseif action == "MatchResult" then
		self:EndMatch(payload)
	end
end

function Controller.OnCue(self: ColosseumController, cue: Cue)
	if cue.Kind ~= "ColosseumBegin" and cue.Kind ~= "ColosseumResult" then
		return
	end
	local data = cue.Data
	local own = self.State.LocalId
	if data.a == own or data.b == own then
		return
	end
	local root = self.State:Own()
	local part = root and root.Root
	local x, z = tonumber(data.x), tonumber(data.z)
	if not part or not x or not z or (Vector3.new(x, part.Position.Y, z) - part.Position).Magnitude > SPECTATOR_RADIUS then
		return
	end
	if cue.Kind == "ColosseumBegin" then
		self.Interface:ShowToast(string.format("%s faces %s in %s.", tostring(data.an or "?"), tostring(data.bn or "?"), tostring(data.name or "the ring")))
	elseif data.draw == true then
		self.Interface:ShowToast(string.format("%s and %s fight to a stalemate.", tostring(data.an or "?"), tostring(data.bn or "?")))
	elseif data.wn then
		self.Interface:ShowToast(string.format("%s prevails in %s.", tostring(data.wn), tostring(data.name or "the ring")))
	end
end

-------------------------------------------------------------------------------------------------
-- Frame
-------------------------------------------------------------------------------------------------

function Controller.Update(self: ColosseumController, _dt: number)
	local current = serverNow()
	if self.Prompt.Visible then
		local remaining = self.ChallengeExpires - current
		if remaining <= 0 then
			self.ChallengeId = nil
			self.Prompt.Visible = false
			if not self.PanelOpen then
				self:HoldMenu(false)
			end
		else
			self.PromptTimer.Text = tostring(math.ceil(remaining))
		end
	end
	if self.PanelOpen and self.Queued then
		self:RefreshRanked()
	end
	if self.MatchId then
		if current < self.MatchStarts then
			local count = math.ceil(self.MatchStarts - current)
			if count ~= self.LastCount then
				self.LastCount = count
				self:Pulse(tostring(count), IVORY)
			end
			self.MatchClock.Text = clockText(self.MatchEnds - self.MatchStarts)
		else
			if self.LastCount ~= 0 then
				self.LastCount = 0
				self:Pulse("FIGHT!", BLOOD)
			end
			local remaining = self.MatchEnds - current
			self.MatchClock.Text = clockText(remaining)
			self.MatchClock.TextColor3 = if remaining <= 10 then BLOOD else IVORY
		end
	end
end

function Controller.Destroy(self: ColosseumController)
	for _, disconnect in self.Disconnects do
		disconnect()
	end
	table.clear(self.Disconnects)
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	table.clear(self.Connections)
	self:HoldMenu(false)
	self.Gui:Destroy()
end

return Controller
