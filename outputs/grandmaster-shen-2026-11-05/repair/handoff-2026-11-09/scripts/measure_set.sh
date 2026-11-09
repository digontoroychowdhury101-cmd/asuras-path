#!/bin/zsh
H="$(cd "$(dirname "$0")" && pwd)"   # (handoff 2026-11-09) this scripts folder; the repo root is five levels up
# usage: measure_set.sh TAG SIM CLOTHDIR [PAR]   bake every clip as c1_/c2_<clip>_TAG with that sim and cloth data, then mesh-clash them (bind-pose baseline)
cd "${SHEN_ROOT:-$H/../../../../..}"
S=${SHEN_SCRATCH:-$PWD/work/shen_repair}; mkdir -p $S
tag=$1; sim=$2; cdir=$3; par=${4:-6}
names=($(ls work/opening_cast_bake/shen/GrandmasterShen_P*.json | xargs -n1 basename | sed -E 's/GrandmasterShen_P([12])_(.*)\.json/c\1_\2/'))
for k in $(seq 0 $((par-1))); do
  grp=(); for ((i=k+1; i<=${#names}; i+=par)); do grp+=${names[i]}; done
  SHEN_CLOTH_SIM=$sim SHEN_CLOTH_DIR=$cdir SHEN_SHOT_SUFFIX=_$tag python3 tools/animation/opening_cast/cloth_bake.py $grp > $S/mset_bake_${tag}_$k.log 2>&1 &
done
wait
echo BAKED $tag
for k in $(seq 0 $((par-1))); do
  grp=(); for ((i=k+1; i<=${#names}; i+=par)); do grp+=${names[i]}_$tag; done
  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/blender/shen_import/mesh_clash.py -- $S/mset_${tag}_$k.json 2 $grp > $S/mset_clash_${tag}_$k.log 2>&1 &
done
wait
echo MEASURED $tag
