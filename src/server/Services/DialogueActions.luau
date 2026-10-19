--!strict
local Shared=game:GetService("ReplicatedStorage").AsurasPath
local Progress=require(Shared.Shared.ProgressionRules)
local Catalog=require(Shared.Shared.NarrativeCatalog)
local Persistence=require(script.Parent.PersistenceService) :: any
local Characters=require(script.Parent.CharacterService)
local World=require(script.Parent.WorldService)
local Shop=require(script.Parent.ShopService)
local Loot=require(script.Parent.LootService)
local Actions={}
function Actions.view(id: number): any
 local p=Persistence.Get(id);if not p then return nil end
 return {qi=p.qiEssence,attributes=p.attributes,inventory=p.inventory,loadout=p.equippedLoadout,mastery=p.weaponMastery,
  colosseum=p.colosseum,cost=Progress.levelCost(Progress.level(p.attributes)),bosses=p.defeatedBosses}
end
function Actions.run(player: Player,s: any,packet: any,valid: ()->boolean): (boolean,string?)
 World.Flush(player.UserId,3)
 assert(valid(),"Conversation ended")
 if packet.action=="Upgrade" and s.Panel=="Forge" then return Shop.UpgradeWeapon(player.UserId)
 elseif packet.action=="Infuse" and s.Panel=="Forge" then return Shop.InfuseWeapon(player.UserId,packet.id)
 elseif packet.action=="Trade" and s.Panel=="Trade" then return Shop.Trade(player.UserId,packet.id)
 elseif packet.action=="Level" and s.Panel=="Level" then
  assert(table.find(Progress.Attributes,packet.id),"Unknown attribute")
  return Persistence.Transaction(player.UserId,function(p: any)
   assert(valid(),"Conversation ended");assert(s.NPC=="Lin","Seek Lady Lin")
   local cost=Progress.levelCost(Progress.level(p.attributes));assert(p.qiEssence>=cost,"Not enough Qi")
   assert(p.attributes[packet.id]<99,"Attribute at maximum")
   p.qiEssence-=cost;p.attributes[packet.id]+=1
  end)
 end
 return false,"Choice unavailable"
end
function Actions.panel(player: Player,action: string)
 if action=="Arsenal" then Loot.Sync(player,true) end
end
function Actions.lore(player: Player,id: string,valid: ()->boolean): (boolean,string?)
 local lore=Catalog.Lore[id];if not lore then return false,"Unknown inscription" end
 return Persistence.Transaction(player.UserId,function(p: any)
  assert(valid(),"Too far from memorial");Progress.discover(p,id,lore.Qi)
 end)
end
function Actions.refresh(id: number)
 Characters.RefreshProgression(id);World.Refresh(id)
end
return table.freeze(Actions)
