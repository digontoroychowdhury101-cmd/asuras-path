--!strict
-- Deterministic casting and status payloads, shared by runtime and CLI checks.
local hasScript=pcall(function() return script.Parent end)
local Spells: any=if hasScript then require(script.Parent.SpellSchema) else require("./SpellSchema")
local Weapons: any=if hasScript then require(script.Parent.WeaponSchema) else require("./WeaponSchema")
local Combat: any=if hasScript then require(script.Parent.CombatRules) else require("./CombatRules")
local Rules={}
export type Cast={Id: string,Start: number,Release: number,End: number,Potency: number}
function Rules.focus(f: any,offhand: string?): (number,boolean)
 local main=Weapons.get(f.Weapon)
 local off=if offhand then Weapons.Weapons[offhand] else nil
 return math.max(main.SpellPotency or 1,if off then off.SpellPotency or 1 else 1),main.QuickCast or (off~=nil and off.QuickCast==true)
end
function Rules.begin(f: any,id: string,now: number,cooldowns: {[string]: number},offhand: string?): (Cast?,string)
 local s=Spells.get(id)
 if not s then return nil,"Unknown spell" end
 if f.State~="Idle" or f.GuardHeld or f.RootUntil>now then return nil,"Cannot cast now" end
 if (cooldowns[id] or 0)>now then return nil,"Spell cooling down" end
 if f.Qi<s.QiCost then return nil,"Not enough Qi" end
 local potency,quick=Rules.focus(f,offhand)
 local timing=Spells.timing(s,quick)
 f.Qi-=s.QiCost;f.Sprinting=false;f.Move=nil
 f.State="Recovery";f.StateStart=now;f.StateEnd=now+timing.Total
 cooldowns[id]=now+s.Cooldown
 return {Id=id,Start=now,Release=now+timing.Startup,End=now+timing.Total,Potency=potency*(f.SpellScale or 1)},"Casting"
end
function Rules.valid(f: any,c: Cast): boolean
 return f.State=="Recovery" and f.Move==nil and f.StateStart==c.Start and f.ActiveHP>0
end
function Rules.payload(id: string,potency: number): any
 local s=assert(Spells.get(id),"Unknown spell")
 return {Damage=s.Damage*potency,Posture=s.Posture*potency,Burn=s.Status.Burn,Root=s.Status.Root,Drain=s.Status.Drain,
  Interrupt=s.Status.Interrupt,IgnoreGuard=s.Status.IgnoreGuard,Ward=s.Status.Ward,Teleport=s.Status.Teleport,Decoy=s.Status.Decoy}
end
function Rules.status(target: any,id: string,now: number)
 local s=assert(Spells.get(id))
 target.Stamina=math.max(0,target.Stamina-s.Status.Drain)
 if s.Status.Root>0 then target.RootUntil=math.max(target.RootUntil,now+s.Status.Root) end
 if s.Status.Interrupt and target.State~="KO" and target.State~="StanceBroken" and target.State~="DeathblowVictim" then
  target.Move=nil;target.Sprinting=false;target.State="Hitstun";target.StateStart=now;target.StateEnd=now+0.4
 end
end
function Rules.ward(f: any,now: number)
 f.WardUntil=now+30
end
function Rules.projectileParry(f: any,now: number): boolean
 return Weapons.get(f.Weapon).ProjectileParry==true and (f.State=="Blocking" or Combat.isDeflectTimed(f,now))
end
return table.freeze(Rules)
