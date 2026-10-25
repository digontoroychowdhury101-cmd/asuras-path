--!strict
-- Weapon arcs (post-F26 step 2). Every swing in view draws the path the server actually swept: the
-- server publishes each committed strike as the model attribute AsuraStrike (StrikeGeometry arc,
-- reach, lunge and yaw), and this ribbon is built from those numbers rather than the animated blade,
-- so an arc that misses a body really missed it. Player, enemy and boss-look swings alike. A tier-1
-- gameplay cue: shaped by the move (a narrow thrust line, a swept slash fan) so it reads in grayscale
-- and with reduced effects, and gone before the next swing can start.
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

-- Builds the swept shape for one strike around `root`, at the committed yaw.
local function draw(folder: Instance, root: BasePart, strike: Strike.Strike)
	local carrier = Instance.new("Part")
	carrier.Name, carrier.Anchored, carrier.Transparency, carrier.Size = "StrikeArc", true, 1, Vector3.one * 0.2
	carrier.CanCollide, carrier.CanQuery, carrier.CanTouch, carrier.CastShadow = false, false, false, false
	carrier.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, strike.Yaw, 0)
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
	carrier.Parent = folder
	Debris:AddItem(carrier, FADE + 0.05)
end

function Controller.new(state: any): any
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "AsuraStrikeArcs", Workspace
	return setmetatable({ State = state, Folder = folder, Seen = {} :: { [number]: string }, Tick = 0 }, Controller)
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
	for id in self.Seen do
		if not self.State:Get(id) then
			self.Seen[id] = nil
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
		local record = e.Model:GetAttribute("AsuraStrike")
		if type(record) == "string" and record ~= self.Seen[id] then
			self.Seen[id] = record
			local strike = Strike.decode(record)
			if strike and now - (strike.Start + strike.Active) < STALE then
				draw(self.Folder, root, strike)
			end
		end
	end
end

function Controller.Destroy(self: any)
	self.Folder:Destroy()
	table.clear(self.Seen)
end

return Controller
