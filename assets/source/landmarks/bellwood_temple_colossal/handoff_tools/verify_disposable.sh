#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
task="work/sol-bellwood-v20"
scratch="tools/_lune_test_slice_dressing.generated.luau"
saved="$task/verification-preserved/original_slice_dressing.luau"
mkdir -p "$(dirname "$saved")"
had_original=0
if [[ -e "$scratch" ]]; then
    [[ ! -e "$saved" ]]
    mv "$scratch" "$saved"
    had_original=1
fi
restore() {
    if [[ -e "$scratch" ]]; then
        mv "$scratch" "$(mktemp "$task/verification-preserved/verify.XXXXXXXX")"
    fi
    if [[ $had_original == 1 ]]; then
        mv "$saved" "$scratch"
    fi
}
trap restore EXIT
ASURA_BUILD_OUTPUT="$task/play.rbxlx" bash tools/verify_all.sh
