---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P03"
milestone: "M018"
name: "Verifiers (7 truth checks) + fixture + P03-SUMMARY + CLAUDE.md/AGENTS.md dual-write"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01 has landed:
  - `_bc_apply_tier1` in `scripts/dispatch/build-context.sh` — paging + cache write + post-paging `pres_check_section` self-check + `tier_preservation_violation` emit on failure.
  - `compression.tier1.*` config keys in `.orchestrator/config.yml`.
  - Additive `tier1_savings_tokens` + `tier1_invocations` fields on `payload_breakdown` JSONL records via `_bc_emit_payload_breakdown`.
  - The Tier 1 call site is between the existing `_bc_emit_payload_breakdown` and `_bc_emit_compression_underperformance` calls (line ~1470).
- T02 has landed:
  - `scripts/util/cache-prune.sh --max-age <duration>` — single-script-file utility; reads `compression.tier1.cache_dir` from config.
- P02 has shipped:
  - `tests/fixtures/m018-p02-baseline-payload.golden.txt` — golden payload for the disable-flag regression. T03's `m018-p03-disable-flag-honored.sh` re-uses this golden under T01's build-context.sh to assert `compression.enabled: false` keeps it byte-identical.
  - `scripts/lib/preservation-check.sh` — sourceable; `pres_check_section` and `pres_emit_violation` exposed.
- AP-009 (Bash shape guard): no compound chains > 2; no plain subshells; no `$(...|...)`. Bash 3.2.

## Description

Land the seven truth verifiers, the T03 fixture, the P03 phase summary, and the CLAUDE.md/AGENTS.md `recent-changes` dual-write. After T03:

1. `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P03/` exits 0 — every truth `Check:` script PASSes; every artifact path exists with required line count + substring; every key link resolves.
2. The phase state advances from `executing` to `phase-summary` once `P03-SUMMARY.md` is written; the next `derive-phase.sh` call returns `phase-complete`.
3. CLAUDE.md and AGENTS.md `orchestrator:recent-changes` blocks both name `M018/P03` (or `tier1`) and were written via `scripts/util/dual-write-runtime-md.sh` so the two files stay in sync.

## Steps

### Step 1 — Build the fixture

Create `tests/fixtures/m018-p03-tool-result/dispatch-payload-fixture.md`. This is a hand-written dispatch payload that contains:
- One short tool-result block (body well under 1500-token threshold) — passes through verbatim.
- One large tool-result block (body well over 1500-token threshold; ~7000 chars of repeated `echo`-like text is enough) — gets paged.
- Some surrounding markdown so the fixture resembles a real assembled payload.

Use `Write` to author the file. Sample shape (the body field is what counts for verification):

```
# Dispatch Context -- T01 (Phase P03, Milestone M018)

## Manifest
| Section | Lines | Tokens |
|---------|-------|--------|
| Upstream Context | 200 | 7000 |

## Upstream Context

### Recent tool results (raw)

<tool-result command="ls -la /tmp">
<tool-result-input>
</tool-result-input>
<tool-result-body>
total 8
drwx------  3 user  wheel  96 Apr 27 12:00 .
drwxrwxrwt 12 root  wheel 384 Apr 27 12:00 ..
-rw-------  1 user  wheel  17 Apr 27 12:00 small.txt
</tool-result-body>
</tool-result>

<tool-result command="cat /tmp/big.log">
<tool-result-input>
</tool-result-input>
<tool-result-body>
LOG line 0001 — repeating-content-marker M018-P03-T03-BIG
LOG line 0002 — repeating-content-marker M018-P03-T03-BIG
... (repeat the LOG line up to ~200 lines so body exceeds 1500-token threshold)
</tool-result-body>
</tool-result>

## Task Plan

A small task plan body, ~10 lines, terminating the payload.
```

Repeat the LOG line ~200 times so the big block's body crosses ~7000 chars (~1750 tokens > 1500-token threshold). The exact authoring step: write a short bash one-liner in the fixture-staging helper (Step 2) to expand the LOG-block — it is easier to maintain than 200 hand-typed lines.

Also create `tests/fixtures/m018-p03-tool-result/README.md` (≥ 10 lines) describing the fixture's intent: small block passes through; big block gets paged; cache-reuse verifier replays the same fixture.

### Step 2 — Build the fixture-staging helper

Create `scripts/verify/_helpers/m018-p03-build-fixture.sh`. Multiple verifiers need the same fixture milestone shape (`.orchestrator/milestones/M018-fixture/...`); this helper stages it under a tmp directory passed as `$1`. Pattern lifted directly from P02's `_helpers/m018-p02-build-fixture.sh`.

```bash
#!/usr/bin/env bash
# Stages a fixture orchestrator root under $1 so a verifier can drive
# build-context.sh against a controlled state. Bash 3.2 + AP-009 clean.
set -eu

DEST="${1:-}"
if [ -z "$DEST" ]; then
  printf 'm018-p03-build-fixture.sh: missing dest directory\n' >&2
  exit 1
fi

PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

mkdir -p "$DEST/milestones/M018-fixture/phases/P03"
mkdir -p "$DEST/cache/tool-results"

# Fake task plan so build-context.sh has somewhere to point.
cat > "$DEST/milestones/M018-fixture/phases/P03/T01-PLAN.md" <<'EOF'
---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P03"
milestone: "M018-fixture"
---
# Stub task plan for fixture dispatch.
EOF

# Copy the fixture payload so build-context.sh can ingest it as a captured payload directly.
mkdir -p "$DEST/_fixture-payloads"
cp "$PROJECT_ROOT/tests/fixtures/m018-p03-tool-result/dispatch-payload-fixture.md" \
   "$DEST/_fixture-payloads/payload.md"

# Minimal config.yml inside the fixture.
cat > "$DEST/config.yml" <<EOF
compression:
  enabled: true
  knowledge_filter:
    enabled: true
    drop_list:
      - superseded
      - experimental
  tier1:
    enabled: true
    inline_threshold_tokens: 1500
    preview_lines: 5
    cache_dir: $DEST/cache/tool-results/
EOF
```

### Step 3 — Author the seven verifiers

Each verifier is a single-script-file (AD-19), AP-009-clean, exits 0 on PASS, exits 1 on FAIL with a one-line `FAIL:` stderr message naming the assertion that broke.

#### 3.1 `scripts/verify/m018-p03-tier1-paging.sh`

Stage the fixture; copy the fixture payload to a tmp `$PAYLOAD_CAPTURE`-shaped path; invoke `_bc_apply_tier1` directly via a small bash invocation that sources build-context.sh's config-derived environment. Cleanest approach: stage the fixture under `$DEST` and run `_bc_apply_tier1` against the staged payload via a small inline shim:

```bash
#!/usr/bin/env bash
# m018-p03-tier1-paging.sh — asserts that the big tool-result block is
# paged out (replaced with a `<tool-result file=...>` reference) and the
# cache file is written under the configured cache_dir; the small block
# is left unchanged.
set -eu

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DEST="$(mktemp -d)"
bash "$PROJECT_ROOT/scripts/verify/_helpers/m018-p03-build-fixture.sh" "$DEST"

# Drive _bc_apply_tier1 indirectly: invoke build-context.sh against the
# fixture? Simpler — author a thin shim that exports the four TIER1_*
# envs and sources just the tier1 function.
SHIM="$DEST/_shim.sh"
cat > "$SHIM" <<'SHIM_EOF'
#!/usr/bin/env bash
set -eu
PROJECT_ROOT="$1"
DEST="$2"
ORCH_ROOT="$DEST"
TMPDIR_BUILD="$(mktemp -d)"
COMPRESSION_ENABLED=true
TIER1_ENABLED=true
TIER1_INLINE_THRESHOLD_TOKENS=1500
TIER1_PREVIEW_LINES=5
TIER1_CACHE_DIR="$DEST/cache/tool-results/"
MILESTONE_ID=M018-fixture
PHASE_ID=P03
TASK_ID=T01
. "$PROJECT_ROOT/scripts/lib/preservation-check.sh"
# Source ONLY the _bc_apply_tier1 function. Cleanest path: extract via sed.
SCRATCH="$(mktemp)"
sed -n '/^_bc_apply_tier1()/,/^}$/p' "$PROJECT_ROOT/scripts/dispatch/build-context.sh" > "$SCRATCH"
. "$SCRATCH"
PAYLOAD="$DEST/_fixture-payloads/payload.md"
_bc_apply_tier1 "$PAYLOAD"
cat "$PAYLOAD"
SHIM_EOF
chmod +x "$SHIM"

OUT="$(bash "$SHIM" "$PROJECT_ROOT" "$DEST")"

if ! printf '%s\n' "$OUT" | grep -q '<tool-result file="'; then
  printf 'FAIL: expected <tool-result file="..."> reference in paged payload\n' >&2
  exit 1
fi
if ! printf '%s\n' "$OUT" | grep -q 'small.txt'; then
  printf 'FAIL: small block was paged (it should pass through verbatim)\n' >&2
  exit 1
fi
if ! ls "$DEST/cache/tool-results/" | grep -qE '^[0-9a-f]{64}$'; then
  printf 'FAIL: expected SHA-256-named cache file under %s\n' "$DEST/cache/tool-results/" >&2
  exit 1
fi
printf 'PASS: m018-p03-tier1-paging\n'
exit 0
```

Note the AP-009-safe shape: heredocs feed plain `cat >` (not piped to a command), shell interpolation happens inside the heredoc body which is permitted, and the captured `OUT` lookups go through `printf '%s\n' "$OUT" | grep -q PATTERN` — that is `cmd | grep -q`, which is a single pipe, not the banned `$(... | ...)` shape (the entire `printf | grep` is the command, not a command-substitution). The verifier shim file extraction via `sed -n '/^_bc_apply_tier1()/,/^}$/p'` is brittle in principle but acceptable: the `_bc_apply_tier1` function is the only one with that exact name, and the closing `^}$` at column 0 is the canonical bash function-end shape.

If the sed-extraction proves too fragile during T03 authoring, alternative: have T01 emit `_bc_apply_tier1` as a separate sourceable file under `scripts/lib/tier1.sh` and source it from build-context.sh. That refactor adds a small file but eliminates the verifier-side sed extraction. Recommend deferring that refactor unless verifiers fail in practice.

#### 3.2 `scripts/verify/m018-p03-cache-reuse.sh`

Same shim pattern as 3.1. Run `_bc_apply_tier1` twice against the same fixture payload (each run rewrites the payload; the second run's input is the original captured payload, not the paged output, because real dispatches always start from a fresh capture). Capture the cache file's mtime after the first run; assert the second run does not change it.

```bash
#!/usr/bin/env bash
# m018-p03-cache-reuse.sh — asserts SHA-256-keyed cache hits short-circuit
# the cache write; mtime preserved across two paging passes.
set -eu

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DEST="$(mktemp -d)"
bash "$PROJECT_ROOT/scripts/verify/_helpers/m018-p03-build-fixture.sh" "$DEST"

PAYLOAD="$DEST/_fixture-payloads/payload.md"
PAYLOAD_BACKUP="$DEST/_fixture-payloads/payload-backup.md"
cp "$PAYLOAD" "$PAYLOAD_BACKUP"

SHIM="$DEST/_shim.sh"
# (same shim authoring as 3.1 — extract _bc_apply_tier1 + run once)
# Author shim exactly as in 3.1.
# ... (verbatim copy of shim from 3.1) ...

# First pass.
bash "$SHIM" "$PROJECT_ROOT" "$DEST" >/dev/null
# Capture mtime of the SHA-256-named cache file (there should be exactly one
# matching the big block).
CACHE_FILE="$(ls "$DEST/cache/tool-results/" | head -n1)"
if [ -z "$CACHE_FILE" ]; then
  printf 'FAIL: cache file missing after first pass\n' >&2
  exit 1
fi
if stat -f %m "$DEST/cache/tool-results/$CACHE_FILE" >/dev/null 2>&1; then
  MTIME1="$(stat -f %m "$DEST/cache/tool-results/$CACHE_FILE")"
else
  MTIME1="$(stat -c %Y "$DEST/cache/tool-results/$CACHE_FILE")"
fi

# Restore the original payload and run again.
cp "$PAYLOAD_BACKUP" "$PAYLOAD"
sleep 1   # ensure mtime resolution is at least 1s.
bash "$SHIM" "$PROJECT_ROOT" "$DEST" >/dev/null

if stat -f %m "$DEST/cache/tool-results/$CACHE_FILE" >/dev/null 2>&1; then
  MTIME2="$(stat -f %m "$DEST/cache/tool-results/$CACHE_FILE")"
else
  MTIME2="$(stat -c %Y "$DEST/cache/tool-results/$CACHE_FILE")"
fi

if [ "$MTIME1" != "$MTIME2" ]; then
  printf 'FAIL: cache-reuse expected mtime preserved (%s != %s)\n' "$MTIME1" "$MTIME2" >&2
  exit 1
fi
printf 'PASS: m018-p03-cache-reuse\n'
exit 0
```

#### 3.3 `scripts/verify/m018-p03-emitter-additivity.sh`

Drive `build-context.sh` end-to-end against a real fixture milestone state, capture the emitted `payload_breakdown` line, assert it contains both `tier1_savings_tokens` and `tier1_invocations` keys with integer values; assert the JSON parses cleanly via `python3 -c 'import json,sys; [json.loads(l) for l in sys.stdin]'`. Also assert pre-existing fields (`payload_chars`, `filter_dropped_tokens`, `model`) are still present (CON-5 additivity check).

The simplest end-to-end path: write a minimal fixture orchestrator state under `$DEST` (already done by `_helpers/m018-p03-build-fixture.sh` from Step 2), invoke `bash scripts/dispatch/build-context.sh M018-fixture P03 T01` against it (set `ORCH_ROOT=$DEST`), then read `$DEST/milestones/M018-fixture/execution-log.jsonl`.

Heredoc the verifier body in the same single-script-file shape; assertions via `grep -q "tier1_savings_tokens"` etc.

#### 3.4 `scripts/verify/m018-p03-cache-prune.sh`

Stage a tmp cache root with two files (one backdated, one fresh), invoke `bash scripts/util/cache-prune.sh --max-age 7d` against it (set `--max-age` and a tmp config that points to the staged directory; alternative: invoke with `cd $DEST` so the script's project-root walk lands on the staged config). Assert:
- The backdated file is gone after the prune.
- The fresh file is still present.
- A second invocation reports `pruned=0` (idempotency).
- The script exits 0 in both calls.

#### 3.5 `scripts/verify/m018-p03-disable-flag-honored.sh`

Two assertions:
1. With `compression.enabled: false` (set via `ORCH_OVERRIDE_COMPRESSION_ENABLED=false`), build-context.sh produces a payload byte-identical to `tests/fixtures/m018-p02-baseline-payload.golden.txt`. (Re-uses P02's existing golden; T01 must not have broken it.)
2. With `compression.enabled: true` and `compression.tier1.enabled: false`, the knowledge filter still drops entries (verifiable from the JSONL `payload_filter` record presence) but the Tier 1 paging short-circuits (no cache writes; `tier1_invocations: 0` in the `payload_breakdown` record).

Both assertions exercise the same fixture state. Implementation pattern is the same as P02's `m018-p02-disable-flag-honored.sh` — diff against the golden under override; assert presence/absence of records in the JSONL.

#### 3.6 `scripts/verify/m018-p03-preservation-self-check.sh`

Construct a small synthetic captured payload that contains a tool-result block whose body, after paging, would corrupt a preserved-pattern (the simplest forcing function: hand-craft a body whose first 5 lines — what the preview keeps — break a cross-tier vocabulary regex from `pres_check_section`). Then assert that:
- The post-paging file is the SAME as the pre-paging file (passthrough on self-check failure).
- A `tier_preservation_violation` JSONL record was emitted with `tier=tier1`.

Hand-engineering a body that passes the threshold AND breaks a preserved pattern requires knowledge of `PRES_PATTERNS_REGEX` content. The simplest forcing function: stub `pres_check_section` itself by sourcing a tiny shadowing function before the shim runs `_bc_apply_tier1`:

```bash
# In the verifier shim, override pres_check_section to always fail.
pres_check_section() { return 1; }
pres_emit_violation() {
  printf '{"record_type":"tier_preservation_violation","tier":"%s","section":"%s","pattern":"%s","timestamp":"stub"}\n' \
         "$1" "$2" "$3" >> "$4"
}
```

Then assert the captured payload equals the pre-paging snapshot AND `execution-log.jsonl` contains the synthetic record. This stub-driven approach exercises the production `_bc_apply_tier1` failure-path code without depending on the regex set's contents.

#### 3.7 `scripts/verify/m018-p03-dual-write-recent.sh`

Read both `CLAUDE.md` and `AGENTS.md`; assert both contain a line matching `M018/P03` OR `tier1` inside their `# >>> orchestrator:recent-changes >>>` block.

```bash
#!/usr/bin/env bash
set -eu
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

for f in "$PROJECT_ROOT/CLAUDE.md" "$PROJECT_ROOT/AGENTS.md"; do
  if [ ! -f "$f" ]; then
    printf 'FAIL: missing %s\n' "$f" >&2
    exit 1
  fi
  # Extract the recent-changes block via awk single pass.
  block="$(awk '
    /^# >>> orchestrator:recent-changes >>>/ { in_blk=1; next }
    /^# <<< orchestrator:recent-changes <<</ { in_blk=0 }
    in_blk { print }
  ' "$f")"
  if ! printf '%s\n' "$block" | grep -qE 'M018/P03|tier1'; then
    printf 'FAIL: %s recent-changes block missing M018/P03 or tier1\n' "$f" >&2
    exit 1
  fi
done
printf 'PASS: m018-p03-dual-write-recent\n'
exit 0
```

### Step 4 — Run the dual-write at phase close

Run `bash scripts/util/dual-write-runtime-md.sh` with whatever invocation pattern P02 used to refresh the `recent-changes` block. The block content is a single bullet line inside the `# >>> orchestrator:recent-changes >>>` ... `# <<<` markers.

Pattern (per P02):

```bash
bash scripts/util/dual-write-runtime-md.sh \
  --section "orchestrator:recent-changes" \
  --content "- 030-context-compression-layer: M018/P03 — Tier 1 microcompact (tool-result paging + SHA-256 cache reuse + tier1_* additive emitter fields + cache-prune.sh)"
```

(If `dual-write-runtime-md.sh` takes different flags, inspect P02's `m018-p02-dual-write-recent.sh` summary or `scripts/util/dual-write-runtime-md.sh --help` and adjust. The contract is just: both files end up with the same content inside the markers.)

### Step 5 — Author `P03-SUMMARY.md`

Create [`.orchestrator/milestones/M018/phases/P03/P03-SUMMARY.md`](../../../../../milestones/M018/phases/P03/P03-SUMMARY.md) per `templates/phase-summary.md`. The 16-field frontmatter (per MEM013) plus a closure body. Sample shape:

```yaml
---
schema_version: "1.0"
type: phase-summary
id: P03
parent: M018
milestone: M018
provides: "tier1 microcompact live in scripts/dispatch/build-context.sh:_bc_apply_tier1; .orchestrator/cache/tool-results/ SHA-256-keyed cache; tier1_savings_tokens + tier1_invocations additive payload_breakdown fields; scripts/util/cache-prune.sh --max-age <duration> mtime-based eviction; tier_preservation_violation JSONL record schema (additive, shared with future P04/P06); compression.tier1.* config keys"
requires: "P02 preservation-check library + payload_breakdown schema + payload_filter record (DEP — P02)"
affects: "P04 (T2 snip — same library, additive tier2_savings_tokens; reads tier_preservation_violation record schema as established here); P05 (eval harness — reads tier1 records); P06 (T3 auto-compact — same record-schema invariants)"
key_files: "scripts/dispatch/build-context.sh;scripts/util/cache-prune.sh;.orchestrator/config.yml;tests/fixtures/m018-p03-tool-result/dispatch-payload-fixture.md;scripts/verify/m018-p03-tier1-paging.sh;scripts/verify/m018-p03-cache-reuse.sh;scripts/verify/m018-p03-emitter-additivity.sh;scripts/verify/m018-p03-cache-prune.sh;scripts/verify/m018-p03-disable-flag-honored.sh;scripts/verify/m018-p03-preservation-self-check.sh;scripts/verify/m018-p03-dual-write-recent.sh"
key_decisions: "Tier 1 awk-driven single-pass paging (AP-009 compliant; mirrors P02 filter shape); SHA-256(command + 0x1F + input) cache key — full digest, no truncation; cache reuse short-circuits writes (mtime preserved); preservation self-check restores pre-paging body on failure (cache files written during failed pass kept for future reuse); cache-prune mtime-only (reference-aware preservation deferred — current cache key small enough that mtime is correct); _bc_apply_tier1 inline in build-context.sh (single call site, MEM004 carve-out)"
patterns_established: "Single-pass awk pagination with cache-write side-effect (T01); shim-style verifier that source-extracts a single bash function via sed (T03 — usable as P04/P06 verifier pattern)"
drill_down_paths: ".orchestrator/milestones/M018/phases/P03/tasks/T01-tier1-paging-SUMMARY.md;.orchestrator/milestones/M018/phases/P03/tasks/T02-cache-prune-SUMMARY.md;.orchestrator/milestones/M018/phases/P03/tasks/T03-verifiers-and-summary-SUMMARY.md"
duration: "~5h"
verification_result: pass
observability_surfaces: "execution-log.jsonl: payload_breakdown.tier1_savings_tokens additive, payload_breakdown.tier1_invocations additive, tier_preservation_violation record_type"
completed_at: "{{ISO 8601 timestamp}}"
---

# Phase Summary: M018/P03 — Tier 1 Microcompact

## Closure summary
... (≥ 30 lines describing what landed; reference T01/T02/T03 and how they
compose; name the verifier roster; note that filter + tier1 are now both
live in every dispatch).
```

The summary body must include the literal string `tier1_savings_tokens` (artifact-must-have).

### Step 6 — Run the full verifier suite

```
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P03/
```

Expected: every truth `Check:` exits 0; every artifact passes its existence + line-count + substring check; every key link resolves. Output ends with `PASS: all must-haves satisfied for P03`.

If any verifier fails, fix the underlying code (T01/T02 may need touch-ups) and re-run. Do not relax the verifier; the must-have is the contract.

## Must-Haves

(All seven phase-level truths from `P03-PLAN.md` map to T03's verifier files. T03 ships every verifier and the phase summary that closes the must-have set.)

## Verification

- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P03/` — PASS.
- `bash scripts/state/derive-phase.sh .orchestrator/milestones/M018/` — outputs `phase-complete`.

## Inputs

### From Previous Tasks

- `scripts/dispatch/build-context.sh` (from T01) — Key API: `_bc_apply_tier1 <payload_capture_path>` rewrites in place; honors `COMPRESSION_ENABLED`/`TIER1_ENABLED` short-circuit; writes stats to `$TMPDIR_BUILD/_tier1_stats.txt`. `_bc_emit_payload_breakdown` emits `tier1_savings_tokens` and `tier1_invocations` integer fields.
- `.orchestrator/config.yml` (from T01) — carries `compression.tier1.{enabled,inline_threshold_tokens,preview_lines,cache_dir}`.
- `scripts/util/cache-prune.sh` (from T02) — Key API: `cache-prune.sh [--max-age <N>{d|h|m}] [--dry-run]`; reads `compression.tier1.cache_dir` from config; prunes mtime-aged files; idempotent.

### From Disk (Pre-existing)

- `scripts/lib/preservation-check.sh` — `pres_check_section`, `pres_emit_violation` (P02 library; T03 verifier 3.6 stubs both for the failure-path test).
- `tests/fixtures/m018-p02-baseline-payload.golden.txt` — golden payload re-used by verifier 3.5 disable-flag check.
- `scripts/util/dual-write-runtime-md.sh` — used in Step 4 to refresh CLAUDE.md + AGENTS.md.
- `scripts/verify/check-must-haves.sh` — phase-level verifier dispatcher; reads `P03-PLAN.md` truths and runs each Check.
- `templates/phase-summary.md` — base for `P03-SUMMARY.md` authoring.

## Constraints

- **AD-19 (single-script-file shape)**: every truth `Check:` IS a single-script-file invocation. T03's seven verifiers ARE those scripts; no inline compound bash, no plain subshells in verifier-body Check commands.
- **AP-009**: every verifier complies with the bash shape guard. Heredocs to `cat >` files: OK. `printf '%s\n' "$VAR" | grep -q PATTERN`: a single pipe, OK. `$(cmd | cmd)` inside the verifier-script body: BANNED.
- **Constitution Principle VI**: the only files T03 mutates outside the phase directory are `CLAUDE.md` + `AGENTS.md` (Step 4 dual-write — additive bullet inside the markers). All other touches are under `.orchestrator/milestones/M018/phases/P03/`, `tests/fixtures/m018-p03-tool-result/`, and `scripts/verify/`.
- **CON-5 (additive emitters)**: T03's `m018-p03-emitter-additivity.sh` enforces this contract — pre-T01 fields still present; new fields are additions, not replacements.
- **Verifier independence**: each verifier stages its own `mktemp -d` fixture root and cleans up via the OS's tmp-cleanup. No verifier shares state with another.

## Expected Output

- All seven verifier scripts under `scripts/verify/m018-p03-*.sh` exist, are executable, AP-009-clean, and exit 0 on PASS.
- `tests/fixtures/m018-p03-tool-result/dispatch-payload-fixture.md` exists.
- `tests/fixtures/m018-p03-tool-result/README.md` exists.
- `scripts/verify/_helpers/m018-p03-build-fixture.sh` exists and is executable.
- [`.orchestrator/milestones/M018/phases/P03/P03-SUMMARY.md`](../../../../../milestones/M018/phases/P03/P03-SUMMARY.md) exists, ≥ 40 lines, contains `tier1_savings_tokens`.
- `CLAUDE.md` + `AGENTS.md` `recent-changes` blocks both name M018/P03 (or tier1).
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P03/` exits 0; output ends with `PASS: all must-haves satisfied`.
- `bash scripts/state/derive-phase.sh .orchestrator/milestones/M018/` outputs `phase-complete`.
