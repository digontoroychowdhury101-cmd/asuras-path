--!strict
-- Discovery and transmutation rewards are authored here, never supplied by clients.
export type Recipe={Boss: string,Kind: string,Reward: string,Name: string}
export type Cache={Name: string,Region: string,X: number,Y: number,Z: number,Weapon: string,Spells: {string},Extras: {string}?}
local Catalog={}
Catalog.Recipes={
 -- Every sovereign's remembrance offers one weapon or one sorcery (One soul, one choice). Shen's
 -- duel also yields the Demonic Chimera token for his second phase. Recipe ids are stable.
 PrayerOfTheDefiled={Boss="GrandmasterShen",Kind="Weapon",Reward="PrayerOfTheDefiled",Name="Prayer of the Defiled"},
 AbbotDirge={Boss="GrandmasterShen",Kind="Spell",Reward="AbbotDirge",Name="Abbot's Dirge"},
 CalamityBoneCleaver={Boss="DemonicChimera",Kind="Weapon",Reward="CalamityBoneCleaver",Name="Calamity Bone Cleaver"},
 FissureSlam={Boss="DemonicChimera",Kind="Spell",Reward="FissureSlam",Name="Fissure Slam"},
 BaizeTessen={Boss="VenerableBaize",Kind="Weapon",Reward="WarFan",Name="Iron Tessen of the Frosted Ridge"},
 BaizeWindSlash={Boss="VenerableBaize",Kind="Spell",Reward="WindSlash",Name="Wind-Cutting Slash"},
 TitanOdachi={Boss="SlumberingTitan",Kind="Weapon",Reward="Odachi",Name="Colossal Odachi of the Crypt"},
 TitanGraveTendrils={Boss="SlumberingTitan",Kind="Spell",Reward="GraveTendrils",Name="Grave Tendrils"},
 WuSpellStaff={Boss="SovereignWu",Kind="Weapon",Reward="Catalyst",Name="Starless Jade Spell Staff"},
 WuBlackflameSurge={Boss="SovereignWu",Kind="Spell",Reward="BlackflameSurge",Name="Blackflame Surge"},
 HeavenPiercingGuandao={Boss="TwinSentinels",Kind="Weapon",Reward="HeavenPiercingGuandao",Name="Heaven-Piercing Guandao"},
 Thunderfall={Boss="TwinSentinels",Kind="Spell",Reward="Thunderfall",Name="Thunderfall"},
 WyrmChainScythe={Boss="AzureWyrm",Kind="Weapon",Reward="ChainScythe",Name="Azure Chain Scythe"},
 WyrmDragonsMaw={Boss="AzureWyrm",Kind="Spell",Reward="DragonsMaw",Name="Dragon's Maw"},
} :: {[string]: Recipe}
-- Batch 16: the two Sanctuary caches moved onto deliberate routes (SanctuaryRoutes): the eaves deck
-- past the loggia roof line (it sat inside the roof ridge) and the cloud isle off the descent pavilion.
Catalog.Caches={
 WaterfallAlcove={Name="Waterfall Alcove",Region="DesecratedMonastery",X=-140,Y=5,Z=-840,Weapon="ChainScythe",Spells={"HeavenlyLightningSpear"}},
 PagodaRafters={Name="High Pagoda Rafters",Region="DesecratedMonastery",X=92,Y=30,Z=-1000,Weapon="TwinDaggers",Spells={"DragonsMaw"},Extras={"Dao"}},
 SealedMausoleum={Name="Sealed Mausoleum",Region="DesecratedMonastery",X=-110,Y=3,Z=-1060,Weapon="Odachi",Spells={"GraveTendrils","BlackflameSurge"},Extras={"Guandao"}},
 SanctuaryEaves={Name="Loggia Eaves",Region="Sanctuary",X=-76,Y=617,Z=923,Weapon="WarFan",Spells={"JadeAegis"}},
 SanctuaryReliquary={Name="Cloud Reliquary",Region="Sanctuary",X=46,Y=605,Z=988,Weapon="Catalyst",Spells={"EmberCataclysm"}},
} :: {[string]: Cache}
-- Practical use, authored as words only: every number on an Arsenal card is derived from
-- SpellSchema / WeaponSchema and the scaling rules (ArsenalFacts), never written here.
Catalog.SpellUses={
 ThunderclapPalm="Close-range burst that staggers whoever is in front of you; punishes a foe mid-swing.",
 HeavenlyLightningSpear="Long piercing bolt for picking off foes at range or lining up several at once.",
 DragonsMaw="Short flame cone that keeps burning; best against foes who stay in front of you.",
 EmberCataclysm="Calls fire pillars onto nearby foes in turn; strong against groups, slow to come out.",
 BlackflameSurge="Wide void sweep that hits through a raised guard.",
 GraveTendrils="Roots foes where they stand, opening them to follow-up strikes or escape.",
 JadeAegis="Defensive seal on yourself that saves you from one posture break.",
 GaleStep="Instant dash that leaves a phantom behind; repositions or escapes a combo.",
 AbbotDirge="Lingering dirge around you that interrupts and saps stamina from anyone close.",
 FissureSlam="Ground-splitting line that breaks posture hard and leaves burning ground.",
 Thunderfall="Hurls lightning at a distant point and carries you to it.",
 WindSlash="Cheap ranged cut for chip damage between melee exchanges.",
} :: {[string]: string}
Catalog.WeaponUses={
 Unarmed="Fast, close palm strikes; scales with Strength.",
 Jian="Balanced one-handed sword with quick strings; a reliable all-rounder.",
 Dao="Heavier one-handed sabre: slightly slower, harder-hitting cuts.",
 Guandao="Two-handed glaive that controls space with long sweeps; scales with Strength.",
 Odachi="Colossal blade: slow, very long reach and crushing hits; scales with Strength.",
 TwinDaggers="Light, fast sai built for aggression and devastating rear strikes.",
 ChainScythe="Longest reach in the arsenal; whips foes from a safe distance.",
 WarFan="Light defensive fan whose guard can turn projectiles aside.",
 Catalyst="Spell staff: strengthens and quickens sorcery, light in melee.",
 PrayerOfTheDefiled="Shen's two-handed relic; reflects posture damage back at attackers.",
 CalamityBoneCleaver="The Chimera's colossal cleaver: slow, enormous hits; scales with Strength.",
 HeavenPiercingGuandao="General Zhao's lightning glaive; long reach, scales with Strength.",
} :: {[string]: string}
Catalog.BossTokens={GrandmasterShen={"GrandmasterShen","DemonicChimera"}} :: {[string]: {string}}
-- Retired encounter ids still found in old profiles map to the sovereign that now carries their
-- rewards: the Ash Pagoda General's lightning glaive and Thunderfall belong to General Zhao.
Catalog.LegacyBosses={AshPagodaGeneral="TwinSentinels"} :: {[string]: string}
-- Forge card state lines (words only; %s is the sovereign's name).
Catalog.ForgeStates={Ready="Remembrance held: forging is permanent and spends it",Spent="Already forged from this remembrance",
 Owned="Already yours: choose this soul's other gift",Locked="Defeat %s to earn its remembrance"} :: {[string]: string}
-- Display order in Gao's forge: the six sovereigns, Shen's Chimera token after Shen.
Catalog.TokenOrder={"GrandmasterShen","DemonicChimera","VenerableBaize","SlumberingTitan","SovereignWu","TwinSentinels","AzureWyrm"} :: {string}
local function freeze(t: any)
 for _,v in t do if type(v)=="table" then freeze(v) end end
 table.freeze(t)
end
freeze(Catalog)
return Catalog
