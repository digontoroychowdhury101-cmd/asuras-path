#!/bin/zsh
H="$(cd "$(dirname "$0")" && pwd)"   # (handoff 2026-11-09) this scripts folder; the repo root is five levels up
# usage: tune.sh TAG 'A=>B;;A=>B'   cloth-only rig with edits into $S/TAG/cloth_pN.json (inputs read from work/shen_import; nothing there is written)
cd "${SHEN_ROOT:-$H/../../../../..}"
S=${SHEN_SCRATCH:-$PWD/work/shen_repair}; mkdir -p $S
tag=$1; mkdir -p $S/$tag
python3 - "$2" "$S/$tag" <<'PY'
import sys
t = open("tools/blender/shen_import/skin_rig.py").read()
for pair in sys.argv[1].split(";;"):
    if not pair.strip(): continue
    a, b = pair.split("=>")
    assert a in t, a
    t = t.replace(a, b)
w = 'open(os.path.join(out, f"cloth_p{phase}.json"), "w")'
assert w in t
t = t.replace(w, 'open(os.path.join("%s", f"cloth_p{phase}.json"), "w")' % sys.argv[2])
h = 'HERE = os.path.dirname(os.path.abspath(__file__))'
assert h in t
t = t.replace(h, 'HERE = "/Users/digonto/Documents/ChatGPT/Roblox game 2/tools/blender/shen_import"')
open(sys.argv[2] + "/skin_rig_t.py", "w").write(t)
PY
python3 $S/$tag/skin_rig_t.py --cloth-only 1 2 > $S/$tag/rig.log 2>&1; grep "skin samples" $S/$tag/rig.log; ls $S/$tag/cloth_p*.json
cp work/shen_import/clothskin_p?.json work/shen_import/clothskin_reach_p?.json $S/$tag/
