--!strict
local hasScript=pcall(function() return script.Parent end)
local Catalog: any=if hasScript then require(script.Parent.Parent.Shared.ArsenalCatalog) else require("../shared/ArsenalCatalog")
local Spells: any=if hasScript then require(script.Parent.SpellSchema) else require("./SpellSchema")
export type Token={Id: string,Kind: string,Boss: string}
export type Inventory={spells: {[string]: boolean},spellSlots: {string},remembrances: {[string]: Token},spentRemembrances: {[string]: boolean},caches: {[string]: boolean}}
local World: any=if hasScript then require(script.Parent.Parent.Shared.WorldDefinitions) else require("../shared/WorldDefinitions")
local Inventory={}
function Inventory.defaults(): Inventory
 return {spells={ThunderclapPalm=true,GaleStep=true},spellSlots={"ThunderclapPalm","GaleStep"},remembrances={},spentRemembrances={},caches={}}
end
local function bosses(): {[string]: boolean}
 local result={}
 for _,r in Catalog.Recipes do result[r.Boss]=true end
 for id in World.Bosses do result[id]=true end
 return result
end
local BOSSES=bosses()
local LEGACY: {[string]: string}=Catalog.LegacyBosses
local function token(id: string): Token return table.freeze({Id="BossRemembrance_"..id,Kind="BossRemembrance",Boss=id}) end
-- A held remembrance is a token object (never a boolean flag).
local function wellFormed(t: any,id: string): boolean
 return type(t)=="table" and t.Kind=="BossRemembrance" and t.Boss==id and t.Id=="BossRemembrance_"..id
end
function Inventory.canonical(boss: string): string return LEGACY[boss] or boss end
function Inventory.owns(i: any,boss: string): boolean
 return type(i)=="table" and type(i.remembrances)=="table" and wellFormed(i.remembrances[boss],boss)
end
-- Idempotent: a repeated victory, replay or rejoin never adds, renews or un-spends a token.
function Inventory.award(i: any,boss: string)
 local id0=Inventory.canonical(boss)
 for _,id in Catalog.BossTokens[id0] or (if BOSSES[id0] then {id0} else {}) do
  if not i.remembrances[id] then i.remembrances[id]=token(id) end
 end
end
export type RecipeState="Ready"|"Spent"|"Owned"|"Locked"
-- What Gao's forge may do with one recipe for this inventory; the server forge uses the same rule.
function Inventory.recipeState(i: any,recipeId: string): RecipeState
 local r=Catalog.Recipes[recipeId]
 if not r or not Inventory.owns(i,r.Boss) then return "Locked" end
 if i.spentRemembrances[r.Boss]==true then return "Spent" end
 local owned=if r.Kind=="Weapon" then i.weapons else i.spells
 return if type(owned)=="table" and owned[r.Reward] then "Owned" else "Ready"
end
function Inventory.migrate(raw: any): Inventory
 local result=Inventory.defaults()
 if type(raw)~="table" then return result end
 for _,key in {"spells","caches","spentRemembrances"} do
  if type(raw[key])=="table" then
   for id,flag in raw[key] do
    local valid=if key=="spells" then Spells.ById[id]~=nil elseif key=="caches" then Catalog.Caches[id]~=nil else BOSSES[id]==true
    if valid and flag==true then (result :: any)[key][id]=true end
   end
  end
 end
 if type(raw.remembrances)=="table" then
  for id,t in raw.remembrances do
   local to=Inventory.canonical(id)
   if (BOSSES[id] or LEGACY[id]) and BOSSES[to] and wellFormed(t,id) then result.remembrances[to]=token(to) end
  end
 end
 -- Legacy spent flags consume the canonical token's forging right (merged, never reset).
 if type(raw.spentRemembrances)=="table" then
  for id,flag in raw.spentRemembrances do if LEGACY[id] and flag==true then result.spentRemembrances[LEGACY[id]]=true end end
 end
 for id in result.spentRemembrances do if not result.remembrances[id] then result.spentRemembrances[id]=nil end end
 -- A claimed cache grants every spell it holds now, including spells added after the claim.
 for id in result.caches do for _,spell in Catalog.Caches[id].Spells do if Spells.ById[spell] then result.spells[spell]=true end end end
 if type(raw.spellSlots)=="table" then
  for slot=1,2 do local id=raw.spellSlots[slot];if type(id)=="string" and result.spells[id] then result.spellSlots[slot]=id end end
 end
 return result
end
function Inventory.validate(i: any): boolean
 if type(i)~="table" then return false end
 for _,key in {"spells","caches","remembrances","spentRemembrances","spellSlots"} do if type(i[key])~="table" then return false end end
 for id,owned in i.spells do if not Spells.ById[id] or owned~=true then return false end end
 if #i.spellSlots~=2 then return false end
 for slot,id in i.spellSlots do if (slot~=1 and slot~=2) or not i.spells[id] then return false end end
 -- Retired ids (LegacyBosses) are accepted so older profiles load; migrate() re-keys them.
 for id,t in i.remembrances do
  if not (BOSSES[id] or LEGACY[id]) or not wellFormed(t,id) then return false end
 end
 for id,spent in i.spentRemembrances do if not i.remembrances[id] or spent~=true then return false end end
 for id,claimed in i.caches do if not Catalog.Caches[id] or claimed~=true then return false end end
 return true
end
function Inventory.forge(i: any,recipeId: string): (boolean,string)
 local r=Catalog.Recipes[recipeId]
 if not r then return false,"Unknown recipe" end
 local state=Inventory.recipeState(i,recipeId)
 if state=="Locked" or state=="Spent" then return false,"Remembrance unavailable" end
 if state=="Owned" then return false,"Already owned" end
 local owned=if r.Kind=="Weapon" then i.weapons else i.spells
 -- Preserve the immutable token as provenance; a separate spent flag consumes its forging right.
 i.spentRemembrances[r.Boss]=true;owned[r.Reward]=true
 return true,"Forged "..r.Name
end
function Inventory.claim(i: any,cacheId: string): (boolean,string)
 local c=Catalog.Caches[cacheId]
 if not c then return false,"Unknown cache" end
 if i.caches[cacheId] then return false,"Cache already discovered" end
 i.caches[cacheId]=true;i.weapons[c.Weapon]=true
 for _,id in c.Spells do i.spells[id]=true end
 for _,id in c.Extras or {} do i.weapons[id]=true end
 return true,"Discovered "..c.Name
end
return table.freeze(Inventory)
