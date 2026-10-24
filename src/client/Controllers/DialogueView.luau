--!strict
-- Conversation and Codex panel. Same lacquer surface, fonts and UiKit buttons as the Arsenal:
-- the speaker's name is the title, their purse/progress sits on a separate status line, choices
-- are Secondary buttons, affordable purchases Primary and unaffordable ones visibly disabled.
-- Essence is the currency; Qi only ever names the spell resource. Long lists scroll inside a
-- bounded region. Purchases lock the panel until the server answers, so one click buys once.
local Kit=require(script.Parent.HudKit)
local UiKit=require(script.Parent.UiKit)
local Shared=game:GetService("ReplicatedStorage").AsurasPath.Shared
local Catalog=require(Shared.NarrativeCatalog)
local Progress=require(Shared.ProgressionRules)
local Preview=require(Shared.LevelPreview)
local Codex=require(script.Parent.CodexView)
local Effects=require(Shared.EffectsPreference)
local View={}
View.Letterbox=0.09 -- height of each cinematic bar, as a fraction of the screen
View.PanelBottom,View.PanelHeight,View.PanelMax=0.9,0.58,Vector2.new(900,600)
-- Screen height fraction (0 = top) midway between the top bar and the panel's top edge: where a
-- speaker's face stays visible. Computed from the layout, so it holds before the panel is laid out.
function View.faceY(screen: number,inset: number): number
 local height=screen-inset
 local top=height*View.PanelBottom-math.min(height*View.PanelHeight,View.PanelMax.Y)
 return (inset+(height*View.Letterbox+top)/2)/screen
end
local T=UiKit.Theme
local PURCHASES={Level=true,Upgrade=true,Infuse=true,Trade=true}
function View.new(parent: Instance): any
 local gui=Kit.make("ScreenGui",parent,{Name="JadeDialogue",ResetOnSpawn=false,DisplayOrder=85,IgnoreGuiInset=true,Enabled=false})
 Kit.make("Frame",gui,{Size=UDim2.fromScale(1,View.Letterbox),BackgroundColor3=T.Ink,BorderSizePixel=0})
 Kit.make("Frame",gui,{Position=UDim2.fromScale(0,1-View.Letterbox),Size=UDim2.fromScale(1,View.Letterbox),BackgroundColor3=T.Ink,BorderSizePixel=0})
 local panel=Kit.panel(gui,"Dialogue",{AnchorPoint=Vector2.new(0.5,1),Position=UDim2.fromScale(0.5,View.PanelBottom),Size=UDim2.fromScale(0.9,View.PanelHeight),BackgroundColor3=T.Surface,BackgroundTransparency=0.08})
 Kit.make("UISizeConstraint",panel,{MaxSize=View.PanelMax})
 local title=Kit.label(panel,"",26,T.TitleFont,T.Gold,{Position=UDim2.fromOffset(18,6),Size=UDim2.new(1,-120,0,32),TextXAlignment=Enum.TextXAlignment.Left})
 local status=Kit.label(panel,"",15,T.BodyFont,T.Ember,{Position=UDim2.fromOffset(18,36),Size=UDim2.new(1,-120,0,18),TextXAlignment=Enum.TextXAlignment.Left})
 Kit.make("Frame",panel,{Position=UDim2.fromOffset(18,58),Size=UDim2.new(1,-36,0,1),BackgroundColor3=T.Gold,BackgroundTransparency=0.5,BorderSizePixel=0})
 local subtitle=Kit.label(panel,"",20,T.BodyFont,T.Ivory,{Position=UDim2.fromOffset(18,66),Size=UDim2.new(1,-36,0.24,0),TextWrapped=true,TextScaled=true,RichText=true,TextYAlignment=Enum.TextYAlignment.Top})
 Kit.make("UITextSizeConstraint",subtitle,{MinTextSize=13,MaxTextSize=20}) -- long lore shrinks to fit, never spills
 local list=Kit.make("ScrollingFrame",panel,{Position=UDim2.new(0,18,0.24,74),Size=UDim2.new(1,-36,0.76,-110),BackgroundTransparency=1,BorderSizePixel=0,
  ScrollBarThickness=4,ScrollBarImageColor3=T.Edge,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollingDirection=Enum.ScrollingDirection.Y})
 Kit.make("UIListLayout",list,{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder})
 Kit.make("UIPadding",list,{PaddingTop=UDim.new(0,2),PaddingRight=UDim.new(0,8)})
 local hint=Kit.label(panel,"",13,T.BodyFont,T.Muted,{AnchorPoint=Vector2.new(0,1),Position=UDim2.new(0,18,1,-8),Size=UDim2.new(1,-36,0,18),TextXAlignment=Enum.TextXAlignment.Left})
 local close=UiKit.button(panel,"Leave","Ghost",function() end)
 close.AnchorPoint=Vector2.new(1,0);close.Position=UDim2.new(1,-14,0,10);close.Size=UDim2.fromOffset(92,34);close.TextSize=17
 return {Gui=gui,Title=title,Status=status,Subtitle=subtitle,List=list,Hint=hint,Close=close,Buttons={},Links={},Locked=false,Enabled={},Serial=0,Order=0}
end
function View.hint(v: any,device: string)
 v.Hint.Text=if device=="Gamepad" then "[B] leave" elseif device=="Touch" then "Tap Leave to return" else "[Backspace] leave"
end
-- Reading text follows the comfort text size (batch 25): long lore still shrinks to fit.
local function readable(v: any)
 local c=v.Subtitle:FindFirstChildOfClass("UITextSizeConstraint");if not c then return end
 local s=Effects.textScale();c.MinTextSize=math.floor(13*s+0.5);c.MaxTextSize=math.floor(20*s+0.5)
end
function View.clear(v: any)
 for _,c in v.Links do c:Disconnect() end;table.clear(v.Links);table.clear(v.Buttons);table.clear(v.Enabled);v.Locked=false;v.Serial+=1;v.Order=0
 for _,child in v.List:GetChildren() do if child:IsA("GuiObject") then child:Destroy() end end
end
function View.note(v: any,text: string,color: Color3)
 v.Order+=1;Kit.label(v.List,text,15,T.BodyFont,color,{Size=UDim2.new(1,-8,0,0),AutomaticSize=Enum.AutomaticSize.Y,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,LayoutOrder=v.Order})
end
function View.button(v: any,label: string,run: ()->(),variant: string?,enabled: boolean?,height: number?)
 local b=UiKit.button(v.List,label,(variant or "Secondary") :: any,run)
 b.Size=UDim2.new(1,-8,0,height or 42);b.TextSize=17;b.TextWrapped=true;v.Order+=1;b.LayoutOrder=v.Order
 if enabled==false then UiKit.setEnabled(b,false) end
 table.insert(v.Buttons,b);v.Enabled[b]=enabled~=false
end
function View.render(v: any,p: any,send: (any)->())
 readable(v)
 View.clear(v);local n=Catalog.NPCs[p.npc];local node=n.Nodes[p.node];local data=p.view
 local function buy(packet: any): ()->()
  return function()
   if v.Locked then return end -- one purchase per server answer; render() unlocks
   if PURCHASES[packet.action] then
    v.Locked=true;local serial=v.Serial;for _,b in v.Buttons do UiKit.setEnabled(b,false) end
    task.delay(1.5,function() -- no answer (refused packet): give the choices back
     if v.Serial==serial and v.Locked then v.Locked=false;for b,on in v.Enabled do UiKit.setEnabled(b,on) end end
    end)
   end
   send(packet)
  end
 end
 v.Title.Text=n.Name..(if p.projection then "  ·  spirit projection" else "")
 v.Status.Text=tostring(data.qi).." Essence"..(if p.npc=="Lin" then "  ·  "..data.sovereigns.."/6 souls at rest" else "")
 v.Subtitle.Text=if p.message then tostring(p.message).."\n"..node.Text else node.Text
 if p.panel=="Level" then
  local affordable,quote=Preview.quote(data.qi,data.cost)
  View.note(v,"Level "..Progress.level(data.attributes).." → "..(Progress.level(data.attributes)+1).."  ·  "..quote,if affordable then T.Gold else T.Muted)
  for _,id in Progress.Attributes do
   local value=data.attributes[id];local open=affordable and value<Preview.Max
   View.button(v,Preview.Labels[id].." "..value.." → "..(value+1).."\n"..Preview.line(data.attributes,id,data.tier or 0),
    buy({action="Level",id=id}),if open then "Primary" else "Secondary",open,58)
  end
 elseif p.panel=="Forge" then
  local id=data.loadout.MainWeapon;local w=data.inventory.Weapons[id];local cost,ore,count=Progress.upgradeCost(w.Level)
  View.note(v,id.." +"..w.Level.."  ·  Mastery "..Progress.masteryRank(data.mastery[id] or 0).."  ·  "..(w.Infusion or "Uninfused"),T.Ivory)
  if w.Level<10 then
   local have=data.inventory.Materials[ore] or 0
   View.button(v,"Reinforce · "..cost.." Essence + "..count.." "..Catalog.Trades[ore].Name.." ("..have.." owned)",buy({action="Upgrade"}),nil,data.qi>=cost and have>=count)
  end
  for _,affinity in {"CrimsonFire","CelestialLightning","AbyssalVoid"} do
   local gem=Progress.Infusions[affinity];local have=data.inventory.Materials[gem] or 0
   View.button(v,"Infuse "..string.gsub(Catalog.Trades[gem].Name," Gem$","").." · 300 Essence + 1 gem ("..have.." owned)",buy({action="Infuse",id=affinity}),nil,data.qi>=300 and have>=1)
  end
 elseif p.panel=="Trade" then
  local ids={};for id in Catalog.Trades do table.insert(ids,id) end;table.sort(ids)
  for _,id in ids do local t=Catalog.Trades[id];View.button(v,t.Name.." · "..t.Price.." Essence",buy({action="Trade",id=id}),nil,data.qi>=t.Price) end
 end
 for index,c in node.Choices do View.button(v,c.Label,buy({action="Choose",index=index})) end
end
-- Codex: progress, instruction and sections from CodexView; only discovered entries open.
function View.codex(v: any,data: any,selected: string?)
 readable(v)
 View.clear(v)
 Codex.render(v,data,selected,{button=View.button,note=View.note,reopen=function(id: string) View.codex(v,data,id) end,Gold=T.Gold,Muted=T.Muted,Ivory=T.Ivory})
end
return table.freeze(View)
