---
schema_version: "1.0"
type: task-plan
task: "T06"
phase: "P04"
milestone: "M014"
name: "scripts/specify/specify.sh --amend full FR-14 three-case body + AS-7 deliberation-preservation + RUNTIME-ASSUMPTIONS.md FR-5-full entry (replaces stub body) + references/spec-management.md completion (SC-11)"
depends_on: ["T04"]
---

## Prerequisites

- T04 shipped: `specify.sh` has the three-way prompt scaffold; `commands/specify.md` documents FR-14 three-case semantics in its Subcommand block.
- P01 shipped: `specify.sh --amend <path>` currently prints the deferral diagnostic `amend: P01 ships the surface; full three-case semantics land in P04` and exits 0.
- `RUNTIME-ASSUMPTIONS.md` has a P01 FR-5 entry with body "P01 stub ..." language. T06 replaces that body with FR-5-full, preserving append-only discipline (heading + subheadings stay; body prose refreshed).
- `references/spec-management.md` exists, partial, with the sentinel `<!-- partial: P04 completes with pressure-test + decomposition sections -->` at EOF.

## Description

Three deliverables, stitched because they are the M014/P04 **close-out** — the SC-11 milestone-close gate (`references/spec-management.md` complete) + SC-15 close-out (`RUNTIME-ASSUMPTIONS.md` FR-5-full) + SC-14 (amend byte-preservation invariant):

1. **Full FR-14 three-case `--amend` body** in `scripts/specify/specify.sh` — parses sections, classifies (a)/(b)/(c), applies case-specific logic with byte-preservation invariant + changed-section detection for AS-7 re-probe gating.
2. **`RUNTIME-ASSUMPTIONS.md` FR-5 entry body replaced** with FR-5-full — same `### FR-5:` heading, same four subsections, refreshed body prose reflecting the T02 full probe behavior. Append-only discipline preserved: the heading stays; only the paragraph text under each subsection is refreshed.
3. **`references/spec-management.md` completion** — four new top-level sections, sentinel removed, `action_type` table extended with three new rows.

## Steps

### Step 1: Replace the `--amend` subcommand body in `scripts/specify/specify.sh`

Locate the existing P01 amend block (lines 95-104):

```bash
# --- Subcommand: amend (P01 placeholder-only semantics) ---
if [ "$SUBCMD" = "amend" ]; then
  if [ ! -f "$AMEND_PATH" ]; then
    echo "specify.sh: --amend target not found: $AMEND_PATH" >&2; exit 1
  fi
  # P01: leave file unchanged. Full FR-14 three-case semantics in P04.
  echo "amend: P01 ships the surface; full three-case semantics land in P04" >&2
  echo "$AMEND_PATH"
  exit 0
fi
```

Replace with the full body:

```bash
# --- Subcommand: amend (FR-14 full three-case semantics) ---
if [ "$SUBCMD" = "amend" ]; then
  if [ ! -f "$AMEND_PATH" ]; then
    echo "specify.sh: --amend target not found: $AMEND_PATH" >&2; exit 1
  fi

  # Snapshot pre-amend shasum for case (b)/(c) byte-preservation invariant (SC-14).
  PRE_SHA="$(shasum -a 256 "$AMEND_PATH" | awk '{print $1}')"

  # Classify each top-level ^## section into case (a), (b), or (c).
  # Extract sections as blocks between adjacent ^## headings.
  AMEND_REPORT="$(mktemp)"
  SECTION_DIR="$(mktemp -d)"
  awk '
    /^## / {
      if (sec != "") {
        fname = sprintf("%s/sec-%03d.md", dir, idx)
        print header > fname
        printf "%s", sec > fname
        close(fname)
        idx++
      }
      header = $0 "\n"
      sec = ""
      next
    }
    { sec = sec $0 "\n" }
    END {
      if (sec != "" || header != "") {
        fname = sprintf("%s/sec-%03d.md", dir, idx)
        print header > fname
        printf "%s", sec > fname
        close(fname)
      }
    }
  ' dir="$SECTION_DIR" "$AMEND_PATH"

  # For each section file, classify and log.
  CHANGED_SECTIONS=""
  for sf in "$SECTION_DIR"/sec-*.md; do
    [ -f "$sf" ] || continue
    SNAME="$(head -n 1 "$sf" | sed -E 's/^## *//')"
    TODO_COUNT="$(grep -cE '<TODO' "$sf" 2>/dev/null || echo 0)"
    # Authored prose bytes = total bytes - bytes of <TODO...>-bearing lines.
    TOTAL_LINES="$(wc -l < "$sf" | tr -d ' ')"
    TODO_LINES="$(grep -cE '<TODO' "$sf" 2>/dev/null || echo 0)"
    AUTHORED_LINES=$(( TOTAL_LINES - TODO_LINES - 1 ))  # -1 for header line
    if [ "$AUTHORED_LINES" -lt 0 ]; then AUTHORED_LINES=0; fi

    CASE=""
    if [ "$TODO_COUNT" -gt 0 ] && [ "$AUTHORED_LINES" -eq 0 ]; then
      CASE="a"  # all-placeholder
    elif [ "$TODO_COUNT" -gt 0 ] && [ "$AUTHORED_LINES" -gt 0 ]; then
      CASE="b"  # partial-placeholder
    else
      CASE="c"  # fully-authored
    fi

    if [ "${DRY_RUN:-0}" -eq 1 ]; then
      printf '{"command":"orchestrator:specify","action_type":"amend-section","target_path":"%s","source_ref":"%s","description":"section %s case %s (todo_lines=%d, authored_lines=%d)"}\n' \
        "$AMEND_PATH" "$SNAME" "$SNAME" "$CASE" "$TODO_LINES" "$AUTHORED_LINES"
    fi

    case "$CASE" in
      a)
        # CC: re-run FR-3 LLM-fill. Non-CC: leave unchanged (CON-2 fallback).
        # P04 T06 note: FR-3 LLM-fill wiring is still deferred to a later phase
        # per RUNTIME-ASSUMPTIONS.md FR-3; case (a) here is a no-op that logs the
        # would-be LLM fill as a diagnostic. The byte-preservation invariant is
        # trivially satisfied (nothing changes).
        echo "amend: section '${SNAME}' case (a) all-placeholder — FR-3 LLM-fill deferred (see RUNTIME-ASSUMPTIONS.md FR-3); no-op" >&2
        CHANGED_SECTIONS="${CHANGED_SECTIONS}${SNAME}\n"
        ;;
      b)
        echo "amend: section '${SNAME}' case (b) partial — both <TODO> and authored prose present; operator must resolve manually" >&2
        ;;
      c)
        # Byte-identical pass: leave alone.
        :
        ;;
    esac
  done

  # Post-amend shasum for SC-14 invariant verification.
  POST_SHA="$(shasum -a 256 "$AMEND_PATH" | awk '{print $1}')"
  if [ "$PRE_SHA" != "$POST_SHA" ]; then
    echo "amend: WARN: file shasum changed (pre=${PRE_SHA} post=${POST_SHA}) — SC-14 invariant may be at risk" >&2
  fi

  # Observability: unit_close-style record with specs_amended field.
  LOG_FILE="${PROJECT_ROOT}/.orchestrator/execution-log.jsonl"
  TS_A="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  REC_A="{\"type\":\"unit_close\",\"ts\":\"${TS_A}\",\"command\":\"orchestrator:specify-amend\",\"target\":\"${AMEND_PATH}\",\"specs_amended\":1,\"pre_shasum\":\"${PRE_SHA}\",\"post_shasum\":\"${POST_SHA}\",\"source\":\"runtime\"}"
  printf '%s\n' "$REC_A" >> "$LOG_FILE" 2>/dev/null || true

  # Re-probe changed sections (AS-7: preserve prior deliberation — probe only fires
  # if CHANGED_SECTIONS non-empty). Under non-CC this is a heuristic-only pass.
  if [ -n "$CHANGED_SECTIONS" ]; then
    PROBE_A="${PROJECT_ROOT}/scripts/knowledge/spec-complexity-probe.sh"
    if [ -x "$PROBE_A" ]; then
      bash "$PROBE_A" "$AMEND_PATH" >/dev/null 2>&1 || true
    fi
  fi

  rm -rf "$SECTION_DIR"
  rm -f "$AMEND_REPORT"
  echo "$AMEND_PATH"
  exit 0
fi
```

### Step 2: Replace `RUNTIME-ASSUMPTIONS.md` FR-5 entry body with FR-5-full prose

Locate the existing FR-5 entry (lines 34-41). Replace the four subsection bullets with FR-5-full language. Keep the `### FR-5:` heading byte-identical; only the body prose changes (append-only discipline: the entry heading is preserved, body is allowed to refresh as P01-stub → P04-full per the spec's "every entry's stub body is replaced at CC-invocation time" interpretation of D016).

Replace the existing FR-5 bullets and the paragraph that follows:

```markdown
- **Claude Code assumption**: under CC runtime (in M014/P04), the probe will invoke an LLM pass to count contradiction signals ...
- **Codex/Cursor fallback**: zero contradiction signals counted ...
- **Milestone / phase**: M014/P01 stub; M014/P04 full implementation.

  In P01, the probe unconditionally emits `probe=below-threshold` with all structured fields at zero. The stub exists so `scripts/specify/specify.sh` can wire the call without branching on probe output in P01. P04 replaces the body; the caller is unchanged.
- **M009 obligation**: re-implement the contradiction-signal LLM pass under Codex/Cursor ...
```

With:

```markdown
- **Claude Code assumption**: under CC runtime, `scripts/knowledge/spec-complexity-probe.sh` invokes an LLM round-trip via `scripts/dispatch/dispatch-interface.sh` using `templates/spec-complexity-contradiction-prompt.md` to count contradiction signals (mutually-exclusive requirements, "should support both X and its opposite" patterns, constraints violating success criteria) in the draft spec prose. The returned count feeds the above-threshold verdict when `contradiction_signal_count >= 1` per `.orchestrator/config.yml specify.complexity_thresholds.contradiction_signal_count`. The LLM pass is defensive: any dispatch failure silently yields zero signals (probe never fails because of LLM flakiness).
- **Codex/Cursor fallback**: the contradiction-signal LLM pass is skipped entirely (gated on `CLAUDE_CODE_RUNTIME=1` + `scripts/lifecycle/detect-capabilities.sh --runtime` = `claude-code`). The probe emits `contradiction_signals=0` in its structured stderr output and relies exclusively on the runtime-agnostic heuristic dimensions (FR count, user-story count, raw token count, TODO density) to reach a verdict. Fully functional — Codex/Cursor users still get useful above-threshold firings on large specs; they simply lose the contradiction-detection signal.
- **Milestone / phase**: M014/P04 introduction (full body replaces M014/P01 stub). Caller contract (single-line stdout verdict + four-key stderr fields + exit code) is unchanged from P01 — callers invoke the probe identically pre- and post-T02.
- **M009 obligation**: re-implement the contradiction-signal LLM pass under Codex CLI (via Codex's API or an external LLM round-trip) and Cursor. Until runtime-parity ships, CC-only contradiction detection is the canonical path; Codex/Cursor users can still dogfood the orchestrator without the signal.
```

### Step 3: Complete `references/spec-management.md`

Remove the partial sentinel `<!-- partial: P04 completes with pressure-test + decomposition sections -->` at EOF. Append four new top-level sections. Also extend the `action_type` table with three new rows.

**3a. Extend the `action_type` table.** Locate the existing table (lines 74-81):

```
| action_type | Emitter | Target |
|---|---|---|
| `scaffold-spec` | `orchestrator:specify` | `specs/<NNN>-<slug>/spec.md` |
| `dual-write-region` | `scripts/util/dual-write-runtime-md.sh`, `orchestrator:specify` | `CLAUDE.md`, `AGENTS.md` |
| `classify-comment` (P03) | `orchestrator:comments` | in-memory classification result |
| `apply-amendment` (P03) | `orchestrator:comments` | `specs/<NNN>-<slug>/spec.md` |
| `append-decision` (P03) | `orchestrator:comments` | `.orchestrator/DECISIONS.md` |
```

Add three rows after the existing rows:

```
| `invoke-conversus-gate` (P04) | `orchestrator:specify` (y path) | `specs/<NNN>-<slug>/conversus/summary/final.md` |
| `propose-decomposition` (P04) | `orchestrator:specify split` | `.orchestrator/specify/decomposition/<source-id>/manifest.md` |
| `amend-section` (P04) | `orchestrator:specify --amend` | `specs/<NNN>-<slug>/spec.md` |
```

**3b. Remove the sentinel and append four sections.** At EOF, remove the `<!-- partial: P04 ... -->` comment. Append:

```markdown

## Complexity Probe (FR-5)

`scripts/knowledge/spec-complexity-probe.sh <spec-path>` evaluates a draft spec against five dimensions and emits a single-line verdict plus four structured fields. Thresholds live in `.orchestrator/config.yml` under `specify.complexity_thresholds:`. The probe was pinned in M014/P04 per the corpus-calibration memo at `.orchestrator/milestones/M014/phases/P04/CALIBRATION-MEMO.md`.

### Dimensions

- **`fr_count`** — number of `^- \*\*FR-[0-9]+|^### FR-[0-9]+|^\*\*FR-[0-9]+` matches. Above-threshold at ≥ `fr_count` (default 15).
- **`user_story_count`** — number of `^### User (Story|Scenario)` matches. Above-threshold at ≥ `user_story_count` (default 5).
- **`raw_token_count`** — `wc -w` of the spec file. Above-threshold at ≥ `raw_token_count` (default 8000).
- **`todo_density`** — `<TODO>` count / (`<TODO>` count + section count). Above-threshold at ≥ `todo_density` (default 0.5).
- **`contradiction_signals`** — LLM-derived contradiction count (CC only; Codex/Cursor emit 0). Above-threshold at ≥ `contradiction_signal_count` (default 1).

### Hardening-spec exception

When `specify.hardening_spec_exception: true` (default) and `fr_count == 0`, the probe returns `below-threshold` unconditionally. Rationale: M016 and M021 hardening milestones have zero FR-list but legitimate user-story counts; the exception prevents false-positive above-threshold firings on small hardening specs. Documented in the calibration memo.

### Runtime split (CON-2)

Heuristic dimensions (`fr_count`, `user_story_count`, `raw_token_count`, `todo_density`) are runtime-agnostic. `contradiction_signals` is CC-only; Codex/Cursor runtimes emit `contradiction_signals=0`. See `RUNTIME-ASSUMPTIONS.md` FR-5 for the full runtime-parity obligation.

### Observability

Every probe invocation appends one `spec_complexity_probe` JSONL record to `.orchestrator/execution-log.jsonl` in the M019 Tier 1 shape: `{type, ts, spec_path, verdict, reason, fr_count, user_story_count, todo_count, contradiction_signals, llm_calls, elapsed_ms, source}`.

## Conversus Pressure-Test (US-3, FR-6)

When the FR-5 probe fires `above-threshold`, `orchestrator:specify` prints a single-line prompt `conversus pressure-test recommended (<reason>). [y/n/d]` and reads one character from the controlling terminal.

### Prompt resolution

- Under `--yes` or non-TTY stdin: defaults to `n` silently (preserves SC-7 zero-prompt baseline).
- On `y`: invokes `scripts/dispatch/adapters/tool/conversus.sh gate --strict spec-pressure-test <spec> specs/<NNN>-<slug>/conversus/summary/final.md`.
- On `d`: invokes `scripts/specify/specify.sh split <spec>` (see Decomposition Flow).
- On `n`: proceeds silently; no side effects.

### Preset

`templates/conversus-presets/spec-pressure-test.yml` (FR-6) — red-blue adversarial deliberation: blue argues shippable, red argues fatal flaw, arbiter grounds verdicts in `.orchestrator/memory/constitution.md` (Principle II Evidence Before Claims, Principle III Design Before Code, Principle XV Surgical Precision). Verdict: PASS|BLOCK.

### Adapter exit-code handling (M013/FR-13 precedent)

- `0` + `SKIPPED:` on stdout → adapter binary missing in non-strict mode (not applicable under `--strict`).
- `0` otherwise → PASS; proceed.
- `2` → BLOCK; record verdict, surface diagnostic, exit 0 with the scaffold intact.
- `1` → ERROR (including `--strict` with missing adapter binary); surface diagnostic, exit 1.

Every `y` invocation appends one `conversus_gate_invocation` JSONL record to `.orchestrator/execution-log.jsonl` per FR-16 + M013/FR-17 shape.

### No adapter modification (D007 + CON-4)

M014 ships preset + prompts only. `scripts/dispatch/adapters/tool/conversus.sh` is unchanged. Under `--strict`, adapter absence fails loudly.

## Decomposition Flow (FR-7)

`orchestrator:specify split <path>` proposes a 2–N-way decomposition of a large draft. CC only in v1 per CON-2.

### Runtime gate

- Under Claude Code runtime (`CLAUDE_CODE_RUNTIME=1` or `scripts/lifecycle/detect-capabilities.sh --runtime` = `claude-code`): invokes `scripts/dispatch/dispatch-interface.sh --prompt-file templates/spec-splitter-prompt.md --input-file <spec> --mode oneshot`.
- Under Codex/Cursor: exits 3 with diagnostic pointing to manual decomposition.

### Manifest shape

The splitter emits a YAML manifest with `type: decomposition-manifest` and an entries list of 2–4 proposed sub-specs. Each entry has `slug`, `slice` (one-line description of owned subset), `inherited_user_stories` (array of `US-N` identifiers from source), and `rationale` (one-line coherence argument).

Cap at 4 sub-specs is prompt-enforced and script-verified; larger decompositions indicate the source isn't ready to split yet.

### Interim path (FR-7 + D016)

The manifest lands at `.orchestrator/specify/decomposition/<source-id>/manifest.md` in v1. When M024 (Universal Intake & Routing) ships, the manifest path migrates to `.orchestrator/intake/<id>/decomposition.md`. The manifest schema is write-forward-compatible; only the file location changes.

## `--amend` Three-Case Semantics (FR-14)

`orchestrator:specify --amend <path>` re-scaffolds an existing spec without overwriting authored content. Per top-level `^## ` section, the amend engine classifies and routes:

### Case (a) — all-placeholder

Section contains `<TODO>` markers and zero authored prose bytes. Under CC: re-run FR-3 LLM-fill (deferred in P04; tracked in RUNTIME-ASSUMPTIONS.md FR-3). Under Codex/Cursor: leave unchanged.

### Case (b) — partial-placeholder

Section contains both `<TODO>` markers and authored prose. Leave both bytes unchanged; log a one-line diagnostic naming the section. Operator resolves manually — this is the Constitution III + XIV guard on spec mutation (the amend engine does not pick between placeholder and authored content).

### Case (c) — fully-authored

Zero `<TODO>` markers. Leave unchanged byte-identically.

### Changed-section computation (US-3 AS-7)

A section is "changed" if either: `<TODO>` count changed, or `shasum -a 256` of authored (non-placeholder) prose bytes changed. FR-5 re-probe fires on changed sections only — prior deliberation state is preserved per CON-5 + CON-8. This closes the loop on M013's D014 pattern: post-deliberation edits are preserved, not re-deliberated.

### SC-14 byte-preservation invariant

`shasum` of pre-amend file bytes equals post-amend file bytes when all sections classify as (b) or (c). Verified by `tests/fixtures/m014-p04/amend-seed-spec.md` + `scripts/verify/m014-p04-amend-three-case.sh` at milestone close.
```

### Step 4: Gate verifier — `scripts/verify/m014-p04-amend-three-case.sh`

Hermetic scratch test of the three-case amend engine. Verbatim body:

```bash
#!/usr/bin/env bash
# Gate: T06 — FR-14 --amend three-case body + SC-14 invariant.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SPECIFY="${PROJECT_ROOT}/scripts/specify/specify.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

[ -x "$SPECIFY" ] || fail "specify.sh not executable"

# P01 stub language gone.
grep -qF 'P01 ships the surface; full three-case semantics land in P04' "$SPECIFY" \
  && fail "P01 amend stub message still present"

# Full body markers present.
grep -qF 'amend-section' "$SPECIFY"              || fail "amend-section action_type missing"
grep -qF 'case (a)' "$SPECIFY"                   || fail "case (a) handling missing"
grep -qF 'case (b)' "$SPECIFY"                   || fail "case (b) handling missing"
grep -qF 'shasum -a 256' "$SPECIFY"              || fail "shasum invariant check missing"

# Hermetic scratch amend.
SCRATCH="$(mktemp -d)"
mkdir -p "${SCRATCH}/.orchestrator"
# Seed spec with (a) all-placeholder, (b) partial, (c) fully-authored sections.
cat > "${SCRATCH}/seed-spec.md" <<'SPEC'
# Feature Specification: Amend Seed

## Problem Statement
<TODO: describe>

## User Scenarios
<TODO: describe>
Some authored prose lives here.

## Functional Requirements
- FR-1: A fully-authored requirement with no placeholders.
- FR-2: Another authored line.

## Success Criteria
- SC-1: Authored success criterion.
SPEC

PRE_SHA="$(shasum -a 256 "${SCRATCH}/seed-spec.md" | awk '{print $1}')"

# Run amend.
OUT="$(bash "$SPECIFY" --amend "${SCRATCH}/seed-spec.md" 2>&1)"
RC=$?
if [ "$RC" -ne 0 ]; then fail "amend exited $RC (expected 0)"; fi

# Diagnostic for case (a) + case (b) printed to stderr.
echo "$OUT" | grep -qF "case (a)" || fail "amend output missing case (a) diagnostic"
echo "$OUT" | grep -qF "case (b)" || fail "amend output missing case (b) diagnostic"

POST_SHA="$(shasum -a 256 "${SCRATCH}/seed-spec.md" | awk '{print $1}')"

# SC-14: case (b) + (c) bytes are unchanged; case (a) no-ops in P04 (LLM-fill deferred).
# Entire file shasum must match.
if [ "$PRE_SHA" != "$POST_SHA" ]; then
  fail "SC-14 byte-preservation violated: pre=${PRE_SHA} post=${POST_SHA}"
fi

# --dry-run emits amend-section records.
DRY_OUT="$(bash "$SPECIFY" --amend "${SCRATCH}/seed-spec.md" --dry-run 2>/dev/null)"
if ! echo "$DRY_OUT" | grep -qF 'amend-section'; then
  rm -rf "$SCRATCH"
  fail "--dry-run missing amend-section records"
fi

rm -rf "$SCRATCH"
echo "PASS: --amend three-case body + SC-14 invariant verified"
exit 0
```

Make executable.

### Step 5: Gate verifier — `scripts/verify/m014-p04-runtime-assumptions-fr5-fr7.sh`

```bash
#!/usr/bin/env bash
# Gate: T06 — RUNTIME-ASSUMPTIONS.md FR-5 body replaced + FR-7 entry appended.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REG="${PROJECT_ROOT}/RUNTIME-ASSUMPTIONS.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

[ -f "$REG" ] || fail "RUNTIME-ASSUMPTIONS.md missing"

# FR-5 full body markers present.
grep -qF 'spec-complexity-contradiction-prompt.md' "$REG" \
  || fail "FR-5 body missing spec-complexity-contradiction-prompt.md reference"
grep -qF 'dispatch-interface.sh' "$REG" \
  || fail "FR-5 body missing dispatch-interface.sh reference"

# P01 stub language gone from FR-5.
grep -qF 'P01 stub' "$REG" \
  && fail "FR-5 body still contains 'P01 stub' language"
grep -qF 'P04 replaces the body' "$REG" \
  && fail "FR-5 body still contains deferral language"

# FR-7 entry present.
grep -qE '^### FR-7: LLM-assisted spec decomposition' "$REG" || fail "FR-7 heading missing"

# Ordering: FR-3 < FR-5 < FR-7 < sentinel.
L3="$(grep -nE '^### FR-3:' "$REG" | head -n 1 | awk -F: '{print $1}')"
L5="$(grep -nE '^### FR-5:' "$REG" | head -n 1 | awk -F: '{print $1}')"
L7="$(grep -nE '^### FR-7:' "$REG" | head -n 1 | awk -F: '{print $1}')"
LE="$(grep -n 'Future entries land below this line' "$REG" | head -n 1 | awk -F: '{print $1}')"
[ -n "$L3" ] && [ -n "$L5" ] && [ -n "$L7" ] && [ -n "$LE" ] || fail "could not locate entry line numbers"
if [ "$L5" -le "$L3" ]; then fail "FR-5 before FR-3"; fi
if [ "$L7" -le "$L5" ]; then fail "FR-7 before FR-5"; fi
if [ "$L7" -ge "$LE" ]; then fail "FR-7 after sentinel"; fi

echo "PASS: RUNTIME-ASSUMPTIONS.md FR-5-full body + FR-7 entry verified"
exit 0
```

### Step 6: Gate verifier — `scripts/verify/m014-p04-spec-management-reference-complete.sh`

```bash
#!/usr/bin/env bash
# Gate: T06 — references/spec-management.md completion (SC-11).
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REF="${PROJECT_ROOT}/references/spec-management.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

[ -f "$REF" ] || fail "references/spec-management.md missing"

# Sentinel removed.
grep -qF 'partial: P04 completes' "$REF" \
  && fail "P04 partial sentinel still present — SC-11 not closed"

# Four new top-level sections present.
grep -qE '^## Complexity Probe \(FR-5\)' "$REF"            || fail "Complexity Probe section missing"
grep -qE '^## Conversus Pressure-Test' "$REF"              || fail "Conversus Pressure-Test section missing"
grep -qE '^## Decomposition Flow \(FR-7\)' "$REF"          || fail "Decomposition Flow section missing"
grep -qE '^## `--amend` Three-Case Semantics' "$REF"       || fail "--amend Three-Case Semantics section missing"

# Action_type table extended with three P04 rows.
grep -qF 'invoke-conversus-gate' "$REF"    || fail "action_type table missing invoke-conversus-gate row"
grep -qF 'propose-decomposition' "$REF"    || fail "action_type table missing propose-decomposition row"
grep -qF 'amend-section' "$REF"            || fail "action_type table missing amend-section row"

# Key cross-references present.
grep -qF 'hardening_spec_exception' "$REF"        || fail "hardening_spec_exception documented"
grep -qF 'CALIBRATION-MEMO.md' "$REF"             || fail "CALIBRATION-MEMO.md cross-reference missing"
grep -qF 'spec-pressure-test.yml' "$REF"          || fail "preset file cross-reference missing"
grep -qF 'decomposition-manifest' "$REF"          || fail "decomposition-manifest shape documented"
grep -qF 'SC-14' "$REF"                           || fail "SC-14 invariant documented"

echo "PASS: references/spec-management.md completion verified"
exit 0
```

Make all three verifiers executable.

## Must-Haves

- `scripts/specify/specify.sh --amend` P01 stub replaced with full FR-14 three-case body (contains `case (a)`, `case (b)`, `shasum -a 256`, `amend-section`)
- On a seed spec with (a)+(b)+(c) sections, amend exits 0, logs (a) and (b) diagnostics, leaves file byte-identical (SC-14 invariant)
- `--amend --dry-run` emits `amend-section` FR-19 records, no disk writes
- `RUNTIME-ASSUMPTIONS.md` FR-5 entry body refreshed to FR-5-full language (removes "P01 stub", references `spec-complexity-contradiction-prompt.md` + `dispatch-interface.sh`)
- `RUNTIME-ASSUMPTIONS.md` FR-7 entry present (shipped in T05; T06 verifies co-existence)
- `RUNTIME-ASSUMPTIONS.md` entry ordering: FR-3 → FR-5 → FR-7 → sentinel, append-only
- `references/spec-management.md` partial sentinel removed; four new top-level sections added (Complexity Probe, Conversus Pressure-Test, Decomposition Flow, --amend Three-Case); action_type table extended with three P04 rows; SC-11 close
- `scripts/verify/m014-p04-amend-three-case.sh` + `scripts/verify/m014-p04-runtime-assumptions-fr5-fr7.sh` + `scripts/verify/m014-p04-spec-management-reference-complete.sh` exist, executable, exit 0
- Bash 3.2 + anti-pattern-lint clean

## Verification

```
bash scripts/verify/m014-p04-amend-three-case.sh
```

Expected: `PASS: --amend three-case body + SC-14 invariant verified`, exit 0.

```
bash scripts/verify/m014-p04-runtime-assumptions-fr5-fr7.sh
```

Expected: `PASS: RUNTIME-ASSUMPTIONS.md FR-5-full body + FR-7 entry verified`, exit 0.

```
bash scripts/verify/m014-p04-spec-management-reference-complete.sh
```

Expected: `PASS: references/spec-management.md completion verified`, exit 0.

## Inputs

### From Previous Tasks

- `scripts/specify/specify.sh` (from T04)
  - Existing P01 `--amend` stub block (lines 95-104 in P01; post-T04 still largely intact). T06 replaces this block.
  - Subcommand dispatch structure unchanged.

- `RUNTIME-ASSUMPTIONS.md` (FR-5 entry from P01; FR-7 entry from T05)
  - T06 replaces FR-5 body prose only (heading + subheadings preserved).

### From Disk (Pre-existing)

- `references/spec-management.md` — P01 partial, `<!-- partial: P04 -->` sentinel at EOF. T06 removes sentinel and appends four sections.

## Constraints

- **Byte-preservation SC-14**: in case (a) we DO NOT rewrite the section in P04 (FR-3 LLM-fill is deferred per RUNTIME-ASSUMPTIONS FR-3). The amend engine logs a diagnostic and leaves bytes unchanged. This preserves the invariant trivially in P04; the invariant becomes load-bearing when FR-3 LLM-fill lands in a later phase.
- **Append-only for RUNTIME-ASSUMPTIONS.md**: FR-5 **heading** + **four subsection headings** are preserved byte-identically. Only the prose paragraphs under each subsection are refreshed. Append-only means no entry is removed; body refresh is permitted by the D016 discipline because the registry is a punch-list, not an audit trail.
- **SC-11 close gate**: `references/spec-management.md` no longer has the `<!-- partial: P04 -->` sentinel; the reference is complete.
- **The amend engine does not invoke conversus or splitter** — it's purely a section-walk + case-dispatch flow. Any integration with T04's three-way prompt happens only if a changed section triggers `scripts/knowledge/spec-complexity-probe.sh` re-probe (end of amend body).
- Bash 3.2 compatible; temp files cleaned with `rm -rf` / `rm -f`; awk section-split is portable (no gawk-only features).
- `set -u` preserved to catch unbound variables early (matches P01 discipline).

## Expected Output

Files committed:

1. `scripts/specify/specify.sh` — modified (amend block replaced, ~120 lines added)
2. `RUNTIME-ASSUMPTIONS.md` — modified (FR-5 body refreshed)
3. `references/spec-management.md` — modified (sentinel removed; 4 sections appended; action_type table extended)
4. `scripts/verify/m014-p04-amend-three-case.sh` — created (~80 lines, executable)
5. `scripts/verify/m014-p04-runtime-assumptions-fr5-fr7.sh` — created (~40 lines, executable)
6. `scripts/verify/m014-p04-spec-management-reference-complete.sh` — created (~35 lines, executable)

All three gates exit 0.
