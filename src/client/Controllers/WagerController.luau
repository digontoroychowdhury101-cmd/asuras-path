--!strict
local Players=game:GetService("Players")
local View=require(script.Parent.DialogueView)
local Definitions=require(game:GetService("ReplicatedStorage").AsurasPath.Shared.WorldDefinitions)
local Controller={};Controller.__index=Controller
function Controller.new(ui: any): any
 local self=setmetatable({Ui=ui,Open=false,View=View.new(Players.LocalPlayer:WaitForChild("PlayerGui")),Links={}},Controller) :: any
 self.Remote=game:GetService("ReplicatedStorage").AsurasPath.Net.WagerIntent
 self.View.Gui.Name="SpectatorWagers";self.View.Gui.DisplayOrder=80
 table.insert(self.Links,self.View.Close.Activated:Connect(function() self:Close() end))
 table.insert(self.Links,self.Remote.OnClientEvent:Connect(function(p: any)
  if p.action~="Panel" then return end
  View.clear(self.View);self.View.Gui.Enabled=true;self.Open=true;ui:CloseAltar();ui.Input:SetMenu(true)
  self.View.Title.Text="COLOSSEUM BALCONY · "..p.qi.." Qi"
  self.View.Subtitle.MaxVisibleGraphemes=-1
  self.View.Subtitle.Text=p.message or "Wager 50–500 Qi before the opening bell. Winners receive 1.8× their stake; a draw or cancelled duel refunds it."
  View.button(self.View,"Refresh active duels",function() self.Remote:FireServer({action="Refresh"}) end)
  if #p.matches==0 then View.button(self.View,"No active duels · challenge a fighter below",function() end) end
  for _,m in p.matches do
   for _,fighter in {{Id=m.a,Name=m.an},{Id=m.b,Name=m.bn}} do
    for _,amount in {50,100,250,500} do
     View.button(self.View,(if m.open then "Wager "..amount.." Qi · " else "Bell sounded · ")..fighter.Name,function()
      if m.open then self.Remote:FireServer({action="Wager",match=m.id,fighter=fighter.Id,amount=amount}) end
     end)
    end
   end
  end
 end))
 return self
end
function Controller.Close(self: any)
 if self.Open then self.Ui.Input:SetMenu(false) end
 self.Open=false;self.View.Gui.Enabled=false
end
function Controller.Update(self: any)
 if not self.Open then return end
 local character=Players.LocalPlayer.Character
 local root=character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
 local c=Definitions.Sanctuary.Promenade
 if not root or math.abs(root.Position.X-c.X-30)>12 or math.abs(root.Position.Z-c.Z)>20 or root.Position.Y<c.Y+11 then self:Close() end
end
function Controller.Destroy(self: any)
 self:Close()
 for _,c in self.Links do c:Disconnect() end;View.clear(self.View);self.View.Gui:Destroy()
end
return Controller
