#!/bin/zsh
H="$(cd "$(dirname "$0")" && pwd)"   # (handoff 2026-11-09) this scripts folder; the repo root is five levels up
cd "${SHEN_ROOT:-$H/../../../../..}"
S=${SHEN_SCRATCH:-$PWD/work/shen_repair}; mkdir -p $S
names=($(ls $S/bake_before/GrandmasterShen_P*.json | xargs -n1 basename | sed -E 's/GrandmasterShen_P([12])_(.*)\.json/c\1_\2/'))
for k in 0 1 2 3; do
  grp=(); for ((i=k+1; i<=${#names}; i+=4)); do grp+=${names[i]}; done
  SHEN_BAKE_DIR=$S/bake_before SHEN_SHOT_SUFFIX=_b0 python3 tools/animation/opening_cast/cloth_bake.py $grp > $S/bake_b0_$k.log 2>&1 &
done
wait
for k in 0 1 2 3; do
  grp=(); for ((i=k+1; i<=${#names}; i+=4)); do grp+=${names[i]}_b0; done
  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/blender/shen_import/mesh_clash.py -- $S/clash_b0_$k.json 2 $grp > $S/clash_b0_$k.log 2>&1 &
done
wait
echo ALLDONE
