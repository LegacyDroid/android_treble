# Patch status

- Applied: 2026-08-08 against this tree
- Reference source: `AndyCGYan/lineage_patches_unified` branch `lineage-21-td`
  (the patch set used for upstream "LineageOS 21 TrebleDroid-based" GSIs)
- Tree base: `legacydroid-14` (LineageOS 21 / Android 14, AOSP android-14.0.0_r67)

## Result

| Group | Applied | Failed |
|-------|---------|--------|
| patches_treble_prerequisite | 7 | 0 |
| patches_treble_td | 186 | 0 |
| patches_treble | 4 | 1 (obsolete) |

## Notes / skipped

1. `vendor_lineage/0001-build_soong-Disable-generated_kernel_headers.patch`
   (patches_treble) does **not** apply — already a no-op in this tree
   (removed kernel-header generator in commit `65a70d9c`). Nothing needed.
2. `device/phh/treble` patches apply only after `repo sync` with
   `local_manifests/10-gsi.xml` (that repo is not part of the default manifest).
3. `treble_app` patches likewise require the manifest-provided `treble_app` repo.
4. The `patches_platform*` groups (personal/aesthetic UI tweaks) are intentionally
   **not** included; this kit only contains Treble/GSI functionality patches:
   prerequisite + td + treble groups.