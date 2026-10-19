--!strict
-- Apply signature loadouts after the campaign roster has finished authoring its phases.
local Armaments={}
function Armaments.apply(world: any)
 local shen=world.Bosses.GrandmasterShen
 -- The campaign duel retains its Jian -> Guandao transformation; remembrance rewards remain available.
 if shen.Archetype~="Duelist" then
  shen.Phases[1].Weapon="PrayerOfTheDefiled"
  shen.Phases[2].Weapon="CalamityBoneCleaver"
 end
 local phase=table.clone(shen.Phases[1])
 phase.Weapon="HeavenPiercingGuandao";phase.Name="Storm of the Ash Pagoda";phase.AnimationSet="ThunderGeneral"
 phase.Stats={MaxHP=700,MaxStamina=180,PostureCapacity=200,StrengthScale=1.3,DexterityScale=1.4,PoiseArmor=0.35}
 phase.Special=nil;phase.Transition=nil;phase.GapCloser=nil
 local zhao=world.Bosses.TwinSentinels
 if zhao then phase.Attacks=zhao.Phases[1].Attacks;phase.AttackInterval=4 end
 world.Bosses.AshPagodaGeneral={Id="AshPagodaGeneral",Name="General of the Ash Pagoda",Title="General of the Ash Pagoda",
  Region="BambooPass",Archetype="Duelist",Scale=1.2,Victory="GREAT FOE VANQUISHED",
  Arena={Center={X=0,Y=20,Z=-1615},Size={X=150,Y=60,Z=120}},Spawn={X=0,Y=3,Z=-1640,Yaw=180},
  FogGate="Gate_AshPagoda",Essence=2500,Phases={phase},BodyColor={95,115,145}}
 world.FogGates.Gate_AshPagoda={Id="Gate_AshPagoda",Boss="AshPagodaGeneral",Placement={X=0,Y=10,Z=-1554,Yaw=0},Size={X=26,Y=20,Z=1.5},
  Trigger={Center={X=0,Y=10,Z=-1570},Size={X=30,Y=20,Z=14}},Inside={X=0,Y=3,Z=-1570,Yaw=0},Outside={X=0,Y=3,Z=-1540,Yaw=0}}
end
return table.freeze(Armaments)
