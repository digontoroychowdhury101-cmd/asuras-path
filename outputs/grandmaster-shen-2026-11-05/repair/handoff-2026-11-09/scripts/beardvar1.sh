#!/bin/zsh
H="$(cd "$(dirname "$0")" && pwd)"   # (handoff 2026-11-09) this scripts folder; the repo root is five levels up
# bake the six beard shots with each trial cloth folder ($S/cloth_<tag>) on the same motion, then the mesh check: beard_mc_<tag>.json
cd "${SHEN_ROOT:-$H/../../../../..}"
S=${SHEN_SCRATCH:-$PWD/work/shen_repair}; mkdir -p $S
shots=(c1_DeathblowVictim c1_Feint c1_Guandao_Heavy c1_Guandao_Running c1_Guandao_Art c1_PostureBreak c1_PrayerBeads)
for t in $@; do SHEN_BAKE_DIR=$S/bake_dc SHEN_CLOTH_DIR=$S/cloth_$t SHEN_SHOT_SUFFIX=_$t python3 tools/animation/opening_cast/cloth_bake.py $shots > $S/beard_bake_$t.log 2>&1 & done
wait
X=/Applications/Blender.app/Contents/MacOS/Blender
for t in $@; do $X -b --factory-startup --threads 2 --python tools/blender/shen_import/mesh_clash.py -- $S/beard_mc_$t.json 2 ${^shots}_$t > $S/beard_mc_$t.log 2>&1 & done
wait
echo BEARDVAR_DONE
