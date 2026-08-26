#!/bin/bash
# revert.sh - fully undo the Treble/GSI patchset that was applied with
# Treble/apply.sh:
#   1. reverse-apply every patch (git apply -R), last group/patch first
#   2. remove the kit's local manifest (.repo/local_manifests/10-gsi.xml)
#   3. in every touched repo, discard any remaining uncommitted changes
#      (git checkout HEAD -- .) and drop untracked files (git clean -fd),
#      so the tree ends up matching its git HEAD
#
# Commits are never touched.
#
# Nothing is skipped silently: every patch that cannot be reverse-applied is
# reported, and a final audit lists anything that survived cleanup.
#
# Usage: bash Treble/revert.sh
set -e

ROOT="$(dirname "$(readlink -f "$0")")/.."
PATCHES="$ROOT/Treble/patches"
MANIFEST_DST="$ROOT/.repo/local_manifests/10-gsi.xml"

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

remove_manifest() {
    if [ ! -f "$MANIFEST_DST" ]; then
        echo "OK   no local manifest installed"
        return 0
    fi
    rm "$MANIFEST_DST"
    rmdir "$(dirname "$MANIFEST_DST")" 2>/dev/null || true
    echo "OK   removed local manifest: .repo/local_manifests/10-gsi.xml"
}

for g in patches_gsi patches_treble patches_treble_td patches_treble_prerequisite; do
    revert_group "$g"
done

echo ""
echo "=== Local manifest ==="
remove_manifest

echo ""
echo "=== Cleanup: force touched repos back to HEAD ==="
DIRTY=0
for p in $TOUCHED; do
    pushd "$ROOT/$p" > /dev/null
    st="$(git status --porcelain)"
    if [ -n "$st" ]; then
        echo "-- $p"
        echo "$st" | sed 's/^/     /'
        git checkout HEAD -- .
        git clean -fd > /dev/null
        echo "     (discarded: git checkout HEAD -- . && git clean -fd)"
        [ -n "$(git status --porcelain)" ] && DIRTY=1
    fi
    popd > /dev/null
done
if [ "$DIRTY" = 0 ]; then
    echo "(every touched repo now matches its git HEAD)"
else
    echo "!! some repos are still not pristine after cleanup - inspect above."
fi

echo ""
if [ "$FAILED" = 1 ] || [ "$DIRTY" = 1 ]; then
    echo "Finished WITH WARNINGS - inspect the '!!' output above."
    exit 1
fi
echo "Revert complete."
