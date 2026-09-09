#!/usr/bin/env python3
"""Validate a board's partition table before anything is written to a device.

A partition table is the one artefact whose mistakes are not recoverable in the
field: a wrong offset does not fail a test, it bricks a unit that then has to be
physically retrieved. So it gets a check, and the check gets a control.

What this verifies:
  1. Every partition parses, with a size and a start.
  2. Partitions are contiguous and non-overlapping -- a gap is wasted space and
     usually a typo; an overlap is data loss.
  3. A/B slot pairs are the same size. The vendor's own table gets this wrong
     (boot_a 64 MiB, boot_b 128 MiB), which produces updates that work on one
     slot and fail on the other.
  4. Each boot slot has headroom for the largest boot image we intend to ship.
  5. The whole table fits the smallest eMMC the board is sold with, leaving a
     usable userdata remainder.

Usage: ci/check-partitions.py boards/<id>/parameter.txt [--emmc-gb N]
"""
import argparse, re, sys

SECTOR = 512
MiB = 1 << 20
GiB = 1 << 30

# Largest boot image we plan to ship, plus the margin our kernel delta needs.
# The vendor's own boot.img is 59,577,344 bytes; ours adds device-mapper,
# dm-verity, AppArmor and VLAN.
BOOT_IMAGE_BUDGET = 96 * MiB


def parse(path):
    text = open(path).read()
    m = re.search(r"^CMDLINE:.*?mtdparts=[^:]*:(.*)$", text, re.M)
    if not m:
        sys.exit(f"{path}: no CMDLINE mtdparts line")
    parts = []
    for spec in m.group(1).split(","):
        spec = spec.strip()
        mm = re.match(r"(-|0x[0-9a-fA-F]+)@(0x[0-9a-fA-F]+)\(([^)]+)\)", spec)
        if not mm:
            sys.exit(f"{path}: cannot parse partition spec {spec!r}")
        size = None if mm.group(1) == "-" else int(mm.group(1), 16)
        parts.append({"name": mm.group(3).split(":")[0],
                      "grow": ":grow" in mm.group(3),
                      "size": size, "start": int(mm.group(2), 16)})
    return parts


def check(parts, emmc_gb):
    problems = []

    fixed = [p for p in parts if p["size"] is not None]
    for a, b in zip(fixed, fixed[1:]):
        end = a["start"] + a["size"]
        if end > b["start"]:
            problems.append(f"{a['name']} overlaps {b['name']}: ends at {end:#x}, "
                            f"{b['name']} starts at {b['start']:#x}")
        elif end < b["start"]:
            problems.append(f"gap of {(b['start']-end)*SECTOR/MiB:.1f} MiB between "
                            f"{a['name']} and {b['name']} -- usually a typo")

    by_name = {p["name"]: p for p in parts}
    for name in [p["name"] for p in parts if p["name"].endswith("_a")]:
        stem = name[:-2]
        other = by_name.get(stem + "_b")
        if other is None:
            problems.append(f"{name} has no matching {stem}_b slot")
        elif other["size"] != by_name[name]["size"]:
            problems.append(
                f"A/B slots differ: {name} is {by_name[name]['size']*SECTOR/MiB:.0f} MiB, "
                f"{stem}_b is {other['size']*SECTOR/MiB:.0f} MiB. An update can then "
                f"succeed on one slot and fail on the other.")

    for name in ("boot_a", "boot_b"):
        p = by_name.get(name)
        if p and p["size"] * SECTOR < BOOT_IMAGE_BUDGET:
            problems.append(f"{name} is {p['size']*SECTOR/MiB:.0f} MiB, under the "
                            f"{BOOT_IMAGE_BUDGET/MiB:.0f} MiB boot-image budget")

    grow = [p for p in parts if p["grow"]]
    if not grow:
        problems.append("no growable partition; userdata cannot use the rest of the device")
    else:
        consumed = grow[0]["start"] * SECTOR
        # A nominal N GB eMMC presents roughly N * 10^9 * 0.92 usable bytes.
        usable = emmc_gb * 10**9 * 0.92
        remain = usable - consumed
        if remain < 2 * GiB:
            problems.append(
                f"table consumes {consumed/GiB:.2f} GiB; a {emmc_gb} GB eMMC leaves "
                f"only {remain/GiB:.2f} GiB for userdata. Container images and "
                f"store-and-forward buffers live there.")
    return problems


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("table")
    ap.add_argument("--emmc-gb", type=int, default=16,
                    help="smallest eMMC the board ships with (default 16)")
    a = ap.parse_args()
    parts = parse(a.table)
    problems = check(parts, a.emmc_gb)
    for p in parts:
        size = "grow" if p["size"] is None else f"{p['size']*SECTOR/MiB:>8.0f} MiB"
        print(f"  {p['name']:<10} {size:>12}  @ {p['start']:#010x}")
    if problems:
        print(f"\npartition check FAILED for {a.table}:", file=sys.stderr)
        for p in problems:
            print(f"  - {p}", file=sys.stderr)
        sys.exit(1)
    print(f"\npartition check: clean ({a.table}, {a.emmc_gb} GB eMMC)")


if __name__ == "__main__":
    main()
