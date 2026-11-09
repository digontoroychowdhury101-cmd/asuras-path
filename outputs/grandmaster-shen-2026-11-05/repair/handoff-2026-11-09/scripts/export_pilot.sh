#!/bin/zsh
H="$(cd "$(dirname "$0")" && pwd)"   # (handoff 2026-11-09) this scripts folder; the repo root is five levels up
S=${SHEN_SCRATCH:-$PWD/work/shen_repair}; mkdir -p $S
cd "${SHEN_ROOT:-$H/../../../../..}"
E=tools/animation/opening_cast/export.py
P=GrandmasterShen_P1_
python3 -u $E shen ${P}Idle ${P}TurnLeft > $S/ex1.txt 2>&1 &
python3 -u $E shen ${P}TurnRight ${P}WalkForward > $S/ex2.txt 2>&1 &
python3 -u $E shen ${P}WalkBackward ${P}StrafeLeft > $S/ex3.txt 2>&1 &
python3 -u $E shen ${P}StrafeRight ${P}RunForward > $S/ex4.txt 2>&1 &
python3 -u $E shen ${P}Guandao_L1 > $S/ex5.txt 2>&1 &
python3 -u $E shen ${P}Guandao_Heavy > $S/ex6.txt 2>&1 &
python3 -u $E shen ${P}FlowingJian > $S/ex7.txt 2>&1 &
wait
cat $S/ex?.txt | grep -E "^(OK|FIX)|Error"
python3 tools/animation/opening_cast/cloth_bake.py pilot1 run1 && echo BAKED
