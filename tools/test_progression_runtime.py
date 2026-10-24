#!/usr/bin/env python3
"""Exercise the actual narrative, forge, wagering and presentation modules with engine fakes."""
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
HEADER = r'''--!nonstrict
local Schema=require("../src/shared/ProfileSchema")
local Store=require("../src/server/ProfileStore")
local Progress=require("../src/shared/ProgressionRules")
local CombatSettings=require("../src/shared/CombatSettings")
local Catalog=require("../src/shared/NarrativeCatalog")
local DialogueRules=require("../src/shared/DialogueRules")
local ArenaRules=require("../src/shared/ArenaRules")
local Definitions=require("../src/shared/WorldDefinitions")
local Budget=require("../src/infrastructure/IntentProtocol")
local Journal=require("../src/server/MatchJournal")
local checks=0
local function check(value,label) assert(value,label);checks+=1 end
local clock=0
local os={clock=function() return clock end,time=function() return 1000 end}
local function signal()
 local s={Links={}}
 function s:Connect(fn) local c={Connected=true};function c:Disconnect() self.Connected=false end;table.insert(self.Links,{C=c,Fn=fn});return c end
 function s:Fire(...) for _,v in self.Links do if v.C.Connected then v.Fn(...) end end end
 return s
end
local spawned={}
local task={}
function task.spawn(fn,...) local co=coroutine.create(fn);local ok,err=coroutine.resume(co,...);assert(ok,err);table.insert(spawned,co);return co end
task.defer=task.spawn
function task.wait() coroutine.yield() end
function task.delay(_,fn) table.insert(spawned,coroutine.create(fn)) end
local V={};V.__index=function(v,k)
 if k=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
 if k=="Unit" then return v/v.Magnitude end
 return V[k]
end
local function vec(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},V) end
V.__add=function(a,b) return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
V.__sub=function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
V.__mul=function(a,b) if type(a)=="number" then a,b=b,a end;return vec(a.X*b,a.Y*b,a.Z*b) end
V.__div=function(a,b) return vec(a.X/b,a.Y/b,a.Z/b) end
function V:Cross(b) return vec(self.Y*b.Z-self.Z*b.Y,self.Z*b.X-self.X*b.Z,self.X*b.Y-self.Y*b.X) end
local Vector3={new=vec,zero=vec(),yAxis=vec(0,1,0),zAxis=vec(0,0,1)}
local Vector2={new=function(x,y) return {X=x,Y=y} end}
local CF={};CF.__index=CF;CF.__mul=function(a,b) return setmetatable({Position=a.Position+b.Position},CF) end
local CFrame={new=function(x,y,z) return setmetatable({Position=if type(x)=="table" then x else vec(x,y,z)},CF) end}
function CFrame.lookAt(p) return CFrame.new(p) end
function CFrame.Angles() return CFrame.new(0,0,0) end -- position-only fake: rotations are identity
local function dim(...) return {...} end
local UDim2={new=dim,fromOffset=dim,fromScale=dim};local UDim={new=dim}
local Enum=setmetatable({}, {__index=function(t,k) local v=setmetatable({}, {__index=function(_,key) return key end});rawset(t,k,v);return v end})
local Color3={fromRGB=dim}
local Instance={}
local Methods={}
local MT={__index=function(t,k)
 if k=="ContentText" then return string.gsub(t.Text or "","<[^>]*>","") end
 return Methods[k]
end,__newindex=function(t,k,v)
 rawset(t,k,v);if k=="Parent" and v and v.Children then table.insert(v.Children,t) end
end}
function Instance.new(kind) return setmetatable({ClassName=kind,Children={},Activated=signal(),Triggered=signal(),Attributes={}},MT) end
function Methods:IsA(kind) return self.ClassName==kind or (kind=="GuiObject" and self.ClassName~="UIListLayout") or (kind=="BasePart" and (self.ClassName=="Part" or self.ClassName=="MeshPart")) end
function Methods:GetChildren() return self.Children end
function Methods:GetDescendants()
 local result={};for _,child in self.Children do table.insert(result,child);for _,v in child:GetDescendants() do table.insert(result,v) end end;return result
end
function Methods:Clone()
 local copy=Instance.new(self.ClassName)
 for k,v in self do if k~="Parent" and k~="Children" and k~="Activated" and k~="Triggered" then copy[k]=v end end
 for _,c in self.Children do local child=c:Clone();child.Parent=copy end;return copy
end
function Methods:PivotTo(cf) self.Pivot=cf end
function Methods:FindFirstChildOfClass(kind) for _,c in self.Children do if c.ClassName==kind then return c end end end
function Methods:FindFirstChild(name) for _,c in self.Children do if c.Name==name and not c.Destroyed then return c end end end
function Methods:WaitForChild(name) return assert(self:FindFirstChild(name),name) end
function Methods:Destroy() self.Destroyed=true end
function Methods:SetAttribute(k,v) self.Attributes[k]=v end
local remotes={}
local function remote(name)
 local r={OnServerEvent=signal(),OnClientEvent=signal(),Packets={},Sent={}}
 function r:FireClient(player,p) table.insert(self.Packets,{Player=player,Packet=p}) end
 function r:FireServer(p) table.insert(self.Sent,p) end
 remotes[name]=r;return r
end
remote("DialogueIntent");remote("WagerIntent")
local net=setmetatable({WaitForChild=function(self,key) return self[key] end},{__index=remotes})
local actors={};local player={UserId=7,Parent=true,CharacterRemoving=signal(),CharacterAdded=signal()}
player.Gui=Instance.new("PlayerGui")
function player:WaitForChild() return self.Gui end
player.Character=Instance.new("Model");local root=Instance.new("Part");root.Name="HumanoidRootPart";root.Position=vec();root.LocalTransparencyModifier=0;root.Parent=player.Character
local Players={LocalPlayer=player,PlayerRemoving=signal()}
function Players:GetPlayerByUserId(id) return if id==7 and player.Parent then player else nil end
function Players:GetPlayers() return if player.Parent then {player} else {} end
local workspace={Children={},GetServerTimeNow=function() return clock end}
workspace.FindFirstChild=Methods.FindFirstChild
workspace.CurrentCamera=Instance.new("Camera")
workspace.CurrentCamera.ViewportSize=vec(1221,503,0) -- the short desktop view where the panel hid Lin's face (F04)
function workspace:Raycast() return nil end
local RaycastParams={new=function() return {} end}
local Run={Heartbeat=signal()}
local inputService={InputBegan=signal(),GamepadEnabled=false}
local services={ReplicatedStorage={AsurasPath={Shared={},Net=net}},Players=Players,RunService=Run,UserInputService=inputService,GuiService={GetGuiInset=function() return vec(0,58,0),vec() end},Workspace=workspace,ProximityPromptService={Enabled=true}}
local game={GetService=function(_,key) return assert(services[key],key) end}
local db={};local database={UpdateAsync=function(_,key,fn)
 -- Invoke the callback twice and discard the speculative result, like an UpdateAsync retry.
 fn(Store.Copy(db[key]));local result=fn(Store.Copy(db[key]));if result then db[key]=Store.Copy(result) end;return Store.Copy(result)
end}
local engine=Store.new(database,Schema,{owner="Runtime",now=function() return 1000 end,wait=function() end,attempts=2,leaseSeconds=180})
assert(engine:Load(7))
local Persistence={Get=function(id) return engine:Get(id) end,Transaction=function(id,fn) return engine:Transaction(id,fn) end}
local refreshes=0;local cues={}
local Characters={GetActor=function(id) return actors[id] end,Now=function() return clock end,RefreshProgression=function() refreshes+=1 end,GetFighter=function(id) return actors[id] and actors[id].Fighter end,IsInDuel=function() return false end,Cue=function(kind) table.insert(cues,kind) end}
actors[7]={Root=root,Fighter={State="Idle"},Duel=nil}
local kindled={Altar_SanctuaryBonfire=true,Altar_MonasteryGate=true}
local World={Flush=function() end,Refresh=function() end,IsInBossFight=function() return false end,GetSession=function() return {Altars=kindled} end}
local hunting=false
local AI={IsHunting=function() return hunting end}
local Loot={Sync=function() end}
local Ledger=Journal.new(database,function(fn) return pcall(fn) end,function() return 1000 end)
local Kit={Palette={Ink=1,Gold=2,Ivory=3},BodyFont="Body",TitleFont="Title",Sounds={Tick="Tick"},cue=function() end}
function Kit.make(kind,parent,props) local v=Instance.new(kind);for k,val in props do v[k]=val end;v.Parent=parent;return v end
function Kit.label(parent,text,_,_,_,props) props.Text=text;return Kit.make("TextLabel",parent,props) end
function Kit.panel(parent,name,props) props.Name=name;return Kit.make("Frame",parent,props) end
local ui={Gui=Instance.new("ScreenGui"),Altar={Visible=false},Input={MenuOpen=false}}
function ui.Input:SetMenu(open) self.MenuOpen=open end
function ui.Input:Label(command) return if command=="Codex" then "J" else "?" end
function ui:CloseAltar() self.Altar.Visible=false;self.Input:SetMenu(false) end
function ui:OpenAltar(id) self.Altar.Visible=true;self.ReopenedAltar=id;self.Input:SetMenu(true) end
local UiKit={Theme={Ink=1,Gold=2,Ivory=3,Muted=4,Ember=5,Edge=6,Surface=7,TitleFont="Title",BodyFont="Body"}}
function UiKit.button(parent,text,_,fn) local b=Kit.make("TextButton",parent,{Text=text});b.Activated:Connect(function() if not b.Disabled then fn() end end);return b end
function UiKit.setEnabled(b,on) b.Disabled=not on end
function ui:ShowBanner() end
function ui:ShowToast() end
local camera={}
'''


def module(name, path, imports):
    source = (ROOT / path).read_text()
    for pattern, replacement in imports.items():
        source, count = re.subn(rf"require\({re.escape(pattern)}\)", replacement, source)
        assert count, (name, pattern)
    assert "require(" not in source, f"Unmapped require in {name}"
    source = re.sub(r"^export type", "type", source, flags=re.M)
    return f"local {name}=(function()\n{source}\nend)()\n"


source = HEADER
source += module("Forge", "src/server/ForgeService.luau", {
    "Shared.Shared.ProgressionRules": "Progress", "Shared.Shared.NarrativeCatalog": "Catalog",
    "script.Parent.PersistenceService": "Persistence", "script.Parent.CharacterService": "Characters",
    "Shared.Shared.WorldDefinitions": "Definitions"})
source += "local Shop={UpgradeWeapon=Forge.Upgrade,InfuseWeapon=Forge.Infuse,Trade=Forge.Trade}\n"
source += module("EndingRules", "src/shared/EndingRules.luau", {})
source += module("EndingCredits", "src/shared/EndingCredits.luau", {})
source += module("Effects", "src/shared/EffectsPreference.luau", {})
source += module("Actions", "src/server/Services/DialogueActions.luau", {
    "Shared.Shared.ProgressionRules": "Progress", "Shared.Shared.NarrativeCatalog": "Catalog",
    "script.Parent.PersistenceService": "Persistence", "script.Parent.CharacterService": "Characters",
    "script.Parent.WorldService": "World", "script.Parent.ShopService": "Shop", "script.Parent.LootService": "Loot",
    "Shared.Shared.EndingRules": "EndingRules"})
source += module("InputMap", "src/shared/InputMap.luau", {})
# CastFigures builds real rig geometry (covered by test_cast_visuals.luau); here a figure is a model with torso and head.
source += """local CastFigures={statue=function(parent,key,_ground)
 local model=Instance.new("Model");model.Name=key;model.Parent=parent
 local torso=Instance.new("Part");torso.Name="UpperTorso";torso.Parent=model
 local head=Instance.new("Part");head.Name="Head";head.Parent=model
 return model,torso,head
end}
"""
source += module("NarrativeWorld", "src/server/Services/NarrativeWorld.luau", {"Shared.NarrativeCatalog": "Catalog", "Shared.InputMap": "InputMap", "script.Parent.CastFigures": "CastFigures"})
source += module("DialogueService", "src/server/Services/DialogueService.luau", {
    "Shared.Shared.NarrativeCatalog": "Catalog", "Shared.Shared.DialogueRules": "DialogueRules",
    "Shared.Shared.IntentProtocol": "Budget", "Shared.Shared.WorldDefinitions": "Definitions",
    "script.Parent.CharacterService": "Characters", "script.Parent.AIService": "AI",
    "script.Parent.WorldService": "World", "script.Parent.DialogueActions": "Actions", "script.Parent.NarrativeWorld": "NarrativeWorld",
    "Shared.Shared.EndingRules": "EndingRules"})
# The balcony's optional imported kit is Studio evidence; exercise its primitive visual fallback here.
source += module("WagerWorld", "src/server/Services/WagerWorld.luau", {"game:GetService(\"ReplicatedStorage\").AsurasPath.Shared.WorldDefinitions": "Definitions", "game:GetService(\"ReplicatedStorage\").AsurasPath.Shared.InputMap": "InputMap", "script.Parent:WaitForChild(\"SanctuaryKit\") :: ModuleScript": "error(\"visual mesh kit unavailable in detached fixture\")"})
source += module("WagerService", "src/server/Services/WagerService.luau", {
    "Shared.Shared.ArenaRules": "ArenaRules", "Shared.Shared.IntentProtocol": "Budget",
    "script.Parent.PersistenceService": "Persistence", "script.Parent.CharacterService": "Characters",
    "script.Parent.WagerLedger": "Ledger", "script.Parent.WagerWorld": "WagerWorld"})
source += module("LevelPreview", "src/shared/LevelPreview.luau", {
    "(script :: any).Parent.ProgressionRules": "Progress", "\"./ProgressionRules\"": "Progress",
    "(script :: any).Parent.CombatSettings": "CombatSettings", "\"./CombatSettings\"": "CombatSettings"})
source += module("CodexView", "src/client/Controllers/CodexView.luau", {"Shared.NarrativeCatalog": "Catalog", "Shared.WorldDefinitions": "Definitions", "Shared.InputMap": "InputMap", "Shared.EndingRules": "EndingRules"})
source += module("View", "src/client/Controllers/DialogueView.luau", {
    "script.Parent.CodexView": "CodexView",
    "script.Parent.HudKit": "Kit", "script.Parent.UiKit": "UiKit", "Shared.NarrativeCatalog": "Catalog",
    "Shared.ProgressionRules": "Progress", "Shared.LevelPreview": "LevelPreview", "Shared.EffectsPreference": "Effects"})
source += module("Portrait", "src/client/Controllers/PortraitCamera.luau", {})
source += module("Visibility", "src/client/Controllers/HudVisibility.luau", {})
source += module("DialogueClient", "src/client/Controllers/DialogueController.luau", {"script.Parent.DialogueView": "View", "script.Parent.HudKit": "Kit", "Shared.Shared.InputMap": "InputMap", "script.Parent.HudVisibility": "Visibility", "script.Parent.PortraitCamera": "Portrait"})
source += module("EndingClient", "src/client/Controllers/EndingController.luau", {
    "Shared.Shared.EndingRules": "EndingRules", "Shared.Shared.EndingCredits": "EndingCredits",
    "Shared.Shared.EffectsPreference": "Effects", "script.Parent.HudKit": "Kit"})
source += module("WagerClient", "src/client/Controllers/WagerController.luau", {
    "script.Parent.DialogueView": "View", "game:GetService(\"ReplicatedStorage\").AsurasPath.Shared.WorldDefinitions": "Definitions"})
world_source=(ROOT / "src/server/Services/WorldService.luau").read_text()
kill_handler=world_source[world_source.index("local function onEvent("):world_source.index("\nlocal function onBossDefeated(")]
source += "local Progression=Progress\nlocal sessions={}\nlocal function enqueue(_,_,fn) assert(fn(engine)) end\nlocal function onPlayerDeath() end\n"+kill_handler+"\n"
source += r'''
local function latest() return remotes.DialogueIntent.Packets[#remotes.DialogueIntent.Packets].Packet end
local function send(p) clock+=1;remotes.DialogueIntent.OnServerEvent:Fire(player,p) end
local function move(x,y,z) root.Position=vec(x,y,z) end
DialogueService.Start()
move(Catalog.NPCs.Gao.X,Catalog.NPCs.Gao.Y,Catalog.NPCs.Gao.Z)
DialogueService.Open(player,"Gao")
check(latest().action=="Dialogue" and latest().node=="Greeting","NPC prompt opens real dialogue session")
local revision=latest().revision
send({action="Choose",index=1,revision=revision})
check(latest().panel=="Forge","choice advances into forge")
local packets=#remotes.DialogueIntent.Packets
send({action="Choose",index=1,revision=revision})
check(#remotes.DialogueIntent.Packets==packets,"stale choice ignored")
local bank=engine:Get(7).qiEssence
send({action="Upgrade",revision=latest().revision})
check(engine:Get(7).qiEssence==bank and engine:Get(7).inventory.Weapons.Jian.Level==0,"unfunded forge leaves profile unchanged")
assert(engine:Transaction(7,function(p) p.qiEssence=10000;p.inventory.Materials.SpiritIronOre=10;p.inventory.Materials.CrimsonFireGem=1 end))
send({action="Upgrade",revision=latest().revision})
check(engine:Get(7).inventory.Weapons.Jian.Level==1 and engine:Get(7).qiEssence==9750,"real dialogue action reinforces")
send({action="Infuse",id="CrimsonFire",revision=latest().revision})
check(engine:Get(7).inventory.Weapons.Jian.Infusion=="CrimsonFire","real dialogue action infuses")
move(1000,600,1000);bank=engine:Get(7).qiEssence
send({action="Upgrade",revision=latest().revision})
check(engine:Get(7).qiEssence==bank,"remote forge fails distance check")
local altar=Definitions.Altars.Altar_SanctuaryBonfire.Placement
move(altar.X,altar.Y+3,altar.Z)
packets=#remotes.DialogueIntent.Packets
send({action="Summon",id="Altar_SanctuaryBonfire"})
check(#remotes.DialogueIntent.Packets==packets+1 and latest().npc=="Lin","altar menu summon opens shrine maiden session")
check(latest().projection==false and latest().altar=="Altar_SanctuaryBonfire" and latest().point.X==Catalog.NPCs.Lin.X,"Lin beside the bonfire speaks in person, framed on her own position")
send({action="Choose",index=1,revision=latest().revision})
check(latest().panel=="Level" and latest().view.cost==Progress.levelCost(Progress.level(engine:Get(7).attributes)),"ascension panel carries the real level cost")
local cost=latest().view.cost
assert(engine:Transaction(7,function(p) p.qiEssence=cost-1 end))
send({action="Choose",index=1,revision=latest().revision});send({action="Choose",index=1,revision=latest().revision})
send({action="Level",id="Vigor",revision=latest().revision})
check(engine:Get(7).attributes.Vigor==10 and engine:Get(7).qiEssence==cost-1 and string.find(latest().message,"Not enough Essence",1,true),"insufficient Essence refused with currency wording")
assert(engine:Transaction(7,function(p) p.qiEssence=10000 end))
local stale=latest().revision
send({action="Level",id="Vigor",revision=stale});send({action="Level",id="Vigor",revision=stale})
check(engine:Get(7).attributes.Vigor==11 and engine:Get(7).qiEssence==10000-cost,"real shrine levels canonical attributes exactly once per revision")
hunting=true;bank=engine:Get(7).qiEssence
send({action="Level",id="Vigor",revision=latest().revision})
check(engine:Get(7).qiEssence==bank,"hunted player cannot level")
hunting=false
move(Catalog.NPCs.Hermit.X,Catalog.NPCs.Hermit.Y,Catalog.NPCs.Hermit.Z)
DialogueService.Open(player,"Hermit");send({action="Choose",index=1,revision=latest().revision})
send({action="Trade",id="LastBreathTalisman",revision=latest().revision})
check(engine:Get(7).inventory.Materials.LastBreathTalisman==1,"hermit sells a real inventory item")
local folder
for _,c in workspace.Children or {} do if c.Name=="JadeCataclysm" then folder=c end end
check(folder~=nil,"lore world is built")
local stone=folder:FindFirstChild("Pillars");move(Catalog.Lore.Pillars.X,3,Catalog.Lore.Pillars.Z)
bank=engine:Get(7).qiEssence
stone:FindFirstChild("NarrativePrompt").Triggered:Fire(player)
stone:FindFirstChild("NarrativePrompt").Triggered:Fire(player)
check(engine:Get(7).qiEssence==bank+Catalog.Lore.Pillars.Qi and engine:Get(7).inventory.LoreEntries.Pillars,"real memorial awards only once")
local client=DialogueClient.new(camera,ui.Input,ui)
move(Catalog.NPCs.Gao.X,Catalog.NPCs.Gao.Y,Catalog.NPCs.Gao.Z)
DialogueService.Open(player,"Gao");client:Receive(latest())
check(client.Open and ui.Input.MenuOpen and camera.DialogueFrame~=nil,"portrait camera and gameplay input are owned during dialogue")
check(root.LocalTransparencyModifier==1,"the player's own avatar is hidden from the portrait shot (F04: hat over Lin's face)")
client.View.Buttons[1].Activated:Fire()
check(remotes.DialogueIntent.Sent[#remotes.DialogueIntent.Sent].revision==latest().revision,"client choices carry current revision")
check(client.View.Subtitle.RichText and client.View.Subtitle.MaxVisibleGraphemes>=1,"rich subtitle typewriter starts")
client:Close();check(not ui.Input.MenuOpen and camera.DialogueFrame==nil,"dialogue close restores camera and input")
check(root.LocalTransparencyModifier~=1,"closing restores the player's avatar")
send({action="Codex"});check(latest().action=="Codex","codex request answered with server discovery flags");client:Receive(latest())
local function texts() local all=client.View.Subtitle.Text.." "..client.View.Status.Text;for _,c in client.View.List.Children do if not c.Destroyed then all..=" "..tostring(c.Text) end end;return all end
local shown=texts()
check(string.find(shown,"1 / 8 Inscriptions",1,true) and string.find(shown,"Sovereigns at rest",1,true),"codex shows discovered totals")
check(string.find(shown,Catalog.Lore.Pillars.Title,1,true)~=nil,"discovered inscription listed")
local leaked=false
for _,id in Catalog.LoreOrder do if id~="Pillars" and (string.find(shown,Catalog.Lore[id].Title,1,true) or string.find(shown,string.sub(Catalog.Lore[id].Text,1,40),1,true)) then leaked=true end end
check(not leaked,"undiscovered inscriptions never show title or text")
check(ui.Input.MenuOpen and camera.DialogueFrame==nil,"codex owns input without a portrait camera")
client:Receive({action="Codex",view=latest().view,id="Feast"})
check(not string.find(client.View.Subtitle.Text,string.sub(Catalog.Lore.Feast.Text,1,40),1,true),"a forged selection of locked lore stays hidden")
client:Close(true);check(not ui.Input.MenuOpen and not client.View.Gui.Enabled and not ui.Altar.Visible,"closing the codex restores movement and opens nothing")
local gate=Definitions.Altars.Altar_MonasteryGate.Placement
move(gate.X+4,gate.Y+3,gate.Z+4);ui.Altar.Visible=true;ui.Input:SetMenu(true)
send({action="Summon",id="Altar_MonasteryGate"});client:Receive(latest())
check(latest().projection and client.Portrait~=nil and client.Portrait.Pivot~=nil,"distant altar summons Lin's spirit projection, placed beside the altar")
check(not ui.Altar.Visible and ui.Input.MenuOpen and camera.DialogueFrame~=nil,"summon hands the altar menu over to the conversation")
client.View.Close.Activated:Fire()
check(client.Portrait==nil and camera.DialogueFrame==nil and ui.Altar.Visible and ui.ReopenedAltar=="Altar_MonasteryGate","leaving Lin returns to the altar menu (travel stays reachable)")
ui:CloseAltar();send({action="Summon",id="Altar_MonasteryGate"});client:Receive(latest())
remotes.DialogueIntent.OnClientEvent:Fire({action="Close",reason="Farewell"})
check(ui.Altar.Visible and not client.Open,"farewell choice also returns to the altar")
-- F04: at the Cloister the rest respawned monks that engaged at once, and Summon did nothing and said nothing.
ui:CloseAltar();ui.Altar.Visible=true;hunting=true
send({action="Summon",id="Altar_MonasteryGate"});client:Receive(latest())
check(latest().action=="Refused" and string.find(latest().message,"hunt",1,true)~=nil and not client.Open and ui.Altar.Visible,"a summon refused while foes hunt says why and keeps the altar menu")
hunting=false;ui:CloseAltar()
ui:CloseAltar();ui.ReopenedAltar=nil;send({action="Summon",id="Altar_MonasteryGate"});client:Receive(latest())
player.CharacterAdded:Fire(player.Character)
check(not client.Open and not ui.Input.MenuOpen and camera.DialogueFrame==nil and client.Portrait==nil and ui.ReopenedAltar==nil,"respawn closes the conversation and restores camera and input without reopening menus")
check(root.LocalTransparencyModifier~=1,"respawn mid-conversation leaves no hidden avatar")
send({action="Summon",id="Altar_MonasteryGate"});client:Receive(latest());ui.DeathShown=true
remotes.DialogueIntent.OnClientEvent:Fire({action="Close"})
check(not client.Open and not ui.Input.MenuOpen and not ui.Altar.Visible,"closing during death restores input and opens nothing")
packets=#remotes.DialogueIntent.Packets
client:Receive({action="Dialogue",npc="Lin",node="Greeting",view=latest().view,point=gate,revision=1})
check(not client.Open and not ui.Input.MenuOpen,"no conversation opens over the death screen");ui.DeathShown=false
send({action="Summon",id="Altar_DesecratedCloister"})
check(#remotes.DialogueIntent.Packets==packets,"unkindled altar cannot summon Lin")
move(1000,600,1000);send({action="Summon",id="Altar_MonasteryGate"})
check(#remotes.DialogueIntent.Packets==packets,"summon refused away from the altar")
move(gate.X+4,gate.Y+3,gate.Z+4)
-- Batch 22: the six-sovereign ending on the real dialogue server, profile store and client scene.
-- Defeated-boss flags are seeded here: this validates logic, not an earned six-boss run (batch 23).
local banners={};function ui:ShowBanner(title,sub) table.insert(banners,{title,sub}) end
function inputService:GetFocusedTextBox() return nil end
local function packets(n) local list=remotes.DialogueIntent.Packets;return list[#list-n].Packet end
local function deliver(n) for i=n,0,-1 do remotes.DialogueIntent.OnClientEvent:Fire(packets(i)) end end
local function index(action) for i,c in Catalog.NPCs.Lin.Nodes[latest().node].Choices do if c.Action==action then return i end end;return nil end
local bonfire=Definitions.Altars.Altar_SanctuaryBonfire.Placement
check(EndingRules.Lin.X==Catalog.NPCs.Lin.X and EndingRules.Lin.Y==Catalog.NPCs.Lin.Y and EndingRules.Lin.Z==Catalog.NPCs.Lin.Z,"ending objective points at Lin's real position")
check(table.concat(EndingRules.Sovereigns,",")==table.concat(Catalog.Sovereigns,","),"ending counts exactly the catalog's six sovereigns")
assert(engine:Transaction(7,function(p) for _,id in Catalog.Sovereigns do if id~="AzureWyrm" then p.defeatedBosses[id]=true end end end))
move(bonfire.X,bonfire.Y+3,bonfire.Z);send({action="Summon",id="Altar_SanctuaryBonfire"})
check(latest().node=="Greeting" and index("Cross")==nil,"five of six: Lin greets and offers no crossing")
local early=Actions.decide(player,{NPC="Lin",Projection=false},"Cross",function() return true end)
check(not early and next(engine:Get(7).souls.world.story)==nil,"five of six: the server refuses a forged crossing")
assert(engine:Transaction(7,function(p) p.defeatedBosses.AzureWyrm=true end))
move(gate.X+4,gate.Y+3,gate.Z+4);send({action="Summon",id="Altar_MonasteryGate"})
check(latest().node=="Summons" and latest().projection and index("Cross")==nil and index("Remain")==nil,"six at a distant altar: her projection calls the Emissary home, no choice through incense")
send({action="Choose",index=1,revision=latest().revision})
check(next(engine:Get(7).souls.world.story)==nil,"a projection cannot record a choice")
local projected,why=Actions.decide(player,{NPC="Lin",Projection=true},"Cross",function() return true end)
check(not projected and string.find(tostring(why),"Primal Bonfire",1,true),"server refuses a projected crossing with a travel instruction")
move(bonfire.X,bonfire.Y+3,bonfire.Z);send({action="Summon",id="Altar_SanctuaryBonfire"})
check(latest().node=="Release" and not latest().projection and index("Cross") and index("Remain"),"six in person: Release offers Cross and Remain")
local before=Store.Copy(engine:Get(7))
local scene=EndingClient.new(camera,ui.Input,ui)
client:Receive(latest())
send({action="Choose",index=index("Remain"),revision=latest().revision})
check(packets(0).action=="Ending" and packets(0).choice=="Remain" and packets(0).first==true and packets(1).action=="Close","remain is recorded, then announced")
deliver(1)
check(not client.Open and not scene.Active and not ui.Input.MenuOpen and banners[#banners][1]=="YOU REMAIN","remain closes Lin and returns to play with a banner")
local story=engine:Get(7).souls.world.story
check(story.Remained and story.Released and not story.Crossed,"remain persisted")
send({action="Summon",id="Altar_SanctuaryBonfire"})
check(latest().node=="Release","after remaining Lin still offers the crossing")
send({action="Choose",index=index("Remain"),revision=latest().revision})
check(packets(0).first==false,"repeating remain is not a first time");deliver(1)
send({action="Summon",id="Altar_SanctuaryBonfire"});client:Receive(latest())
send({action="Choose",index=index("Cross"),revision=latest().revision})
check(packets(0).choice=="Cross" and packets(0).first==true and engine:Get(7).souls.world.story.Crossed,"crossing recorded before the scene")
deliver(1)
check(scene.Active and ui.EndingActive and ui.Input.MenuOpen and camera.DialogueFrame~=nil and not client.Open,"the crossing owns camera and input")
local layers=Visibility.of(ui);check(not layers.Combat and not layers.Prompts and not layers.Guidance,"HUD, prompts and guidance hidden during the crossing")
scene:Update(0.3);inputService.InputBegan:Fire({UserInputType="Keyboard"})
check(scene.Index==1,"the choosing input cannot skip the scene")
scene:Update(0.6);inputService.InputBegan:Fire({UserInputType="Keyboard"})
check(scene.Index==EndingRules.CardBeat and scene.Line.Text=="THE ASURA'S PATH","first skip lands on the completion card")
scene:Update(EndingRules.Scene[EndingRules.CardBeat].Duration+0.01)
check(scene.Roll.Visible and string.find(scene.Roll.Text,"Kenney",1,true) and string.find(scene.Roll.Text,"Ron Kapaun",1,true),"credits roll from the project record")
inputService.InputBegan:Fire({UserInputType="Keyboard"})
check(not scene.Active and camera.DialogueFrame==nil and not ui.Input.MenuOpen and not ui.EndingActive and scene.Gui==nil,"second skip ends the scene and restores camera, input and HUD")
check(banners[#banners][1]=="THE EMISSARY RETURNS","completion acknowledged with the return line")
local after=engine:Get(7)
local kept=after.qiEssence==before.qiEssence
for _,key in {"attributes","defeatedBosses","unlockedAltars"} do for k,v in before[key] do if after[key][k]~=v then kept=false end end end
for id in before.inventory.Weapons do if not after.inventory.Weapons[id] then kept=false end end
for id in before.inventory.LoreEntries do if not after.inventory.LoreEntries[id] then kept=false end end
check(kept,"the ending grants nothing and keeps every weapon, discovery, flag and Essence")
send({action="Summon",id="Altar_SanctuaryBonfire"})
check(latest().node=="Postgame" and index("Cross") and index("Remain")==nil,"after crossing Lin welcomes the returned Emissary and offers the crossing again")
client:Receive(latest());send({action="Choose",index=index("Cross"),revision=latest().revision})
check(packets(0).first==false,"walking the crossing again is a replay, not a second completion");deliver(1)
scene:Update(1);player.CharacterAdded:Fire(player.Character)
check(not scene.Active and camera.DialogueFrame==nil and not ui.Input.MenuOpen and banners[#banners][1]=="THE CROSSING IS RECORDED","respawn interrupts cleanly and says the crossing is kept")
scene:Play();player.CharacterRemoving:Fire()
check(not scene.Active and not ui.EndingActive,"leaving the character interrupts cleanly")
ui.DeathShown=true;scene:Play();check(not scene.Active,"no crossing over the death screen");ui.DeathShown=false
scene:Play();local steps=0;while scene.Active and steps<400 do scene:Update(0.25);steps+=1 end
check(not scene.Active and steps*0.25>=40 and camera.DialogueFrame==nil and not ui.Input.MenuOpen,"unskipped scene plays every beat and cleans up")
local remain=Actions.decide(player,{NPC="Lin",Projection=false},"Remain",function() return true end)
check(remain and engine:Get(7).souls.world.story.Crossed,"remain after crossing never undoes the crossing")
assert(engine:Release(7));assert(engine:Load(7))
local rejoined=engine:Get(7).souls.world.story
check(rejoined.Crossed and rejoined.Remained and rejoined.Released,"story flags survive release and rejoin")
send({action="Summon",id="Altar_SanctuaryBonfire"})
check(latest().node=="Postgame","rejoined Emissary returns to the postgame Lin")
send({action="Codex"});check(string.find(CodexView.summary(latest().view).Crossing,"crossing is made",1,true)~=nil,"Codex records the completed crossing")
local raw=Store.Copy(engine:Get(7));raw.souls.world.story={Crossed="yes"}
check(not Store.ValidateSouls(raw.souls),"corrupt story flags are rejected")
check(Store.MigrateSouls(raw.souls).world.story.Crossed==nil,"migration drops corrupt story flags rather than inventing a completion")
local legacy=Store.Copy(engine:Get(7).souls);legacy.world.story=nil
check(Store.ValidateSouls(legacy) and next(Store.MigrateSouls(legacy).world.story)==nil,"profiles from before batch 22 load with no choice made")
scene:Destroy()
client:Destroy()
local arena={};WagerService.Start(arena)
local c=Definitions.Sanctuary.Promenade;move(c.X+30,c.Y+15,c.Z)
local function wager(p) clock+=1;remotes.WagerIntent.OnServerEvent:Fire(player,p) end
arena.SpectatorBegin("duel",8,9,"Ash","Jade",clock+12,"Ring_SanctuaryPromenade")
bank=engine:Get(7).qiEssence
wager({action="Wager",match="duel",fighter=8,amount=100})
check(engine:Get(7).qiEssence==bank-100,"spectator wager escrows once through actual handler")
wager({action="Wager",match="duel",fighter=8,amount=100})
check(engine:Get(7).qiEssence==bank-100,"duplicate wager refused")
arena.SpectatorResult("duel",8,false)
check(engine:Get(7).qiEssence==bank+80,"durable winning wager pays 1.8x")
WagerService.Recover(7);check(engine:Get(7).qiEssence==bank+80,"recovery cannot repay settled wager")
local spectator=WagerClient.new(ui)
wager({action="Refresh"})
local panel=remotes.WagerIntent.Packets[#remotes.WagerIntent.Packets].Packet
remotes.WagerIntent.OnClientEvent:Fire(panel)
check(spectator.Open and ui.Input.MenuOpen,"wager panel owns input")
spectator.View.Buttons[1].Activated:Fire()
check(remotes.WagerIntent.Sent[#remotes.WagerIntent.Sent].action=="Refresh","spectator panel refresh is connected")
move(0,0,0);spectator:Update()
check(not spectator.Open and not ui.Input.MenuOpen,"leaving balcony closes wager input")
spectator:Destroy();move(c.X+30,c.Y+15,c.Z)
arena.SpectatorBegin("late",8,9,"Ash","Jade",clock+1,"Ring_SanctuaryPromenade")
bank=engine:Get(7).qiEssence;clock+=2
wager({action="Wager",match="late",fighter=8,amount=100})
check(engine:Get(7).qiEssence==bank,"opening bell closes wagers")
arena.SpectatorBegin("self",7,9,"Ash","Jade",clock+12,"Ring_SanctuaryPromenade")
wager({action="Wager",match="self",fighter=7,amount=100})
check(engine:Get(7).qiEssence==bank,"combatants cannot wager")
arena.SpectatorBegin("offline",8,9,"Ash","Jade",clock+12,"Ring_SanctuaryPromenade")
wager({action="Wager",match="offline",fighter=8,amount=100});assert(engine:Release(7));player.Parent=false
arena.SpectatorResult("offline",9,false)
player.Parent=true;assert(engine:Load(7));WagerService.Recover(7)
check(engine:Get(7).qiEssence==bank-100,"disconnect cannot evade losing stake")
arena.SpectatorBegin("shutdown",8,9,"Ash","Jade",clock+12,"Ring_SanctuaryPromenade")
bank=engine:Get(7).qiEssence;wager({action="Wager",match="shutdown",fighter=8,amount=100})
WagerService.Close(clock+5)
check(engine:Get(7).qiEssence==bank,"shutdown refunds unfinished duels")
WagerService.Destroy();DialogueService.Destroy()
assert(engine:Transaction(7,function(p) p.weaponMastery.Jian=1490 end))
actors[7].Fighter.Weapon="Jian"
player.SetAttribute=function() end
sessions[7]={UserId=7,Player=player,Unbanked=0}
AI.GetAgent=function(id) return if id==99 then {Kind="Mob",Essence=25} else nil end
local beforeRefresh=refreshes
onEvent({Kind="KO",Source=7,Target=99})
check(engine:Get(7).weaponMastery.Jian==1520 and refreshes>beforeRefresh,"kill applies mastery unlock to the current fighter immediately")
check(cues[#cues]=="SignatureUnlocked" and sessions[7].Unbanked==25,"rank-five cue and harvested Qi are emitted")
check(World.OnAltarRest==nil,"resting never installs a dialogue callback")
print("PASS progression runtime: "..checks.." checks")
'''


def check_credits():
    """Batch 22: the crossing's credits match assets/CREDITS.md both ways (no invented or missing rows)."""
    record = (ROOT / "assets/CREDITS.md").read_text()
    flat = " ".join(record.split())
    credits = (ROOT / "src/shared/EndingCredits.luau").read_text()
    listed = set(re.findall(r'Source = "([^"]+)"', credits))
    rows = set()
    for line in record.splitlines():
        if line.startswith("|") and "http" in line and not line.startswith("|---"):
            rows.update(re.findall(r"https?://[^\s)|]+", line.split("|")[2]))
    assert rows, "no credit rows parsed"
    assert listed == rows, (sorted(rows - listed), sorted(listed - rows))
    for work, by, licence, source in re.findall(r'Work = "([^"]+)", By = "([^"]+)", License = "([^"]+)", Source = "([^"]+)"', credits):
        row = next(l for l in record.splitlines() if source in l)
        assert licence in row, (work, licence)
        assert by.split(" / ")[0] in row or by in record, (work, by)
    project = re.search(r"Credits.Project = table.freeze\(\{(.*?)\}\)", credits, re.S).group(1)
    for phrase in re.findall(r'"([^"]+)"', project):
        assert phrase.split(": ", 1)[-1] in flat, phrase
    print(f"PASS ending credits: {len(rows)} sourced rows and project lines match assets/CREDITS.md")


check_credits()
output = ROOT / "work/test_progression_runtime.generated.luau"
output.parent.mkdir(exist_ok=True)
output.write_text(source)
subprocess.run([str(ROOT / "work/bin/luau/luau"), str(output)], cwd=ROOT, check=True)
