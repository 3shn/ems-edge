# Contributing

## Sign-off (DCO)

Commits need a `Signed-off-by` line — `git commit -s`. It certifies you wrote
the change or have the right to submit it under the file's licence
(developercertificate.org). No CLA.

## Licence of your contribution

Match the directory. Apache-2.0 in the core, EPL-2.0 under
`apps/openems/bundles/**` so it can go upstream, GPL-2.0 for kernel and U-Boot
patches. `NOTICE` has the map. If you are unsure, ask in the issue first —
relicensing later is painful.

## The one rule that is not style

**A claim that something works needs the command and its output.** "Tested on
hardware" is not evidence; the probe run and its result JSON are. If you did not
run something, say so — `NOT_RUN` is a perfectly good answer and is much more
useful than a guess. This applies to bug reports too: what you observed beats
what you concluded.

If a check's failure mode is silence — a lint, a guard, a gate — it needs a
control in **both** directions before anyone believes it: a case it must fail
and a case it must pass, both executed, and one mutation per rule. A single
planted defect tripping two rules lets the control pass with one rule dead.
`ci/board-lint-control.sh` is the worked example.

## Hardware facts

Never from vendor prose. Read the device tree on the booted unit or extract from
the shipped artefact, and record the evidence in the profile as a comment.
Vendor documentation says what the vendor documents; the artefact says what the
vendor shipped, and on this hardware they have already disagreed.

Do not commit vendor documentation, schematics, or proprietary loader binaries.
Facts derived from them are fine with attribution; the documents are not ours to
redistribute.

## Board profiles

A new board is a new `boards/<id>/` plus a BSP pin plus a CI matrix entry, and
**zero diffs elsewhere**. If you find yourself editing the core to add a board,
that is a schema bug — please report it rather than working around it. That
property is the whole point of the repository and it is currently unproven,
since one profile cannot falsify it.
