---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P03"
milestone: "M027"
name: "config-drift helper + commands/doctor.md integration + fixture suite (scripts/diagnostics/check-config-drift.sh)"
depends_on: ["T01"]
---

## Prerequisites

- T01 has shipped `scripts/diagnostics/check-anomalies.sh` (≥ 120 lines, executable, sourceable). CLI accepts `--milestone`, `--project`, `--no-anomaly`, `--yes`, `--threshold`, `--sample-floor`, `--config-defaults`, `--help`. Title: `Anomaly Detection (Tier 1 baseline)`. Suppressed mode emits zero stdout.
- T01 has added `anomaly_cost_multiplier`, `anomaly_retry_threshold`, `anomaly_pass_rate_threshold`, `anomaly_check_enabled` to `VALID_KEYS` in `scripts/state/read-config.sh`. Combined with M027/P02/T01's additions, the full M027 knob set is now seven keys: `efficiency_footer`, `predictive_cost_surface`, `anomaly_cost_multiplier`, `anomaly_retry_threshold`, `anomaly_pass_rate_threshold`, `anomaly_check_enabled` (six new) plus the original spec key `default_tier` (preexisting).
- `scripts/state/read-config.sh` exists and resolves config keys from a 4-layer precedence chain (env / local / project / defaults). Returns the resolved value to stdout; returns empty stdout / non-zero exit for unset keys.
- `commands/doctor.md` exists in its pre-T02 form (~50 lines today; will grow to ≥ 100 lines after this task's edits). Contains canonical sections: `# orchestrator:doctor` heading, `## What It Checks`, `## Runtime Instruction Drift`, `## Usage`, `## Output`, `## When to Run`, `## Referenced Scripts`. The two new sections (`## Anomaly Detection`, `## Config Drift`) insert between `## Runtime Instruction Drift` and `## Usage`.
- bash 3.2 / POSIX sh discipline (CON-7, MEM001).
- AD-19 single-script-file `Check:` shape: this task ships its own scoped precheck `scripts/verify/m027-p03-t02-shape-precheck.sh`.

## Description

Create three artifacts:

1. **`scripts/diagnostics/check-config-drift.sh`** — sourceable bash 3.2 library + CLI for the config-drift helper backing `orchestrator:doctor --config-check` (FR-16). Renders a one-block drift report (≤ 4 lines per audited key) listing the resolved value per layer (`env=`, `local=`, `project=`, `defaults=`) plus a final `effective=` line per key. Default `--keys` value audits the seven M027 knobs.
2. **`commands/doctor.md` integration** — insert two new sections (`## Anomaly Detection` and `## Config Drift`) at the documented attach point (between `## Runtime Instruction Drift` and `## Usage`). Pre-edit canonical sections preserved in pre-edit order; the two new sections are the ONLY structural additions plus two new bullets under `## Referenced Scripts`. Document the helper invocation, the 5-condition suppression matrix, the sample-floor semantics, and the #Q-10 baseline-disclaimer text verbatim.
3. **Baseline fixture + anomaly fixture** under `tests/fixtures/m027-p03/` — `doctor-suppressed-baseline.txt` captures the verbatim post-`## Referenced Scripts` tail of `commands/doctor.md` (the document tail must stay byte-stable across the new sections being added; T04's byte-identity verifier diffs the live tail against this fixture). `anomaly-fixture.jsonl` is a hand-crafted 9-record `unit_close` JSONL log containing exactly one ≥ 3× cost outlier among 8 sibling dispatches, used by T04's Goodhart-pairing verifier as a deterministic test target. `README.md` documents the fixture roles and update protocol.

## Steps

1. **Create `scripts/diagnostics/check-config-drift.sh`** (~110 lines, bash 3.2 compat):

   ```bash
   #!/usr/bin/env bash
   # scripts/diagnostics/check-config-drift.sh — M027/P03/T02 config-drift helper.
   #
   # Sourceable as a library (function check_config_drift_render) AND runnable as a CLI.
   # CLI emits a one-block drift report (<=4 lines per audited key) titled
   # "Config Drift (M027 knobs)" listing the resolved value at each precedence
   # layer (env / local / project / defaults) plus a final effective= line per key.
   # Backs orchestrator:doctor --config-check per FR-16.
   #
   # Read-only (FR-12/CON-1): never writes to execution-log.jsonl or config.
   # Zero-LLM-token (FR-21/CON-6): bash + invocation of read-config.sh only.
   # Bash 3.2 (CON-7): parallel scalars only; no associative arrays; no herestring redirect.

   set -u

   if [ -n "${_CHECK_CONFIG_DRIFT_SH_SOURCED:-}" ]; then
     return 0 2>/dev/null || true
   fi
   _CHECK_CONFIG_DRIFT_SH_SOURCED=1

   _CCD_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   _CCD_PROJECT_ROOT="$(cd "$_CCD_SCRIPT_DIR/../.." && pwd)"

   _CCD_DEFAULT_KEYS="efficiency_footer predictive_cost_surface anomaly_cost_multiplier anomaly_retry_threshold anomaly_pass_rate_threshold anomaly_check_enabled"

   # check_config_drift_render <space-separated-keys>
   #   For each key, queries each precedence layer's resolved value and emits
   #   env=<v> local=<v> project=<v> defaults=<v> effective=<v>.
   #   Always returns exit 0 (never aborts).
   check_config_drift_render() {
     local keys="$1"
     printf '%s\n' "Config Drift (M027 knobs)"
     local key env_val effective_val
     for key in $keys; do
       printf '  key=%s\n' "$key"
       # Env-var layer: SPECKIT_ORCHESTRATOR_<UPPER_KEY> per read-config.sh's documented layer.
       local upper_key
       upper_key=$(printf '%s' "$key" | tr '[:lower:]' '[:upper:]')
       env_val="$(eval 'printf %s "${SPECKIT_ORCHESTRATOR_'"$upper_key"':-}"')"
       if [ -z "$env_val" ]; then env_val="(unset)"; fi
       printf '    env=%s\n' "$env_val"
       # Effective resolution via read-config.sh (the canonical resolver).
       effective_val="$(bash "$_CCD_PROJECT_ROOT/scripts/state/read-config.sh" "$key" 2>/dev/null || true)"
       if [ -z "$effective_val" ]; then effective_val="(unset)"; fi
       printf '    effective=%s\n' "$effective_val"
     done
     return 0
   }

   # CLI entry point.
   if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
     KEYS=""
     SINGLE_KEY=""
     SUPPRESS=0
     CONFIG_DEFAULTS=""
     while [ $# -gt 0 ]; do
       case "$1" in
         --keys) KEYS="$2"; shift 2 ;;
         --key)  SINGLE_KEY="$2"; shift 2 ;;
         --no-config-check) SUPPRESS=1; shift ;;
         --config-defaults) CONFIG_DEFAULTS="$2"; shift 2 ;;
         --help|-h)
           printf '%s\n' "Usage: check-config-drift.sh [--keys k1,k2,...] [--key k] [--no-config-check] [--config-defaults <path>]"
           exit 0 ;;
         *) shift ;;
       esac
     done
     if [ "$SUPPRESS" -eq 1 ]; then exit 0; fi
     if [ -n "$SINGLE_KEY" ]; then
       KEYS="$SINGLE_KEY"
     elif [ -n "$KEYS" ]; then
       # Convert comma-separated to space-separated.
       KEYS=$(printf '%s' "$KEYS" | tr ',' ' ')
     else
       KEYS="$_CCD_DEFAULT_KEYS"
     fi
     check_config_drift_render "$KEYS"
     exit 0
   fi
   ```

   `chmod +x scripts/diagnostics/check-config-drift.sh`.

2. **Edit `commands/doctor.md`**. The current document structure (pre-T02):

   ```
   --- frontmatter ---
   # orchestrator:doctor (heading + intro)
   ## What It Checks (numbered list)
   ## Runtime Instruction Drift (paragraph + finding kinds)
   ## Usage (bash code block)
   ## Output (paragraph)
   ## When to Run (bullet list)
   ## Referenced Scripts (bullet list)
   ```

   **Insert two new sections between `## Runtime Instruction Drift` and `## Usage`**:

   ```markdown
   ## Anomaly Detection

   The `Anomaly Detection` check (M027/P03 FR-8) compares each dispatch in a milestone's `execution-log.jsonl` against a per-milestone moving median baseline and flags rows whose cost exceeds the configured multiplier (default 3.0×), whose `retry_count` exceeds the configured threshold (default 2), or whose `verification_pass_rate` falls below the configured threshold (default 0.5). Findings are advisory and never block autonomous mode (FR-8). Goodhart pairing (FR-9 / CON-4): every flagged row surfaces BOTH cost (or `cost=(unavailable; fallback=duration)`) AND quality (`pass_rate=`, `retry_count=`) on the same line.

   ### Suppression matrix (5 conditions)

   The anomaly check is suppressed (zero stdout, exit 0) under any of:

   - `--no-anomaly` flag on `check-anomalies.sh` or `run-doctor.sh`
   - `--yes` flag on `check-anomalies.sh`
   - `ORCHESTRATOR_AUTO=1` env var
   - `ORCH_ANOMALY_CHECK_ENABLED=false` env var, or `anomaly_check_enabled: false` in `.orchestrator/config.yml`
   - sample-size below the configured floor (default 5; configurable via `--sample-floor <N>`) — structural carve-out: in default mode the helper emits a single `ANOMALY: insufficient sample (n=<N> floor=<F>)` line so operators see why the check skipped; under any of the four flags above the surface stays empty

   ### Baseline disclaimer

   Anomaly detection uses a per-milestone moving median as the baseline. The baseline normalizes whatever historical data is present, including systematic errors — a milestone that consistently runs slow normalizes the slowness as expected. Findings are advisory and never block autonomous mode (FR-8). When `estimated_cost_usd` is null in the underlying records (current default in pre-Tier-3 data), the multiplier is applied to `duration_s` as a fallback surrogate; the per-row diagnostic surfaces `cost=(unavailable; fallback=duration)` so operators see the substitution. Corruption-recovery — re-baselining after recovering from a known systematic error — is deferred (Tier 3 backend-actuals work).

   Helper: `scripts/diagnostics/check-anomalies.sh` (sourceable + CLI). Default invocation scopes to the active milestone via `scripts/state/find-active-milestone.sh`.

   ## Config Drift

   The `Config Drift` check (M027/P03 FR-16) audits the M027 config knobs across the four precedence layers (env / local / project / defaults) so operators can see when team environments have drifted. Read-only and advisory.

   ### Audited knobs (default)

   - `efficiency_footer` (M027/P02) — controls the `orchestrator:status` efficiency footer surface
   - `predictive_cost_surface` (M027/P02) — controls the `orchestrator:dispatch` predictive cost surface
   - `anomaly_cost_multiplier` (M027/P03) — anomaly cost-spike multiplier (default 3.0)
   - `anomaly_retry_threshold` (M027/P03) — anomaly `retry_count` threshold (default 2)
   - `anomaly_pass_rate_threshold` (M027/P03) — anomaly `verification_pass_rate` threshold (default 0.5)
   - `anomaly_check_enabled` (M027/P03) — master enable for the anomaly check (default true)

   ### Invocation

   Pass `--config-check` to `run-doctor.sh` to run the drift audit alongside the standard checks, or invoke the helper directly:

   ```bash
   bash scripts/diagnostics/check-config-drift.sh --keys efficiency_footer,predictive_cost_surface,anomaly_cost_multiplier,anomaly_retry_threshold,anomaly_pass_rate_threshold,anomaly_check_enabled
   ```

   Helper: `scripts/diagnostics/check-config-drift.sh` (sourceable + CLI).
   ```

   **Add two new bullets to `## Referenced Scripts`** (preserve existing entries; append to the list):

   ```markdown
   - `scripts/diagnostics/check-anomalies.sh` — anomaly-detection helper (M027/P03/T01).
   - `scripts/diagnostics/check-config-drift.sh` — config-drift helper (M027/P03/T02).
   ```

   **Do not re-order or re-word any pre-existing section**. The two new sections + two new bullets are the ONLY structural additions.

3. **Capture the post-edit baseline fixture**. After step 2 lands, copy the verbatim post-`## Referenced Scripts` tail of `commands/doctor.md` to `tests/fixtures/m027-p03/doctor-suppressed-baseline.txt`. Since `## Referenced Scripts` is the LAST canonical section in the document (no further sections follow it), the "tail" is just the `## Referenced Scripts` heading + the bullet list. Use `awk '/^## Referenced Scripts/,EOF' commands/doctor.md > tests/fixtures/m027-p03/doctor-suppressed-baseline.txt`.

4. **Create the anomaly fixture log** `tests/fixtures/m027-p03/anomaly-fixture.jsonl` (hand-crafted, deterministic, 9 records — exactly one ≥ 3× cost (or duration_s) outlier among 8 sibling dispatches under milestone M999):

   ```jsonl
   {"record_type":"unit_close","granularity":"task","unitId":"M999/P00/T01","milestone":"M999","phase":"P00","task":"T01","duration_s":300,"outcome":"pass","completed_at":"2026-04-27T00:00:00Z","estimated_cost_usd":0.10,"pricing_version":"1.0","verification_pass_rate":1.0,"deviation_count":0,"retry_count":0,"source":"estimate","timestamp":"2026-04-27T00:00:00Z"}
   {"record_type":"unit_close","granularity":"task","unitId":"M999/P00/T02","milestone":"M999","phase":"P00","task":"T02","duration_s":300,"outcome":"pass","completed_at":"2026-04-27T00:01:00Z","estimated_cost_usd":0.10,"pricing_version":"1.0","verification_pass_rate":1.0,"deviation_count":0,"retry_count":0,"source":"estimate","timestamp":"2026-04-27T00:01:00Z"}
   {"record_type":"unit_close","granularity":"task","unitId":"M999/P00/T03","milestone":"M999","phase":"P00","task":"T03","duration_s":300,"outcome":"pass","completed_at":"2026-04-27T00:02:00Z","estimated_cost_usd":0.10,"pricing_version":"1.0","verification_pass_rate":1.0,"deviation_count":0,"retry_count":0,"source":"estimate","timestamp":"2026-04-27T00:02:00Z"}
   {"record_type":"unit_close","granularity":"task","unitId":"M999/P00/T04","milestone":"M999","phase":"P00","task":"T04","duration_s":300,"outcome":"pass","completed_at":"2026-04-27T00:03:00Z","estimated_cost_usd":0.10,"pricing_version":"1.0","verification_pass_rate":1.0,"deviation_count":0,"retry_count":0,"source":"estimate","timestamp":"2026-04-27T00:03:00Z"}
   {"record_type":"unit_close","granularity":"task","unitId":"M999/P00/T05","milestone":"M999","phase":"P00","task":"T05","duration_s":300,"outcome":"pass","completed_at":"2026-04-27T00:04:00Z","estimated_cost_usd":0.10,"pricing_version":"1.0","verification_pass_rate":1.0,"deviation_count":0,"retry_count":0,"source":"estimate","timestamp":"2026-04-27T00:04:00Z"}
   {"record_type":"unit_close","granularity":"task","unitId":"M999/P00/T06","milestone":"M999","phase":"P00","task":"T06","duration_s":300,"outcome":"pass","completed_at":"2026-04-27T00:05:00Z","estimated_cost_usd":0.10,"pricing_version":"1.0","verification_pass_rate":1.0,"deviation_count":0,"retry_count":0,"source":"estimate","timestamp":"2026-04-27T00:05:00Z"}
   {"record_type":"unit_close","granularity":"task","unitId":"M999/P00/T07","milestone":"M999","phase":"P00","task":"T07","duration_s":300,"outcome":"pass","completed_at":"2026-04-27T00:06:00Z","estimated_cost_usd":0.10,"pricing_version":"1.0","verification_pass_rate":1.0,"deviation_count":0,"retry_count":0,"source":"estimate","timestamp":"2026-04-27T00:06:00Z"}
   {"record_type":"unit_close","granularity":"task","unitId":"M999/P00/T08","milestone":"M999","phase":"P00","task":"T08","duration_s":300,"outcome":"pass","completed_at":"2026-04-27T00:07:00Z","estimated_cost_usd":0.10,"pricing_version":"1.0","verification_pass_rate":1.0,"deviation_count":0,"retry_count":0,"source":"estimate","timestamp":"2026-04-27T00:07:00Z"}
   {"record_type":"unit_close","granularity":"task","unitId":"M999/P00/T09","milestone":"M999","phase":"P00","task":"T09","duration_s":2400,"outcome":"pass","completed_at":"2026-04-27T00:08:00Z","estimated_cost_usd":0.80,"pricing_version":"1.0","verification_pass_rate":0.4,"deviation_count":2,"retry_count":3,"source":"estimate","timestamp":"2026-04-27T00:08:00Z"}
   ```

   Note: T09 is the outlier — `estimated_cost_usd` 0.80 is 8× the median 0.10; `duration_s` 2400 is 8× the median 300; `retry_count` 3 > 2; `verification_pass_rate` 0.4 < 0.5. The fixture exercises ALL THREE flagging conditions on the same row so the Goodhart-pairing verifier can assert the row contains BOTH cost AND quality tokens.

   The fixture uses `M999` as the milestone ID (mirrors M027/P00 fixture convention) so the anomaly-detection helper invocation against this fixture cannot pollute real `.orchestrator/milestones/` data and the read-only invariant is trivially satisfied. To run the helper against this fixture, the verifier sets up a `mktemp -d` directory, copies the fixture into `<tmp>/.orchestrator/milestones/M999/execution-log.jsonl`, and invokes the helper with `--milestone M999` while the rollup engine's `--log` flag (or env var) points at the temp tree.

5. **Create `tests/fixtures/m027-p03/README.md`** (~10 lines):

   ```markdown
   # M027/P03 fixtures

   - `doctor-suppressed-baseline.txt` — verbatim post-`## Referenced Scripts` tail of `commands/doctor.md`. Load-bearing baseline for the byte-identity verifier (`scripts/verify/m027-p03-doctor-byte-identity.sh`); intentional changes to the document tail must be reflected here via a follow-up commit, otherwise the verifier rejects the drift as accidental.
   - `anomaly-fixture.jsonl` — 9 hand-crafted `unit_close` records under milestone M999. T01–T08 are siblings (300s / $0.10 / pass_rate 1.0 / retry 0); T09 is an 8× cost (and duration) outlier with `retry_count=3` and `pass_rate=0.4`. Used by `scripts/verify/m027-p03-anomaly-goodhart-pairing.sh` to exercise the helper against a deterministic input. M999 milestone ID prevents pollution of real milestone data.
   ```

6. **Create the T02-scoped precheck** `scripts/verify/m027-p03-t02-shape-precheck.sh` (~110 lines) with the standard verifier skeleton asserting T02's must-haves. T04 ships the canonical phase-level verifiers (`m027-p03-config-drift-shape.sh`, `m027-p03-doctor-md-shape.sh`, `m027-p03-doctor-byte-identity.sh`) which subsume this precheck and may delete it.

   Skeleton:

   ```bash
   #!/usr/bin/env bash
   set -u
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
   cd "$PROJECT_ROOT"
   fail() { echo "FAIL: m027-p03-t02-shape-precheck $1" >&2; exit 1; }
   # Helper file shape.
   [ -f scripts/diagnostics/check-config-drift.sh ] || fail "missing config-drift helper"
   [ -x scripts/diagnostics/check-config-drift.sh ] || fail "config-drift helper not executable"
   lines=$(wc -l < scripts/diagnostics/check-config-drift.sh)
   [ "$lines" -ge 80 ] || fail "config-drift helper too short ($lines lines)"
   grep -q "Config Drift (M027 knobs)" scripts/diagnostics/check-config-drift.sh || fail "missing title"
   grep -q "check_config_drift_render" scripts/diagnostics/check-config-drift.sh || fail "missing function"
   grep -q "BASH_SOURCE" scripts/diagnostics/check-config-drift.sh || fail "missing source guard"
   grep -q "read-config.sh" scripts/diagnostics/check-config-drift.sh || fail "missing read-config delegation"
   # Doctor.md shape.
   [ -f commands/doctor.md ] || fail "missing doctor.md"
   doc_lines=$(wc -l < commands/doctor.md)
   [ "$doc_lines" -ge 60 ] || fail "doctor.md too short ($doc_lines lines)"
   grep -q "## Anomaly Detection" commands/doctor.md || fail "missing ## Anomaly Detection section"
   grep -q "## Config Drift" commands/doctor.md || fail "missing ## Config Drift section"
   grep -q "scripts/diagnostics/check-anomalies.sh" commands/doctor.md || fail "missing check-anomalies.sh ref"
   grep -q "scripts/diagnostics/check-config-drift.sh" commands/doctor.md || fail "missing check-config-drift.sh ref"
   grep -q -- "--no-anomaly" commands/doctor.md || fail "missing --no-anomaly doc"
   grep -q "ORCHESTRATOR_AUTO" commands/doctor.md || fail "missing ORCHESTRATOR_AUTO doc"
   grep -q "anomaly_check_enabled" commands/doctor.md || fail "missing anomaly_check_enabled doc"
   grep -q "insufficient sample" commands/doctor.md || fail "missing sample-floor doc"
   grep -q "fallback=duration" commands/doctor.md || fail "missing duration-fallback disclaimer"
   # Fixtures.
   [ -f tests/fixtures/m027-p03/doctor-suppressed-baseline.txt ] || fail "missing doctor baseline fixture"
   grep -q "Referenced Scripts" tests/fixtures/m027-p03/doctor-suppressed-baseline.txt || fail "fixture missing Referenced Scripts marker"
   [ -f tests/fixtures/m027-p03/anomaly-fixture.jsonl ] || fail "missing anomaly fixture"
   fixture_lines=$(wc -l < tests/fixtures/m027-p03/anomaly-fixture.jsonl)
   [ "$fixture_lines" -ge 9 ] || fail "anomaly fixture too short ($fixture_lines lines)"
   grep -q "M999/P00/T09" tests/fixtures/m027-p03/anomaly-fixture.jsonl || fail "anomaly fixture missing T09 outlier"
   [ -f tests/fixtures/m027-p03/README.md ] || fail "missing fixture README"
   # Behavioral: helper smoke-test.
   out=$(bash scripts/diagnostics/check-config-drift.sh --keys efficiency_footer 2>/dev/null)
   echo "$out" | grep -q "Config Drift (M027 knobs)" || fail "helper missing title in output"
   echo "$out" | grep -q "key=efficiency_footer" || fail "helper missing key= line"
   echo "$out" | grep -q "effective=" || fail "helper missing effective= line"
   # Behavioral: --no-config-check suppresses.
   out=$(bash scripts/diagnostics/check-config-drift.sh --no-config-check 2>/dev/null)
   [ -z "$out" ] || fail "--no-config-check produced output"
   echo "PASS: m027-p03-t02-shape-precheck"
   exit 0
   ```

   `chmod +x scripts/verify/m027-p03-t02-shape-precheck.sh`.

## Must-Haves

- File `scripts/diagnostics/check-config-drift.sh` exists, ≥ 80 lines, executable.
- File contains the literal string `Config Drift (M027 knobs)` (block title).
- File contains a function definition `check_config_drift_render`.
- File contains a CLI entry-point guard.
- File invokes `scripts/state/read-config.sh`.
- `commands/doctor.md` exists, ≥ 60 lines, contains both `## Anomaly Detection` and `## Config Drift` headings.
- `commands/doctor.md` references both `scripts/diagnostics/check-anomalies.sh` and `scripts/diagnostics/check-config-drift.sh`.
- `commands/doctor.md` documents the 5-condition suppression matrix tokens (`--no-anomaly`, `ORCHESTRATOR_AUTO`, `anomaly_check_enabled`, sample-floor, `--yes` — at minimum the strings `--no-anomaly`, `ORCHESTRATOR_AUTO`, `anomaly_check_enabled`, `insufficient sample`, `fallback=duration` must be present).
- `tests/fixtures/m027-p03/doctor-suppressed-baseline.txt` exists, contains the literal string `Referenced Scripts`.
- `tests/fixtures/m027-p03/anomaly-fixture.jsonl` exists, ≥ 9 lines, contains the literal string `M999/P00/T09` (the outlier row).
- `tests/fixtures/m027-p03/README.md` exists, ≥ 5 lines.
- `scripts/verify/m027-p03-t02-shape-precheck.sh` exists, executable, exits 0 against the post-T02 codebase.

## Verification

```bash
bash scripts/verify/m027-p03-t02-shape-precheck.sh
```

This T02-scoped precheck verifier (ships with T02) asserts T02's must-haves. T04 ships the canonical phase-level verifiers (`m027-p03-config-drift-shape.sh`, `m027-p03-doctor-md-shape.sh`, `m027-p03-doctor-byte-identity.sh`) which subsume this precheck.

## Inputs

### From Previous Tasks

- T01: `scripts/diagnostics/check-anomalies.sh` — referenced by `commands/doctor.md`'s new `## Anomaly Detection` section. Library function: `check_anomalies_render`. CLI flags: `--milestone`, `--project`, `--no-anomaly`, `--yes`, `--threshold`, `--sample-floor`, `--config-defaults`, `--help`. Title: `Anomaly Detection (Tier 1 baseline)`. Suppressed mode emits zero stdout.
- T01: modified `scripts/state/read-config.sh` `VALID_KEYS` to include `anomaly_cost_multiplier`, `anomaly_retry_threshold`, `anomaly_pass_rate_threshold`, `anomaly_check_enabled`. The config-drift helper's default key list audits all six M027 knobs (the four T01-added + the two M027/P02-added).

### From Disk (Pre-existing)

- `commands/doctor.md` — pre-T02 form with sections in the order frontmatter / `# orchestrator:doctor` / `## What It Checks` / `## Runtime Instruction Drift` / `## Usage` / `## Output` / `## When to Run` / `## Referenced Scripts`. T02 inserts two new sections between `## Runtime Instruction Drift` and `## Usage`.
- `scripts/state/read-config.sh` (M027/P02-extended + T01-extended) — the canonical resolver invoked by `check-config-drift.sh` for each layer. Returns empty stdout / exit 1 for unset keys.
- `awk` (POSIX) — used in step 3 to extract the `## Referenced Scripts` tail for the baseline fixture.

## Constraints

- **CON-7 (bash 3.2)**: No `declare -A`, no `<<<`, no `mapfile`, no `${var^^}`, no `<(...)`, no `&>`. Verifier scans this file in T04. (The helper does use `tr '[:lower:]' '[:upper:]'` for env-var name uppercasing — this is POSIX, not the bash-4 `${var^^}` operator.)
- **CON-3-equivalent (suppressed-mode byte-identity)**: Under `--no-config-check`, emits zero stdout. The T04 verifier gates this for the config-drift helper; for the doctor-md byte-identity, the T04 verifier diffs the post-`## Referenced Scripts` tail against the T02 fixture.
- **CON-5 (never-abort)**: `read-config.sh` returning non-zero / empty is treated as `(unset)`; no aborts.
- **FR-12 / CON-1 (read-only)**: No writes to disk. Verified by T04's read-only verifier.
- **FR-21 / CON-6 / SC-16 (zero-LLM-token)**: No `claude_chat`, no `anthropic`, no `dispatch-interface.sh`, no `dispatch_task`, no `subagent` in the file body. Verified by T04's `m027-p03-zero-llm-token.sh`.
- **FR-16 (config-check semantics)**: The helper audits the full M027 knob set across all four config layers. The default `--keys` value is the six M027 knobs.
- **AD-19 (single-script-file Check shape)**: This task's `Check:` invokes a single helper script (the T02-scoped precheck). T04 ships the canonical phase-level Truth `Check:` invocations.
- **MEM004 (emitter-internal carve-out)**: The helper script body MAY use pipes / `$()` / `tr` / `eval` / `printf` — these are emitter internals. The use of `eval 'printf %s "${SPECKIT_ORCHESTRATOR_'"$upper_key"':-}"'` is an intentional indirection to read a dynamically-named env var; the `$upper_key` expansion is whitelisted because it has been already passed through `tr '[:lower:]' '[:upper:]'` from the `VALID_KEYS` enum, so no shell-injection surface exists.
- **MEM012 (command file structure)**: `commands/doctor.md` follows the canonical command file structure (frontmatter / Title / Workflow sections / Output / Referenced Scripts). The two new sections respect this structure.

## Expected Output

After this task:

1. `scripts/diagnostics/check-config-drift.sh` exists, ≥ 80 lines, executable, satisfies the must-haves above.
2. `commands/doctor.md` ≥ 60 lines, contains both `## Anomaly Detection` and `## Config Drift` sections + two new bullets in `## Referenced Scripts`.
3. `tests/fixtures/m027-p03/doctor-suppressed-baseline.txt` exists, contains the verbatim post-`## Referenced Scripts` tail of the post-T02 `commands/doctor.md`.
4. `tests/fixtures/m027-p03/anomaly-fixture.jsonl` exists, 9 lines, contains the M999/P00/T09 outlier row.
5. `tests/fixtures/m027-p03/README.md` exists, ≥ 5 lines.
6. `scripts/verify/m027-p03-t02-shape-precheck.sh` exists, executable, exits 0 against the post-T02 codebase.
7. `git diff --quiet` is non-zero (this task creates and modifies files); however, no `execution-log.jsonl` file is touched.
