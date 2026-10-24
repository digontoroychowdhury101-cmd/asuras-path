--!strict
-- Hand-drawn 2D screen beats from the reference cut (NovaInk and InkFrames draw the ink frames):
-- the black frame with a white ground band, a comic "BOOM."
-- bubble, diagonal swoop streaks and full-screen colour fills (the slow whiteout). Lines re-cut every
-- frame like smear animation. Caster only; reduced flashes shortens and softens every beat.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Effects = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.EffectsPreference) :: any
local Kit = require(script.Parent.SkillKit)
local Manga = {}

local WHITE, INK = Color3.new(1, 1, 1), Color3.fromRGB(6, 6, 8)

local function screen(trove: Kit.Trove, order: number): (ScreenGui?, Vector2)
	local player, camera = Players.LocalPlayer, Workspace.CurrentCamera
	if not player or not camera then return nil, Vector2.zero end
	local gui = Kit.add(trove, Instance.new("ScreenGui"))
	gui.Name, gui.IgnoreGuiInset, gui.DisplayOrder, gui.ResetOnSpawn = "AsuraMangaFrame", true, order, false
	gui.Parent = player:FindFirstChildOfClass("PlayerGui")
	return gui, camera.ViewportSize
end

local function box(parent: Instance, color: Color3, transparency: number?): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3, f.BackgroundTransparency, f.BorderSizePixel, f.AnchorPoint = color, transparency or 0, 0, Vector2.new(0.5, 0.5)
	f.Parent = parent
	return f
end

local function blob(parent: Instance, color: Color3): Frame
	local f = box(parent, color)
	local c = Instance.new("UICorner")
	c.CornerRadius, c.Parent = UDim.new(0.5, 0), f
	return f
end

-- Runs `draw` now and every 1/30 s for `seconds`, then removes the gui.
local function animate(trove: Kit.Trove, gui: ScreenGui, seconds: number, draw: (number) -> ())
	if Effects.reducedFlashes() then seconds *= 0.5 end
	draw(0)
	Kit.add(trove, task.spawn(function()
		local start = os.clock()
		while os.clock() - start < seconds and gui.Parent do
			task.wait(1 / 30)
			draw(os.clock() - start)
		end
		gui:Destroy()
	end))
end

-- A long, needle-thin 4-point sparkle (the reference's cross-shaped glints).
local function sparkle(parent: Instance, at: Vector2, size: number, color: Color3?)
	for _, bar in { { size, size * 0.022 }, { size * 0.022, size * 0.8 } } do
		local f = box(parent, color or WHITE)
		f.Position, f.Size, f.ZIndex = UDim2.fromOffset(at.X, at.Y), UDim2.fromOffset(bar[1], bar[2]), 5
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) })
		g.Rotation, g.Parent = if bar[1] < bar[2] then 90 else 0, f
	end
end

Manga.screen, Manga.box, Manga.blob, Manga.animate, Manga.sparkle = screen, box, blob, animate, sparkle

-- Black frame with a white ground band and scattered white blobs (the burst's first instant).
function Manga.groundFlash(trove: Kit.Trove, seconds: number)
	local gui, size = screen(trove, 62)
	if not gui then return end
	local back = box(gui, INK)
	back.Position, back.Size = UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1)
	local band = box(back, WHITE)
	band.AnchorPoint, band.Position, band.Size = Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.66), UDim2.fromScale(1, 0.4)
	local blobs: { Frame } = {}
	for n = 1, 10 do blobs[n] = blob(back, WHITE) end
	animate(trove, gui, seconds, function()
		for n, f in blobs do
			local bump = n <= 6
			local d = if bump then size.Y * (0.03 + math.random() * 0.05) else size.Y * (0.015 + math.random() * 0.025)
			f.Position = UDim2.fromOffset(math.random() * size.X, if bump then size.Y * 0.66 else size.Y * (0.15 + math.random() * 0.35))
			f.Size = UDim2.fromOffset(d * (if bump then 3 else 1.3), d)
		end
	end)
end

-- Comic speech bubble with vertical "BOOM." lettering, popped in at `anchor` (0..1 screen space).
function Manga.boom(trove: Kit.Trove, anchor: Vector2, seconds: number)
	local gui, size = screen(trove, 61)
	if not gui then return end
	local holder = box(gui, WHITE, 1)
	holder.Position, holder.Size = UDim2.fromScale(anchor.X, anchor.Y), UDim2.fromOffset(0, 0)
	local h = size.Y * 0.62
	local body = blob(holder, WHITE)
	body.Position, body.Size = UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.82, 0.9)
	for n = 1, 16 do -- ragged rim and two drips
		local a = n / 16 * math.pi * 2
		local puff = blob(holder, WHITE)
		puff.Position, puff.Size = UDim2.fromScale(0.5 + math.cos(a) * 0.38, 0.5 + math.sin(a) * 0.43), UDim2.fromScale(0.16 + math.random() * 0.1, 0.1 + math.random() * 0.06)
	end
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency, text.Text, text.Font, text.TextColor3 = 1, "B\nO\nO\nM.", Enum.Font.Bangers, INK
	text.TextScaled, text.Size, text.Position, text.AnchorPoint, text.ZIndex = true, UDim2.fromScale(0.5, 0.82), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), 3
	text.Parent = holder
	Kit.tween(trove, holder, 0.08, { Size = UDim2.fromOffset(h * 0.5, h) }, Enum.EasingStyle.Back)
	Kit.after(trove, seconds, function() if holder.Parent then holder.Parent:Destroy() end end)
end

-- Diagonal motion streaks raking across the screen (the camera swoop).
function Manga.streaks(trove: Kit.Trove, color: Color3, seconds: number)
	local gui, size = screen(trove, 40)
	if not gui then return end
	local lines: { Frame } = {}
	for n = 1, 14 do
		local f = box(gui, color, 0.35)
		local g = Instance.new("UIGradient")
		g.Transparency, g.Parent = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) }), f
		lines[n] = f
	end
	animate(trove, gui, seconds, function()
		for _, f in lines do
			f.Position, f.Rotation = UDim2.fromOffset(math.random() * size.X, math.random() * size.Y), -18 + (math.random() - 0.5) * 6
			f.Size = UDim2.fromOffset(size.X * (0.3 + math.random() * 0.6), 2 + math.random() * 18)
		end
	end)
end

-- A full-screen colour that fades in, holds and fades out (the slow whiteout).
function Manga.fill(trove: Kit.Trove, color: Color3, fadeIn: number, hold: number, fadeOut: number)
	local gui = screen(trove, 63)
	if not gui then return end
	local f = box(gui, color, 1)
	f.Position, f.Size = UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1)
	local peak = 1 - Effects.flash(1)
	Kit.tween(trove, f, fadeIn, { BackgroundTransparency = peak }, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
	Kit.after(trove, fadeIn + hold, function()
		Kit.tween(trove, f, fadeOut, { BackgroundTransparency = 1 })
		Kit.after(trove, fadeOut, function() gui:Destroy() end)
	end)
end

return table.freeze(Manga)
