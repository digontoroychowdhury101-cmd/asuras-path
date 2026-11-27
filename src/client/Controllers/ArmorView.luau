--!strict
-- Gao's armour panel. Every number comes from ArmorRules.quote, the same rules the server applies,
-- so what the buttons promise is what a confirmation does. Drawn inside the conversation surface.
local UiKit=require(script.Parent.UiKit)
local HudKit=require(script.Parent.HudKit)
local ItemInspection=require(script.Parent.ItemInspection)
local Shared=game:GetService("ReplicatedStorage").AsurasPath.Shared
local Catalog=require(Shared.NarrativeCatalog)
local Armor: any=require(Shared.ArmorRules)
local T=UiKit.Theme
local ArmorView={}
local function showcase(v: any, id: string): Frame
 v.Order+=1
 local row=HudKit.make("Frame",v.List,{Name="ArmourInspection",BackgroundTransparency=1,Size=UDim2.new(1,-8,0,240),LayoutOrder=v.Order})
 local choices=HudKit.make("Frame",row,{Name="ArmourChoices",BackgroundTransparency=1})
 HudKit.make("UIListLayout",choices,{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder})
 local case=HudKit.make("Frame",row,{Name="ArmourCase",BackgroundColor3=T.Ink,BorderSizePixel=0})
 HudKit.make("UIStroke",case,{Color=T.Edge,Transparency=0.35})
 local stage=ItemInspection.new(case,{Size=UDim2.fromScale(1,1)})
 row.Destroying:Connect(function() stage:Destroy() end)
 stage:Show("Armor",id)
 local function layout()
  local narrow=row.AbsoluteSize.X<510
  row.Size=UDim2.new(1,-8,0,if narrow then 329 else 238)
  choices.Position=if narrow then UDim2.fromOffset(0,171) else UDim2.new()
  choices.Size=if narrow then UDim2.new(1,0,0,156) else UDim2.new(0.39,-7,1,0)
  case.Position=if narrow then UDim2.new() else UDim2.new(0.39,5,0,0)
  case.Size=if narrow then UDim2.new(1,0,0,159) else UDim2.new(0.61,-5,1,0)
 end
 row:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
 layout()
 return choices
end

function ArmorView.render(View: any,v: any,p: any,send: (any)->(),buy: (any)->(()->()))
 local data=p.view
 if not v.ArmorSet or not Armor.Sets[v.ArmorSet] then v.ArmorSet=if Armor.Sets[data.loadout.ArmorSet] then data.loadout.ArmorSet else Armor.Default end
 local function pct(x: number): string return string.format("%.1f%%",x*100) end
 local function slow(x: number): string return if x>=1 then "full speed" else string.format("%d%% move speed",math.floor(x*100+0.5)) end
 local q=Armor.quote(data,v.ArmorSet);local now=q.Values;local worn=q.Compare
 local choices=showcase(v,q.Id)
 local picked=nil
 for order,id in Armor.Order do
  local entry=Armor.quote(data,id)
  local function pick()
   if v.Locked then return end
   v.ArmorSet=id;p.message=nil;v.Picked=id;View.render(v,p,send);v.Picked=nil
   if v.Refocus then v.Refocus() end
  end
  local state=if entry.Worn then "Worn" elseif entry.Owned then "Owned" else "Unowned"
  local caption=entry.Name..(if entry.Owned and entry.Level>0 then " +"..entry.Level else "").."\n"..entry.Role.." · "..state
  local button=UiKit.button(choices,caption,if id==q.Id then "Primary" else "Secondary",pick)
  button.Name,button.LayoutOrder,button.Size=id,order,UDim2.new(1,0,0,46)
  button.TextSize,button.TextWrapped=16,true
  table.insert(v.Buttons,button);v.Enabled[button]=true
  if v.Picked==id then picked=button end
 end
 View.note(v,q.Name.." ("..q.Role..") +"..q.Level.."  ·  "..(if q.Worn then "worn" elseif q.Owned then "owned" else "not yours yet").."\n"..q.Blurb,T.Ivory)
 View.note(v,string.format("Protection %s  ·  Posture +%d  ·  %s",pct(now.Protection),now.Posture,slow(now.Speed)),T.Gold)
 if not q.Worn then
  View.note(v,string.format("Against what you wear: protection %s → %s, posture +%d → +%d, %s → %s",pct(worn.Protection),pct(now.Protection),worn.Posture,now.Posture,slow(worn.Speed),slow(now.Speed)),T.Muted)
 end
 if q.Acquire then
  local a=q.Acquire;local name=Catalog.Trades[a.Material].Name
  View.button(v,"Have Gao forge it · "..a.Price.." Essence + "..a.Need.." "..name.." ("..a.Have.." owned)",buy({action="Armor",verb="Acquire",id=q.Id,tier=0}),if a.Refusal then "Secondary" else "Primary",a.Refusal==nil)
  if a.Refusal then View.note(v,if a.Refusal==a.Requirement then a.Requirement.." first." elseif a.Refusal=="Not enough Essence" then "Needs "..(a.Price-data.qi).." more Essence." else "Needs "..(a.Need-a.Have).." more "..name..".",T.Muted) else v.Focus=v.Buttons[#v.Buttons] end
 else
  if q.Next then
   local n=q.Next;local name=Catalog.Trades[n.Material].Name
   View.note(v,string.format("At +%d: protection %s → %s, posture +%d → +%d",n.Level,pct(now.Protection),pct(n.Values.Protection),now.Posture,n.Values.Posture),T.Gold)
   View.button(v,"Reinforce to +"..n.Level.." · "..n.Cost.." Essence + "..n.Need.." "..name.." ("..n.Have.." owned)",buy({action="Armor",verb="Reinforce",id=q.Id,tier=q.Level}),if n.Refusal then "Secondary" else "Primary",n.Refusal==nil)
   if not n.Refusal then v.Focus=v.Buttons[#v.Buttons]
   elseif data.qi<n.Cost then View.note(v,"Needs "..(n.Cost-data.qi).." more Essence.",T.Muted)
   else View.note(v,"Needs "..(n.Need-n.Have).." more "..name..".",T.Muted) end
  else
   View.note(v,"Gao can reinforce this no further.",T.Muted)
  end
  if not q.Worn then View.button(v,"Wear "..q.Name,buy({action="Armor",verb="Wear",id=q.Id,tier=0})) end
  if q.Worn then View.button(v,"Set armour aside",buy({action="Armor",verb="Wear",id=Armor.None,tier=0})) end
 end
 if picked then v.Focus=picked end
end
return ArmorView
