---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P04"
milestone: "M014"
name: "scripts/specify/specify.sh split full body (CC LLM splitter + manifest emission + interim path) + RUNTIME-ASSUMPTIONS.md FR-7 entry"
depends_on: ["T03", "T04"]
---

## Prerequisites

- T03 shipped: `templates/spec-splitter-prompt.md` exists (CC LLM prompt body).
- T04 shipped: `specify.sh` three-way wiring invokes `bash $0 split <path>` on the `d` path.
- P01 shipped: `specify.sh` has a hard-stub `split` subcommand (lines 72-75) that prints `split: decomposition flow lands in P04 per M014 roadmap` and exits 2.
- `scripts/dispatch/dispatch-interface.sh` exists — CC LLM dispatch surface.
- `scripts/lifecycle/detect-capabilities.sh` exists — runtime detection.
- `RUNTIME-ASSUMPTIONS.md` has FR-3 + FR-5 entries (from P01).

## Description

Replace the P01 hard-stub `split` body with the full FR-7 flow:

1. **Validate** the target spec path exists.
2. **Runtime gate**: if runtime is not Claude Code, print a loud diagnostic and exit 3 (distinct from P01 stub exit 2).
3. **LLM dispatch**: invoke `scripts/dispatch/dispatch-interface.sh` against `templates/spec-splitter-prompt.md` with the spec as input.
4. **Parse** the LLM response as a YAML manifest; validate it has ≥2 and ≤4 entries with required fields per entry.
5. **Derive source-id**: from the spec directory basename (e.g., `024-spec-management-extended` → source-id `024-spec-management-extended`).
6. **Write manifest** to `.orchestrator/specify/decomposition/<source-id>/manifest.md` (interim path per FR-7 + D016; [M024](../../../../milestones/M024/index.md) will migrate to `.orchestrator/intake/<id>/decomposition.md`).
7. **Emit FR-19 manifest records** under `--dry-run` (`action_type: "propose-decomposition"`, one record per proposed sub-spec).
8. **Append** FR-7 entry to `RUNTIME-ASSUMPTIONS.md` per CON-2 + D016 discipline.

## Steps

### Step 1: Replace the `split` subcommand body in `scripts/specify/specify.sh`

Locate the existing block (lines 71-75 in P01):

```bash
# --- Subcommand: split (P01 stub) ---
if [ "$SUBCMD" = "split" ]; then
  echo "split: decomposition flow lands in P04 per M014 roadmap" >&2
  exit 2
fi
```

Replace with the full body:

```bash
# --- Subcommand: split (FR-7 full) ---
if [ "$SUBCMD" = "split" ]; then
  if [ -z "${SPLIT_PATH:-}" ]; then
    echo "split: usage: specify.sh split <spec-path>" >&2
    exit 1
  fi
  if [ ! -f "$SPLIT_PATH" ]; then
    echo "split: spec path not found: $SPLIT_PATH" >&2
    exit 1
  fi

  # Derive source-id from spec directory basename.
  SPLIT_DIR="$(cd "$(dirname "$SPLIT_PATH")" && pwd)"
  SOURCE_ID="$(basename "$SPLIT_DIR")"
  MANIFEST_DIR="${PROJECT_ROOT}/.orchestrator/specify/decomposition/${SOURCE_ID}"
  MANIFEST_PATH="${MANIFEST_DIR}/manifest.md"

  # Runtime gate: CC only in v1.
  RUNTIME_SIG=""
  if [ "${CLAUDE_CODE_RUNTIME:-0}" = "1" ]; then
    RUNTIME_SIG="claude-code"
  elif [ -x "${PROJECT_ROOT}/scripts/lifecycle/detect-capabilities.sh" ]; then
    RUNTIME_SIG="$(bash "${PROJECT_ROOT}/scripts/lifecycle/detect-capabilities.sh" --runtime 2>/dev/null || echo "")"
  fi

  SPLITTER_PROMPT="${PROJECT_ROOT}/templates/spec-splitter-prompt.md"
  DISPATCH_IF="${PROJECT_ROOT}/scripts/dispatch/dispatch-interface.sh"

  if [ "$RUNTIME_SIG" != "claude-code" ]; then
    echo "split: LLM-assisted splitter is Claude Code only in v1 (see RUNTIME-ASSUMPTIONS.md FR-7); fall back to manual spec decomposition" >&2
    exit 3
  fi
  if [ ! -f "$SPLITTER_PROMPT" ]; then
    echo "split: splitter prompt missing: $SPLITTER_PROMPT" >&2
    exit 1
  fi
  if [ ! -x "$DISPATCH_IF" ]; then
    echo "split: dispatch-interface.sh missing or not executable: $DISPATCH_IF" >&2
    exit 1
  fi

  # Dispatch LLM.
  SPLIT_OUT="$(bash "$DISPATCH_IF" --prompt-file "$SPLITTER_PROMPT" --input-file "$SPLIT_PATH" --mode oneshot 2>/dev/null || true)"
  if [ -z "$SPLIT_OUT" ]; then
    echo "split: LLM dispatch produced empty response; bailing" >&2
    exit 1
  fi

  # Basic shape check: manifest must contain "type: decomposition-manifest" and at least two "- slug:" entries.
  ENTRY_COUNT="$(printf '%s\n' "$SPLIT_OUT" | grep -cE '^  - slug:')"
  if [ "$ENTRY_COUNT" -lt 2 ]; then
    echo "split: malformed LLM response (expected >=2 entries, got ${ENTRY_COUNT})" >&2
    exit 1
  fi
  if [ "$ENTRY_COUNT" -gt 4 ]; then
    echo "split: malformed LLM response (expected <=4 entries, got ${ENTRY_COUNT})" >&2
    exit 1
  fi
  if ! printf '%s\n' "$SPLIT_OUT" | grep -qF 'type: decomposition-manifest'; then
    echo "split: malformed LLM response (missing type: decomposition-manifest)" >&2
    exit 1
  fi

  if [ "${DRY_RUN:-0}" -eq 1 ]; then
    # Emit one FR-19 record per proposed sub-spec.
    SLUGS="$(printf '%s\n' "$SPLIT_OUT" | grep -E '^  - slug:' | sed -E 's/^  - slug: *//; s/ *$//')"
    for s in $SLUGS; do
      printf '{"command":"orchestrator:specify","action_type":"propose-decomposition","target_path":"%s","source_ref":"%s","description":"would scaffold sub-spec %s from %s"}\n' \
        "$MANIFEST_PATH" "$SPLIT_PATH" "$s" "$SOURCE_ID"
    done
    exit 0
  fi

  mkdir -p "$MANIFEST_DIR"
  TMP_M="$(mktemp)"
  printf '%s\n' "$SPLIT_OUT" > "$TMP_M"
  mv "$TMP_M" "$MANIFEST_PATH"

  # Observability: emit unit_close-style record with specs_decomposed field.
  LOG_FILE="${PROJECT_ROOT}/.orchestrator/execution-log.jsonl"
  TS_S="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  REC_S="{\"type\":\"unit_close\",\"ts\":\"${TS_S}\",\"command\":\"orchestrator:specify-split\",\"source_id\":\"${SOURCE_ID}\",\"sub_specs_proposed\":${ENTRY_COUNT},\"manifest_path\":\"${MANIFEST_PATH}\",\"source\":\"runtime\"}"
  printf '%s\n' "$REC_S" >> "$LOG_FILE" 2>/dev/null || true

  echo "$MANIFEST_PATH"
  exit 0
fi
```

### Step 2: Append FR-7 entry to `RUNTIME-ASSUMPTIONS.md`

Locate the end-of-file sentinel (line 51-52):

```
<!-- Future entries land below this line as new CC-only paths are introduced.
     Append-only per D016. Do not reorder or delete existing entries. -->
```

Insert the FR-7 entry **before** that sentinel, so the file ordering is: header → FR-3 → FR-5 → FR-7 → sentinel.

Verbatim FR-7 entry:

```markdown
### FR-7: LLM-assisted spec decomposition (`orchestrator:specify split`)

- **Claude Code assumption**: under CC runtime, `scripts/specify/specify.sh split <path>` invokes an LLM round-trip via `scripts/dispatch/dispatch-interface.sh` using `templates/spec-splitter-prompt.md` to propose a 2–N-way decomposition manifest for large specs that cross the FR-5 probe's above-threshold verdict and elect the `d` path in the US-3 three-way prompt.
- **Codex/Cursor fallback**: `split` exits 3 with a clear diagnostic naming CC-only status and pointing to manual spec decomposition. The operator authors N new specs by hand using `orchestrator:specify --description ...` and manages the decomposition manually. No silent degradation.
- **Milestone / phase**: M014/P04 introduction.

  The splitter caps proposed decompositions at 4 sub-specs (prompt-enforced); the manifest lands at `.orchestrator/specify/decomposition/<source-id>/manifest.md` (interim path — M024 Universal Intake milestone migrates to `.orchestrator/intake/<id>/decomposition.md` when shipped; manifest schema is write-forward-compatible).
- **M009 obligation**: re-implement the LLM-assisted splitter under Codex CLI (via Codex's API or external LLM round-trip) and Cursor, or document CC-only as permanent fallback if the LLM round-trip value under those runtimes proves low for the engineering cost.
```

### Step 3: Gate verifier — `scripts/verify/m014-p04-split-subcommand.sh`

Single-script file. Exercises:

1. `specify.sh split` with no arg → exits 1 with usage message.
2. `specify.sh split /nonexistent.md` → exits 1 with not-found message.
3. `CLAUDE_CODE_RUNTIME=0 specify.sh split <real-spec>` → exits 3 (Codex/Cursor runtime gate).
4. P01 stub language is gone (split body must not contain the exact P01 stub string).
5. RUNTIME-ASSUMPTIONS.md has FR-7 entry with the four required subsections.

Cannot hermetically exercise the CC success path without a real dispatch-interface + LLM, so the gate asserts the structural shape and the non-CC gate.

Verbatim body:

```bash
#!/usr/bin/env bash
# Gate: T05 — split subcommand full body + FR-7 RUNTIME-ASSUMPTIONS entry.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SPECIFY="${PROJECT_ROOT}/scripts/specify/specify.sh"
REG="${PROJECT_ROOT}/RUNTIME-ASSUMPTIONS.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

[ -x "$SPECIFY" ] || fail "specify.sh not executable"
[ -f "$REG" ]     || fail "RUNTIME-ASSUMPTIONS.md missing"

# P01 stub language is gone.
grep -qF 'decomposition flow lands in P04 per M014 roadmap' "$SPECIFY" \
  && fail "P01 split stub message still present in specify.sh"

# Full body markers present.
grep -qF 'propose-decomposition' "$SPECIFY"            || fail "propose-decomposition action_type missing"
grep -qF 'spec-splitter-prompt.md' "$SPECIFY"          || fail "splitter prompt reference missing"
grep -qF 'decomposition/' "$SPECIFY"                   || fail "decomposition manifest path missing"

# Runtime gate: under non-CC, split exits 3.
SCRATCH="$(mktemp -d)"
mkdir -p "${SCRATCH}/.orchestrator"
mkdir -p "${SCRATCH}/specs/000-stub"
touch "${SCRATCH}/specs/000-stub/spec.md"
CLAUDE_CODE_RUNTIME=0 bash "$SPECIFY" split "${SCRATCH}/specs/000-stub/spec.md" >/dev/null 2>&1
RC=$?
if [ "$RC" -ne 3 ]; then
  rm -rf "$SCRATCH"
  fail "non-CC split expected exit 3, got $RC"
fi

# No-arg case.
bash "$SPECIFY" split >/dev/null 2>&1
if [ $? -eq 0 ]; then rm -rf "$SCRATCH"; fail "split with no arg exited 0"; fi

# Missing-path case.
bash "$SPECIFY" split "${SCRATCH}/does-not-exist.md" >/dev/null 2>&1
if [ $? -eq 0 ]; then rm -rf "$SCRATCH"; fail "split with missing path exited 0"; fi

rm -rf "$SCRATCH"

# RUNTIME-ASSUMPTIONS FR-7 entry shape.
grep -qE '^### FR-7: LLM-assisted spec decomposition' "$REG" || fail "FR-7 heading missing"
# Each required subsection present (search anywhere in file — all three entries share these subheadings).
grep -qF 'Claude Code assumption' "$REG" || fail "Claude Code assumption subsection missing"
grep -qF 'Codex/Cursor fallback' "$REG"  || fail "Codex/Cursor fallback subsection missing"
grep -qF 'M009 obligation' "$REG"        || fail "M009 obligation subsection missing"

# FR-7 entry is positioned between FR-5 and the end-of-file sentinel.
# Use grep -n and numeric comparison.
L_FR5="$(grep -nE '^### FR-5:' "$REG" | head -n 1 | awk -F: '{print $1}')"
L_FR7="$(grep -nE '^### FR-7:' "$REG" | head -n 1 | awk -F: '{print $1}')"
L_END="$(grep -n 'Future entries land below this line' "$REG" | head -n 1 | awk -F: '{print $1}')"
[ -n "$L_FR5" ] && [ -n "$L_FR7" ] && [ -n "$L_END" ] || fail "could not locate FR-5/FR-7/sentinel line numbers"
if [ "$L_FR7" -le "$L_FR5" ]; then fail "FR-7 appears before FR-5"; fi
if [ "$L_FR7" -ge "$L_END" ]; then fail "FR-7 appears below sentinel"; fi

echo "PASS: split subcommand + FR-7 registry entry verified"
exit 0
```

Make executable.

## Must-Haves

- `scripts/specify/specify.sh` `split` subcommand body replaces P01 hard-stub; contains `propose-decomposition`, `decomposition/`, `spec-splitter-prompt.md`
- `split` no-arg → exits 1
- `split /missing.md` → exits 1
- `split <real-path>` under non-CC runtime → exits 3 with clear diagnostic
- `split <real-path>` under CC runtime → invokes dispatch-interface, writes manifest to `.orchestrator/specify/decomposition/<source-id>/manifest.md`, exits 0 (hermetic-test-out-of-scope; structural invariant)
- `split --dry-run <real-path>` emits `propose-decomposition` FR-19 records, no disk writes
- Manifest validation: ≥2 and ≤4 entries; `type: decomposition-manifest` marker
- `RUNTIME-ASSUMPTIONS.md` has FR-7 entry after FR-5, before end-of-file sentinel, with four required subsections
- `scripts/verify/m014-p04-split-subcommand.sh` exists, executable, exits 0
- Bash 3.2 + anti-pattern-lint clean

## Verification

```
bash scripts/verify/m014-p04-split-subcommand.sh
```

Expected: `PASS: split subcommand + FR-7 registry entry verified`, exit 0.

## Inputs

### From Previous Tasks

- `templates/spec-splitter-prompt.md` (from T03)
  - Consumed by `scripts/dispatch/dispatch-interface.sh --prompt-file ... --input-file ... --mode oneshot`.
  - LLM response shape: YAML with `type: decomposition-manifest` + entries list (each with `slug:`, `slice:`, `inherited_user_stories:`, `rationale:`).

- `scripts/specify/specify.sh` (from T04)
  - Existing subcommand dispatch structure with `SUBCMD="split"`, `SPLIT_PATH` variable, and the three-way `d` path delegation `bash $0 split <spec-path>`.

### From Disk (Pre-existing)

- `scripts/dispatch/dispatch-interface.sh` — CC LLM round-trip. Invocation: `bash ... --prompt-file <p> --input-file <i> --mode oneshot`. Response on stdout. On error, empty stdout; T05 checks for empty and bails.
- `scripts/lifecycle/detect-capabilities.sh` — returns `claude-code` / `codex` / `cursor` on `--runtime`.
- `RUNTIME-ASSUMPTIONS.md` — existing FR-3 + FR-5 entries; T05 appends FR-7 between FR-5 and the end-of-file sentinel.

## Constraints

- **Manifest cap at 4 entries** matches the splitter prompt constraint. T05 enforces via `grep -c`; a malformed response (0, 1, or >4 entries) fails loudly with exit 1.
- **Source-id derivation** uses spec-directory basename (`024-spec-management-extended`), not a UUID. Matches M024 intake convention per D016.
- **Interim path vs. M024 migration**: manifest path is `.orchestrator/specify/decomposition/<source-id>/manifest.md`. When M024 ships, the path migrates to `.orchestrator/intake/<id>/decomposition.md`. Schema is write-forward-compatible (the YAML shape is the same; only the file location changes).
- **No direct `/conversus` invocation** — T05 uses `scripts/dispatch/dispatch-interface.sh` only (D007).
- **Runtime gate is a hard exit 3** — distinct from P01 stub's exit 2. Callers (specify.sh three-way `d` path from T04) see exit 3 and surface the "LLM-only, use manual decomposition" diagnostic.
- **No adapter modification** — T05 does not touch `scripts/dispatch/adapters/tool/conversus.sh`.
- Bash 3.2 + anti-pattern-lint clean. `for s in $SLUGS; do` is Bash 3.2 safe (the variable `SLUGS` is newline-separated; the default IFS word-splits safely).

## Expected Output

Files committed:

1. `scripts/specify/specify.sh` — modified (P01 stub block replaced with full body, ~75 lines added)
2. `RUNTIME-ASSUMPTIONS.md` — modified (FR-7 entry appended before sentinel)
3. `scripts/verify/m014-p04-split-subcommand.sh` — created (~70 lines, executable)

Gate exits 0.
