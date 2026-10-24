--!strict
-- 2D layers of the Blazing Sun blast (the fire itself is FireStorm, in 3D): the caster's crimson
-- silhouette with white-hot eyes burning through it, the yellow-to-crimson wash and the soft dark
-- orange frame with the sun's disc. Caster only; reduced flashes lets the world show through.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Effects = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.EffectsPreference) :: any
local Kit = require(script.Parent.SkillKit)
local Screen = require(script.Parent.ImpactFrame)
local Canvas = {}

local rgb = Color3.fromRGB

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


-- The caster as a dark crimson silhouette with two white-hot eyes burning through the blast, drawn
-- exactly where they stand for `seconds` (over the 3D firestorm).
function Canvas.emerge(trove: Kit.Trove, model: Model, seconds: number)
	local g = gui(trove, 59)
	local camera = Workspace.CurrentCamera
	local head = model:FindFirstChild("Head")
	if not g or not camera or not head or not head:IsA("BasePart") then return end
	local layer = Instance.new("Frame")
	layer.Size, layer.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	layer.Parent = g
	Screen.silhouette(layer, model, camera.CFrame, camera.FieldOfView, rgb(120, 14, 6), 1, 7, true)
	local s = head.Size
	for _, side in { -1, 1 } do
		local at = camera:WorldToViewportPoint((head.CFrame * CFrame.new(side * s.X * 0.22, s.Y * 0.08, -s.Z * 0.5)).Position)
		for n, spec in { { rgb(255, 210, 80), 0.05, 0.35 }, { Color3.new(1, 1, 1), 0.022, 0 } } do
			local eye = shape(layer, 8 + n)
			eye.Position, eye.Size = UDim2.fromOffset(at.X, at.Y), UDim2.fromOffset(camera.ViewportSize.Y * spec[2], camera.ViewportSize.Y * spec[2] * 0.8)
			eye.BackgroundColor3, eye.BackgroundTransparency = spec[1], spec[3]
			eye:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.5, 0)
		end
	end
	Kit.tween(trove, layer, seconds, { BackgroundTransparency = 1 })
	Kit.after(trove, seconds, function() g:Destroy() end)
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
	-- Every shape is stacked in widening, fading copies: a cheap blur, as the reference frame is soft.
	local function soft(color: Color3, x: number, y: number, w: number, h: number, rotation: number, z: number)
		for k, fade in { 0, 0.5, 0.72, 0.86 } do
			local f = shape(back, z)
			local grow = 1 + (k - 1) * 0.09
			f.Position, f.Size, f.Rotation = UDim2.fromScale(x, y), UDim2.fromOffset(w * grow, h * grow), rotation
			f.BackgroundColor3, f.BackgroundTransparency = color, fade
			f:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.5, 0)
		end
	end
	soft(rgb(255, 196, 60), 0.16, 0.2, size.Y * 0.5, size.Y * 0.3, -35, 2)
	for n, lobe in { { 0.55, 0.62, 0.62 }, { 0.2, 0.95, 0.5 }, { 0.88, 0.9, 0.45 } } do
		soft(rgb(130 - n * 10, 50, 8), lobe[1], lobe[2], size.Y * lobe[3], size.Y * lobe[3] * 1.1, 0, 3)
	end
	Kit.tween(trove, back, seconds, { BackgroundTransparency = 0.3 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Kit.after(trove, seconds, function() g:Destroy() end)
end

return table.freeze(Canvas)
