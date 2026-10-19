--!strict
-- Discovery and transmutation rewards are authored here, never supplied by clients.
export type Recipe={Boss: string,Kind: string,Reward: string,Name: string}
export type Cache={Name: string,Region: string,X: number,Y: number,Z: number,Weapon: string,Spells: {string},Extras: {string}?}
local Catalog={}
Catalog.Recipes={
 PrayerOfTheDefiled={Boss="GrandmasterShen",Kind="Weapon",Reward="PrayerOfTheDefiled",Name="Prayer of the Defiled"},
 AbbotDirge={Boss="GrandmasterShen",Kind="Spell",Reward="AbbotDirge",Name="Abbot's Dirge"},
 CalamityBoneCleaver={Boss="DemonicChimera",Kind="Weapon",Reward="CalamityBoneCleaver",Name="Calamity Bone Cleaver"},
 FissureSlam={Boss="DemonicChimera",Kind="Spell",Reward="FissureSlam",Name="Fissure Slam"},
 HeavenPiercingGuandao={Boss="AshPagodaGeneral",Kind="Weapon",Reward="HeavenPiercingGuandao",Name="Heaven-Piercing Guandao"},
 Thunderfall={Boss="AshPagodaGeneral",Kind="Spell",Reward="Thunderfall",Name="Thunderfall"},
} :: {[string]: Recipe}
Catalog.Caches={
 WaterfallAlcove={Name="Waterfall Alcove",Region="DesecratedMonastery",X=-140,Y=5,Z=-840,Weapon="ChainScythe",Spells={"HeavenlyLightningSpear"}},
 PagodaRafters={Name="High Pagoda Rafters",Region="DesecratedMonastery",X=92,Y=30,Z=-1000,Weapon="TwinDaggers",Spells={"DragonsMaw"},Extras={"Dao"}},
 SealedMausoleum={Name="Sealed Mausoleum",Region="DesecratedMonastery",X=-110,Y=3,Z=-1060,Weapon="Odachi",Spells={"GraveTendrils","BlackflameSurge"},Extras={"Guandao"}},
 SanctuaryEaves={Name="Loggia Eaves",Region="Sanctuary",X=-84,Y=621,Z=900,Weapon="WarFan",Spells={"JadeAegis"}},
 SanctuaryReliquary={Name="Cloud Reliquary",Region="Sanctuary",X=28,Y=602,Z=870,Weapon="Catalyst",Spells={"EmberCataclysm"}},
} :: {[string]: Cache}
Catalog.BossTokens={GrandmasterShen={"GrandmasterShen","DemonicChimera"},AshPagodaGeneral={"AshPagodaGeneral"}} :: {[string]: {string}}
local function freeze(t: any)
 for _,v in t do if type(v)=="table" then freeze(v) end end
 table.freeze(t)
end
freeze(Catalog)
return Catalog
