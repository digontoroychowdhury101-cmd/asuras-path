--!strict
-- Runs in ReplicatedFirst without waiting for the shared HUD kit.
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")

local IVORY = Color3.fromRGB(245, 237, 222)
local MUTED = Color3.fromRGB(190, 177, 155)
local BRONZE = Color3.fromRGB(225, 195, 145)
local ERROR = Color3.fromRGB(237, 155, 139)
local SERVER_GRACE = 20
local TIPS = {
	"Tap Guard just as a blow lands to deflect and crack your enemy's posture.",
	"Rest at an incense altar to set your checkpoint and refill your gourd.",
	"If you fall, reclaim your essence from your bloodstain.",
	"Break an enemy's posture, then use Heavy to deal a Deathblow.",
}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gui = Instance.new("ScreenGui")
gui.Name = "AsurasPathLoading"
gui.DisplayOrder = 100
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false

local background = Instance.new("Frame")
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.fromRGB(41, 35, 29)
background.BorderSizePixel = 0
background.Parent = gui

local grade = Instance.new("UIGradient")
grade.Rotation = 18
grade.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(249, 241, 228)),
	ColorSequenceKeypoint.new(0.62, Color3.fromRGB(142, 142, 142)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(98, 98, 98)),
})
grade.Parent = background

local plate = Instance.new("Frame")
plate.Name = "TitlePlate"
plate.AnchorPoint = Vector2.new(0, 0.5)
plate.Position = UDim2.fromScale(0.10, 0.48)
plate.Size = UDim2.new(0.80, 0, 0, 164)
plate.BackgroundTransparency = 1
plate.Parent = background
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(900, 164)
limit.Parent = plate

local function caption(name: string, value: string, y: number, height: number, low: number, high: number, font: Enum.Font, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name, label.Text, label.Font, label.TextColor3 = name, value, font, color
	label.BackgroundTransparency = 1
	label.Position, label.Size = UDim2.fromOffset(0, y), UDim2.new(1, 0, 0, height)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped, label.TextScaled = true, true
	local fit = Instance.new("UITextSizeConstraint")
	fit.MinTextSize, fit.MaxTextSize = low, high
	fit.Parent = label
	label.Parent = plate
	return label
end

caption("Title", "Asura's Path", 0, 86, 30, 83, Enum.Font.Antique, IVORY)

local function engravedLine(parent: Instance, name: string, position: UDim2, size: UDim2, transparency: number): Frame
	local line = Instance.new("Frame")
	line.Name, line.Position, line.Size = name, position, size
	line.BackgroundColor3, line.BackgroundTransparency, line.BorderSizePixel = BRONZE, transparency, 0
	line.Parent = parent
	return line
end

local rule = engravedLine(plate, "TitleRule", UDim2.fromOffset(0, 93), UDim2.new(0.76, 0, 0, 1), 0.5)
engravedLine(rule, "KnifeEdge", UDim2.fromOffset(0, 0), UDim2.fromOffset(54, 2), 0)
local status = caption("Status", "Preparing your fighter", 107, 28, 14, 17, Enum.Font.GothamMedium, IVORY)
local tip = caption("Hint", TIPS[1], 0, 42, 13, 16, Enum.Font.Gotham, MUTED)
tip.Parent = background
tip.AnchorPoint, tip.Position, tip.Size = Vector2.new(0, 1), UDim2.fromScale(0.10, 0.88), UDim2.new(0.80, 0, 0, 42)
local tipLimit = Instance.new("UISizeConstraint")
tipLimit.MaxSize = Vector2.new(640, 42)
tipLimit.Parent = tip

gui.Parent = playerGui
ReplicatedFirst:RemoveDefaultLoadingScreen()

local started = os.clock()
local alive = true
script.Destroying:Once(function()
	alive = false
	gui:Destroy()
end)
while alive do
	local hud = playerGui:FindFirstChild("AsuraHUD")
	local character = player.Character
	if player:GetAttribute("AsuraClientReady") == true and hud and hud:FindFirstChild("Vitals")
		and character and character:FindFirstChild("HumanoidRootPart") then
		gui:Destroy()
		break
	end
	local elapsed = os.clock() - started
	local serverUp = workspace:GetAttribute("AsuraReady") == true
	if not serverUp and elapsed > SERVER_GRACE then
		status.Text = if RunService:IsStudio() then "Server failed to start. Check Studio Output." else "Server is not responding. Try rejoining."
		status.TextColor3 = ERROR
	else
		status.Text = if elapsed > 60 then "Still connecting to the game" else "Preparing your fighter" .. string.rep(".", math.floor(elapsed) % 4)
		status.TextColor3 = IVORY
	end
	tip.Text = TIPS[math.floor(elapsed / 6) % #TIPS + 1]
	task.wait(0.1)
end
