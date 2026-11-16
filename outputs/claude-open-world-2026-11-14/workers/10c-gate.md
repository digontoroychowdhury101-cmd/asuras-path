- [10c start] task: Shen gate buried in terrain blend. Source: src/shared/Overworld.luau gate pad -> chain of pads (GateRadius 18, Blend 30, Step 16) at gate floor heightAt 1578 (surface 1580) from Outside z -8140 to Inside z -8206. Next: tests (terrain corridor check, blockout line 69), lune/py/compile/build, Studio.
- [10c edit] Overworld.luau gate pad chain (GateRadius 18, Blend 56, Step 16, Y 1578); tests: test_overworld_terrain +section 9 (corridor surface 1580.00..1580.00, no lip), blockout line 69 voxel-aware; both pass. Next: lune --all, py, compile, scratch build.
- [10c prep] build in scratchpad/t10g (digest printed below in next entry)
- [10c prep2] build digest scripts 291 bytes 3015784 digest 2070091499; baseline places digest 462022588; http 8766 up in scratchpad/t10g (no stale listener)
- [10c sync] Studio digest scripts 291 bytes 3015784 digest 2070091499 == build; HttpEnabled true.
STUDIO RUN STARTED (Play next, build 2070091499)
- [10c studio] Play (build 2070091499): terrain-only raycast x=-7200/-7213/-7187 every 4: 1552 at altar, monotone rise 1552->1580 by z -8108, flat 1580.0 (+-0.4) z -8116..-8204 (was ~1585 + blend slope). capture t10/shen_gate_exposed.jpg (from z -8110 corridor start, eye 1584; from the altar the 28-stud ascent + temple stilts hide the gate by design, shot ScreenCapture_g2 not saved). Next: character_navigation altar->gate.
- [10c walk] character_navigation altar -> (-7200,1583,-8172) x3 speed: arrived (-7199.7,1583.06,-8171.5), no snag.
STUDIO RESTORED: digest scripts 286 bytes 2859366 digest 462022588, HttpEnabled false, Edit mode, http server killed, place not saved. Source changed: src/shared/Overworld.luau, tools/test_overworld_terrain.luau, tools/test_overworld_blockout.luau.
