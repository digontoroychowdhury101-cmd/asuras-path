--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/SanctuaryAscent
-- The Ascension stairs and gateway on the bonfire -> stairs -> gate -> statue axis: a broad 1:2 flight
-- of stone treads between moulded stringers and carved balustrades, newel lanterns at its foot and
-- head, a paved landing, and a modest double-eaved gate hall whose lacquered inner columns frame the
-- jade portal (the Monastery travel trigger) and, beyond it, the Veiled Ascetic. Local to the plaza
-- centre, north is -Z; `top` is the landing height and the flight starts `start` studs north.
local Kit = require(script.Parent:WaitForChild("SanctuaryKit") :: ModuleScript)
local Frame = require(script.Parent:WaitForChild("SanctuaryFrame") :: ModuleScript)
local Rails = require(script.Parent:WaitForChild("SanctuaryRails") :: ModuleScript)
local Props = require(script.Parent:WaitForChild("SanctuaryProps") :: ModuleScript)
local Leaves = require(script.Parent:WaitForChild("SanctuaryLeaves") :: ModuleScript)
local Assets = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.PresentationAssets)

local Ascent = {}

export type Stair = { Steps: number, Rise: number, Run: number, Width: number, Start: number, Landing: number, Gate: number }
local PORTAL = Color3.fromRGB(111, 170, 164)
local Y = Vector3.yAxis

local function treads(group: Instance, origin: CFrame, s: Stair)
	for i = 1, s.Steps do
		local height = i * s.Rise + 6
		local z = -(s.Start + (i - 0.5) * s.Run)
		Kit.slab(group, "Step" .. i, Vector3.new(s.Width, height, s.Run + 0.03), origin * CFrame.new(0, i * s.Rise - height / 2, z), "Stone")
		Kit.slab(group, "TreadNosing", Vector3.new(s.Width, 0.14, 0.3), origin * CFrame.new(0, i * s.Rise + 0.02, z + s.Run / 2 - 0.15), "StoneDark", Kit.decor())
	end
	for _, i in { 3, 7, 12, 16 } do
		Leaves.Scatter(group, origin * CFrame.new(0, i * s.Rise, -(s.Start + (i - 0.5) * s.Run)), Vector2.new(s.Width * 0.4, s.Run * 0.4), 10, i)
	end
	-- Stringers: a sloped moulded cap over a solid stepped cheek on each side, balustrade on top.
	local run, rise = s.Steps * s.Run, s.Steps * s.Rise
	local slope = math.atan2(rise, run)
	for side = -1, 1, 2 do
		local x = side * (s.Width / 2 + 0.85)
		for i = 1, s.Steps do
			local h = i * s.Rise + 6 -- tops stay under the sloped cap
			Kit.slab(group, "StairCheek", Vector3.new(1.7, h, s.Run + 0.03), origin * CFrame.new(x, i * s.Rise - 0.3 - h / 2, -(s.Start + (i - 0.5) * s.Run)), "StoneDark")
		end
		local mid = origin * CFrame.new(x, rise / 2 + 1.05, -(s.Start + run / 2))
		Kit.slab(group, "StringerCap", Vector3.new(1.9, 0.6, math.sqrt(run * run + rise * rise) + 0.6), mid * CFrame.Angles(slope, 0, 0), "Stone", Kit.decor())
		-- The cap's top runs 1.35 above the first tread's front edge at the stair's own pitch.
		local foot = (origin * CFrame.new(x, 1.35, -s.Start)).Position
		local head = (origin * CFrame.new(x, 1.35 + (run - s.Run) * rise / run, -(s.Start + run - s.Run))).Position
		Rails.stair(group, foot, head)
		Props.lantern(group, origin * CFrame.new(side * (s.Width / 2 + 2.4), 0.1, -s.Start + 2.4))
		Props.lantern(group, origin * CFrame.new(side * (s.Width / 2 + 3.2), rise, -(s.Start + run + 2.5)))
	end
end

local function landing(group: Instance, origin: CFrame, s: Stair)
	local top, back = s.Steps * s.Rise, s.Start + s.Steps * s.Run
	Kit.slab(group, "Landing", Vector3.new(44, 10, s.Landing + 3), origin * CFrame.new(0, top - 5, -back - s.Landing / 2), "Paving")
	Kit.slab(group, "LandingSkirting", Vector3.new(45, 2, s.Landing + 3.5), origin * CFrame.new(0, top - 6.2, -back - s.Landing / 2), "StoneDark")
	for side = -1, 1, 2 do
		local a = (origin * CFrame.new(side * (s.Width / 2 + 1.9), top, -back - 0.6)).Position
		local b = (origin * CFrame.new(side * 21, top, -back - 0.6)).Position
		Rails.run(group, a, b)
	end
end

-- Double-eaved gate hall; returns the portal trigger (touch to travel).
local function gate(group: Instance, origin: CFrame, s: Stair): BasePart
	local floor = origin * CFrame.new(0, s.Steps * s.Rise, -(s.Start + s.Steps * s.Run + s.Gate))
	-- The plaza looks at the hall's back (+Z), so the hall is turned to face south.
	local hall = floor * CFrame.Angles(0, math.pi, 0)
	Frame.pavilion(group, hall, 30, 6, 12, { Rise = 0.85, Xs = { -15, -7.4, 7.4, 15 }, Lanterns = false })
	Kit.slab(group, "UpperStorey", Vector3.new(17, 5.2, 4.6), hall * CFrame.new(0, 16.8, 0), "Lacquer", Kit.decor())
	Kit.slab(group, "StoreyBand", Vector3.new(17.4, 0.6, 5), hall * CFrame.new(0, 14.4, 0), "Timber", Kit.decor())
	Kit.place(group, "Roof_Hall", hall * CFrame.new(0, 19.6, 0), Vector3.new(0.68, 0.72, 0.78))
	local plaque = floor * CFrame.new(0, 16.9, 2.45)
	Kit.place(group, "Gate_Plaque", plaque)
	local text = Kit.part(group, "GateTablet", Vector3.new(6.2, 2.3, 0.05), plaque * CFrame.new(0, 0, 0.22), Color3.new(), Enum.Material.Wood, Kit.decor())
	text.Transparency = 1
	local gui = Instance.new("SurfaceGui")
	gui.Face, gui.SizingMode, gui.PixelsPerStud, gui.LightInfluence = Enum.NormalId.Back, Enum.SurfaceGuiSizingMode.PixelsPerStud, 40, 1
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency, label.Text, label.TextScaled = UDim2.fromScale(1, 1), 1, "PATH OF THE ASURA", true
	label.Font, label.TextColor3 = Enum.Font.Antique, Kit.Palette.Gold
	label.Parent = gui
	gui.Parent = text
	-- Side bays: stone dado and timber lattice, so the jade portal is the one opening on the axis.
	for side = -1, 1, 2 do
		local bay = floor * CFrame.new(side * 11.2, 0, 0)
		Kit.slab(group, "GateDado", Vector3.new(6.8, 2.4, 0.8), bay * CFrame.new(0, 1.2, 0), "StoneDark")
		for x = -3, 3, 0.75 do
			Kit.slab(group, "GateLattice", Vector3.new(0.2, 7.4, 0.25), bay * CFrame.new(x, 6.1, 0), "Timber", Kit.decor())
		end
		Kit.slab(group, "GateLatticeRail", Vector3.new(6.8, 0.35, 0.4), bay * CFrame.new(0, 9.9, 0), "Lacquer", Kit.decor())
		Kit.blocker(group, "GateBayCollision", (bay * CFrame.new(-3.4, 0, 0)).Position, (bay * CFrame.new(3.4, 0, 0)).Position, 10, 0.8)
		Frame.hanging(group, (floor * CFrame.new(side * 11.2, 11.6, 3)).Position, 16)
	end
	local cf = floor * CFrame.new(0, 5.8, 0)
	local veil = Kit.part(group, "PortalVeil", Vector3.new(13, 11.4, 0.2), cf, Color3.fromRGB(46, 92, 88), Enum.Material.Glass, Kit.decor())
	veil.Transparency, veil.Reflectance = 0.25, 0.1
	for side = -1, 1, 2 do
		Kit.part(group, "PortalSeam", Vector3.new(0.06, 11.3, 0.1), cf * CFrame.new(side * 6.4, 0, 0.15), PORTAL, Enum.Material.Neon, Kit.decor())
	end
	Kit.light(veil, PORTAL, 18, 0.9, false)
	if Assets.Textures.Smoke ~= "" then
		local mist = Instance.new("ParticleEmitter")
		mist.Texture, mist.Rate, mist.Lifetime, mist.Speed = Assets.Textures.Smoke, 4, NumberRange.new(3, 4), NumberRange.new(0.2, 0.6)
		mist.SpreadAngle, mist.LightEmission = Vector2.new(30, 15), 0.15
		mist.Size = Kit.sequence({ { 0, 2 }, { 1, 6 } })
		mist.Transparency = Kit.sequence({ { 0, 1 }, { 0.3, 0.85 }, { 1, 1 } })
		mist.Color = ColorSequence.new(PORTAL, Color3.fromRGB(72, 103, 112))
		mist.Parent = veil
	end
	local trigger = Kit.part(group, "PortalTrigger", Vector3.new(13, 11.4, 2.4), cf, PORTAL, Enum.Material.SmoothPlastic,
		{ Collide = false, Query = false, Transparency = 1, Shadow = false })
	trigger.CanTouch = true
	return trigger
end

function Ascent.Build(parent: Instance, origin: CFrame, stair: Stair): BasePart
	local group = Kit.folder("AscensionGateway", parent)
	treads(group, origin, stair)
	landing(group, origin, stair)
	return gate(group, origin, stair)
end

return table.freeze(Ascent)
