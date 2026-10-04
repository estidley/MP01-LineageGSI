#!/usr/bin/env bash
# Run as root in the dedicated MP01-Output WSL distro.
set -euo pipefail
mkdir -p /build /mnt/wsl/mp01-output
mountpoint -q /mnt/wsl/mp01-output || mount --bind /build /mnt/wsl/mp01-output
echo 'MP01 output filesystem mounted.'
exec sleep infinity
