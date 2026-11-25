# Genre research: what top action-RPG / combat games do, and what Asura's Path should copy

Date written: 2026-11-25. Author: research agent (read-only on the repo).
Context read: PROJECT_STATE.md (top), outputs/claude-open-world-2026-11-14/handoff/CLAUDE_RETURN_HANDOFF.md. GLOSSARY.md does not exist.

## How to read the numbers

- "Live" figures were pulled on 2026-11-25 straight from Roblox's public endpoints (games.roblox.com/v1/games, apis.roblox.com/search-api/omni-search, apis.roblox.com/game-passes/v1). They are a single snapshot, not a peak. Halloween event titles are still in the names, so CCU may be slightly event-inflated.
- RoMonitor, Rolimons and RoWatcher pages mostly would not load or returned empty; peak figures come from secondary trackers. Anything marked [UNVERIFIED] is a single secondary source or conflicts with another.
- Where a source gave no date I say so. I could not reach Reddit or YouTube through the tools, so community criticism comes from review sites and wikis, not threads. That is a real gap.
- Several third-party blogs (earnaldo, ejaw, heycash) are affiliate/SEO sites. I used them only for figures that match the live API.

## Part A: Roblox games

### A0. Market snapshot

- Bloxodes October 2026 report (updated 2026-11-16), https://bloxodes.com/stats/reports/roblox-october-2026: Blox Fruits rank 6, avg 174,003, peak 823,808, 358.6M visits in the month. Jujutsu Shenanigans rank 9, avg 130,620, peak 630,323, 325.0M visits. Genre trend: Action share 7.3% (down 0.5), RPG 3.8% (down 1.5), RPG weekly totals falling from 637K (31 Aug) to 388K (26 Oct). Read: our genre is healthy at the top but the middle is shrinking, so only the top few titles win.
- Earnaldo, last checked 2026-11-23, https://earnaldo.com/blog/best-roblox-games-2026.html: Blox Fruits ~250K median (Nov 8-16), King Legacy ~53K, Jujutsu Shenanigans ~80K, Strongest Battlegrounds ~50K, Attack on Titan Revolution ~49K. These differ from my live pull for JJS and TSB (see table); treat the live pull as the better snapshot of that moment and earnaldo as a medians-over-a-week figure.
- Ejaw, 2026-03-16, https://ejaw.net/roblox-charts/: Blox Fruits ~350K+ peak (+18%), Jujutsu Shenanigans ~150K+ peak (+44%) [UNVERIFIED, tracker-sourced]. Conflicts with Bloxodes (823K peak in October), so peaks vary hugely by window.

### A1. Live snapshot table (2026-11-25, Roblox public API)

| Game | Playing now | Lifetime visits | Favourites | Max players per server | Created | Last updated |
|---|---|---|---|---|---|---|
| Blox Fruits | 252,191 | 65.65B | 20.29M | 12 | 2019-01-16 | 2026-11-24 |
| The Strongest Battlegrounds | 34,084 | 19.70B | 7.85M | 15 | 2022-08-02 | 2026-11-24 |
| Jujutsu Shenanigans | 50,949 | 8.02B | 3.29M | 20 | 2022-04-17 | 2026-11-16 |
| King Legacy | 37,699 | 4.12B | 2.81M | 12 | 2019-12-17 | 2026-11-24 |
| Your Bizarre Adventure | 4,291 | 2.32B | 1.99M | 20 | 2019-02-02 | 2026-11-25 |
| Deepwoken | 1,923 | 1.66B | 1.05M | 30 | 2019-10-12 | 2026-11-25 |
| Grand Piece Online | 3,295 | 1.36B | 1.52M | 1 (lobby universe) | 2018-05-06 | 2026-11-25 |
| Fruit Battlegrounds | 2,399 | 1.08B | 1.01M | 20 | 2022-03-29 | 2026-11-17 |
| Type Soul (TYPE://SOUL) | 30 [UNVERIFIED: hub universe, max 1; real CCU is elsewhere] | 819M | 554K | 1 | 2023-07-15 | 2026-10-18 |
| Peroxide | 819 | 428M | 876K | 30 | 2022-03-14 | 2026-11-25 |
| Rogue Lineage | 636 | 387M | 348K | 10 | 2019-03-29 | 2026-11-14 |
| Project Slayers 2 | 9,864 | 162M | 557K | 1 (lobby universe) | 2024-02-02 | 2026-11-25 |
| Arcane Odyssey | 275 | 156M | 888K | 12 | 2019-06-07 | 2026-11-06 |
| Cultivation Unbound (cultivation genre, new) | 2,950 | 2.6M | 69K | 24 | 2026-06-30 | 2026-11-24 |
| Immortality Incremental (idle cultivation) | 1,905 | 47.3M | 300K | 10 | 2026-01-18 | 2026-11-23 |
| Martial Arts World (wuxia, new) | 184 | 2.0M | 23K | 20 | 2026-09-24 | 2026-11-25 |

Source: https://games.roblox.com/v1/games?universeIds=... pulled 2026-11-25. Vote ratios from https://games.roblox.com/v1/games/votes: Blox Fruits 12.90M up / 1.07M down (92.3%); Deepwoken 414,677 up / 66,329 down (86.2%); Peroxide 460,233 / 46,313 (90.9%); Arcane Odyssey 371,669 / 30,742 (92.4%); Rogue Lineage 118,886 / 23,348 (83.6%); Type Soul 398,915 / 98,439 (80.2%); Strongest Battlegrounds 5.38M / 1.05M (83.7%); Jujutsu Shenanigans 2.76M / 439K (86.3%); GPO 1.08M / 122K (89.8%).

What the table says in one line: the top is two licensed-feeling anime/pirate games with huge lifetime visits. Everything in the "hardcore build" tier (Deepwoken, Rogue Lineage, Arcane Odyssey, Peroxide, Type Soul) sits at 0.3K to 3K concurrent despite excellent approval, and the two cultivation/wuxia-flavoured titles that exist are idle or tiny. Nobody owns "wuxia action RPG with real combat and an open world" on Roblox. That is our gap, but the data also say the gap may be small, so we should aim for quality of feel and retention, not for breadth.

### A2. Per-game notes

#### Blox Fruits (Gamer Robot Inc)
- CCU: 252K now (live API, 2026-11-25); Oct 2026 peak 823,808 and avg 174,003 (Bloxodes, link above); another review says ~295K typical and weekend peaks above 700K, undated (https://rowatcher.com/news/is-blox-fruits-worth-playing-in-2026-an-honest-review).
- Core loop: level through quest NPCs on islands, farm, fight bosses, hunt fruits, sail seas. Naavik (2024-01-23): explore, face harder enemies, farm and loot to fund more farming, with friendly players helping and PvP players interrupting. https://naavik.co/digest/blox-fruits-lessons/
- Progression hook: level cap 2,800 (earnaldo page says 3,000, a likely newer value), three seas gating at roughly 700 and 1,500. A single active Devil Fruit gives your skill set; fruits are single-use drops from a loot box (2 hour cooldown) or traded. Mastery points, fighting styles and swords layer on top. Estimated 80-120 hours to cap without passes (RoWatcher 2026 review, undated).
- Combat feel: fruit skills plus a fighting style plus a sword chained as combos. Weakness: stun-heavy styles dominate PvP and hit detection is inconsistent (RoWatcher review).
- Retention: loot-box cooldown, trading economy (some players only trade), seasonal events, Update 29 (2025-12-25) added Dungeons as PvE endgame, a Fourth Sea is on the 2026 roadmap. Creator ecosystem (four YouTubers over 1M subs per Naavik). Naavik also reports the game's first year stayed below 20K CCU and it took roughly two years of patches and rework (2020 Patch 13, 2021 third sea, 2022 rework) to break out.
- Monetisation: live pass list (API, 2026-11-25): Dark Blade 1,200 R$, 2x Mastery 450, 2x Money 450, Fruit Notifier 2,700, Fast Boats 350, 2x Boss Drops 350. Permanent copies of fruits are the main revenue driver (Naavik). Private servers: not found in sources, not verified.
- Criticism: repetitive First Sea grind where many quit; pay-to-win perception; PvP stun meta; hit detection; scams in trading (RoWatcher review).

#### Jujutsu Shenanigans (Roblox Battlegrounds, anime fighter)
- CCU: ~51K live; Oct 2026 avg 130,620, peak 630,323 (Bloxodes). 20 players per server.
- Core loop: pick a character from a roster (all four skills plus M1 combo, dash, block), fight in a battlegrounds arena, ranked ladder. Earnaldo lists melee strings, four numbered skills, dash, block, awakening.
- Progression hook: very little character power progression; mastery of a kit and ranked Elo. v1.62 (Sept 2025) overhauled Elo and matchmaking (https://www.sportskeeda.com/roblox-news/jujutsu-shenanigans-v1-62-the-nothing-update-guide). Awakening is a resource that decides long fights (https://beebom.com/jujutsu-shenanigans-tier-list/).
- Retention: frequent roster updates (v1.81 on 2026-08-16 per a single source [UNVERIFIED]; live API says last update 2026-11-16), tier lists driving YouTube coverage, cosmetics.
- Monetisation: live passes: Early Access 345 R$, Awakening Outfits 115, More Emote Slots 175, Custom Kill Sound 120, More Build Saves 125. Cosmetic and convenience only, plus paying for early access to characters.
- Criticism: balance swings with every skill rework (a single rework can move a tier, per the October 2026 tier list at https://timesaver.gg/blog/jujutsu-shenanigans-tier-list-october-2026), not much solo content.

#### The Strongest Battlegrounds (Roblox, 2022-08-02)
- CCU: ~34K live; earnaldo ~50K median; secondary estimates of 83K to 324K are inconsistent [UNVERIFIED] (https://www.sportskeeda.com/roblox-news/5-things-know-playing-roblox-the-strongest-battlegrounds). 19.7B visits is the highest lifetime visit count among combat-only titles here.
- Core loop: short-round arena PvP, one-punch-man style moveset, ragdoll knockback, dash to cancel, ultimates. RoWatcher: One Punch Man sparked the anime battlegrounds subgenre (https://rowatcher.com/news/the-strongest-battlegrounds-how-one-punch-man-sparked-roblox-s-anime-fighter-revolution).
- Combat feel: momentum-swing combos, side-dash as the core defensive and offensive tool, emotes as social status (Sportskeeda link above).
- Progression: none beyond cosmetics and moveset unlocks. Monetisation: cosmetics, emotes. Retention: raw skill and spectacle, plus short sessions.
- Criticism: not cited in sources I could load; rating 83.7% with 1.05M downvotes suggests balance and exploit complaints [UNVERIFIED inference].

#### Deepwoken (Crypto Studios / Rogue Lineage team)
- CCU: 1.9K live; 1.66B lifetime visits; 1.05M favourites; 30-player servers. Released as Deepwoken in Dec 2021; won Best New Experience at the 2022 Roblox Innovation Awards; renamed Deepwoken: Ironsworn after Chapter 2 in Dec 2025 (RoWatcher: https://rowatcher.com/news/deepwoken-inside-roblox-s-most-brutal-hardcore-rpg).
- Core loop: build a character through Power levels, gain Talents from RNG cards, explore the Luminants, fight monsters, bosses and players, dive into the Void Sea for double XP at higher risk.
- Progression: attunements, oaths (one at a time), murmurs, bells (one active ability), Echoes. Three-stage permadeath: first death stains (permanent max-health loss until Power raised), second death sends you to the Depths, a death there deletes the character unless a rare Echo revives it.
- Combat feel: parry and posture system described as the most technically demanding on Roblox; skilled players beat much higher Power enemies. 2024 patch made parry stun, block stun and shaky-block frames scale with weapon speed (https://deepwoken.fandom.com/wiki/Version_History/2024). Input set not documented in loaded sources.
- Retention: chapter updates (Chapter 1 Oct 2025, Chapter 2 Dec 2025, "Operation: Deep Healing" announced Jan 2026 to address core-loop concerns). Monetisation: 400 R$ entry fee (RoWatcher); live passes are two 150 R$ emote packs only.
- Criticism: opacity (crafting, synergies, oaths need a wiki), veterans griefing new characters in starting zones, RNG talent draws causing rage quits, grind restarts after permadeath (RoWatcher; https://forum.arcaneodyssey.dev/t/a-review-of-deepwoken/73730).

#### Grand Piece Online (One Piece MMORPG)
- CCU: ~3.3K live; ~12K at one snapshot in Sept 2026 [UNVERIFIED single source] (https://allthings.how/grand-piece-online-events-schedule/); 1.36B visits; 1.52M favourites; 89.8% approval.
- Core loop: sail islands, level, quest, fight bosses, hunt fruits. Update 13 (2026-08-30, same source) added dungeon MVP fruit drops, weekend legendary/mythical fruit spawn doubling and 1.25x XP; Whole Cake Island is described as a large expansion with a new level cap (https://grindnstrat.com/gpo-whole-cake-island-update-part-1-guide/, undated).
- Progression: levels, fruits, races, fighting styles. Monetisation: not retrievable (pass endpoint returned nothing for its universe). Criticism: not found in loaded sources.
- Lesson: a long-lived 2018 title that retains 1.5M favourites on a recurring update cadence with weekend boosts.

#### Type Soul (Bleach-style action RPG)
- 819M visits, 554K favourites, 80.2% approval (lowest in this set). The trackers I could load showed 0 CCU (RoWatcher says "too new to call"), which almost certainly means they do not follow its real universe [UNVERIFIED]. 
- May 2026 overhaul removed Soul Wars, Culling Games, True Modes, Devil Trigger, Ancient Vastocar or disabled them pending reworks (https://www.pulse.bot/gaming/news/what-got-removed-in-the-type-soul-update-a9540c31-7f4d-4c0d-99bf-811c60a99d9b/, https://www.gamezebo.com/walkthroughs/type-soul-update-log/). Reaction mixed; complaints about OP reworked weapons.
- Lesson: a big content prune and rework by a new team is high-risk; low approval relative to Blox Fruits or Arcane Odyssey.

#### Peroxide
- 819 live, 428M visits, 876K favourites, 90.9% approval, 30 per server. Bleach-flavoured; start as Soul Reaper, Hollow or Quincy and that decides the path; combat rewards timing and positioning over stats; heavy grind (https://www.talkandroid.com/26550-roblox-peroxide-ultimate-progression-guide/, https://www.thespike.gg/roblox/best-roblox-games/games-like-project-mugetsu). The 91% approval figure from an affiliate blog matches the live vote data. Monetisation: donations and a trading sign only (live pass list: Trading Sign 100 R$, donations 100 to 1,000).

#### Rogue Lineage, Arcane Odyssey
- Rogue Lineage: 636 live, 387M visits, 83.6% approval, 10 per server. Same studio lineage as Deepwoken; hardcore permadeath. Arcane Odyssey: 275 live, 156M visits, 888K favourites, 92.4% approval (highest approval in the set apart from Blox Fruits), 12 per server, sailing and magic combat. I found no reliable reviews of either through the available tools, so no criticism section; this is a gap.
- Read: both prove deep systems earn love (very high approval) but not scale.

#### Project Slayers 2, King Legacy, Your Bizarre Adventure (context)
- Project Slayers 2: ~9.9K live, 162M visits (lobby universe, max 1). King Legacy: 37.7K live, 4.12B visits, Blox-Fruits-like (earnaldo: level cap 5,450, 45 fruits). Your Bizarre Adventure: 4.3K live, 2.32B visits. Not researched in depth.

#### Wuxia and cultivation titles on Roblox (the direct niche)
- Cultivation Unbound: 2,950 live, 2.6M visits (created 2026-06-30), 24 per server. Live passes (API): all passes bundle 999 R$, Auto Breakthrough 200, Auto Orb Collect 100, 2x Luck 500, Auto Quest 299, Storage 299, 2x Silver 399, Skip Reroll 100, 2x Drop Chance 399. This is an idle/auto-progress cultivation game, not an action game.
- Immortality Incremental: 1,905 live, 47.3M visits, 130,855 upvotes. Idle.
- Martial Arts World: 184 live, 2.0M visits (created 2026-09-24). Wuxia, early.
- Read: cultivation as a progression fantasy already pulls 2-3K concurrent from a 5-month-old low-effort game. Real action combat plus cultivation structure is open. The tool search is not exhaustive; there may be others.

## Part B: Off-Roblox references

- Where Winds Meet (NetEase, Nov 2025): 2M players in about 24h, Steam peak ~190-193K, 15M players in the first month (https://www.gamesradar.com/games/action-rpg/open-world-action-rpg-where-winds-meet-tops-2-million-players-in-its-first-weekend-with-a-concurrent-peak-of-190-000-on-steam-alone-as-it-rakes-in-very-positive-reviews, https://wccftech.com/where-winds-meet-surpassed-15-million-players-in-its-first-month/amp/). Praised: qinggong traversal (wall-running, gliding, grapple), parry-driven fluid combat, 30+ mystic arts and weapon variety, huge open world, cosmetic-only monetisation (https://eog.gg/games/where-winds-meet/review/). Criticised: AI chatbot NPCs, dense UI with many currencies, unskippable cutscenes and a long tutorial that dragged its early Steam rating to Mixed, a sparse MMO mode (https://www.pcgamesn.com/where-winds-meet/reception-ai-chatbots, 2025-11-15).
- Black Myth: Wukong (Game Science, Aug 2024): 10M copies in three days; reported above 30M by June 2026 (https://www.gematsu.com/2024/08/black-myth-wukong-sales-top-10-million, https://comicbook.com/gaming/news/black-myth-wukong-sales-milestone-30m/ [UNVERIFIED: cites a youth-league document]). Pillars (from general knowledge, not re-fetched this session): boss-centric spectacle, a very strong mythic aesthetic, transformations and spells layered on staff combat.
- Elden Ring: 36.4M copies and ~$2B revenue estimated by Alinea Analytics, Oct 2026 (https://ixbt.games/en/news/2026/10/23/elden-ring-prodalas-tirazom-364-mln-kopii-i-prinesla-2-mlrd-podscitali-analitiki.amp.html; secondary, [UNVERIFIED]). Pillars: open exploration with no map markers pulling you, landmarks as navigation, optional bosses, build variety.
- Sekiro: 5M copies as of July 2020 (https://ibtimes.com/elden-ring-races-past-dark-souls-iii-sekiro-reaching-sales-milestone-3636288, older). Pillars: posture/deflect combat, clear telegraphs, one mastery skill (the parry), sharp boss pacing. Genshin Impact: no revenue figure retrieved this session; its pillars from general knowledge are exploration rewards, element combos, dailies, and gacha banners.
- Common design pillars across these: (1) a single mastery action that feels excellent (parry/deflect), (2) readable boss telegraphs, (3) landmarks as navigation and reward, (4) traversal that is fun in itself, (5) a build identity the player chooses, (6) a visual identity, (7) restraint in monetisation (cosmetic only for WWM).

## Part C: Synthesis: features most correlated with success

Ranking logic: correlation with top results (Blox Fruits, JJS, TSB, GPO, WWM) and with approval among hardcore titles, plus what the sources explicitly said keeps players. No game has a controlled comparison, so this is directional.

Effort S = days, M = 1-3 weeks, L = more than 3 weeks. I do not have the Luau source in front of me this session; risks name systems from the handoff and your brief, and should be checked by whoever implements.

1. **A combat core with one mastery verb (parry/deflect plus dash) and frame data that is readable.** Evidence: Deepwoken parry/posture, Sekiro, WWM "parry-driven", JJS dash and block, TSB dash. Rec: lock a small input set (M1 string, heavy, 2-4 skills, dash/dodge, parry/deflect), give each a published startup/active/recovery table, add hit-stop of ~60-100 ms on connect, a distinct parry sound and flash, and server-side validation with a ~150 ms client-lead grace for latency. Effort L (it is a rewrite or heavy tune of existing combat). Risk: combat module is the highest-risk change; wrap behind a feature flag and keep Shen's phase hooks reading the same damage events.
2. **A long, visible, multi-region progression ladder with named gates.** Evidence: Blox Fruits three seas (level ~700 and ~1,500 gates), GPO level caps and islands, cultivation games' realm names. Rec: map our regions (Bellwood, Frostmere, Saltreach, Amberfall, Vesperhold, etc. from PROJECT_STATE) to cultivation realms with power gates and a visible next-gate indicator; breakthrough as a short combat or trial moment. Effort M. Risk: stat attribute persistence (Vigor/Endurance/Strength/Dexterity/ArcaneQi) must stay backward compatible; add new fields with defaults, never rename existing keys.
3. **Build identity: one active "style/technique" choice plus a stat spread, with respec limits.** Evidence: Blox Fruits one active fruit; Deepwoken oaths/bells; WWM schools and 8 playstyles; Peroxide race choice. Rec: three to four schools (sword, palm, spear, qi-arts) with one equipped signature technique and a small slot count; ArcaneQi boosts the technique, not raw damage. Effort M-L. Risk: skill/ability ID registry; use new persistent IDs, never recycle.
4. **Boss and elite content with telegraphed phases, mechanics and tiered rewards, including a repeatable form.** Evidence: Blox Fruits dungeons added Dec 2025 to fix endgame complaint; Black Myth/Sekiro/Elden Ring; Deepwoken Chapter bosses. Rec: Shen stays the template; add a replayable "echo" version with a modifier and a weekly boss with a rotating reward. Effort M per boss using the boss integration playbook. Risk: the Shen barrier must not be touched; add new bosses as separate encounters and test barrier open/close in a 2-client run.
5. **A hook economy that is not pay-to-win: rolls/drops plus trading or at least gifting.** Evidence: Blox Fruits (fruit drops, 2h loot cooldown, trading economy, permanent fruit copies), GPO weekend drop boosts; JJS and WWM cosmetic-led. Rec: timed drop chest (technique scrolls, cosmetics, upgrade materials), no direct power sales; sell cosmetics, emotes, loadout slots, XP boosts, cosmetic auras. Effort M (S without trading). Risk: persistent ID collisions and duplication exploits; any trade needs atomic server-side transfer. Defer trading until after launch.
6. **Open-world discovery with reasons to go there (landmarks, rewards, lore, no marker spam).** Evidence: Elden Ring, WWM qinggong and world, Blox Fruits islands. Rec: you already have colossal landmarks and the "Discovered" banner; attach one real reward per landmark (a technique fragment, a lore scroll, a mini-boss), and a fast traversal verb (wall-run/glide/dash) that costs ArcaneQi. Effort M. Risk: streaming and frame rate (handoff notes mesh dropout and white-load times of 15-30 s); do not widen streaming globally.
7. **Daily and weekly retention loops with events and boosts.** Evidence: GPO weekend 2x legendary spawns and 1.25x XP, Blox Fruits seasonal events, Update cadence in all top titles. Rec: a daily quest set, weekly boss, login streak, weekend XP boost, a monthly seasonal event with cosmetic reward track. Effort M. Risk: DataStore load and daily reset timezone; store a UTC day number.
8. **Social layer: co-op bosses, factions/sects, small shared servers, parties.** Evidence: Blox Fruits 12-player servers with raid co-op, WWM co-op, Deepwoken guilds; TSB short matches. Rec: sect membership with a sect banner and a shared weekly goal; party-scaled bosses. Effort L. Risk: lobby and teleport service; test two-client party teleport (hand off to the other computer per your note on multi-client tests).
9. **Low-friction onboarding in the first 10 minutes.** Evidence: WWM's long tutorial and unskippable cutscenes pulled launch ratings to Mixed; Deepwoken and Blox Fruits First Sea both lose players early. Rec: play within 60 seconds of spawn, a first fight in 3 minutes, skippable cutscenes, one-screen stat explainer, a "next goal" arrow; the earlier onboarding-overhaul branch is the right place. Effort S-M. Risk: lobby flow and new-player tutorial flags; add a flag, do not reset existing players.
10. **Clear visual identity and combat VFX (the "wuxia look" and sound).** Evidence: Black Myth, WWM awards for design, TSB/JJS spectacle driving YouTube clips. Rec: signature slash trails, qi aura (already in Vesperhold night work), parry spark, ground cracks, hit-stop, audio stingers; keep clip-worthy "ultimate" moves. Effort M. Risk: particle and mesh budget on phones; profile before shipping (handoff says phone profiling is still pending).
11. **Creator and community loop (tier lists, codes, updates cadence).** Evidence: Blox Fruits creator ecosystem (Naavik), JJS tier lists, steady updates. Rec: a codes system, clip-friendly kill-cam or victory pose, public roadmap, twice-monthly patch cadence. Effort S-M. Risk: low.
12. **Ranked or arena mode as a secondary mode.** Evidence: JJS Elo overhaul v1.62, TSB. Rec: only after the core combat is tuned; reuse the combat in a 1v1 or small FFA arena with cosmetic rewards. Effort M-L. Risk: PvP balance burdens a PvE-first game; skip for the first six months unless combat testing goes well.

### Things to avoid (from the criticisms)
- A repetitive early grind (Blox Fruits First Sea) and opaque systems (Deepwoken). Our persistent stat system needs in-game explanations.
- Hard permadeath. Deepwoken's approval is good but concurrent is under 2K; if we want a hardcore tier, make it an opt-in mode, not the default.
- Pay-to-win perception: Blox Fruits' own review coverage flags it as valid criticism. WWM's cosmetic-only model earned explicit praise.
- Big content prunes (Type Soul May 2026) with mixed reception and the lowest approval in the set.
- AI-chatbot NPCs (WWM) as a headline feature.
- Wide RNG on build-critical draws (Deepwoken talent cards cause rage quits). Use pity timers on any roll.

## Recommended order (given the repo's current state)
1. Combat feel pass: parry/dash/hit-stop and readable telegraphs (items 1 and 10) behind a flag.
2. First-ten-minutes pass (item 9) while the onboarding branch is open.
3. Region-gated progression ladder with realm names (item 2) and one technique choice (item 3).
4. Landmark rewards and a traversal verb (item 6).
5. Daily/weekly loop plus weekend boost (item 7), then boss variants (item 4), then a sect/party layer (item 8).

## Caveats
- No Reddit or YouTube pages were readable; player criticism is thin for Rogue Lineage, Arcane Odyssey, GPO and TSB.
- RoMonitor and Rolimons gave no usable data through the tools; peak CCUs for most titles are not verified.
- Type Soul and Project Slayers 2 live figures are hub universes and not the real CCU.
- I did not read the Luau source for Asura's Path; effort estimates and risks are from the handoff and your brief only.
