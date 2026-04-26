---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P02"
milestone: "M024"
name: "Spec-shape classifier — replace P01 stubs for spec branch"
depends_on: []
---

## Prerequisites

- P01 complete: `templates/intake-proposal.md`, `scripts/intake/proposal-emit.sh`, `scripts/intake/shape-detect.sh`, `scripts/intake/intake-id-allocate.sh` all exist and are executable.
- The proposal emitter currently writes the P01 stub axis values (`scope_tier=A`, `decomposition=single-task`, `recommended_command=orchestrator:dispatch`, axis rationales = `"P01 stub — deep classifier ships in a later phase."`) for spec inputs. T01 replaces those stubs **only for the spec branch** (`input_shape=spec`); idea / fragment / empty branches retain P01 stubs (those land in later phases). The paragraph branch is already handled by P03's classifier.
- `scripts/state/spec-metrics.sh` is the M020 chunks-first metric source. Signature: `bash spec-metrics.sh <orch_root>` → emits `spec_chunks_present=true|false`, `story_count=N`, `requirement_count=N`, `acceptance_count=N`, `constraint_count=N`, `nfr_count=N`, `non_goal_count=N` to stdout. The orch_root argument resolves to a project that has chunks under `knowledge/spec/`. When `spec_chunks_present=false`, the classifier falls back to grep-counting the raw spec body.
- Bash 3.2 + POSIX sh portable. AD-19 single-script-file shape — no inline compound bash, no plain subshells, no `$(...)` containing pipes.

## Description

Author `scripts/intake/spec-shape-classify.sh` — a pure classifier that reads a spec path from `--spec-path <p>` and emits five key=value stdout lines to be consumed by `proposal-emit.sh`:

```
scope_tier=<A|B|C>
decomposition=<single-task|single-phase|milestone-with-phases|multi-milestone>
recommended_command=<orchestrator:roadmap>
metrics_source=<spec_chunks|raw_spec>
rationale_spec=<one-line evidence string citing slug + metrics_source + counts>
```

Then wire the classifier into `scripts/intake/proposal-emit.sh` so that when `input_shape=spec`, the emitter substitutes the four classifier outputs in place of the P01 stub values for `scope_tier`, `decomposition`, `recommended_command`. The other three axes (`design_gate`, `conversus_gate`, `intensity` — already wired in P01 via `intensity-recommend.sh`) are not modified by T01. P04 wires conversus, P07 wires design.

### Heuristic rules — tier derivation (mirrors `commands/evaluate.md` chunks-first / raw-spec path)

Order of evaluation (first match wins):

1. **Chunks-first**: if a `knowledge/spec/` tree exists at the project root (the same root that contains the supplied `--spec-path`), invoke `bash scripts/state/spec-metrics.sh <orch_root>`. Parse `spec_chunks_present` from stdout. When `true`, use `story_count`, `requirement_count`, `acceptance_count` directly. Set `metrics_source=spec_chunks`.

2. **Raw-spec fallback**: when `spec_chunks_present=false` (or `spec-metrics.sh` is unavailable), grep-count the raw spec at `<spec-path>`:
   - `story_count`: `grep -cE '^### User Story|^- \*\*US-' <spec>` (count "### User Story" headings or "- **US-" bullets).
   - `requirement_count`: `grep -cE '^- \*\*FR-' <spec>` (count FR-bullet markers).
   - `acceptance_count`: `grep -cE '^[0-9]+\. \*\*Given\*\*|^- \*\*Given\*\*' <spec>` (count Given/When/Then numbered or bulleted scenarios).
   - Set `metrics_source=raw_spec`.

### Tier classification thresholds (NG-1: inherited unchanged from `commands/evaluate.md`)

- **Tier A**: `requirement_count` ≤ 3 AND `acceptance_count` ≤ 5 AND `story_count` ≤ 1.
- **Tier C**: `requirement_count` ≥ 10 OR `acceptance_count` ≥ 15 OR `story_count` ≥ 4.
- **Tier B**: everything in between.

NG-1 holds: M024 does not re-tune these thresholds — they reproduce the existing `commands/evaluate.md` tier-classification surface. If `commands/evaluate.md` and this classifier ever diverge, the spec is the authority and the classifier is wrong.

### Tier → decomposition mapping

| Tier | Decomposition          | Recommended command |
|------|------------------------|---------------------|
| A    | single-task            | orchestrator:roadmap |
| B    | single-phase           | orchestrator:roadmap |
| C    | milestone-with-phases  | orchestrator:roadmap |

`recommended_command` is always `orchestrator:roadmap` for spec-path inputs per FR-6 byte-compat invariant — the spec-on-disk caller's downstream is the legacy `orchestrator:roadmap` flow regardless of tier. The proposal still records the tier; downstream commands (M013 sync, future M018 autonomous loop) read the tier from the proposal.

### `rationale_spec` format

One line, naming all four signals:

```
rationale_spec=spec <slug> — metrics_source=<spec_chunks|raw_spec>; stories=<N>, FRs=<N>, ACs=<N> — Tier <A|B|C> <decomposition>
```

Example: `rationale_spec=spec 023-github-native-integration — metrics_source=raw_spec; stories=6, FRs=11, ACs=18 — Tier C milestone-with-phases`.

### Wiring into proposal-emit.sh

In `scripts/intake/proposal-emit.sh`, **after** the existing paragraph-branch hook block (the `(3a)` block T01-P03 added) and **before** the `(4) Input hash.` block, add the spec-branch hook:

```bash
# (3b) Spec deep classifier (P02 — replaces P01 stubs for spec shape).
SPEC_CLASSIFY="$ROOT/scripts/intake/spec-shape-classify.sh"
spec_rationale=""
spec_evidence=""
if [ "$input_shape" = "spec" ] && [ -n "$SPEC_PATH" ] && [ -x "$SPEC_CLASSIFY" ]; then
  sc_out=$(bash "$SPEC_CLASSIFY" --spec-path "$SPEC_PATH" 2>/dev/null || true)
  sc_tier=$(echo "$sc_out" | sed -n 's/^scope_tier=//p')
  sc_decomp=$(echo "$sc_out" | sed -n 's/^decomposition=//p')
  sc_cmd=$(echo "$sc_out" | sed -n 's/^recommended_command=//p')
  sc_rat=$(echo "$sc_out" | sed -n 's/^rationale_spec=//p')
  sc_metrics=$(echo "$sc_out" | sed -n 's/^metrics_source=//p')
  case "$sc_tier" in A|B|C) scope_tier_override="$sc_tier" ;; esac
  case "$sc_decomp" in single-task|single-phase|milestone-with-phases|multi-milestone) decomposition_override="$sc_decomp" ;; esac
  case "$sc_cmd" in orchestrator:roadmap) recommended_command_override="$sc_cmd" ;; esac
  if [ -n "$sc_rat" ]; then
    spec_rationale="$sc_rat"
    spec_evidence="metrics_source=$sc_metrics (see scripts/intake/spec-shape-classify.sh)"
  fi
fi
```

The override variables (`scope_tier_override`, `decomposition_override`, `recommended_command_override`) are the SAME variables the paragraph hook uses — the existing `Apply paragraph-classifier overrides (P03).` block at line ~100 already consumes them, so no additional override-application code is needed for the three axes. The spec-branch only adds the `spec_rationale` / `spec_evidence` slot wiring (which T03 finishes — T01 only adds the classifier invocation and the override-variable wiring; T03 swaps the rationale into the body).

T01 does NOT touch the rationale-substitution loop — that lands in T03, which adds a SPEC_AXES_DONE sentinel mirroring the existing PARA_AXES_DONE pattern.

## Steps

1. **Create the classifier** at `scripts/intake/spec-shape-classify.sh`:

```bash
#!/usr/bin/env bash
# scripts/intake/spec-shape-classify.sh
# M024/P02/T01 — Spec-branch axis classifier (replaces P01 stubs for input_shape=spec).
#
# Inputs:
#   --spec-path <path>   Path to a feature spec (file with `type: feature-spec` frontmatter).
#
# Output (stdout, five lines):
#   scope_tier=<A|B|C>
#   decomposition=<single-task|single-phase|milestone-with-phases>
#   recommended_command=orchestrator:roadmap
#   metrics_source=<spec_chunks|raw_spec>
#   rationale_spec=<one-line evidence string>
#
# Exit 0 on success, 2 on usage error, 1 on internal error (spec missing / bad frontmatter).

set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SPEC_METRICS="$ROOT/scripts/state/spec-metrics.sh"

usage() {
  echo "usage: spec-shape-classify.sh --spec-path <path>" >&2
  exit 2
}

SPEC_PATH=""
while [ $# -gt 0 ]; do
  case "$1" in
    --spec-path) SPEC_PATH="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) usage ;;
  esac
done

[ -n "$SPEC_PATH" ] || usage
[ -f "$SPEC_PATH" ] || { echo "spec-shape-classify.sh: spec not found: $SPEC_PATH" >&2; exit 1; }

# Validate the spec carries the M014 interim manifest frontmatter.
if ! head -30 "$SPEC_PATH" | grep -q '^type: feature-spec'; then
  echo "spec-shape-classify.sh: not a feature-spec frontmatter: $SPEC_PATH" >&2
  exit 1
fi

# Derive slug from the spec's parent dir name (e.g. 023-github-native-integration).
slug=$(basename "$(dirname "$SPEC_PATH")")

# Default counts (raw-spec fallback).
metrics_source="raw_spec"
story_count=0
fr_count=0
ac_count=0

# Chunks-first path: invoke spec-metrics.sh if its tree is reachable.
proj_root=$(dirname "$(dirname "$SPEC_PATH")")
orch_root="$proj_root/.orchestrator"
if [ -d "$orch_root" ] && [ -x "$SPEC_METRICS" ]; then
  sm_out=$(bash "$SPEC_METRICS" "$orch_root" 2>/dev/null || true)
  chunks_present=$(echo "$sm_out" | sed -n 's/^spec_chunks_present=//p')
  if [ "$chunks_present" = "true" ]; then
    metrics_source="spec_chunks"
    story_count=$(echo "$sm_out" | sed -n 's/^story_count=//p')
    fr_count=$(echo "$sm_out" | sed -n 's/^requirement_count=//p')
    ac_count=$(echo "$sm_out" | sed -n 's/^acceptance_count=//p')
  fi
fi

# Raw-spec fallback if chunks did not provide values.
if [ "$metrics_source" = "raw_spec" ]; then
  story_count=$(grep -cE '^### User Story|^- \*\*US-' "$SPEC_PATH" || true)
  fr_count=$(grep -cE '^- \*\*FR-' "$SPEC_PATH" || true)
  ac_count=$(grep -cE '^[0-9]+\. \*\*Given\*\*|^- \*\*Given\*\*' "$SPEC_PATH" || true)
fi

# Tier classification (NG-1: inherited from commands/evaluate.md, not re-tuned).
tier="B"
decomposition="single-phase"
if [ "$fr_count" -ge 10 ] || [ "$ac_count" -ge 15 ] || [ "$story_count" -ge 4 ]; then
  tier="C"
  decomposition="milestone-with-phases"
elif [ "$fr_count" -le 3 ] && [ "$ac_count" -le 5 ] && [ "$story_count" -le 1 ]; then
  tier="A"
  decomposition="single-task"
fi

echo "scope_tier=$tier"
echo "decomposition=$decomposition"
echo "recommended_command=orchestrator:roadmap"
echo "metrics_source=$metrics_source"
echo "rationale_spec=spec $slug — metrics_source=$metrics_source; stories=$story_count, FRs=$fr_count, ACs=$ac_count — Tier $tier $decomposition"
exit 0
```

2. **Make it executable**: `chmod +x scripts/intake/spec-shape-classify.sh`.

3. **Edit `scripts/intake/proposal-emit.sh`** per the wiring snippet in the Description. Add the `(3b)` spec hook block immediately after the existing `(3a)` paragraph hook block. Do NOT modify the rationale-substitution loop — T03 wires the spec rationale slot.

4. **Write the verify script** at `scripts/verify/m024-p02-spec-shape-classify.sh`:

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p02-spec-shape-classify.sh
# Verifies spec-shape-classify.sh produces non-stub axis values across tier
# buckets AND that proposal-emit.sh wires the classifier when input_shape=spec.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CLASSIFY="$ROOT/scripts/intake/spec-shape-classify.sh"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"

[ -x "$CLASSIFY" ] || { echo "FAIL: $CLASSIFY not executable"; exit 1; }
[ -x "$EMIT" ]     || { echo "FAIL: $EMIT not executable"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Use an existing in-repo spec.
SPEC="$ROOT/specs/023-github-native-integration/spec.md"
[ -f "$SPEC" ] || { echo "FAIL: fixture spec missing: $SPEC"; exit 1; }

out=$(bash "$CLASSIFY" --spec-path "$SPEC")
echo "$out" | grep -qE '^scope_tier=[ABC]$'                    || { echo "FAIL: scope_tier not A/B/C — got: $out"; exit 1; }
echo "$out" | grep -qE '^decomposition=(single-task|single-phase|milestone-with-phases)$' || { echo "FAIL: decomposition wrong"; exit 1; }
echo "$out" | grep -q  '^recommended_command=orchestrator:roadmap$' || { echo "FAIL: recommended_command not orchestrator:roadmap"; exit 1; }
echo "$out" | grep -qE '^metrics_source=(spec_chunks|raw_spec)$' || { echo "FAIL: metrics_source wrong"; exit 1; }
echo "$out" | grep -q  '^rationale_spec=spec '                  || { echo "FAIL: rationale_spec missing slug prefix"; exit 1; }

# End-to-end: emitter consumes classifier on spec branch.
emit_out=$(bash "$EMIT" --spec-path "$SPEC" --intake-root "$tmp/intake")
proposal_path=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal_path" ] || { echo "FAIL: emitter did not produce a proposal"; exit 1; }

grep -qE '^scope_tier: "[ABC]"' "$proposal_path"            || { echo "FAIL: proposal scope_tier missing"; exit 1; }
grep -qE '^decomposition: "(single-task|single-phase|milestone-with-phases)"' "$proposal_path" || { echo "FAIL: proposal decomposition missing"; exit 1; }
grep -q  '^recommended_command: "orchestrator:roadmap"' "$proposal_path" || { echo "FAIL: proposal recommended_command not roadmap"; exit 1; }

# P01 stub MUST NOT appear on scope_tier or decomposition slots for spec inputs.
if grep -E '(rationale_scope_tier|rationale_decomposition|Rationale.*Tier).*P01 stub' "$proposal_path" >/dev/null 2>&1; then
  echo "FAIL: spec proposal still carries P01-stub rationale on scope_tier/decomposition"
  exit 1
fi

echo "PASS: spec-shape-classify.sh — tier classification + emitter wiring"
exit 0
```

## Must-Haves

- `scripts/intake/spec-shape-classify.sh` exists, is executable, and emits the five required key=value stdout lines on every valid spec-path input.
- The tier classification thresholds (`fr_count`/`ac_count`/`story_count` buckets per the `commands/evaluate.md` rules) are inherited unchanged (NG-1) — same input → same tier.
- `scripts/intake/proposal-emit.sh` invokes the classifier when `input_shape=spec` and wires the override variables for `scope_tier`, `decomposition`, `recommended_command`. T03 wires the rationale-slot swap; T01 only sets up the classifier invocation and the variable wiring.
- The emitted proposal for a spec input does NOT carry the P01-stub rationale string on `scope_tier` or `decomposition` slots (T03 closes the input_shape rationale slot for spec branch).
- The classifier writes nothing to disk — pure stdout (SB-3 invariant).
- AD-19 harness shape: every external invocation in the verify script is single-script-file form.

## Verification

```
bash scripts/verify/m024-p02-spec-shape-classify.sh
```

Expected output (exit 0): `PASS: spec-shape-classify.sh — tier classification + emitter wiring`

## Inputs

### From Previous Tasks

- `scripts/intake/proposal-emit.sh` (from M024/P01/T04, modified by M024/P03/T01) — modified by this task. Key API (existing): `bash proposal-emit.sh [--input <s>] [--spec-path <p>] [--intake-root <d>]` → emits `proposal_path=<absolute path>`. Existing override variables this task wires: `scope_tier_override`, `decomposition_override`, `recommended_command_override` (consumed by the existing paragraph-branch override block — same variables for spec branch). Internal hook variables this task adds: `spec_rationale`, `spec_evidence`.
- `scripts/intake/shape-detect.sh` (from M024/P01/T03) — read-only consumer; classifies inputs into `spec` shape that this task's classifier deepens.
- `templates/intake-proposal.md` (from M024/P01/T01) — read-only consumer; the frontmatter keys `scope_tier`, `decomposition`, `recommended_command` are the substitution targets.
- `scripts/intake/paragraph-classify.sh` (from M024/P03/T01) — sibling pattern reference; the spec-branch hook mirrors the paragraph-branch hook shape.

### From Disk (Pre-existing)

- `scripts/state/spec-metrics.sh` — chunks-first metric source. Signature: `bash spec-metrics.sh <orch_root>` → emits `spec_chunks_present`, `story_count`, `requirement_count`, `acceptance_count` to stdout.
- `specs/023-github-native-integration/spec.md` — in-repo fixture spec used by the verify script (and by T03's baseline capture).
- `grep`, `head`, `sed -n`, `echo`, `dirname`, `basename` — POSIX utilities.

## Constraints

- POSIX sh + bash 3.2 portable.
- Pure classifier — no disk writes, no temp files, no subprocess fanout. Reads `--spec-path` from argv only.
- AD-19 single-script-file shape: every command in the verify script is a top-level bash invocation; no inline compound bash, no plain subshells, no `$(...)` containing pipes.
- The classifier is idempotent: identical input → byte-identical stdout.
- NG-1: tier-classification thresholds inherited unchanged from `commands/evaluate.md`. No new thresholds.
- No conversus invocations, no knowledge writes (NG-2, NG-5).

## Expected Output

`scripts/intake/spec-shape-classify.sh` exists and is executable; `scripts/intake/proposal-emit.sh` wires the classifier on the spec branch; `scripts/verify/m024-p02-spec-shape-classify.sh` exits 0 with `PASS:`.
