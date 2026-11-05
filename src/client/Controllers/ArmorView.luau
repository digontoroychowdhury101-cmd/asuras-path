--!strict
-- Gao's armour panel. Every number comes from ArmorRules.quote, the same rules the server applies,
-- so what the buttons promise is what a confirmation does. Drawn inside the conversation surface.
local Kit=require(script.Parent.UiKit)
local Shared=game:GetService("ReplicatedStorage").AsurasPath.Shared
local Catalog=require(Shared.NarrativeCatalog)
local Armor: any=require(Shared.ArmorRules)
local T=Kit.Theme
local ArmorView={}
function ArmorView.render(View: any,v: any,p: any,send: (any)->(),buy: (any)->(()->()))
 local data=p.view
 if not v.ArmorSet or not Armor.Sets[v.ArmorSet] then v.ArmorSet=if Armor.Sets[data.loadout.ArmorSet] then data.loadout.ArmorSet else Armor.Default end
 local function pct(x: number): string return string.format("%.1f%%",x*100) end
 local function slow(x: number): string return if x>=1 then "full speed" else string.format("%d%% move speed",math.floor(x*100+0.5)) end
 local q=Armor.quote(data,v.ArmorSet);local now=q.Values;local worn=q.Compare
 -- the three suits come first: a choice that sits below the fold is one nobody makes
 for _,id in Armor.Order do
  local entry=Armor.quote(data,id)
  local function pick()
   if v.Locked then return end
   v.ArmorSet=id;p.message=nil;v.Picked=id;View.render(v,p,send);v.Picked=nil
   if v.Refocus then v.Refocus() end
  end
  View.button(v,entry.Name.." · "..entry.Role..(if entry.Owned then " +"..entry.Level else " · not yours")..(if entry.Worn then " · worn" else ""),pick,if id==q.Id then "Primary" else "Secondary",nil,34)
  if v.Picked==id then v.Focus=v.Buttons[#v.Buttons] end
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
end
return ArmorView
