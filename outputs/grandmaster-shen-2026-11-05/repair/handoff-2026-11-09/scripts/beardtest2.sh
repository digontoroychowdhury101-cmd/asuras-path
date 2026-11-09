#!/bin/zsh
H="$(cd "$(dirname "$0")" && pwd)"   # (handoff 2026-11-09) this scripts folder; the repo root is five levels up
# A/B of the phase 2 cloth on the same motion: base (cloth_base) vs current work/shen_import, six beard-heavy shots, then the mesh check
cd "${SHEN_ROOT:-$H/../../../../..}"
S=${SHEN_SCRATCH:-$PWD/work/shen_repair}; mkdir -p $S
A=${1:-bb}; B=${2:-bd2}
shots=(c2_RendingArc c2_DeathblowVictim c2_Feint c2_Guandao_Heavy c2_BloodWave c2_Guandao_Running)
[ -s $S/beard_mc_$A.json ] || SHEN_BAKE_DIR=$S/bake_dc SHEN_CLOTH_DIR=$S/cloth_base SHEN_SHOT_SUFFIX=_$A python3 tools/animation/opening_cast/cloth_bake.py $shots > $S/beard_bake_$A.log 2>&1 &
SHEN_BAKE_DIR=$S/bake_dc SHEN_SHOT_SUFFIX=_$B python3 tools/animation/opening_cast/cloth_bake.py $shots > $S/beard_bake_$B.log 2>&1 &
wait
X=/Applications/Blender.app/Contents/MacOS/Blender
[ -s $S/beard_mc_$A.json ] || $X -b --factory-startup --threads 2 --python tools/blender/shen_import/mesh_clash.py -- $S/beard_mc_$A.json 2 ${^shots}_$A > $S/beard_mc_$A.log 2>&1 &
$X -b --factory-startup --threads 2 --python tools/blender/shen_import/mesh_clash.py -- $S/beard_mc_$B.json 2 ${^shots}_$B > $S/beard_mc_$B.log 2>&1 &
wait
echo BEARD2_DONE
