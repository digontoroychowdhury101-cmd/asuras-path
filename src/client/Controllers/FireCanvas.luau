--!strict
-- The Blazing Sun blast as the reference draws it: flat cel-shaded flame shapes (hard-edged yellow,
-- orange, crimson and near-black blobs) boiling over the whole screen with bright spark streaks,
-- then a yellow-to-crimson wash and a dark orange frame with the sun's disc. Smear frames at 24 fps.
-- Caster only; reduced flashes keeps the shapes but lets the world show through.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Effects = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.EffectsPreference) :: any
local Kit = require(script.Parent.SkillKit)
local Canvas = {}

local rgb = Color3.fromRGB
local HOT = { rgb(255, 250, 200), rgb(255, 236, 70), rgb(255, 214, 40) }
local BODY = { rgb(255, 150, 30), rgb(250, 110, 25), rgb(225, 70, 20), rgb(170, 35, 10), rgb(70, 14, 4) }

local function gui(trove: Kit.Trove, order: number): (ScreenGui?, Vector2)
	local player, camera = Players.LocalPlayer, Workspace.CurrentCamera
	if not player or not camera then return nil, Vector2.zero end
	local g = Kit.add(trove, Instance.new("ScreenGui"))
	g.Name, g.IgnoreGuiInset, g.DisplayOrder, g.ResetOnSpawn = "AsuraFireCanvas", true, order, false
	g.Parent = player:FindFirstChildOfClass("PlayerGui")
	return g, camera.ViewportSize
end

local function shape(parent: Instance, z: number): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel, f.AnchorPoint, f.ZIndex = 0, Vector2.new(0.5, 0.5), z
	local c = Instance.new("UICorner")
	c.Parent = f
	f.Parent = parent
	return f
end

local function pick(list: { Color3 }): Color3 return list[math.random(1, #list)] end

-- `seconds` of boiling toon fire. Heat starts blown-out (mostly yellow/white) and cools to crimson.
function Canvas.chaos(trove: Kit.Trove, seconds: number)
	local g, size = gui(trove, 58)
	if not g then return end
	local see = if Effects.reducedFlashes() then 0.45 else 0
	local back = shape(g, 1)
	back.Position, back.Size, back.BackgroundColor3, back.BackgroundTransparency = UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1), BODY[2], 0.15 + see
	back:FindFirstChildOfClass("UICorner"):Destroy()
	local blobs: { Frame } = {}
	local tips: { Frame } = {}
	for n = 1, 34 do
		blobs[n] = shape(back, 2 + n % 3)
		local tip = shape(blobs[n], 2 + n % 3) -- a square turned 45 degrees: the tongue's point
		tip.Rotation, tip.Position = 45, UDim2.fromScale(0.5, 0.08)
		tip:FindFirstChildOfClass("UICorner"):Destroy()
		tips[n] = tip
	end
	local sparks: { Frame } = {}
	for n = 1, 16 do
		local s = shape(back, 6)
		s.BackgroundColor3 = if n % 3 == 0 then Color3.new(1, 1, 1) else HOT[2]
		sparks[n] = s
	end
	local function draw(t: number)
		local heat = math.clamp(1 - t / (seconds * 0.6), 0, 1)
		back.BackgroundColor3 = if heat > 0.6 then HOT[3] else BODY[2]
		for n, f in blobs do
			local hot = math.random() < 0.12 + heat * 0.55
			local w = size.Y * (0.1 + math.random() * 0.32)
			local h = w * (1.3 + math.random() * 1.2)
			f.BackgroundColor3 = if hot then pick(HOT) else pick(BODY)
			f.BackgroundTransparency = see
			f.Position = UDim2.fromOffset(math.random() * size.X, size.Y * (0.2 + math.random() * 0.95))
			f.Size, f.Rotation = UDim2.fromOffset(w, h), (math.random() - 0.5) * 60
			f:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.5, 0)
			local tip = tips[n]
			tip.BackgroundColor3, tip.BackgroundTransparency = f.BackgroundColor3, see
			tip.Size = UDim2.fromScale(0.72, 0.72 * w / h)
		end
		for _, s in sparks do
			s.Position = UDim2.fromOffset(math.random() * size.X, math.random() * size.Y)
			s.Size, s.Rotation = UDim2.fromOffset(size.Y * (0.008 + math.random() * 0.02), size.Y * (0.08 + math.random() * 0.3)), (math.random() - 0.5) * 70
		end
	end
	draw(0)
	Kit.add(trove, task.spawn(function()
		local start = os.clock()
		while os.clock() - start < seconds and g.Parent do
			task.wait(1 / 24)
			draw(os.clock() - start)
		end
		g:Destroy()
	end))
end

-- Yellow-to-crimson gradient wash over `seconds`, sliding as it fades.
function Canvas.wash(trove: Kit.Trove, seconds: number)
	local g = gui(trove, 58)
	if not g then return end
	local f = shape(g, 1)
	f.Position, f.Size, f.BackgroundColor3 = UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1.4, 1), Color3.new(1, 1, 1)
	f.BackgroundTransparency = if Effects.reducedFlashes() then 0.5 else 0
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, rgb(255, 236, 70)), ColorSequenceKeypoint.new(0.45, rgb(255, 150, 30)), ColorSequenceKeypoint.new(1, rgb(200, 45, 12)) })
	grad.Parent = f
	Kit.tween(trove, f, seconds, { Position = UDim2.fromScale(0.35, 0.5), BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Kit.after(trove, seconds, function() g:Destroy() end)
end

-- Dark orange frame with a yellow sun disc breaking in from the corner and darker silhouette lobes.
function Canvas.sunFrame(trove: Kit.Trove, seconds: number)
	local g, size = gui(trove, 58)
	if not g then return end
	local back = shape(g, 1)
	back.Position, back.Size, back.BackgroundColor3 = UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1), rgb(165, 70, 12)
	back:FindFirstChildOfClass("UICorner"):Destroy()
	local sun = shape(back, 2)
	sun.Position, sun.Size, sun.BackgroundColor3, sun.Rotation = UDim2.fromScale(0.16, 0.2), UDim2.fromOffset(size.Y * 0.5, size.Y * 0.3), rgb(255, 196, 60), -35
	sun:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.5, 0)
	for n, lobe in { { 0.55, 0.62, 0.62 }, { 0.2, 0.95, 0.5 }, { 0.88, 0.9, 0.45 } } do
		local f = shape(back, 3)
		f.Position, f.Size, f.BackgroundColor3 = UDim2.fromScale(lobe[1], lobe[2]), UDim2.fromOffset(size.Y * lobe[3], size.Y * lobe[3] * 1.1), rgb(130 - n * 10, 50, 8)
		f:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.5, 0)
	end
	Kit.tween(trove, back, seconds, { BackgroundTransparency = 0.3 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Kit.after(trove, seconds, function() g:Destroy() end)
end

return table.freeze(Canvas)
