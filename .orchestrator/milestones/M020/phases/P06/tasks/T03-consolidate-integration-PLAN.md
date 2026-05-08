---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P06"
milestone: "M020"
name: "Wire consolidate-artifacts.sh --cluster to preferences + emit effective_threshold="
depends_on: ["T01"]
---

## Prerequisites

- T01 has shipped: `scripts/knowledge/lib/preferences.sh` is sourceable and exposes `pref_resolve similarity_threshold` returning the effective threshold (project>user>built-in `0.7`).
- P05 has shipped: `scripts/knowledge/consolidate-artifacts.sh --cluster <orch-root> <milestone-id> [<knowledge-root>] [<threshold>]` invokes `cluster_compute` from `lib/cluster.sh`, computes connected components, emits `cluster_id=C<8-hex>` + indented `member=` blocks on stdout, and appends `consolidate_cluster` JSONL records via `dh_emit_jsonl`. The legacy two-positional invocation (no `--cluster`) is byte-equivalent (CON-4).
- M020 cross-cutting concern (FR-8 / CON-1): `consolidate-artifacts.sh --cluster` is read-only with respect to `knowledge/**` (mutations go through `graduate.sh`). The JSONL append to `${ORCH_ROOT}/execution-log.jsonl` is the only legitimate write — preserved unchanged.
- AD-19: every verifier's external invocation is a single `bash <script>` call.
- M020 ROADMAP P06 dependency edge: `P05 → P06` (clustering honors `similarity_threshold` from preferences).
- spec 025 SC-5: "Setting `similarity_threshold: 0.6` in a fixture project preferences file and `0.8` in the user preferences file, then invoking `orchestrator:consolidate --cluster`, produces clusters computed at threshold 0.6 (project wins). Assertion: stdout contains `effective_threshold=0.6`."

## Description

Extend `scripts/knowledge/consolidate-artifacts.sh` IN PLACE inside the existing `--cluster` short-circuit block (lines 29–172 in the current file). Two narrow edits:

**Edit 1 — preference-aware threshold resolution.** The current code unconditionally takes the threshold from positional arg or defaults to the literal `0.7`:

```bash
CLUSTER_THRESHOLD="${2:-0.7}"
```

This becomes a deferred resolution: if positional `$2` is set, use it (CLI wins); else call `pref_resolve similarity_threshold` from preferences.sh (project>user>built-in `0.7`). Add a `cluster_threshold_seen_on_cli` sentinel to track which path was taken, used by Edit 2 below for a precedence-aware diagnostic.

**Edit 2 — emit `effective_threshold=<N>` on stdout.** A single line, emitted ONCE, BEFORE the per-cluster output blocks (i.e. before the `while IFS=$'\t' read -r cid members_csv` loop that emits `cluster_id=...` + `member=...` lines). Format: `effective_threshold=<N>\n`. Always emitted when `--cluster` is invoked (covers SC-5 directly; gives the operator a single audit line; gives downstream tooling a deterministic anchor).

CON-4 byte-equivalence preservation:

- The existing P05 test suite (`tests/test-jaccard-clustering.sh`, 16 cases) currently invokes `consolidate-artifacts.sh --cluster` with explicit positional thresholds. After this edit, `effective_threshold=<N>` becomes a NEW stdout line emitted before the cluster blocks. The P05 test currently asserts via `grep "^cluster_id=C[0-9a-f]\{8\}$"` and counts cluster IDs — adding a non-matching `effective_threshold=` prefix line does NOT break those grep-based assertions. If a P05 test asserts a precise stdout-prefix shape (rare; verify by reading the test before editing), augment that test in the same task to tolerate the new prefix line.
- The existing legacy two-positional invocation (no `--cluster`) is untouched — those code paths are below the `--cluster` short-circuit's `exit 0` and are unreachable for `--cluster` invocations.
- The JSONL `threshold_used` field continues to use `$CLUSTER_THRESHOLD` (the resolved value), so the JSONL record reflects the effective threshold without any shape change.

## Steps

### Step 1: Edit `scripts/knowledge/consolidate-artifacts.sh` in place

Path: `/Users/brettkellgren/Sites/orchestrator/scripts/knowledge/consolidate-artifacts.sh`

Edit 1 — replace the current threshold resolution. Locate the existing code (around line 38-40):

```bash
  # Optional positionals: knowledge-root, threshold.
  CLUSTER_KNOWLEDGE_ROOT="${1:-}"
  CLUSTER_THRESHOLD="${2:-0.7}"
```

Replace with:

```bash
  # Optional positionals: knowledge-root, threshold.
  CLUSTER_KNOWLEDGE_ROOT="${1:-}"
  if [ "$#" -ge 2 ] && [ -n "${2:-}" ]; then
    CLUSTER_THRESHOLD="$2"
    cluster_threshold_seen_on_cli=1
  else
    CLUSTER_THRESHOLD=""
    cluster_threshold_seen_on_cli=0
  fi
```

Edit 2 — source `lib/preferences.sh` adjacent to the existing `lib/*.sh` source lines. Locate (around line 56-63):

```bash
  # Source helpers from this phase.
  CLUSTER_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"
  # shellcheck source=lib/cluster.sh
  . "$CLUSTER_LIB_DIR/cluster.sh"
  # shellcheck source=lib/decision-history.sh
  . "$CLUSTER_LIB_DIR/decision-history.sh"
  # shellcheck source=lib/frontmatter.sh
  . "$CLUSTER_LIB_DIR/frontmatter.sh"
```

Insert the preferences source line after `frontmatter.sh`:

```bash
  # shellcheck source=lib/preferences.sh
  . "$CLUSTER_LIB_DIR/preferences.sh"
```

Edit 3 — resolve the threshold via `pref_resolve` when not on CLI. Insert immediately AFTER the four source lines and BEFORE the existing `# Export ORCH_ROOT for dh_emit_jsonl ...` comment (around line 65):

```bash
  # FR-6 / P06: deferred similarity_threshold resolution.
  # CLI > project preferences > user preferences > built-in default 0.7.
  if [ "${cluster_threshold_seen_on_cli:-0}" = "0" ] || [ -z "$CLUSTER_THRESHOLD" ]; then
    resolved_threshold="$(pref_resolve similarity_threshold 2>/dev/null || true)"
    if [ -n "$resolved_threshold" ]; then
      CLUSTER_THRESHOLD="$resolved_threshold"
    else
      CLUSTER_THRESHOLD="0.7"
    fi
  fi
```

Edit 4 — emit `effective_threshold=<N>` on stdout BEFORE the per-cluster output blocks. Locate the start of the output-emission loop (around line 100-102):

```bash
  # Walk the cluster summary, emit per-cluster output + JSONL.
  while IFS=$'\t' read -r cid members_csv; do
```

Insert IMMEDIATELY BEFORE this `while` loop, AFTER the `awk` group-by block that builds `$CLUSTER_TMP`:

```bash
  # FR-6 / SC-5: emit the resolved threshold once, before the per-cluster blocks.
  printf 'effective_threshold=%s\n' "$CLUSTER_THRESHOLD"
```

This is the SC-5 audit line. It is emitted on EVERY `--cluster` invocation — whether the threshold came from CLI, project, user, or default — making the resolved value visible to operators and downstream tooling.

### Step 2: Create `scripts/verify/m020-p06-consolidate-effective-threshold.sh`

Verifier asserts the SC-5 contract end-to-end:

- Set up tempdir fixtures (HOME, PROJECT_ROOT, knowledge tree, ORCH_ROOT).
- Populate the knowledge tree with at least 3 candidate entries (so `cluster_compute` produces ≥1 cluster — singletons are fine).
- Case A: write `<project-tempdir>/.orchestrator/preferences.yml` with `similarity_threshold: 0.6` and `<user-tempdir>/.orchestrator/preferences.yml` with `similarity_threshold: 0.8`. Run `bash scripts/knowledge/consolidate-artifacts.sh --cluster <ORCH_ROOT> MTEST <KNOWLEDGE_ROOT>` (no positional threshold). Assert stdout contains exactly one `effective_threshold=0.6` line, and that line appears BEFORE any `cluster_id=` line.
- Case B: remove the project file. Run the same command. Assert stdout contains `effective_threshold=0.8`.
- Case C: remove the user file too. Run the same command. Assert stdout contains `effective_threshold=0.7`.
- Case D: with no preferences files, run with positional threshold `0.5`: `bash scripts/knowledge/consolidate-artifacts.sh --cluster <ORCH_ROOT> MTEST <KNOWLEDGE_ROOT> 0.5`. Assert stdout contains `effective_threshold=0.5`.
- Case E (line-ordering invariant): for the Case A invocation, assert the `effective_threshold=` line appears before the first `cluster_id=` line via a single `awk` block reading stdout.

Use `pass()`/`fail()` parallel-scalar pattern (MEM002). Tempdir + trap cleanup. Capture stdout to a file in the tempdir; grep against the file.

### Step 3: Create `scripts/verify/m020-p06-consolidate-cli-precedence.sh`

Verifier asserts CLI > preferences precedence + CON-4 byte-equivalence preservation for the legacy explicit-threshold invocation:

- Set up tempdir fixtures.
- Write a project preferences file with `similarity_threshold: 0.3` and a user preferences file with `similarity_threshold: 0.4`.
- Run `bash scripts/knowledge/consolidate-artifacts.sh --cluster <ORCH_ROOT> MTEST <KNOWLEDGE_ROOT> 0.9`. Assert stdout contains `effective_threshold=0.9` (CLI wins over both preference files).
- Assert the JSONL record at `<ORCH_ROOT>/execution-log.jsonl` carries `threshold_used=0.9` (matches the resolved threshold).
- Assert the project + user preferences files md5 unchanged (read-only invariant).
- Run an additional sanity case: no preferences files, no positional threshold. Assert stdout contains `effective_threshold=0.7` (built-in default).

Use `pass()`/`fail()` parallel-scalar pattern (MEM002). Tempdir + trap cleanup.

## Must-Haves

This task addresses the following P06 must-haves:

- Truth: `consolidate-artifacts.sh --cluster` resolves threshold from preferences when no positional threshold; emits `effective_threshold=<N>` line BEFORE per-cluster blocks (Check: `m020-p06-consolidate-effective-threshold.sh`).
- Truth: legacy invocation (no preferences file, explicit positional threshold) preserves byte-equivalent observable behavior; CLI wins over preferences (Check: `m020-p06-consolidate-cli-precedence.sh`).
- Artifact: `scripts/knowledge/consolidate-artifacts.sh` (min 290 lines, contains `effective_threshold=`).
- Artifact: `scripts/verify/m020-p06-consolidate-effective-threshold.sh`.
- Artifact: `scripts/verify/m020-p06-consolidate-cli-precedence.sh`.
- Key Link: `consolidate-artifacts.sh → lib/preferences.sh` (source line + named comment).

## Verification

```bash
bash scripts/verify/m020-p06-consolidate-effective-threshold.sh
bash scripts/verify/m020-p06-consolidate-cli-precedence.sh
bash tests/test-jaccard-clustering.sh
```

The third command is the CON-4 byte-equivalence regression gate: P05's existing 16-case integration test must remain green after this in-place edit. If any P05 assertion is shape-fragile against the new `effective_threshold=` prefix line, augment that test in this same task to tolerate the new line (the augmentation is bounded to test-side tolerance, not a contract change). Each script exits 0. AD-19 compliant.

## Inputs

### From Previous Tasks

- `scripts/knowledge/lib/preferences.sh` (from T01 of this phase)
  - Key API: `pref_resolve <key>` echoes the effective scalar value of `<key>` on stdout, applying project>user>built-in-default precedence. For `similarity_threshold`, returns a float in `[0.0, 1.0]`; built-in default `0.7`.
  - Key types: pure shell helper, sourceable, double-source-guarded with `_PREFERENCES_HELPER_SOURCED` sentinel.
  - Behavioral contract: read-only — never writes to any file. Honors `PROJECT_ROOT` and `HOME` env vars for fixture isolation. Falls back to built-in default with stderr diagnostic on malformed values.

### From Disk (Pre-existing)

- `scripts/knowledge/consolidate-artifacts.sh` (P05) — the file being edited in place. Existing `--cluster` short-circuit block at lines 29–172. Existing JSONL emission via `dh_emit_jsonl consolidate_cluster ...` carries `threshold_used=$CLUSTER_THRESHOLD`.
- `scripts/knowledge/lib/cluster.sh` (P05) — exposes `cluster_compute <root> <threshold>`. Sourced by consolidate-artifacts.sh; not modified by this task.
- `scripts/knowledge/lib/decision-history.sh` (P03) — exposes `dh_emit_jsonl`. Sourced by consolidate-artifacts.sh; not modified.
- `scripts/knowledge/lib/frontmatter.sh` (P01) — sourced by consolidate-artifacts.sh; not modified.
- `tests/test-jaccard-clustering.sh` (P05) — the regression gate that proves CON-4 surface preservation after the in-place edit.

## Constraints

- **CON-4 (byte-equivalent surface preservation)**: every existing CLI shape (`<orch> <milestone>` legacy and `--cluster <orch> <milestone> [<knowledge-root>] [<threshold>]`), JSONL record shape, and exit code MUST remain unchanged. The new `effective_threshold=` line is an ADDITIVE stdout emission; existing P05 test assertions over `cluster_id=` and `member=` lines remain green because they do not assert exact stdout prefix.
- **CON-1 / FR-8 (read-only with respect to knowledge/**)**: this task introduces no writes to `knowledge/**`. The single legitimate write — JSONL append to `${ORCH_ROOT}/execution-log.jsonl` — is preserved unchanged.
- **AD-19 (single-script-invocation shape)**: each verifier is invoked externally as `bash <script>`.
- **MEM002 (test conventions)**: verifiers use tempdir + trap cleanup; `HOME`, `PROJECT_ROOT`, and `ORCH_ROOT` set to fresh tempdirs (no live filesystem access).
- **MEM001 (Bash 3.2)**: no `declare -A` in any new code.
- **Plan-deviation invariant (P04)**: this task's Verification section names ONLY verifiers authored by this task plus the P05 test (which already exists). No future-task verifiers referenced.
- **THREAT-006 (cluster staleness mitigation)**: this task does NOT change clustering semantics — `cluster_compute` is invoked unchanged; only the threshold INPUT is now preference-aware. No staleness regression introduced.

## Expected Output

```
$ bash scripts/verify/m020-p06-consolidate-effective-threshold.sh
PASS: case A project=0.6 user=0.8 -> effective_threshold=0.6
PASS: case A effective_threshold= line precedes first cluster_id= line
PASS: case B user-only=0.8 -> effective_threshold=0.8
PASS: case C no-pref -> effective_threshold=0.7
PASS: case D CLI=0.5 (no pref) -> effective_threshold=0.5
RESULT: 5/5 PASS
exit 0

$ bash scripts/verify/m020-p06-consolidate-cli-precedence.sh
PASS: CLI=0.9 with project=0.3 user=0.4 -> effective_threshold=0.9
PASS: JSONL threshold_used=0.9 matches CLI value
PASS: project preferences file md5 unchanged
PASS: user preferences file md5 unchanged
PASS: no-pref no-CLI -> effective_threshold=0.7
RESULT: 5/5 PASS
exit 0

$ bash tests/test-jaccard-clustering.sh
... (existing P05 assertions, all pass)
RESULT: 16/16 PASS
exit 0
```
