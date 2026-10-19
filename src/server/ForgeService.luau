--!strict
local Shared=game:GetService("ReplicatedStorage").AsurasPath
local Rules=require(Shared.Shared.ProgressionRules)
local Catalog=require(Shared.Shared.NarrativeCatalog)
local Persistence=require(script.Parent.PersistenceService) :: any
local Characters=require(script.Parent.CharacterService)
local World=require(Shared.Shared.WorldDefinitions)
local Forge={}
local function near(id: number,point: Vector3): boolean
 local e=Characters.GetActor(id)
 return e~=nil and not e.Duel and (e.Fighter.State=="Idle" or e.Fighter.State=="RestingAtShrine") and (e.Root.Position-point).Magnitude<=18
end
function Forge.smith(id: number): boolean
 local p=World.Sanctuary.Loggia;return near(id,Vector3.new(p.X+5,p.Y+3,p.Z))
end
function Forge.Upgrade(id: number): (boolean,string?)
 if not Forge.smith(id) then return false,"Visit Master Smith Gao" end
 return Persistence.Transaction(id,function(p: any)
  assert(Forge.smith(id),"Visit Master Smith Gao");Rules.upgrade(p,p.equippedLoadout.MainWeapon)
 end)
end
function Forge.Infuse(id: number,affinity: string): (boolean,string?)
 if not Forge.smith(id) then return false,"Visit Master Smith Gao" end
 return Persistence.Transaction(id,function(p: any)
  assert(Forge.smith(id),"Visit Master Smith Gao");Rules.infuse(p,p.equippedLoadout.MainWeapon,affinity)
 end)
end
function Forge.Trade(id: number,item: string): (boolean,string?)
 local trade=Catalog.Trades[item];if not trade then return false,"Unknown trade" end
 local h=Catalog.NPCs.Hermit;local position=Vector3.new(h.X,h.Y,h.Z)
 if not near(id,position) then return false,"Visit the Wandering Hermit" end
 return Persistence.Transaction(id,function(p: any)
  assert(near(id,position),"Visit the Wandering Hermit");assert(p.qiEssence>=trade.Price,"Not enough Qi")
  p.qiEssence-=trade.Price;p.inventory.Materials[item]=(p.inventory.Materials[item] or 0)+1
 end)
end
return table.freeze(Forge)
