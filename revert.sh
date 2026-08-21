#!/bin/bash
# revert.sh - undo the Treble/GSI patchset that was applied with Treble/apply.sh
# (git apply -R, in reverse order). Does NOT touch commits; untracked files
# created by patches are removed with git clean -fd (only with --clean).
#
# Nothing is skipped silently: every patch that cannot be reverse-applied is
# reported, and a final audit lists every touched repo that is still not
# pristine (modified tracked files and/or untracked leftovers), so a partial
# revert can never go unnoticed.
#
# Usage:
#   bash Treble/revert.sh           # revert + report leftovers
#   bash Treble/revert.sh --clean   # also run `git clean -fd` in touched
#                                   # repos to drop untracked files created
#                                   # by patches (and leftover empty dirs).
#                                   # Only do this with no other local work!
set -e

ROOT="$(dirname "$(readlink -f "$0")")/.."
PATCHES="$ROOT/Treble/patches"
CLEAN=0
[ "${1:-}" = "--clean" ] && CLEAN=1

FAILED=0
TOUCHED=""

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
    echo "=== $group ==="
    # reverse = last group first, last patch of each project first
    local project p patch attempted
    for project in $(cd "$PATCHES/$group" && ls | tac); do
        p=$(map_path "$project")
        if [ ! -e "$ROOT/$p/.git" ]; then
            echo "SKIP (repo missing): $project -> $p"
            continue
        fi
        pushd "$ROOT/$p" > /dev/null
        attempted=0
        for patch in $(ls "$PATCHES/$group/$project"/*.patch 2>/dev/null | sort -r); do
            attempted=1
            if git apply --reverse --check "$patch" 2>/dev/null; then
                git apply --reverse "$patch"
                echo "OK   reverted $p/$(basename "$patch")"
            else
                echo "!!   NOT reverted: $p/$(basename "$patch")"
                echo "     (never applied, or the file changed after apply)"
                FAILED=1
            fi
        done
        [ "$attempted" = 1 ] && TOUCHED="$TOUCHED $p"
        popd > /dev/null
    done
}

for g in patches_gsi patches_treble patches_treble_td patches_treble_prerequisite; do
    revert_group "$g"
done

echo ""
echo "=== Audit: touched repos still not pristine ==="
DIRTY=0
for p in $TOUCHED; do
    pushd "$ROOT/$p" > /dev/null
    st="$(git status --porcelain)"
    leftovers="$(git clean -ndf)"
    if [ -n "$st" ] || [ -n "$leftovers" ]; then
        DIRTY=1
        echo "-- $p"
        [ -n "$st" ] && echo "$st" | sed 's/^/     /'
        [ -n "$leftovers" ] && echo "$leftovers" | sed 's/^/     /'
        if [ "$CLEAN" = 1 ] && [ -n "$leftovers" ]; then
            git clean -fd > /dev/null
            echo "     (ran git clean -fd)"
        fi
    fi
    popd > /dev/null
done
if [ "$DIRTY" = 0 ]; then
    echo "(none - every touched repo matches its git HEAD)"
else
    echo "Tracked-file diffs above = revert was INCOMPLETE; untracked/empty-dir"
    echo "lines above = patch-created leftovers (re-run with --clean to drop)."
fi

echo ""
if [ "$FAILED" = 1 ] || [ "$DIRTY" = 1 ]; then
    echo "Finished WITH WARNINGS - inspect the '!!' and audit output above."
    exit 1
fi
echo "Revert complete."
