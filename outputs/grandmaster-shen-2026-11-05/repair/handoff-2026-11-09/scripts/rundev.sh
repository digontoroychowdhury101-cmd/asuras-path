#!/bin/zsh
H="$(cd "$(dirname "$0")" && pwd)"   # (handoff 2026-11-09) this scripts folder; the repo root is five levels up
# rundev.sh TAG clip...   dev-copy bakes, at most $MAXJ (default 2) at once: ttTAG_<clip>.log
cd "${SHEN_ROOT:-$H/../../../../..}"
S=${SHEN_SCRATCH:-$PWD/work/shen_repair}; mkdir -p $S
TAG=$1; shift
for c in "$@"; do
  while [ $(pgrep -f "torsotest_dev.py on" | wc -l) -ge ${MAXJ:-2} ]; do sleep 3; done
  VECLIB_MAXIMUM_THREADS=1 OMP_NUM_THREADS=1 python3 $H/torsotest_dev.py on $c > $S/tt${TAG}_$c.log 2>&1 &
  sleep 1
done
wait
echo RUNDEV_DONE
