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

Linux support checkout: `/home/estid/mp01/MP01-LineageGSI` in WSL Ubuntu.
Android source: `/mnt/mp01-source/source`, linked at `/mnt/mp01-build/source`.
Source filesystem: `F:\MP01-Builds\android-source.ext4`, a sparse 300 GiB image
on the SATA SSD. Build output, cache, logs, and images: `/mnt/mp01-build`.
Output filesystem: `D:\MP01-Builds\android-build.ext4`, a sparse 600 GiB ext4
image. Its maximum size is reserved logically; actual usage grows with the build.
It must be mounted before starting the build. Never compile Android in OneDrive
or directly on a Windows filesystem.

To remount after a WSL restart, from PowerShell:

```powershell
wsl -d Ubuntu -u root -- mkdir -p /mnt/mp01-build
wsl -d Ubuntu -u root -- mount -o loop,noatime /mnt/d/MP01-Builds/android-build.ext4 /mnt/mp01-build
wsl -d Ubuntu -u root -- mkdir -p /mnt/mp01-source
wsl -d Ubuntu -u root -- mount -o loop,noatime /mnt/f/MP01-Builds/android-source.ext4 /mnt/mp01-source
```

Run the mount command and build within the same WSL invocation if Ubuntu exits
between commands; mounts are lost when WSL stops. For example:

```powershell
wsl -d Ubuntu -u root -- bash -lc 'set -e; mkdir -p /mnt/mp01-build /mnt/mp01-source; mountpoint -q /mnt/mp01-build || mount -o loop,noatime /mnt/d/MP01-Builds/android-build.ext4 /mnt/mp01-build; mountpoint -q /mnt/mp01-source || mount -o loop,noatime /mnt/f/MP01-Builds/android-source.ext4 /mnt/mp01-source; runuser -u estid -- bash /home/estid/mp01/MP01-LineageGSI/scripts/build-local.sh'
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
2. Confirm the user's backup and acceptance of the required data erase.
3. Obtain and verify the applicable stock factory firmware for recovery.
4. Verify the built image checksum, architecture, partition compatibility, and
   required screen firmware against the upstream installation guide.

After installation, verify boot, the physical keyboard and modifiers, refresh
controls, calling and SMS, mobile data/IMS, Wi-Fi, Bluetooth, sleep/wake, and
charging. Record failures before claiming the ROM is usable.

Installation reference: https://chardidath.ing/posts/mp01-flashing-guide/
