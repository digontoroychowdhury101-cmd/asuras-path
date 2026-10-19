--!strict
local Players=game:GetService("Players")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath")
local Catalog=require(Shared.Shared.ArsenalCatalog)
local World=require(Shared.Shared.WorldDefinitions)
local Protocol=require(Shared.Shared.ArsenalProtocol)
local Budget=require(Shared.Shared.IntentProtocol)
local Inventory=require(Shared.Simulation.ArsenalInventory)
local Weapons=require(Shared.Simulation.WeaponSchema)
local Characters=require(script.Parent.CharacterService)
local Persistence=require(script.Parent.PersistenceService) :: any
local Magic=require(script.Parent.MagicService)
local LootWorld=require(script.Parent.LootWorld)
local remote=Shared.Net:WaitForChild("ArsenalIntent") :: RemoteEvent
local Loot={}
local connections: {RBXScriptConnection}={}
local buckets: {[number]: Budget.Bucket}={}
local busy: {[number]: boolean}={}
local root: Folder?=nil
local function available(id: number): any
 local e=Characters.GetActor(id)
 return if e and e.Fighter.State=="Idle" and not e.Duel then e else nil
end
local function nearSmith(e: any): boolean
 local l=World.Sanctuary.Loggia
 return (e.Root.Position-Vector3.new(l.X+5,l.Y+3,l.Z)).Magnitude<=16
end
function Loot.Sync(player: Player,open: boolean?)
 local p=Persistence.Get(player.UserId);if not p then return end
 local inventory=table.clone(p.souls.inventory);inventory.materials=table.clone(p.inventory.Materials)
 remote:FireClient(player,{action="State",inventory=inventory,cooldowns=Magic.Cooldowns(player.UserId),open=open or false})
end
local function transact(player: Player,mutate: (any)->())
 local id=player.UserId;if busy[id] then return end;busy[id]=true
 local ok,err=Persistence.Transaction(id,function(p: any) mutate(p.souls.inventory) end)
 busy[id]=nil
 if ok then Characters.RefreshProgression(id);Loot.Sync(player) end
 if player.Parent then remote:FireClient(player,{action="Result",ok=ok,message=if ok then "Arsenal updated" else tostring(err)}) end
end
function Loot.Claim(player: Player,id: string)
 local c=Catalog.Caches[id];local e=available(player.UserId)
 if not c or not e or (e.Root.Position-Vector3.new(c.X,c.Y,c.Z)).Magnitude>10 then return end
 transact(player,function(i: any)
  local live=available(player.UserId);assert(live and (live.Root.Position-Vector3.new(c.X,c.Y,c.Z)).Magnitude<=10,"Too far from cache")
  local ok,reason=Inventory.claim(i,id);assert(ok,reason)
 end)
end
function Loot.Forge(player: Player,id: string)
 local e=available(player.UserId);if not e or not nearSmith(e) then remote:FireClient(player,{action="Result",ok=false,message="Visit Master Smith Gao in the Loggia"});return end
 transact(player,function(i: any)
  local live=available(player.UserId);assert(live and nearSmith(live),"Visit Master Smith Gao")
  local ok,reason=Inventory.forge(i,id);assert(ok,reason)
 end)
end
local function useTalisman(player: Player)
 local id=player.UserId;local e=available(id);if not e or busy[id] then return end;busy[id]=true
 local ok,err=Persistence.Transaction(id,function(p: any)
  assert(available(id)==e,"Cannot use a talisman now")
  local m=p.inventory.Materials;assert((m.LastBreathTalisman or 0)>0,"No Last Breath Talisman")
  m.LastBreathTalisman-=1
 end)
 busy[id]=nil
 if ok and available(id)==e then e.Fighter.WardUntil=Characters.Now()+30 end
 Loot.Sync(player);remote:FireClient(player,{action="Result",ok=ok,message=if ok then "Last Breath · one fatal blow warded for 30s" else tostring(err)})
end
local function handle(player: Player,packet: any)
 if not Protocol.valid(packet) or packet.action=="Cast" then return end
 local id=player.UserId;local now=Characters.Now();local bucket=buckets[id] or {tokens=5,time=now};buckets[id]=bucket
 if not Budget.Take(bucket,now,1,2,5) then return end
 if packet.action=="State" then Loot.Sync(player);return end
 if packet.action=="UseTalisman" then useTalisman(player);return end
 if packet.action=="Forge" then Loot.Forge(player,packet.id);return end
 if not available(id) then return end
 if packet.action=="EquipSpell" then
  transact(player,function(i: any)
   assert(available(id),"Cannot equip now");assert(i.spells[packet.id],"Spell is locked");i.spellSlots[packet.slot]=packet.id
  end)
 elseif packet.action=="EquipWeapon" then
  transact(player,function(i: any)
   assert(available(id),"Cannot equip now");assert(i.weapons[packet.id] and Weapons.Weapons[packet.id],"Weapon is locked")
   if packet.offhand then assert(packet.id=="Catalyst","Only catalysts may focus spells off-hand");i.offhand=packet.id else i.mainhand=packet.id end
  end)
  local p=Persistence.Get(id)
  if p and available(id) then Characters.EquipWeapon(id,p.souls.inventory.mainhand) end
 end
end
function Loot.Start()
 assert(not root,"LootService already started")
 local folder,links=LootWorld.build(Loot.Claim,function(player: Player) if available(player.UserId) then Loot.Sync(player,true) end end)
 root=folder;for _,c in links do table.insert(connections,c) end
 table.insert(connections,remote.OnServerEvent:Connect(handle))
 table.insert(connections,Players.PlayerRemoving:Connect(function(player: Player) buckets[player.UserId]=nil;busy[player.UserId]=nil end))
end
function Loot.Destroy()
 for _,c in connections do c:Disconnect() end
 table.clear(connections);table.clear(buckets);table.clear(busy)
 if root then root:Destroy();root=nil end
end
return Loot
