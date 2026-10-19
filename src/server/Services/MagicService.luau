--!strict
local Players=game:GetService("Players")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath")
local Spells=require(Shared.Simulation.SpellSchema)
local Rules=require(Shared.Simulation.SpellRules)
local Protocol=require(Shared.Shared.ArsenalProtocol)
local Budget=require(Shared.Shared.IntentProtocol)
local Characters=require(script.Parent.CharacterService)
local Persistence=require(script.Parent.PersistenceService) :: any
local Effects=require(script.Parent.SpellEffects)
local remote=Shared.Net:WaitForChild("ArsenalIntent") :: RemoteEvent
local Magic={}
local pending: {[number]: {Cast: Rules.Cast,Actor: any,Fighter: any}}={}
local cooldowns: {[number]: {[string]: number}}={}
local buckets: {[number]: Budget.Bucket}={}
local connections: {RBXScriptConnection}={}
local disconnect: (() -> ())?=nil
function Magic.Cast(userId: number,slot: number): (boolean,string)
 local actor=Characters.GetActor(userId);local profile=Persistence.Get(userId)
 if not actor or not profile or pending[userId] then return false,"Unavailable" end
 local inventory=profile.souls.inventory;local id=inventory.spellSlots[slot]
 if not id or not inventory.spells[id] then return false,"Spell is locked" end
 local cd=cooldowns[userId] or {};cooldowns[userId]=cd
 local cast,reason=Rules.begin(actor.Fighter,id,Characters.Now(),cd,inventory.offhand)
 if not cast then return false,reason end
 pending[userId]={Cast=cast,Actor=actor,Fighter=actor.Fighter}
 Characters.Cue("SpellStartup",userId,{spell=id,release=cast.Release,finish=cast.End,position=actor.Root.Position})
 remote:FireClient(actor.Player,{action="Cooldown",id=id,untilTime=cd[id]})
 return true,reason
end
function Magic.Cooldowns(userId: number): {[string]: number}
 return table.clone(cooldowns[userId] or {})
end
function Magic.ReleaseArt(actor: any,id: string,now: number)
 if Spells.get(id) then Effects.release(actor,id,1,now) end
end
function Magic.Start()
 assert(not disconnect,"MagicService already started")
 disconnect=Characters.OnStep(function(now: number,dt: number)
  for id,p in pending do
   if Characters.GetActor(id)~=p.Actor or p.Actor.Fighter~=p.Fighter or not Rules.valid(p.Fighter,p.Cast) then
    pending[id]=nil;Characters.Cue("SpellInterrupted",id,{spell=p.Cast.Id})
   elseif now>=p.Cast.Release then pending[id]=nil;Effects.release(p.Actor,p.Cast.Id,p.Cast.Potency,now) end
  end
  Effects.step(now,dt)
 end)
 table.insert(connections,remote.OnServerEvent:Connect(function(player: Player,packet: any)
  if not Protocol.valid(packet) or packet.action~="Cast" then return end
  local now=Characters.Now();local bucket=buckets[player.UserId] or {tokens=4,time=now};buckets[player.UserId]=bucket
  if not Budget.Take(bucket,now,1,3,4) then return end
  local ok,reason=Magic.Cast(player.UserId,packet.slot)
  remote:FireClient(player,{action="Result",ok=ok,message=reason})
 end))
 table.insert(connections,Players.PlayerRemoving:Connect(function(player: Player)
  pending[player.UserId]=nil;cooldowns[player.UserId]=nil;buckets[player.UserId]=nil
 end))
end
function Magic.Destroy()
 if disconnect then disconnect();disconnect=nil end
 for _,c in connections do c:Disconnect() end
 table.clear(connections);table.clear(pending);table.clear(cooldowns);table.clear(buckets);Effects.clear()
end
return Magic
