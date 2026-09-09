#!/usr/bin/env bash
# Control for board-lint.sh, per the SDLC playbook.
#
# Two properties are being defended, and they are different:
#   (a) the hook rejects a coupled tree and accepts a clean one;
#   (b) EACH of the hook's three rules independently does its job.
#
# (b) needs one mutation per rule, each tripping only that rule and checked
# against that rule's own message. A single mutation that trips two rules lets
# the control pass with one rule dead -- which is the failure mode the hook
# itself exists to prevent, one level up.
#
# A mutation that failed to apply is indistinguishable from a control that
# worked, so every mutation's content hash is compared against its pre-mutation
# hash and the comparison is printed, not merely recorded.
set -uo pipefail
cd "$(dirname "$0")/.."
VICTIM=os/board-lint-control.probe
EMPTY=$(printf '' | git hash-object --stdin)
fail=0

cleanup() { git rm -q --cached "$VICTIM" 2>/dev/null || true; rm -f "$VICTIM"; }
trap cleanup EXIT

echo "== direction 1: clean tree must PASS =="
cleanup
if ./ci/board-lint.sh >/dev/null 2>&1; then echo "  PASS (expected exit 0, got 0)"
else echo "  FAIL (expected exit 0, got $?)"; fail=1; fi

# rule id | payload tripping ONLY that rule | expected message fragment
run_case() {
  local id="$1" payload="$2" want="$3"
  echo "== direction 2, rule $id: must be CAUGHT, and by rule $id =="
  cleanup
  local pre; pre=$(git hash-object "$VICTIM" 2>/dev/null || printf '%s' "$EMPTY")
  printf '%s\n' "$payload" > "$VICTIM"; git add -N "$VICTIM"
  local post; post=$(git hash-object "$VICTIM")
  echo "  pre-mutation (absent):   $pre"
  echo "  post-mutation (planted): $post"
  if [ "$pre" = "$post" ]; then
    echo "  MUTATION DID NOT APPLY -- any result below is meaningless"; fail=1; return
  fi
  echo "  hashes differ: the mutation applied"
  local out; out=$(./ci/board-lint.sh 2>&1); local got=$?
  if [ $got -eq 0 ]; then echo "  FAIL (expected non-zero, got 0)"; fail=1; return; fi
  if printf '%s' "$out" | grep -qF "$want"; then
    echo "  PASS (exit $got, and rule $id reported: \"$want\")"
  else
    echo "  FAIL (exit $got, but rule $id stayed silent -- another rule caught it)"
    printf '%s\n' "$out" | sed 's/^/    | /'; fail=1
  fi
}

run_case 1 'see boards/somebrd/io.yaml for the port map' \
           'references a concrete board directory'
run_case 2 'open /dev/ttyUSB0 at 9600 8N1' \
           'names a concrete device node'
run_case 3 'flash with rkdeveloptool db loader.bin' \
           'contains a board/SoC literal'

echo "== cleanup =="
cleanup
[ $fail -eq 0 ] && echo "CONTROL: all cases PASS" || echo "CONTROL: FAILED"
exit $fail
