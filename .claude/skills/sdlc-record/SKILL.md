---
name: sdlc-record
description: >
  Run a unit of work under the AI-native SDLC (playbook v0.4) and keep its work
  record honest — change class, checkable requirements, evidence classes, check
  states, bindings, and a verdict that cannot be inflated. Use this skill for ANY
  non-trivial change in this repository: writing or updating a work record under
  docs/records/, filling a CHECK table, deciding whether something is PASS vs
  NOT_RUN vs INCONCLUSIVE, deciding whether a claim is VERIFIED, running a spike,
  building or validating a CI gate, or reporting what you did and how you know.
  Also use it whenever you are about to say a check "passed", call an integration
  healthy, claim something is verified or complete, or write a summary containing
  a number or a status — those claims are exactly what this procedure governs.
  A commit that stages a record under docs/records/ is validated by a hook, so
  reach for this skill before writing the record, not after the commit is refused.
---

# SDLC work record

This is a self-contained execution snapshot of the AI-native SDLC playbook,
**v0.4**. It carries the procedure a fresh executor needs and nothing else — not
the reasoning behind the procedure, and not the history of how it got here. Those
live in the playbook, which owns them. Cite this version in trial feedback so a
result can be attributed to the procedure that produced it.

The point of all of this is narrow and worth stating plainly: **make it hard to
report work as more finished than it is.** Every rule below exists because some
specific claim turned out to be hollow. If a rule ever seems like ceremony, the
question to ask is "what false claim does this prevent" — not "can I skip it".

## Change class

Named at admission. May be raised mid-flight, never lowered silently. It is not
a confidentiality tier.

- **Routine** — one record entry, the diff, its evidence.
- **Substantive** — plus a plan written before code: files, order, risks, proof.
- **Consequential** — the operator reads the plan first. A decision that outlives
  the change becomes an ADR in the repo that owns the topic.
- **Spike** — a question with a stop condition and a bound, written first. **A
  negative answer closes a spike successfully.** No code is owed. A refuted
  engineering requirement is not "verified" — it is refuted, and saying so is the
  deliverable.

If a task contains several of these, admit them separately. Bundling a spike, a
consequential decision and some routine edits into one item is how a consequential
decision gets made without anyone reading it.

## Stages

Admit → Frame → Design → Build → Verify → Review → Release → Operate → Learn.

Each produces an artifact: a record header, checkable requirements, a plan, a
diff, a CHECK table, findings, the artifact plus remaining gates, expected
behaviour and its rollback, and a close line. A finding in Operate or Learn
re-enters at Admit.

Requirements are only useful if they can be wrong: **give every requirement a
falsifier and a source.** A requirement no observation could refute is a wish.

## Evidence — three classes, always labelled

- **static inspection** — reading code, YAML, config, a datasheet; a linter's
  opinion; reading a remote setting through an already-authenticated tool.
- **executed local check** — a command run here that could have failed.
- **hosted execution** — the platform actually ran it.

Reasoning over a file is static inspection and is never called simulation or a
run. Reading a vendor's documentation tells you what the vendor *documents*;
extracting the fact from the shipped artifact tells you what the vendor *shipped*.
When those can differ, prefer the artifact and say which you used.

## Check states — one per check

`PASS` · `FAIL` · `NOT_RUN` · `STALE` · `INCONCLUSIVE`

- `NOT_RUN` = did not execute, for any reason — missing runner, variable,
  credential, tool, hardware, or you simply did not get to it.
- `INCONCLUSIVE` = executed and produced no discriminating result. An unexecuted
  control is `NOT_RUN`, never `INCONCLUSIVE`.
- `cancelled` is `NOT_RUN`, never a failure — it says nothing about the code.

There are exactly five states. Do not invent a sixth ("partial", "mostly", "ok",
a checkmark). The hook rejects them, but the reason to avoid them is that a state
outside this set is always a way of not answering the question.

**A check's state describes the check, not the build.** A control whose property
is *this must be rejected* records `PASS` when the run goes red. Say so explicitly
next to it, because a reader seeing `PASS` beside a red build assumes one of them
is wrong.

## Applicability — recorded separately from state

- `applicable`
- `excluded-by-policy (<the policy>)` — e.g. fork PRs not running privileged
  jobs. Neither a pass nor a gap; never counted toward a verified verdict. Only
  use this when a policy is genuinely doing the excluding.
- `not-applicable (<the scope>)` — never in scope for this event or artifact.
  Counts toward nothing in either direction.

## Binding — how a check stays true

Each check records: the command; its class; where it ran; a clean snapshot commit,
or the base commit plus a retained diff and content hashes of the relevant
changed/untracked files; inputs with versions or hashes; tool versions. Anything
unknown is written as a stated limit, not omitted.

Invalidate conservatively. A `PASS` becomes `STALE` when its implementation,
requirement, verifier, environment, or inputs change. Editing a record or a log
does not invalidate a code check. Where the dependency is uncertain, mark the
plausibly affected set `STALE` rather than everything.

## Verdict

Name the claim and its scope before giving a verdict — local guard behaviour is
not hosted test execution, and an all-excluded test set establishes no execution
coverage.

`VERIFIED` requires every applicable mandatory check `PASS`, the mandatory list
complete, and every binding current. Any `FAIL`, `NOT_RUN`, `STALE` or
`INCONCLUSIVE` in that set blocks it. **List the blocking states individually
rather than collapsing them into a single word** — which one is blocking is the
information the reader needs.

The operator may accept residual risk. That is an **exception disposition**,
recorded with the risk named. It does not convert the verdict to verified.

Bounded local work can be complete and *ready for hosted validation* with hosted
checks honestly `NOT_RUN`, provided the remaining gate is named. That is not a
waiver. Local completion still requires every mandatory **local** check to pass;
a patch with unexecuted local acceptance cases is prepared, not verified.

## Controls on the verifier

When a check's `PASS` is the reason a claim is believed, and its failure mode is
silence, exercise **both directions**: a case it must fail and a case it must
pass, both executed. If either was not executed, it is `NOT_RUN` and the claim
stays unsupported.

Record both expected and actual outcomes **in the row of the check the control
defends**, with the mutation's own binding — the content hash of the deliberate
break. **Compare that hash against the pre-mutation hash and say you did.** A
mutation that silently failed to apply is indistinguishable from a control that
succeeded; the two hashes are the only thing that tells them apart.

One mutation per property. If a single planted defect trips two rules at once,
the control still passes with one rule dead — which is the failure the check
itself exists to prevent, one level up.

A local test of decision logic must exercise the real artifact, not a hand-built
model that can pass while the real one stays broken.

## Claims hygiene

No number, threshold, or status appears in a summary unless it appears in output
actually produced — quote the line. Numbers are either sourced or declared chosen
policy. Human time may be estimated and must be labelled estimate. Attribute each
observation to whoever made it. A delegate's report is input, never a verdict;
re-derive its figures from the machine-readable artifact, not its prose.

## Review

A finding counts when it cites the tree, an output, or a source. An assertion
without one is a prompt to go look, not a verdict, and disagreements are resolved
on evidence rather than by counting agreeing opinions.

Name whether a review was self-review or independent. For substantive work, give
at least one reviewer an explicitly **adversarial** job: *under what conditions
does this report a passing state when the property does not hold?* Any brief that
checks a claim ends by asking what in the material contradicts the drafted
conclusion, with a quote.

## Stop and recovery

**Stop when the mechanism is known and unaddressed.** A second attempt against a
cause you have not changed is not a retry — it is the same attempt. An attempt
that changes an input in order to identify an *unknown* cause is a diagnostic,
and diagnostics do not count toward a stop. Three failures can look identical and
share nothing, which is why this keys on the mechanism and not the appearance.

Report the mechanism if known; if unknown, say unknown, give the observations,
and name the next diagnostic action. Do not invent a mechanism to fill a field.

On quota exhaustion or an unavailable dependency, park with: branch and SHA, what
was running, the state of each check, and the next single action.

## Enforced versus asked

**Enforced** here: git history, the hooks in `.claude/hooks/`, CI workflow
conditions, and branch protection *where it has actually been inspected*.

**Asked**: everything else in this file. Prompted behaviour, not a gate — and it
must never be described as one. Saying "the record is validated" when only a
person read it is the same class of error as calling an unrun check a pass.

## Writing the record

Copy `docs/records/TEMPLATE.md`. Keep routine work to five lines: task; branch
and commit; the checks with state, class, applicability and bound evidence; the
remaining gate if any; one line of what was learned.

The CHECK table is what the hook validates on commit. It reads the `State` and
`Applicability` columns and the `Verdict:` line, and it refuses a record whose
verdict claims more than its rows support. It cannot check whether you actually
ran anything — only you can, so never write a state you did not observe.
