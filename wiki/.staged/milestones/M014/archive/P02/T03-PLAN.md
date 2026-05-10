---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P02"
milestone: "M014"
name: "Patch consolidate-artifacts.sh with recent-changes dual-write + unit_close emission"
depends_on: ["T01"]
---

## Prerequisites

- T01 has shipped the write-site manifest listing `scripts/knowledge/consolidate-artifacts.sh` as a `recent-changes` region writer.
- P01 has shipped `scripts/util/dual-write-runtime-md.sh` (full FR-12 surface) and the `recent-changes` marker convention is already in use by `scripts/specify/specify.sh`.
- `scripts/knowledge/consolidate-artifacts.sh` currently has 187 lines; its final stdout line is `CONSOLIDATE: $MILESTONE_ID consolidated, $archived_count phases archived` at line 187.
- `.orchestrator/execution-log.jsonl` is the [M019](../../../../milestones/M019/index.md) Tier 1 append target. JSONL records for `unit_close` events follow the shape:
  ```
  {"command":"<command-name>","unit_type":"command","milestone":"<M###>","elapsed_ms":<N>,"source":"runtime",...}
  ```

## Description

Wire the `recent-changes` dual-write region into `consolidate-artifacts.sh`. After the existing knowledge-lifecycle advisory output and before the final stdout confirmation, the script appends a one-line entry to the marker-bounded region of both `CLAUDE.md` and `AGENTS.md` at the project root, documenting the milestone close.

Also emit a single `unit_close` JSONL record to `.orchestrator/execution-log.jsonl` with the M019 Tier 1 shape carrying `{command, milestone_id, dual_writes, reduction_pct, archived_count, elapsed_ms, source: "runtime"}`. The emission is defensive — if the append fails (readonly filesystem, missing state dir) the script still exits 0 with a WARN line.

## Steps

### Step 1: Patch `scripts/knowledge/consolidate-artifacts.sh`

Capture start-of-run epoch milliseconds for elapsed_ms computation. Near the top of the script (after `ORCH_ROOT="$1"` / `MILESTONE_ID="$2"`, line 45), insert:

```bash
START_EPOCH_MS=$(date +%s)000
```

(macOS `date` does not support `%N` for milliseconds in Bash 3.2; using second-resolution with `000` suffix is the accepted project precedent — see M016/[M021](../../../../milestones/M021/index.md) event emitters.)

After line 181 (`echo "CONSOLIDATE: compute-staleness.sh not found, skipping staleness check" >&2`) and before line 184 (`echo "CONSOLIDATE: ${size_before_bytes} → ${size_after_bytes} (${reduction}% reduction)" >&2`), insert:

```bash
# --- Dual-write Recent Changes entry (M014/P02 FR-12) ---
DUAL_WRITE_HELPER="$PROJECT_ROOT/scripts/util/dual-write-runtime-md.sh"
DUAL_WRITES=0
if [ -x "$DUAL_WRITE_HELPER" ]; then
  FRAG_FILE="$(mktemp)"
  # Build single-line Recent Changes entry. Appended above the closing marker;
  # existing region entries preserved (the helper replaces the region wholesale,
  # so we read-append-write via a temp file that concatenates existing region
  # content with the new entry line).
  EXISTING_REGION="$(mktemp)"
  if [ -f "$PROJECT_ROOT/CLAUDE.md" ]; then
    awk '/^# >>> orchestrator:recent-changes >>>/ { in_r=1; next } /^# <<< orchestrator:recent-changes <<</ { in_r=0; next } in_r==1 { print }' \
      "$PROJECT_ROOT/CLAUDE.md" > "$EXISTING_REGION"
  fi
  {
    cat "$EXISTING_REGION"
    printf -- '- %s: milestone consolidated (%d%% reduction, %d phases archived)\n' \
      "$MILESTONE_ID" "$reduction" "$archived_count"
  } > "$FRAG_FILE"

  if bash "$DUAL_WRITE_HELPER" \
      --marker recent-changes \
      --content "$FRAG_FILE" \
      --root "$PROJECT_ROOT" \
      --file CLAUDE.md --file AGENTS.md \
      >/dev/null 2>&1; then
    DUAL_WRITES=2
  else
    if bash "$DUAL_WRITE_HELPER" \
        --marker recent-changes \
        --content "$FRAG_FILE" \
        --root "$PROJECT_ROOT" \
        --file CLAUDE.md \
        >/dev/null 2>&1; then
      DUAL_WRITES=1
    else
      echo "WARN: consolidate dual-write recent-changes failed; continuing" >&2
    fi
  fi
  rm -f "$FRAG_FILE" "$EXISTING_REGION"
else
  echo "SKIPPED: dual-write-runtime-md.sh not executable (consolidate)" >&2
fi

# --- Emit unit_close JSONL record (M014/P02 FR-16 / M019 Tier 1) ---
END_EPOCH_MS=$(date +%s)000
ELAPSED_MS=$((END_EPOCH_MS - START_EPOCH_MS))
LOG_FILE="$ORCH_ROOT/execution-log.jsonl"
mkdir -p "$ORCH_ROOT"
if ! printf '{"command":"orchestrator:consolidate","unit_type":"command","milestone":"%s","dual_writes":%d,"reduction_pct":%d,"archived_count":%d,"elapsed_ms":%d,"source":"runtime"}\n' \
    "$MILESTONE_ID" "$DUAL_WRITES" "$reduction" "$archived_count" "$ELAPSED_MS" \
    >> "$LOG_FILE" 2>/dev/null; then
  echo "WARN: failed to append unit_close record to $LOG_FILE" >&2
fi
```

### Step 2: Create `scripts/verify/m014-p02-consolidate-dual-write.sh`

Verbatim body (hermetic test against a scratch milestone):

```bash
#!/usr/bin/env bash
# Gate: verify consolidate-artifacts.sh dual-writes recent-changes + emits unit_close.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONSOLIDATE="${PROJECT_ROOT}/scripts/knowledge/consolidate-artifacts.sh"
HELPER="${PROJECT_ROOT}/scripts/util/dual-write-runtime-md.sh"

if [ ! -f "$CONSOLIDATE" ]; then echo "FAIL: consolidate-artifacts.sh missing" >&2; exit 1; fi
if [ ! -x "$HELPER" ]; then echo "FAIL: dual-write helper missing" >&2; exit 1; fi

# Shape checks on the script source.
grep -q 'dual-write-runtime-md.sh' "$CONSOLIDATE" || { echo "FAIL: consolidate does not reference helper" >&2; exit 1; }
grep -q 'recent-changes'           "$CONSOLIDATE" || { echo "FAIL: consolidate does not use recent-changes marker" >&2; exit 1; }
grep -q 'unit_close\|\"command\":\"orchestrator:consolidate\"' "$CONSOLIDATE" || { echo "FAIL: consolidate does not emit unit_close record" >&2; exit 1; }

# Hermetic integration: build a scratch milestone that consolidate can process.
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

# Set up a minimal consolidatable milestone fixture.
ORCH="$SCRATCH/.orchestrator"
MDIR="$ORCH/milestones/M999"
mkdir -p "$MDIR/phases/P01/tasks"

cat > "$MDIR/M999-ROADMAP.md" <<'EOF'
---
schema_version: "1.0"
type: roadmap
milestone: "M999"
---
## Phases
- P01 complete risk=low depends_on=[]
EOF

cat > "$MDIR/phases/P01/P01-PLAN.md" <<'EOF'
# P01 Plan
Content to archive.
EOF

cat > "$MDIR/phases/P01/P01-SUMMARY.md" <<'EOF'
---
schema_version: "1.0"
type: phase-summary
---
Phase summary preserved.
EOF

# Seed CLAUDE.md with an empty marker region.
cat > "$SCRATCH/CLAUDE.md" <<'EOF'
# Scratch project
Pre-existing outside content.

# >>> orchestrator:recent-changes >>>
- existing-entry: preserved
# <<< orchestrator:recent-changes <<<

## Recent Changes
Outside-marker section — preserved byte-for-byte.
EOF

# Capture outside-markers shasum.
outside_bytes() {
  awk '/^# >>> orchestrator:/ { in_r=1; next } /^# <<< orchestrator:/ { in_r=0; next } in_r != 1 { print }' "$1"
}
REF_SHA="$(outside_bytes "$SCRATCH/CLAUDE.md" | shasum -a 256 | awk '{print $1}')"

# Run consolidate against the scratch project.
bash "$CONSOLIDATE" "$ORCH" M999 >/dev/null 2>&1
RC=$?
if [ $RC -ne 0 ]; then echo "FAIL: consolidate exited non-zero ($RC)" >&2; exit 1; fi

# Assertions.
if ! grep -qF '# >>> orchestrator:recent-changes >>>' "$SCRATCH/CLAUDE.md"; then
  echo "FAIL: CLAUDE.md missing recent-changes marker" >&2; exit 1
fi
if ! grep -qE '^- M999: milestone consolidated' "$SCRATCH/CLAUDE.md"; then
  echo "FAIL: CLAUDE.md missing new consolidate entry" >&2; exit 1
fi
if ! grep -qE '^- existing-entry: preserved' "$SCRATCH/CLAUDE.md"; then
  echo "FAIL: existing region entry was not preserved on append" >&2; exit 1
fi
if [ ! -f "$SCRATCH/AGENTS.md" ]; then
  echo "FAIL: AGENTS.md not created by consolidate dual-write" >&2; exit 1
fi
if ! grep -qE '^- M999: milestone consolidated' "$SCRATCH/AGENTS.md"; then
  echo "FAIL: AGENTS.md missing new consolidate entry" >&2; exit 1
fi

POST_SHA="$(outside_bytes "$SCRATCH/CLAUDE.md" | shasum -a 256 | awk '{print $1}')"
if [ "$REF_SHA" != "$POST_SHA" ]; then
  echo "FAIL: outside-markers bytes diverged after consolidate dual-write" >&2; exit 1
fi

# Execution-log assertion.
LOG_FILE="$ORCH/execution-log.jsonl"
if [ ! -f "$LOG_FILE" ]; then
  echo "FAIL: execution-log.jsonl not created" >&2; exit 1
fi
if ! grep -q '"command":"orchestrator:consolidate"' "$LOG_FILE"; then
  echo "FAIL: unit_close record not appended" >&2; exit 1
fi
if ! grep -q '"milestone":"M999"' "$LOG_FILE"; then
  echo "FAIL: unit_close record missing milestone field" >&2; exit 1
fi

echo "PASS: consolidate dual-writes recent-changes + emits unit_close record"
exit 0
```

Make executable.

## Must-Haves

- `scripts/knowledge/consolidate-artifacts.sh` references `scripts/util/dual-write-runtime-md.sh`, uses `--marker recent-changes`, and appends new entries above the closing marker preserving existing region content
- The script emits exactly one `unit_close` JSONL record per invocation to `$ORCH_ROOT/execution-log.jsonl` with `{command, milestone, dual_writes, reduction_pct, archived_count, elapsed_ms, source}` fields
- Running against a hermetic scratch milestone: (a) creates AGENTS.md, (b) preserves existing region entries on append, (c) preserves outside-markers bytes on CLAUDE.md, (d) appends the unit_close record to execution-log.jsonl
- Modified script passes `scripts/verify/anti-pattern-lint.sh`
- Gate verifier exits 0

## Verification

```
bash scripts/verify/m014-p02-consolidate-dual-write.sh
```

Expected: `PASS: consolidate dual-writes recent-changes + emits unit_close record`, exit 0.

```
bash scripts/verify/anti-pattern-lint.sh --fixture scripts/knowledge/consolidate-artifacts.sh
```

Expected: exit 0.

## Inputs

### From Previous Tasks

- [`.orchestrator/milestones/M014/phases/P02/WRITE-SITES.md`](../../../../milestones/M014/phases/P02/WRITE-SITES.md) (from T01) — lists consolidate-artifacts.sh as a `recent-changes` call site.

### From Disk (Pre-existing)

- `scripts/util/dual-write-runtime-md.sh` — P01 helper. Invocation: `--marker recent-changes --content <tmp> --root "$PROJECT_ROOT" --file CLAUDE.md --file AGENTS.md`.
- `scripts/knowledge/consolidate-artifacts.sh` — existing consolidation script. The patch inserts one block before the final stdout line and extends the preamble with a `START_EPOCH_MS` capture.
- `.orchestrator/execution-log.jsonl` — M019 Tier 1 append target. The patch creates the parent dir if missing and appends a JSONL record.
- `scripts/verify/anti-pattern-lint.sh` — lint surface.

## Constraints

- Bash 3.2 compatible. Block uses `printf`, `awk`, `cat`, `mktemp`, `rm -f`, plain `if` — no process substitution, no `$(... | ...)` with piped inner.
- Append semantics: the dual-write helper replaces the region wholesale (full-rewrite), so the patch reads existing region content first, appends the new entry, then passes the concatenation to the helper. This preserves every previous Recent Changes entry byte-for-byte.
- The millisecond elapsed calculation uses `$(date +%s)000` second-resolution with `000` suffix — the project convention for Bash 3.2 where `%N` is absent on macOS.
- The `unit_close` record is best-effort: if append fails, emit a `WARN:` line and continue with exit 0 (consolidation itself is not blocked by observability failure).
- Passes `scripts/verify/anti-pattern-lint.sh`.

## Expected Output

Files modified:

1. `scripts/knowledge/consolidate-artifacts.sh` — START_EPOCH_MS capture near top + dual-write block + unit_close emission block (~50 lines added total)

Files created:

2. `scripts/verify/m014-p02-consolidate-dual-write.sh` — gate verifier (~95 lines, executable)

Modified script passes anti-pattern-lint; gate verifier exits 0.
