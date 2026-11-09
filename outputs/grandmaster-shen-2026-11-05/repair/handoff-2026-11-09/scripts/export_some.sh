#!/bin/zsh
H="$(cd "$(dirname "$0")" && pwd)"   # (handoff 2026-11-09) this scripts folder; the repo root is five levels up
# usage: export_some.sh PAR clip...   (clip names without the GrandmasterShen_ prefix) -> $S/exp_<k>.log
cd "${SHEN_ROOT:-$H/../../../../..}"
S=${SHEN_SCRATCH:-$PWD/work/shen_repair}; mkdir -p $S
par=$1; shift; names=($@)
for k in $(seq 0 $((par-1))); do
  grp=(); for ((i=k+1; i<=${#names}; i+=par)); do grp+=GrandmasterShen_${names[i]}; done
  [ ${#grp} -gt 0 ] && python3 tools/animation/opening_cast/export.py shen $grp > $S/exp_$k.log 2>&1 &
done
wait
cat $S/exp_*.log | grep -E "^(OK|FIX) "
