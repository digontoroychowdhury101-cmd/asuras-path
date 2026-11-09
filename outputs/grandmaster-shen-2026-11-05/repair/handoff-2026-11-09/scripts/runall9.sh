#!/bin/zsh
H="$(cd "$(dirname "$0")" && pwd)"   # (handoff 2026-11-09) this scripts folder; the repo root is five levels up
# runall9.sh TAG [list]: in-process bake + validate of every clip with the repo code, 7 at a time, saved bakes in baked_TAG, logs ttTAG_<clip>.log
cd "${SHEN_ROOT:-$H/../../../../..}"
S=${SHEN_SCRATCH:-$PWD/work/shen_repair}; mkdir -p $S
TAG=$1
for c in $(cat ${2:-$S/all64_sorted.txt}); do
  while [ $(pgrep -f "[t]orsotest_patch.py on" | wc -l) -ge ${JOBS:-7} ]; do sleep 5; done
  [ -s $S/tt${TAG}_$c.log ] && grep -q "problems" $S/tt${TAG}_$c.log && continue
  TAG=_$TAG SHEN_SAVE_BAKED=$S/baked_$TAG VECLIB_MAXIMUM_THREADS=1 OMP_NUM_THREADS=1 python3 $H/torsotest_patch.py on $c > $S/tt${TAG}_$c.log 2>&1 &
  sleep 1
done
wait
echo RUNALL9_DONE_$TAG
