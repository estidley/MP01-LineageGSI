#!/usr/bin/env bash
# Local development image only. Never publishes, flashes, or deletes a checkout.
set -Eeuo pipefail
shopt -s nullglob
support_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
build_root=${MP01_BUILD_ROOT:-/mnt/mp01-build}
jobs=${MP01_JOBS:-8}
variant=${MP01_VARIANT:-gapps}
case "$variant" in
    gapps) product=treble_arm64_bgN ;;
    vanilla) product=treble_arm64_bvN ;;
    *) echo 'MP01_VARIANT must be gapps or vanilla.' >&2; exit 2 ;;
esac
export MP01_VARIANT="$variant"
export GOGC=${GOGC:-50}
export GOMEMLIMIT=${GOMEMLIMIT:-20GiB}
export GOMAXPROCS=${GOMAXPROCS:-$jobs}
[[ $GOGC =~ ^[1-9][0-9]*$ && $GOMAXPROCS =~ ^[1-9][0-9]*$ ]] || { echo 'Go GC and concurrency settings must be positive integers.' >&2; exit 2; }
[[ $GOMEMLIMIT =~ ^[1-9][0-9]*(KiB|MiB|GiB|TiB|KB|MB|GB|TB|B)$ ]] || { echo 'GOMEMLIMIT must be a positive size, such as 20GiB.' >&2; exit 2; }
stage=${1:-all}
case "$stage" in all|sync|build) ;; *) echo 'Usage: build-local.sh [all|sync|build]' >&2; exit 2 ;; esac
[[ $jobs =~ ^[1-9][0-9]*$ ]] || { echo 'MP01_JOBS must be positive.' >&2; exit 2; }
mountpoint -q "$build_root" || { echo "Mount the dedicated build filesystem at $build_root first." >&2; exit 1; }
[[ $(stat -f -c %T "$build_root") == ext2/ext3 ]] || { echo 'An ext4 build filesystem is required.' >&2; exit 1; }
if [[ -L "$build_root/source" ]]; then
    mountpoint -q /mnt/mp01-source || { echo 'Mount the SSD source filesystem at /mnt/mp01-source first.' >&2; exit 1; }
fi
for tool in repo git git-lfs curl jq ccache unzip sha256sum; do
    command -v "$tool" >/dev/null || { echo "Missing dependency: $tool" >&2; exit 1; }
done
mkdir -p "$build_root/source" "$build_root/images" "$build_root/logs" "$build_root/cache"
exec 9>"$build_root/build.lock"
flock -n 9 || { echo 'Another MP01 build is running.' >&2; exit 1; }
log_file="$build_root/logs/build-$(date -u +%Y%m%dT%H%M%SZ).log"
exec > >(tee -a "$log_file") 2>&1
state() { printf '%s\n' "$1" > "$build_root/status.txt"; }
trap 'state "FAILED line $LINENO (see $log_file)"' ERR
export USE_CCACHE=1 CCACHE_EXEC=/usr/bin/ccache
export CCACHE_DIR="$build_root/cache"
export TMPDIR="$build_root/tmp"
export OUT_DIR="$build_root/out"
mkdir -p "$TMPDIR"
ccache -M 30G
cd "$build_root/source"
git config --global user.name >/dev/null 2>&1 || git config --global user.name estidley
git config --global user.email >/dev/null 2>&1 || git config --global user.email 36413107+estidley@users.noreply.github.com
if [[ $stage != build ]]; then
    state 'INITIALIZING AND DOWNLOADING SOURCE'
    repo init -u https://github.com/LineageOS/android.git -b lineage-22.2 --git-lfs --depth=1 --no-clone-bundle
    if [[ ! -e .repo/local_manifests ]]; then
        git clone -b 15-los-qpr2 https://github.com/MP01Experiments/treble_manifest.git .repo/local_manifests
        git -C .repo/local_manifests checkout 14b70f55973219b9fb752b4759d178b022906c4e
    fi
    # Restore the pinned manifest before selecting the requested variant.
    git -C .repo/local_manifests show 14b70f55973219b9fb752b4759d178b022906c4e:manifest.xml > .repo/local_manifests/manifest.xml
    python3 - <<'PY'
import os
from pathlib import Path
import xml.etree.ElementTree as ET
for path in Path('.repo/local_manifests').glob('*.xml'):
    tree = ET.parse(path)
    root = tree.getroot()
    for project in list(root.findall('project')):
        if project.get('path') == 'vendor/gapps' and os.environ['MP01_VARIANT'] == 'vanilla':
            root.remove(project)
    tree.write(path, encoding='utf-8', xml_declaration=True)
PY
    repo sync -c --no-tags --no-clone-bundle --optimized-fetch --fail-fast -j"$jobs"
    repo manifest -r -o "$build_root/images/source-manifest.xml"
    state 'SOURCE READY'
    [[ $stage != sync ]] || exit 0
fi
[[ -f build/envsetup.sh ]] || { echo 'Source download is incomplete.' >&2; exit 1; }
state 'APPLYING MP01 PATCHES'
for group in host trebledroid personal minimal; do
    for patch_dir in "$support_dir/patches/$group"/*; do
        [[ -d $patch_dir ]] || continue
        tree=${patch_dir##*/}
        tree=${tree//_//}
        tree=${tree#platform/}
        case "$tree" in
            build) tree=build/make ;;
            vendor/hardware/overlay) tree=vendor/hardware_overlay ;;
            treble/app) tree=treble_app ;;
            vendor/partner/gms) tree=vendor/partner_gms ;;
        esac
        [[ -d $tree ]] || { echo "Missing patch target: $tree" >&2; exit 1; }
        for patch_file in "$patch_dir"/*.patch; do
            if git -C "$tree" apply --reverse --check "$patch_file" 2>/dev/null; then
                echo "Already applied: ${patch_file##*/}"
                continue
            fi
            git -C "$tree" apply --check "$patch_file"
            git -C "$tree" -c user.name=estidley -c user.email=36413107+estidley@users.noreply.github.com am "$patch_file"
        done
    done
done
state 'PREPARING MP01 PRODUCT'
(cd device/phh/treble && bash generate.sh lineage)
cp "$support_dir/$product.mk" device/phh/treble/
cp -a "$support_dir/vendor/." vendor/
finqwerty_url=https://github.com/MP01Experiments/finqwerty/releases/download/76cef2d/finqwerty-release.apk
curl --fail --location --retry 3 --output vendor/finqwerty/finqwerty-release.apk "$finqwerty_url"
printf '%s  %s\n' d5fedb270671d13fa02177c53191bab6d76f99de133bac4c48efec65ed8d683e vendor/finqwerty/finqwerty-release.apk | sha256sum --check
unzip -t vendor/finqwerty/finqwerty-release.apk >/dev/null
curl --fail --location --retry 3 --output vendor/F-Droid/F-Droid.apk https://f-droid.org/repo/org.fdroid.fdroid_2000051.apk
printf '%s  %s\n' 83d3fe522281c3cb89fce3bc05038f81b3c3b32c108536941f184c5f9bb53778 vendor/F-Droid/F-Droid.apk | sha256sum --check
unzip -t vendor/F-Droid/F-Droid.apk >/dev/null
git -C "$support_dir" rev-parse HEAD > "$build_root/images/support-commit.txt"
state 'COMPILING DEVELOPMENT SYSTEM IMAGE'
# Android environment scripts do not support nounset.
set +u
source build/envsetup.sh
lunch "$product-bp1a-userdebug"
make systemimage -j"$jobs"
set -u
image="$OUT_DIR/target/product/tdgsi_arm64_ab/system.img"
[[ -s $image ]] || { echo 'No system image was produced.' >&2; exit 1; }
image_name="MP01-estidley-$variant-$(date -u +%Y%m%dT%H%M%SZ)-dev.img"
cp "$image" "$build_root/images/$image_name"
(cd "$build_root/images" && sha256sum "$image_name" > "$image_name.sha256")
state "BUILT $build_root/images/$image_name (device validation required)"
echo "Development image: $build_root/images/$image_name"
echo 'This userdebug image uses Android development keys; it is not a hardened release.'
