# Publication readiness

Repo:          3shn/ems-edge
Posture:       build-in-the-open, decided 2026-09-09
Current state: **public since 2026-09-09.** The blockers below were closed
               first; what remains open is listed as open.

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

## Blockers — closed 2026-09-09, before the repo went public

| Item | State | Evidence |
|---|---|---|
| **Fork-PR privilege exclusion** | PASS | Workflow uses `pull_request`, never `pull_request_target`, so fork code runs with a read-only token and no secrets. No self-hosted runners. Default workflow token set to `read`; `can_approve_pull_request_reviews=false`. Fork-PR approval policy raised from `first_time_contributors` to **`all_external_contributors`** — every fork PR needs a human before any workflow runs. `actions/checkout` pinned to commit `fbc6f39` (v5.1.0), not a tag. |
| **The gate can actually fail** | PASS | Both directions executed. Positive: run `34337181851`, three mandatory jobs `success`, gate `success`. Negative: run `34337282653`, a planted board literal made `board-lint` and `board-lint control` fail and the gate reported `failure`. Mutation binding: pre `e69de29bb2d1d6434b8b29ae775ad8c2e48c5391` → post `7f050200caceaa8643e918eb43b32c94766d08da`, hashes compared and differing. Control branch and PR #1 closed and deleted. |
| **Secret scanning + push protection** | PASS | Both `enabled` via the API and read back. Note the pre-commit `gitleaks` hook is local and advisory — it gates nothing a contributor does; these do. |
| **Branch protection on `main`** | PASS | `gate` required and `strict`; force pushes and deletions blocked; conversation resolution required. `enforce_admins` is **false** deliberately, so the maintainer can still push directly on a solo project — that is a stated weakening, not an oversight. |

## Still open

| Item | State | What would settle it |
|---|---|---|
| **GPL corresponding-source mechanism** | PARTLY | Release `bsp-v2.1` (2026-09-10) publishes the vendor kernel and U-Boot source, which discharges §3(a) for the vendor tree. Still missing: a per-release bundle pinned to what each shipped image actually contains, including our own patches. |
| **Employer-IP boundary** | NOT_RUN | The project began in a commercial EMS context and is now designated a post-exit personal asset. Raised before the transfer and reaffirmed by the operator; proceeding on that decision. No technical check can close this one, and publication does not settle it. |
| **"Zero diffs outside `boards/**`" is unproven** | NOT_RUN | One profile cannot falsify the claim the repository exists to make. A second profile with a genuinely different flash path (Sige5: mainline U-Boot, no maskrom) would. Until then the README describes it as the design intention, which is what it is. |

## Defects found while doing this, kept because they are the useful part

1. **`NOTICE` tripped the board-lint denylist.** It names `rk3576_spl_loader` and
   `rk3576_idblock`, which a licence file must do. The rule targets code that
   would have to change for a new board; prose does not. Prose is now exempt,
   consistent with `docs/` already being exempt.
2. **The guard could not see untracked files.** `git grep` searches tracked
   files by default, so a newly written, unstaged file carrying a board literal
   passed. The control did not catch it because every case staged its victim
   with `git add -N` — a path real usage does not take. Fixed with
   `--untracked`, plus a regression case that plants an unstaged victim.
   A control that only exercises paths the code already handles is the failure
   mode the control exists to prevent, one level up.

## Deliberately not blocking

- **Kernel `.config` and device-tree facts are publishable.** The kernel and
  U-Boot are GPL-2.0; we are obliged to offer that source, not merely permitted.
  The shipped `.config` was extracted from `boot.img` in seconds via
  `CONFIG_IKCONFIG_PROC` — it was never confidential.
- **The board-profile schema is ours.** It contains no vendor material.
