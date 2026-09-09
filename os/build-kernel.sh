#!/usr/bin/env bash
# Build a board's kernel from its pinned vendor source plus its config fragments.
#
# We build our own kernel rather than shipping the vendor binary because the
# vendor's shipped configuration is missing options this platform requires --
# established by extracting the config out of their boot.img, not by reading
# their defconfig, which claims a Docker fragment they never applied.
#
# The source tarball is GPL-2.0. We must be able to hand its exact contents to
# anyone who receives a device, so the build pins it by sha256 and refuses to
# proceed on a mismatch: a corresponding-source obligation you cannot reproduce
# is not discharged.
#
# Usage:
#   os/build-kernel.sh --board <id> [--jobs N] [--out DIR]
# Source is taken from, in order:
#   $BSP_KERNEL_TARBALL   local path
#   $BSP_KERNEL_URL       downloaded, then hash-checked
set -euo pipefail
cd "$(dirname "$0")/.."

board=""; jobs="$(nproc)"; out="build"
while [ $# -gt 0 ]; do
  case "$1" in
    --board) board="$2"; shift 2 ;;
    --jobs)  jobs="$2";  shift 2 ;;
    --out)   out="$2";   shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ -n "$board" ] || { echo "--board is required" >&2; exit 2; }

profile="boards/$board"
[ -d "$profile" ] || { echo "no such board profile: $profile" >&2; exit 2; }

# Read the profile. yq is not assumed; these are simple scalars and lists.
y() { python3 -c "
import sys,yaml
d=yaml.safe_load(open('$profile/kernel.yaml'))
for k in '$1'.split('.'): d=d[k]
print(d if not isinstance(d,list) else '\n'.join(map(str,d)))
"; }

want_sha=$(y source.sha256)
tarball_name=$(y source.file)
version=$(y source.version)
mapfile -t fragments < <(y config_fragments)

echo "board:    $board"
echo "kernel:   $version ($tarball_name)"
echo "fragments:"; printf '  %s\n' "${fragments[@]}"

mkdir -p "$out"
src_tar="${BSP_KERNEL_TARBALL:-}"
if [ -z "$src_tar" ]; then
  [ -n "${BSP_KERNEL_URL:-}" ] || {
    echo >&2
    echo "No kernel source available. Set BSP_KERNEL_TARBALL to a local path, or" >&2
    echo "BSP_KERNEL_URL to where the GPL-2.0 source is published." >&2
    exit 3
  }
  src_tar="$out/$tarball_name"
  [ -f "$src_tar" ] || curl -fsSL -o "$src_tar" "$BSP_KERNEL_URL"
fi

got_sha=$(sha256sum "$src_tar" | cut -d' ' -f1)
if [ "$got_sha" != "$want_sha" ]; then
  echo "kernel source hash mismatch -- refusing to build" >&2
  echo "  expected $want_sha" >&2
  echo "  got      $got_sha" >&2
  exit 4
fi
echo "source hash: $got_sha (matches $profile/kernel.yaml)"

tree="$out/linux"
if [ ! -d "$tree" ]; then
  mkdir -p "$tree"
  tar xzf "$src_tar" -C "$tree"
fi

export ARCH=arm64
export CROSS_COMPILE="${CROSS_COMPILE:-aarch64-linux-gnu-}"

# Resolve fragments: entries are paths inside the kernel tree, except ours,
# which live in the board profile.
resolved=()
for f in "${fragments[@]}"; do
  if [ -f "$tree/$f" ]; then resolved+=("$tree/$f")
  elif [ -f "$profile/$f" ]; then resolved+=("$(pwd)/$profile/$f")
  else echo "fragment not found: $f" >&2; exit 5; fi
done

base="${resolved[0]}"
make -C "$tree" O=../obj "$(basename "$base")" >/dev/null
if [ "${#resolved[@]}" -gt 1 ]; then
  "$tree/scripts/kconfig/merge_config.sh" -m -O "$out/obj" \
    "$out/obj/.config" "${resolved[@]:1}"
  make -C "$tree" O=../obj olddefconfig >/dev/null
fi

# The point of the whole exercise: prove our delta actually landed. A fragment
# that silently failed to apply looks exactly like a fragment that was applied,
# which is why this asserts rather than reports.
echo
echo "verifying the config delta actually applied:"
missing=0
while read -r line; do
  case "$line" in \#*|"") continue ;; esac
  opt="${line%%=*}"; val="${line#*=}"
  if grep -qx "$opt=$val" "$out/obj/.config"; then
    printf '  %-34s %s\n' "$opt" "$val"
  else
    actual=$(grep -E "^($opt=| *# $opt is not set)" "$out/obj/.config" || echo "absent")
    printf '  %-34s WANTED %s, GOT %s\n' "$opt" "$val" "${actual:-absent}"
    missing=1
  fi
done < "$profile/fragments/ems-edge.config"
[ $missing -eq 0 ] || { echo "config delta did not apply -- refusing to build" >&2; exit 6; }

echo
echo "building with -j$jobs ..."
time make -C "$tree" O=../obj -j"$jobs" Image dtbs modules

echo
echo "artefacts:"
ls -l "$out/obj/arch/arm64/boot/Image" 2>/dev/null || true
