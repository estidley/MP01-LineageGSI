#!/usr/bin/env bash
# Run as root in MP01-Build after starting mount-wsl-output.sh in MP01-Output.
set -euo pipefail
mountpoint -q /mnt/wsl/mp01-output || { echo 'Start the MP01-Output mount first.' >&2; exit 1; }
mkdir -p /sourcevol/source /mnt/mp01-source /mnt/mp01-build
mountpoint -q /mnt/mp01-source || mount --bind /sourcevol /mnt/mp01-source
mountpoint -q /mnt/mp01-build || mount --bind /mnt/wsl/mp01-output /mnt/mp01-build
[[ -e /mnt/mp01-build/source ]] || ln -s /mnt/mp01-source/source /mnt/mp01-build/source
chown estid:estid /sourcevol/source /mnt/mp01-build
exec runuser -u estid -- bash /home/estid/mp01/MP01-LineageGSI/scripts/build-local.sh "${1:-all}"
