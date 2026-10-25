--!nonstrict
-- Unmapped Studio-only panel for the human combat playtest (pairs with HumanPlaytest.server.luau).
-- Hold Alt to free the cursor, then click a station. M drops a timestamped "felt wrong" mark into the
-- Output log. The panel collapses to one small tab so it stays out of the way while fighting.
local Run = game:GetService("RunService")
if not Run:IsStudio() then return end
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local remote = game:GetService("ReplicatedStorage"):WaitForChild("AsuraPlaytest", 10)
if not remote then return end
local gui = Players.LocalPlayer:WaitForChild("PlayerGui")
local old = gui:FindFirstChild("AsuraPlaytestPanel")
if old then old:Destroy() end

local screen = Instance.new("ScreenGui")
screen.Name, screen.ResetOnSpawn, screen.DisplayOrder, screen.IgnoreGuiInset = "AsuraPlaytestPanel", false, 50, true
local frame = Instance.new("Frame")
frame.AnchorPoint, frame.Position, frame.Size = Vector2.new(0, 0), UDim2.new(0, 12, 0, 60), UDim2.fromOffset(210, 0)
frame.AutomaticSize, frame.BackgroundColor3, frame.BackgroundTransparency = Enum.AutomaticSize.Y, Color3.fromRGB(16, 14, 18), 0.25
frame.Parent = screen
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)
local pad = Instance.new("UIPadding", frame)
pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 6), UDim.new(0, 6), UDim.new(0, 6), UDim.new(0, 6)
local layout = Instance.new("UIListLayout", frame)
layout.Padding, layout.SortOrder = UDim.new(0, 3), Enum.SortOrder.LayoutOrder

local body: { GuiObject } = {}
local function button(order: number, text: string, onClick: () -> (), header: boolean?): TextButton
	local b = Instance.new("TextButton")
	b.LayoutOrder, b.Size, b.Text, b.AutoButtonColor = order, UDim2.new(1, 0, 0, if header then 22 else 20), text, true
	b.Font, b.TextSize, b.TextColor3 = Enum.Font.GothamBold, 13, Color3.fromRGB(240, 232, 214)
	b.BackgroundColor3 = if header then Color3.fromRGB(120, 28, 34) else Color3.fromRGB(46, 42, 50)
	b.TextXAlignment = Enum.TextXAlignment.Left
	Instance.new("UIPadding", b).PaddingLeft = UDim.new(0, 8)
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
	b.Activated:Connect(onClick)
	b.Parent = frame
	if not header then table.insert(body, b) end
	return b
end

local note = Instance.new("TextLabel")
note.LayoutOrder, note.Size, note.BackgroundTransparency = 99, UDim2.new(1, 0, 0, 28), 1
note.Font, note.TextSize, note.TextWrapped, note.TextColor3 = Enum.Font.Gotham, 12, true, Color3.fromRGB(214, 200, 170)
note.Text = "Hold Alt to use the mouse. M = mark a moment."
note.Parent = frame
table.insert(body, note)

local open = true
local header
header = button(0, "PLAYTEST [-]  not earned play", function()
	open = not open
	for _, item in body do item.Visible = open end
	header.Text = if open then "PLAYTEST [-]  not earned play" else "PLAYTEST [+]"
	frame.Size = UDim2.fromOffset(if open then 210 else 120, 0)
end, true)
button(1, "1  Training yard (warm-up)", function() remote:FireServer("go", "Yard") end)
button(2, "2  Monk courtyard", function() remote:FireServer("go", "Monk") end)
button(3, "3  Bridge swordsman (Jian)", function() remote:FireServer("go", "Bridge") end)
button(4, "4  Twin Sentinels gate", function() remote:FireServer("go", "Twins") end)
button(5, "Heal me", function() remote:FireServer("heal") end)
button(6, "Use fists", function() remote:FireServer("weapon", "Unarmed") end)
button(7, "Use Jian", function() remote:FireServer("weapon", "Jian") end)

local marks = 0
UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed or input.KeyCode ~= Enum.KeyCode.M then return end
	marks += 1
	remote:FireServer("mark", "#" .. marks)
end)
remote.OnClientEvent:Connect(function(kind: string, text: string)
	if kind == "note" then note.Text = tostring(text) end
end)
screen.Parent = gui
