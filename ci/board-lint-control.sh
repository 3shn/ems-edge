#!/usr/bin/env bash
# Control for board-lint.sh, both directions, per the SDLC playbook.
#
# A check whose failure mode is silence must be exercised in the direction it
# must FAIL as well as the direction it must PASS. A mutation that failed to
# apply is indistinguishable from a control that succeeded, so the mutation's
# content hash is compared against the pre-mutation hash and the comparison is
# printed, not merely recorded.
set -uo pipefail
cd "$(dirname "$0")/.."
VICTIM=os/board-lint-control.probe
fail=0

echo "== direction 1: clean tree must PASS =="
rm -f "$VICTIM"
if ./ci/board-lint.sh >/dev/null 2>&1; then echo "  PASS (expected exit 0, got 0)"
else echo "  FAIL (expected exit 0, got $?)"; fail=1; fi

echo "== mutation: plant a board literal in the core =="
PRE=$(git hash-object "$VICTIM" 2>/dev/null || printf '' | git hash-object --stdin)
printf 'probe: /dev/ttyS3 on rk3576\n' > "$VICTIM"
git add -N "$VICTIM"
POST=$(git hash-object "$VICTIM")
echo "  pre-mutation  (absent): $PRE"
echo "  post-mutation (planted): $POST"
if [ "$PRE" = "$POST" ]; then
  echo "  MUTATION DID NOT APPLY -- the result below would be meaningless"; fail=1
else
  echo "  hashes differ: the mutation applied"
fi

echo "== direction 2: planted literal must be CAUGHT =="
./ci/board-lint.sh >/dev/null 2>&1; got=$?
if [ $got -ne 0 ]; then echo "  PASS (expected non-zero, got $got)"
else echo "  FAIL (expected non-zero, got 0)"; fail=1; fi

git rm -q --cached "$VICTIM" 2>/dev/null || true
rm -f "$VICTIM"
echo "== cleanup: victim removed =="
[ $fail -eq 0 ] && echo "CONTROL: both directions PASS" || echo "CONTROL: FAILED"
exit $fail
