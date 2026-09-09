#!/usr/bin/env bash
# Control for check-identity.sh. The negative case is built by writing a commit
# with a disallowed author into a scratch repository, because mutating this
# repository's history to test a check is not worth the risk.
set -uo pipefail
cd "$(dirname "$0")/.."
CHECK="$(pwd)/ci/check-identity.sh"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
fail=0

echo "== direction 1: this repository must PASS =="
if "$CHECK" >/dev/null 2>&1; then echo "    PASS (exit 0)"
else echo "    FAIL"; "$CHECK" | sed 's/^/      | /'; fail=1; fi

echo "== direction 2: a disallowed author must be CAUGHT =="
git init -q "$TMP/scratch"; cd "$TMP/scratch"
# --no-verify throughout: the operator's global pre-commit hook already refuses
# non-allowlisted addresses, and on the first run of this control it silently
# prevented the mutation from applying -- the control then reported a clean
# scratch repo as a passing check. Local hook and CI check are two layers, and
# the control has to reach past the first to exercise the second.
mkdir -p ci && cp "$CHECK" ci/check-identity.sh
git -c user.name=ok -c user.email=88603768+3shn@users.noreply.github.com \
    commit -q --no-verify --allow-empty -m good
PRE=$(git rev-parse HEAD)
git -c user.name='Someone Else' -c user.email='someone@example.invalid' \
    commit -q --no-verify --allow-empty -m bad
POST=$(git rev-parse HEAD)
echo "    pre-mutation HEAD:  $PRE"
echo "    post-mutation HEAD: $POST"
if [ "$PRE" = "$POST" ]; then echo "    MUTATION DID NOT APPLY"; fail=1
else echo "    hashes differ: the mutation applied"; fi
out=$(./ci/check-identity.sh 2>&1); got=$?
if [ $got -ne 0 ] && printf '%s' "$out" | grep -qF 'someone@example.invalid'; then
  echo "    PASS (exit $got, and it named the offending address)"
else
  echo "    FAIL (exit $got)"; printf '%s\n' "$out" | sed 's/^/      | /'; fail=1
fi

echo
[ $fail -eq 0 ] && echo "CONTROL: all cases PASS" || echo "CONTROL: FAILED"
exit $fail
