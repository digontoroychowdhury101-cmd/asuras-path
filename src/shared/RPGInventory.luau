--!strict
local hasScript=pcall(function() return script.Parent end)
local Rules: any=if hasScript then require(script.Parent.ProgressionRules) else require("./ProgressionRules")
local Weapons: any=if hasScript then require(script.Parent.Parent.Simulation.WeaponSchema) else require("../simulation/WeaponSchema")
local Spells: any=if hasScript then require(script.Parent.Parent.Simulation.SpellSchema) else require("../simulation/SpellSchema")
local Inventory={}
function Inventory.integer(v: any,lo: number,hi: number): boolean
 return type(v)=="number" and v==v and v>=lo and v<=hi and v%1==0
end
function Inventory.id(v: any): boolean
 return type(v)=="string" and #v>0 and #v<=64 and string.match(v,"^[%w_]+$")~=nil
end
function Inventory.flags(raw: any): {[string]: boolean}
 local result={};if type(raw)=="table" then for k,v in raw do if Inventory.id(k) and v==true then result[k]=true end end end;return result
end
function Inventory.defaults(): any
 return {Weapons={Unarmed={Level=0},Jian={Level=0}},Spells={ThunderclapPalm=true,GaleStep=true},Materials={},LoreEntries={}}
end
function Inventory.migrate(raw: any,legacy: any): any
 local i=Inventory.defaults();raw=if type(raw)=="table" then raw else {};legacy=if type(legacy)=="table" then legacy else {}
 for id,w in (if type(raw.Weapons)=="table" then raw.Weapons else {}) do
  if Weapons.Weapons[id] and type(w)=="table" then
   i.Weapons[id]={Level=if Inventory.integer(w.Level,0,10) then w.Level else 0,
    Infusion=if type(w.Infusion)=="string" and Rules.Infusions[w.Infusion] then w.Infusion else nil}
  end
 end
 for id,owned in (if type(legacy.weapons)=="table" then legacy.weapons else {}) do
  if owned==true and Weapons.Weapons[id] and not i.Weapons[id] then
   local tier=if type(legacy.reinforcement)=="table" then legacy.reinforcement[id] else nil
   i.Weapons[id]={Level=if Inventory.integer(tier,0,10) then tier else 0}
  elseif owned==true and i.Weapons[id] and raw.Weapons==nil then
   local tier=if type(legacy.reinforcement)=="table" then legacy.reinforcement[id] else nil
   if Inventory.integer(tier,0,10) then i.Weapons[id].Level=tier end
  end
 end
 for _,set in {raw.Spells,legacy.spells} do
  if type(set)=="table" then for id,flag in set do if flag==true and Spells.ById[id] then i.Spells[id]=true end end end
 end
 if type(raw.Materials)=="table" then
  for id,count in raw.Materials do if Inventory.id(id) and Inventory.integer(count,0,9007199254740991) then i.Materials[id]=count end end
 end
 i.LoreEntries=Inventory.flags(raw.LoreEntries);return i
end
function Inventory.validate(i: any): boolean
 if type(i)~="table" then return false end
 for _,key in {"Weapons","Spells","Materials","LoreEntries"} do
  if type(i[key])~="table" then return false end
  local n=0;for _ in i[key] do n+=1 end;if n>512 then return false end
 end
 for id,w in i.Weapons do
  if not Weapons.Weapons[id] or type(w)~="table" or not Inventory.integer(w.Level,0,10)
   or (w.Infusion~=nil and (type(w.Infusion)~="string" or not Rules.Infusions[w.Infusion])) then return false end
 end
 for id,v in i.Spells do if not Spells.ById[id] or v~=true then return false end end
 for id,v in i.Materials do if not Inventory.id(id) or not Inventory.integer(v,0,9007199254740991) then return false end end
 for id,v in i.LoreEntries do if not Inventory.id(id) or v~=true then return false end end
 return i.Weapons.Unarmed~=nil and i.Weapons.Jian~=nil
end
return table.freeze(Inventory)
