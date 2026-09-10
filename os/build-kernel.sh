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

board=""; jobs="$(nproc)"; out="build"; config_only=0
while [ $# -gt 0 ]; do
  case "$1" in
    --board) board="$2"; shift 2 ;;
    --jobs)  jobs="$2";  shift 2 ;;
    --out)   out="$2";   shift 2 ;;
    # Validate that the config delta lands, without the compile. This is the
    # part that actually catches a silently-dropped fragment, it needs no cross
    # toolchain, and it runs in seconds instead of tens of minutes -- so it is
    # worth having as its own check rather than only as a build prelude.
    --config-only) config_only=1; shift ;;
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

# Refuse to build into a RAM-backed filesystem.
#
# On tmpfs every byte of the object tree is an unevictable page: unlike the page
# cache, the kernel cannot drop it under pressure, only push it to swap.
#
# Honest sizing: this config is 2009 built-in against 155 modules with
# DEBUG_INFO_REDUCED, so its object tree is a few GB, not the tens of GB an
# allmodconfig build produces. It would fit the tmpfs on this host. The guard is
# cheap insurance for a bigger config or a smaller box, not a fix for an
# incident -- no OOM has ever been attributed to this.
#
# Not hypothetical -- 3shn/nix records it in modules/powerful-server.nix: a
# `cargo test --workspace` overflowed a fresh 4 GiB tmpfs on ai-gateway
# (2026-07-03, ENOSPC mid-compile, ld.lld SIGBUS on mmap). The fix there was to
# bind-mount the runner work dir to disk.
#
# You do not need a RAM disk to use RAM for build I/O: the page cache already
# does that, for free, and hands it back when something else needs it.
out_fs=$(findmnt -no FSTYPE -T "$out" 2>/dev/null || echo unknown)
case "$out_fs" in
  tmpfs|ramfs)
    echo "refusing to build in $out: it is on $out_fs (RAM-backed)" >&2
    echo "Object trees are unevictable pages there, and tmpfs is lost on reboot." >&2
    echo "Pass --out with a path on a disk-backed filesystem." >&2
    exit 7 ;;
esac
echo "build dir:   $out ($out_fs)"
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
# Both directions of the delta are checked. An earlier version skipped every
# comment line, which silently meant the options we *disable* were never
# verified -- half a delta asserted and reported as the whole one.
missing=0
while read -r line; do
  case "$line" in
    "") continue ;;
    "# CONFIG_"*" is not set")
      opt="${line#\# }"; opt="${opt%% is not set}"
      if grep -qx "# $opt is not set" "$out/obj/.config"; then
        printf '  %-34s %s\n' "$opt" "n"
      else
        actual=$(grep -E "^$opt=" "$out/obj/.config" || echo absent)
        printf '  %-34s WANTED n, GOT %s\n' "$opt" "${actual:-absent}"
        missing=1
      fi
      continue ;;
    \#*) continue ;;
  esac
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

if [ "$config_only" -eq 1 ]; then
  echo
  echo "config-only: delta verified, compile skipped by request"
  exit 0
fi

dtb=$(y boot_artifacts.dtb)
echo
echo "building with -j$jobs ..."
echo "  targets: Image, $dtb, modules"
time make -C "$tree" O=../obj -j"$jobs" Image "$dtb" modules

echo
echo "artefacts:"
ls -l "$out/obj/arch/arm64/boot/Image" 2>/dev/null || true
