#!/bin/zsh
H="$(cd "$(dirname "$0")" && pwd)"   # (handoff 2026-11-09) this scripts folder; the repo root is five levels up
# render_set.sh SUFFIX : x-ray renders (arms inside UpperTorso lit magenta) of the four comparison shots, front and quarter cameras
cd "${SHEN_ROOT:-$H/../../../../..}"
S=${SHEN_SCRATCH:-$PWD/work/shen_repair}; mkdir -p $S
B=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
R=tools/blender/shen_import/review.py
v=$1
typeset -A span; span=(c2_Flourish 46:64:1 c2_CrimsonEmbrace 50:76:1 c2_Strike 28:46:1 c2_Guandao_Heavy 24:38:1 c2_BloodWave 34:50:1 c2_RendingArc 46:60:1)
for shot in ${=SHOTS:-c2_Flourish c2_CrimsonEmbrace c2_Strike c2_Guandao_Heavy}; do
  for cam in ${=CAMS:-front quarter}; do
    SHEN_REVIEW_CLASH=UpperTorso SHEN_REVIEW_CLASH_FROM=LeftUpperArm,LeftLowerArm,RightUpperArm,RightLowerArm nice -n 10 $B -b --factory-startup --threads 2 --python $R -- ${shot}_$v $S/rv/x9_${shot}_${v}_$cam $cam ${span[$shot]} > $S/rv/x9_${shot}_${v}_$cam.log 2>&1 &
  done
  wait
done
echo RENDERED_$v
