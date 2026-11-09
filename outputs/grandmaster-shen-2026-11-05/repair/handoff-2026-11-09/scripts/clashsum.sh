#!/bin/zsh
H="$(cd "$(dirname "$0")" && pwd)"   # (handoff 2026-11-09) this scripts folder; the repo root is five levels up
# clashsum.sh LOG... : frames with arm vertices inside UpperTorso (over 0), max count and deepest, from review.py's CLASH lines
for f in "$@"; do
  awk -v f=$(basename $f .log) '/CLASH frame/{n++; c=$4+0; d=$NF+0; if(c>0){lit++}; if(c>mc)mc=c; if(d>md)md=d} END{printf "%-38s lit %2d/%2d  max %5d verts  deepest %.3f\n", f, lit, n, mc, md}' $f
done
