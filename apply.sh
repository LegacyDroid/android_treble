#!/bin/bash
# apply.sh - apply the Treble/GSI patchset to this source tree via git apply.
# NO commits are made; the tree stays unpushed and clean(ish) - uncommitted only.
# Also installs the kit's local manifest and repo-syncs any Treble repos that
# are missing (device/phh/treble, treble_app, ...), so a fresh tree just works.
# Usage: bash Treble/apply.sh
set -e

ROOT="$(dirname "$(readlink -f "$0")")/.."
PATCHES="$ROOT/Treble/patches"
MANIFEST_SRC="$ROOT/Treble/local_manifests/10-gsi.xml"
FAILED=0

ensure_treble_repos() {
    if [ ! -d "$ROOT/.repo" ]; then
        echo "WARN no .repo workspace at $ROOT - skipping manifest/sync step"
        return 0
    fi
    local dst="$ROOT/.repo/local_manifests/10-gsi.xml"
    if [ ! -f "$dst" ]; then
        mkdir -p "$ROOT/.repo/local_manifests"
        cp "$MANIFEST_SRC" "$dst"
        echo "OK   installed local manifest: .repo/local_manifests/10-gsi.xml"
    fi
    # Sync only the manifest projects that are still missing from the tree.
    local missing=""
    local path
    while IFS= read -r path; do
        if [ ! -e "$ROOT/$path/.git" ]; then
            missing="$missing $path"
        fi
    done < <(grep -o 'path="[^"]*"' "$MANIFEST_SRC" | cut -d'"' -f2)
    if [ -z "$missing" ]; then
        echo "OK   all Treble repos present"
        return 0
    fi
    echo "=== repo sync (missing Treble repos:$missing ) ==="
    if ! (cd "$ROOT" && repo sync -c --no-tags -j8 $missing); then
        echo "WARN repo sync failed - continuing; patches for missing repos will be skipped"
    fi
}

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
            echo "SKIP (repo missing - was repo sync interrupted/offline?): $project"
            continue
        fi
        pushd "$ROOT/$p" > /dev/null
        assert_clean "$p"
        for patch in "$PATCHES/$group/$project"/*.patch; do
            [ -f "$patch" ] || continue
            if git apply --check "$patch" 2>/dev/null; then
                git apply "$patch"
                echo "OK   $p/$(basename "$patch")"
            elif git apply --reverse --check "$patch" 2>/dev/null; then
                echo "==   already applied: $p/$(basename "$patch")"
            else
                echo "!!   SKIP (does not apply): $p/$(basename "$patch")"
                FAILED=1
            fi
        done
        popd > /dev/null
    done
}

ensure_treble_repos

for g in patches_treble_prerequisite patches_treble_td patches_treble patches_gsi; do
    apply_group "$g"
done

echo ""
if [ "$FAILED" = 1 ]; then
    echo "Some patches did not apply cleanly - inspect output above."
else
    echo "All patches applied. Uncommitted changes only - nothing was committed."
fi