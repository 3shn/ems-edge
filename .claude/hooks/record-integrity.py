#!/usr/bin/env python3
"""PreToolUse gate: a staged work record must not claim more than its rows support.

Scope, deliberately narrow. This checks *internal consistency* of a record --
that its states are real states, its applicability is a real applicability, and
that a VERIFIED verdict is supported by every applicable row. It cannot know
whether a command was actually run; only the author can. That limit is stated in
the skill too, because a gate described as more than it is becomes the false
claim it was built to prevent.

Blocks (exit 2) only when a record file is staged in the commit. A commit with
no record passes -- so the gate can both fail and pass, which is the point.
"""
import json, re, subprocess, sys

STATES = {"PASS", "FAIL", "NOT_RUN", "STALE", "INCONCLUSIVE"}
RECORD_DIR = "docs/records/"
TEMPLATE = "docs/records/TEMPLATE.md"


def staged_records():
    try:
        out = subprocess.run(["git", "diff", "--cached", "--name-only", "--diff-filter=ACM"],
                             capture_output=True, text=True, timeout=10).stdout
    except Exception:
        return []
    return [p for p in out.split("\n")
            if p.startswith(RECORD_DIR) and p.endswith(".md") and p != TEMPLATE]


def staged_content(path):
    r = subprocess.run(["git", "show", f":{path}"], capture_output=True, text=True, timeout=10)
    return r.stdout if r.returncode == 0 else ""


def check_rows(text):
    """Yield (state, applicability, rownum) for CHECK-table rows.

    A check row is a pipe table row carrying exactly one recognised state token
    in some cell. Header and separator rows carry none and are skipped, so the
    parser does not depend on column position -- records drift, and a gate that
    breaks when a column moves is a gate that silently stops running.
    """
    for i, line in enumerate(text.split("\n"), 1):
        s = line.strip()
        if not (s.startswith("|") and s.endswith("|")):
            continue
        cells = [c.strip() for c in s.strip("|").split("|")]
        if len(cells) < 3 or set(s) <= set("|- :"):
            continue
        found = [c for c in cells if c.strip("*` ") in STATES]
        if len(found) != 1:
            continue
        state = found[0].strip("*` ")
        appl = next((c for c in cells
                     if re.match(r"^(applicable|excluded-by-policy|not-applicable)\b", c.strip("*` "), re.I)), None)
        yield state, (appl.strip("*` ") if appl else None), i, cells


def invented_states(text):
    """Cells that look like a verdict but are not one of the five states."""
    bad = []
    for i, line in enumerate(text.split("\n"), 1):
        s = line.strip()
        if not (s.startswith("|") and s.endswith("|")) or set(s) <= set("|- :"):
            continue
        for c in [c.strip("*` ") for c in s.strip("|").split("|")]:
            u = c.upper().replace(" ", "_")
            if u in STATES or not c:
                continue
            if u in {"PARTIAL", "PARTIALLY", "OK", "PASSED", "FAILED", "SKIP", "SKIPPED",
                     "N/A", "NA", "TODO", "PENDING", "UNKNOWN", "GREEN", "RED", "YES", "NO",
                     "SUCCESS", "MOSTLY", "DONE", "WIP"} or c in {"✓", "✔", "✗", "✘", "?", "-"}:
                bad.append((i, c))
    return bad


def audit(path, text):
    problems = []
    rows = list(check_rows(text))

    for line, cell in invented_states(text):
        problems.append(f"{path}:{line}: '{cell}' is not a check state. "
                        f"Use one of PASS, FAIL, NOT_RUN, STALE, INCONCLUSIVE -- "
                        f"a state outside that set is a way of not answering.")

    for state, appl, line, cells in rows:
        if appl is None:
            problems.append(f"{path}:{line}: check row has state {state} but no applicability. "
                            f"Record applicable / excluded-by-policy (<policy>) / not-applicable (<scope>) "
                            f"separately from the state.")

    m = re.search(r"^\s*(?:\*\*)?Verdict(?:\*\*)?\s*:\s*(.+)$", text, re.M | re.I)
    if m:
        verdict = m.group(1)
        claims_verified = re.search(r"\bVERIFIED\b", verdict) and not re.search(
            r"\b(not|isn'?t|never|blocked|cannot be|no)\b[^.]{0,40}\bVERIFIED\b", verdict, re.I)
        if claims_verified:
            blockers = [(s, l) for s, a, l, _ in rows
                        if a and a.lower().startswith("applicable") and s != "PASS"]
            if blockers:
                detail = ", ".join(f"line {l} is {s}" for s, l in blockers)
                problems.append(
                    f"{path}: verdict claims VERIFIED, but applicable checks are not all PASS ({detail}). "
                    f"List the blocking states individually instead; the operator may accept residual "
                    f"risk as an exception disposition, which is not a verified verdict.")
            if not rows:
                problems.append(f"{path}: verdict claims VERIFIED with no check rows at all. "
                                f"An empty mandatory list establishes no coverage.")
    return problems


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)
    cmd = (data.get("tool_input") or {}).get("command", "")
    if "git" not in cmd or "commit" not in cmd:
        sys.exit(0)
    if re.search(r"--no-verify|--amend\s+--no-edit", cmd):
        sys.exit(0)

    problems = []
    for path in staged_records():
        problems += audit(path, staged_content(path))
    if problems:
        print("SDLC record integrity -- commit refused:\n\n" + "\n\n".join(f"  - {p}" for p in problems)
              + "\n\nFix the record, or state honestly what was not run. "
                "Deliberate override: git commit --no-verify", file=sys.stderr)
        sys.exit(2)
    sys.exit(0)


if __name__ == "__main__":
    main()
