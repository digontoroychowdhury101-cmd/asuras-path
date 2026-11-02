--!strict
-- Weapon trails. Every swing in view draws the path the server actually sweeps, as it happens: a swing with a baked
-- blade (StrikeTrajectories) grows along its samples on the clip's own clock, so the trail stays on the blade and stops
-- with it in hitstop; any other (a clip without a bake, a boss look) grows along the StrikeGeometry path the server
-- publishes in AsuraStrike, on the strike's clock. An arc that misses a body really missed it. A tier-1 gameplay
-- cue: shaped by the move so it reads in grayscale and with reduced effects, and gone before the next swing can start.
-- The whole shape at once is a debug outline only, behind the Workspace attribute AsuraDebugReach.
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")
local Shared = game:GetService("ReplicatedStorage").AsurasPath
local Assets = require(Shared.Shared.PresentationAssets)
local Strike = require(Shared.Simulation.StrikeGeometry)
local Controller = {}
Controller.__index = Controller
local COLORS = { CalamityBoneCleaver=Color3.fromRGB(215,33,27), HeavenPiercingGuandao=Color3.fromRGB(74,222,255),
	TwinShadowSai=Color3.fromRGB(139,66,221), JadeCatalyst=Color3.fromRGB(83,241,208) }
local DEFAULT_COLOR = Color3.fromRGB(237, 192, 118)
local SAMPLES = 8
local FADE = 0.15 -- shorter than any recovery, so a fading arc never reads as the next attack
local RANGE = 80
local STALE = 0.5 -- records older than this (late replication, streaming in) are not drawn

local function beam(carrier: BasePart, a: Attachment, b: Attachment, color: Color3, width: number)
	local item = Instance.new("Beam")
	item.Attachment0, item.Attachment1, item.FaceCamera, item.Segments = a, b, true, 1
	item.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	item.Transparency = NumberSequence.new(0.1, 0.35)
	item.LightEmission, item.Width0, item.Width1 = 0.6, width, width
	item.Parent = carrier
	TweenService:Create(item, TweenInfo.new(FADE), { Width0 = 0, Width1 = 0 }):Play()
end

local function node(carrier: BasePart, x: number, z: number): Attachment
	local a = Instance.new("Attachment")
	a.Position = Vector3.new(x, 0.6, z)
	a.Parent = carrier
	return a
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

-- One growing trail: `Sample(index)` gives a root-space tip, `Reached` how many samples have been passed.
type Ribbon = { Key: string, Carrier: BasePart, Last: Attachment?, Drawn: number, Color: Color3, Width: number }

local function grow(ribbon: Ribbon, upTo: number, tipAt: (number) -> Vector3)
	for index = ribbon.Drawn + 1, upTo do
		local current = point(ribbon.Carrier, tipAt(index))
		if ribbon.Last then
			beam(ribbon.Carrier, ribbon.Last, current, ribbon.Color, ribbon.Width)
		end
		ribbon.Last, ribbon.Drawn = current, index
	end
end

local function finish(ribbon: Ribbon)
	Debris:AddItem(ribbon.Carrier, FADE + 0.05)
end

-- Debug outline: the swept shape for one strike around `root`, at the committed yaw, whole.
local function draw(folder: Instance, root: BasePart, strike: Strike.Strike)
	local carrier = carrierAt(folder, CFrame.new(root.Position) * CFrame.Angles(0, strike.Yaw, 0))
	local color = (COLORS :: any)[strike.Weapon] or DEFAULT_COLOR
	local shape = { Arc = strike.Arc, Reach = strike.Reach, Lunge = strike.Lunge }
	if strike.Arc > Strike.SlashArc then
		-- Slash: the outer edge of the fan plus its two radial edges.
		local tips = Strike.sweep(shape, 0, SAMPLES)
		local hx, _, hz = Strike.segment(shape, 0, 0)
		local ex, _, ez = Strike.segment(shape, 1, 0)
		local previous = node(carrier, tips[1][1], tips[1][2])
		beam(carrier, node(carrier, hx, hz), previous, color, 0.08)
		for i = 2, #tips do
			local current = node(carrier, tips[i][1], tips[i][2])
			beam(carrier, previous, current, color, 0.32)
			previous = current
		end
		beam(carrier, node(carrier, ex, ez), previous, color, 0.08)
	else
		-- Thrust: one line from the hilt to full extension.
		local ax, _, az, bx, _, bz = Strike.segment(shape, 1, 0)
		beam(carrier, node(carrier, ax, az), node(carrier, bx, bz), color, 0.3)
	end
	Debris:AddItem(carrier, FADE + 0.05)
end

function Controller.new(state: any): any
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "AsuraStrikeArcs", Workspace
	return setmetatable({ State = state, Folder = folder, Seen = {} :: { [number]: string }, Ribbons = {} :: { [number]: Ribbon }, Generic = {} :: { [number]: any }, Tick = 0, Animations = nil :: any }, Controller)
end

-- The trail of a baked swing, on its clip's clock.
local function bakedTrail(self: any, id: number, root: BasePart, data: any, clip: number, key: string)
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
			Color = (COLORS :: any)[weapon] or DEFAULT_COLOR, Width = 0.3 }
		self.Ribbons[id] = ribbon
	end
	if ribbon.Drawn >= #samples then
		return
	end
	local span = math.max(data.ClipActiveEnd - data.ClipContact, 1e-3)
	local reached = 1 + math.floor(math.clamp((clip - data.ClipContact) / span, 0, 1) * (#samples - 1) + 1e-6)
	grow(ribbon, reached, function(index: number): Vector3
		local s = samples[index]
		return Vector3.new(s[4], s[5], s[6])
	end)
end

-- The trail of a swing with no bake, on the server's strike clock along the shape it published.
local function genericTrail(self: any, id: number, root: BasePart, now: number)
	local entry = self.Generic[id]
	if not entry then
		return
	end
	local strike, ribbon = entry.Strike, entry.Ribbon
	local shape = { Arc = strike.Arc, Reach = strike.Reach, Lunge = strike.Lunge }
	if strike.Arc > Strike.SlashArc then
		local reached = 1 + math.floor(math.clamp((now - strike.Start) / math.max(strike.Active, 1e-3), 0, 1) * SAMPLES + 1e-6)
		grow(ribbon, reached, function(index: number): Vector3
			local _, y, _, x, _, z = Strike.segment(shape, (index - 1) / SAMPLES, 0)
			return Vector3.new(x, y, z)
		end)
		if reached > SAMPLES then
			finish(ribbon)
			self.Generic[id] = nil
		end
	else
		local ax, ay, az, bx, by, bz = Strike.segment(shape, 1, 0)
		if not ribbon.Last then
			ribbon.Last = point(ribbon.Carrier, Vector3.new(ax, ay, az))
			beam(ribbon.Carrier, ribbon.Last, point(ribbon.Carrier, Vector3.new(bx, by, bz)), ribbon.Color, ribbon.Width)
			finish(ribbon)
			self.Generic[id] = nil
		end
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
		local data, clip, key = nil, 0, ""
		if self.Animations then
			data, clip, key = self.Animations:Swing(e.Model)
		end
		if data then
			bakedTrail(self, id, root, data, clip, key)
		elseif self.Ribbons[id] then
			finish(self.Ribbons[id])
			self.Ribbons[id] = nil
		end
		local record = e.Model:GetAttribute("AsuraStrike")
		if type(record) == "string" and record ~= self.Seen[id] then
			self.Seen[id] = record
			local strike = Strike.decode(record)
			if strike and now - (strike.Start + strike.Active) < STALE then
				if debug then
					draw(self.Folder, root, strike)
				end
				if not data then
					self.Generic[id] = { Strike = strike, Ribbon = { Key = record, Carrier = carrierAt(self.Folder, CFrame.new(root.Position) * CFrame.Angles(0, strike.Yaw, 0)),
						Last = nil, Drawn = 0, Color = (COLORS :: any)[strike.Weapon] or DEFAULT_COLOR, Width = 0.32 } :: Ribbon }
				end
			end
		end
		genericTrail(self, id, root, now)
	end
end

function Controller.Destroy(self: any)
	self.Folder:Destroy()
	table.clear(self.Seen)
	table.clear(self.Ribbons)
	table.clear(self.Generic)
end

return Controller
