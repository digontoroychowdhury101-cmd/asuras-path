--!strict
local hasScript=pcall(function() return script.Parent end)
local I: any=if hasScript then require(script.Parent.RPGInventory) else require("./RPGInventory")
local Rules: any=if hasScript then require(script.Parent.ProgressionRules) else require("./ProgressionRules")
local Arena: any=if hasScript then require(script.Parent.ArenaRules) else require("./ArenaRules")
local RPG={}
function RPG.apply(p: any,raw: any)
 raw=if type(raw)=="table" then raw else {}
 local s=if type(raw.souls)=="table" then raw.souls else {}
 local a=if type(raw.attributes)=="table" then raw.attributes else {}
 local s_attr=if type(s.attributes)=="table" then s.attributes else {}
 local world=if type(s.world)=="table" then s.world else {}
 p.qiEssence=if I.integer(raw.qiEssence,0,9007199254740991) then raw.qiEssence
  else (if I.integer(raw.fightCash,0,9007199254740991) then raw.fightCash else (if I.integer(s.essence,0,9007199254740991) then 0 else 500))+(if I.integer(s.essence,0,9007199254740991) then s.essence else 0)
 p.qiEssence=math.min(p.qiEssence,9007199254740991)
 p.attributes={}
 for _,name in Rules.Attributes do
  local value=a[name] or s_attr[name]
  if value==nil then value=if name=="Vigor" then (a.Vitality or s_attr.Vitality) elseif name=="Endurance" then (a.Qi or s_attr.Qi) else nil end
  p.attributes[name]=if I.integer(value,10,99) then value else 10
 end
 p.inventory=I.migrate(raw.inventory,s.inventory)
 local old=if type(s.inventory)=="table" then s.inventory else {}
 local loadout=if type(raw.equippedLoadout)=="table" then raw.equippedLoadout else {}
 local main=loadout.MainWeapon or old.mainhand;local off=loadout.OffWeapon or old.offhand
 p.equippedLoadout={MainWeapon=if type(main)=="string" and p.inventory.Weapons[main] then main else "Jian",
  OffWeapon=if type(off)=="string" and p.inventory.Weapons[off] then off else nil,ArmorSet=if I.id(loadout.ArmorSet) then loadout.ArmorSet else nil}
 for n=1,2 do
  local key="SpellSlot"..n;local id=loadout[key] or (if type(old.spellSlots)=="table" then (old.spellSlots :: any)[n] else nil)
  p.equippedLoadout[key]=if type(id)=="string" and p.inventory.Spells[id] then id else (if n==1 then "ThunderclapPalm" else "GaleStep")
 end
 p.defeatedBosses=I.flags(raw.defeatedBosses or world.bosses);p.unlockedAltars=I.flags(raw.unlockedAltars or world.altars)
 for id in I.flags(world.altars) do p.unlockedAltars[id]=true end
 for id in I.flags(world.bosses) do p.defeatedBosses[id]=true end
 p.unlockedAltars.Altar_SanctuaryBonfire=true
 local c=if type(raw.colosseum)=="table" then raw.colosseum else {}
 p.colosseum={Elo=if I.integer(c.Elo,0,5000) then c.Elo else p.elo,Wins=if I.integer(c.Wins,0,9007199254740991) then c.Wins else p.wins,
  Losses=if I.integer(c.Losses,0,9007199254740991) then c.Losses else p.losses,WinStreak=if I.integer(c.WinStreak,0,9007199254740991) then c.WinStreak else p.winStreak}
 p.colosseum.Rank=Arena.rank(p.colosseum.Elo,p.colosseum.Wins+p.colosseum.Losses+p.draws)
 p.weaponMastery={};for id,xp in (if type(raw.weaponMastery)=="table" then raw.weaponMastery else {}) do
  if p.inventory.Weapons[id] and I.integer(xp,0,9007199254740991) then p.weaponMastery[id]=xp end
 end
 p.arenaWagers={}
 for id,b in (if type(raw.arenaWagers)=="table" then raw.arenaWagers else {}) do
  assert(type(id)=="string" and #id<=64 and type(b)=="table" and I.integer(b.Fighter,-9007199254740991,9007199254740991)
   and Arena.validWager(b.Amount) and (b.State=="Pending" or b.State=="Settled"),"Corrupt wager ledger")
  p.arenaWagers[id]={Fighter=b.Fighter,Amount=b.Amount,State=b.State}
 end
end
function RPG.validate(p: any): (boolean,string?)
 if not I.integer(p.qiEssence,0,9007199254740991) or type(p.attributes)~="table" then return false,"Invalid Qi or attributes" end
 for _,key in Rules.Attributes do if not I.integer(p.attributes[key],10,99) then return false,"Invalid "..key end end
 if not I.validate(p.inventory) or type(p.equippedLoadout)~="table" then return false,"Invalid RPG inventory" end
 local l=p.equippedLoadout
 if not p.inventory.Weapons[l.MainWeapon] or (l.OffWeapon~=nil and not p.inventory.Weapons[l.OffWeapon]) then return false,"Unowned loadout" end
 for _,key in {"SpellSlot1","SpellSlot2"} do if l[key]~=nil and not p.inventory.Spells[l[key]] then return false,"Unowned spell" end end
 if l.ArmorSet~=nil and not I.id(l.ArmorSet) then return false,"Invalid armor" end
 for _,key in {"defeatedBosses","unlockedAltars"} do
  if type(p[key])~="table" then return false,"Missing flags" end
  local n=0;for id,v in p[key] do n+=1;if n>512 or not I.id(id) or v~=true then return false,"Invalid flags" end end
 end
 local c=p.colosseum;if type(c)~="table" or not I.integer(c.Elo,0,5000) then return false,"Invalid arena" end
 for _,key in {"Wins","Losses","WinStreak"} do if not I.integer(c[key],0,9007199254740991) then return false,"Invalid arena counter" end end
 if c.Rank~=Arena.rank(c.Elo,c.Wins+c.Losses+p.draws) then return false,"Invalid rank" end
 if type(p.weaponMastery)~="table" or type(p.arenaWagers)~="table" then return false,"Missing mastery or wagers" end
 for id,xp in p.weaponMastery do if not p.inventory.Weapons[id] or not I.integer(xp,0,9007199254740991) then return false,"Invalid mastery" end end
 local count=0;for id,b in p.arenaWagers do
  count+=1
  if count>512 or type(id)~="string" or #id==0 or #id>64 or type(b)~="table" or not I.integer(b.Fighter,-9007199254740991,9007199254740991)
   or not Arena.validWager(b.Amount) or (b.State~="Pending" and b.State~="Settled") then return false,"Invalid wager" end
 end
 return true,nil
end
return table.freeze(RPG)
