--!strict
local Kit=require(script.Parent.HudKit)
local Shared=game:GetService("ReplicatedStorage").AsurasPath.Shared
local Catalog=require(Shared.NarrativeCatalog)
local Progress=require(Shared.ProgressionRules)
local View={}
local P=Kit.Palette
function View.new(parent: Instance): any
 local gui=Kit.make("ScreenGui",parent,{Name="JadeDialogue",ResetOnSpawn=false,DisplayOrder=85,IgnoreGuiInset=true,Enabled=false})
 Kit.make("Frame",gui,{Size=UDim2.fromScale(1,0.09),BackgroundColor3=P.Ink,BorderSizePixel=0})
 Kit.make("Frame",gui,{Position=UDim2.fromScale(0,0.91),Size=UDim2.fromScale(1,0.09),BackgroundColor3=P.Ink,BorderSizePixel=0})
 local panel=Kit.panel(gui,"Dialogue",{AnchorPoint=Vector2.new(0.5,1),Position=UDim2.fromScale(0.5,0.9),Size=UDim2.fromScale(0.9,0.58)})
 Kit.make("UISizeConstraint",panel,{MaxSize=Vector2.new(900,600)})
 local title=Kit.label(panel,"",24,Kit.TitleFont,P.Gold,{Position=UDim2.fromOffset(18,6),Size=UDim2.new(1,-100,0,34),TextXAlignment=Enum.TextXAlignment.Left})
 local subtitle=Kit.label(panel,"",20,Kit.BodyFont,P.Ivory,{Position=UDim2.fromOffset(18,44),Size=UDim2.new(1,-36,0.26,0),TextWrapped=true,RichText=true,TextYAlignment=Enum.TextYAlignment.Top})
 local list=Kit.make("ScrollingFrame",panel,{Position=UDim2.new(0,18,0.26,50),Size=UDim2.new(1,-36,0.74,-60),BackgroundTransparency=1,
  ScrollBarThickness=5,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new()})
 Kit.make("UIListLayout",list,{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder})
 local close=Kit.make("TextButton",panel,{Text="Leave",Position=UDim2.new(1,-82,0,8),Size=UDim2.fromOffset(70,30),TextColor3=P.Ivory,BackgroundColor3=P.Ink})
 return {Gui=gui,Title=title,Subtitle=subtitle,List=list,Close=close,Buttons={},Links={}}
end
function View.clear(v: any)
 for _,c in v.Links do c:Disconnect() end;table.clear(v.Links);table.clear(v.Buttons)
 for _,child in v.List:GetChildren() do if child:IsA("GuiObject") then child:Destroy() end end
end
function View.button(v: any,label: string,run: ()->())
 local b=Kit.make("TextButton",v.List,{Text=label,Size=UDim2.new(1,-8,0,40),TextSize=16,TextWrapped=true,Font=Kit.BodyFont,
  TextColor3=P.Ivory,BackgroundColor3=Color3.fromRGB(34,28,25),AutoButtonColor=true,Selectable=true,LayoutOrder=#v.Buttons+1})
 table.insert(v.Buttons,b);table.insert(v.Links,b.Activated:Connect(run))
end
function View.render(v: any,p: any,send: (any)->())
 View.clear(v);local n=Catalog.NPCs[p.npc];local node=n.Nodes[p.node];local data=p.view
 v.Title.Text=n.Name.."  ·  "..tostring(data.qi).." Qi"
 v.Subtitle.Text=if p.message then tostring(p.message).."\n"..node.Text else node.Text
 if p.panel=="Level" then
  for _,id in Progress.Attributes do View.button(v,id.." "..data.attributes[id].." → "..(data.attributes[id]+1).." · "..data.cost.." Qi",function() send({action="Level",id=id}) end) end
 elseif p.panel=="Forge" then
  local id=data.loadout.MainWeapon;local w=data.inventory.Weapons[id];local cost,ore,count=Progress.upgradeCost(w.Level)
  View.button(v,id.." +"..w.Level.." · Mastery "..Progress.masteryRank(data.mastery[id] or 0).." · "..(w.Infusion or "Uninfused"),function() end)
  if w.Level<10 then View.button(v,"Reinforce · "..cost.." Qi + "..count.." "..ore.." ("..(data.inventory.Materials[ore] or 0).." owned)",function() send({action="Upgrade"}) end) end
  for _,affinity in {"CrimsonFire","CelestialLightning","AbyssalVoid"} do
   local gem=Progress.Infusions[affinity]
   View.button(v,"Infuse "..affinity.." · 300 Qi + "..gem.." ("..(data.inventory.Materials[gem] or 0).." owned)",function() send({action="Infuse",id=affinity}) end)
  end
 elseif p.panel=="Trade" then
  local ids={};for id in Catalog.Trades do table.insert(ids,id) end;table.sort(ids)
  for _,id in ids do local t=Catalog.Trades[id];View.button(v,t.Name.." · "..t.Price.." Qi",function() send({action="Trade",id=id}) end) end
 end
 for index,c in node.Choices do View.button(v,c.Label,function() send({action="Choose",index=index}) end) end
end
function View.codex(v: any,data: any,selected: string?)
 View.clear(v);v.Title.Text="MEMORIES OF THE JADE CATACLYSM"
 local entry=if selected then Catalog.Lore[selected] else nil
 v.Subtitle.Text=if entry then entry.Text else "Eight inscriptions. Six souls. One path beyond death."
 for id,l in Catalog.Lore do
  if data.inventory.LoreEntries[id] then View.button(v,l.Title,function() View.codex(v,data,id) end) end
 end
end
return table.freeze(View)
