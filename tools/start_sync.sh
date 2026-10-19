#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

ROJO="work/bin/rojo/rojo"

if [ ! -f "$ROJO" ]; then
    if command -v rojo >/dev/null 2>&1; then
        ROJO="rojo"
    else
        echo "Error: Rojo binary not found in work/bin/rojo/rojo or on PATH."
        exit 1
    fi
fi

echo "=========================================================="
echo " Starting Rojo Live-Sync for Asura's Path"
echo " Project root: $DIR"
echo " Rojo binary:  $ROJO"
echo "=========================================================="
echo ""
echo "Steps in Roblox Studio:"
echo " 1. Open Roblox Studio with your place."
echo " 2. In the Plugins tab, click on the Rojo plugin."
echo " 3. Click 'Connect' (default port: 34872)."
echo ""
echo "Live sync is now running. Press Ctrl+C to stop."
echo "=========================================================="

"$ROJO" serve default.project.json --port 34872
