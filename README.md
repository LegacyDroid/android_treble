# Treble / GSI patch kit — LegacyDroid 14 (arm64)

This kit turns the **LegacyDroid** source tree (LineageOS 21 / Android 14,
branch `legacydroid-14`) into an **arm64 GSI** builder — without ever
committing or pushing a single byte to the ROM's own git remotes.

Everything lives here in `./Treble` as its own git repo:

- `patches/` — the complete, reproducible patchset
- `local_manifests/10-gsi.xml` — the Treble device repos, fetched via `repo`
- `apply.sh` / `revert.sh` — apply / undo everything with `git apply` (never commits)
- `STATUS.md` — per-group application results against this exact tree

Based on the canonical LineageOS 21 + TrebleDroid patchset maintained by
AndyCGYan (`lineage_patches_unified`, branch `lineage-21-td`), which is what the
public LOS21 TrebleDroid-based GSIs are built from.

---

## Patch groups

| Group | Patches | What / why |
|-------|---------|------------|
| `patches_treble_prerequisite` | 7 | Undo LineageOS-specific hacks (UDFPS, Bluetooth, protobuf-vendorcompat) that break generic boot and rendering on non-LOS devices |
| `patches_treble_td` | 184 | The TrebleDroid platform patch set: selinux workarounds, legacy BPF / kernel-5.10 support, sysbta-style tweaks, telephony fallbacks, no-vendor resilience |
| `patches_treble` | 10 | Build- and device-side bits: `device/phh/treble` support, `init.vndk-nodef.rc` removal, Magisk-compatible sbin restore, `treble_app` |
| `patches_gsi` | 4 | **This kit's own fixes** — without them the arm64 GSI would not build/boot right |

Patches that upstream has already merged (or that are dead on this tree)
live in `patches_obsolete/`, which apply.sh/revert.sh never scan — so a
fully-applied run ends with "All patches applied." instead of a false
failure. See `STATUS.md` for why each was retired.

The four hand-written `patches_gsi` patches, one line each:

| Patch | Why |
|-------|-----|
| `build_make/0001-aosproot-skip-*` | GSI/system-only targets have no kernel → no boot.img or ramdisk to root. Root injection (Magisk via aosproot) becomes a no-op when `TARGET_NO_KERNEL` is set; device/emulator builds keep root. |
| `build_make/0002-drop-sepolicy-v28-*` | LOS21 removed the sepolicy v28 Soong module (`prebuilts/api/28.0/Android.bp`); the TD list re-added version 28.0, so ninja demanded a CIL nobody builds. Dropped 28.0 from the compat list (29.0–34.0 untouched). |
| `vendor_legacydroid/0001-ncnn-prebuilts-*` | Soong rejects `srcs` + `arch.arm64.srcs` on prebuilt modules ("multiple prebuilt source files") — moved both ABIs into per-arch `srcs` blocks (no top-level `srcs`). |
| `system_sepolicy/0001-bpfloader-*` | The TD kit grants `network_stack` fs_bpf read/write (for BPF maps) but `bpfloader.te`'s neverallow only whitelisted `netd`; added the missing `-network_stack` exception so the policy compiles. |

(The Termux/SimpMusic boot-install fix lives upstream in
`vendor/legacydroid` since 5fa20d8 — shell-domain install instead of
magisk — so no kit patch is needed for it.)

## Repos (manifest)

`local_manifests/10-gsi.xml` adds the Treble repos the default manifest
doesn't have:

- `device/phh/treble` (TrebleDroid device), `treble_app`, `vendor/hardware_overlay`
- `vendor/interfaces`, `vendor/vndk-tests`, `vendor/lptools`, `vendor/magisk`
- `packages/apps/QcRilAm`, `prebuilts/vndk/v28`

`apply.sh` installs this manifest into `.repo/local_manifests/` and
repo-syncs any of these repos that are missing, so a fresh tree just
works. To do it manually instead:

```sh
cp Treble/local_manifests/10-gsi.xml .repo/local_manifests/
repo sync
```

## Build (verified 2026-08-09)

```sh
bash Treble/apply.sh            # git apply only — nothing is committed

source build/envsetup.sh
lunch lineage_gsi_arm64-${aosp_target_release}-userdebug
m -j12 systemimage # or mka systemimage
```

Result (raw ext4 system image, the standard GSI artifact):

```sh
out/target/product/generic_arm64/system.img      # ~2.4 GiB
```

Undo everything (including the file-tree changes):

```sh
bash Treble/revert.sh           # reverts in reverse order, then audits every
                                # touched repo and reports anything not pristine
bash Treble/revert.sh --clean   # additionally `git clean -fd` touched repos to
                                # drop untracked files/empty dirs left by patches
```

Notes:

- Patches that cannot be reverse-applied are reported with `!!`, never
  skipped silently. Patches known to be dead on this tree (upstream already
  merged them) live in `patches_obsolete/` and are not scanned at all.
- Exit code is non-zero if anything looks off, so it can be scripted.
- `--clean` wipes ALL untracked files in touched repos — only use it right
  after an apply→revert cycle with no other local work in those repos.

### Flash

```sh
adb reboot bootloader
fastboot -w flash system system.img
fastboot reboot
```

- Device must be **unlocked**; `-w` wipes userdata (required when switching GSIs).
- `system.img.zst` is for storage/transfer only — **decompress on the PC before flashing** (phones/bootloaders don't read `.zst` or `.zip` here):

  ```sh
  zstd -d system.img.zst -o system.img
  ```
