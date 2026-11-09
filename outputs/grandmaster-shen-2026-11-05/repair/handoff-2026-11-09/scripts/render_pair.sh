#!/bin/zsh
H="$(cd "$(dirname "$0")" && pwd)"   # (handoff 2026-11-09) this scripts folder; the repo root is five levels up
# usage: render_pair.sh OUTTAG SPAN SIZE shotA shotB cam1 cam2 ...  (renders every shot x camera in parallel)
cd "${SHEN_ROOT:-$H/../../../../..}"
S=${SHEN_SCRATCH:-$PWD/work/shen_repair}; mkdir -p $S
tag=$1; span=$2; size=$3; a=$4; b=$5; shift 5
for cam in $@; do for shot in $a $b; do
  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/blender/shen_import/review.py -- $shot $S/rv/${tag}_${shot}_$cam $cam $span $size > $S/rv/${tag}_${shot}_$cam.log 2>&1 &
done; done
wait
echo RENDERED $tag
