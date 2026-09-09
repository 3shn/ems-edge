# ems-edge

A reproducible edge platform for commercial energy management — PV, storage,
meters, tariff response — built so that **every unit can be built, signed,
provisioned, updated and audited identically**. Deploying one working box is not
the goal; if the fleet operation does not exist, the product does not exist.

Status: **early.** The board profile schema and the guards around it are real
and tested. Nothing has touched hardware yet. See `docs/` for what is
established and what is still assumed.

## The one idea

The board is not baked into the workflow. Everything the core does — OS build,
flashing, provisioning, tests, CI, fleet ops — is hardware-agnostic, and every
hardware fact lives in exactly one place:

```
boards/<board-id>/
├── board.yaml        identity, SoC, arch, support status
├── parameter.txt     partition table (A/B rootfs from day one)
├── flash.yaml        method, tool, loader artefacts
├── kernel.yaml       source pin, config fragments, boot artefacts
├── io.yaml           rs485[], can[], lan[], di/do, wdt, rtc, quirks[]
└── constraints.yaml  temperature grade, eMMC endurance budget, power input
```

Adding a supplier means adding a profile, not grepping the tree. `ci/board-lint.sh`
enforces it: no file outside `boards/**` may reference a concrete board directory
or a concrete device node. It ships with a control that plants a violation and
checks it is caught — one mutation per rule, hashes compared — because a lint that
has only ever returned clean has not been run in any meaningful sense.

## Layout

| Path | What |
|---|---|
| `boards/` | one directory per board; the only place hardware facts live |
| `os/` | image recipe, parameterised by profile |
| `deploy/` | flashing and provisioning, dispatching on `flash.yaml` |
| `apps/openems/` | upstream OpenEMS Edge, pinned by commit, plus our EPL-2.0 drivers |
| `apps/sidecars/` | dispatch and optimisation logic, outside the Edge image |
| `tests/probe/` | profile-driven hardware tests; a test exists iff the profile declares the interface |
| `ci/` | the guards, each with its control |
| `.claude/` | the SDLC harness — see below |

## Why OpenEMS is split in two

Device drivers go **in-tree** as OSGi bundles under EPL-2.0. OpenEMS's Modbus
bridge, channel model and scheduler integration are the reason to use OpenEMS at
all; reimplementing them outside just to feed results back over MQTT is worse
code for no benefit. These are integration, not commercial value, and are
licensed to match upstream so they can be contributed back.

Dispatch and optimisation logic goes in **sidecar containers**. Not for licence
reasons — EPL-2.0 is weak, file-level copyleft and would not force our bundles
open. The reasons are architectural: a controller change must not require
rebuilding and revalidating Edge, we stay off OpenEMS's release treadmill, our
bugs stay away from the dispatch runtime, and the language stays open.

## Licensing

Apache-2.0 for the core (`LICENSE`). This is a mixed-licence tree on purpose —
GPL-2.0 for kernel and U-Boot work, EPL-2.0 for OpenEMS bundles. `NOTICE` says
which is which and what is deliberately *not* redistributed here.

Shipping a kernel binary obliges us to provide corresponding source to whoever
receives the device. That is a release artefact, not an afterthought.

## How work is done here

`.claude/skills/sdlc-record/` carries a self-contained snapshot of the AI-native
SDLC this project runs on: change classes, three evidence classes, five check
states, applicability recorded separately from state, and a verdict that cannot
be inflated. `.claude/hooks/record-integrity.py` enforces the part that can be
enforced — a staged work record cannot claim `VERIFIED` over a check that is not
`PASS`.

The distinction matters and is kept explicit throughout: the hook is a **gate**,
the skill is **asked**. Prompted behaviour is never described as enforcement.

## Contributing

See `CONTRIBUTING.md`. Short version: sign off your commits (DCO), and a claim
that something works needs the command you ran and its output.
