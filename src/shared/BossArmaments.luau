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
 -- The former "General of the Ash Pagoda" (a thunder clone of Shen's first phase in the Bamboo Pass)
 -- is retired: General Zhao of the Twin Sentinels now carries its glaive and Thunderfall, and
 -- ArsenalCatalog.LegacyBosses re-keys its old remembrance tokens and defeat records.
 world.Bosses.AshPagodaGeneral=nil
 world.FogGates.Gate_AshPagoda=nil
end
return table.freeze(Armaments)
