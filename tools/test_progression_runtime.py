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
function Methods:IsA(kind) return self.ClassName==kind or (kind=="GuiObject" and self.ClassName~="UIListLayout") end
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
local actors={};local player={UserId=7,Parent=true,CharacterRemoving=signal()}
player.Gui=Instance.new("PlayerGui")
function player:WaitForChild() return self.Gui end
player.Character=Instance.new("Model");local root=Instance.new("Part");root.Name="HumanoidRootPart";root.Position=vec();root.Parent=player.Character
local Players={LocalPlayer=player,PlayerRemoving=signal()}
function Players:GetPlayerByUserId(id) return if id==7 and player.Parent then player else nil end
function Players:GetPlayers() return if player.Parent then {player} else {} end
local workspace={Children={},GetServerTimeNow=function() return clock end}
workspace.FindFirstChild=Methods.FindFirstChild
workspace.CurrentCamera=Instance.new("Camera")
local Run={Heartbeat=signal()}
local inputService={InputBegan=signal(),GamepadEnabled=false}
local services={ReplicatedStorage={AsurasPath={Shared={},Net=net}},Players=Players,RunService=Run,UserInputService=inputService,GuiService={},Workspace=workspace}
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
local World={Flush=function() end,Refresh=function() end,IsInBossFight=function() return false end}
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
function ui:CloseAltar() self.Altar.Visible=false;self.Input:SetMenu(false) end
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
source += module("Actions", "src/server/Services/DialogueActions.luau", {
    "Shared.Shared.ProgressionRules": "Progress", "Shared.Shared.NarrativeCatalog": "Catalog",
    "script.Parent.PersistenceService": "Persistence", "script.Parent.CharacterService": "Characters",
    "script.Parent.WorldService": "World", "script.Parent.ShopService": "Shop", "script.Parent.LootService": "Loot"})
source += module("NarrativeWorld", "src/server/Services/NarrativeWorld.luau", {"Shared.NarrativeCatalog": "Catalog"})
source += module("DialogueService", "src/server/Services/DialogueService.luau", {
    "Shared.Shared.NarrativeCatalog": "Catalog", "Shared.Shared.DialogueRules": "DialogueRules",
    "Shared.Shared.IntentProtocol": "Budget", "Shared.Shared.WorldDefinitions": "Definitions",
    "script.Parent.CharacterService": "Characters", "script.Parent.AIService": "AI",
    "script.Parent.WorldService": "World", "script.Parent.DialogueActions": "Actions", "script.Parent.NarrativeWorld": "NarrativeWorld"})
source += module("WagerWorld", "src/server/Services/WagerWorld.luau", {"game:GetService(\"ReplicatedStorage\").AsurasPath.Shared.WorldDefinitions": "Definitions"})
source += module("WagerService", "src/server/Services/WagerService.luau", {
    "Shared.Shared.ArenaRules": "ArenaRules", "Shared.Shared.IntentProtocol": "Budget",
    "script.Parent.PersistenceService": "Persistence", "script.Parent.CharacterService": "Characters",
    "script.Parent.WagerLedger": "Ledger", "script.Parent.WagerWorld": "WagerWorld"})
source += module("View", "src/client/Controllers/DialogueView.luau", {
    "script.Parent.HudKit": "Kit", "Shared.NarrativeCatalog": "Catalog", "Shared.ProgressionRules": "Progress"})
source += module("DialogueClient", "src/client/Controllers/DialogueController.luau", {"script.Parent.DialogueView": "View", "script.Parent.HudKit": "Kit"})
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
World.OnAltarRest(player,"Altar_SanctuaryBonfire")
check(latest().npc=="Lin","rest opens shrine maiden session")
send({action="Choose",index=1,revision=latest().revision})
send({action="Level",id="Vigor",revision=latest().revision})
check(engine:Get(7).attributes.Vigor==11,"real shrine levels canonical attributes")
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
client.View.Buttons[1].Activated:Fire()
check(remotes.DialogueIntent.Sent[#remotes.DialogueIntent.Sent].revision==latest().revision,"client choices carry current revision")
check(client.View.Subtitle.RichText and client.View.Subtitle.MaxVisibleGraphemes>=1,"rich subtitle typewriter starts")
client:Close();check(not ui.Input.MenuOpen and camera.DialogueFrame==nil,"dialogue close restores camera and input")
move(altar.X,altar.Y+3,altar.Z);World.OnAltarRest(player,"Altar_SanctuaryBonfire");client:Receive(latest())
check(client.Portrait~=nil,"altar summons shrine maiden portrait projection")
client:Close();check(client.Portrait==nil,"projection cleaned when dialogue closes")
assert(engine:Transaction(7,function(p) for _,id in Catalog.Sovereigns do p.defeatedBosses[id]=true end end))
World.OnAltarRest(player,"Altar_SanctuaryBonfire")
check(latest().node=="Release","all six sovereigns unlock the narrative ending")
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
check(World.OnAltarRest==nil,"narrative shutdown removes altar callback")
print("PASS progression runtime: "..checks.." checks")
'''
output = ROOT / "work/test_progression_runtime.generated.luau"
output.parent.mkdir(exist_ok=True)
output.write_text(source)
subprocess.run([str(ROOT / "work/bin/luau/luau"), str(output)], cwd=ROOT, check=True)
