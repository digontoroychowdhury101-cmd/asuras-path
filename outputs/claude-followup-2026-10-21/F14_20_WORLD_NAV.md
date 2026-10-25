# Follow-ups 14–20 — campaign world, traversal and navigation (25 Oct 2026, Computer A)

Place: `places/AsurasPath.rbxlx`, opened in Studio from each build and proven equal by `tools/qa/SourceDigest.luau`
(digests 347189247 → 563204935 → 2022834115 → 1360326681 → 1290155875; the final source commit rebuilds after
one more data-only Pagoda zone edit). Views: `f14-20-views/`.

Evidence types used below: **source**, **local regression** (Luau suites), **seeded Studio diagnostic** (placement,
seeded attribute or scripted `Humanoid:MoveTo` locomotion under real Studio physics), **real Studio play** (held
keys / prompts through Studio input). Nothing here is earned continuous-input play, hardware or live service.

## Shared navigation layer (prompt 14, #28)

- `RouteGuide.next` now returns the whole staged `Route` (doorways in order, then the goal when it is reached on
  foot); portal exits end the line (northern gate, Well of Descent, crypt/bastion return portals).
- New `MinimapRoute` (registered under Controllers): pooled segments clipped to the disc, nodes for climbs/drops
  (▲/▼), portal exits (◎) and the bloodstain (✕). Fed by ObjectiveController's 0.2 s refresh; no world scans.
- Fixed (source + local regression, fail-before shown): crypt/bastion → Sanctuary goals aimed straight across the
  world split; they now stage the region's return portal. Bloodstain card said "northern gate" for a crypt stain.
- Fixed (real Studio, seeded stain): after a death moved the player home, the card kept "Return to your
  bloodstain" while the marker said "Northern gate" (`Show` only redrew on key change → `Objectives.changed`).
- Real Studio: gate → courtyard line north along the Gatehouse; death respawn draws the line to the portal ◎;
  crypt arrival line stages the stairs. Off-disc nodes moved inside the N/E/S/W ring (was hidden under "N").

## Route geometry found by walking the guide in Studio (seeded diagnostic walker) — all fixed

| Region | Failure observed | Fix | Regression |
|---|---|---|---|
| Crypt | Lids over the pit belonged to no zone → straight line across walls; walker fell in | Reliquary zone spans the lid causeway; lids door at the pit lip | door-in-zone, lid cells |
| Crypt | Arrival line cut the landing parapet over a 30-stud drop | Descent stair / gallery / gallery stair zones | route over walked ground |
| Ash | Ring → court door line crossed the MistVeil (L-shaped court) | `AC_CourtWalk` + ring yard door | veil-crossing sample |
| Pagoda | West stair door mid-stair; line ran along the stair side | Stair zone, foot + head doors | foot→head check |
| Pagoda | Stair head → beam far end diagonal over the gorge (walker fell 20 studs) | Gallery narrowed; `CP_Beam` zone | over-ground check |
| Pagoda | Fewest-doors routing then chose the optional rafter-end jumps | `Optional` doors used only when nothing else connects (rafter ends, frost stones) | names check |
| Pagoda | Lantern rafter → stair foot diagonal clipped the stair side (fell) | `CP_RafterStair` zone (final build pending Studio re-walk; same line walked explicitly without a fall) | names check |
| Monastery | Grave-field line ran through the ToppledPagoda set piece | Route follows authored `GravePath` | trail check |

## Catches and physics (prompts 15, 18, 20)

- Real Studio: the Well of Descent prompt (held Z) → crypt arrival (520, 33, 1062) facing north; walking the crypt never
  fired the Sanctuary catch; a pit drop returned to the pit lip (366, 2.9, 904); Sanctuary isle fall → bonfire.
- Fixed (seeded diagnostic + local regression): falls off the Citadel bridge/bastion were **killed** by
  `FallenPartsDestroyHeight` −100 before the 0.6 s catch could fire (body deleted ≈0.94 s into the fall). Now −400
  (Config + saved place); both falls return alive. Regression computes fall time vs hold+poll from the saved-place
  values for every catch.
- Fixed (real Studio): Loggia Eaves lookout rail 2.4 → 3.8; the cache chest was a step that let a running player
  clear it. Ladder climb (Climbing 604 → 618) and deck stop at z 926 verified live.

## Walked routes and collectibles

- Monastery: tablet I read (real Z); Gatehouse sparring yard reached on foot, ring panel opens; bridge swordsman
  clear line of sight from 4 eye points at both ends; Cloister altar 34/40 free standing cells; Waterfall Alcove
  (via the curtain side — east approach is blocked by `AlcoveRock` by design) and Sealed Mausoleum claimed by real
  prompts. **Not evidenced:** my M1s did not register on the bridge swordsman (MCP input), Rafters ladder climb
  (Cloister foes killed the idle QA body twice; same truss mechanic verified on the Eaves ladder), tablets II–IV.
- Sanctuary: three cloud shards and isle landed with single real jumps; Cloud Reliquary claimed; west viewing wing
  captured at shoulder height (lion fills the right third; figure above default pitch — recorded, not re-composed).
- Bamboo: Bamboo Gate → Ridge stairs → Shrine stairs → Baize's mouth walked; entering the arena starts Baize
  (the idle walker died; onward road runs through the boss). Inscriptions/frost stones not walked this pass.
- Ash: ring yard → court → antechamber → halls → Shen's gate walked; exploration fill raised (night kept) after the
  region read near-black at character height (`f17_*` before/after). Ring is entered by queue/challenge (barrier).
- Pagoda: gorge → west stair → head → beam → rafter stair → Wu's gate walked; optional rafter ends landed one hop
  each to the loft; VII read on the loft and VIII on the dawn terrace (seeded placement past Wu) — Essence once each.
- Citadel: summit bridge → Heaven's stair → bastion walked; both catches return alive (after the destroy-height fix).

## Still open (exact)

- Human/earned: bridge duel damage from both ends, Baize/Shen/Titan/Wu/Wyrm fights and post-victory exits (22).
- Studio re-walk of the final `CP_RafterStair` doorway; Rafters ladder in the Cloister; Monastery tablets II–IV;
  Bamboo inscriptions and frost-stone/double-jump/glide vs thicket veils; Wyrm landing vs built geometry.
- Visual: Waterfall Alcove interior unreadably dark; memorial hint line clipped ("Reopen it any…"); Sanctuary
  region label overflows the minimap disc.
- Art (#22/#32 Blocked): production kits for Colosseum tiers, crypt vaults/sarcophagi, Pagoda eaves/rafters,
  Citadel towers/battlements; Bamboo ruins (ASSET_REQUIREMENTS.md). Geometry above is structural, not final art.
