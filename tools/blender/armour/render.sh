#!/bin/zsh
# build + turnaround of one set: render.sh <set> <tag> [master|game] [ghost|no] [samples]
cd "$(dirname "$0")/../../.."
B=/Applications/Blender.app/Contents/MacOS/Blender
SET=$1; TAG=$2; LEVEL=${3:-master}; GHOST=${4:-no}; SAMPLES=${5:-32}
if [[ $LEVEL == master ]]; then
  $B -b --factory-startup --python-exit-code 3 -P tools/blender/armour/build.py -- $SET 2>&1 | grep -E "^(Master|Game|Error)|OVER|Traceback|line " | cut -c1-200
fi
$B -b assets/source/armour/$SET/$SET.blend --python-exit-code 3 -P tools/blender/armour/review.py -- $SET $LEVEL $TAG $GHOST $SAMPLES 2>&1 | grep -E "Error|Traceback|line " | cut -c1-200
R=assets/source/armour/$SET/review
python3 tools/blender/armour/sheet.py $R/${TAG}_sheet.png $R/${TAG}_front.png $R/${TAG}_three.png $R/${TAG}_left.png $R/${TAG}_back.png
echo done $R/${TAG}_sheet.png
