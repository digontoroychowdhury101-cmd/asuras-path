--!strict
-- Conversations (physical NPCs and Lin's intentional altar projection) and the Codex reader.
-- Owns camera framing (PortraitCamera) and gameplay input while open and always gives both back:
-- on Leave/Escape/B, on the server ending the session, on death, on respawn and when a new
-- conversation replaces this one. Lin is summoned deliberately from the altar menu (ui.OnSummon);
-- after a farewell the player is returned to that altar menu so Travel stays one press away.
local Players=game:GetService("Players")
local UserInput=game:GetService("UserInputService")
local GuiService=game:GetService("GuiService")
local Shared=game:GetService("ReplicatedStorage").AsurasPath
local View=require(script.Parent.DialogueView)
local Kit=require(script.Parent.HudKit)
local InputMap=require(Shared.Shared.InputMap)
local Visibility=require(script.Parent.HudVisibility)
local Portrait=require(script.Parent.PortraitCamera)
-- Codex owns its InputMap key alone (weapon swap moved off it).
local CODEX_KEYS: {[Enum.KeyCode]: boolean}={}
for _,name in (InputMap.get("Codex") :: any).Keys do CODEX_KEYS[(Enum.KeyCode :: any)[name]]=true end
local Controller={};Controller.__index=Controller
function Controller.new(camera: any,input: any,ui: any): any
 local self=setmetatable({Camera=camera,Input=input,UI=ui,Revision=0,Generation=0,Open=false,Links={},ReturnAltar=nil},Controller) :: any
 self.Remote=Shared.Net:WaitForChild("DialogueIntent")
 self.View=View.new(Players.LocalPlayer:WaitForChild("PlayerGui"))
 self.View.Close.Activated:Connect(function() self:Close(true) end)
 local codex=Instance.new("TextButton");codex.Name="CodexButton";codex.Text="Codex";codex.Size=UDim2.fromOffset(92,30)
 codex.Position=UDim2.new(0,14,0.55,0);codex.BackgroundColor3=Kit.Palette.Ink;codex.TextColor3=Kit.Palette.Ivory
 codex.Parent=ui.Gui;self.Codex=codex;Visibility.register(codex,"Pointer")
 local function caption()
  local key=input:Label("Codex");codex.Text=if key~="" and key~="—" then "Codex ["..key.."]" else "Codex"
  View.hint(self.View,input.Device)
 end
 caption()
 local previousDevice=input.OnDeviceChanged
 input.OnDeviceChanged=function(device: string) if previousDevice then previousDevice(device) end;caption() end
 self.RestoreDevice=function() input.OnDeviceChanged=previousDevice end
 -- The altar menu's "Summon Lady Lin" choice; the server validates the kindled altar and distance.
 ui.OnSummon=function(altarId: string) self.Remote:FireServer({action="Summon",id=altarId}) end
 -- Also opened from the Respite menu (touch, controller) through ui.OpenCodex.
 ui.OpenCodex=function() if not self.Open then self.Remote:FireServer({action="Codex"}) end end
 table.insert(self.Links,codex.Activated:Connect(function() if not input.MenuOpen then self.Remote:FireServer({action="Codex"}) end end))
 table.insert(self.Links,UserInput.InputBegan:Connect(function(key: InputObject,used: boolean)
  if used or UserInput:GetFocusedTextBox() then return end
  if CODEX_KEYS[key.KeyCode] and not input.MenuOpen and Visibility.of(ui).Guidance then self.Remote:FireServer({action="Codex"})
  -- Roblox reserves Escape for its own menu (the event arrives processed), so Backspace is the desktop back key, as in Respite.
  elseif self.Open and (key.KeyCode==Enum.KeyCode.Backspace or key.KeyCode==Enum.KeyCode.Escape or key.KeyCode==Enum.KeyCode.ButtonB) then self:Close(true) end
 end))
 -- Death and respawn always end the conversation without returning to any menu.
 local function watch(character: Model) -- one Died link at a time (batch 26: none kept per respawn)
  if self.DiedLink then self.DiedLink:Disconnect();self.DiedLink=nil end
  local humanoid=character:FindFirstChildOfClass("Humanoid")
  if humanoid then self.DiedLink=humanoid.Died:Connect(function() self:Close(false) end) end
 end
 local player=Players.LocalPlayer
 if player.Character then watch(player.Character) end
 table.insert(self.Links,player.CharacterAdded:Connect(function(character: Model) self:Close(false);watch(character) end))
 table.insert(self.Links,player.CharacterRemoving:Connect(function() self:Close(false) end))
 table.insert(self.Links,self.Remote.OnClientEvent:Connect(function(p: any) self:Receive(p) end))
 return self
end
-- toAltar: a deliberate farewell/leave reopens the altar menu Lin was summoned from.
function Controller.Close(self: any,toAltar: boolean?)
 if self.Portrait then self.Portrait:Destroy();self.Portrait=nil end
 local altar=self.ReturnAltar;self.ReturnAltar=nil
 self.Generation+=1;local wasOpen=self.Open;self.Open=false;self.UI.DialogueOpen=false;self.View.Gui.Enabled=false;self.Camera.DialogueFrame=nil
 if wasOpen then self.Input:SetMenu(false,"Dialogue");self.Remote:FireServer({action="Close"}) end
 View.clear(self.View)
 if wasOpen and toAltar and altar and not self.UI.DeathShown then self.UI:OpenAltar(altar) end
end
function Controller.Frame(self: any,p: any)
 local character=Players.LocalPlayer.Character
 local root=character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
 local world=workspace:FindFirstChild("JadeCataclysm")
 local original=world and world:FindFirstChild(p.npc)
 local exclude: {Instance}={workspace.CurrentCamera}
 if character then table.insert(exclude,character) end
 if original then table.insert(exclude,original) end
 local viewer=if root then root.Position else p.point+Vector3.zAxis*8
 local probe=Portrait.probe(exclude)
 local subject=p.point+Vector3.new(0,2,0)
 if p.projection and original and original:IsA("Model") then
  local spirit=original:Clone()
  for _,child in spirit:GetDescendants() do
   if child:IsA("BasePart") then child.Transparency=0.35;child.CanCollide=false;child.CanQuery=false
   elseif child:IsA("ProximityPrompt") or child:IsA("BillboardGui") then child:Destroy() end
  end
  local spot=Portrait.spiritSpot(p.point,viewer,probe)
  spirit.Parent=workspace.CurrentCamera;spirit:PivotTo(CFrame.lookAt(spot,Vector3.new(viewer.X,spot.Y,viewer.Z)))
  self.Portrait=spirit;subject=spot+Vector3.new(0,2,0)
 end
 self.Camera.DialogueFrame=CFrame.lookAt(Portrait.choose(subject,viewer,probe),subject)
end
function Controller.Receive(self: any,p: any)
 if p.action=="Close" then self:Close(p.reason=="Farewell");return end
 if p.action=="Result" then self.UI:ShowBanner("THE INSCRIPTION",tostring(p.message),2);return end
 if not p.view or self.UI.DeathShown then return end
 if self.UI.Altar.Visible then self.UI:CloseAltar() end
 if self.Portrait then self.Portrait:Destroy();self.Portrait=nil end -- a replacement conversation
 self.Generation+=1;local generation=self.Generation
 if not self.Open then self.Input:SetMenu(true,"Dialogue") end
 self.Open=true;self.UI.DialogueOpen=true;self.View.Gui.Enabled=true
 if p.action=="Dialogue" then
  self.Revision=p.revision;self.ReturnAltar=p.altar
  View.render(self.View,p,function(packet: any) packet.revision=self.Revision;self.Remote:FireServer(packet) end)
  self:Frame(p)
 else self.ReturnAltar=nil;self.Camera.DialogueFrame=nil;View.codex(self.View,p.view,p.id) end
 self.View.Subtitle.MaxVisibleGraphemes=0
 local count=utf8.len(self.View.Subtitle.ContentText) or #self.View.Subtitle.Text
 task.spawn(function()
  for i=1,count do
   if generation~=self.Generation then return end
   self.View.Subtitle.MaxVisibleGraphemes=i
   if i%4==0 then Kit.cue(Kit.Sounds.Tick,0.08,0.8) end
   task.wait(0.022)
  end
 end)
 if UserInput.GamepadEnabled then GuiService.SelectedObject=self.View.Buttons[1] or self.View.Close end
end
function Controller.Destroy(self: any)
 self:Close(false);if self.DiedLink then self.DiedLink:Disconnect() end;for _,c in self.Links do c:Disconnect() end;self.RestoreDevice();self.UI.OnSummon=nil;self.UI.OpenCodex=nil;self.Codex:Destroy();self.View.Gui:Destroy()
end
return Controller
