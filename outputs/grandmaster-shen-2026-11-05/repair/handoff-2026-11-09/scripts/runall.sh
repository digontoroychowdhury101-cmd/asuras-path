#!/bin/zsh
H="$(cd "$(dirname "$0")" && pwd)"   # (handoff 2026-11-09) this scripts folder; the repo root is five levels up
# in-process bake + validate of every clip in allclips_sorted.txt, 8 at a time: tt<TAG>_<clip>.log
cd "${SHEN_ROOT:-$H/../../../../..}"
S=${SHEN_SCRATCH:-$PWD/work/shen_repair}; mkdir -p $S
TAG=$1; shift
for c in $(cat ${1:-$S/allclips_sorted.txt}); do
  while [ $(pgrep -f "torsotest.py on" | wc -l) -ge 8 ]; do sleep 3; done
  [ -s $S/tt${TAG}_$c.log ] && grep -q "problems" $S/tt${TAG}_$c.log && continue
  python3 $H/torsotest.py on $c > $S/tt${TAG}_$c.log 2>&1 &
  sleep 1
done
wait
echo RUNALL_DONE
