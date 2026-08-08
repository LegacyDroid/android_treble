# Treble / GSI patch kit for this ROM

Turn this Android 14 (LineageOS 21 / "legacydroid-14") tree into an **arm64 GSI**
without committing anything into the source tree. All patches, the local repo
manifest and the helpers live here, in their own git repo.

Based on the canonical LineageOS-21 + TrebleDroid patchset maintained by
AndyCGYan (`lineage_patches_unified`, branch `lineage-21-td`) and used for the
public LOS21 TrebleDroid-based GSIs.

## What's inside

- `patches/` — the GSI patch groups (git-format patches, one per repo path):
  - `patches_treble_prerequisite` — undo LineageOS-specific hacks (UDFPS,
    Bluetooth, protobuf-vendorcompat) that break generic boot/render.
  - `patches_treble_td` — the TrebleDroid platform patchset (device support,
    no-vendor resilience: selinux workarounds, legacy BPF/kernel support,
    sysbta-ish tweaks, telephony fallbacks).
  - `patches_treble` — build-side and device-side bits (device_phh_treble
    patches, `init.vndk-nodef.rc` removal, Magisk-compatible sbin restore...).
- `local_manifests/10-gsi.xml` — repo local manifest adding the Treble repos
  (device (phh), vendor overlays, vndk v28 prebuilt, ...). Copy it to
  `.repo/local_manifests/`.
- `apply.sh` / `revert.sh` — apply or undo the patchset in the source tree
  with `git apply` (never commits).
- `STATUS.md` — which patches applied here and which were skipped & why.

## Usage

```sh
# 1. register the extra treble repos and fetch them
cp Treble/local_manifests/10-gsi.xml .repo/local_manifests/
repo sync

# 2. apply the patchset (working tree only, no commits)
bash Treble/apply.sh

# 3. build (NOT run here - owner runs this):
#    source build/envsetup.sh
#    source vendor/lineage/vars/aosp_target_release   # gives $aosp_target_release
#    lunch lineage_arm64_bvN-${aosp_target_release}-userdebug
#    make -j$(nproc --all) systemimage
#    # system.img = GSI, flashable on any arm64 device with a Treble
#    # user... (or make gsi with build/gsi/etc)

# undo everything again:
bash Treble/revert.sh
```

The `*_vN` / `*_gN` product variants (TVanilla / GApps) mirror upstream
naming. `vendor/hardware_overlay` holds the TrebleApp APK used for vendor
props override UI.

## Notes / status

- The full patchset was applied on 2026-08-08 against this exact tree
  (branch `legacydroid-14`, Android 14 / LineageOS 21). See `STATUS.md` for
  per-patch results.
- Patches which expect repos not yet present (e.g. `device/phh/treble`,
  `treble_app`) apply only after `repo sync` picks up the local manifest.
- Nothing is committed or pushed to the ROMs' own remotes; the tree only has
  uncommitted working-tree changes after `apply.sh`.