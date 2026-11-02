--!strict
local Shared=game:GetService("ReplicatedStorage").AsurasPath
local Rules=require(Shared.Shared.ProgressionRules)
local Catalog=require(Shared.Shared.NarrativeCatalog)
local Persistence=require(script.Parent.PersistenceService) :: any
local Characters=require(script.Parent.CharacterService)
local Forge={}
local function near(id: number,point: Vector3): boolean
 local e=Characters.GetActor(id)
 return e~=nil and not e.Duel and (e.Fighter.State=="Idle" or e.Fighter.State=="RestingAtShrine") and (e.Root.Position-point).Magnitude<=18
end
-- The same spot and radius the conversation is validated against (DialogueService.nearby).
function Forge.smith(id: number): boolean
 local g=Catalog.NPCs.Gao;return near(id,Vector3.new(g.X,g.Y,g.Z))
end
-- "Missing SpiritIronOre" reads as the item's name.
local function reason(text: string?): string?
 local item=text and string.match(text,"^Missing (%w+)$")
 return if item and Catalog.Trades[item] then "Missing "..Catalog.Trades[item].Name else text
end
-- Refused before the store is touched, so a refusal answers at once rather than after UpdateAsync's retries;
-- the transaction checks everything again against the record it writes. One Rules.upgrade is the only debit.
function Forge.Upgrade(id: number,weapon: string,tier: number): (boolean,string?)
 if not Forge.smith(id) then return false,"Visit Master Smith Gao" end
 local profile=Persistence.Get(id);if not profile then return false,"Your record is unavailable" end
 local refused=Rules.upgradeRefusal(profile,weapon,tier);if refused then return false,reason(refused) end
 local reached=0
 local ok,err=Persistence.Transaction(id,function(p: any)
  assert(Forge.smith(id),"Visit Master Smith Gao");Rules.upgrade(p,weapon,tier);reached=p.inventory.Weapons[weapon].Level
 end)
 if not ok then return false,reason(err) end
 Characters.Cue("WeaponReinforced",id,{weapon=weapon,level=reached})
 return true,"Reinforced to +"..reached
end
function Forge.Infuse(id: number,weapon: string,affinity: string): (boolean,string?)
 if not Forge.smith(id) then return false,"Visit Master Smith Gao" end
 local ok,err=Persistence.Transaction(id,function(p: any)
  assert(Forge.smith(id),"Visit Master Smith Gao");Rules.infuse(p,weapon,affinity)
 end)
 if not ok then return false,reason(err) end
 return true,"Infused"
end
-- Deliberately taking up a forged weapon: the saved loadout first, then the fighter, as LootService does.
-- A weapon already held off-hand trades places, as a swap would.
function Forge.Equip(id: number,weapon: string): (boolean,string?)
 if not Forge.smith(id) then return false,"Visit Master Smith Gao" end
 local ok,err=Persistence.Transaction(id,function(p: any)
  assert(Forge.smith(id),"Visit Master Smith Gao");assert(p.inventory.Weapons[weapon],"Weapon is locked")
  local l=p.equippedLoadout;assert(l.MainWeapon~=weapon,"Already in hand")
  if l.OffWeapon==weapon then l.OffWeapon=l.MainWeapon end
  l.MainWeapon=weapon
 end)
 if not ok then return false,err end
 local equipped,why=Characters.EquipWeapon(id,weapon)
 if not equipped then return false,why end
 return true,"Taken in hand"
end
function Forge.Trade(id: number,item: string): (boolean,string?)
 local trade=Catalog.Trades[item];if not trade then return false,"Unknown trade" end
 local h=Catalog.NPCs.Hermit;local position=Vector3.new(h.X,h.Y,h.Z)
 if not near(id,position) then return false,"Visit the Wandering Hermit" end
 return Persistence.Transaction(id,function(p: any)
  assert(near(id,position),"Visit the Wandering Hermit");assert(p.qiEssence>=trade.Price,"Not enough Essence")
  p.qiEssence-=trade.Price;p.inventory.Materials[item]=(p.inventory.Materials[item] or 0)+1
 end)
end
return table.freeze(Forge)
