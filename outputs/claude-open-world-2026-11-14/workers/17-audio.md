# 17 Audio beds (Lane 6, assets only, no Studio, no src)

## Step 1 Inventory (done)
Mechanism today: `SoundscapeController.Update` plays ONE key, `Audio.play("Wind", SoundService, 0.22, true)`, on every region change
(any region except Sanctuary gets 0.22, Sanctuary 0.12). `Overworld.Regions[*].Ambience` strings exist (WindReeds x4,
TempleBells for GoldenRavine, EmberCrowd for AshColosseum) but NOTHING consumes them; no PresentationAssets key matches them.

| Key / file | Asset ID | Serves | Status |
|---|---|---|---|
| Wind | 122450130719273 | every non-Sanctuary region (single generic bed) | uploaded, registered |
| Bell | 123385330740698 | DesecratedMonastery only (old world; never plays in overworld, 08-audit) | registered |
| Water | 113213311649809 | DesecratedMonastery only | registered |
| BossDrone | 123393717022210 | boss | registered |
| Glide/Slide/BulletJump | various | movement loops | registered |
| Github forest-ambience.wav (CC0) | 87123492592079 | none | upload rejected by requester approval, EXCLUDED |
| Shen/Nova/Sun layers | various | combat | not ambience |

Biome coverage: Bellwood forest NO dedicated bed (generic Wind only). Amberfall Ravine NO (TempleBells key unmapped).
Saltreach basin NO. Frostmere Heads snow NO. Ashen Stair mountain NO (generic Wind). Caves NO. Wind: one generic loop,
not wind-source driven. ESE ruling R3: one wind source feeds foliage, precipitation, cloth and ambience; so beds must be
wind-neutral base layers; gust/intensity must be driven from the shared wind value (gain/pitch), not baked-in gusts.
Credits: assets/CREDITS.md line 118 documents the Superpowers CC0 pack; no ElevenLabs entries yet.
Tooling: no local ElevenLabs script in tools/ (build_*_audio.py are procedural). Existing provider = ElevenLabs
connector in this session (eleven_text_to_sound_v2, loop param, 30 s max). Plan tier: starter. Roblox env vars
ROBLOX_API_KEY/CREATOR_ID/TYPE are set; upload tool: tools/assets/register_uploads.py (not yet inspected).

## Step 2 Generation (3 takes used, 240 credits, ~4.8 cents; starter tier)
Files: assets/source/audio/overworld/{bellwood_forest_day,frostmere_snow,saltreach_basin}.mp3 (raw), *_loop.wav (baked), PROVENANCE.json.
Method: ElevenLabs sfx eleven_text_to_sound_v2, 24 s, loop=true, influence 0.5, then local 2 s equal-power fold, DC removal, RMS -26 dBFS, peak <= -3.

## Step 3 Objective checks (baked loops; I cannot hear audio, HUMAN AUDITION REQUIRED)
| Bed | dur | peak | RMS | DC | head/tail 50ms | seam jump vs mean step | 1 s RMS range |
|---|---|---|---|---|---|---|---|
| bellwood_forest_day | 22.0 s | -16.2 | -26.8 | 0.00004 | -22.1/-19.9 | 2.1x (no click) | -29.6..-24.9 |
| frostmere_snow | 22.0 s | -15.1 | -26.7 | -0.00002 | -30.7/-25.2 | 0.5x | -27.9..-25.0 |
| saltreach_basin | 22.0 s | -11.4 | -26.0 | -0.00001 | -28.0/-27.2 | 1.2x | -27.1..-24.7 |
Raw forest was 11 dB under target (peak -32 dBFS); raw snow -20.7; raw saltreach -56 dBFS / rms -71 (near silent): REJECTED, baked file is amplified hiss.
Existing project check (test_audiovisual.py) covers only the Phase5 manifest; not applicable to these files.

## Upload: BLOCKED (no project upload tooling; no IDs invented). Local files kept. Also Roblox needs mp3/ogg: bake wav is not uploadable; raw mp3 is (but quiet), or re-encode with ffmpeg elsewhere.

## WIRING FOR LEAD
- PresentationAssets.Audio keys: ForestBed, SnowBed (after upload); SoundscapeController: map region -> key via Overworld.Regions[id].Ambience (currently ignored, plays "Wind" for everything).
- Ambience strings are unconsumed; change Forest "WindReeds" -> "ForestBed", Snowfields -> "SnowBed"; fall back to Wind.
- R3: beds are gust-free; scale gain/pitch of one active bed from the shared wind value; crossfade (one active Sound per region, tween out old over ~2 s) to avoid stacking.
- Set Sound.Looped=true; volume ~0.3-0.5 (baked at -26 RMS).
- Credits line in PROVENANCE.json for assets/CREDITS.md.
## GAPS: Amberfall Ravine, Ashen Stair, caves, Saltreach (regen), detail layers, footsteps, shelter, barrier sound.

## Round 2
Provider unchanged: ElevenLabs eleven_text_to_sound_v2 via creative connector (flow hxbOSqQmmdTk2ycrmBWX). Gotcha: generate_in_flow ignores duration/loop (first call gave a 1 s non-loop clip, 17 credits wasted); fix = creative_update_node model_parameters {duration_seconds, loop, prompt_influence} then creative_run_flow_nodes. Bake script = same fold/-26 RMS as round 1.

### Saltreach (AridBasin) saltreach_basin_r2.mp3 / saltreach_basin_r2_loop.wav, 80 credits (+17 wasted)
Prompt: loud steady dry wind over empty salt flat, gritty crystal hiss, faint distant gulls/insects, no gusts.
Raw: 24 s, peak -13.7, rms -30.3 (round 1 was -71). Baked 22 s: peak -10.8, rms -26.0, DC -0.00008, head/tail 50ms -24.2/-26.9, seam jump 1.8x mean step (no click), 1 s RMS -28.3..-23.1. PASS objective checks; HUMAN AUDITION REQUIRED (gull/insect presence unverified). Supersedes saltreach_basin.mp3 (reject).

### Amberfall Ravine (GoldenRavine) amberfall_ravine.mp3 / amberfall_ravine_loop.wav, 80 credits
Prompt: steady dry grass rustle in canyon wind, hollow chasm echo, distant seasonal trickle, no gusts/birds/music.
Raw: 24 s, peak -10.9, rms -30.3. Baked 22 s: peak -6.5, rms -26.0, DC -0.00004, head/tail 50ms -28.5/-28.4, seam jump 1.4x (no click), 1 s RMS -32.0..-17.8 (14 dB swing: some swell/event inside, unlike the other beds; audition for R3 gust-free). Objective PASS except level steadiness flag. HUMAN AUDITION REQUIRED.

### Ashen Stair (mountain) ashen_stair.mp3 / ashen_stair_loop.wav, 80 credits
Prompt: high thin steady wind over bare rock, soft ash hiss, very distant faint temple wind-chime, no gusts/voices/music.
Raw: 24 s, peak -25.6, rms -40.6 (quiet; bake gain +14.6 dB amplifies hiss). Baked 22 s: peak -11.0, rms -26.0, DC -0.00001, head/tail 50ms -27.9/-27.9, seam jump 1.3x (no click), 1 s RMS -35.9..-22.1 (14 dB range, probably chimes). Objective PASS; HUMAN AUDITION REQUIRED (chime presence, hiss quality).

### Round 2 totals
Credits 80x3 = 240 + 17 wasted (1 s non-loop first call) = 257 (~5.1 cents). Saltreach needed no regen. Still missing: caves, Bellwood detail layers, footsteps, shelter, barrier sound. Upload still blocked; wavs not Roblox-uploadable (need ogg/mp3 encode on a machine with ffmpeg).
