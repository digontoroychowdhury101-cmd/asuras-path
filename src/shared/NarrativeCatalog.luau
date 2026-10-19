--!strict
export type Choice={Label: string,Next: string?,Action: string?,Close: boolean?}
export type Node={Text: string,Choices: {Choice}}
export type NPC={Name: string,X: number,Y: number,Z: number,Color: {number},Start: string,Nodes: {[string]: Node}}
export type Lore={Title: string,Region: string,X: number,Y: number,Z: number,Qi: number,Text: string}
export type Trade={Name: string,Price: number}
local Catalog: {Premise: string,NPCs: {[string]: NPC},Lore: {[string]: Lore},Trades: {[string]: Trade},Sovereigns: {string},LoreOrder: {string}}={Premise="",NPCs={},Lore={},Trades={},Sovereigns={},LoreOrder={}}
Catalog.Premise="Grandmaster Shen devoured his disciples and shattered the celestial pillars. You are an Asura Emissary: a wandering phantom barred from the afterlife until the six Fallen Sovereigns are laid to rest."
Catalog.NPCs={
 Gao={Name="Master Smith Gao",X=-86,Y=603,Z=899,Color={74,57,49},Start="Greeting",Nodes={
  Greeting={Text="I lost my eyes to the <i>Jade Cataclysm</i>. Still, I can hear the blood upon your blade. What burden have you brought?",Choices={
   {Label="Reinforce or infuse my weapon",Next="Forge",Action="Forge"},{Label="What can a sovereign's soul become?",Next="Remembrance"},{Label="Farewell",Close=true}}},
  Forge={Text="Iron remembers every wound. Bring ore, starfall, and dragonite; I will teach your steel to remember you.",Choices={{Label="Return",Next="Greeting"},{Label="Farewell",Close=true}}},
  Remembrance={Text="A fallen sovereign leaves a remembrance. Discover one and its weapon or sorcery becomes yours to forge. One soul, one choice.",Choices={{Label="Show discovered remembrances",Next="Greeting",Action="Arsenal"},{Label="Return",Next="Greeting"}}},
 }},
 Lin={Name="Lady Lin · Shrine Maiden",X=8,Y=603,Z=918,Color={145,121,117},Start="Greeting",Nodes={
  Greeting={Text="Emissary, the incense knows your name. Your soul cannot cross while the six sovereigns bind the Abyss. Rest, and let stolen Qi become strength.",Choices={
   {Label="Guide my Ascension",Next="Ascend",Action="Level"},{Label="Tell me of Shen",Next="Shen"},{Label="Farewell",Close=true}}},
  Ascend={Text="Vigor shelters the soul. Endurance steadies the stance. Strength and Dexterity guide steel; Arcane Qi gives sorrow a voice.",Choices={{Label="Return",Next="Greeting"},{Label="Farewell",Close=true}}},
  Shen={Text="He called it salvation. Six disciples became sovereigns, their souls chained to the broken pillars. Lay all six to rest, and the road beyond death may open.",Choices={{Label="Return",Next="Greeting"}}},
 }},
 Hermit={Name="Wandering Hermit",X=-14,Y=3,Z=-738,Color={77,86,70},Start="Greeting",Nodes={
  Greeting={Text="The gate remembers footsteps that have yet to fall. A talisman, phantom? Or the price of knowing?",Choices={
   {Label="Trade for talismans and gems",Next="Trade",Action="Trade"},{Label="Whisper a sovereign's weakness",Next="Weakness"},{Label="Farewell",Close=true}}},
  Trade={Text="A ward may turn a fatal blow. Ore will never rust in a phantom's hand. My prices are fixed; the Abyss has had enough chance.",Choices={{Label="Return",Next="Greeting"},{Label="Farewell",Close=true}}},
  Weakness={Text="Deflect Shen's discipline, evade his hunger. Leap over the frost serpent's sweep. Strike the titan's ankles; separate the twin sentinels before their grief becomes one.",Choices={{Label="Return",Next="Greeting"}}},
 }},
}
Catalog.Lore={
 Pillars={Title="I · The Six Pillars",Region="DesecratedMonastery",X=-24,Y=3,Z=-766,Qi=100,Text="Six celestial pillars held the Abyss beneath the jade mountain. Each bore a disciple's vow. Shen alone was trusted with their names."},
 Feast={Title="II · The Last Supper",Region="DesecratedMonastery",X=48,Y=3,Z=-830,Qi=125,Text="The bowls were set for seven. At dawn, only the master's shadow remained. It cast six faces upon the wall."},
 Bell={Title="III · A Bell Without Echo",Region="DesecratedMonastery",X=-55,Y=3,Z=-918,Qi=125,Text="The monastery bell rang once when the first pillar fell. The second swallowed its echo. The sixth silenced the dead."},
 Emissary={Title="IV · The Uncrossed River",Region="DesecratedMonastery",X=72,Y=3,Z=-1070,Qi=150,Text="A phantom stood at the river of souls. The ferryman counted six chains around its heart. 'Return them to rest,' he said, 'and I shall return for you.'"},
 Bamboo={Title="V · Jade in the Roots",Region="BambooPass",X=28,Y=3,Z=-1235,Qi=150,Text="Jade splinters fell like rain. Bamboo drank the scattered Qi, and its leaves began to whisper the disciples' forgotten prayers."},
 Wraith={Title="VI · What Death Cannot Keep",Region="BambooPass",X=-48,Y=3,Z=-1490,Qi=175,Text="The Emissary left a crimson wraith where its borrowed body fell. One memory could be reclaimed. A second death erased the first."},
 Pagoda={Title="VII · The Empty Throne",Region="CelestialPagoda",X=-33,Y=3,Z=-2258,Qi=200,Text="Above the clouded stair, the throne stood empty. Sovereignty was never a crown. It was the wound left where a soul had been."},
 Dawn={Title="VIII · The Unwritten Dawn",Region="CelestialPagoda",X=35,Y=3,Z=-2470,Qi=250,Text="Gao forged no chain for the seventh soul. Lin kept no incense for its passing. The hermit alone smiled: 'Some endings must be chosen by the dead.'"},
}
Catalog.Trades={SpiritIronOre={Name="Spirit Iron Ore",Price=80},StarfallShard={Name="Starfall Shard",Price=240},DragoniteCore={Name="Dragonite Core",Price=700},
 CrimsonFireGem={Name="Crimson Fire Gem",Price=600},CelestialLightningGem={Name="Celestial Lightning Gem",Price=600},AbyssalVoidGem={Name="Abyssal Void Gem",Price=600},
 LastBreathTalisman={Name="Last Breath Talisman · prevents one fatal blow for 30s",Price=400}}
Catalog.Sovereigns={"GrandmasterShen","VenerableBaize","SlumberingTitan","SovereignWu","TwinSentinels","AzureWyrm"}
Catalog.LoreOrder={"Pillars","Feast","Bell","Emissary","Bamboo","Wraith","Pagoda","Dawn"}
Catalog.NPCs.Lin.Nodes.Release={Text="Six chains have fallen silent. The ferryman waits beyond the jade dawn. You may cross, Emissary—or remain a little longer, and carry their names where the living have forgotten.",Choices={{Label="Guide my Ascension",Next="Ascend",Action="Level"},{Label="I will carry their names",Close=true}}}
local function freeze(t: any) for _,v in t do if type(v)=="table" then freeze(v) end end;table.freeze(t) end
freeze(Catalog)
return Catalog
