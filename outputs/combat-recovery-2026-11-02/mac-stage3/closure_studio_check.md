# Stage 3A closure: focused Studio check (Mac, 2 November 2026)

Seeded single-client diagnostic with Studio-injected input. Not ordinary input, not two-client, not a visual judgment. Build `scripts 272 bytes 2147557 digest 696604417`, matched in Studio. Frame rate not recorded for this run.

| Check | Result |
|---|---|
| `tools/qa/Stage3ScaleProbe.client.luau` | scale 1: 1-stud Transform moved the pelvis 1.000 studs; scale 2: 1-stud Transform moved the pelvis 1.000 studs. A presented step therefore has to be multiplied by the model's scale. |
| `AsuraDebugReach` on, three real-clicked swings | Each swing made one `StrikeDebug` and one `StrikeArc` (`StrikeArc:6;StrikeDebug:5`, twice, then `StrikeArc:8;StrikeDebug:6`, attachments 120 ms after creation) |
| Record on the character | `70|7.00|1.00|0.0000|…|0.050|Jian|0.00|1.000|Jian_L2|1`: move, scale, bonus and baked selection arrive on the client |
| Console | Only the known `CampaignTerrain` line 120 grid warning; no errors from changed modules |

Not checked here: the step writer on a real out-of-budget fighter, a scaled rig swinging, convergence at real latency (W-04, W-06, W-13).
