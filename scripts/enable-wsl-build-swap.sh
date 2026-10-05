#!/usr/bin/env bash
# Run as root after mounting the dedicated MP01 build filesystem.
set -euo pipefail
build_root=${MP01_BUILD_ROOT:-/mnt/mp01-build}
mountpoint -q "$build_root" || { echo 'Mount the MP01 build filesystem first.' >&2; exit 1; }
[[ $(stat -f -c %T "$build_root") == ext2/ext3 ]] || { echo 'An ext4 build filesystem is required.' >&2; exit 1; }
swap_file="$build_root/swap/soong.swap"
mkdir -p "$build_root/swap"
if [[ ! -e $swap_file ]]; then
    umask 077
    fallocate -l 24G "$swap_file"
    mkswap "$swap_file"
fi
[[ $(stat -c %s "$swap_file") == 25769803776 ]] || { echo 'Unexpected existing swap file size.' >&2; exit 1; }
if ! swapon --show=NAME --noheadings --raw | grep -Fxq -- "$swap_file"; then
    swapon "$swap_file"
fi
swapon --show
