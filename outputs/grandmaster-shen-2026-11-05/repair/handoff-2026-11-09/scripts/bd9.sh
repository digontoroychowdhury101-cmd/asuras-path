#!/bin/zsh
H="$(cd "$(dirname "$0")" && pwd)"   # (handoff 2026-11-09) this scripts folder; the repo root is five levels up
# bd9: skin-only tiles (default) + the chest sphere's least-squares radius instead of its 95th percentile; bake the six beard shots, mesh check, render DBV
S=${SHEN_SCRATCH:-$PWD/work/shen_repair}; mkdir -p $S
cd "${SHEN_ROOT:-$H/../../../../..}"
export VECLIB_MAXIMUM_THREADS=1 OMP_NUM_THREADS=1
$H/tune.sh cloth_bd9 '    rs = float(np.percentile(np.linalg.norm(near - (cx, cy, cz), axis=1), 95))=>    pass' > $S/bd9_tune.log 2>&1
grep -A1 "UpperTorso" $S/cloth_bd9/rig.log | head -4
$H/beardvar.sh bd9 > $S/bd9_var.log 2>&1
B=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}; R=tools/blender/shen_import/review.py
for cam in chestfront chestside; do SHEN_REVIEW_GROUNDED=1 SHEN_REVIEW_CLASH=UpperTorso SHEN_REVIEW_CLASH_FROM=Beard $B -b --factory-startup --threads 2 --python $R -- c2_DeathblowVictim_bd9 $S/rv/beard_dbv_bd9_$cam $cam 6:44:1 > $S/rv/beard_dbv_bd9_$cam.log 2>&1 & done; wait
grep -h "CLASH frame" $S/rv/beard_dbv_bd9_chestfront.log | awk '{n+=$4; if($10>m)m=$10} END{print "bd9 beard verts in chest", n, "deepest", m}'
echo BD9_DONE
