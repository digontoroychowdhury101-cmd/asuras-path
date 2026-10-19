--!strict
-- The RPG record owns data. Older world/arsenal code receives a synchronized compatibility view.
local hasScript=pcall(function() return script.Parent end)
local Shared: any=if hasScript then game:GetService("ReplicatedStorage").AsurasPath.Shared else nil
local Rules: any=if hasScript then require(Shared.ProgressionRules) else require("../shared/ProgressionRules")
local Arena: any=if hasScript then require(Shared.ArenaRules) else require("../shared/ArenaRules")
local Bridge={}
function Bridge.toSouls(p: any)
 local s=p.souls;local i=s.inventory
 s.essence=p.qiEssence;s.attributes=table.clone(p.attributes);s.level=Rules.level(p.attributes)
 s.world.bosses=table.clone(p.defeatedBosses);s.world.altars=table.clone(p.unlockedAltars)
 i.weapons={};i.reinforcement={}
 for id,w in p.inventory.Weapons do i.weapons[id]=true;if w.Level>0 then i.reinforcement[id]=w.Level end end
 i.spells=table.clone(p.inventory.Spells);i.mainhand=p.equippedLoadout.MainWeapon;i.offhand=p.equippedLoadout.OffWeapon or "None"
 i.spellSlots={p.equippedLoadout.SpellSlot1 or "ThunderclapPalm",p.equippedLoadout.SpellSlot2 or "GaleStep"}
 s.rpg={Materials=p.inventory.Materials,Weapons=p.inventory.Weapons,Mastery=p.weaponMastery}
 p.elo=p.colosseum.Elo;p.peakElo=math.max(p.peakElo,p.elo);p.wins=p.colosseum.Wins;p.losses=p.colosseum.Losses;p.winStreak=p.colosseum.WinStreak
end
function Bridge.snapshot(p: any): any
 return {qi=p.qiEssence,attributes=table.clone(p.attributes),levels=table.clone(p.souls.inventory.reinforcement),
  main=p.equippedLoadout.MainWeapon,off=p.souls.inventory.offhand,slots=table.clone(p.souls.inventory.spellSlots),
  elo=p.elo,wins=p.wins,losses=p.losses,streak=p.winStreak}
end
function Bridge.reconcile(p: any,b: any)
 local s=p.souls;local i=s.inventory
 if s.essence~=b.qi then p.qiEssence=s.essence end
 for _,key in Rules.Attributes do if s.attributes[key]~=b.attributes[key] then p.attributes[key]=s.attributes[key] end end
 for id,owned in i.weapons do
  if owned then
   if not p.inventory.Weapons[id] then p.inventory.Weapons[id]={Level=0} end
   local tier=i.reinforcement[id] or 0
   if tier~=(b.levels[id] or 0) then p.inventory.Weapons[id].Level=tier end
  end
 end
 for id,owned in i.spells do if owned then p.inventory.Spells[id]=true end end
 for id,flag in s.world.bosses do if flag then p.defeatedBosses[id]=true end end
 for id,flag in s.world.altars do if flag then p.unlockedAltars[id]=true end end
 if i.mainhand~=b.main then p.equippedLoadout.MainWeapon=i.mainhand end
 if i.offhand~=b.off then p.equippedLoadout.OffWeapon=if i.offhand=="None" then nil else i.offhand end
 for slot=1,2 do if i.spellSlots[slot]~=b.slots[slot] then p.equippedLoadout["SpellSlot"..slot]=i.spellSlots[slot] end end
 local c=p.colosseum
 if p.elo~=b.elo then c.Elo=p.elo end;if p.wins~=b.wins then c.Wins=p.wins end
 if p.losses~=b.losses then c.Losses=p.losses end;if p.winStreak~=b.streak then c.WinStreak=p.winStreak end
 c.Rank=Arena.rank(c.Elo,c.Wins+c.Losses+p.draws)
 Bridge.toSouls(p)
end
return table.freeze(Bridge)
