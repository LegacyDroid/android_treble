# Treble / GSI patch kit — LegacyDroid 14 (arm64)

Patch kit that turns the LegacyDroid source tree (LineageOS 21 / Android 14,
branch `legacydroid-14`) into an arm64 GSI builder. No commits go to the ROM's
git remotes — everything is `git apply` only.

Everything lives in `./Treble` as its own git repo:

- `patches/` — the patchset
- `local_manifests/10-gsi.xml` — Treble device repos, fetched via `repo`
- `apply.sh` / `revert.sh` — apply / undo via `git apply` (no commits)
- `STATUS.md` — per-group results against this tree

Based on AndyCGYan's `lineage_patches_unified` (branch `lineage-21-td`).

---

## Patch groups

| Group | Patches | What / why |
|-------|---------|------------|
| `patches_treble_prerequisite` | 7 | Undo LOS-specific hacks (UDFPS, Bluetooth, protobuf-vendorcompat) that break generic boot/rendering on non-LOS devices |
| `patches_treble_td` | 185 | TrebleDroid platform set: selinux workarounds, legacy BPF / kernel-5.10, sysbta tweaks, telephony fallbacks, no-vendor resilience |
| `patches_treble` | 13 | Build/device bits: `device/phh/treble`, `init.vndk-nodef.rc` removal, sbin restore for Magisk, `treble_app` |
| `patches_gsi` | 4 | Kit's own fixes — without them the arm64 GSI won't build or boot |

Dead/merged patches live in `patches_obsolete/`. `apply.sh`/`revert.sh`
don't scan it, so a clean apply ends with "All patches applied." See
`STATUS.md` for why each was retired.

The four `patches_gsi` patches:

| Patch | Why |
|-------|-----|
| `build_make/0001-aosproot-skip-*` | GSI targets have no kernel. Magisk root injection via aosproot is a no-op when `TARGET_NO_KERNEL` is set; device/emulator builds keep root. |
| `build_make/0002-drop-sepolicy-v28-*` | LOS21 dropped the sepolicy v28 Soong module; TD re-added 28.0, ninja demanded a CIL nobody builds. Dropped 28.0 (29.0–34.0 untouched). |
| `vendor_legacydroid/0001-ncnn-prebuilts-*` | Soong rejects `srcs` + `arch.arm64.srcs` on prebuilts. Moved both ABIs into per-arch `srcs` blocks. |
| `system_sepolicy/0001-bpfloader-*` | TD grants `network_stack` fs_bpf read/write but `bpfloader.te` neverallow only whitelisted `netd`. Added the missing exception. |

(Termux/SimpMusic boot-install fix lives upstream in `vendor/legacydroid`
since `5fa20d8` — shell-domain install, no magisk — so no kit patch needed.)

## Repos (manifest)

`local_manifests/10-gsi.xml` adds repos the default manifest lacks:

- `device/phh/treble`, `treble_app`, `vendor/hardware_overlay`
- `vendor/interfaces`, `vendor/vndk-tests`, `vendor/lptools`, `vendor/magisk`
- `packages/apps/QcRilAm`, `prebuilts/vndk/v28`

`apply.sh` installs the manifest and repo-syncs missing repos. Manual:

```sh
cp Treble/local_manifests/10-gsi.xml .repo/local_manifests/
repo sync
```

## Build

```sh
bash Treble/apply.sh

source build/envsetup.sh
lunch lineage_gsi_arm64-${aosp_target_release}-userdebug
m -j12 systemimage
```

Output:

```sh
out/target/product/generic_arm64/system.img      # ~2.4 GiB
```

## Revert

```sh
bash Treble/revert.sh
```

Reverse-applies every patch, removes the local manifest, then force-touches
repos back to HEAD (`git checkout HEAD -- . && git clean -fd`). Patches that
can't reverse-apply are reported with `!!`. Exit code is non-zero if anything
looks off.

## Flash

```sh
adb reboot bootloader
fastboot -w flash system system.img
fastboot reboot
```

Device must be unlocked. `-w` wipes userdata (required when switching GSIs).

Decompress before flashing if the image is `.zst`:

```sh
zstd -d system.img.zst -o system.img
```
