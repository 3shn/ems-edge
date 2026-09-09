# Publication readiness

Repo:          3shn/ems-edge
Posture:       build-in-the-open, decided 2026-09-09
Current state: **private.** Flipping to public is the operator's action, not a
               consequence of this document.

This uses the project's own check vocabulary deliberately: `PASS`, `FAIL`,
`NOT_RUN`. A row that says `NOT_RUN` means nobody has run it, not that it is
fine.

## Audit performed 2026-09-09

Executed local checks over the tracked tree and reachable history.

| Check | Command | State | Result |
|---|---|---|---|
| Secrets in history | `gitleaks` on each commit (pre-commit hook) | PASS | no leaks found, every commit |
| Absolute local paths | `git grep -E '/home/u/\|\$HOME/'` | PASS | none in tracked files |
| Personal email addresses | `git grep -E '<email pattern>'` excluding noreply | PASS | none |
| Prior-org branding | `git grep -i 'econ-iot'` over all reachable blobs | PASS | none; a `.pyc` embedding the old path was removed and history rewritten (`3b92d22` → `25585c6`, force-pushed) |
| Vendor documents committed | tree inspection | PASS | none. Board facts are recorded with attribution; source PDFs and schematics stay out |
| Proprietary blobs committed | tree inspection | PASS | none. Rockchip loaders are fetched at build time, never committed |
| Licence coverage stated | `LICENSE`, `NOTICE` | PASS | Apache-2.0 core; GPL-2.0 and EPL-2.0 components mapped in `NOTICE` |

## Blocking before public

| Item | State | What would settle it |
|---|---|---|
| **Fork-PR privilege exclusion** | NOT_RUN | There is no CI yet. Public means untrusted contributors can propose workflow runs, so *before* a pipeline exists publicly, every privileged job must be gated on a same-repo condition and fork-excluded jobs reported `excluded-by-policy`, never as verified. This is the single largest new attack surface that going public creates. |
| **Secret-scanning + push protection** | NOT_RUN | Enable both in repository settings once public (free for public repos). The pre-commit `gitleaks` hook is local and advisory; it is not a gate on anyone else's contribution. |
| **Branch protection on `main`** | NOT_RUN | Currently none, and history was force-pushed today, which protection would have blocked. Decide the rule before inviting contributors, not after. |
| **GPL corresponding-source mechanism** | NOT_RUN | We will ship GPL-2.0 kernel and U-Boot binaries. §3(a) accompanying source or §3(b) a written offer valid three years. Neither exists. This is unconditional on shipping, independent of publication, and is currently specified but not built. |
| **Employer-IP boundary** | NOT_RUN | The project originated in a commercial EMS context and is now designated a post-exit personal asset. Whether any of it is employer work product is a question the operator answers, not this repository. Shipped bytes belong to whoever they belong to; a change of posture does not move that line. Recorded here because it is the one item no technical check can close. |

## Deliberately not blocking

- **Kernel `.config` and device-tree facts are publishable.** The kernel and
  U-Boot are GPL-2.0; we are obliged to offer that source, not merely permitted.
  The shipped `.config` was extracted from `boot.img` in seconds via
  `CONFIG_IKCONFIG_PROC` — it was never confidential.
- **The board-profile schema is ours.** It contains no vendor material.
