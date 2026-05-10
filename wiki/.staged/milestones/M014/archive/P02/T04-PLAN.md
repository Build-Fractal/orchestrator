---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P02"
milestone: "M014"
name: "Extend check-docs.sh with drift pass + wire into run-doctor.sh + update commands/doctor.md"
depends_on: ["T01"]
---

## Prerequisites

- T01 has shipped the write-site manifest naming the two canonical marker regions (`project-identity`, `recent-changes`).
- `scripts/diagnostics/check-docs.sh` (from [M006](../../../../milestones/M006/index.md)) is the existing docs-completeness diagnostic. Its current output shape on exit 0 is `DOCTOR:DOCS status=ok found=<N> total=<N>`; on failure it exits 1 with missing-file listings.
- `scripts/diagnostics/run-doctor.sh` is the orchestrator of all diagnostic checks (14 `run_check` invocations). Each `run_check` takes (name, script, args, advisory-flag). The `Documentation Completeness` check at line 111 calls `check-docs.sh`.
- `commands/doctor.md` is the 31-line user-facing command document listing four check categories under `## What It Checks`.

## Description

Extend `scripts/diagnostics/check-docs.sh` with a new `--check drift` mode that performs FR-13 runtime-instruction drift detection between `CLAUDE.md` and `AGENTS.md`. Wire the new mode into `run-doctor.sh` as a `Runtime Instruction Drift` section (advisory). Update `commands/doctor.md` to document the new check.

The default no-flag invocation of `check-docs.sh` preserves M006 behavior byte-for-byte — the new mode is opt-in via `--check drift`. The drift pass detects three finding kinds: `missing_region` (marker present in one file only), `byte_divergence` (both markers present, region bytes differ), `unmatched_marker` (opening marker without closing). Findings are reported as warnings per FR-13 v1 stance; exit is 0 even on `warn` (escalation to fail is future-milestone work).

## Steps

### Step 1: Extend `scripts/diagnostics/check-docs.sh`

Current body (82 lines) performs only the docs-completeness pass. Extend to support two modes routed by an optional `--check <mode>` flag:

- `--check docs` (default when no flag) — runs existing M006 completeness pass
- `--check drift` — runs new FR-13 drift pass

Insert argument parsing additions near the top (before the existing `--root` case):

```bash
CHECK_MODE="docs"

while [ $# -gt 0 ]; do
  case "$1" in
    --root) PROJECT_ROOT="$2"; shift 2 ;;
    --check) CHECK_MODE="$2"; shift 2 ;;
    *) echo "check-docs.sh: unknown option: $1" >&2; exit 1 ;;
  esac
done
```

Then branch on `$CHECK_MODE`. The existing body (lines 28-81) becomes the `docs` branch. Add a new `drift` branch with the following body:

```bash
if [ "$CHECK_MODE" = "drift" ]; then
  CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"
  AGENTS_MD="$PROJECT_ROOT/AGENTS.md"

  # Skip gracefully if either file is absent.
  if [ ! -f "$CLAUDE_MD" ] || [ ! -f "$AGENTS_MD" ]; then
    reason="both-absent"
    if [ ! -f "$CLAUDE_MD" ] && [ -f "$AGENTS_MD" ]; then reason="CLAUDE.md-absent"; fi
    if [ -f "$CLAUDE_MD" ] && [ ! -f "$AGENTS_MD" ]; then reason="AGENTS.md-absent"; fi
    printf 'DOCTOR:DRIFT status=skip reason=%s regions=0 divergences=0\n' "$reason"
    exit 0
  fi

  # Discover every opening marker in either file.
  # Marker literal: `# >>> orchestrator:<region-name> >>>`
  regions_file="$(mktemp)"
  trap 'rm -f "$regions_file"' EXIT

  grep -hE '^# >>> orchestrator:[a-zA-Z0-9_-]+ >>>$' "$CLAUDE_MD" "$AGENTS_MD" 2>/dev/null \
    | sed -E 's/^# >>> orchestrator:([a-zA-Z0-9_-]+) >>>$/\1/' \
    | sort -u \
    > "$regions_file"

  regions_total=$(wc -l < "$regions_file" | tr -d ' ')
  divergences=0
  findings_file="$(mktemp)"
  trap 'rm -f "$regions_file" "$findings_file"' EXIT

  # Extract region bytes helper.
  extract_region() {
    file="$1"; name="$2"
    awk -v open="# >>> orchestrator:${name} >>>" -v close="# <<< orchestrator:${name} <<<" '
      $0 == open { in_r=1; next }
      $0 == close { in_r=0; next }
      in_r==1 { print }
    ' "$file"
  }

  # Walk each discovered region name.
  while IFS= read -r region; do
    if [ -z "$region" ]; then continue; fi

    c_has_open=0;  c_has_close=0
    a_has_open=0;  a_has_close=0
    grep -qF "# >>> orchestrator:${region} >>>" "$CLAUDE_MD" && c_has_open=1
    grep -qF "# <<< orchestrator:${region} <<<" "$CLAUDE_MD" && c_has_close=1
    grep -qF "# >>> orchestrator:${region} >>>" "$AGENTS_MD" && a_has_open=1
    grep -qF "# <<< orchestrator:${region} <<<" "$AGENTS_MD" && a_has_close=1

    # Unmatched markers within a single file.
    if [ "$c_has_open" -ne "$c_has_close" ]; then
      echo "DRIFT: unmatched_marker region=${region} file=CLAUDE.md" >&2
      divergences=$((divergences + 1))
    fi
    if [ "$a_has_open" -ne "$a_has_close" ]; then
      echo "DRIFT: unmatched_marker region=${region} file=AGENTS.md" >&2
      divergences=$((divergences + 1))
    fi

    # Region missing in one file.
    if [ "$c_has_open" -eq 1 ] && [ "$a_has_open" -eq 0 ]; then
      echo "DRIFT: missing_region region=${region} file=AGENTS.md" >&2
      divergences=$((divergences + 1))
      continue
    fi
    if [ "$a_has_open" -eq 1 ] && [ "$c_has_open" -eq 0 ]; then
      echo "DRIFT: missing_region region=${region} file=CLAUDE.md" >&2
      divergences=$((divergences + 1))
      continue
    fi

    # Both present + both matched — compare bytes.
    if [ "$c_has_open" -eq 1 ] && [ "$c_has_close" -eq 1 ] && \
       [ "$a_has_open" -eq 1 ] && [ "$a_has_close" -eq 1 ]; then
      c_sha="$(extract_region "$CLAUDE_MD" "$region" | shasum -a 256 | awk '{print $1}')"
      a_sha="$(extract_region "$AGENTS_MD" "$region" | shasum -a 256 | awk '{print $1}')"
      if [ "$c_sha" != "$a_sha" ]; then
        echo "DRIFT: byte_divergence region=${region} file=CLAUDE.md vs AGENTS.md" >&2
        divergences=$((divergences + 1))
      fi
    fi
  done < "$regions_file"

  status="ok"
  if [ "$divergences" -gt 0 ]; then status="warn"; fi

  printf 'DOCTOR:DRIFT status=%s regions=%d divergences=%d\n' \
    "$status" "$regions_total" "$divergences"

  # FR-13 v1: drift is advisory; exit 0 even on warn.
  exit 0
fi
```

The existing M006 pass remains the default and runs when `$CHECK_MODE = "docs"` (the current body at lines 28-81 is wrapped in an `if [ "$CHECK_MODE" = "docs" ]; then ... fi`).

### Step 2: Patch `scripts/diagnostics/run-doctor.sh`

Insert a new `run_check` line after the existing `run_check "Documentation Completeness"` at line 111 and before the `if [ -f "$PROJECT_ROOT/knowledge.db" ]` block at line 114:

```bash
run_check "Runtime Instruction Drift" "$SCRIPT_DIR/check-docs.sh" "--check drift --root $PROJECT_ROOT" "1"
```

Advisory flag `1` means drift findings do NOT count toward `checks_total` — they increment `advisory_warnings` and the overall health status remains `HEALTHY` even with drift present. This matches FR-13 v1 advisory stance.

The `run_check` function already parses `DOCTOR:` lines — `DOCTOR:DRIFT status=warn` triggers the `warn` branch which is already handled (sets `passed=0` — but the advisory flag means the warning counter increments without affecting pass/fail). Verify by reading the existing `run_check` body at lines 31-90.

### Step 3: Update `commands/doctor.md`

Under `## What It Checks` add a fifth bullet between the current 4th (Cost Spikes) and `## Usage`:

```markdown
5. **Runtime Instruction Drift**: `CLAUDE.md` and `AGENTS.md` marker-bounded region comparison (FR-13 advisory in v1). Detects missing regions, byte-divergence between matching regions, and unmatched markers. Surfaces findings under a `Runtime Instruction Drift` section in the doctor output; warnings count as advisory (do not fail the overall health status) until a future milestone escalates.
```

Also add a `## Referenced Scripts` section at the end (after `## When to Run`, before end of file):

```markdown
## Referenced Scripts

- `scripts/diagnostics/run-doctor.sh` — diagnostic orchestrator.
- `scripts/diagnostics/check-docs.sh` — documentation completeness + runtime instruction drift (`--check drift`).
```

### Step 4: Create `scripts/verify/m014-p02-check-docs-drift.sh`

Verbatim body:

```bash
#!/usr/bin/env bash
# Gate: verify check-docs.sh --check drift detects the three drift kinds.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CHECK="${PROJECT_ROOT}/scripts/diagnostics/check-docs.sh"

if [ ! -x "$CHECK" ]; then echo "FAIL: check-docs.sh missing or not executable" >&2; exit 1; fi

# Shape checks.
grep -q -- '--check' "$CHECK" || { echo "FAIL: --check flag not documented" >&2; exit 1; }
grep -q 'DOCTOR:DRIFT' "$CHECK" || { echo "FAIL: DOCTOR:DRIFT output line missing" >&2; exit 1; }
grep -q 'byte_divergence' "$CHECK" || { echo "FAIL: byte_divergence kind missing" >&2; exit 1; }
grep -q 'missing_region' "$CHECK" || { echo "FAIL: missing_region kind missing" >&2; exit 1; }
grep -q 'unmatched_marker' "$CHECK" || { echo "FAIL: unmatched_marker kind missing" >&2; exit 1; }

# Hermetic scenario 1: clean state (both files empty of markers) => status=ok regions=0.
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

cat > "$SCRATCH/CLAUDE.md" <<'EOF'
# plain CLAUDE.md
No markers here.
EOF
cat > "$SCRATCH/AGENTS.md" <<'EOF'
# plain AGENTS.md
No markers here.
EOF

OUT="$(bash "$CHECK" --check drift --root "$SCRATCH" 2>/dev/null)"
if ! echo "$OUT" | grep -q 'DOCTOR:DRIFT status=ok regions=0 divergences=0'; then
  echo "FAIL: clean scratch did not report status=ok" >&2
  echo "  got: $OUT" >&2
  exit 1
fi

# Scenario 2: matching regions => status=ok regions=1 divergences=0.
cat > "$SCRATCH/CLAUDE.md" <<'EOF'
# CLAUDE.md
# >>> orchestrator:recent-changes >>>
- entry-1: identical
# <<< orchestrator:recent-changes <<<
EOF
cat > "$SCRATCH/AGENTS.md" <<'EOF'
# AGENTS.md
# >>> orchestrator:recent-changes >>>
- entry-1: identical
# <<< orchestrator:recent-changes <<<
EOF

OUT="$(bash "$CHECK" --check drift --root "$SCRATCH" 2>/dev/null)"
if ! echo "$OUT" | grep -q 'DOCTOR:DRIFT status=ok regions=1 divergences=0'; then
  echo "FAIL: matching regions did not report status=ok" >&2
  echo "  got: $OUT" >&2
  exit 1
fi

# Scenario 3: byte divergence => status=warn divergences>=1.
cat > "$SCRATCH/AGENTS.md" <<'EOF'
# AGENTS.md
# >>> orchestrator:recent-changes >>>
- entry-1: DIFFERENT
# <<< orchestrator:recent-changes <<<
EOF

OUT="$(bash "$CHECK" --check drift --root "$SCRATCH" 2>/dev/null)"
if ! echo "$OUT" | grep -qE 'DOCTOR:DRIFT status=warn regions=1 divergences=[1-9]'; then
  echo "FAIL: byte divergence scenario did not report status=warn" >&2
  echo "  got: $OUT" >&2
  exit 1
fi

# Scenario 4: missing region in one file.
cat > "$SCRATCH/AGENTS.md" <<'EOF'
# AGENTS.md
# no markers present
EOF

OUT="$(bash "$CHECK" --check drift --root "$SCRATCH" 2>/dev/null)"
if ! echo "$OUT" | grep -qE 'DOCTOR:DRIFT status=warn regions=1 divergences=[1-9]'; then
  echo "FAIL: missing region scenario did not report status=warn" >&2
  echo "  got: $OUT" >&2
  exit 1
fi

# Scenario 5: absent file => status=skip.
rm -f "$SCRATCH/AGENTS.md"
OUT="$(bash "$CHECK" --check drift --root "$SCRATCH" 2>/dev/null)"
if ! echo "$OUT" | grep -q 'DOCTOR:DRIFT status=skip'; then
  echo "FAIL: absent-file scenario did not report status=skip" >&2
  echo "  got: $OUT" >&2
  exit 1
fi

# Verify default invocation still runs the M006 docs pass.
OUT="$(bash "$CHECK" --root "$PROJECT_ROOT" 2>/dev/null || true)"
if ! echo "$OUT" | grep -q 'DOCTOR:DOCS'; then
  echo "FAIL: default (docs) mode was disabled by drift patch" >&2
  exit 1
fi

echo "PASS: check-docs.sh --check drift detects all three finding kinds"
exit 0
```

Make executable.

### Step 5: Create `scripts/verify/m014-p02-run-doctor-drift-section.sh`

Verbatim body:

```bash
#!/usr/bin/env bash
# Gate: verify run-doctor.sh wires the Runtime Instruction Drift section.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RUN_DOCTOR="${PROJECT_ROOT}/scripts/diagnostics/run-doctor.sh"

if [ ! -f "$RUN_DOCTOR" ]; then echo "FAIL: run-doctor.sh missing" >&2; exit 1; fi

# Shape checks.
grep -q 'Runtime Instruction Drift' "$RUN_DOCTOR" || { echo "FAIL: Runtime Instruction Drift section not wired" >&2; exit 1; }
grep -q -- '--check drift' "$RUN_DOCTOR" || { echo "FAIL: --check drift invocation missing" >&2; exit 1; }

# Verify advisory=1 (the fourth positional arg is "1").
if ! grep -E 'run_check "Runtime Instruction Drift".*"1"' "$RUN_DOCTOR" >/dev/null; then
  echo "FAIL: Runtime Instruction Drift is not advisory (expected fourth arg \"1\")" >&2
  exit 1
fi

# Integration test: run-doctor against a scratch project with matching regions.
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
mkdir -p "$SCRATCH/.orchestrator"

cat > "$SCRATCH/CLAUDE.md" <<'EOF'
# >>> orchestrator:recent-changes >>>
- aligned
# <<< orchestrator:recent-changes <<<
EOF
cp "$SCRATCH/CLAUDE.md" "$SCRATCH/AGENTS.md"

OUT="$(bash "$RUN_DOCTOR" --root "$SCRATCH" 2>&1 || true)"
if ! echo "$OUT" | grep -q 'Runtime Instruction Drift'; then
  echo "FAIL: run-doctor did not display Runtime Instruction Drift section" >&2
  exit 1
fi
if ! echo "$OUT" | grep -q 'DOCTOR:DRIFT'; then
  echo "FAIL: run-doctor did not surface DOCTOR:DRIFT output" >&2
  exit 1
fi

echo "PASS: run-doctor.sh surfaces Runtime Instruction Drift section"
exit 0
```

Make executable.

### Step 6: Create `scripts/verify/m014-p02-doctor-md.sh`

Verbatim body:

```bash
#!/usr/bin/env bash
# Gate: verify commands/doctor.md documents runtime_instruction_drift.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOCTOR_MD="${PROJECT_ROOT}/commands/doctor.md"

if [ ! -f "$DOCTOR_MD" ]; then echo "FAIL: commands/doctor.md missing" >&2; exit 1; fi

grep -q 'Runtime Instruction Drift' "$DOCTOR_MD" || { echo "FAIL: Runtime Instruction Drift bullet missing" >&2; exit 1; }
grep -qE 'FR-13|runtime_instruction_drift' "$DOCTOR_MD" || { echo "FAIL: FR-13 / runtime_instruction_drift not named" >&2; exit 1; }
grep -q 'scripts/diagnostics/check-docs.sh' "$DOCTOR_MD" || { echo "FAIL: check-docs.sh not referenced" >&2; exit 1; }

echo "PASS: commands/doctor.md documents runtime_instruction_drift"
exit 0
```

Make executable.

## Must-Haves

- `scripts/diagnostics/check-docs.sh` supports `--check drift` (new) and `--check docs` (default, preserves M006 behavior); the drift mode emits `DOCTOR:DRIFT status=<ok|warn|skip> regions=<N> divergences=<M>` on stdout and per-finding `DRIFT: <kind> region=<name> file=<path>` lines on stderr
- Three drift kinds detected and reported: `missing_region`, `byte_divergence`, `unmatched_marker`
- Absent `CLAUDE.md` or `AGENTS.md` results in `status=skip` and exit 0
- `scripts/diagnostics/run-doctor.sh` wires a `Runtime Instruction Drift` section as an advisory check (advisory flag `1`)
- `commands/doctor.md` documents the new check under `## What It Checks` and names `scripts/diagnostics/check-docs.sh` as the referenced script
- All three modified files pass `scripts/verify/anti-pattern-lint.sh`
- All three new gate verifiers exit 0

## Verification

```
bash scripts/verify/m014-p02-check-docs-drift.sh
```

Expected: `PASS: check-docs.sh --check drift detects all three finding kinds`, exit 0.

```
bash scripts/verify/m014-p02-run-doctor-drift-section.sh
```

Expected: `PASS: run-doctor.sh surfaces Runtime Instruction Drift section`, exit 0.

```
bash scripts/verify/m014-p02-doctor-md.sh
```

Expected: `PASS: commands/doctor.md documents runtime_instruction_drift`, exit 0.

```
bash scripts/verify/anti-pattern-lint.sh --fixture scripts/diagnostics/check-docs.sh
```

Expected: exit 0.

## Inputs

### From Previous Tasks

- [`.orchestrator/milestones/M014/phases/P02/WRITE-SITES.md`](../../../../milestones/M014/phases/P02/WRITE-SITES.md) (from T01) — names the two marker regions drift detection scans for.

### From Disk (Pre-existing)

- `scripts/diagnostics/check-docs.sh` — existing M006 docs-completeness diagnostic. Current output: `DOCTOR:DOCS status=ok found=N total=N`. Existing `--root` flag preserved.
- `scripts/diagnostics/run-doctor.sh` — orchestrator. `run_check NAME SCRIPT ARGS ADVISORY` is the invocation shape. Advisory flag `1` routes to `advisory_warnings` counter.
- `commands/doctor.md` — user-facing command doc; `## What It Checks` is the section to extend.
- `scripts/verify/anti-pattern-lint.sh` — lint surface.

## Constraints

- Bash 3.2 compatible. Drift pass uses `grep`, `awk`, `sed`, `shasum`, `mktemp`, plain `if`/`while` — no process substitution, no `$( ... | ... )` with inner pipe, no inline `for`/`if` compounds.
- The existing M006 docs-completeness pass is preserved byte-for-byte — it becomes the `"docs"` branch. Default behavior (no flag) is unchanged for downstream callers.
- FR-13 v1 stance: drift is advisory. Exit is 0 on `warn` status; escalation to fail is deferred.
- The `run-doctor.sh` edit is a single-line insertion; the `run_check` function is not modified.
- Passes `scripts/verify/anti-pattern-lint.sh`.

## Expected Output

Files modified:

1. `scripts/diagnostics/check-docs.sh` — `--check <mode>` flag + drift mode body (~90 lines added; existing 82 lines preserved under `docs` branch)
2. `scripts/diagnostics/run-doctor.sh` — one `run_check` line inserted after line 111
3. `commands/doctor.md` — new bullet under What It Checks + new Referenced Scripts section (~8 lines added)

Files created:

4. `scripts/verify/m014-p02-check-docs-drift.sh` (~95 lines, executable)
5. `scripts/verify/m014-p02-run-doctor-drift-section.sh` (~45 lines, executable)
6. `scripts/verify/m014-p02-doctor-md.sh` (~25 lines, executable)

All six files pass anti-pattern-lint; all three gate verifiers exit 0.
