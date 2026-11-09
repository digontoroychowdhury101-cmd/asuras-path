#!/bin/zsh
H="$(cd "$(dirname "$0")" && pwd)"   # (handoff 2026-11-09) this scripts folder; the repo root is five levels up
cd "${SHEN_ROOT:-$H/../../../../..}"
S=${SHEN_SCRATCH:-$PWD/work/shen_repair}; mkdir -p $S
shots=(c2_RendingArc c2_DeathblowVictim c2_Feint c2_Guandao_Heavy c2_BloodWave c2_Guandao_Running)
SHEN_BAKE_DIR=$S/bake_dc SHEN_SHOT_SUFFIX=_bd0 python3 tools/animation/opening_cast/cloth_bake.py $shots > $S/beard_bake0.log 2>&1 &
SHEN_BAKE_DIR=$S/bake_dc SHEN_CLOTH_DIR=$S/cloth_beard SHEN_SHOT_SUFFIX=_bd1 python3 tools/animation/opening_cast/cloth_bake.py $shots > $S/beard_bake1.log 2>&1 &
wait
B=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
$B -b --factory-startup --threads 2 --python tools/blender/shen_import/mesh_clash.py -- $S/beard_mc0.json 2 ${^shots}_bd0 > $S/beard_mc0.log 2>&1 &
$B -b --factory-startup --threads 2 --python tools/blender/shen_import/mesh_clash.py -- $S/beard_mc1.json 2 ${^shots}_bd1 > $S/beard_mc1.log 2>&1 &
wait
echo BEARD_DONE
