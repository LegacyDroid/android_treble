# Patch status

- Applied: 2026-08-08 against this tree
- Reference source: `AndyCGYan/lineage_patches_unified` branch `lineage-21-td`
  (the patch set used for upstream "LineageOS 21 TrebleDroid-based" GSIs)
- Tree base: `legacydroid-14` (LineageOS 21 / Android 14, AOSP android-14.0.0_r67)

## Result

| Group | Applied | Failed |
|-------|---------|--------|
| patches_treble_prerequisite | 7 | 0 |
| patches_treble_td | 185 | 0 |
| patches_treble | 13 | 0 |
| patches_gsi | 4 | 0 |

(2026-08-21: six dead/merged patches moved to `patches_obsolete/` — see
changelog "convergence" entry. Counts reflect the active set.)

## Changelog

### 2026-08-21

- **revert.sh rewritten.** It used to swallow every failure
  (`git apply --reverse --check ... 2>/dev/null` + `if`), so a partial revert
  was invisible — you could not tell which repo got skipped. It now prints
  every patch it cannot reverse (`!!` lines), then audits all touched repos
  for modified tracked files and untracked/empty-dir leftovers, and exits
  non-zero if anything is off. `--clean` opt-in runs `git clean -fd`.
- **Identified the "obsolete" patches_treble failure**: TD patch
  `0001-build_soong-Disable-generated_kernel_headers` targets
  `vendor/lineage/build/soong/Android.bp`, but LegacyDroid already replaced
  `generated_kernel_headers` with a stub ("Stub kernel headers for emulator
  build"), so there is nothing left to remove. Genuinely obsolete here; stays
  unapplied by design (revert.sh reports it as `!!`, which is expected).
- **Termux/SimpMusic GSI fix merged upstream** into `vendor/legacydroid`
  (commit `5fa20d8`, local branch `legacydroid-14` — push when ready): the
  boot-time `pm install` ran as `u:r:magisk:s0`, which does not exist once
  aosproot root injection is skipped (no kernel), so both APKs shipped in the
  GSI but never installed. Now runs as `u:r:shell:s0 shell shell`. The
  temporary kit patch `patches_gsi/vendor_legacydroid/0002-*` was removed;
  patches_gsi is back to 4 patches.

### 2026-08-21 (later)

- **Build fix**: TD patch `frameworks_base/0017-TelephonyManager-bring-back-
  getNetworkClass` duplicated `getNetworkClass()` + `NETWORK_CLASS_*` —
  LegacyDroid's frameworks/base never removed them (AOSP did, which the TD
  patch assumes). Java compile fails with "duplicate declaration of field".
  New patch `patches_gsi/frameworks_base/0001-drop-duplicate-getNetworkClass-
  block-from-td-0017.patch` removes the TD-introduced copy. patches_gsi is
  now 5 patches.

### 2026-08-21 (convergence)

- **apply.sh made idempotent across repeated runs.** Two problems fixed:
  1. **Duplicate insertion**: pure-addition patches (e.g., td 0031, 0006,
     vendor800) found new offsets each run via `git apply --check`, silently
     inserting duplicates. Added `content_already_present()` — checks the
     first added line against the target file before applying. If already
     present, reports `== (content match)` instead of applying.
  2. **Telephony oscillation**: td `0017-TelephonyManager-bring-back-
     getNetworkClass` re-added a block every run, then
     `0001-drop-duplicate-getNetworkClass` removed it — both printed `OK`
     forever. Both retired to `patches_obsolete/` (LegacyDroid already ships
     `getNetworkClass()`).
- **Also retired** (moved to `patches_obsolete/`):
  - `platform_build/0001-Include-vndk-v28-*` — sole effect was adding `28.0`
    to `PLATFORM_SEPOLICY_COMPAT_VERSIONS`, which
    `build_make/0002-drop-sepolicy-v28-*` immediately removes (oscillator).
  - `device_phh_treble/0001-Lineage-ify` + `0002-BOARD_EXT4_SHARE_DUP-*` —
    upstream TrebleDroid already merged both.
  - `vendor_lineage/0001-build_soong-*` — dead since day one.
- **Dirty-repo handling**: patches that fail both directions on repos with
  local changes (context drifted from upstream syncs or local commits) now
  report `?? cannot verify` without failing the summary.
- A fully-applied tree now ends with "All patches applied." — any future `!!`
  is a real problem on a clean repo.
- README/STATUS counts updated (td 185, treble 13, gsi 4).
