#!/bin/bash
# apply.sh - apply the Treble/GSI patchset to this source tree via git apply.
# NO commits are made; the tree stays unpushed and clean(ish) - uncommitted only.
# Usage: bash Treble/apply.sh
set -e

ROOT="$(dirname "$(readlink -f "$0")")/.."
PATCHES="$ROOT/Treble/patches"
FAILED=0

assert_clean() {
    if [ -n "$(git status --porcelain)" ]; then
        echo "WARN $1 already has changes - will skip patches that do not apply cleanly"
    fi
}

# Map a dir name like platform_frameworks_base to a real path under tree root.
map_path() {
    local p="${1//_//}"
    p="${p#platform/}"
    case "$p" in
        build) echo "build/make";;
        frameworks/proto/logging) echo "frameworks/proto_logging";;
        treble/app) echo "treble_app";;
        *) echo "$p" ;;
    esac
}

apply_group() {
    local group="$1"
    [ -d "$PATCHES/$group" ] || return 0
    echo "=== $group ==="
    for project in $(cd "$PATCHES/$group" && echo *); do
        local p; p=$(map_path "$project")
        if [ ! -d "$ROOT/$p" ]; then
            echo "SKIP (repo missing, add via local manifest): $project"
            continue
        fi
        pushd "$ROOT/$p" > /dev/null
        assert_clean "$p"
        for patch in "$PATCHES/$group/$project"/*.patch; do
            [ -f "$patch" ] || continue
            if git apply --check "$patch" 2>/dev/null; then
                git apply "$patch"
                echo "OK   $p/$(basename "$patch")"
            else
                echo "!!   SKIP (does not apply): $p/$(basename "$patch")"
                FAILED=1
            fi
        done
        popd > /dev/null
    done
}

for g in patches_treble_prerequisite patches_treble_td patches_treble patches_gsi; do
    apply_group "$g"
done

echo ""
if [ "$FAILED" = 1 ]; then
    echo "Some patches did not apply cleanly - inspect output above."
else
    echo "All patches applied. Uncommitted changes only - nothing was committed."
fi