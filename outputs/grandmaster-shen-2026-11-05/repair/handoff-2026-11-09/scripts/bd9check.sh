#!/bin/zsh
H="$(cd "$(dirname "$0")" && pwd)"   # (handoff 2026-11-09) this scripts folder; the repo root is five levels up
S=${SHEN_SCRATCH:-$PWD/work/shen_repair}; mkdir -p $S
cd "${SHEN_ROOT:-$H/../../../../..}"
B=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}; R=tools/blender/shen_import/review.py
for v in bd5 bd9; do SHEN_REVIEW_GROUNDED=1 SHEN_REVIEW_CLASH=UpperTorso SHEN_REVIEW_CLASH_FROM=RobeRight $B -b --factory-startup --threads 2 --python $R -- c2_DeathblowVictim_$v $S/rv/robe_dbv_${v}_quarter quarter > $S/rv/robe_dbv_${v}_quarter.log 2>&1 & done
$H/beardvar1.sh p1bd9 > $S/p1bd9.log 2>&1 &
wait
echo BD9CHECK_DONE
