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

# Check whether a patch's added content is already present in the target file.
# Uses the first non-empty added line as a signature.  This catches the case
# where git apply --check passes at a NEW offset (pure-addition patches with
# non-unique surrounding context) but the effect is already in the file —
# applying would silently insert a duplicate.
content_already_present() {
    local patch="$1" file="$2"
    [ -f "$file" ] || return 1
    # Only check pure additions — patches with removals (mixed or remove-only)
    # can't be content-checked reliably.
    grep -q '^-\([^-]\|$\)' "$patch" && return 1
    # Get first 3 substantive added lines (skip comments, blanks, annotations)
    # as a combined signature — one-line matches are too generic.
    local sig
    sig=$(sed -n '/^+[^+]/s/^+//p' "$patch" | sed '/^[[:space:]]*$\|^[[:space:]]*\/[/*]\|^[[:space:]]*\*\|^[[:space:]]*@/d' | head -3)
    [ -z "$sig" ] && return 1
    # All 3 lines must be present (not necessarily adjacent) in the file
    local all_present=true
    while IFS= read -r line; do
        grep -qF "$line" "$file" 2>/dev/null || { all_present=false; break; }
    done <<< "$sig"
    $all_present
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
        local dirty=0
        [ -n "$(git status --porcelain)" ] && dirty=1
        for patch in "$PATCHES/$group/$project"/*.patch; do
            [ -f "$patch" ] || continue
            if git apply --check "$patch" 2>/dev/null; then
                local filepath
                filepath=$(grep '^diff --git' "$patch" | head -1 | sed 's|^diff --git a/[^ ]* b/||')
                if [ -n "$filepath" ] && content_already_present "$patch" "$filepath"; then
                    echo "==   already applied (content match): $p/$(basename "$patch")"
                else
                    git apply "$patch"
                    echo "OK   $p/$(basename "$patch")"
                fi
            elif git apply --reverse --check "$patch" 2>/dev/null; then
                echo "==   already applied: $p/$(basename "$patch")"
            elif [ "$dirty" = 1 ]; then
                echo "??   cannot verify (repo has local changes): $p/$(basename "$patch")"
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
