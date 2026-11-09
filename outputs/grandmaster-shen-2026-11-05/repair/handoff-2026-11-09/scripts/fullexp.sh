#!/bin/zsh
H="$(cd "$(dirname "$0")" && pwd)"   # (handoff 2026-11-09) this scripts folder; the repo root is five levels up
cd "${SHEN_ROOT:-$H/../../../../..}"
S=${SHEN_SCRATCH:-$PWD/work/shen_repair}; mkdir -p $S
names=($(ls work/opening_cast_bake/shen/GrandmasterShen_P*.json | xargs -n1 basename | sed 's/\.json//'))
par=8
for k in $(seq 0 $((par-1))); do
  grp=(); for ((i=k+1; i<=${#names}; i+=par)); do grp+=${names[i]}; done
  python3 tools/animation/opening_cast/export.py shen $grp > $S/full_exp_$k.log 2>&1 &
done
wait
grep -hE "^(OK|FIX)" $S/full_exp_*.log | cut -c1-60 | sort | uniq -c | awk '{print $2}' | sort | uniq -c
grep -hE "Traceback|Error" $S/full_exp_*.log | head
echo EXPORTED
