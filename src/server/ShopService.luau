--!nonstrict
local Shared=game:GetService("ReplicatedStorage").AsurasPath
local Catalog=require(Shared.ShopCatalog)
local Schema=require(Shared.ProfileSchema)
local Config=require(Shared.Config)
local Persistence=require(script.Parent.PersistenceService)
local Shop={}
local rng=Random.new()
local policyCache={}
local function canRoll(id)
 if not Config.Release.PurchasesIntegrationPassed then return true end
 -- Cash/spins are potentially paid once product delivery is enabled. Fail closed on policy errors.
 local cached=policyCache[id]
 if cached and cached.expires>os.clock() then return cached.allowed end
 local player=game:GetService("Players"):GetPlayerByUserId(id)
 if not player then return false end
 local ok,info=pcall(function() return game:GetService("PolicyService"):GetPolicyInfoForPlayerAsync(player) end)
 local allowed=ok and type(info)=="table" and info.ArePaidRandomItemsRestricted==false
 policyCache[id]={allowed=allowed,expires=os.clock()+60}
 return allowed
end
function Shop.RollStyle(id,useToken)
 if not canRoll(id) then return false,"Random purchases are unavailable for this account" end
 local selected,isDuplicate
 local seed=rng:NextNumber() -- Stable across UpdateAsync callback retries.
 local ok,err=Persistence.Transaction(id,function(p)
  if useToken then assert(p.styleSpins>0,"No style spins remaining");p.styleSpins-=1
  else assert(p.fightCash>=Catalog.SpinCostCash,"Insufficient Fight Cash");p.fightCash-=Catalog.SpinCostCash end
  p.pityCounter+=1
  local pool,total={},0
  for _,s in Catalog.Styles do
   if p.pityCounter<Catalog.PityThreshold or s.rarity=="Epic" or s.rarity=="Legendary" then
    table.insert(pool,s);total+=s.weight
   end
  end
  local roll=math.floor(seed*total)+1
  for _,s in pool do roll-=s.weight;if roll<=0 then selected=s;break end end
  if selected.rarity=="Epic" or selected.rarity=="Legendary" then p.pityCounter=0 end
  local entry=assert(p.styles[selected.name]);isDuplicate=entry.unlocked
  if isDuplicate then
   entry.xp+=Catalog.DuplicateXpBonus*(if p.ownedCosmetics.VIP_Pass then 2 else 1)
   entry.level=Schema.Level(entry.xp)
  else entry.unlocked=true end
 end)
 return ok,err,if ok then selected else nil,if ok then isDuplicate else nil
end
function Shop.RollCrate(id,crateId)
 if not canRoll(id) then return false,"Random purchases are unavailable for this account" end
 local crate=Catalog.Crates[crateId]
 if not crate then return false,"Unknown crate" end
 local seed=rng:NextNumber()
 local selected,duplicate
 local ok,err=Persistence.Transaction(id,function(p)
  assert(p.fightCash>=crate.cost,"Insufficient Fight Cash")
  local roll=math.floor(seed*100)+1
  for _,drop in crate.drops do roll-=drop.weight;if roll<=0 then selected=drop.id;break end end
  assert(selected,"Invalid crate odds")
  duplicate=p.ownedCosmetics[selected]==true
  p.fightCash-=crate.cost
  if duplicate then p.fightCash+=crate.refund else p.ownedCosmetics[selected]=true end
 end)
 return ok,err,if ok then selected else nil,if ok then duplicate else nil
end
function Shop.BuyCosmetic(id,itemId)
 local item=Catalog.Cosmetics[itemId];if not item then return false,"Unknown cosmetic" end
 return Persistence.Transaction(id,function(p)
  assert(not p.ownedCosmetics[itemId],"Already owned");assert(p.fightCash>=item.cashPrice,"Insufficient Fight Cash")
  p.fightCash-=item.cashPrice;p.ownedCosmetics[itemId]=true
 end)
end
function Shop.EquipCosmetic(id,itemId)
 local item=Catalog.Cosmetics[itemId];if not item then return false,"Unknown cosmetic" end
 return Persistence.Transaction(id,function(p) assert(p.ownedCosmetics[itemId],"Item is locked");p.equippedCosmetics[item.slot]=itemId end)
end
function Shop.EquipStyle(id,name)
 return Persistence.Transaction(id,function(p) assert(p.styles[name] and p.styles[name].unlocked,"Style is locked");p.activeStyle=name end)
end
function Shop.SaveSettings(id,settings)
 if settings.keybinds~=nil and not Schema.ValidKeybinds(settings.keybinds) then return false,"Invalid or conflicting keybinds" end
 return Persistence.Transaction(id,function(p)
  p.settings.fov=settings.fov;p.settings.sensitivity=settings.sensitivity;p.settings.leftHanded=settings.leftHanded
  if settings.keybinds then p.settings.keybinds=table.clone(settings.keybinds) end
 end)
end
function Shop.BuyBundle() return false,"Developer products require a durable receipt" end
-- Shared server-side grant body for real delivery and the isolated synthetic adapter.
function Shop.GrantBundle(p,bundle)
 if bundle.bundleType=="Cash" then p.fightCash+=bundle.amount
 elseif bundle.bundleType=="Spins" then p.styleSpins+=bundle.amount
 elseif bundle.bundleType=="Pass" then p.ownedCosmetics.VIP_Pass=true
 else error("Unsupported product") end
end
function Shop.ProcessReceipt(receipt)
 local decision=Enum.ProductPurchaseDecision
 -- Delivery of outstanding receipts is independent of whether new purchase prompts are enabled.
 if not Config.Release.PurchasesIntegrationPassed then return decision.NotProcessedYet end
 if not Persistence.Get(receipt.PlayerId) then return decision.NotProcessedYet end
 local bundle
 for _,b in Catalog.Bundles do if b.productId==receipt.ProductId then bundle=b;break end end
 if not bundle then return decision.NotProcessedYet end
 local ok=Persistence.ProcessReceipt(receipt.PlayerId,receipt.PurchaseId,receipt.ProductId,function(p)
  Shop.GrantBundle(p,bundle)
 end)
 return if ok then decision.PurchaseGranted else decision.NotProcessedYet
end
return Shop
