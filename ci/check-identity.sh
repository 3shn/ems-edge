#!/usr/bin/env bash
# Every commit in this repository must be authored under the personal open-source
# identity. This is a personal, post-exit project; a commit carrying an employer
# identity misattributes authorship in a public, Apache-2.0 tree, and git history
# is the one place a mistake like that cannot be quietly edited later.
#
# Checks author AND committer on every reachable commit, not just HEAD.
set -uo pipefail
cd "$(dirname "$0")/.."

ALLOWED='^(88603768\+3shn@users\.noreply\.github\.com|noreply@anthropic\.com)$'
range="${1:---all}"
rc=0

while IFS='|' read -r ae ce sha; do
  for e in "$ae" "$ce"; do
    if ! printf '%s' "$e" | grep -qE "$ALLOWED"; then
      echo "identity: $sha carries a non-allowlisted address: $e"
      rc=1
    fi
  done
done < <(git log "$range" --format='%ae|%ce|%h')

if [ $rc -eq 0 ]; then
  echo "identity: clean ($(git rev-list --count "$range") commits checked)"
else
  echo
  echo "Author identity is enforced here because this is a public personal project."
  echo "Fix with: git commit --amend --author='3shn <88603768+3shn@users.noreply.github.com>'"
  echo "or git rebase to correct earlier commits before pushing."
fi
exit $rc
