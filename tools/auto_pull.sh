#!/usr/bin/env bash
set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

BRANCH="$(git rev-parse --abbrev-ref HEAD)"

echo "=========================================================="
echo " Starting Git Auto-Pull Loop for Asura's Path"
echo " Project root: $DIR"
echo " Active branch: $BRANCH"
echo "=========================================================="
echo "Watching GitHub for updates every 4 seconds..."
echo "Press Ctrl+C to stop."
echo ""

while true; do
    git fetch origin "$BRANCH" --quiet 2>/dev/null || true
    
    LOCAL=$(git rev-parse HEAD 2>/dev/null)
    REMOTE=$(git rev-parse "origin/$BRANCH" 2>/dev/null)

    if [ -n "$LOCAL" ] && [ -n "$REMOTE" ] && [ "$LOCAL" != "$REMOTE" ]; then
        echo "[$(date +'%H:%M:%S')] 🚀 Remote change detected from Computer B! Syncing..."
        if git pull --rebase --autostash origin "$BRANCH"; then
            echo "[$(date +'%H:%M:%S')] ✅ Synced! Rojo is updating Roblox Studio now."
        else
            echo "[$(date +'%H:%M:%S')] ⚠️ Sync conflict. Check git status."
        fi
        echo "----------------------------------------------------------"
    fi
    sleep 4
done
