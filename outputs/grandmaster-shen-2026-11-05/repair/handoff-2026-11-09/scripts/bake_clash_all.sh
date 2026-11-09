#!/bin/zsh
H="$(cd "$(dirname "$0")" && pwd)"   # (handoff 2026-11-09) this scripts folder; the repo root is five levels up
# usage: bake_clash_all.sh TAG   (bake every c1_/c2_ shot from work/opening_cast_bake/shen, then mesh-clash them)
cd "${SHEN_ROOT:-$H/../../../../..}"
S=${SHEN_SCRATCH:-$PWD/work/shen_repair}; mkdir -p $S
names=($(ls work/opening_cast_bake/shen/GrandmasterShen_P*.json | xargs -n1 basename | sed -E 's/GrandmasterShen_P([12])_(.*)\.json/c\1_\2/'))
for k in 0 1 2 3 4 5 6 7; do
  grp=(); for ((i=k+1; i<=${#names}; i+=8)); do grp+=${names[i]}; done
  python3 tools/animation/opening_cast/cloth_bake.py $grp > $S/bake_$1_$k.log 2>&1 &
done
wait
echo BAKED
zsh $H/clash_all.sh $S $1
