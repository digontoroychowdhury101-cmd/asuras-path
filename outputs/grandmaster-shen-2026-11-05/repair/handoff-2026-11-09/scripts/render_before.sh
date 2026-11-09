#!/bin/zsh
H="$(cd "$(dirname "$0")" && pwd)"   # (handoff 2026-11-09) this scripts folder; the repo root is five levels up
cd "${SHEN_ROOT:-$H/../../../../..}"
S=${SHEN_SCRATCH:-$PWD/work/shen_repair}; mkdir -p $S
B=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
R=tools/blender/shen_import/review.py
for shot in c2_DeathblowVictim_dcb c1_DeathblowVictim_dcb; do
  for cam in front lside; do
    SHEN_REVIEW_GROUNDED=1 SHEN_REVIEW_CLASH=LeftUpperLeg SHEN_REVIEW_CLASH_FROM=RobeFront,RobeLeft,RobeRight $B -b --factory-startup --threads 2 --python $R -- $shot $S/rv/ev_${shot}_$cam $cam > $S/rv/ev_${shot}_$cam.log 2>&1
  done
done
for shot in c1_Guandao_Heavy_dcb c2_Guandao_Heavy_dcb; do
  for cam in lhand combat; do
    $B -b --factory-startup --threads 2 --python $R -- $shot $S/rv/ev_${shot}_$cam $cam > $S/rv/ev_${shot}_$cam.log 2>&1
  done
done
echo BEFORE_DONE
