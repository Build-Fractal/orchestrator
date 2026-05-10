---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P02"
milestone: "M014"
name: "Patch init-project.sh + reinit-handler.sh with project-identity dual-write"
depends_on: ["T01"]
---

## Prerequisites

- T01 has shipped the write-site manifest at [`.orchestrator/milestones/M014/phases/P02/WRITE-SITES.md`](../../../../milestones/M014/phases/P02/WRITE-SITES.md) naming `scripts/lifecycle/init-project.sh` and `scripts/lifecycle/reinit-handler.sh` as `project-identity` region call sites.
- P01 has shipped `scripts/util/dual-write-runtime-md.sh` with the full FR-12 flag surface (`--marker <name>` + `--content <file>` + `[--file CLAUDE.md] [--file AGENTS.md]` + `[--root <dir>]` + `[--dry-run]`).
- `scripts/lifecycle/init-project.sh` currently renders `templates/project-instruction.md` to the runtime-native path (`CLAUDE.md` for claude-code, `AGENTS.md` for codex, `.cursor/rules/orchestrator.md` for cursor) at line 193. The runtime-native full-file render remains unchanged — the dual-write invocation is additive.
- `scripts/lifecycle/reinit-handler.sh` at lines 249/253 writes the merged instruction file via `mv -f "$merged" "$INSTRUCTION_FILE"`. The dual-write invocation is inserted after the `mv` and before the `log` line.

## Description

Wire the `project-identity` dual-write region into both init paths. After init (or reinit) writes the runtime-native instruction file, both commands now additionally populate a marker-bounded `project-identity` region in BOTH `CLAUDE.md` and `AGENTS.md` at the project root, carrying five identity key=value lines.

The region regenerates in full on every invocation — not append-only. Bytes outside the markers are byte-preserved per SC-6a. If the helper is missing (defensive — the helper is always present post-P01 but the patch future-proofs against installs without it), both commands emit a `SKIPPED:` stderr line and continue.

## Steps

### Step 1: Patch `scripts/lifecycle/init-project.sh`

Insert a new numbered section "12b" between the existing Step 12 (write instruction file, line 194) and Step 13 (write config.yml, line 196). Exact insertion point: after the existing `log "wrote=$INSTRUCTION_FILE"` line.

Exact new block to insert:

```bash
# --- 12b. Dual-write project-identity region to CLAUDE.md + AGENTS.md ----------
# Per M014/P02 FR-12 — populate a marker-bounded project-identity region in
# both runtime-instruction files so runtime-agnostic identity is queryable
# from either file. Outside-markers bytes preserved per SC-6a.
DUAL_WRITE_HELPER="$REPO_ROOT/scripts/util/dual-write-runtime-md.sh"
DUAL_WRITES=0
if [ -x "$DUAL_WRITE_HELPER" ]; then
  FRAG_FILE="$(mktemp)"
  {
    printf 'project_name=%s\n'           "$PROJECT_NAME"
    printf 'runtime=%s\n'                "$RUNTIME"
    printf 'cap_score=%s\n'              "$CAP_SCORE"
    printf 'recommended_intensity=%s\n'  "$RECOMMENDED_INTENSITY"
    printf 'initialized_at=%s\n'         "$INITIALIZED_AT"
  } > "$FRAG_FILE"

  if bash "$DUAL_WRITE_HELPER" \
      --marker project-identity \
      --content "$FRAG_FILE" \
      --root "$PROJECT_DIR" \
      --file CLAUDE.md --file AGENTS.md \
      >/dev/null 2>&1; then
    DUAL_WRITES=2
  else
    # Fallback: try CLAUDE.md only (e.g. dual_write_agents=false gated AGENTS.md).
    if bash "$DUAL_WRITE_HELPER" \
        --marker project-identity \
        --content "$FRAG_FILE" \
        --root "$PROJECT_DIR" \
        --file CLAUDE.md \
        >/dev/null 2>&1; then
      DUAL_WRITES=1
    else
      echo "WARN: dual-write project-identity failed; continuing" >&2
    fi
  fi
  rm -f "$FRAG_FILE"
else
  echo "SKIPPED: dual-write-runtime-md.sh not executable (init)" >&2
fi
log "dual_writes=$DUAL_WRITES region=project-identity"
```

Also extend the final `SUMMARY:` line (line 249) to carry `dual_writes=$DUAL_WRITES`. New SUMMARY line:

```bash
echo "SUMMARY: project_type=$PROJECT_TYPE runtime=$RUNTIME instruction_file=$INSTRUCTION_FILE config_file=$CONFIG_FILE cap_score=$CAP_SCORE recommended_intensity=$RECOMMENDED_INTENSITY skills_installed=$SKILLS_INSTALLED dual_writes=$DUAL_WRITES next_step=run_orchestrator_evaluate"
```

Also extend the dry-run SUMMARY line at line 156 similarly:

```bash
echo "SUMMARY: project_type=$PROJECT_TYPE runtime=$RUNTIME instruction_file=$INSTRUCTION_FILE config_file=$CONFIG_FILE cap_score=$CAP_SCORE recommended_intensity=$RECOMMENDED_INTENSITY dual_writes=0 next_step=run_orchestrator_evaluate"
```

Append one line after the dry-run block's `exit 0` (or at the existing `would_write=$INSTRUCTION_FILE` area):

```bash
  echo "would_dual_write_region=project-identity files=CLAUDE.md,AGENTS.md"
```

### Step 2: Patch `scripts/lifecycle/reinit-handler.sh`

Insert a symmetric block after the `mv -f "$merged" "$INSTRUCTION_FILE"` / `mv -f "$rendered" "$INSTRUCTION_FILE"` branch (i.e., after the `log "wrote=$INSTRUCTION_FILE (custom_block_preserved=$CUSTOM_BLOCK_PRESERVED)"` line 255) and before any further flow. Exact block to insert:

```bash
# --- Dual-write project-identity region (M014/P02 FR-12) ---
DUAL_WRITE_HELPER="$REPO_ROOT/scripts/util/dual-write-runtime-md.sh"
DUAL_WRITES=0
if [ -x "$DUAL_WRITE_HELPER" ]; then
  FRAG_FILE="$(mktemp)"
  {
    printf 'project_name=%s\n'           "$(basename "$PROJECT_DIR")"
    printf 'runtime=%s\n'                "$RUNTIME"
    printf 'cap_score=%s\n'              "${CAP_SCORE:-unknown}"
    printf 'recommended_intensity=%s\n'  "${RECOMMENDED_INTENSITY:-standard}"
    printf 'initialized_at=%s\n'         "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$FRAG_FILE"

  if bash "$DUAL_WRITE_HELPER" \
      --marker project-identity \
      --content "$FRAG_FILE" \
      --root "$PROJECT_DIR" \
      --file CLAUDE.md --file AGENTS.md \
      >/dev/null 2>&1; then
    DUAL_WRITES=2
  else
    if bash "$DUAL_WRITE_HELPER" \
        --marker project-identity \
        --content "$FRAG_FILE" \
        --root "$PROJECT_DIR" \
        --file CLAUDE.md \
        >/dev/null 2>&1; then
      DUAL_WRITES=1
    else
      echo "WARN: reinit dual-write project-identity failed; continuing" >&2
    fi
  fi
  rm -f "$FRAG_FILE"
else
  echo "SKIPPED: dual-write-runtime-md.sh not executable (reinit)" >&2
fi
log "dual_writes=$DUAL_WRITES region=project-identity"
```

Extend the final `SUMMARY:` line (line 310) to include `dual_writes=$DUAL_WRITES`.

Extend the dry-run SUMMARY branch (line 186) similarly with `dual_writes=0`.

**Note**: `reinit-handler.sh` may not have `CAP_SCORE` / `RECOMMENDED_INTENSITY` in scope — the insertion block uses `${VAR:-fallback}` so it degrades gracefully if upstream context does not expose them. If both vars are present (they are, per the handler's Step-6 capability re-probe), they are used verbatim.

### Step 3: Create `scripts/verify/m014-p02-init-dual-write.sh`

Verbatim body (hermetic scratch-project test):

```bash
#!/usr/bin/env bash
# Gate: verify init-project.sh dual-writes the project-identity region.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
INIT="${PROJECT_ROOT}/scripts/lifecycle/init-project.sh"
HELPER="${PROJECT_ROOT}/scripts/util/dual-write-runtime-md.sh"

if [ ! -x "$INIT" ]; then echo "FAIL: init-project.sh missing" >&2; exit 1; fi
if [ ! -x "$HELPER" ]; then echo "FAIL: dual-write helper missing" >&2; exit 1; fi

# Check the source for the wiring (shape-level).
grep -q 'dual-write-runtime-md.sh'    "$INIT" || { echo "FAIL: init does not reference helper" >&2; exit 1; }
grep -q 'project-identity'            "$INIT" || { echo "FAIL: init does not use project-identity marker" >&2; exit 1; }
grep -q 'dual_writes='                "$INIT" || { echo "FAIL: init does not expose dual_writes in SUMMARY" >&2; exit 1; }

# Hermetic integration: run init against a scratch dir.
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

# Run init with --runtime claude-code against the scratch project.
bash "$INIT" --project-dir "$SCRATCH" --runtime claude-code --force >/dev/null 2>&1
RC=$?
if [ $RC -ne 0 ]; then
  echo "FAIL: init exited non-zero ($RC) against scratch dir" >&2
  exit 1
fi

# Assert both CLAUDE.md and AGENTS.md got the region.
for f in CLAUDE.md AGENTS.md; do
  if [ ! -f "$SCRATCH/$f" ]; then
    echo "FAIL: $f not created by init" >&2; exit 1
  fi
  if ! grep -qF '# >>> orchestrator:project-identity >>>' "$SCRATCH/$f"; then
    echo "FAIL: $f missing project-identity opening marker" >&2; exit 1
  fi
  if ! grep -qF '# <<< orchestrator:project-identity <<<' "$SCRATCH/$f"; then
    echo "FAIL: $f missing project-identity closing marker" >&2; exit 1
  fi
  if ! grep -qE '^runtime=claude-code' "$SCRATCH/$f"; then
    echo "FAIL: $f missing runtime=claude-code identity line" >&2; exit 1
  fi
done

# Extract region bytes from both files and assert byte-identical (SC-6 peer-match).
extract_region() {
  awk '/^# >>> orchestrator:project-identity >>>/ { in_r=1; next } /^# <<< orchestrator:project-identity <<</ { in_r=0; next } in_r==1 { print }' "$1"
}
C_SHA="$(extract_region "$SCRATCH/CLAUDE.md" | shasum -a 256 | awk '{print $1}')"
A_SHA="$(extract_region "$SCRATCH/AGENTS.md" | shasum -a 256 | awk '{print $1}')"
if [ "$C_SHA" != "$A_SHA" ]; then
  echo "FAIL: project-identity region bytes differ between CLAUDE.md and AGENTS.md" >&2
  echo "  CLAUDE=$C_SHA  AGENTS=$A_SHA" >&2
  exit 1
fi

echo "PASS: init-project.sh dual-writes project-identity region byte-identical"
exit 0
```

Make executable.

### Step 4: Create `scripts/verify/m014-p02-reinit-dual-write.sh`

Verbatim body:

```bash
#!/usr/bin/env bash
# Gate: verify reinit-handler.sh dual-writes the project-identity region.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
INIT="${PROJECT_ROOT}/scripts/lifecycle/init-project.sh"
REINIT="${PROJECT_ROOT}/scripts/lifecycle/reinit-handler.sh"
HELPER="${PROJECT_ROOT}/scripts/util/dual-write-runtime-md.sh"

if [ ! -x "$REINIT" ]; then echo "FAIL: reinit-handler.sh missing" >&2; exit 1; fi
if [ ! -x "$HELPER" ]; then echo "FAIL: dual-write helper missing" >&2; exit 1; fi

grep -q 'dual-write-runtime-md.sh' "$REINIT" || { echo "FAIL: reinit does not reference helper" >&2; exit 1; }
grep -q 'project-identity'         "$REINIT" || { echo "FAIL: reinit does not use project-identity marker" >&2; exit 1; }
grep -q 'dual_writes='             "$REINIT" || { echo "FAIL: reinit does not expose dual_writes in SUMMARY" >&2; exit 1; }

SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

# First init to set up the scratch project.
bash "$INIT" --project-dir "$SCRATCH" --runtime claude-code --force >/dev/null 2>&1
RC=$?
if [ $RC -ne 0 ]; then echo "FAIL: initial init non-zero" >&2; exit 1; fi

# Capture post-init outside-markers shasum on CLAUDE.md.
outside_bytes() {
  awk '/^# >>> orchestrator:/ { in_r=1; next } /^# <<< orchestrator:/ { in_r=0; next } in_r != 1 { print }' "$1"
}
REF_SHA="$(outside_bytes "$SCRATCH/CLAUDE.md" | shasum -a 256 | awk '{print $1}')"

# Run init again (no --force) — should delegate to reinit-handler.
bash "$INIT" --project-dir "$SCRATCH" --runtime claude-code >/dev/null 2>&1
RC=$?
if [ $RC -ne 0 ]; then echo "FAIL: reinit delegation non-zero ($RC)" >&2; exit 1; fi

# Assert outside-markers bytes are preserved on CLAUDE.md.
POST_SHA="$(outside_bytes "$SCRATCH/CLAUDE.md" | shasum -a 256 | awk '{print $1}')"
if [ "$REF_SHA" != "$POST_SHA" ]; then
  echo "FAIL: outside-markers bytes diverged on reinit" >&2; exit 1
fi

# Assert region still present in both files.
for f in CLAUDE.md AGENTS.md; do
  grep -qF '# >>> orchestrator:project-identity >>>' "$SCRATCH/$f" || { echo "FAIL: $f missing region after reinit" >&2; exit 1; }
done

echo "PASS: reinit-handler.sh dual-writes project-identity region; outside-markers bytes preserved"
exit 0
```

Make executable.

## Must-Haves

- `scripts/lifecycle/init-project.sh` references `scripts/util/dual-write-runtime-md.sh`, uses `--marker project-identity`, emits `dual_writes=<N>` in its SUMMARY line
- `scripts/lifecycle/reinit-handler.sh` references the helper, uses the same marker, emits `dual_writes=<N>` in its SUMMARY line
- Running `init-project.sh` against a hermetic scratch dir produces `CLAUDE.md` and `AGENTS.md` both containing a byte-identical `project-identity` marker region (shasums match)
- Running `init-project.sh` twice (second run delegating to reinit-handler) preserves outside-markers bytes on `CLAUDE.md` (SC-6a invariant holds on reinit)
- Both patched scripts pass `scripts/verify/anti-pattern-lint.sh`
- Both new gate verifiers exit 0

## Verification

```
bash scripts/verify/m014-p02-init-dual-write.sh
```

Expected: `PASS: init-project.sh dual-writes project-identity region byte-identical`, exit 0.

```
bash scripts/verify/m014-p02-reinit-dual-write.sh
```

Expected: `PASS: reinit-handler.sh dual-writes project-identity region; outside-markers bytes preserved`, exit 0.

```
bash scripts/verify/anti-pattern-lint.sh --fixture scripts/lifecycle/init-project.sh
```

Expected: exit 0.

```
bash scripts/verify/anti-pattern-lint.sh --fixture scripts/lifecycle/reinit-handler.sh
```

Expected: exit 0.

## Inputs

### From Previous Tasks

- [`.orchestrator/milestones/M014/phases/P02/WRITE-SITES.md`](../../../../milestones/M014/phases/P02/WRITE-SITES.md) (from T01) — source of truth naming both sites as `project-identity` writers.

### From Disk (Pre-existing)

- `scripts/util/dual-write-runtime-md.sh` — P01 helper. Called with `--marker project-identity --content <tmp> --root "$PROJECT_DIR" --file CLAUDE.md --file AGENTS.md`. Returns 0 on both writes, non-zero if either fails. Writes are idempotent: re-invocation replaces the region in-place.
- `scripts/lifecycle/init-project.sh` — existing entry point. Step 9 computes `$INSTRUCTION_FILE`; Step 12 renders the template; Step 13 writes `config.yml`; Step 14 delegates to the installer. The new Step 12b slots between 12 and 13.
- `scripts/lifecycle/reinit-handler.sh` — existing reinit path. Step-11 block around line 249–255 writes the merged/rendered instruction file. The new block slots after the `log "wrote=..."` line.
- `scripts/verify/anti-pattern-lint.sh` — lint surface. The inserted blocks use plain `if`, `bash`, `printf`, `rm -f` — no `$(... | ...)`, no `<(...)`, no `&>`.

## Constraints

- Bash 3.2 compatible. Each block uses `printf`, `bash`, `rm -f`, `mktemp` only.
- The inserted blocks MUST NOT break existing behavior — existing placeholder substitution, existing SUMMARY-line fields, and existing `log` calls all continue to fire. The dual-write is purely additive.
- Passes `scripts/verify/anti-pattern-lint.sh` (no `$(...)` containing pipes, no process substitution, no inline `for`/`if` compounds).
- The helper's `dual_write_agents: false` config gate continues to work — both the primary and fallback code paths handle the gated case (primary returns 0 with only CLAUDE.md written, fallback is never invoked).

## Expected Output

Files modified:

1. `scripts/lifecycle/init-project.sh` — new Step 12b block (~32 lines) + extended SUMMARY lines (2 edits)
2. `scripts/lifecycle/reinit-handler.sh` — new block after instruction-file rename (~32 lines) + extended SUMMARY lines (2 edits)

Files created:

3. `scripts/verify/m014-p02-init-dual-write.sh` — gate verifier (~55 lines, executable)
4. `scripts/verify/m014-p02-reinit-dual-write.sh` — gate verifier (~55 lines, executable)

All four shell files pass `anti-pattern-lint.sh`; both gate verifiers exit 0.
