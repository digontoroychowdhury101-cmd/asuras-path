#!/bin/zsh
H="$(cd "$(dirname "$0")" && pwd)"   # (handoff 2026-11-09) this scripts folder; the repo root is five levels up
# render_pass4.sh : x-ray renders (arm vertices inside UpperTorso lit magenta) of each pass-4 clip, before (_pre4: the export this pass started from)
# and after (_p4: the final export), front camera, every frame from the clip's start in the shot; then one labelled before/after video per clip
cd "${SHEN_ROOT:-$H/../../../../..}"
S=${SHEN_SCRATCH:-$PWD/work/shen_repair}; mkdir -p $S
B=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
R=tools/blender/shen_import/review.py
OUT=outputs/grandmaster-shen-2026-11-05/repair
mkdir -p $S/rv4
PAR=${PAR:-5}
CAM=${CAM:-front}
PART=${PART:-UpperTorso}
job() {   # shot version
  local dir=$S/rv4/${1}_${2}_${PART}_$CAM
  rm -rf $dir
  SHEN_REVIEW_CLASH=$PART SHEN_REVIEW_CLASH_FROM=LeftUpperArm,LeftLowerArm,LeftHand,RightUpperArm,RightLowerArm,RightHand \
    nice -n 5 $B -b --factory-startup --threads 2 --python $R -- ${1}_$2 $dir $CAM 17::1 640x360 > $dir.log 2>&1
  echo "$(date +%T) $1 $2 $(ls $dir 2>/dev/null | wc -l | tr -d ' ') frames"
}
for shot in ${=SHOTS}; do
  for v in pre4 p4; do
    while [ $(jobs -r | wc -l) -ge $PAR ]; do sleep 2; done
    job $shot $v &
  done
done
wait
for shot in ${=SHOTS}; do
  zsh $H/clashsum.sh $S/rv4/${shot}_pre4_${PART}_$CAM.log $S/rv4/${shot}_p4_${PART}_$CAM.log
done
if [ -n "$VIDEO" ]; then
  for shot in ${=SHOTS}; do
    $B -b --factory-startup --python tools/blender/shen_import/compare_video.py -- $OUT/arms_pass4_${shot}_${PART:l}_before_after.mp4 15 \
      "$shot: arm skin inside the ${PART} lit magenta (x-ray), half speed" \
      "BEFORE (export this pass started from)=$S/rv4/${shot}_pre4_${PART}_$CAM" "AFTER (final export)=$S/rv4/${shot}_p4_${PART}_$CAM" > $S/rv4/video_${shot}.log 2>&1
    echo "video $shot $(ls -la $OUT/arms_pass4_${shot}_${PART:l}_before_after.mp4 2>/dev/null | awk '{print $5}')"
  done
fi
echo RENDER_PASS4_DONE
