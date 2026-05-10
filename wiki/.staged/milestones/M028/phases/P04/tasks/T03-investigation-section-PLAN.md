---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P04"
milestone: "M028"
name: "Investigation Patterns Documentation Section"
depends_on: ["T01", "T02"]
---

## Prerequisites

Plan-author empirically verified each Prerequisite path on disk at plan-authoring time:

- `commands/dispatch.md` exists.
- `templates/dispatch-prompt.md` exists.
- `ANTIPATTERNS.md` exists (post-P03 with AP-014 as the last entry on line 310).
- `scripts/verify/anti-pattern-lint.sh` exists.

Files T03 expects to exist (T01 + T02 deliverables) after upstream tasks complete:
- `scripts/util/grep-files.sh` (T01)
- `scripts/util/cleanup-stale-results.sh` (T01)
- `scripts/util/node-eval.sh` (T02)
- `scripts/util/peek-files.sh` (T02)

T03 reads neither task's *summary* but consumes their *deliverables*: each wrapper file is named in T03's documentation prose. T03 does NOT need to source or invoke the wrappers — only name them with a one-line example each.

## Description

Author three documentation deliverables and two co-authored verifiers:

1. **`commands/dispatch.md`** — add a top-level `## Investigation Patterns` section after `## Context Construction` (line 35) and before `## Dispatch Strategy` (line 67). The section names all four wrappers with a one-line usage example each + an AP-ID cross-reference. Section authoring discipline: every code fence must itself pass `bash scripts/verify/anti-pattern-lint.sh` — no compound shells, no quoted-brace, no backtick-in-grep, no nested cmd-sub. Examples use the canonical `bash scripts/util/<wrapper> <args>` shape.

2. **`templates/dispatch-prompt.md`** — add a parallel `## Investigation Patterns` section after `## Scope` and before `## Upstream Context`. Same four wrappers, same one-line usage examples, but framed as "if you need to do X, call Y" advice for the dispatched agent. The dispatch payload's section is the agent-facing surface (per the M028 spec FR-18: "their `dispatch-prompt.md` template carries the section so subagents see it").

3. **`ANTIPATTERNS.md`** — add a new `## Investigation patterns` subsection after AP-014 (current last entry, line 310-onwards). Cross-references each wrapper to its AP-ID:
   - `grep-files.sh` → AP-010 (cmd-sub-in-pattern; backtick-in-grep alternative)
   - `cleanup-stale-results.sh` → Finding D (Screenshot 2; no AP entry — anchored at the M028 spec's Finding D evidence trail)
   - `node-eval.sh` → AP-012 (multiline-quoted-script)
   - `peek-files.sh` → AP-013 (unquoted-brace-glob alternative for the file-enum-then-peek pattern) + AP-014 (xargs-sh-c-compound-body)

4. **`scripts/verify/m028/p04-investigation-section.sh`** (~50 lines) — co-authored plan-level verifier asserting each section exists and names each wrapper at least once.

5. **`scripts/verify/m028/p04-anti-pattern-lint-clean.sh`** (~40 lines) — co-authored plan-level verifier running `bash scripts/verify/anti-pattern-lint.sh` and asserting exit 0 against the post-T03 tree.

## Steps

### Round 1 — `commands/dispatch.md`

1. **Read `commands/dispatch.md`** to confirm the insertion site. The `## Context Construction` section ends at line 66 (before `## Dispatch Strategy` at line 67). Insert the new section between them.

2. **Author the new section** in `commands/dispatch.md`. Insert verbatim:

```markdown
## Investigation Patterns

Subagents performing mid-task investigation (grep across files, cleanup stale per-step results, evaluate a short Node expression, peek the first N lines of files matching a glob) MUST call one of the four canonical wrappers under `scripts/util/` instead of constructing a compound shell. The compound shells trip the M021/M028 shape guard; the wrappers are allow-listed and shape-clean.

| Use case | Wrapper | One-line example | Antipattern remediated |
|---|---|---|---|
| Grep one pattern across multiple files | `scripts/util/grep-files.sh` | `bash scripts/util/grep-files.sh 'pattern' file1.md file2.md` | AP-010 (cmd-sub-in-pattern) |
| Remove stale per-step result files | `scripts/util/cleanup-stale-results.sh` | `bash scripts/util/cleanup-stale-results.sh M028` | Finding D (Screenshot 2) |
| Run a Node script file (no inline `-e` body) | `scripts/util/node-eval.sh` | `bash scripts/util/node-eval.sh tmp/probe.js arg1 arg2` | AP-012 (multiline-quoted-script) |
| Peek first N lines of files matching a glob | `scripts/util/peek-files.sh` | `bash scripts/util/peek-files.sh 'T*-SUMMARY.md' --lines 20` | AP-013, AP-014 |

Each wrapper exits 0 on success, returns a structured exit code on failure (2 on usage error), and is bash 3.2 + POSIX-sh-safe. See `ANTIPATTERNS.md` "Investigation patterns" subsection for AP-ID cross-references.
```

3. **Verify shape-cleanness** of every example fence by running:

```bash
bash scripts/verify/anti-pattern-lint.sh --fixture commands/dispatch.md
```

The lint must exit 0. If any line trips a heuristic, adjust the example (e.g. quote glob patterns, drop literal backticks).

### Round 2 — `templates/dispatch-prompt.md`

4. **Read `templates/dispatch-prompt.md`** to confirm the insertion site. The `## Scope` section ends before `## Upstream Context` (around line 27 in the current file; T03 author re-confirms by reading the file).

5. **Author the new section** in `templates/dispatch-prompt.md`. Insert verbatim:

```markdown
## Investigation Patterns

<!-- Static reference for the dispatched agent. Names the four canonical
     wrappers under scripts/util/ that replace agent-invented compound shells.
     The dispatched agent reads this section in-payload and calls these
     wrappers instead of constructing inline grep ; echo ; grep / find | head |
     xargs sh -c '...' / node -e "<multiline body>" / etc. shapes. -->

If you need to investigate the codebase mid-task, use these canonical wrappers under `scripts/util/` instead of constructing compound shells (which the active M021/M028 shape guard will reject):

- **Grep one pattern across multiple files**: `bash scripts/util/grep-files.sh <pattern> <file...>` — emits per-file separators; replaces `grep PAT f1 ; echo "---" ; grep PAT f2`. Cross-ref: ANTIPATTERNS.md AP-010.
- **Remove stale per-step result files for a milestone**: `bash scripts/util/cleanup-stale-results.sh <milestone-id>` — refuses paths outside the milestone tree. Cross-ref: M028 Finding D.
- **Run a short Node script** (file path, NOT `-e` body): `bash scripts/util/node-eval.sh <script-path> [args...]` — refuses `-e`/`-p`. Cross-ref: ANTIPATTERNS.md AP-012.
- **Peek first N lines of files matching a glob**: `bash scripts/util/peek-files.sh <glob> [--lines N] [--exclude PATH] [--max N]` — replaces `find ... | head | xargs -I{} sh -c '...'`. Cross-ref: ANTIPATTERNS.md AP-013 + AP-014.
```

6. **Verify shape-cleanness** of the new template section:

```bash
bash scripts/verify/anti-pattern-lint.sh --fixture templates/dispatch-prompt.md
```

### Round 3 — `ANTIPATTERNS.md`

7. **Append the `## Investigation patterns` subsection** to `ANTIPATTERNS.md` (after line 339, the AP-014 closing). Insert verbatim:

```markdown

## Investigation patterns

Investigation-pattern wrappers landed in M028/P04 to give agents canonical alternatives to the compound shells that trip M021's classifier and M028's expanded matrix. Each wrapper is a flat AD-19 single-script-file under `scripts/util/`, bash 3.2 + POSIX-sh-safe, with no jq dependency.

| Wrapper | Use case | Cross-ref |
|---|---|---|
| `scripts/util/grep-files.sh <pattern> <file...>` | Grep one pattern across multiple files; per-file separators; aggregate exit code | AP-010 (cmd-sub-in-pattern) — backtick-in-grep alternative |
| `scripts/util/cleanup-stale-results.sh <milestone-id>` | Remove per-step result files under a milestone tree; refuses paths outside `.orchestrator/milestones/<MID>/` | M028 Finding D (Screenshot 2) — `/bin/rm && ls` shape replacement |
| `scripts/util/node-eval.sh <script-path> [args...]` | Run a `.js`/`.mjs`/`.cjs` script; refuses `-e`/`-p` to prevent rebuilding the AP-012 shape | AP-012 (multiline-quoted-script) |
| `scripts/util/peek-files.sh <glob> [--lines N] [--exclude PATH] [--max N]` | Enumerate files matching a glob and head-N each match; uses `find`+`while-read`, never `xargs sh -c` | AP-013 (unquoted-brace-glob), AP-014 (xargs-sh-c-compound-body) |

The wrappers are referenced from `commands/dispatch.md` "Investigation Patterns" section (the planner-facing surface) and from `templates/dispatch-prompt.md` "Investigation Patterns" section (the agent-facing dispatch payload). When the M021/M028 hook rejects an investigation-shape command, the rejected diagnostic names the relevant wrapper as the remediation path.
```

8. **Verify shape-cleanness** of the new ANTIPATTERNS.md section:

```bash
bash scripts/verify/anti-pattern-lint.sh --fixture ANTIPATTERNS.md
```

(Note: `anti-pattern-lint.sh` self-excludes `ANTIPATTERNS.md` from its default scan, but the `--fixture` mode forces the scan; use this to validate the new subsection's shape independently.)

### Round 4 — Plan-level verifiers

9. **Author `scripts/verify/m028/p04-investigation-section.sh`** (~55 lines):

```bash
#!/usr/bin/env bash
# scripts/verify/m028/p04-investigation-section.sh -- M028 P04/T03 plan-level verifier.
#
# Asserts that the three documentation surfaces (commands/dispatch.md,
# templates/dispatch-prompt.md, ANTIPATTERNS.md) carry the Investigation
# Patterns section and that each section names all four wrappers.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"

DISPATCH_MD="${REPO_ROOT}/commands/dispatch.md"
PROMPT_TPL="${REPO_ROOT}/templates/dispatch-prompt.md"
ANTI_MD="${REPO_ROOT}/ANTIPATTERNS.md"

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

assert_section_and_wrappers() {
  local file="$1" header_pattern="$2" label="$3"
  if [ ! -f "$file" ]; then
    fail "$label exists" "missing $file"
    return
  fi
  if grep -qE "$header_pattern" "$file"; then
    pass "$label has Investigation section header"
  else
    fail "$label section header" "no match for $header_pattern in $file"
    return
  fi
  for w in grep-files.sh cleanup-stale-results.sh node-eval.sh peek-files.sh; do
    if grep -q "$w" "$file"; then
      pass "$label names $w"
    else
      fail "$label names $w" "missing $w in $file"
    fi
  done
}

assert_section_and_wrappers "$DISPATCH_MD" "^## Investigation Patterns" "commands/dispatch.md"
assert_section_and_wrappers "$PROMPT_TPL" "^## Investigation Patterns" "templates/dispatch-prompt.md"
assert_section_and_wrappers "$ANTI_MD"    "^## Investigation patterns" "ANTIPATTERNS.md"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: p04-investigation-section.sh"
  exit 0
fi
echo "FAIL: p04-investigation-section.sh ($fail_count failures)"
exit 1
```

10. **Author `scripts/verify/m028/p04-anti-pattern-lint-clean.sh`** (~40 lines):

```bash
#!/usr/bin/env bash
# scripts/verify/m028/p04-anti-pattern-lint-clean.sh -- M028 P04/T03 plan-level verifier.
#
# Runs `scripts/verify/anti-pattern-lint.sh` against its default scope
# (which includes commands/*.md, templates/*.md, dispatch lib, and task
# PAYLOADs) and asserts exit 0. The default scope covers the T03 surface;
# the lint already self-excludes ANTIPATTERNS.md.
#
# Also runs the lint with --fixture against ANTIPATTERNS.md to validate
# the new "Investigation patterns" subsection's shape is clean.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"
LINT="${REPO_ROOT}/scripts/verify/anti-pattern-lint.sh"

if [ ! -f "$LINT" ]; then
  echo "FAIL: $LINT not found" >&2
  exit 1
fi

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

# Default-scope lint -- must pass.
if bash "$LINT" >/dev/null 2>&1; then
  pass "anti-pattern-lint default-scope clean"
else
  fail "anti-pattern-lint default-scope" "non-zero exit"
fi

# Fixture-mode lint against ANTIPATTERNS.md -- must pass on the new subsection.
if bash "$LINT" --fixture "${REPO_ROOT}/ANTIPATTERNS.md" >/dev/null 2>&1; then
  pass "anti-pattern-lint --fixture ANTIPATTERNS.md clean"
else
  fail "anti-pattern-lint --fixture ANTIPATTERNS.md" "non-zero exit"
fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: p04-anti-pattern-lint-clean.sh"
  exit 0
fi
echo "FAIL: p04-anti-pattern-lint-clean.sh ($fail_count failures)"
exit 1
```

11. **Run both plan-level verifiers locally** before commit:

```bash
bash scripts/verify/m028/p04-investigation-section.sh
```

```bash
bash scripts/verify/m028/p04-anti-pattern-lint-clean.sh
```

12. **Commit** via `git commit -F <message-file>`.

## Must-Haves

This task addresses the phase Truths:

- "`commands/dispatch.md` carries an Investigation Patterns section …"
- "`bash scripts/verify/anti-pattern-lint.sh` exits 0 against the updated tree …"

The plan-level verifiers `p04-investigation-section.sh` and `p04-anti-pattern-lint-clean.sh` (T03 deliverables) implement the assertion logic.

## Verification

```bash
bash scripts/verify/m028/p04-investigation-section.sh
```

```bash
bash scripts/verify/m028/p04-anti-pattern-lint-clean.sh
```

## Inputs

### From Previous Tasks

- `scripts/util/grep-files.sh` (T01) — named in dispatch.md, dispatch-prompt.md, ANTIPATTERNS.md.
- `scripts/util/cleanup-stale-results.sh` (T01) — named in the three docs.
- `scripts/util/node-eval.sh` (T02) — named in the three docs.
- `scripts/util/peek-files.sh` (T02) — named in the three docs.

T03 does not source / invoke / parse any wrapper script; it only references each by relative path in prose. The wrappers' API surface is the documented one-line `bash scripts/util/<name> <args>` form (see T01/T02 plans for the full interface).

### From Disk (Pre-existing)

- `commands/dispatch.md` — the section-insertion target. Plan-author confirmed line 35 (`## Context Construction`) and line 67 (`## Dispatch Strategy`) at plan-authoring time; the new section sits between.
- `templates/dispatch-prompt.md` — the section-insertion target. Plan-author confirmed `## Scope` and `## Upstream Context` markers at plan-authoring time; the new section sits between.
- `ANTIPATTERNS.md` — the subsection-append target. Plan-author confirmed AP-014 ends at line 339; the new subsection sits after.
- `scripts/verify/anti-pattern-lint.sh` — the lint the close-out verifier invokes; plan-author confirmed it accepts `--fixture <path>` mode (lines 32-49 of the lint script).

### Key API Surface

- `anti-pattern-lint.sh [--fixture <file>]` — exits 0 if the scanned tree (or the single fixture) is shape-clean; exits 1 with diagnostic if any AP-001..AP-009 pattern is found.

## Constraints

- **CON-1 (AD-19)**: Each plan-level verifier is a flat single-file shape under `scripts/verify/m028/`.
- **CON-2 (bash 3.2 + POSIX sh)**: No `mapfile`, no `<<<`, no process substitution.
- **CON-7 (no-M021-regression)**: T03 must not introduce any line into the three documentation surfaces that trips an [M021](../../../../../milestones/M021/index.md) AP-001..AP-009 heuristic. The lint passes are the gate; the canonical wrapper-invocation examples were chosen specifically to be shape-clean (no compound `;`/`&&`/`||`, no quoted brace, no backtick-in-regex).
- **Documentation discipline**: Each wrapper appears in all three documentation surfaces (`dispatch.md`, `dispatch-prompt.md`, `ANTIPATTERNS.md`); the `p04-investigation-section.sh` verifier asserts exact pattern coverage on each.
- **Verification-section authoring**: `## Verification` invokes project-tree verifiers directly. No `run-probe.sh` wrapping.
- **Plan-time verifier-availability**: Both `## Verification` checks resolve to scripts T03 itself authors.
- **Plan-time classifier-shape pre-validation**: Verifier-invocation lines `bash scripts/verify/m028/p04-investigation-section.sh` and `bash scripts/verify/m028/p04-anti-pattern-lint-clean.sh` traced through `classify_command` at plan-authoring time → both `allow`. The example wrapper-invocations (`bash scripts/util/grep-files.sh 'pattern' file1.md file2.md`, etc.) were chosen to classify clean — single-stage wrapper invocation, no compound, no backtick-in-grep.
- **Commit-message form**: `git commit -F <file>`.

## Expected Output

After `bash scripts/verify/m028/p04-investigation-section.sh`:

```
PASS: commands/dispatch.md has Investigation section header
PASS: commands/dispatch.md names grep-files.sh
PASS: commands/dispatch.md names cleanup-stale-results.sh
PASS: commands/dispatch.md names node-eval.sh
PASS: commands/dispatch.md names peek-files.sh
PASS: templates/dispatch-prompt.md has Investigation section header
PASS: templates/dispatch-prompt.md names grep-files.sh
PASS: templates/dispatch-prompt.md names cleanup-stale-results.sh
PASS: templates/dispatch-prompt.md names node-eval.sh
PASS: templates/dispatch-prompt.md names peek-files.sh
PASS: ANTIPATTERNS.md has Investigation section header
PASS: ANTIPATTERNS.md names grep-files.sh
PASS: ANTIPATTERNS.md names cleanup-stale-results.sh
PASS: ANTIPATTERNS.md names node-eval.sh
PASS: ANTIPATTERNS.md names peek-files.sh
PASS: p04-investigation-section.sh
```

After `bash scripts/verify/m028/p04-anti-pattern-lint-clean.sh`:

```
PASS: anti-pattern-lint default-scope clean
PASS: anti-pattern-lint --fixture ANTIPATTERNS.md clean
PASS: p04-anti-pattern-lint-clean.sh
```
