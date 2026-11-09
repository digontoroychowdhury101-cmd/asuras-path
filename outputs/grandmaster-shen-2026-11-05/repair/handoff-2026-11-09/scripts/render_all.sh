#!/bin/zsh
H="$(cd "$(dirname "$0")" && pwd)"   # (handoff 2026-11-09) this scripts folder; the repo root is five levels up
cd "${SHEN_ROOT:-$H/../../../../..}"
S=${SHEN_SCRATCH:-$PWD/work/shen_repair}; mkdir -p $S
B=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
for shot in pilot1 run1; do
  for ver in _before ""; do
    for cam in side front combat; do
      [[ $shot == run1 && $cam == combat ]] && continue
      out=$S/frames/${shot}${ver:-_after}_$cam
      [[ -f $out/done ]] && continue
      $B -b --factory-startup --python tools/blender/shen_import/review.py -- ${shot}${ver} $out $cam "::1" 640x360 > $out.log 2>&1 && touch $out/done
      echo "$(date +%T) ${shot}${ver:-_after} $cam $(ls $out | wc -l)"
    done
  done
done
echo ALLDONE
