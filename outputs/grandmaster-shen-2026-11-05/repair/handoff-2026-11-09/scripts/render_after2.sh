#!/bin/zsh
H="$(cd "$(dirname "$0")" && pwd)"   # (handoff 2026-11-09) this scripts folder; the repo root is five levels up
cd "${SHEN_ROOT:-$H/../../../../..}"
S=${SHEN_SCRATCH:-$PWD/work/shen_repair}; mkdir -p $S
B=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
job() { # shot cam
  out=$S/frames/$1_after_$2
  rm -rf $out; mkdir -p $out
  $B -b --factory-startup --python tools/blender/shen_import/review.py -- $1 $out $2 "::1" 640x360 > $out.log 2>&1 && touch $out/done
  echo "$(date +%T) $1 $2 $(ls $out | wc -l)"
}
job pilot1 side & job pilot1 front & job pilot1 combat & job pilot1 lhand & job run1 side & job run1 front &
wait
job deaths1 side & job deaths2 side & job sky2 side & job cuts2 combat & job deaths1 front & job deaths2 front &
wait
echo ALLDONE
