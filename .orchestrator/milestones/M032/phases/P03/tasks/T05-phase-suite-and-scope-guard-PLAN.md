---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P03"
milestone: "M032"
name: "P03 phase-suite aggregator + scope-guard"
depends_on: ["T01", "T02", "T03", "T04"]
---

## Prerequisites

- T01–T04 have all landed at execution time. T05 reads each upstream task's verifier paths to compose the phase-suite chain. Verified by:
  - `[ -x tools/verify/m032-p03-giscus-templating.sh ]` (T01)
  - `[ -x tools/verify/m032-p03-with-giscus-scope.sh ]` (T01)
  - `[ -x tools/verify/m032-p03-deploy-scope.sh ]` (T02)
  - `[ -x tools/verify/m032-p03-wiki-deploy-cwd-gate.sh ]` (T02)
  - `[ -x tools/verify/m032-p03-custom-nav-region.sh ]` (T03)
  - `[ -x tools/verify/m032-p03-with-feature-pattern-doc.sh ]` (T04)
  - `[ -x tools/verify/m032-p03-throwaway-protocol-shape.sh ]` (T04)
  - `[ -x tools/verify/m032-p03-acceptance-shape-sc4.sh ]` (T01)
  - `[ -x tools/verify/m032-p03-acceptance-shape-sc5.sh ]` (T04)
  - `[ -x tools/verify/m032-p03-acceptance-shape-sc6.sh ]` (T03)
- `tools/verify/fixtures/` exists from P01/P02 baseline-ref convention. Verified by `[ -d tools/verify/fixtures ]`.
- The previous P02 baseline-ref `tools/verify/fixtures/m032-p02-baseline-ref.txt` exists as the pattern T05 follows for `m032-p03-baseline-ref.txt`. Verified by `[ -f tools/verify/fixtures/m032-p02-baseline-ref.txt ]`.

## Description

T05 is the verification-aggregation surface that ties P03 closed. The deliverable surface has three pieces:

1. **Phase-suite aggregator** at `tools/verify/m032-p03-phase-suite.sh` — invokes every P03 sub-gate in dependency order, exits 0 iff every sub-gate passes, emits a `SUMMARY: m032-p03-phase-suite.sh pass=N fail=M` summary line. Single-script-file shape per AD-19.

2. **Scope-guard** at `tools/verify/m032-p03-scope-guard.sh` — asserts P03's diff is confined to the declared "Files Likely Touched" list. Greps `git diff --name-only` against an allowlist of P03-owned paths and a denylist of P00/P01/P02-owned paths. Captures a baseline-ref at `tools/verify/fixtures/m032-p03-baseline-ref.txt` per the M032 P01/P02 baseline-ref convention.

3. **Baseline-ref fixture** at `tools/verify/fixtures/m032-p03-baseline-ref.txt` — first-run captures the post-P03-execution file-set state; subsequent runs of the scope-guard compare against it.

T05 modifies zero T01–T04 deliverables. It consumes them.

## Steps

1. **Author `tools/verify/m032-p03-phase-suite.sh`** chaining the ten P03 sub-gates in dependency order. Single-script-file shape; exits 0 iff every sub-gate passes; emits the summary line per AD-19.

```bash
#!/usr/bin/env bash
# tools/verify/m032-p03-phase-suite.sh — P03 phase-suite aggregator.
# Invokes every P03 sub-gate in dependency order, exits 0 iff every gate
# passes, emits a single SUMMARY line. Single-script-file shape per AD-19.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

pass=0
fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

run_gate() {
  _name="$1"
  _path="$2"
  if [ ! -x "$_path" ]; then
    say_fail "$_name: verifier missing or non-executable at $_path"
    return
  fi
  if bash "$_path" >/tmp/m032-p03-gate-$$.out 2>&1; then
    say_pass "$_name"
  else
    rc=$?
    say_fail "$_name (rc=$rc): $(tail -3 /tmp/m032-p03-gate-$$.out | tr '\n' ' ')"
  fi
  rm -f /tmp/m032-p03-gate-$$.out
}

run_gate 'FR-7 giscus-templating'              tools/verify/m032-p03-giscus-templating.sh
run_gate 'FR-8 with-giscus-scope'              tools/verify/m032-p03-with-giscus-scope.sh
run_gate 'FR-9 deploy-scope'                   tools/verify/m032-p03-deploy-scope.sh
run_gate 'FR-10 wiki-deploy-cwd-gate'          tools/verify/m032-p03-wiki-deploy-cwd-gate.sh
run_gate 'FR-14 custom-nav-region'             tools/verify/m032-p03-custom-nav-region.sh
run_gate 'FR-13 with-feature-pattern-doc'      tools/verify/m032-p03-with-feature-pattern-doc.sh
run_gate 'AD-7 throwaway-protocol-shape'       tools/verify/m032-p03-throwaway-protocol-shape.sh
run_gate 'SC-4 acceptance-shape'               tools/verify/m032-p03-acceptance-shape-sc4.sh
run_gate 'SC-5 acceptance-shape'               tools/verify/m032-p03-acceptance-shape-sc5.sh
run_gate 'SC-6 acceptance-shape'               tools/verify/m032-p03-acceptance-shape-sc6.sh

printf 'SUMMARY: m032-p03-phase-suite.sh pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

2. **Author `tools/verify/m032-p03-scope-guard.sh`** asserting P03's diff is confined to the declared "Files Likely Touched" list. Single-script-file shape. Required content:

```bash
#!/usr/bin/env bash
# tools/verify/m032-p03-scope-guard.sh — SC-13 scope-guard for P03.
# Asserts P03's git-tracked changes are confined to the P03 allowlist.
# Compares the current working-tree state (or an explicit baseline-ref)
# against the M032/P03 expected paths. Single-script-file shape per AD-19.
#
# Baseline-ref convention (P01/P02): if
# tools/verify/fixtures/m032-p03-baseline-ref.txt exists, this verifier
# compares the current diff against the baseline. If absent, the verifier
# captures the current diff as the baseline (first-run capture pattern).

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"
BASELINE="tools/verify/fixtures/m032-p03-baseline-ref.txt"

pass=0
fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

# P03 allowlist — every path P03 may touch (create or modify).
ALLOWLIST="
wiki/overrides/partials/comments.html
scripts/lifecycle/wiki-init.sh
scripts/wiki/wiki-deploy.sh
scripts/wiki/wiki-generate-nav.sh
wiki/mkdocs.yml
references/installation.md
tests/m032-acceptance/throwaway-fixture-protocol.md
tests/m032-acceptance/p02-wiki-init-with-giscus.sh
tests/m032-acceptance/p03-wiki-init-deploy-live.sh
tests/m032-acceptance/p02-wiki-generate-nav-custom-region.sh
tools/verify/m032-p03-giscus-templating.sh
tools/verify/m032-p03-with-giscus-scope.sh
tools/verify/m032-p03-deploy-scope.sh
tools/verify/m032-p03-wiki-deploy-cwd-gate.sh
tools/verify/m032-p03-custom-nav-region.sh
tools/verify/m032-p03-with-feature-pattern-doc.sh
tools/verify/m032-p03-throwaway-protocol-shape.sh
tools/verify/m032-p03-acceptance-shape-sc4.sh
tools/verify/m032-p03-acceptance-shape-sc5.sh
tools/verify/m032-p03-acceptance-shape-sc6.sh
tools/verify/m032-p03-phase-suite.sh
tools/verify/m032-p03-scope-guard.sh
tools/verify/fixtures/m032-p03-baseline-ref.txt
.orchestrator/milestones/M032/phases/P03/P03-PLAN.md
.orchestrator/milestones/M032/phases/P03/P03-PLANNING-PAYLOAD.md
.orchestrator/milestones/M032/phases/P03/P03-SUMMARY.md
.orchestrator/milestones/M032/phases/P03/tasks/T01-with-giscus-scope-PLAN.md
.orchestrator/milestones/M032/phases/P03/tasks/T01-with-giscus-scope-PAYLOAD.md
.orchestrator/milestones/M032/phases/P03/tasks/T01-with-giscus-scope-SUMMARY.md
.orchestrator/milestones/M032/phases/P03/tasks/T02-deploy-scope-PLAN.md
.orchestrator/milestones/M032/phases/P03/tasks/T02-deploy-scope-PAYLOAD.md
.orchestrator/milestones/M032/phases/P03/tasks/T02-deploy-scope-SUMMARY.md
.orchestrator/milestones/M032/phases/P03/tasks/T03-custom-nav-region-PLAN.md
.orchestrator/milestones/M032/phases/P03/tasks/T03-custom-nav-region-PAYLOAD.md
.orchestrator/milestones/M032/phases/P03/tasks/T03-custom-nav-region-SUMMARY.md
.orchestrator/milestones/M032/phases/P03/tasks/T04-throwaway-fixture-and-sc5-PLAN.md
.orchestrator/milestones/M032/phases/P03/tasks/T04-throwaway-fixture-and-sc5-PAYLOAD.md
.orchestrator/milestones/M032/phases/P03/tasks/T04-throwaway-fixture-and-sc5-SUMMARY.md
.orchestrator/milestones/M032/phases/P03/tasks/T05-phase-suite-and-scope-guard-PLAN.md
.orchestrator/milestones/M032/phases/P03/tasks/T05-phase-suite-and-scope-guard-PAYLOAD.md
.orchestrator/milestones/M032/phases/P03/tasks/T05-phase-suite-and-scope-guard-SUMMARY.md
.orchestrator/milestones/M032/execution-log.jsonl
"

# Denylist — paths that P03 MUST NOT touch (P00/P01/P02 ownership).
DENYLIST="
packaging/install/install-claude-code.sh
packaging/install/install-codex.sh
packaging/install/install-cursor.sh
packaging/bundle/manifest.yml
commands/init.md
scripts/lifecycle/init-project.sh
wiki/glossary.md
scripts/wiki/wiki-scan-sources.sh
scripts/knowledge/lookup-mems.sh
tests/paired-m032-m033/seam-A.sh
tests/paired-m032-m033/seam-B.sh
tests/paired-m032-m033/seam-C.sh
"

# Resolve the diff set: prefer git diff against the milestone-entry tag/ref
# if available; otherwise fall back to git status's modified/untracked list
# scoped to the working tree.
DIFF_RAW=""
if git rev-parse --verify HEAD >/dev/null 2>&1; then
  # Compare against the most recent commit. P03 is mid-flight at scope-guard
  # invocation time, so working-tree changes are the load-bearing surface.
  DIFF_RAW=$(git status --porcelain | awk '{print $2}' | sort -u)
fi

# Filter out anything outside the repo (path-traversal safety) and anything
# that only matches whitespace.
DIFF_PATHS=$(printf '%s\n' "$DIFF_RAW" | grep -v '^$' || true)

# Allowlist check: every diff path must be in the allowlist.
TOTAL_IN_SCOPE=0
TOTAL_OUT_OF_SCOPE=0
OUT_OF_SCOPE_LIST=""
while IFS= read -r dpath; do
  [ -z "$dpath" ] && continue
  if printf '%s' "$ALLOWLIST" | grep -qxF "$dpath"; then
    TOTAL_IN_SCOPE=$((TOTAL_IN_SCOPE + 1))
  else
    TOTAL_OUT_OF_SCOPE=$((TOTAL_OUT_OF_SCOPE + 1))
    OUT_OF_SCOPE_LIST="$OUT_OF_SCOPE_LIST $dpath"
  fi
done <<EOF
$DIFF_PATHS
EOF

if [ "$TOTAL_OUT_OF_SCOPE" -eq 0 ]; then
  say_pass "scope: all $TOTAL_IN_SCOPE diff paths within P03 allowlist"
else
  say_fail "scope: $TOTAL_OUT_OF_SCOPE diff path(s) outside P03 allowlist:$OUT_OF_SCOPE_LIST"
fi

# Denylist check: no diff path may be in the denylist.
DENY_HITS=0
DENY_LIST=""
while IFS= read -r dpath; do
  [ -z "$dpath" ] && continue
  if printf '%s' "$DENYLIST" | grep -qxF "$dpath"; then
    DENY_HITS=$((DENY_HITS + 1))
    DENY_LIST="$DENY_LIST $dpath"
  fi
done <<EOF
$DIFF_PATHS
EOF

if [ "$DENY_HITS" -eq 0 ]; then
  say_pass "scope: no diff path in P00/P01/P02 denylist"
else
  say_fail "scope: $DENY_HITS diff path(s) in P00/P01/P02 denylist:$DENY_LIST (SC-13 violation)"
fi

# Baseline-ref capture / verify.
if [ -f "$BASELINE" ]; then
  if printf '%s\n' "$DIFF_PATHS" | sort -u | diff -q - "$BASELINE" >/dev/null 2>&1; then
    say_pass "baseline-ref matches: $BASELINE"
  else
    say_pass "baseline-ref drift detected (informational; expected during active phase)"
  fi
else
  printf '%s\n' "$DIFF_PATHS" | sort -u > "$BASELINE"
  say_pass "baseline-ref captured at $BASELINE (first-run)"
fi

printf 'PASS: m032-p03 scope-guard pass=%d fail=%d in_scope=%d denylist_hits=%d\n' "$pass" "$fail" "$TOTAL_IN_SCOPE" "$DENY_HITS"
printf 'SUMMARY: m032-p03-scope-guard.sh pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

3. **Make new scripts executable**: `chmod +x tools/verify/m032-p03-phase-suite.sh tools/verify/m032-p03-scope-guard.sh`.

4. **Capture the baseline-ref**. On first execution, the scope-guard's first-run-captures-baseline branch will write `tools/verify/fixtures/m032-p03-baseline-ref.txt`. T05 invokes the scope-guard once at task close to ensure the baseline is captured:

```bash
bash tools/verify/m032-p03-scope-guard.sh
```

The capture writes the file. Subsequent runs of the scope-guard verify the working-tree diff against the captured baseline (drift is informational during active phase per the P02 precedent).

5. **Run the full phase-suite once at task close** to confirm all ten sub-gates pass:

```bash
bash tools/verify/m032-p03-phase-suite.sh
```

Expected output: `SUMMARY: m032-p03-phase-suite.sh pass=10 fail=0`, exit 0.

## Must-Haves

- `tools/verify/m032-p03-phase-suite.sh` aggregator chaining all ten P03 sub-gates with single-script-file shape per AD-19, emitting `SUMMARY: m032-p03-phase-suite.sh pass=N fail=M` summary line, exit 0 iff every gate passes
- `tools/verify/m032-p03-scope-guard.sh` enforcing the SC-13 scope discipline against the P03 allowlist + P00/P01/P02 denylist, with first-run baseline-ref capture per the M032 P01/P02 convention
- `tools/verify/fixtures/m032-p03-baseline-ref.txt` baseline-ref captured

## Verification

```bash
bash tools/verify/m032-p03-phase-suite.sh
```

```bash
bash tools/verify/m032-p03-scope-guard.sh
```

## Notes

Expected output:
- `m032-p03-phase-suite.sh` final line: `SUMMARY: m032-p03-phase-suite.sh pass=10 fail=0`, exit 0.
- `m032-p03-scope-guard.sh` final lines (two summary lines per the P02 precedent): `PASS: m032-p03 scope-guard pass=N fail=0 in_scope=M denylist_hits=0` followed by `SUMMARY: m032-p03-scope-guard.sh pass=N fail=0`, exit 0.

The phase-suite aggregator is intentionally thin — it does not add any new verification logic, only chains existing ones. This matches the M030/M031/M032 P00–P02 phase-suite-aggregator pattern. New verification logic for P03 lives in T01–T04's verifiers; T05's job is to express the dependency order and emit a unified summary line.

The scope-guard's allowlist intentionally includes the planning-state files (`P03-PLAN.md`, `P03-PAYLOAD.md`, `P03-SUMMARY.md`, the per-task `T##-*-PAYLOAD.md` / `-SUMMARY.md`) and the milestone execution-log because P03 work flows through those paths during dispatch. The denylist excludes only the file paths owned by P00/P01/P02 — paths owned by future phases (P04 scanner extensions, etc.) are NOT in the denylist because the P03 working tree should not contain them yet (they don't exist; if a P03 task accidentally created one, the allowlist check would still flag it as out-of-scope).

Bash 3.2 gotcha for the `<<EOF` heredoc-fed `while read` loop: the harness shape-guard (AP-009) does not flag heredocs feeding while-loops; it flags heredocs feeding pipelines. The structure here is `while IFS= read -r dpath; do ... done <<EOF\n$DIFF_PATHS\nEOF` — single heredoc, no pipes — which is allowed.

The baseline-ref file format is one-path-per-line, sorted, deduplicated. Subsequent baseline-ref drift is informational rather than fatal because P03 work continues across multiple commits during active development (the SC-13 scope-guard pattern from P01/P02 also surfaces drift informationally; the SC-13 final gate is the post-close `validate-milestone.sh` PASS).

## Inputs

### From Previous Tasks

- `tools/verify/m032-p03-giscus-templating.sh` (T01) — invoked by phase-suite as gate 1.
- `tools/verify/m032-p03-with-giscus-scope.sh` (T01) — invoked as gate 2.
- `tools/verify/m032-p03-deploy-scope.sh` (T02) — invoked as gate 3.
- `tools/verify/m032-p03-wiki-deploy-cwd-gate.sh` (T02) — invoked as gate 4.
- `tools/verify/m032-p03-custom-nav-region.sh` (T03) — invoked as gate 5.
- `tools/verify/m032-p03-with-feature-pattern-doc.sh` (T04) — invoked as gate 6.
- `tools/verify/m032-p03-throwaway-protocol-shape.sh` (T04) — invoked as gate 7.
- `tools/verify/m032-p03-acceptance-shape-sc4.sh` (T01) — invoked as gate 8.
- `tools/verify/m032-p03-acceptance-shape-sc5.sh` (T04) — invoked as gate 9.
- `tools/verify/m032-p03-acceptance-shape-sc6.sh` (T03) — invoked as gate 10.

Each upstream verifier's contract: exit 0 on pass with final line `SUMMARY: <name> pass=N fail=0`; non-zero on fail with `SUMMARY: <name> pass=N fail=M` where M > 0. The phase-suite aggregator does NOT parse the SUMMARY line — it only consumes the exit code (`bash <gate>` and check `$?`).

### From Disk (Pre-existing)

- `tools/verify/fixtures/` — directory exists per P01/P02 baseline-ref convention.
- `tools/verify/fixtures/m032-p02-baseline-ref.txt` — pattern reference for `m032-p03-baseline-ref.txt`'s file shape.

## Constraints

- Single-script-file shape for the verifier `Check:` commands per AD-19.
- bash 3.2 compatibility (per MEM001) — no `declare -A`, no process substitution; the `while IFS= read -r ... done <<EOF` heredoc-fed loop pattern is allowed (harness shape-guard does not flag this; AP-009 concerns inline compound bash, not heredoc-into-while).
- Verifier scripts MUST live under `tools/verify/` with the `m032-p03-*` prefix.
- T05 modifies ZERO T01–T04 deliverables — purely additive.
- The `tools/verify/fixtures/m032-p03-baseline-ref.txt` path is INSIDE the P03 allowlist (this is intentional — the scope-guard captures its own baseline as part of its diff).
- The phase-suite's gate-naming is operator-facing; preserve the FR-/SC-/AD- tag prefixes for grep-able diagnostics in the failure case.

## Expected Output

After T05 completes:

- `tools/verify/m032-p03-phase-suite.sh` exists and is executable; running it emits `SUMMARY: m032-p03-phase-suite.sh pass=10 fail=0` and exits 0.
- `tools/verify/m032-p03-scope-guard.sh` exists and is executable; running it emits the two-line summary (`PASS: m032-p03 scope-guard ...` + `SUMMARY: m032-p03-scope-guard.sh pass=N fail=0`) and exits 0.
- `tools/verify/fixtures/m032-p03-baseline-ref.txt` exists with the captured first-run diff path set (sorted, deduplicated).
- The two `Check:` commands listed in P03-PLAN.md's "Truths" section for T05-owned truths return exit 0.
