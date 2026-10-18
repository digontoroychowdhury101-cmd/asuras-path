--!nonstrict
-- Small first-replicated loading cover; no remote assets or invented progress percentages.
local Players=game:GetService("Players")
local ReplicatedFirst=game:GetService("ReplicatedFirst")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local gui=Instance.new("ScreenGui");gui.Name="AsurasPathLoading";gui.DisplayOrder=100;gui.IgnoreGuiInset=true;gui.ResetOnSpawn=false
local background=Instance.new("Frame");background.Size=UDim2.fromScale(1,1);background.BackgroundColor3=Color3.fromRGB(10,17,24);background.BorderSizePixel=0;background.Parent=gui
local gradient=Instance.new("UIGradient");gradient.Rotation=25;gradient.Color=ColorSequence.new(Color3.fromRGB(10,17,24),Color3.fromRGB(45,56,66));gradient.Parent=background
local function label(value,y,size,color)
 local l=Instance.new("TextLabel");l.Text=value;l.Font=Enum.Font.GothamBold;l.TextSize=size;l.TextColor3=color;l.BackgroundTransparency=1;l.AnchorPoint=Vector2.new(.5,.5);l.Position=UDim2.fromScale(.5,y);l.Size=UDim2.new(.9,0,0,70);l.TextWrapped=true;l.Parent=background;return l
end
label("ASURA'S PATH",.43,38,Color3.fromRGB(242,240,232))
label("WALK THE ASURA'S PATH",.52,12,Color3.fromRGB(225,185,108))
local status=label("PREPARING YOUR FIGHTER…",.68,12,Color3.fromRGB(160,175,185))
-- Rotating tips teach the core loop while the client boots.
local TIPS={"Tap GUARD just as a blow lands to deflect and crack their posture.","Rest at incense altars to set your respawn and refill your gourd.","Fall, and your essence stays behind. Reclaim it from your bloodstain.","Break an enemy's posture, then strike with HEAVY for a Deathblow."}
local tip=label(TIPS[1],.78,14,Color3.fromRGB(200,192,176));tip.Font=Enum.Font.Garamond
local SERVER_GRACE=20
gui.Parent=player:WaitForChild("PlayerGui")
ReplicatedFirst:RemoveDefaultLoadingScreen()
local started=os.clock();local connection
connection=RunService.RenderStepped:Connect(function()
 local hud=gui.Parent:FindFirstChild("AsuraHUD")
 local character=player.Character
 if player:GetAttribute("AsuraClientReady")==true and hud and hud:FindFirstChild("Vitals") and character and character:FindFirstChild("HumanoidRootPart") then connection:Disconnect();gui:Destroy();return end
 gradient.Rotation=25+math.sin((os.clock()-started)*.3)*12
 local elapsed=os.clock()-started
 tip.Text=TIPS[math.floor(elapsed/6)%#TIPS+1]
 -- AsuraReady is set by the server bootstrap; if it never arrives the server failed to start.
 local serverUp=workspace:GetAttribute("AsuraReady")==true
 if not serverUp and elapsed>SERVER_GRACE then
  status.Text=if RunService:IsStudio() then "SERVER FAILED TO START — CHECK THE OUTPUT WINDOW" else "THE SERVER IS NOT RESPONDING — TRY REJOINING"
  status.TextColor3=Color3.fromRGB(214,120,96)
 else
  status.Text=if elapsed>60 then "STILL CONNECTING — WAITING FOR THE GAME CLIENT" else "PREPARING YOUR FIGHTER"..string.rep(".",math.floor(elapsed)%4)
 end
end)
script.Destroying:Connect(function() if connection then connection:Disconnect() end;gui:Destroy() end)
