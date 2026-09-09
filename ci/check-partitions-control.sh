#!/usr/bin/env bash
# Control for check-partitions.py. One case per property, each checked against
# that property's own message so a dead rule cannot hide behind a live one.
#
# The first negative case is not synthetic: it is the vendor's own A/B layout,
# whose boot slots are 64 MiB and 128 MiB. Building the control around a defect
# that shipped is better than inventing one, because it proves the check would
# have caught the thing we actually had to fix.
set -uo pipefail
cd "$(dirname "$0")/.."
CHECK=ci/check-partitions.py
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
fail=0

table() { printf 'CMDLINE: mtdparts=:%s\n' "$1"; }

expect() { # name expect_rc want_msg cmdline [extra args]
  local name="$1" want="$2" msg="$3" cmd="$4"; shift 4
  echo "== $name: expect exit $want =="
  table "$cmd" > "$TMP/p.txt"
  local pre post
  pre=$(printf '' | git hash-object --stdin); post=$(git hash-object "$TMP/p.txt")
  echo "    pre-mutation (empty): $pre"
  echo "    fixture:              $post"
  [ "$pre" = "$post" ] && { echo "    FIXTURE EMPTY -- result meaningless"; fail=1; return; }
  local out; out=$(./"$CHECK" "$TMP/p.txt" "$@" 2>&1); local got=$?
  if [ "$got" != "$want" ]; then
    echo "    FAIL (got $got)"; printf '%s\n' "$out" | sed 's/^/      | /'; fail=1; return
  fi
  if [ -n "$msg" ] && ! printf '%s' "$out" | grep -qF "$msg"; then
    echo "    FAIL (exit $got but the intended rule stayed silent)"
    printf '%s\n' "$out" | sed 's/^/      | /'; fail=1; return
  fi
  echo "    PASS (exit $got${msg:+, reported by the intended rule})"
}

GOOD='0x00002000@0x00004000(uboot),0x00002000@0x00006000(misc),0x00040000@0x00008000(boot_a),0x00040000@0x00048000(boot_b),0x00010000@0x00088000(backup),0x00800000@0x00098000(system_a),0x00800000@0x00898000(system_b),0x00040000@0x01098000(oem),-@0x010d8000(userdata:grow)'

expect "our table passes" 0 "" "$GOOD"

# The vendor's shipped A/B layout: asymmetric boot slots, 7 GiB system slots.
VENDOR='0x00002000@0x00004000(uboot),0x00002000@0x00006000(misc),0x00020000@0x00008000(boot_a),0x00040000@0x00028000(boot_b),0x00010000@0x00068000(backup),0x00e00000@0x00078000(system_a),0x00e00000@0x00e78000(system_b),0x00040000@0x01c78000(oem),-@0x01cb8000(userdata:grow)'
expect "vendor A/B asymmetry is caught" 1 "A/B slots differ" "$VENDOR"
expect "vendor layout overflows 16 GB eMMC" 1 "leaves" "$VENDOR"

# Overlap: system_a extended so it runs into system_b.
OVERLAP=${GOOD/0x00800000@0x00098000(system_a)/0x00900000@0x00098000(system_a)}
expect "overlap is caught" 1 "overlaps" "$OVERLAP"

# Gap: push oem forward, leaving unallocated space.
GAP=${GOOD/0x00040000@0x01098000(oem)/0x00040000@0x01198000(oem)}
expect "gap is caught" 1 "gap of" "$GAP"

# Undersized boot slot, both sides symmetric so only the budget rule fires.
SMALL=${GOOD//0x00040000@0x00008000(boot_a)/0x00008000@0x00008000(boot_a)}
SMALL=${SMALL//0x00040000@0x00048000(boot_b)/0x00008000@0x00010000(boot_b)}
echo "== boot budget: expect exit 1 =="
table "$SMALL" > "$TMP/p.txt"
out=$(./"$CHECK" "$TMP/p.txt" 2>&1); got=$?
if [ $got -eq 1 ] && printf '%s' "$out" | grep -qF 'boot-image budget'; then
  echo "    PASS (exit $got, reported by the budget rule)"
else
  echo "    FAIL (exit $got)"; printf '%s\n' "$out" | sed 's/^/      | /'; fail=1
fi

echo
[ $fail -eq 0 ] && echo "CONTROL: all cases PASS" || echo "CONTROL: FAILED"
exit $fail
