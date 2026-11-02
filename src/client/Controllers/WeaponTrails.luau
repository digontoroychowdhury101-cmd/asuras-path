--!strict
-- Weapon trails. Every swing in view draws the path the server actually sweeps, as it happens. AsuraStrike names what the
-- server selected: a baked blade (StrikeTrajectories) with its scale, reach bonus and committed yaw, or the StrikeGeometry
-- path. A swing with a local clip grows along that blade on the clip's own clock, so the trail stays on the blade and stops
-- with it in hitstop; anything else grows on the strike's clock. Each point is placed once, in world space, by the root as
-- it stands when the point is emitted, as the server's sweep does, and stays where the blade passed. Before the record
-- arrives (a predicted swing) the root's facing and the model's scale stand in. An arc that misses a body really missed it.
-- A tier-1 gameplay cue: shaped by the move so it reads in grayscale and with reduced effects, and gone before the next
-- swing can start. The whole trajectory at once is a debug outline only, behind the Workspace attribute AsuraDebugReach.
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")
local Shared = game:GetService("ReplicatedStorage").AsurasPath
local Assets = require(Shared.Shared.PresentationAssets)
local Strike = require(Shared.Simulation.StrikeGeometry)
local Trajectories = require(Shared.Shared.StrikeTrajectories)
local Controller = {}
Controller.__index = Controller
local COLORS = { CalamityBoneCleaver=Color3.fromRGB(215,33,27), HeavenPiercingGuandao=Color3.fromRGB(74,222,255),
	TwinShadowSai=Color3.fromRGB(139,66,221), JadeCatalyst=Color3.fromRGB(83,241,208) }
local DEFAULT_COLOR = Color3.fromRGB(237, 192, 118)
local SAMPLES = 8
local FADE = 0.15 -- shorter than any recovery, so a fading arc never reads as the next attack
local RANGE = 80
local STALE = 0.5 -- records older than this (late replication, streaming in) are not drawn
local LIVE = 0.15 -- a record this long past its active frames belongs to an earlier swing, even of the same move

local function beam(carrier: BasePart, a: Attachment, b: Attachment, color: Color3, width: number)
	local item = Instance.new("Beam")
	item.Attachment0, item.Attachment1, item.FaceCamera, item.Segments = a, b, true, 1
	item.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	item.Transparency = NumberSequence.new(0.1, 0.35)
	item.LightEmission, item.Width0, item.Width1 = 0.6, width, width
	item.Parent = carrier
	TweenService:Create(item, TweenInfo.new(FADE), { Width0 = 0, Width1 = 0 }):Play()
end

local function carrierAt(folder: Instance, at: CFrame): BasePart
	local carrier = Instance.new("Part")
	carrier.Name, carrier.Anchored, carrier.Transparency, carrier.Size = "StrikeArc", true, 1, Vector3.one * 0.2
	carrier.CanCollide, carrier.CanQuery, carrier.CanTouch, carrier.CastShadow = false, false, false, false
	carrier.CFrame = at
	carrier.Parent = folder
	return carrier
end

local function point(carrier: BasePart, at: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Position = at
	a.Parent = carrier
	return a
end

-- The frame the server sweeps in this tick: the root as it stands, turned to the committed yaw (CharacterService.strikeFrame).
local function strikeFrame(root: CFrame, yaw: number?): CFrame
	if not yaw then
		return root
	end
	local look = root.LookVector
	return CFrame.new(root.Position) * CFrame.Angles(0, Strike.delta(Strike.yaw(look.X, look.Z) or 0, yaw), 0) * root.Rotation
end

-- One growing trail. `tipAt(index)` gives a world-space tip and hilt for each sample passed since the last call.
type Ribbon = { Key: string, Carrier: BasePart, Last: Attachment?, Drawn: number, Color: Color3, Width: number, Debug: boolean? }

local function grow(ribbon: Ribbon, upTo: number, tipAt: (number) -> (Vector3, Vector3))
	local carrier = ribbon.Carrier
	for index = ribbon.Drawn + 1, upTo do
		local tip, hilt = tipAt(index)
		local current = point(carrier, carrier.CFrame:PointToObjectSpace(tip))
		if ribbon.Last then
			beam(carrier, ribbon.Last, current, ribbon.Color, ribbon.Width)
		end
		if ribbon.Debug then
			beam(carrier, point(carrier, carrier.CFrame:PointToObjectSpace(hilt)), current, ribbon.Color, 0.06) -- the swept segment itself
		end
		ribbon.Last, ribbon.Drawn = current, index
	end
end

local function finish(ribbon: Ribbon)
	Debris:AddItem(ribbon.Carrier, FADE + 0.05)
end

-- Debug outline: the trajectory the server selected for this strike, whole, in its frame as the record is seen. A root
-- that moves afterward moves the sweep with it; the segments drawn as the trail grows show that.
local function draw(folder: Instance, root: BasePart, strike: Strike.Strike)
	local carrier = carrierAt(folder, strikeFrame(root.CFrame, strike.Yaw))
	carrier.Name = "StrikeDebug"
	local color = (COLORS :: any)[strike.Weapon] or DEFAULT_COLOR
	local data = if strike.Baked and strike.Move then Trajectories.forMove(strike.Move) else nil
	local shape = { Arc = strike.Arc, Reach = strike.Reach, Lunge = strike.Lunge }
	if data or strike.Arc > Strike.SlashArc then
		-- The tip's path plus the blade at each end.
		local count = if data then #data.Samples else SAMPLES + 1
		local function sample(index: number): (Vector3, Vector3)
			local progress = (index - 1) / math.max(count - 1, 1)
			local hx, hy, hz, tx, ty, tz
			if data then
				hx, hy, hz, tx, ty, tz = Trajectories.segment(data, progress, strike.Bonus, strike.Scale)
			else
				hx, hy, hz, tx, ty, tz = Strike.segment(shape, progress, 0)
			end
			return Vector3.new(tx, ty, tz), Vector3.new(hx, hy, hz)
		end
		local previous: Attachment? = nil
		for index = 1, count do
			local tip, hilt = sample(index)
			local current = point(carrier, tip)
			if previous then
				beam(carrier, previous, current, color, 0.32)
			end
			if index == 1 or index == count then
				beam(carrier, point(carrier, hilt), current, color, 0.08)
			end
			previous = current
		end
	else
		-- Thrust: one line from the hilt to full extension.
		local ax, ay, az, bx, by, bz = Strike.segment(shape, 1, 0)
		beam(carrier, point(carrier, Vector3.new(ax, ay, az)), point(carrier, Vector3.new(bx, by, bz)), color, 0.3)
	end
	Debris:AddItem(carrier, FADE + 0.05)
end

function Controller.new(state: any): any
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "AsuraStrikeArcs", Workspace
	return setmetatable({ State = state, Folder = folder, Seen = {} :: { [number]: string }, Ribbons = {} :: { [number]: Ribbon }, Generic = {} :: { [number]: any }, Strikes = {} :: { [number]: Strike.Strike }, Tick = 0, Animations = nil :: any }, Controller)
end

-- The trail of a baked swing, on its clip's clock. `strike` is the server's record of this swing, if it has arrived.
local function bakedTrail(self: any, id: number, root: BasePart, model: Model, data: any, clip: number, key: string, strike: Strike.Strike?, debug: boolean)
	local ribbon = self.Ribbons[id]
	if ribbon and ribbon.Key ~= key then
		finish(ribbon)
		ribbon = nil
		self.Ribbons[id] = nil
	end
	if clip < data.ClipContact then
		return
	end
	local samples = data.Samples
	if not ribbon then
		local weapon = string.split(key, "_")[1]
		ribbon = { Key = key, Carrier = carrierAt(self.Folder, root.CFrame), Last = nil, Drawn = 0,
			Color = (COLORS :: any)[weapon] or DEFAULT_COLOR, Width = 0.3, Debug = debug }
		self.Ribbons[id] = ribbon
	end
	if ribbon.Drawn >= #samples then
		return
	end
	local span = math.max(data.ClipActiveEnd - data.ClipContact, 1e-3)
	local reached = 1 + math.floor(math.clamp((clip - data.ClipContact) / span, 0, 1) * (#samples - 1) + 1e-6)
	local frame = strikeFrame(root.CFrame, if strike then strike.Yaw else nil)
	local bonus = if strike then strike.Bonus else 0
	local scale = if strike then strike.Scale else model:GetScale()
	grow(ribbon, reached, function(index: number): (Vector3, Vector3)
		local hx, hy, hz, tx, ty, tz = Trajectories.segment(data, (index - 1) / math.max(#samples - 1, 1), bonus, scale)
		return frame:PointToWorldSpace(Vector3.new(tx, ty, tz)), frame:PointToWorldSpace(Vector3.new(hx, hy, hz))
	end)
end

-- The trail of a swing with no local baked clip, on the server's strike clock along what it selected.
local function strikeTrail(self: any, id: number, root: BasePart, now: number)
	local entry = self.Generic[id]
	if not entry then
		return
	end
	local strike, ribbon = entry.Strike, entry.Ribbon
	local frame = strikeFrame(root.CFrame, strike.Yaw)
	local data = if strike.Baked and strike.Move then Trajectories.forMove(strike.Move) else nil
	local shape = { Arc = strike.Arc, Reach = strike.Reach, Lunge = strike.Lunge }
	if data or strike.Arc > Strike.SlashArc then
		local steps = if data then #data.Samples - 1 else SAMPLES
		local reached = 1 + math.floor(math.clamp((now - strike.Start) / math.max(strike.Active, 1e-3), 0, 1) * steps + 1e-6)
		grow(ribbon, reached, function(index: number): (Vector3, Vector3)
			local progress = (index - 1) / math.max(steps, 1)
			local hx, hy, hz, tx, ty, tz
			if data then
				hx, hy, hz, tx, ty, tz = Trajectories.segment(data, progress, strike.Bonus, strike.Scale)
			else
				hx, hy, hz, tx, ty, tz = Strike.segment(shape, progress, 0)
			end
			return frame:PointToWorldSpace(Vector3.new(tx, ty, tz)), frame:PointToWorldSpace(Vector3.new(hx, hy, hz))
		end)
		if reached > steps then
			finish(ribbon)
			self.Generic[id] = nil
		end
	elseif not ribbon.Last then
		local ax, ay, az, bx, by, bz = Strike.segment(shape, 1, 0)
		local carrier = ribbon.Carrier
		ribbon.Last = point(carrier, carrier.CFrame:PointToObjectSpace(frame:PointToWorldSpace(Vector3.new(ax, ay, az))))
		beam(carrier, ribbon.Last, point(carrier, carrier.CFrame:PointToObjectSpace(frame:PointToWorldSpace(Vector3.new(bx, by, bz)))), ribbon.Color, ribbon.Width)
		finish(ribbon)
		self.Generic[id] = nil
	end
end

function Controller.Update(self: any, dt: number)
	self.Tick += dt
	if self.Tick < 1 / 30 then
		return
	end
	self.Tick = 0
	local own = self.State:Own()
	if not own or not own.Root then
		return
	end
	local now, admitted = Workspace:GetServerTimeNow(), 0
	local debug = Workspace:GetAttribute("AsuraDebugReach") == true
	for id in self.Seen do
		if not self.State:Get(id) then
			self.Seen[id] = nil
			self.Generic[id] = nil
			self.Strikes[id] = nil
		end
	end
	for id, e in self.State.Entities do
		local root = e.Root
		if not root or (own.Root.Position - root.Position).Magnitude > RANGE then
			continue
		end
		admitted += 1
		if admitted > Assets.Limits.TrailActors then
			break
		end
		local fresh: Strike.Strike? = nil
		local record = e.Model:GetAttribute("AsuraStrike")
		if type(record) == "string" and record ~= self.Seen[id] then
			self.Seen[id] = record
			fresh = Strike.decode(record)
			self.Strikes[id] = fresh
		end
		local data, clip, key, move = nil, 0, "", nil
		if self.Animations then
			data, clip, key, move = self.Animations:Swing(e.Model)
		end
		-- The server's record of the swing on show, if it has one yet; its selection decides which path this is.
		local latest = self.Strikes[id]
		local strike = if latest and data and latest.Move == move and now - (latest.Start + latest.Active) < LIVE then latest else nil
		if strike and not strike.Baked then
			data = nil
		end
		if data then
			bakedTrail(self, id, root, e.Model, data, clip, key, strike, debug)
			if self.Generic[id] then
				finish(self.Generic[id].Ribbon)
				self.Generic[id] = nil
			end
		elseif self.Ribbons[id] then
			finish(self.Ribbons[id])
			self.Ribbons[id] = nil
		end
		if fresh and now - (fresh.Start + fresh.Active) < STALE then
			if debug then
				draw(self.Folder, root, fresh)
			end
			if not data then
				self.Generic[id] = { Strike = fresh, Ribbon = { Key = record, Carrier = carrierAt(self.Folder, CFrame.new(root.Position)),
					Last = nil, Drawn = 0, Color = (COLORS :: any)[fresh.Weapon] or DEFAULT_COLOR, Width = 0.32, Debug = debug } :: Ribbon }
			end
		end
		strikeTrail(self, id, root, now)
	end
end

function Controller.Destroy(self: any)
	self.Folder:Destroy()
	table.clear(self.Seen)
	table.clear(self.Ribbons)
	table.clear(self.Generic)
	table.clear(self.Strikes)
end

return Controller
