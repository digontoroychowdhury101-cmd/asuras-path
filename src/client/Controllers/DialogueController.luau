--!strict
local Players=game:GetService("Players")
local UserInput=game:GetService("UserInputService")
local GuiService=game:GetService("GuiService")
local Shared=game:GetService("ReplicatedStorage").AsurasPath
local View=require(script.Parent.DialogueView)
local Kit=require(script.Parent.HudKit)
local Controller={};Controller.__index=Controller
function Controller.new(camera: any,input: any,ui: any): any
 local self=setmetatable({Camera=camera,Input=input,UI=ui,Revision=0,Generation=0,Open=false,Links={}},Controller) :: any
 self.Remote=Shared.Net:WaitForChild("DialogueIntent")
 self.View=View.new(Players.LocalPlayer:WaitForChild("PlayerGui"))
 self.View.Close.Activated:Connect(function() self:Close() end)
 local codex=Instance.new("TextButton");codex.Name="CodexButton";codex.Text="Codex [J]";codex.Size=UDim2.fromOffset(92,30)
 codex.Position=UDim2.new(0,14,0.55,0);codex.BackgroundColor3=Kit.Palette.Ink;codex.TextColor3=Kit.Palette.Ivory
 codex.Parent=ui.Gui;self.Codex=codex
 table.insert(self.Links,codex.Activated:Connect(function() self.Remote:FireServer({action="Codex"}) end))
 table.insert(self.Links,UserInput.InputBegan:Connect(function(key: InputObject,used: boolean)
  if used then return end
  if key.KeyCode==Enum.KeyCode.J and not input.MenuOpen then self.Remote:FireServer({action="Codex"})
  elseif self.Open and (key.KeyCode==Enum.KeyCode.Escape or key.KeyCode==Enum.KeyCode.ButtonB) then self:Close() end
 end))
 table.insert(self.Links,Players.LocalPlayer.CharacterRemoving:Connect(function() self:Close() end))
 table.insert(self.Links,self.Remote.OnClientEvent:Connect(function(p: any) self:Receive(p) end))
 return self
end
function Controller.Close(self: any)
 if self.Portrait then self.Portrait:Destroy();self.Portrait=nil end
 self.Generation+=1;local wasOpen=self.Open;self.Open=false;self.View.Gui.Enabled=false;self.Camera.DialogueFrame=nil
 if wasOpen then self.Input:SetMenu(false) end;self.Remote:FireServer({action="Close"})
 View.clear(self.View)
end
function Controller.Receive(self: any,p: any)
 if p.action=="Close" then self:Close();return end
 if p.action=="Result" then self.UI:ShowBanner("THE INSCRIPTION",tostring(p.message),2);return end
 if not p.view then return end
 if self.UI.Altar.Visible then self.UI:CloseAltar() end
 if self.Portrait then self.Portrait:Destroy();self.Portrait=nil end
 self.Generation+=1;local generation=self.Generation
 self.Open=true;self.View.Gui.Enabled=true;self.Input:SetMenu(true)
 if p.action=="Dialogue" then
  self.Revision=p.revision
  View.render(self.View,p,function(packet: any) packet.revision=self.Revision;self.Remote:FireServer(packet) end)
  local root=Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
  local point=p.point+Vector3.new(0,2,0)
  if p.projection then
   local world=workspace:FindFirstChild("JadeCataclysm")
   local original=world and world:FindFirstChild("Lin")
   if original and original:IsA("Model") then
    local spirit=original:Clone()
    for _,child in spirit:GetDescendants() do
     if child:IsA("BasePart") then child.Transparency=0.35;child.CanCollide=false
     elseif child:IsA("ProximityPrompt") or child:IsA("BillboardGui") then child:Destroy() end
    end
    spirit.Parent=workspace.CurrentCamera;spirit:PivotTo(CFrame.new(p.point+Vector3.new(3,2,0)))
    self.Portrait=spirit;point=p.point+Vector3.new(3,4,0)
   end
  end
  if root then
   local direction=root.Position-point;direction=if direction.Magnitude>0.1 then direction.Unit else Vector3.zAxis
   local shoulder=direction:Cross(Vector3.yAxis)*2
   self.Camera.DialogueFrame=CFrame.lookAt(point+direction*7+shoulder+Vector3.new(0,1,0),point)
  end
 else self.Camera.DialogueFrame=nil;View.codex(self.View,p.view,p.id) end
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
 self:Close();for _,c in self.Links do c:Disconnect() end;self.Codex:Destroy();self.View.Gui:Destroy()
end
return Controller
