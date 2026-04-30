---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P03"
milestone: "M028"
name: "Hook reject_lookup Extension"
depends_on: ["T01", "T02"]
---

## Prerequisites

- `scripts/hooks/pre-bash-shape-guard.sh` exists (verified: `[ -f /Users/brettkellgren/Sites/spec-kit-orchestrator/scripts/hooks/pre-bash-shape-guard.sh ]` returns exit 0; current line count 188).
- `ANTIPATTERNS.md` carries entries AP-010..AP-014 (T01 deliverable).
- `scripts/verify/lib/shape-classifier.sh` emits the five new reject classes (T02 deliverable).
- The hook's `reject_lookup` function exists at lines 25..33 with the four existing case arms (`nested-cmd-sub`, `compound-chain-gt2`, `heredoc-with-expansion`, `quoted-brace`) plus the catch-all default arm.

## Description

Extend the `reject_lookup` function in `scripts/hooks/pre-bash-shape-guard.sh` with five new case arms — one per new reject class — each emitting a `<wrapper.sh> <AP-ID>` pair on stdout. The hook's existing dispatch logic (lines 171..180) reads this output and emits the canonical `REJECT: <class> — use scripts/util/<wrapper> instead. See ANTIPATTERNS.md#<AP-ID>.` diagnostic on stderr with exit 2.

The five new arms map each new pattern class to a wrapper basename:

| pattern-class                 | wrapper.sh        | AP-ID  | Note                                                                  |
|-------------------------------|-------------------|--------|------------------------------------------------------------------------|
| `cmd-sub-in-pattern`          | `grep-files.sh`   | AP-010 | P04 deliverable; today the diagnostic surfaces the AP-ID for the operator. |
| `quoted-arg-newline-hash`     | `read-range.sh`   | AP-011 | No wrapper exists; `read-range.sh` is the closest investigation-class wrapper. The actual fix is the operator's command shape (per AP-011 ANTIPATTERNS Remedy section). |
| `multiline-quoted-script`     | `node-eval.sh`    | AP-012 | P04 deliverable; the wrapper takes a script-file path as a positional arg. |
| `unquoted-brace-glob`         | `peek-files.sh`   | AP-013 | P04 deliverable; replaces the brace-glob enumerate-and-peek shape.    |
| `xargs-sh-c-compound-body`    | `peek-files.sh`   | AP-014 | P04 deliverable; replaces the find/head/xargs/sh-c construction.     |

Existing four arms and the catch-all are preserved verbatim (CON-7).

## Steps

1. **Read the existing hook** at `scripts/hooks/pre-bash-shape-guard.sh:25..33` — the current `reject_lookup` body:

```bash
reject_lookup() {
  case "$1" in
    nested-cmd-sub)         printf 'run-probe.sh AP-009\n'   ;;
    compound-chain-gt2)     printf 'run-probe.sh AP-009\n'   ;;
    heredoc-with-expansion) printf 'run-probe.sh AP-008\n'   ;;
    quoted-brace)           printf 'read-range.sh AP-007\n'  ;;
    *)                      printf 'run-probe.sh AP-009\n'   ;;
  esac
}
```

2. **Replace the function body** with the extended version. Insert the five new arms BEFORE the catch-all default (`*)`); preserve the existing four arms verbatim:

```bash
reject_lookup() {
  case "$1" in
    nested-cmd-sub)             printf 'run-probe.sh AP-009\n'   ;;
    compound-chain-gt2)         printf 'run-probe.sh AP-009\n'   ;;
    heredoc-with-expansion)     printf 'run-probe.sh AP-008\n'   ;;
    quoted-brace)               printf 'read-range.sh AP-007\n'  ;;
    cmd-sub-in-pattern)         printf 'grep-files.sh AP-010\n'  ;;
    quoted-arg-newline-hash)    printf 'read-range.sh AP-011\n'  ;;
    multiline-quoted-script)    printf 'node-eval.sh AP-012\n'   ;;
    unquoted-brace-glob)        printf 'peek-files.sh AP-013\n'  ;;
    xargs-sh-c-compound-body)   printf 'peek-files.sh AP-014\n'  ;;
    *)                          printf 'run-probe.sh AP-009\n'   ;;
  esac
}
```

Each arm is a single `printf` statement — no compound chain, no subshell, no pipe. The case statement as a whole is a single `case` block (FR-21 self-conformance preserved; AP-009 classifier scans inline command-line shape, not case-statement bodies).

3. **Pre-validate the new arms via classifier probe** (per CLAUDE.md plan-time classifier-shape pre-validation discipline). Each new line is a single `printf` followed by `;;` — these are case-arm bodies, not standalone command lines. The AP-009 classifier scans inline command-line shape; case-arm bodies are not flagged. P02/T01 codified this exact convention. T05's `finding-G-self-conformance.sh` empirically re-validates against the M028-extended classifier at verification time.

4. **Verify no other line in the hook body changes**. The reject_lookup function lives at lines 25..33 and is a self-contained block — the surrounding hook body (BASH_SOURCE resolution, JSON parsing, classification dispatch, rewrite/reject emission) does not touch reject_lookup output beyond reading its single-line stdout via `LOOKUP="$(reject_lookup "$PATTERN_CLASS")"` on line 173.

5. **Author the per-task verifier** at `scripts/verify/m028/p03-reject-lookup-coverage.sh` (chmod +x). The verifier sources `scripts/hooks/pre-bash-shape-guard.sh` (or extracts the `reject_lookup` body) and asserts each of the five new arms emits the wrapper-basename + AP-ID pair listed in Must-Haves, plus the four existing arms + catch-all default emit unchanged. Per-task deliverable so `auto-loop.sh --step=V` resolves at T03 time (per CLAUDE.md hotfix "Plan-time verifier-availability cross-check missing").

   Reference shape: `scripts/verify/m028/p03-antipatterns-entries.sh` — single-script-file (AD-19), `set -u`, BASH_SOURCE self-location, prefixed `PASS:`/`FAIL:` output. Bash 3.2 + POSIX-sh safe. Use a function wrapper to source the hook (helper-function carve-out per AD-19) if direct sourcing trips classifier shape on this script — see M028/P02/T03 for the source-and-call pattern.

6. **Commit** via `git commit -F <message-file>`. Suggested message:

```
M028/P03/T03: hook reject_lookup — 5 new case arms

cmd-sub-in-pattern      -> grep-files.sh AP-010
quoted-arg-newline-hash -> read-range.sh AP-011 (hint only; no wrapper)
multiline-quoted-script -> node-eval.sh AP-012
unquoted-brace-glob     -> peek-files.sh AP-013
xargs-sh-c-compound-body -> peek-files.sh AP-014

Existing four arms (nested-cmd-sub, compound-chain-gt2,
heredoc-with-expansion, quoted-brace) and the catch-all default
preserved verbatim. CON-7 strict-superset.

The wrapper basenames AP-010/012/013/014 reference are P04
deliverables; today the hook surfaces the AP-ID and the operator's
command shape changes are tracked in ANTIPATTERNS.md.
```

## Must-Haves

This task addresses the phase Truth: "The PreToolUse hook's `reject_lookup` maps every new pattern class ... and every existing M021 pattern class is preserved unchanged."

The per-task verifier `scripts/verify/m028/p03-reject-lookup-coverage.sh` (co-authored with this task — see Steps step 5) asserts:
- Calling `reject_lookup cmd-sub-in-pattern` (after sourcing the hook's helpers) prints `grep-files.sh AP-010\n`.
- Calling `reject_lookup quoted-arg-newline-hash` prints `read-range.sh AP-011\n`.
- Calling `reject_lookup multiline-quoted-script` prints `node-eval.sh AP-012\n`.
- Calling `reject_lookup unquoted-brace-glob` prints `peek-files.sh AP-013\n`.
- Calling `reject_lookup xargs-sh-c-compound-body` prints `peek-files.sh AP-014\n`.
- The four existing arms (`nested-cmd-sub`, `compound-chain-gt2`, `heredoc-with-expansion`, `quoted-brace`) emit unchanged.
- The catch-all default (any unknown pattern class) emits `run-probe.sh AP-009\n` unchanged.

## Verification

```bash
bash scripts/verify/m028/p03-reject-lookup-coverage.sh
```

```bash
bash scripts/verify/m028/p02-hook-self-conformance.sh
```

## Notes

`scripts/verify/check-must-haves.sh .orchestrator/milestones/M028/phases/P03` is a phase-level check; it runs at phase close, not per-task. Per-task `## Verification` invokes only task-scoped verifiers (matches P02 convention).

## Inputs

### From Previous Tasks

- `ANTIPATTERNS.md` (from T01) — references the AP-IDs the hook emits (AP-010..AP-014). The hook diagnostic format `See ANTIPATTERNS.md#AP-NNN` is consumed by the operator following the link to the entry.
- `scripts/verify/lib/shape-classifier.sh` (from T02) — emits the new reject classes whose labels MUST match the hook's case arms byte-for-byte. The pattern-class → wrapper mapping is the contract glue between T02 (classifier emits class) and T03 (hook surfaces wrapper hint).

### Key API Surface (from T02)

- `classify_command "<cmd>"` returns one of `reject:cmd-sub-in-pattern`, `reject:quoted-arg-newline-hash`, `reject:multiline-quoted-script`, `reject:unquoted-brace-glob`, `reject:xargs-sh-c-compound-body` (5 new) plus the existing 4 reject classes plus 6 rewrite classes plus `allow`.
- The hook's existing dispatch (lines 171..180) parses `reject:<class>` via `${CLASS#reject:}`, calls `reject_lookup "<class>"`, awks out the wrapper and AP-ID, and emits the canonical diagnostic on stderr — T03 only adds case arms; the dispatch logic stays.

### From Disk (Pre-existing)

- `scripts/hooks/pre-bash-shape-guard.sh` — the existing PreToolUse hook; T03 modifies only the `reject_lookup` function body.
- `scripts/verify/m028/p02-hook-self-conformance.sh` — T03 re-runs this verifier after the edit to confirm the resolution-block self-conformance (from P02/T01) is unaffected.

## Constraints

- **CON-1 (AD-19)**: T03 modifies a flat single-script file. The five new lines are single-statement `printf` arms.
- **CON-2 (bash 3.2 + POSIX sh)**: Case statement is POSIX. Single-line printf is bash 3.2 + POSIX-sh-safe.
- **CON-3 (shape-guard self-conformance)**: The five new lines are case-arm bodies. The AP-009 classifier scans inline command-line shape, not case-arm bodies (P02/T01 codified the carve-out). T05's `finding-G-self-conformance.sh` empirically re-validates against the M028-extended classifier.
- **CON-7 (no-M021-regression)**: The four existing case arms and the catch-all default are preserved byte-for-byte.
- **Wrapper-basename invariant**: The wrapper basenames (`grep-files.sh`, `read-range.sh`, `node-eval.sh`, `peek-files.sh`) MUST match the P04 wrapper filenames. P04 (M028 phase 4) authors `scripts/util/{grep-files,cleanup-stale-results,node-eval,peek-files}.sh`. T03 cites the basenames per FR-14..FR-17; if P04's authoring drifts (e.g. renames `node-eval.sh` to `node-run.sh`), T03's case arms must be updated in lockstep — but P04 is downstream of P03, so the spec FR contract is the binding agreement.
- **AP-011 wrapper choice rationale**: There is no AP-011 wrapper in P04's deliverable set. The hook's diagnostic format requires SOME wrapper basename per the format string `use scripts/util/<wrapper>`. `read-range.sh` is the closest existing investigation-class wrapper (M021/P03 deliverable, in `scripts/util/`). The AP-011 ANTIPATTERNS.md Remedy section documents that the actual fix is the operator's command shape (single-line quoted args; separate setter calls), not invoking the wrapper. The diagnostic is the AP-ID pointer; the wrapper is the format requirement.

## Expected Output

After running `bash scripts/verify/m028/p03-reject-lookup-coverage.sh`:

```
PASS: reject_lookup cmd-sub-in-pattern -> grep-files.sh AP-010
PASS: reject_lookup quoted-arg-newline-hash -> read-range.sh AP-011
PASS: reject_lookup multiline-quoted-script -> node-eval.sh AP-012
PASS: reject_lookup unquoted-brace-glob -> peek-files.sh AP-013
PASS: reject_lookup xargs-sh-c-compound-body -> peek-files.sh AP-014
PASS: reject_lookup nested-cmd-sub (M021 baseline preserved)
PASS: reject_lookup compound-chain-gt2 (M021 baseline preserved)
PASS: reject_lookup heredoc-with-expansion (M021 baseline preserved)
PASS: reject_lookup quoted-brace (M021 baseline preserved)
PASS: reject_lookup default (catch-all preserved)
PASS: p03-reject-lookup-coverage.sh
```

After running `bash scripts/verify/m028/p02-hook-self-conformance.sh`:

```
PASS: resolution-block lines 35..64 conform to M021 classifier
PASS: p02-hook-self-conformance.sh
```

(P02 verifier still passes — T03 did not touch the resolution block. The M028-extended self-conformance scope is T05's `finding-G-self-conformance.sh` which extends to the new reject_lookup arms.)
