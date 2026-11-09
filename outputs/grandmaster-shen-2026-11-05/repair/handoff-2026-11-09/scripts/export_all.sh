#!/bin/zsh
H="$(cd "$(dirname "$0")" && pwd)"   # (handoff 2026-11-09) this scripts folder; the repo root is five levels up
cd "${SHEN_ROOT:-$H/../../../../..}"
S=${SHEN_SCRATCH:-$PWD/work/shen_repair}; mkdir -p $S
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1
k=0
while read -r line; do k=$((k+1)); python3 -u tools/animation/opening_cast/export.py shen ${=line} > $S/exall_$k.txt 2>&1 & done < $S/groups.txt
wait
cat $S/exall_*.txt | grep -E "^(OK|FIX)|Error|Traceback"
