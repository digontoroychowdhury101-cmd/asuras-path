#!/bin/zsh
H="$(cd "$(dirname "$0")" && pwd)"   # (handoff 2026-11-09) this scripts folder; the repo root is five levels up
cd "${SHEN_ROOT:-$H/../../../../..}"
S=${SHEN_SCRATCH:-$PWD/work/shen_repair}; mkdir -p $S
B=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
R=tools/blender/shen_import/review.py
for v in bb bd7; do
  for cam in chestside chestfront; do
    SHEN_REVIEW_GROUNDED=1 SHEN_REVIEW_CLASH=UpperTorso SHEN_REVIEW_CLASH_FROM=Beard $B -b --factory-startup --threads 2 --python $R -- c2_DeathblowVictim_$v $S/rv/beard_dbv_${v}_$cam $cam 6:44:1 > $S/rv/beard_dbv_${v}_$cam.log 2>&1 &
  done
done
wait
echo BEARD_RENDERED
