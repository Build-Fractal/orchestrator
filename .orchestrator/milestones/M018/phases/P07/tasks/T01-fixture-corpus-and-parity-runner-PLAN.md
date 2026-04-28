---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P07"
milestone: "M018"
name: "Fixture corpus + zero-LLM parity runner — filter + T1 + T2 byte-equality across CC / Codex CLI / Cursor simulated runtimes"
depends_on: []
---

## Prerequisites

- The bash-only tier helpers exist and are stable from prior phases:
  - `_bc_apply_filter` at `scripts/dispatch/build-context.sh` (P02) — knowledge-aware filter; honors `compression.knowledge_filter.drop_list`.
  - `_bc_apply_tier1` at `scripts/dispatch/build-context.sh:614` (P03) — tool-result paging + SHA-256 cache reuse; reads `compression.tier1.tool_result_budget_bytes` and persists to `.orchestrator/cache/tool-results/<sha256>.txt`.
  - `_bc_apply_tier2` at `scripts/dispatch/build-context.sh:823` (P04) — section head-drop with `compression.tier2.protected_tail_ratio`; refuses to cross preserved-pattern boundaries.
- `scripts/lib/knowledge-filter.sh` `kf_get_*` accessors (P02/P03/P04/P06) read config keys from `.orchestrator/config.yml` resolved via `ORCHESTRATOR_ROOT` (`scripts/state/resolve-root.sh`).
- `scripts/util/dual-write-runtime-md.sh` exists; T01 does NOT invoke it (T03 closes the dual-write).
- `scripts/verify/_helpers/m018-p06-build-fixture.sh` (P06/T04) is the canonical fixture-staging helper shape T01's helper mirrors. Read it once for shape (config-override scaffolding, fixture path resolution under `$TMPDIR_BUILD/_p07_fixture/<slug>/`) before authoring `m018-p07-build-fixture.sh`.
- AP-009 / AD-19: no compound chains > 2; no inline `$(...)` containing pipes; no plain subshells; no process substitution. SHA-256 over a generated payload is computed by writing the payload to a temp file first, then invoking `shasum -a 256 <file>` as a single command, then awk-reading the hash from stdout. Bash 3.2.

## Description

T01 ships **one fixture corpus tree** and **one zero-LLM parity runner** that proves filter + T1 + T2 produce byte-identical compressed payloads across three simulated runtime environments (`ORCH_BACKEND` ∈ {`claude-code`, `codex`, `cursor`}).

Specifically, T01 ships:

1. **`tests/compression-runtime-parity/`** corpus tree with three fixtures (one per zero-LLM tier):
   - `fixtures/filter-mixed-status/` — knowledge tree with mixed `status:` field values (graduated / experimental / superseded) so the filter has work to do.
   - `fixtures/tier1-oversized-tool-result/` — a payload-input file containing an oversized tool-result block past the configured T1 budget.
   - `fixtures/tier2-oversized-section/` — a payload-input file containing an oversized section body past the configured T2 budget.
   - Each fixture carries its own minimal `config.yml` (compression knobs only — `compression.enabled: true`; per-tier knobs sized so the tier under test fires) and an `input/` subdirectory with the bytes the parity runner feeds into `build-context.sh`.
2. **`tests/compression-runtime-parity/README.md`** documenting the corpus, the SHA-256 byte-equality contract, and how to add a new fixture.
3. **`scripts/diagnostics/m018-runtime-parity.sh`** — the parity runner. Single-script-file shape. CLI:

   ```
   m018-runtime-parity.sh [--corpus-dir <path>] [--fixture <name>] [--runtimes <csv>]
   ```

   Defaults: `--corpus-dir tests/compression-runtime-parity`, `--fixture all`, `--runtimes claude-code,codex,cursor`. For each fixture × runtime pair: stages a hermetic `ORCHESTRATOR_ROOT` via the helper, exports `ORCH_BACKEND=<runtime>`, invokes `bash scripts/dispatch/build-context.sh` with the fixture's input bytes, captures the post-T2 payload to a fixture-local temp file, computes SHA-256, prints a `runtime-parity` line per (fixture, runtime, sha256) triple, and emits a `runtime_parity` JSONL record to the staged fixture's `execution-log.jsonl`. After all (fixture, runtime) pairs run, asserts that the three SHA-256 values per fixture match. Always exits 0 (advisory pattern; FAIL surfaces via `regression_flag:` advisory line read by the T03 verifier).
4. **`scripts/verify/_helpers/m018-p07-build-fixture.sh`** — fixture-staging helper. Mirrors `m018-p06-build-fixture.sh` shape. Takes one argument (the fixture name from `tests/compression-runtime-parity/fixtures/<name>/`) and prints the staged hermetic root on stdout. Idempotent (clean-stage on re-invocation). Bash 3.2.

T01 does NOT ship:

- Tier 3 routing parity (T02).
- Verifiers (T03 — except the bash-n self-check on the parity runner that serves as T01's task-local Check).
- RUNTIME-ASSUMPTIONS.md (T03).
- P07-SUMMARY.md or dual-write (T03).

## Steps

### Step 1 — Author `scripts/verify/_helpers/m018-p07-build-fixture.sh`

Mirror P06/T04 helper. Job: stage a hermetic `ORCHESTRATOR_ROOT`-style root at `$TMPDIR/_p07_fixture/<runtime>-<fixture>/` containing:

- `.orchestrator/config.yml` — copied from `tests/compression-runtime-parity/fixtures/<fixture>/config.yml`.
- `knowledge/` — copied from `tests/compression-runtime-parity/fixtures/<fixture>/knowledge/` if present (filter fixture has this; T1 / T2 fixtures may have empty knowledge tree).
- `.orchestrator/milestones/M-FIXTURE/` — minimal milestone scaffolding (a `M-FIXTURE-ROADMAP.md`, an empty `execution-log.jsonl`).
- `input/payload-input.txt` — copied from `tests/compression-runtime-parity/fixtures/<fixture>/input/payload-input.txt`.

Helper takes two positional args: `<runtime>` `<fixture>`. Prints the staged root path on stdout. Idempotent — `rm -rf` the existing staged root before re-staging.

Pseudo-shape (single-script-file; no compound > 2; no `$(... | ...)`):

```bash
#!/usr/bin/env bash
# scripts/verify/_helpers/m018-p07-build-fixture.sh
# M018/P07/T01 — Stage a hermetic fixture root for runtime-parity assertions.
# Usage: bash _helpers/m018-p07-build-fixture.sh <runtime> <fixture-name>
set -u
RUNTIME="${1:?runtime required}"
FIXTURE="${2:?fixture name required}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CORPUS="$PROJECT_ROOT/tests/compression-runtime-parity/fixtures/$FIXTURE"
if [ ! -d "$CORPUS" ]; then
  printf 'FAIL: fixture not found: %s\n' "$CORPUS" >&2
  exit 1
fi
STAGE="${TMPDIR:-/tmp}/_p07_fixture/${RUNTIME}-${FIXTURE}"
rm -rf "$STAGE"
mkdir -p "$STAGE/.orchestrator/milestones/M-FIXTURE"
mkdir -p "$STAGE/input"
# Stage config + knowledge + input
cp "$CORPUS/config.yml" "$STAGE/.orchestrator/config.yml"
if [ -d "$CORPUS/knowledge" ]; then
  cp -R "$CORPUS/knowledge" "$STAGE/knowledge"
fi
cp "$CORPUS/input/payload-input.txt" "$STAGE/input/payload-input.txt"
: > "$STAGE/.orchestrator/milestones/M-FIXTURE/execution-log.jsonl"
# Minimal roadmap so derive-phase / read-config find a milestone
printf -- '---\nschema_version: "1.0"\ntype: roadmap\nmilestone: "M-FIXTURE"\n---\n' \
  > "$STAGE/.orchestrator/milestones/M-FIXTURE/M-FIXTURE-ROADMAP.md"
printf '%s\n' "$STAGE"
```

### Step 2 — Author `tests/compression-runtime-parity/fixtures/filter-mixed-status/`

Create directory tree:

```
fixtures/filter-mixed-status/
  config.yml          # compression.enabled: true; knowledge_filter.drop_list: ["superseded","experimental"]
  knowledge/
    conventions/
      MEM-FXT-A.md   # status: graduated  (kept)
      MEM-FXT-B.md   # status: experimental (dropped)
    patterns/
      MEM-FXT-C.md   # status: superseded (dropped)
      MEM-FXT-D.md   # status: graduated  (kept)
  input/
    payload-input.txt  # canonical payload-input shape build-context expects
  README.md           # what this fixture exercises
```

Each MEM-FXT-* entry is a minimal valid knowledge entry (frontmatter with `id:`, `status:`, `category:`, `confidence:`, `created_at:`, `last_verified:`, `hit_count:`, `source_unit:`, `source_type:`, `supersedes:`, `superseded_by:`, `relates_to:`, `content_hash:`) plus a one-line body. The filter contract (US-2 / FR-3) drops entries with `status: superseded` or `status: experimental` from the Knowledge section.

`config.yml` minimum content (Bash 3.2-friendly grep/sed parsing per MEM001):

```yaml
compression:
  enabled: true
  knowledge_filter:
    drop_list: ["superseded", "experimental"]
  tier1:
    enabled: false
  tier2:
    enabled: false
  tier3:
    enabled: false
```

Disabling tier1/tier2/tier3 isolates the filter as the only mutating stage so byte-equality across runtimes is provable on filter alone.

### Step 3 — Author `tests/compression-runtime-parity/fixtures/tier1-oversized-tool-result/`

Create directory tree:

```
fixtures/tier1-oversized-tool-result/
  config.yml          # compression.enabled: true; tier1.enabled: true; tier1.tool_result_budget_bytes: 4096
  input/
    payload-input.txt # canonical payload with one inline tool-result block sized at ~12 KB
  README.md
```

`config.yml` enables T1 only (filter / T2 / T3 disabled). The `payload-input.txt` carries one tool-result block with body size ~12 KB so T1's 4 KB budget triggers paging. The post-T1 output replaces the inline block with a `<tool-result file="..." preview-bytes="200">…</tool-result>` reference and persists the original to `<staged-root>/.orchestrator/cache/tool-results/<sha256>.txt`. The byte-equality assertion is on the post-pipeline payload bytes including the file-path reference (which is computed from a SHA-256 over the tool-call command + input — runtime-agnostic).

### Step 4 — Author `tests/compression-runtime-parity/fixtures/tier2-oversized-section/`

Create directory tree:

```
fixtures/tier2-oversized-section/
  config.yml          # compression.enabled: true; tier2.enabled: true; tier2.section_budget tuned to fire snip
  input/
    payload-input.txt # canonical payload with one ~30 KB Upstream Context section
  README.md
```

`config.yml` enables T2 only. The `payload-input.txt` carries a single ~30 KB Upstream Context section. T2's head-drop reduces it to budget while preserving the configured tail ratio; emits the in-band `<!-- compressed:tier2 head-dropped=N bytes -->` marker. Byte-equality across runtimes is provable because the snip is rule-based, not LLM-based.

### Step 5 — Author `tests/compression-runtime-parity/fixtures/tier3-oversized-section/`

Create directory tree:

```
fixtures/tier3-oversized-section/
  config.yml          # compression.enabled: true; tier3.enabled: true; tier3.section_budget tuned to fire T3
  input/
    payload-input.txt # canonical payload with one ~25 KB Knowledge section that survives T1+T2
  README.md
```

This fixture is **consumed by T02** (Tier 3 routing parity), not by T01's zero-LLM runner. T01 stages the directory but does not exercise it. Documenting it here keeps the corpus shape complete and authored in one place; T02's runner reads from the same tree.

### Step 6 — Author `tests/compression-runtime-parity/README.md`

Document:

1. **Purpose**: byte-equality proof that bash-only compression tiers (filter, T1, T2) produce identical compressed payloads under every supported runtime (`claude-code`, `codex`, `cursor`); routing proof that T3 dispatches through `dispatch-interface.sh` correctly under every runtime.
2. **Corpus structure**: `fixtures/<name>/{config.yml, knowledge/, input/payload-input.txt, README.md}` — each fixture isolates one tier under test.
3. **How to add a fixture**: copy an existing fixture; tune `config.yml`; rewrite `input/payload-input.txt`; add a `README.md` naming what it exercises.
4. **Byte-equality contract**: the parity runner asserts `sha256(post-pipeline payload bytes)` is identical across all runtimes per fixture. Any divergence is either a bug to fix or a row to document in `references/RUNTIME-ASSUMPTIONS.md`.
5. **Stub usage** (forward reference to T02): the `_stubs/tier3-stub-llm.sh` deterministic stub fronts `tier3-llm-call.sh` via `ORCH_TIER3_LLM_BIN` so T3 invocations are byte-deterministic across runtimes.

Min 20 lines; must contain the literal substring "byte-identical".

### Step 7 — Author `scripts/diagnostics/m018-runtime-parity.sh`

Single-script-file. Bash 3.2. AP-009-clean. Outline:

```bash
#!/usr/bin/env bash
# scripts/diagnostics/m018-runtime-parity.sh
# M018/P07/T01 — Zero-LLM parity runner.
#
# For each fixture in tests/compression-runtime-parity/fixtures/, stage a
# hermetic root under each runtime (claude-code|codex|cursor), invoke
# build-context.sh, capture the post-pipeline payload, compute SHA-256
# over the bytes, and assert the three runtimes' hashes match.
#
# Always exits 0 (FR-12 advisory pattern). Per-fixture FAIL surfaces via
# 'regression_flag: divergence' line read by the T03 verifier.

set -u
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER="$PROJECT_ROOT/scripts/verify/_helpers/m018-p07-build-fixture.sh"
CORPUS_DIR="$PROJECT_ROOT/tests/compression-runtime-parity/fixtures"
FIXTURE_FILTER="all"
RUNTIMES="claude-code,codex,cursor"

# CLI parsing (case ladder; no compound chains > 2)
while [ $# -gt 0 ]; do
  case "$1" in
    --corpus-dir) CORPUS_DIR="$2"; shift 2 ;;
    --fixture)    FIXTURE_FILTER="$2"; shift 2 ;;
    --runtimes)   RUNTIMES="$2"; shift 2 ;;
    *)            shift ;;
  esac
done

# For each fixture, for each runtime: stage; invoke; capture; hash; compare.
# (Skip the tier3-oversized-section fixture in T01 — that's T02's job.)
# Print: 'runtime-parity fixture=<name> runtime=<name> sha256=<hash>'
# Per-fixture summary: 'parity fixture=<name> result=<match|divergence> runtimes=<n>'
# Always exit 0.
```

Detailed contract:

- For each fixture name (excluding `tier3-oversized-section` — T02's fixture):
  - For each runtime in `$RUNTIMES`:
    - Stage root via `bash "$HELPER" "$runtime" "$fixture"` → stdout is the staged root path.
    - Export `ORCH_BACKEND=$runtime`, `ORCHESTRATOR_ROOT=<staged-root>`.
    - Invoke `bash "$PROJECT_ROOT/scripts/dispatch/build-context.sh" --task-plan <staged-root>/input/payload-input.txt --milestone M-FIXTURE > <staged-root>/output/payload.txt 2>/dev/null`. (If build-context's CLI requires different flags, T01 author reads `scripts/dispatch/build-context.sh --help` once and matches the actual surface; the contract is "feed the fixture in; capture the post-pipeline payload out".)
    - Compute SHA-256 over the captured payload: `shasum -a 256 <staged-root>/output/payload.txt > <staged-root>/output/payload.sha256` then awk-extract field 1.
    - Print `runtime-parity fixture=<name> runtime=<runtime> sha256=<hash>`.
    - Append a `runtime_parity` JSONL record to `<staged-root>/.orchestrator/milestones/M-FIXTURE/execution-log.jsonl`: `{"record_type":"runtime_parity","fixture":"<name>","runtime":"<runtime>","sha256":"<hash>","timestamp":"<iso8601>"}`.
  - After all runtimes for this fixture: compare the three hashes. Print `parity fixture=<name> result=match runtimes=3` if all match, else `parity fixture=<name> result=divergence runtimes=3 diffs=<list>`.
- Final line: `regression_flag: <none|divergence>` (none if every fixture matched; divergence otherwise).
- Always exit 0.

MEM004 carve-out applies inside the runner body — single-pass awk + pipes permitted INSIDE the runner script. The AD-19 single-script-file shape rule applies only to the Check: line at task / phase plan level.

### Step 8 — Run the parity runner end-to-end against the corpus

```bash
bash scripts/diagnostics/m018-runtime-parity.sh --runtimes claude-code,codex,cursor --fixture all
```

Expected stdout (example):

```
runtime-parity fixture=filter-mixed-status runtime=claude-code sha256=abc...
runtime-parity fixture=filter-mixed-status runtime=codex sha256=abc...
runtime-parity fixture=filter-mixed-status runtime=cursor sha256=abc...
parity fixture=filter-mixed-status result=match runtimes=3
runtime-parity fixture=tier1-oversized-tool-result runtime=claude-code sha256=def...
[...]
parity fixture=tier2-oversized-section result=match runtimes=3
regression_flag: none
```

Exit 0. If a fixture produces divergent hashes, the run still exits 0 but the `parity ... result=divergence` line names the fixture; T03's verifier asserts on the runner's stdout.

### Step 9 — Bash-n self-check (T01 task-local Check)

```bash
bash -n scripts/diagnostics/m018-runtime-parity.sh
bash -n scripts/verify/_helpers/m018-p07-build-fixture.sh
```

Both exit 0.

## Verification

T01's task-local extractable Check is the syntax-only self-check on the parity runner:

- Check: `bash -n scripts/diagnostics/m018-runtime-parity.sh`

(One Check per task per the auto-loop verify parser. The canonical truth verifier — `m018-p07-zero-llm-parity.sh` — ships in T03 and exercises the runner end-to-end.)

## Inputs

### From Previous Tasks

(none — T01 is the entry task in the T01/T02 fan-in, both depend on P06's surface only)

### From Disk (Pre-existing)

- `scripts/dispatch/build-context.sh` — bash-only tier helpers (`_bc_apply_filter`, `_bc_apply_tier1`, `_bc_apply_tier2`) that the parity runner exercises end-to-end. Reads its own `--task-plan` / `--milestone` / `--intensity-metadata` CLI flags; T01 author reads the actual flag set once at integration time.
- `scripts/lib/knowledge-filter.sh` — `kf_get_*` accessors that read config keys from the staged `config.yml`.
- `scripts/state/resolve-root.sh` — 4-rule state root resolver that build-context.sh uses to find the staged fixture root via `ORCHESTRATOR_ROOT`.
- `scripts/verify/_helpers/m018-p06-build-fixture.sh` — canonical fixture-staging helper shape T01's helper mirrors.
- `tests/fixtures/m018-p06-tier3-fired-log/execution-log.jsonl` — JSONL-record-mix shape T01's `runtime_parity` record schema mirrors.

## Constraints

- **AD-19 / AP-009**: no compound chains > 2; no inline `$(...)` containing pipes; no plain subshells; no process substitution. SHA-256 is computed by writing to a temp file, invoking `shasum -a 256 <file>`, and awk-reading the hash.
- **CON-1 / Constitution Principle VI**: T01 modifies no production code. New files only under `scripts/diagnostics/`, `scripts/verify/_helpers/`, and `tests/compression-runtime-parity/`. Pre-M018 sentinel byte-identity is preserved.
- **CON-5 (additive emitters)**: the new `runtime_parity` JSONL record_type is additive; pre-M018 readers ignore unknown record_type values; no existing record schemas change.
- **Bash 3.2** (MEM001): no `declare -A`, no process substitution, no merged stdout-stderr shorthand. Parallel scalars / indexed arrays only.
- **Hermetic fixtures**: every parity invocation uses `ORCHESTRATOR_ROOT=<staged-root>`. No write to canonical `.orchestrator/` during the runner.
- **Always-exit-0 advisory pattern**: the runner always exits 0 even on divergence; FAIL surfaces via the `regression_flag:` line.

## Expected Output

After T01 lands:

- `tests/compression-runtime-parity/` corpus tree exists with four fixture directories (filter / tier1 / tier2 / tier3) and a `README.md`.
- `scripts/diagnostics/m018-runtime-parity.sh` exists and `bash -n` clean.
- `scripts/verify/_helpers/m018-p07-build-fixture.sh` exists and `bash -n` clean.
- `bash scripts/diagnostics/m018-runtime-parity.sh --runtimes claude-code,codex,cursor --fixture all` runs end-to-end, prints per-fixture parity lines and a `regression_flag: <none|divergence>` summary, and exits 0.
- All three filter / tier1 / tier2 fixtures report `parity ... result=match runtimes=3` on a clean checkout (the bash-only tiers ARE byte-identical because they're bash code that ignores `ORCH_BACKEND`); if a fixture diverges, T01 author files an issue and T03 documents the divergence in RUNTIME-ASSUMPTIONS.md.
