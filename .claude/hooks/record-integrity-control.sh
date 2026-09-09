#!/usr/bin/env bash
# Control for record-integrity.py, per the SDLC playbook (v0.4).
#
# One mutation per rule. A single planted defect tripping two rules lets the
# control pass with one rule dead -- the failure the gate exists to prevent, one
# level up. Every mutation's content hash is compared against its pre-mutation
# hash and the comparison is printed: a mutation that failed to apply is
# indistinguishable from a control that worked.
set -uo pipefail
cd "$(dirname "$0")/../.."
HOOK=.claude/hooks/record-integrity.py
V=docs/records/_control.md
EVENT='{"tool_name":"Bash","tool_input":{"command":"git commit -m x"}}'
fail=0

cleanup(){ git rm -q --cached "$V" 2>/dev/null || true; rm -f "$V"; }
trap cleanup EXIT

hdr() { printf '# control\n\n## Checks\n| ID | Command | Class | Where | Binding | Inputs | Applicability | State | Notes |\n|---|---|---|---|---|---|---|---|---|\n'; }

# stage $1 as the record; sets global RC to the hook's exit code.
# Diagnostics print directly rather than being returned, so they cannot be
# captured into the exit code by a caller using command substitution.
RC=
run_with() {
  cleanup
  local pre; pre=$(printf '' | git hash-object --stdin)
  printf '%s' "$1" > "$V"; git add "$V"
  local post; post=$(git hash-object "$V")
  echo "    pre-mutation (absent):   $pre"
  echo "    post-mutation (staged):  $post"
  if [ "$pre" = "$post" ]; then
    echo "    MUTATION DID NOT APPLY -- result below is meaningless"; fail=1
  else
    echo "    hashes differ: the mutation applied"
  fi
  printf '%s' "$EVENT" | python3 "$HOOK" 2>/tmp/ctl.err
  RC=$?
}

expect() { # name expected_rc want_msg content
  local name="$1" want_rc="$2" want_msg="$3" body="$4"
  echo "== $name: expect exit $want_rc =="
  run_with "$body"; local got=$RC
  if [ "$got" != "$want_rc" ]; then
    echo "    FAIL (expected $want_rc, got $got)"; sed 's/^/      | /' /tmp/ctl.err; fail=1; return
  fi
  if [ -n "$want_msg" ] && ! grep -qF "$want_msg" /tmp/ctl.err; then
    echo "    FAIL (exit $got, but this rule stayed silent -- another rule caught it)"
    sed 's/^/      | /' /tmp/ctl.err; fail=1; return
  fi
  echo "    PASS (exit $got${want_msg:+, reported by the intended rule})"
}

CLEAN="$(hdr)| C1 | ran it | executed local | here | sha | tool 1.0 | applicable | PASS | expected x, got x |
Verdict: VERIFIED
"
expect "clean record must PASS"          0 "" "$CLEAN"
expect "rule A: invented state blocked"  2 "is not a check state" \
  "$(hdr)| C1 | ran it | executed local | here | sha | tool 1.0 | applicable | PARTIAL | half |
Verdict: not VERIFIED
"
expect "rule B: missing applicability"   2 "no applicability" \
  "$(hdr)| C1 | ran it | executed local | here | sha | tool 1.0 |  | PASS | fine |
Verdict: not VERIFIED
"
expect "rule C: VERIFIED over NOT_RUN"   2 "verdict claims VERIFIED" \
  "$(hdr)| C1 | ran it | executed local | here | sha | tool 1.0 | applicable | NOT_RUN | no runner |
Verdict: VERIFIED
"
echo "== no record staged must PASS =="
cleanup
printf '%s' "$EVENT" | python3 "$HOOK" 2>/dev/null; rc=$?
[ $rc -eq 0 ] && echo "    PASS (exit 0)" || { echo "    FAIL (expected 0, got $rc)"; fail=1; }

echo
[ $fail -eq 0 ] && echo "CONTROL: all cases PASS" || echo "CONTROL: FAILED"
exit $fail
