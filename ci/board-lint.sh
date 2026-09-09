#!/usr/bin/env bash
# HAL guard: the core workflow must not know which board it is building for.
#
# Structural rule first. A denylist of literals cannot fail on the NEXT board's
# literals, which is the failure mode this hook exists to prevent; the literal
# list is a backstop, not the mechanism.
#
# Exit 0 clean, 1 on any violation. Control: ci/board-lint-control.sh
set -uo pipefail
cd "$(dirname "$0")/.."

EX=(':(exclude)boards' ':(exclude)ci/board-lint.sh'
    ':(exclude)ci/board-lint-control.sh' ':(exclude)docs')
rc=0
report() { printf '%s\n' "$1"; printf '%s\n' "$2"; rc=1; }

# 1. Structural: no core file may name a concrete board directory.
if out=$(git grep -n -E 'boards/[a-z0-9][a-z0-9._-]+/' -- . "${EX[@]}"); then
  report "board-lint: core code references a concrete board directory:" "$out"
fi

# 2. Structural: no core file may name a concrete device node.
if out=$(git grep -n -E '/dev/(tty(S|USB|WCH)[0-9]|mmcblk[0-9]|i2c-[0-9]|watchdog[0-9])' -- . "${EX[@]}"); then
  report "board-lint: core code names a concrete device node (belongs in io.yaml):" "$out"
fi

# 3. Backstop denylist of literals we already know about.
if out=$(git grep -n -i -E 'rk3576|rk3588|epc-tl3576|sbc-tl3576|rkdeveloptool|ch9434|maskrom' -- . "${EX[@]}"); then
  report "board-lint: core code contains a board/SoC literal:" "$out"
fi

[ $rc -eq 0 ] && echo "board-lint: clean"
exit $rc
