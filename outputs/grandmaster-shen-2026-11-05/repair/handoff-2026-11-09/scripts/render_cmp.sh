#!/bin/zsh
H="$(cd "$(dirname "$0")" && pwd)"   # (handoff 2026-11-09) this scripts folder; the repo root is five levels up
# render_cmp.sh : x-ray renders (arm vertices inside $PART lit magenta) of two versions of each shot (VA, VB: shot suffixes), front camera, every
# frame from the clip's start, then clashsum and one labelled side-by-side video per shot ($OUT/$PREFIX_<shot>_<part>.mp4)
cd "${SHEN_ROOT:-$H/../../../../..}"
S=${SHEN_SCRATCH:-$PWD/work/shen_repair}; mkdir -p $S
B=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
R=tools/blender/shen_import/review.py
OUT=outputs/grandmaster-shen-2026-11-05/repair
PAR=${PAR:-2}; CAM=${CAM:-front}; PART=${PART:-UpperTorso}; VA=${VA:-cur}; VB=${VB:-opt}; PREFIX=${PREFIX:-slsqp}
LA=${LA:-current bake}; LB=${LB:-SLSQP joint solve}
mkdir -p $S/rv5
job() {
  local dir=$S/rv5/${1}_${2}_${PART}_$CAM
  rm -rf $dir
  SHEN_REVIEW_CLASH=$PART SHEN_REVIEW_CLASH_FROM=LeftUpperArm,LeftLowerArm,LeftHand,RightUpperArm,RightLowerArm,RightHand \
    nice -n 5 $B -b --factory-startup --threads 2 --python $R -- ${1}_$2 $dir $CAM 17::1 640x360 > $dir.log 2>&1
  echo "$(date +%T) $1 $2 $(ls $dir 2>/dev/null | wc -l | tr -d ' ') frames"
}
for shot in ${=SHOTS}; do
  for v in $VA $VB; do
    while [ $(jobs -r | wc -l) -ge $PAR ]; do sleep 2; done
    job $shot $v &
  done
done
wait
for shot in ${=SHOTS}; do
  zsh $H/clashsum.sh $S/rv5/${shot}_${VA}_${PART}_$CAM.log $S/rv5/${shot}_${VB}_${PART}_$CAM.log
  $B -b --factory-startup --python tools/blender/shen_import/compare_video.py -- $OUT/${PREFIX}_${shot}_${PART:l}.mp4 15 \
    "$shot: arm skin inside the ${PART} lit magenta (x-ray), half speed" \
    "$LA=$S/rv5/${shot}_${VA}_${PART}_$CAM" "$LB=$S/rv5/${shot}_${VB}_${PART}_$CAM" > $S/rv5/video_${shot}.log 2>&1
  echo "video $shot $(ls -la $OUT/${PREFIX}_${shot}_${PART:l}.mp4 2>/dev/null | awk '{print $5}')"
done
echo RENDER_CMP_DONE
