#!/bin/bash
# revert.sh - undo the Treble/GSI patchset that was applied with Treble/apply.sh
# (git apply -R, in reverse order). Does NOT touch commits; untracked files
# created by patches are removed with git clean -fd (only in touched repos).
# Usage: bash Treble/revert.sh
set -e

ROOT="$(dirname "$(readlink -f "$0")")/.."
PATCHES="$ROOT/Treble/patches"

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

revert_group() {
    local group="$1"
    [ -d "$PATCHES/$group" ] || return 0
    # reverse = last group first, last patch of each project first
    for project in $(cd "$PATCHES/$group" && echo * | tr ' ' '\n' | tac); do
        local p; p=$(map_path "$project")
        if [ ! -d "$ROOT/$p" ]; then
            echo "SKIP (repo missing): $project"
            continue
        fi
        pushd "$ROOT/$p" > /dev/null
        for patch in $(ls -r "$PATCHES/$group/$project"/*.patch 2>/dev/null); do
            if git apply --reverse --check "$patch" 2>/dev/null; then
                git apply --reverse "$patch"
                echo "OK   reverted $p/$(basename "$patch")"
            fi
        done
        popd > /dev/null
    done
}

for g in patches_gsi patches_treble patches_treble_td patches_treble_prerequisite; do
    revert_group "$g"
done

echo ""
echo "Done. Untracked leftovers (new files from patches) can be removed with:"
echo "  git status --porcelain | grep '^??'   (in each touched repo)"
echo "  git clean -fd   (only in repos that gained new files)"