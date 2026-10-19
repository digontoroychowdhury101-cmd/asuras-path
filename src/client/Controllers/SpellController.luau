--!strict
local ContextActionService=game:GetService("ContextActionService")
local UserInputService=game:GetService("UserInputService")
local Workspace=game:GetService("Workspace")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath")
local simFolder=Shared:WaitForChild("Simulation")
local Spells=require(simFolder:WaitForChild("SpellSchema") :: ModuleScript)
local Hud=require(script.Parent.SpellHud)
local Panel=require(script.Parent.ArsenalPanel)
local Vfx=require(script.Parent.SpellVfx)
local Controller={}
Controller.__index=Controller
export type SpellController=typeof(setmetatable({} :: {State: any,Ui: any,Remote: RemoteEvent,Slots: {string},Cooldowns: {[string]: number},
 View: Hud.View,Panel: Panel.View,Connections: {RBXScriptConnection},Unsubscribe: ()->()},Controller))
function Controller.Cast(self: SpellController,slot: number)
 if self.Ui.Input.MenuOpen or UserInputService:GetFocusedTextBox() or self.Panel.Root.Visible or self.Ui.Altar.Visible or self.Ui.PrologueActive then return end
 local snapshot=self.State:OwnSnapshot();local id=self.Slots[slot];local s=if id then Spells.get(id) else nil
 if not snapshot or snapshot.State~="Idle" or not s then return end
 if (self.Cooldowns[id] or 0)>Workspace:GetServerTimeNow() then return end
 if snapshot.Qi<s.QiCost then self.Ui:ShowToast("Not enough Qi");return end
 self.Remote:FireServer({action="Cast",slot=slot})
end
function Controller.new(state: any,ui: any,net: Instance): SpellController
 local remote=net:WaitForChild("ArsenalIntent") :: RemoteEvent
 local self: any=setmetatable({State=state,Ui=ui,Remote=remote,Slots={"ThunderclapPalm","GaleStep"},Cooldowns={},Connections={}},Controller)
 local function toggle()
  if ui.Input.MenuOpen and not Panel.isOpen(self.Panel) then return end
  if Panel.isOpen(self.Panel) then Panel.close(self.Panel) else Panel.open(self.Panel);remote:FireServer({action="State"}) end
 end
 self.Panel=Panel.new(ui.Gui,function(packet: any) remote:FireServer(packet) end)
 self.View=Hud.new(ui.Gui,function(slot: number) self:Cast(slot) end,toggle)
 table.insert(self.Connections,self.Panel.Root:GetPropertyChangedSignal("Visible"):Connect(function()
  if self.Panel.Root.Visible then ui:CloseAltar() end
  ui.Input:SetMenu(self.Panel.Root.Visible or ui.Altar.Visible)
 end))
 table.insert(self.Connections,remote.OnClientEvent:Connect(function(packet: any)
  if type(packet)~="table" then return end
  if packet.action=="State" then
   self.Slots=packet.inventory.spellSlots;self.Cooldowns=packet.cooldowns or {};Panel.update(self.Panel,packet.inventory)
   if packet.open and not Panel.isOpen(self.Panel) then Panel.open(self.Panel) end
  elseif packet.action=="Cooldown" then self.Cooldowns[packet.id]=packet.untilTime
  elseif packet.action=="Result" and not packet.ok then ui:ShowToast(packet.message) end
 end))
 self.Unsubscribe=state:OnCue(function(cue: any) Vfx.cue(cue,state) end)
 local function action(name: string,inputState: Enum.UserInputState,_input: InputObject): Enum.ContextActionResult
  if UserInputService:GetFocusedTextBox() or (self.Panel.Root.Visible and name~="QiArsenal") then return Enum.ContextActionResult.Pass end
  if inputState==Enum.UserInputState.Begin then
   if name=="QiArsenal" then toggle() else self:Cast(if name=="QiSpellOne" then 1 else 2) end
  end
  return Enum.ContextActionResult.Sink
 end
 ContextActionService:BindActionAtPriority("QiSpellOne",action,false,Enum.ContextActionPriority.High.Value+1,Enum.KeyCode.One,Enum.KeyCode.DPadUp)
 ContextActionService:BindActionAtPriority("QiSpellTwo",action,false,Enum.ContextActionPriority.High.Value+1,Enum.KeyCode.E,Enum.KeyCode.DPadDown)
 ContextActionService:BindAction("QiArsenal",action,false,Enum.KeyCode.B,Enum.KeyCode.ButtonSelect)
 table.insert(self.Connections,Workspace:GetAttributeChangedSignal("AsuraReady"):Connect(function()
  if Workspace:GetAttribute("AsuraReady") then remote:FireServer({action="State"}) end
 end))
 if Workspace:GetAttribute("AsuraReady") then remote:FireServer({action="State"}) end
 return self
end
function Controller.Step(self: SpellController)
 local snapshot=self.State:OwnSnapshot()
 Hud.update(self.View,self.Slots,self.Cooldowns,Workspace:GetServerTimeNow(),if snapshot then snapshot.Qi else 0)
end
function Controller.Destroy(self: SpellController)
 for _,c in self.Connections do c:Disconnect() end;self.Unsubscribe()
 for _,name in {"QiSpellOne","QiSpellTwo","QiArsenal"} do ContextActionService:UnbindAction(name) end
 self.View.Root:Destroy();self.Panel.Root:Destroy();Vfx.destroy()
end
return Controller
