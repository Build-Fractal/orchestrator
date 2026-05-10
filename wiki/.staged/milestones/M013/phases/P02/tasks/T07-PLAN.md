---
schema_version: "1.0"
type: task-plan
task: "T07"
phase: "P02"
milestone: "M013"
name: "Phase verification suite — eight gates + phase-suite orchestrator + Bash 3.2 compat + anti-pattern-lint"
depends_on: ["T01", "T02", "T03", "T04", "T05", "T06"]
---

## Prerequisites

- All P02 task deliverables T01–T06 are on disk: `scripts/integrations/github-common.sh`, `scripts/integrations/github-init.sh`, `commands/github-init.md`, `references/github-integration.md` (extended), `templates/github-integration-sidecar.json` (extended), `tests/fixtures/m013-p02/`.
- P01 phase-suite precedent at `scripts/verify/m013-p01-phase-suite.sh` is the pattern. Study its structure (Bash 3.2 compat loop, per-gate capture files under `/tmp/m013-p01-<gate>.out`, PASS/FAIL accumulators, dependency order).
- `scripts/verify/anti-pattern-lint.sh` exists (M016/[M021](../../../../../milestones/M021/index.md) invariant). Consumed by the bash32-compat gate.
- AD-19 script-file-shape discipline — verify gate scripts are single-script-file invocations. They may internally contain compound bash (they run locally, not through the harness heuristic layer).

## Description

Author the P02 verification suite — eight gate scripts + one phase-suite orchestrator. Each gate script emits ≥3 `PASS:` lines on green, ≥1 `FAIL:` line on red, and exits 0/1 accordingly. The phase-suite orchestrator mirrors the P01 pattern: ordered gate list iterated in a bash-3.2-safe loop, per-gate capture file, PASS/FAIL counters, final self-named summary line.

## Steps

### Step 1: Author `scripts/verify/m013-p02-github-common.sh`

Gate covering T01 deliverables. Assertions:

1. File exists at `scripts/integrations/github-common.sh`, ≥120 lines.
2. Contains the literal `orchestrator_id_for`.
3. `bash -n scripts/integrations/github-common.sh` passes.
4. `orchestrator_id_for` returns `M013-P02` for a fixture milestone dir + `P02`.
5. `orchestrator_id_for` returns `M013-P02-T03` for (M013 dir, P02, T03).
6. `orchestrator_id_for` exits 2 on malformed phase id `Z99`.
7. `emit_marker M013-P02` emits literal `<!-- orchestrator-id: M013-P02 -->`.
8. `find_marker_in_body` exits 0 on unique-match body.
9. `find_marker_in_body` exits 2 on duplicate-match body.
10. `sidecar_path` resolves to `<root>/.orchestrator/integrations/github.json`.
11. `sidecar_get_field repo_slug` returns `pending` on fresh bootstrapped sidecar.
12. `sidecar_set_top_field repo_slug owner/repo` replaces in place.
13. `sidecar_upsert_item M013-P02 42 true true 2026-04-21T12:00:00Z` inserts `items.M013-P02` entry.
14. `manifest_header 5 0 0` prints `MANIFEST: 5 0 0`.
15. `manifest_upsert_line phase-issue M013-P02 - create` prints exactly `UPSERT: phase-issue M013-P02 - create`.
16. `manifest_footer 5 0 0` prints `upserts=5 skipped=0 errors=0`.

Pattern (based on P01 precedent):

```bash
#!/usr/bin/env bash
# scripts/verify/m013-p02-github-common.sh — Gate: T01 github-common.sh helper library.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="${REPO_ROOT}/scripts/integrations/github-common.sh"

pass=0; fail=0; failures=""
pass_fn() { pass=$((pass+1)); echo "PASS: $1"; }
fail_fn() { fail=$((fail+1)); echo "FAIL: $1"; failures="${failures}\n$1"; }

# Assertion 1
if [ -f "$LIB" ]; then pass_fn "github-common.sh present"; else fail_fn "github-common.sh missing"; fi
# Assertion 2
if [ -f "$LIB" ] && [ "$(wc -l < "$LIB" | tr -d ' ')" -ge 120 ]; then
  pass_fn "github-common.sh >=120 lines"
else
  fail_fn "github-common.sh <120 lines"
fi
# Assertion 3 (bash -n)
if bash -n "$LIB" 2>/dev/null; then pass_fn "bash -n github-common.sh"; else fail_fn "bash -n failure"; fi
# Assertions 4-16: source the library + exercise each function
# ... (source "$LIB" + test each)

echo "SUMMARY: m013-p02-github-common.sh pass=$pass fail=$fail"
[ "$fail" -eq 0 ] && { echo "PASS: m013-p02-github-common.sh"; exit 0; }
echo "FAIL: m013-p02-github-common.sh"
exit 1
```

### Step 2: Author `scripts/verify/m013-p02-github-init-fixture.sh`

Gate covering T02 deliverables. Assertions:

1. `scripts/integrations/github-init.sh` present, ≥200 lines, contains `pending-operator-complete`.
2. `bash -n scripts/integrations/github-init.sh` passes.
3. Script supports `--help` (exit 0 with usage).
4. Unknown flag exits 2.
5. Running `bash scripts/integrations/github-init.sh --dry-run --root tests/fixtures/m013-p02/orchestrator-state/ --repo-slug test/test` with `M013_GH_STUB_DIR=tests/fixtures/m013-p02/gh-stub-responses` produces output matching `tests/fixtures/m013-p02/expected-manifest.txt` byte-identical (use `diff -u`).
6. The dry-run output does NOT include the Planning-state phase `M013-P03` (AS-4a lazy projection).
7. The dry-run output contains exactly one `MANIFEST:` header line, followed by `UPSERT:` lines, terminated by a `upserts=... skipped=... errors=...` footer.

### Step 3: Author `scripts/verify/m013-p02-github-init-preflight.sh`

Gate covering preflight diagnostics. Assertions:

1. With stub `auth-status-missing-scope.txt`, preflight emits `integration-auth-failed: missing scope project` on stderr and exits 1 (or preflight-only exit 3 — align with T02 impl).
2. With stub `subissue-rest-unavailable.json`, preflight emits `SUBISSUE_MODE: labeled-fallback` on stdout.
3. With stub `subissue-rest-available.json`, preflight emits `SUBISSUE_MODE: native`.
4. With stub `labels-collision.json` AND `--strict-labels`, preflight emits `integration-labels-collision: phase` on stderr and exits 3.
5. With stub `labels-empty.json` AND `--strict-labels`, preflight succeeds.

### Step 4: Author `scripts/verify/m013-p02-dry-run-manifest.sh`

Gate covering T03 format contract. Assertions:

1. `manifest_header` / `manifest_upsert_line` / `manifest_footer` are defined in `github-common.sh`.
2. `github-init.sh` does not contain any inline `echo "MANIFEST:` or `echo "UPSERT:` — it uses the helpers.
3. First dry-run against fixture matches `expected-manifest.txt` byte-identical.
4. Second dry-run (with sidecar pre-populated) matches `expected-manifest-noop.txt`.
5. No Planning-state phase appears in either manifest.

### Step 5: Author `scripts/verify/m013-p02-github-init-command.sh`

Gate covering T04 command doc. Assertions:

1. `commands/github-init.md` present, ≥50 lines, contains `github-init.sh`.
2. YAML frontmatter has `description` field starting with `Use when`.
3. Contains headings: `Prerequisites / State Check`, `Core Workflow`, `Output`, `Idempotency`, `Error Handling`, `Referenced Scripts`.
4. `Referenced Scripts` section names all four required scripts: `github-init.sh`, `github-common.sh`, `sidecar-init-pending.sh`, `github-status.sh`.
5. Each Referenced Scripts path resolves to an existing file.
6. Contains the auto-mode pending-sentinel paragraph (searches for `pending-operator-complete`).

### Step 6: Author `scripts/verify/m013-p02-reference-extensions.sh`

Gate covering T05 doc extensions. Assertions:

1. `references/github-integration.md` present, ≥240 lines, contains `Auth Modes`.
2. Contains headings: `Auth Modes`, `Sub-Issue Representation Modes`, `Partial Mapping Table`, `init Workflow`, `Dry-Run Manifest Format`.
3. No `TODO P02` markers remain in the file.
4. Contains at least three `_deferred to P03_` cells (the deferred mapping-table rows).
5. P01-authored sections are byte-identical — spot-check: lines containing `"pending"` in any FR-6 top-level field, the `<!-- orchestrator-id: M###-P##[-T##] -->` marker example, and the Knowledge-Layer Boundary subsection header are all present and in the same relative order.

### Step 7: Author `scripts/verify/m013-p02-auto-mode-pending.sh`

Gate covering SC-7 zero-prompt + pending-sentinel path. Assertions:

1. Run `bash scripts/integrations/github-init.sh --root /tmp/m013-p02-t07-auto` under a shell that redirects stdin from `/dev/null` (simulating no TTY).
2. Exit code 0.
3. Stdout first line is `STATUS: pending-operator-complete`.
4. The sidecar at `/tmp/m013-p02-t07-auto/.orchestrator/integrations/github.json` exists after the call.
5. The sidecar contains `sub_issue_mode` set to `pending` (T06 schema extension).
6. Strace/ps log (if available) shows zero `gh` subprocess invocations — OR a simpler proxy: assert the script does not contain `gh ` calls outside of the `OPERATOR -eq 1` or `DRY_RUN` branches (text scan).
7. Running the bootstrap twice in a row doesn't crash (the P01 `sidecar-init-pending.sh` exit 2 is absorbed by init's guard).

### Step 8: Author `scripts/verify/m013-p02-bash32-compat.sh`

Gate covering Constitution IX + MEM001 + SC-6. Mirror the P01 implementation at `scripts/verify/m013-p01-bash32-compat.sh`. Assertions:

1. For each P02-touched `.sh` file (list: `scripts/integrations/github-common.sh`, `scripts/integrations/github-init.sh`, plus every `scripts/verify/m013-p02-*.sh` gate):
   - `bash -n <file>` passes.
   - `grep -E 'declare -A|mapfile|readarray|\$\{[a-zA-Z_][a-zA-Z0-9_]*\^\^\}|\$\{[a-zA-Z_][a-zA-Z0-9_]*,,\}|<\(|>\(|&>|\|&' <file>` returns no matches.
2. `scripts/verify/anti-pattern-lint.sh` passes clean on every P02-touched `.sh` file.

### Step 9: Author `scripts/verify/m013-p02-phase-suite.sh`

The orchestrator. Mirrors P01 pattern. Eight gates in dependency order:

```bash
#!/usr/bin/env bash
# scripts/verify/m013-p02-phase-suite.sh — Orchestrate all M013/P02 gate scripts.
#
# Exits 0 only when every gate passes. Bash 3.2 compatible.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VDIR="${REPO_ROOT}/scripts/verify"

# Dependency order:
#   github-common (T01) ->
#   github-init-fixture (T02) -> github-init-preflight (T02) ->
#   dry-run-manifest (T03) ->
#   github-init-command (T04) ->
#   reference-extensions (T05) ->
#   auto-mode-pending (T02+T06) ->
#   bash32-compat (T07 self + T01..T06 sweep).
GATES="
m013-p02-github-common.sh
m013-p02-github-init-fixture.sh
m013-p02-github-init-preflight.sh
m013-p02-dry-run-manifest.sh
m013-p02-github-init-command.sh
m013-p02-reference-extensions.sh
m013-p02-auto-mode-pending.sh
m013-p02-bash32-compat.sh
"

passed=0; failed=0; failures=""

IFS='
'
for g in $GATES; do
  IFS=' '
  [ -n "$g" ] || continue
  path="${VDIR}/${g}"
  capture="/tmp/m013-p02-${g}.out"
  if [ ! -f "$path" ]; then
    failed=$((failed+1))
    failures="${failures}
FAIL: gate script missing: ${g}"
    continue
  fi
  if bash "$path" > "$capture" 2>&1; then
    passed=$((passed+1))
    echo "PASS: ${g}"
  else
    failed=$((failed+1))
    echo "FAIL: ${g} (see ${capture})"
    failures="${failures}
FAIL: ${g} (exit non-zero; capture at ${capture})"
  fi
done
IFS=' '

echo "SUMMARY: m013-p02-phase-suite.sh pass=${passed} fail=${failed}"
[ "$failed" -eq 0 ] && { echo "PASS: m013-p02-phase-suite.sh"; exit 0; }
printf '%b\n' "$failures"
echo "FAIL: m013-p02-phase-suite.sh"
exit 1
```

### Step 10: Spot-check every gate is Bash 3.2 + AD-19 clean

The phase suite's bash32-compat gate self-checks every gate script. Ensure every `scripts/verify/m013-p02-*.sh` file this task authors:

- Uses `set -u`, never `set -euo pipefail` around loops that span gates (set -e causes loop iterations to abort on first failure; we want to accumulate).
- Uses no `declare -A`, no `mapfile`, no `<(...)`, no `&>`, no `${var^^}`.
- Every `bash` invocation in the gate scripts is a single-script-file shape.
- IFS manipulation follows the P01 suite pattern (reset to space after newline-split loops).

## Must-Haves

- Nine new files under `scripts/verify/`:
  - `m013-p02-github-common.sh` (≥40 lines, contains `orchestrator_id_for`)
  - `m013-p02-github-init-fixture.sh` (≥60 lines, contains `items`)
  - `m013-p02-github-init-preflight.sh` (≥40 lines, contains `integration-auth-failed`)
  - `m013-p02-dry-run-manifest.sh` (≥40 lines, contains `MANIFEST:`)
  - `m013-p02-github-init-command.sh` (≥25 lines, contains `Referenced Scripts`)
  - `m013-p02-reference-extensions.sh` (≥40 lines, contains `Auth Modes`)
  - `m013-p02-auto-mode-pending.sh` (≥30 lines, contains `pending-operator-complete`)
  - `m013-p02-bash32-compat.sh` (≥30 lines, contains `declare -A`)
  - `m013-p02-phase-suite.sh` (≥50 lines, contains `m013-p02`)
- All gate scripts Bash 3.2 compatible (`bash -n` green, no bash-4-only tokens).
- All gate scripts pass `scripts/verify/anti-pattern-lint.sh`.
- Phase-suite orchestrator exits 0 on all-green and non-zero on any-fail with a per-gate breakdown.

## Verification

```bash
bash scripts/verify/m013-p02-phase-suite.sh
```

Expected output on green:
```
PASS: m013-p02-github-common.sh
PASS: m013-p02-github-init-fixture.sh
PASS: m013-p02-github-init-preflight.sh
PASS: m013-p02-dry-run-manifest.sh
PASS: m013-p02-github-init-command.sh
PASS: m013-p02-reference-extensions.sh
PASS: m013-p02-auto-mode-pending.sh
PASS: m013-p02-bash32-compat.sh
SUMMARY: m013-p02-phase-suite.sh pass=8 fail=0
PASS: m013-p02-phase-suite.sh
```

Exit 0.

## Inputs

### From Previous Tasks

- `scripts/integrations/github-common.sh` (from T01, extended by T03) — the main gate target.
  - Key API asserted: `orchestrator_id_for`, `emit_marker`, `find_marker_in_body`, `shasum_marker_byte_identity`, `sidecar_*`, `manifest_*`.
- `scripts/integrations/github-init.sh` (from T02/T03) — main gate target.
  - Key API asserted: `--dry-run`, `--i-am-operator`, `--strict-labels`, exit codes 0/1/2/3.
- `commands/github-init.md` (from T04) — gate target for github-init-command.
- `references/github-integration.md` (extended by T05) — gate target for reference-extensions.
- `templates/github-integration-sidecar.json` (extended by T06) — gate target for auto-mode-pending.
- `tests/fixtures/m013-p02/` (from T01) — fixture tree for dry-run / preflight gates.

### From Disk (Pre-existing)

- `scripts/verify/m013-p01-phase-suite.sh` — precedent for phase-suite structure.
- `scripts/verify/m013-p01-bash32-compat.sh` — precedent for bash32-compat scan.
- `scripts/verify/anti-pattern-lint.sh` — M016/M021 invariant.

## Constraints

- **AD-19 `Check:` shape**: verify gates are single-script-file invocations. Gate internals are unconstrained Bash 3.2.
- **Bash 3.2 everywhere**: no `declare -A`, no `mapfile`/`readarray`, no `<(...)`/`>(...)`, no `&>`/`|&`, no `${var^^}`/`${var,,}`.
- **No `set -euo pipefail` around gate loops**: accumulator pattern requires continuing past individual gate failures.
- **No compound-chain `bash -c '... && ...'`**: gates invoke scripts directly.
- **Zero `gh` CLI dependency**: gates use `M013_GH_STUB_DIR` + fixture stub files. CI must pass without authenticated `gh`.
- **Per-gate capture files under `/tmp/m013-p02-<gate>.out`**: P01 precedent; each gate script routes via the phase-suite orchestrator.
- **Final self-named summary line**: `PASS: m013-p02-phase-suite.sh` (or `FAIL:`) — P01 convention; enables higher-level composite gates to grep for this exact string.
- **Idempotent**: running the suite multiple times produces identical output and exit code.
- **No orchestrator-state side effects**: the suite must not write to `.orchestrator/**` outside the `/tmp/m013-p02-t07-auto/` fixture roots.

## Expected Output

P02 phase closes with `scripts/verify/m013-p02-phase-suite.sh` exit 0, eight gates PASS. The phase-suite is suitable for composition into a higher-level milestone-close suite in P04 (e.g., `scripts/verify/m013-milestone-suite.sh` invokes p01-phase-suite + p02-phase-suite + p03-phase-suite + p04-phase-suite). That composition is a P04 task — T07 scopes to P02 only.
