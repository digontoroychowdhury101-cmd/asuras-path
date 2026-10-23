#!/usr/bin/env bash
# Wrapper to run generate_glb.py using the isolated tools/trellis_env virtual environment
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$DIR/../.." && pwd)"
PYTHON="$REPO_ROOT/tools/trellis_env/bin/python3"

if [ ! -f "$PYTHON" ]; then
    echo "[SETUP] Creating tools/trellis_env..."
    python3 -m venv "$REPO_ROOT/tools/trellis_env"
    "$REPO_ROOT/tools/trellis_env/bin/pip" install --upgrade pip requests gradio_client trimesh pillow
fi

exec "$PYTHON" "$REPO_ROOT/tools/trellis/generate_glb.py" "$@"
