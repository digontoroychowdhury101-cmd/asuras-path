--!strict
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath")
local simFolder=Shared:WaitForChild("Simulation")
local Spells=require(simFolder:WaitForChild("SpellSchema") :: ModuleScript)
local Hud={}
local CYAN=Color3.fromRGB(102,222,223)
local GOLD=Color3.fromRGB(217,185,108)
export type Card={Button: TextButton,Name: TextLabel,Timer: TextLabel,Segments: {Frame}}
export type View={Root: Frame,Cards: {Card},Menu: TextButton}
function Hud.new(gui: ScreenGui,cast: (number)->(),menu: ()->()): View
 local root=Instance.new("Frame");root.Name="QiSpellSlots";root.Size=UDim2.fromOffset(228,120);root.Position=UDim2.fromOffset(32,232)
 root.BackgroundTransparency=1;root.Parent=gui
 local cards: {Card}={}
 for slot=1,2 do
  local button=Instance.new("TextButton");button.Name="SpellSlot"..slot;button.Size=UDim2.fromOffset(43,43);button.Position=UDim2.fromOffset(16+(slot-1)*100,10)
  button.Rotation=45;button.BackgroundColor3=Color3.fromRGB(15,26,32);button.Text="";button.Parent=root
  local stroke=Instance.new("UIStroke");stroke.Color=GOLD;stroke.Thickness=1.5;stroke.Parent=button
  local icon=Instance.new("TextLabel");icon.Size=UDim2.fromScale(1,1);icon.BackgroundTransparency=1;icon.Rotation=-45
  icon.Font=Enum.Font.GothamBold;icon.TextSize=17;icon.TextColor3=CYAN;icon.Text=if slot==1 then "1" else "E";icon.Parent=button
  local name=Instance.new("TextLabel");name.BackgroundTransparency=1;name.Size=UDim2.fromOffset(96,24);name.Position=UDim2.fromOffset((slot-1)*100-8,66)
  name.Font=Enum.Font.Gotham;name.TextSize=10;name.TextWrapped=true;name.TextColor3=CYAN;name.Parent=root
  local timer=Instance.new("TextLabel");timer.BackgroundTransparency=1;timer.Size=UDim2.fromOffset(80,16);timer.Position=UDim2.fromOffset((slot-1)*100,90)
  timer.TextSize=11;timer.TextColor3=GOLD;timer.Font=Enum.Font.GothamMedium;timer.Parent=root
  local segments: {Frame}={}
  for n=1,20 do
   local angle=math.rad((n-1)*18-90);local f=Instance.new("Frame");f.Size=UDim2.fromOffset(3,5);f.AnchorPoint=Vector2.new(0.5,0.5)
   f.Position=UDim2.fromOffset(37+(slot-1)*100+math.cos(angle)*34,31+math.sin(angle)*34);f.Rotation=(n-1)*18
   f.BorderSizePixel=0;f.BackgroundColor3=GOLD;f.Parent=root;table.insert(segments,f)
  end
  button.Activated:Connect(function() cast(slot) end)
  table.insert(cards,{Button=button,Name=name,Timer=timer,Segments=segments})
 end
 local menuButton=Instance.new("TextButton");menuButton.Size=UDim2.fromOffset(100,24);menuButton.Position=UDim2.fromOffset(0,113)
 menuButton.Text="ARSENAL  [B]";menuButton.TextSize=11;menuButton.TextColor3=GOLD;menuButton.BackgroundColor3=Color3.fromRGB(21,29,32);menuButton.Parent=root
 menuButton.Activated:Connect(menu)
 return {Root=root,Cards=cards,Menu=menuButton}
end
function Hud.update(view: View,slots: {string},cooldowns: {[string]: number},now: number,qi: number)
 for slot,c in view.Cards do
  local id=slots[slot];local s=if id then Spells.get(id) else nil
  local remaining=math.max(0,(cooldowns[id] or 0)-now)
  c.Name.Text=if s then s.Name else "Empty"
  c.Timer.Text=if remaining>0 then string.format("%.1fs",remaining) elseif s then tostring(s.QiCost).." QI" else ""
  c.Button.BackgroundColor3=if s and qi>=s.QiCost and remaining==0 then Color3.fromRGB(26,64,69) else Color3.fromRGB(21,26,31)
  for n,f in c.Segments do f.Visible=s~=nil and n<=math.ceil(remaining/(if s then s.Cooldown else 1)*20) end
 end
end
return table.freeze(Hud)
