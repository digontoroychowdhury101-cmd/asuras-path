# Asura's Path (修羅之道)

**High-Tempo Grimdark Wuxia Souls + Action Combat Hybrid on Roblox.**

### Overview
- **Combat Core**: 1.4× tempo hybrid combat combining Unarmed Martial Arts (fists, kicks, clinches) with Equippable Melee Weapons (Jian Sword, Dao Sabre, Guandao Glaive).
- **Deflect & Posture**: 100ms deflect timing window, posture meter buildup, StanceBreak stun, and cinematic Deathblow critical executions.
- **Blood Rally & Tri-Layer Health**: ActiveHP, RecoverableHP (debt restored via aggressive counter-attacks), and PermanentDeficit.
- **Server Netcode**: 60 Hz Circular Ring Buffer lag compensation with sub-millisecond bisection search and 150ms max rewind ceiling.
- **PvE Story Mode**: Semi-open world across the Desecrated Monastery, Bamboo Pass, and Ash Pagoda with Incense Altar (bonfire) checkpoints, Lost Qi death drops, and multi-phase boss encounters (Grandmaster Shen / Demonic Chimera).
- **PvP Colosseums**: Ancient dueling rings with normalized attribute scaling for competitive 1v1 Ranked Duels and casual sparring.
- **Client Presentation**: Third-Person Over-the-Shoulder Camlock, metallic deflect sparks, hit-stop, and dynamic concussive eye/head trauma effects.

### Development & Build
- **Build Place**: `python3 tools/build.py` (builds `outputs/AsurasPath.rbxlx`)
- **Run Tests**: 
  - `work/bin/luau/luau tools/test_asura_stage1.luau`
  - `python3 tools/test_asura_stage2.py`
  - `work/bin/luau/luau tools/test_asura_stage3.luau`
