#!/bin/zsh
H="$(cd "$(dirname "$0")" && pwd)"   # (handoff 2026-11-09) this scripts folder; the repo root is five levels up
cd "${SHEN_ROOT:-$H/../../../../..}"
names=($(ls work/opening_cast_bake/shen | sed -E 's/GrandmasterShen_P([12])_(.*)\.json/c\1_\2/'))
for k in 0 1 2 3 4 5 6 7; do
  grp=()
  for ((i=k+1; i<=${#names}; i+=8)); do grp+=${names[i]}; done
  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/blender/shen_import/mesh_clash.py -- $1/clash_$2_$k.json 2 $grp > $1/clash_$2_$k.log 2>&1 &
done
wait
echo ALLDONE
