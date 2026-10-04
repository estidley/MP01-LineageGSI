# MP01 development fork

Upstream: https://github.com/MP01Experiments/MP01-LineageGSI
Fork: https://github.com/estidley/MP01-LineageGSI
Development branch: `codex/mp01-bringup`

The first build targets the upstream Android 15 / LineageOS 22.2 Google-enabled
configuration, including the MP01 display service, hardware keyboard maps,
FinQwerty, and the upstream inkOS APK. Google Play services are included at the
user's request. `MP01_VARIANT=vanilla` selects a Google-free build instead.
Establish hardware compatibility before replacing more system components.

On a fresh setup, the MP01 service selects a light system theme and disables
window, transition, and animator animations. It applies these defaults once,
preserves choices on already configured devices, and permits later customization.
These defaults still require build and on-device validation.

## Workstation

Windows checkout: `C:\Users\Estid\OneDrive\Documents\ChatGPT\Android\MP01-LineageGSI`

Linux support checkout: `/home/estid/mp01/MP01-LineageGSI` in WSL `MP01-Build`.
Android source: `/mnt/mp01-source/source`, linked at `/mnt/mp01-build/source`.
The dedicated `MP01-Build` distro uses a native WSL virtual disk at
`F:\MP01-Builds\WSL\ext4.vhdx` on the SATA SSD. Source lives in `/sourcevol`.
The `MP01-Output` distro uses `D:\MP01-Builds\WSL\ext4.vhdx` and exposes
`/build` at `/mnt/wsl/mp01-output`. Build output, cache, logs, and images are
bound at `/mnt/mp01-build` in the build distro. Both disks grow with usage.
Never compile Android in OneDrive or directly on a Windows filesystem.
Earlier loop filesystem images and incomplete downloads are preserved on D:
and F:; they are no longer the active build environment.

After a WSL restart, keep this output mount command running in one terminal:

```powershell
wsl -d MP01-Output -u root -- bash /mnt/c/Users/Estid/OneDrive/Documents/ChatGPT/Android/MP01-LineageGSI/scripts/mount-wsl-output.sh
```

Then start or resume the build in another terminal:

```powershell
wsl -d MP01-Build -u root -- bash /mnt/c/Users/Estid/OneDrive/Documents/ChatGPT/Android/MP01-LineageGSI/scripts/run-wsl-build.sh
```

Run `bash scripts/build-local.sh sync` to download source, then
`bash scripts/build-local.sh build` to patch and compile, or omit the argument
to run both. `MP01_JOBS` defaults to 8 for the current WSL memory limit.
Compilation and downloads may take hours.

The local script stops at patch conflicts, records a revision-pinned Android
manifest after sync, verifies the pinned FinQwerty and F-Droid APKs, and writes an image
checksum. It does not publish releases, push commits, or operate on the phone.
The upstream `build.sh` is a maintainer publishing workflow; use the local script.

Progress: `/mnt/mp01-build/status.txt`; full logs: `/mnt/mp01-build/logs/`.
Output: `/mnt/mp01-build/images/`.
This is a userdebug development build using Android development signing keys.
A successful compilation does not establish that the image works on the phone.

## Phone installation gate

Before issuing unlock, flash, or erase commands:

1. Detect exactly the intended MP01 and collect its current firmware and hardware
   information using read-only ADB commands.
2. Record the user's backup decision and acceptance of the required data erase.
   For this installation, the user waived backup and authorized erasure.
3. Obtain and verify the applicable stock factory firmware for recovery.
4. Verify the built image checksum, architecture, partition compatibility, and
   required screen firmware against the upstream installation guide.

After installation, verify boot, the physical keyboard and modifiers, refresh
controls, calling and SMS, mobile data/IMS, Wi-Fi, Bluetooth, sleep/wake, and
charging. Record failures before claiming the ROM is usable.

Installation reference: https://chardidath.ing/posts/mp01-flashing-guide/
