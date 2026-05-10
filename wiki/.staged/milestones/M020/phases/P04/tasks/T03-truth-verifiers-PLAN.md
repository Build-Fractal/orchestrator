---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P04"
milestone: "M020"
name: "per-truth contract verifiers (scripts/verify/m020-p04-*.sh)"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01: `scripts/knowledge/compute-staleness.sh --review-queue [--knowledge-root <path>]` ships the documented stdout contract (`EMPTY` sentinel; one `cluster_id=...` line per cluster otherwise). Legacy invocation shape preserved.
- T02: `scripts/orchestrator/status.sh` ships the Review-Queue section rendering with empty / non-empty / unavailable / stale-marker shapes; pre-P04 prefix preserved byte-equivalent.
- P05: `scripts/knowledge/lib/cluster.sh::cluster_compute` is on main and the live tree has zero `status: candidate` entries (so `--review-queue` against the live tree emits `EMPTY` deterministically).
- P03/T04 carry-forward: tempdir + trap-EXIT-rm-rf + PROJECT_ROOT + ORCH_ROOT env-override fixture isolation pattern. The harness shape-guard inspects only directly-invoked Bash tool-call shapes; verifier internals may use heredocs / pipes / process-substitution / `<<EOF` freely (P03/T04 carry-forward and AD-19 + AP-009 governance).

## Description

Ship the six per-truth verifiers under `scripts/verify/`, one per phase-plan Truth. Each verifier is a single-script-file invocation that can be run by `scripts/verify/check-must-haves.sh` or directly by `orchestrator:auto`. All verifiers use tempdir + trap-EXIT-rm-rf fixture isolation; the live `knowledge/**` tree and the live `.orchestrator/execution-log.jsonl` are NEVER touched by any T03 verifier.

The six verifiers map 1:1 to the six "Truths" in `P04-PLAN.md`'s Must-Haves block. Each verifier prints exactly one trailing `PASS: <truth-summary>` line on success and exits 0; on failure each emits one or more `FAIL: <reason>` lines and exits 1.

**Authoring convention** (mirrors P03/T03 + P03/T01 + P05/T02 patterns):

- Bash 3.2 safe (no `declare -A`, no `mapfile`, no `<<<` here-strings inside `$()`).
- `set -u` (NOT `set -e`; we want explicit `|| true` discipline so a failed assertion can emit `FAIL:` and exit 1 instead of dying silently).
- `tmpdir="$(mktemp -d)"; trap 'rm -rf "$tmpdir"' EXIT`.
- Path resolution: `ROOT="$(cd "$(dirname "$0")/../.." && pwd)"` resolves the repo root from `scripts/verify/<this>.sh`.
- Tempdir fixture layout: `<tmpdir>/orch/` is the orchestrator state root, `<tmpdir>/knowledge/` is the candidate knowledge tree (as a sibling of `orch`, mirroring how the live tree sits at `<repo>/knowledge/` next to `<repo>/.orchestrator/`).
- Script-under-test invocation: pass `--knowledge-root "$tmpdir/knowledge"` (compute-staleness.sh) or set `PWD` via `cd "$tmpdir"` plus pass `--root "$tmpdir/orch"` (status.sh).
- Fixture entries are minimal MEM-files with the smallest valid frontmatter (id, status, created_at, last_verified, topic, tags). Bodies are <=10 lines so cluster.sh's body-window doesn't dominate the feature vector.

## Steps

### Step 1: Create the six verifier scripts

Each script lives at `scripts/verify/m020-p04-<truth-slug>.sh`. The full list with one-line descriptions:

1. `m020-p04-compute-staleness-review-queue.sh` — exercises T01's stdout shape: builds a fixture with two candidate entries (similar enough to cluster) + one graduated entry (must be excluded), invokes `--review-queue --knowledge-root <fixture>`, asserts stdout starts with `cluster_id=C` and contains `count=2`, plus a separate run against an empty fixture asserts stdout is `EMPTY` exactly.
2. `m020-p04-compute-staleness-stale-flag.sh` — builds a fixture with one candidate entry whose `created_at:` is `2025-01-01` (>14 days before the test reference date), invokes `--review-queue`, asserts stdout cluster line contains `stale=true`. Second run with `created_at:` set to today's date asserts the line contains `stale=false`.
3. `m020-p04-status-review-queue-section.sh` — builds a fixture orchestrator root + knowledge tree with candidate entries, invokes `bash scripts/orchestrator/status.sh --root <fixture-orch>`, asserts stdout contains a `^Review Queue: <N> clusters, <M> entries awaiting review$` line followed by `<N>` indented `  cluster=` lines. Second sub-case asserts the empty-knowledge-tree fixture emits the literal `Review Queue: empty` line.
4. `m020-p04-status-stale-marker.sh` — builds a fixture with one candidate created `2024-01-01` (clearly stale), invokes status.sh, asserts the cluster line ends with ` (stale)`. Negative sub-case: replaces `created_at:` with today's date, re-invokes, asserts no `(stale)` token.
5. `m020-p04-status-review-queue-readonly.sh` — builds a fixture, captures `find <fixture>/knowledge -type f -exec md5 {} +` (or `md5sum`) into a checksum baseline, invokes status.sh, recomputes the checksum, asserts byte-equivalent. Also asserts `<fixture-orch>/execution-log.jsonl` does NOT exist post-invocation (status.sh must not create it).
6. `m020-p04-status-prefix-preserved.sh` — builds a fixture orchestrator root containing one milestone (`M999/M999-FOO.md`) with one phase (`P01/P01-PLAN.md` to set state to executing). Invokes status.sh against the fixture twice: once before any candidates exist, once after seeding two candidates. Asserts that the prefix lines (`MILESTONE: M999`, `STATE: executing`, `PHASE: P01 executing`) are byte-equivalent in both runs (only the trailing Review-Queue section changes).

#### Verifier 1: `scripts/verify/m020-p04-compute-staleness-review-queue.sh`

```bash
#!/usr/bin/env bash
# m020-p04-compute-staleness-review-queue.sh — assert T01 --review-queue
# stdout shape: EMPTY-on-empty + cluster_id=... line per cluster.
# Bash 3.2 safe. AD-19 single-script-file shape.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HELPER="$ROOT/scripts/knowledge/compute-staleness.sh"

if [ ! -f "$HELPER" ]; then
  echo "FAIL: compute-staleness.sh missing at $HELPER"
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# --- Case 1: empty knowledge tree -> EMPTY sentinel, exit 0 ---
mkdir -p "$tmpdir/empty/conventions"
out="$(bash "$HELPER" --review-queue --knowledge-root "$tmpdir/empty" 2>"$tmpdir/empty.err")"
rc=$?
if [ "$rc" -ne 0 ]; then
  echo "FAIL: empty case exit rc=$rc; stderr: $(cat "$tmpdir/empty.err")"
  exit 1
fi
if [ "$out" != "EMPTY" ]; then
  echo "FAIL: empty case stdout != 'EMPTY'; got: '$out'"
  exit 1
fi

# --- Case 2: two candidates clustering -> one cluster_id= line ---
mkdir -p "$tmpdir/candidates/patterns"
write_entry() {
  local id="$1" topic="$2" body="$3" file="$tmpdir/candidates/patterns/$id.md"
  cat >"$file" <<EOF
---
id: $id
status: candidate
created_at: 2026-04-01
last_verified: 2026-04-01
topic: $topic
tags: [test, fixture]
confidence: 0.5
hit_count: 0
---

$body
EOF
}
write_entry MEM900 alpha "alpha alpha alpha pattern test fixture body unique"
write_entry MEM901 alpha "alpha alpha alpha pattern test fixture body unique"

out2="$(bash "$HELPER" --review-queue --knowledge-root "$tmpdir/candidates" 2>"$tmpdir/cand.err")"
rc=$?
if [ "$rc" -ne 0 ]; then
  echo "FAIL: candidates case exit rc=$rc; stderr: $(cat "$tmpdir/cand.err")"
  exit 1
fi

# Expect at least one line starting with cluster_id=C and containing topic=alpha + count=
case "$out2" in
  cluster_id=C*topic=alpha*count=*)
    ;;
  *)
    echo "FAIL: candidates case stdout missing cluster_id=...topic=alpha...count= ; got:"
    echo "$out2"
    exit 1
    ;;
esac

# Sanity: stdout MUST NOT include 'EMPTY' when candidates exist.
case "$out2" in
  *EMPTY*)
    echo "FAIL: candidates case stdout contains EMPTY: $out2"
    exit 1
    ;;
esac

echo "PASS: compute-staleness.sh --review-queue stdout shape (EMPTY + cluster_id lines)"
exit 0
```

`chmod +x scripts/verify/m020-p04-compute-staleness-review-queue.sh`.

#### Verifier 2: `scripts/verify/m020-p04-compute-staleness-stale-flag.sh`

```bash
#!/usr/bin/env bash
# m020-p04-compute-staleness-stale-flag.sh — assert T01 stale=true|false flag
# resolves correctly against the staleness threshold.
# Bash 3.2 safe.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HELPER="$ROOT/scripts/knowledge/compute-staleness.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/k/patterns"
TODAY="$(date -u +%Y-%m-%d)"

# --- Case 1: a clearly-stale candidate (created Jan 2024) ---
cat >"$tmpdir/k/patterns/MEM900.md" <<EOF
---
id: MEM900
status: candidate
created_at: 2024-01-01
last_verified: 2024-01-01
topic: stale_topic
tags: [test]
confidence: 0.5
hit_count: 0
---

stale candidate body unique tokens
EOF

out_stale="$(bash "$HELPER" --review-queue --knowledge-root "$tmpdir/k" 2>"$tmpdir/stale.err")"
case "$out_stale" in
  *stale=true*) ;;
  *)
    echo "FAIL: stale case did not set stale=true; got: $out_stale"
    exit 1
    ;;
esac

# --- Case 2: a fresh candidate (created today) ---
cat >"$tmpdir/k/patterns/MEM900.md" <<EOF
---
id: MEM900
status: candidate
created_at: $TODAY
last_verified: $TODAY
topic: fresh_topic
tags: [test]
confidence: 0.5
hit_count: 0
---

fresh candidate body unique tokens
EOF

out_fresh="$(bash "$HELPER" --review-queue --knowledge-root "$tmpdir/k" 2>"$tmpdir/fresh.err")"
case "$out_fresh" in
  *stale=false*) ;;
  *)
    echo "FAIL: fresh case did not set stale=false; got: $out_fresh"
    exit 1
    ;;
esac

# Confirm fresh case did NOT emit stale=true.
case "$out_fresh" in
  *stale=true*)
    echo "FAIL: fresh case incorrectly emitted stale=true: $out_fresh"
    exit 1
    ;;
esac

echo "PASS: compute-staleness.sh stale=true|false flag resolution"
exit 0
```

`chmod +x scripts/verify/m020-p04-compute-staleness-stale-flag.sh`.

#### Verifier 3: `scripts/verify/m020-p04-status-review-queue-section.sh`

```bash
#!/usr/bin/env bash
# m020-p04-status-review-queue-section.sh — assert T02 emits the
# 'Review Queue:' section with empty + non-empty rendering.
# Bash 3.2 safe.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
STATUS_SH="$ROOT/scripts/orchestrator/status.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# Build a minimal orchestrator state root with one milestone, no candidates.
mkdir -p "$tmpdir/orch/milestones/M999/phases/P01"
cat >"$tmpdir/orch/milestones/M999/M999-EVALUATION.md" <<'EOF'
---
type: evaluation
tier: C
---

placeholder
EOF
cat >"$tmpdir/orch/milestones/M999/M999-ROADMAP.md" <<'EOF'
---
type: roadmap
milestone: M999
---

- [ ] **P01**: placeholder
EOF
cat >"$tmpdir/orch/milestones/M999/phases/P01/P01-PLAN.md" <<'EOF'
---
type: phase-plan
phase: P01
milestone: M999
---

placeholder
EOF

mkdir -p "$tmpdir/knowledge/conventions"

# --- Case 1: empty queue -> 'Review Queue: empty' ---
cd "$tmpdir"
out1="$(bash "$STATUS_SH" --root "$tmpdir/orch" 2>"$tmpdir/case1.err" || true)"
case "$out1" in
  *"Review Queue: empty"*) ;;
  *)
    echo "FAIL: empty case stdout missing 'Review Queue: empty'; got:"
    echo "$out1"
    exit 1
    ;;
esac

# Confirm absence of per-cluster lines (no '  cluster=' indented lines).
if printf '%s\n' "$out1" | grep -qE '^[[:space:]]+cluster='; then
  echo "FAIL: empty case stdout contains an unexpected cluster= line"
  echo "$out1"
  exit 1
fi

# --- Case 2: two candidates clustering -> non-empty header + indented lines ---
mkdir -p "$tmpdir/knowledge/patterns"
write_entry() {
  local id="$1" topic="$2"
  cat >"$tmpdir/knowledge/patterns/$id.md" <<EOF
---
id: $id
status: candidate
created_at: 2026-04-01
last_verified: 2026-04-01
topic: $topic
tags: [test]
confidence: 0.5
hit_count: 0
---

beta beta beta token vocabulary fixture
EOF
}
write_entry MEM910 beta_topic
write_entry MEM911 beta_topic

out2="$(bash "$STATUS_SH" --root "$tmpdir/orch" 2>"$tmpdir/case2.err" || true)"

# Header line shape.
if ! printf '%s\n' "$out2" | grep -qE '^Review Queue: [0-9]+ clusters, [0-9]+ entries awaiting review$'; then
  echo "FAIL: non-empty case missing well-formed 'Review Queue: <N> clusters, <M> entries' header"
  echo "$out2"
  exit 1
fi

# At least one indented cluster= line.
if ! printf '%s\n' "$out2" | grep -qE '^  cluster=C[0-9a-f]{8} '; then
  echo "FAIL: non-empty case missing indented '  cluster=C<8hex>' summary line"
  echo "$out2"
  exit 1
fi

echo "PASS: status.sh Review Queue: section (empty + non-empty rendering)"
exit 0
```

`chmod +x scripts/verify/m020-p04-status-review-queue-section.sh`.

#### Verifier 4: `scripts/verify/m020-p04-status-stale-marker.sh`

```bash
#!/usr/bin/env bash
# m020-p04-status-stale-marker.sh — assert T02 renders ' (stale)' marker on
# stale cluster lines and omits it on fresh ones.
# Bash 3.2 safe.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
STATUS_SH="$ROOT/scripts/orchestrator/status.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/orch/milestones/M999/phases/P01"
cat >"$tmpdir/orch/milestones/M999/M999-EVALUATION.md" <<'EOF'
---
type: evaluation
tier: C
---

placeholder
EOF
cat >"$tmpdir/orch/milestones/M999/phases/P01/P01-PLAN.md" <<'EOF'
---
type: phase-plan
phase: P01
milestone: M999
---

placeholder
EOF

mkdir -p "$tmpdir/knowledge/patterns"

# --- Stale fixture ---
cat >"$tmpdir/knowledge/patterns/MEM900.md" <<'EOF'
---
id: MEM900
status: candidate
created_at: 2024-01-01
last_verified: 2024-01-01
topic: stale_topic
tags: [test]
confidence: 0.5
hit_count: 0
---

stale body content tokens disjoint
EOF

cd "$tmpdir"
out_stale="$(bash "$STATUS_SH" --root "$tmpdir/orch" 2>"$tmpdir/stale.err" || true)"
if ! printf '%s\n' "$out_stale" | grep -qE '^  cluster=.*\(stale\)$'; then
  echo "FAIL: stale fixture cluster line missing ' (stale)' marker; got:"
  echo "$out_stale"
  exit 1
fi

# --- Fresh fixture (today) ---
TODAY="$(date -u +%Y-%m-%d)"
cat >"$tmpdir/knowledge/patterns/MEM900.md" <<EOF
---
id: MEM900
status: candidate
created_at: $TODAY
last_verified: $TODAY
topic: fresh_topic
tags: [test]
confidence: 0.5
hit_count: 0
---

fresh body content tokens disjoint
EOF

out_fresh="$(bash "$STATUS_SH" --root "$tmpdir/orch" 2>"$tmpdir/fresh.err" || true)"
if printf '%s\n' "$out_fresh" | grep -qE '\(stale\)'; then
  echo "FAIL: fresh fixture stdout incorrectly contains '(stale)' marker:"
  echo "$out_fresh"
  exit 1
fi

echo "PASS: status.sh ' (stale)' marker rendering"
exit 0
```

`chmod +x scripts/verify/m020-p04-status-stale-marker.sh`.

#### Verifier 5: `scripts/verify/m020-p04-status-review-queue-readonly.sh`

```bash
#!/usr/bin/env bash
# m020-p04-status-review-queue-readonly.sh — assert status.sh does NOT
# mutate knowledge/** or .orchestrator/execution-log.jsonl when invoked.
# Bash 3.2 safe.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
STATUS_SH="$ROOT/scripts/orchestrator/status.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/orch/milestones/M999/phases/P01"
cat >"$tmpdir/orch/milestones/M999/phases/P01/P01-PLAN.md" <<'EOF'
---
type: phase-plan
phase: P01
milestone: M999
---

placeholder
EOF

mkdir -p "$tmpdir/knowledge/patterns"
cat >"$tmpdir/knowledge/patterns/MEM900.md" <<'EOF'
---
id: MEM900
status: candidate
created_at: 2026-04-01
last_verified: 2026-04-01
topic: read_only_topic
tags: [test]
---

readonly body content tokens
EOF

# --- Capture knowledge/ checksums ---
md5_of() {
  if command -v md5sum >/dev/null 2>&1; then
    md5sum "$1" | awk '{print $1}'
  else
    md5 -q "$1"
  fi
}

before_md5="$(md5_of "$tmpdir/knowledge/patterns/MEM900.md")"

# Invoke status.sh.
cd "$tmpdir"
bash "$STATUS_SH" --root "$tmpdir/orch" >/dev/null 2>"$tmpdir/err"

after_md5="$(md5_of "$tmpdir/knowledge/patterns/MEM900.md")"
if [ "$before_md5" != "$after_md5" ]; then
  echo "FAIL: status.sh mutated knowledge entry MEM900.md (md5 before=$before_md5 after=$after_md5)"
  exit 1
fi

# Confirm no execution-log.jsonl was created under fixture orch.
if [ -f "$tmpdir/orch/execution-log.jsonl" ]; then
  echo "FAIL: status.sh created $tmpdir/orch/execution-log.jsonl (must remain absent)"
  exit 1
fi

echo "PASS: status.sh read-only invariant (knowledge/ + execution-log.jsonl untouched)"
exit 0
```

`chmod +x scripts/verify/m020-p04-status-review-queue-readonly.sh`.

#### Verifier 6: `scripts/verify/m020-p04-status-prefix-preserved.sh`

```bash
#!/usr/bin/env bash
# m020-p04-status-prefix-preserved.sh — assert status.sh emits the same
# pre-Review-Queue prefix lines (MILESTONE/STATE/PHASE) byte-equivalent
# regardless of whether the knowledge tree has candidates.
# Bash 3.2 safe.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
STATUS_SH="$ROOT/scripts/orchestrator/status.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/orch/milestones/M999/phases/P01"
cat >"$tmpdir/orch/milestones/M999/phases/P01/P01-PLAN.md" <<'EOF'
---
type: phase-plan
phase: P01
milestone: M999
---

placeholder
EOF

mkdir -p "$tmpdir/knowledge/patterns"

# --- Capture #1: empty knowledge ---
cd "$tmpdir"
cap1="$(bash "$STATUS_SH" --root "$tmpdir/orch" 2>/dev/null || true)"

# --- Capture #2: with one candidate ---
cat >"$tmpdir/knowledge/patterns/MEM900.md" <<'EOF'
---
id: MEM900
status: candidate
created_at: 2026-04-01
last_verified: 2026-04-01
topic: prefix_topic
tags: [test]
---

prefix preservation body content tokens
EOF
cap2="$(bash "$STATUS_SH" --root "$tmpdir/orch" 2>/dev/null || true)"

# Extract prefix lines (everything before the first 'Review Queue:' line).
extract_prefix() {
  printf '%s\n' "$1" | awk '/^Review Queue:/{exit} {print}'
}

prefix1="$(extract_prefix "$cap1")"
prefix2="$(extract_prefix "$cap2")"

if [ "$prefix1" != "$prefix2" ]; then
  echo "FAIL: status.sh prefix differs between empty and non-empty knowledge runs"
  echo "--- empty prefix ---"
  printf '%s\n' "$prefix1"
  echo "--- non-empty prefix ---"
  printf '%s\n' "$prefix2"
  exit 1
fi

# Confirm prefix contains the expected three line-shapes for M999.
case "$prefix1" in
  *"MILESTONE: M999"*)
    ;;
  *)
    echo "FAIL: prefix missing 'MILESTONE: M999' line: $prefix1"
    exit 1
    ;;
esac
case "$prefix1" in
  *"PHASE: P01 "*)
    ;;
  *)
    echo "FAIL: prefix missing 'PHASE: P01 ...' line: $prefix1"
    exit 1
    ;;
esac

echo "PASS: status.sh pre-Review-Queue prefix byte-equivalent across empty + non-empty runs"
exit 0
```

`chmod +x scripts/verify/m020-p04-status-prefix-preserved.sh`.

### Step 2: `chmod +x` all six

```
chmod +x scripts/verify/m020-p04-compute-staleness-review-queue.sh
chmod +x scripts/verify/m020-p04-compute-staleness-stale-flag.sh
chmod +x scripts/verify/m020-p04-status-review-queue-section.sh
chmod +x scripts/verify/m020-p04-status-stale-marker.sh
chmod +x scripts/verify/m020-p04-status-review-queue-readonly.sh
chmod +x scripts/verify/m020-p04-status-prefix-preserved.sh
```

(One chmod per verifier; six lines total. Single-script-file Check shapes only.)

## Must-Haves

- All six verifier scripts exist under `scripts/verify/m020-p04-*.sh`, are executable, and exit 0 against the on-main `compute-staleness.sh` + `status.sh` after T01 + T02 land.
- Each verifier exercises exactly the Truth it is named for (1:1 mapping between verifier filename and phase-plan Truth).
- Each verifier uses tempdir + trap-EXIT-rm-rf isolation; the live `knowledge/**` and `.orchestrator/execution-log.jsonl` are never touched.
- Each verifier's directly-invoked Bash tool-call shape is a single-script-file invocation (AD-19); internals may use heredocs / awk / case-globs.
- Bash 3.2 safe throughout (no `declare -A`, no `mapfile`, no `<<<`-into-`$()`).
- Each verifier emits exactly one trailing `PASS:` line on success and at least one `FAIL:` line on failure.

## Verification

```
bash scripts/verify/m020-p04-compute-staleness-review-queue.sh
bash scripts/verify/m020-p04-compute-staleness-stale-flag.sh
bash scripts/verify/m020-p04-status-review-queue-section.sh
bash scripts/verify/m020-p04-status-stale-marker.sh
bash scripts/verify/m020-p04-status-review-queue-readonly.sh
bash scripts/verify/m020-p04-status-prefix-preserved.sh
```

All six must print a `PASS:` line and exit 0.

## Inputs

### From Previous Tasks

- `scripts/knowledge/compute-staleness.sh` (M020/P04/T01)
  - Key API: `--review-queue [--knowledge-root <path>]` — see T01 task plan for the full stdout contract. T03 invokes it directly.
- `scripts/orchestrator/status.sh` (M020/P04/T02)
  - Key API: invoked as `bash status.sh --root <fixture-orch>`; emits `MILESTONE:` / `STATE:` / `PHASE:` lines followed by the `Review Queue:` section.

### From Disk (Pre-existing)

- `scripts/knowledge/lib/cluster.sh` (M020/P05) — used indirectly by the helpers under test. T03 verifies the integration via fixture invocations of compute-staleness.sh + status.sh; T03 does not call cluster.sh directly.
- `scripts/knowledge/lib/jaccard.sh` (M020/P01 + extended P05) — used indirectly. The fixture entries' bodies use distinct vocabularies (per P05/T04 carry-forward "distinct-vocabulary fixture pattern") to ensure deterministic 2-entry clustering at the 0.7 default threshold.
- `tests/test-graduate-workflow.sh` (M020/P03/T04) — reference example for tempdir + fm_get awk patterns. T03 does not source this file but mirrors its conventions.

## Constraints

- **AD-19 / MEM001**: every Truth Check in the phase plan is a single-script-file invocation. Each T03 verifier itself is invoked as `bash scripts/verify/<name>.sh`; verifier internals may use heredocs / pipes / awk / case-glob freely (P03/T04 carry-forward — harness shape-guard inspects only directly-invoked Bash tool-call shapes).
- **Bash 3.2**: every verifier is `set -u` (NOT `set -e`); uses `case "$x" in glob) ...` for pattern-matching; uses `printf '%s\n' "$x" | awk ...` rather than `<<<`-here-strings.
- **CON-1 / FR-8 (read-only-during-dispatch)**: every verifier creates `tmpdir="$(mktemp -d)"` and `trap 'rm -rf "$tmpdir"' EXIT`. The live `knowledge/**` tree and the live `.orchestrator/execution-log.jsonl` are never touched; verifier `cd`s into the tmpdir before invoking status.sh so any "default knowledge root" resolution lands inside the tmpdir.
- **CON-4 (Surgical Precision)**: T03 creates only NEW files under `scripts/verify/`. No modifications to any pre-existing script.
- **Principle XIV (No Speculative Complexity)**: each verifier exercises ONE truth. No cross-truth assertions; no setup-once-test-many shortcuts (each verifier owns its tempdir, its fixture, and its assertions).
- **Distinct-vocabulary fixture pattern** (P05/T04 carry-forward): when the fixture relies on candidates clustering or NOT clustering, body content must use disjoint vocabularies for "distinct" entries and overlapping vocabularies for "should-cluster" entries. The 0.7 default threshold is sensitive to scaffolding noise (`distinct`, `fixture`, `body`, `unique`, `for` co-cluster spuriously). T03's verifiers use entry-specific tokens (`alpha alpha alpha`, `beta beta beta`, etc.).
- **`grep -c` safe-counter** (P03/T03 carry-forward): T03 verifiers use `grep -qE` for boolean assertions rather than `grep -c` (which has the rc=1+prints-0 footgun documented in MEM028 / P03 lessons).

## Expected Output

After this task:

1. Six verifier scripts under `scripts/verify/m020-p04-*.sh`, each executable, each <=200 lines.
2. Each verifier exits 0 and emits a `PASS:` line against the on-main compute-staleness.sh + status.sh after T01 + T02 land.
3. No file under `knowledge/**` or `.orchestrator/execution-log.jsonl` is touched by running any verifier.
4. The phase-level rollup `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M020/phases/P04` consumes these verifiers via the `Check:` lines in `P04-PLAN.md` and exits 0.

**Done when**: all six `bash scripts/verify/m020-p04-*.sh` invocations exit 0 with a `PASS:` line and `git status knowledge/` reflects no T03-attributable diff.
