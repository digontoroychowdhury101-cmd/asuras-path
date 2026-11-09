#!/bin/zsh
H="$(cd "$(dirname "$0")" && pwd)"   # (handoff 2026-11-09) this scripts folder; the repo root is five levels up
cd "${SHEN_ROOT:-$H/../../../../..}"
S=${SHEN_SCRATCH:-$PWD/work/shen_repair}; mkdir -p $S
B=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
job() { # shot version cam
  out=$S/frames/$1${2:-_after}_$3
  [[ -f $out/done ]] && return
  $B -b --factory-startup --python tools/blender/shen_import/review.py -- $1$2 $out $3 "::1" 640x360 > $out.log 2>&1 && touch $out/done
  echo "$(date +%T) $1${2:-_after} $3 $(ls $out | wc -l)"
}
job pilot1 "" side & job pilot1 "" front & job pilot1 "" combat & job run1 "" side & job run1 "" front &
job pilot1 _before lhand & job pilot1 "" lhand &
wait
echo ALLDONE
