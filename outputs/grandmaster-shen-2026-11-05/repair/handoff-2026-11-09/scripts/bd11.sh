#!/bin/zsh
H="$(cd "$(dirname "$0")" && pwd)"   # (handoff 2026-11-09) this scripts folder; the repo root is five levels up
S=${SHEN_SCRATCH:-$PWD/work/shen_repair}; mkdir -p $S
cd "${SHEN_ROOT:-$H/../../../../..}"
$H/regen_cloth.sh
mkdir -p $S/cloth_bd11 $S/cloth_p1bd11
cp work/shen_import/cloth_p2.json work/shen_import/clothskin_reach_p2.json $S/cloth_bd11/
cp work/shen_import/cloth_p1.json work/shen_import/clothskin_reach_p1.json $S/cloth_p1bd11/
$H/beardvar.sh bd11 > $S/bd11_var.log 2>&1 &
$H/beardvar1.sh p1bd11 > $S/p1bd11_var.log 2>&1 &
wait
B=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}; R=tools/blender/shen_import/review.py
for cam in chestfront chestside; do SHEN_REVIEW_GROUNDED=1 SHEN_REVIEW_CLASH=UpperTorso SHEN_REVIEW_CLASH_FROM=Beard $B -b --factory-startup --threads 2 --python $R -- c2_DeathblowVictim_bd11 $S/rv/beard_dbv_bd11_$cam $cam 6:44:1 > $S/rv/beard_dbv_bd11_$cam.log 2>&1 & done; wait
grep -h "CLASH frame" $S/rv/beard_dbv_bd11_chestfront.log | awk '{n+=$4; if($10>m)m=$10} END{print "bd11 beard verts in chest", n, "deepest", m}'
echo BD10_DONE
