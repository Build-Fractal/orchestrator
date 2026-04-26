---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P02"
milestone: "M024"
name: "Backcompat baseline capture + spec-path emitter rationale wiring"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete: `scripts/intake/spec-shape-classify.sh` exists, is executable, and the `(3b)` spec hook block in `scripts/intake/proposal-emit.sh` populates `spec_rationale` and `spec_evidence` shell variables when `input_shape=spec`.
- The proposal emitter currently leaves the `rationale_input_shape` / `evidence_input_shape` slot at the P01 stub for spec inputs (T01 only wired scope_tier / decomposition / recommended_command — the input_shape rationale slot needs T03's swap).
- `commands/evaluate.md` documents the chunks-first / raw-spec metric path (lines ~67–86 — the `## Scope Analysis` section). Same metric extraction this task reproduces in the baseline-capture script.
- The P03 paragraph-branch wiring established the `PARA_AXES_DONE` sentinel pattern — T03 mirrors that with `SPEC_AXES_DONE`.
- Bash 3.2 + POSIX sh portable. AD-19 single-script-file shape.

## Description

Two deliverables:

### (a) Capture the pre-M024 baseline fixture

Author `tests/fixtures/evaluate-pre-m024-baseline.txt` — the today-shape evaluation metric output for `specs/023-github-native-integration/spec.md`. Format: one `key=value` line per metric. The four required metrics (matching `commands/evaluate.md`'s `## Scope Analysis` output):

```
metrics_source=raw_spec
story_count=<N>
requirement_count=<N>
acceptance_count=<N>
```

The capture is performed once by hand (or by a one-shot capture script invoked via `bash` in the steps below) — the fixture is then committed and becomes the byte-compat baseline downstream tests `diff` against. The fixture includes a leading `#` comment block naming the source spec, the date of capture, and a note that any future `commands/evaluate.md` change to the metric path requires re-capture.

The capture method for `023-github-native-integration` MUST use the same metric-extraction logic the new `scripts/intake/spec-shape-classify.sh` uses (T01's raw-spec fallback path, since 023 has no `knowledge/spec/` chunks today): the same grep regex set, applied to the same spec file. This guarantees the byte-compat assertion in T04 is meaningful (the test exercises the same code path the baseline captured).

### (b) Wire the spec rationale slot into proposal-emit.sh

Modify the existing rationale-substitution loop in `scripts/intake/proposal-emit.sh` (around lines 200–220, after the `Paragraph branch overrides P01 stubs` block T01-P03 added) to mirror the same sentinel pattern for the spec branch.

Add — immediately AFTER the existing `if [ -n "${paragraph_rationale:-}" ]; then ... fi` block — a sibling spec block:

```bash
# Spec branch overrides P01 stubs for input_shape rationale slot (P02/T03).
# (scope_tier / decomposition rationales are wired by re-using paragraph_rationale-style
#  swap below; the input_shape slot is the spec-specific rationale.)
if [ -n "${spec_rationale:-}" ]; then
  swap rationale_input_shape "$spec_rationale"
  swap evidence_input_shape  "$spec_evidence"
  swap rationale_scope_tier "$spec_rationale"
  swap evidence_scope_tier  "$spec_evidence"
  swap rationale_decomposition "$spec_rationale"
  swap evidence_decomposition  "$spec_evidence"
  SPEC_AXES_DONE=1
fi
```

Then modify the rationale-substitution `for` loop guard to also skip when `SPEC_AXES_DONE=1`:

```bash
for axis in input_shape scope_tier decomposition design_gate conversus_gate intensity; do
  if [ "${PARA_AXES_DONE:-0}" = "1" ] && [ "$axis" = "scope_tier" -o "$axis" = "decomposition" ]; then
    continue
  fi
  if [ "${SPEC_AXES_DONE:-0}" = "1" ] && [ "$axis" = "input_shape" -o "$axis" = "scope_tier" -o "$axis" = "decomposition" ]; then
    continue
  fi
  swap "rationale_${axis}" "$stub_rationale"
  swap "evidence_${axis}" "$stub_evidence"
done
```

The two sentinel blocks are mutually-exclusive in practice (`paragraph_rationale` is only set when `input_shape=paragraph`; `spec_rationale` is only set when `input_shape=spec`) so there is no ordering concern between them.

## Steps

1. **Create the baseline-capture helper** (one-shot script, lives at `scripts/intake/_capture-baseline.sh` and is invoked once during this task — NOT shipped as a verify):

```bash
#!/usr/bin/env bash
# scripts/intake/_capture-baseline.sh
# M024/P02/T03 — One-shot baseline capture for tests/fixtures/evaluate-pre-m024-baseline.txt.
# Re-runs the same raw-spec grep counts that scripts/intake/spec-shape-classify.sh uses.
#
# Invoked once at T03 author time. Not part of the verify suite; the baseline is the
# committed artifact, not the script.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SPEC="$ROOT/specs/023-github-native-integration/spec.md"
[ -f "$SPEC" ] || { echo "missing: $SPEC" >&2; exit 1; }

story_count=$(grep -cE '^### User Story|^- \*\*US-' "$SPEC" || true)
fr_count=$(grep -cE '^- \*\*FR-' "$SPEC" || true)
ac_count=$(grep -cE '^[0-9]+\. \*\*Given\*\*|^- \*\*Given\*\*' "$SPEC" || true)

cat <<EOF
# tests/fixtures/evaluate-pre-m024-baseline.txt
# M024/P02/T03 — Pre-M024 evaluation baseline for specs/023-github-native-integration/spec.md.
# Captured: $(date -u +%Y-%m-%d)
# Re-capture if commands/evaluate.md ## Scope Analysis metric extraction changes.
metrics_source=raw_spec
story_count=$story_count
requirement_count=$fr_count
acceptance_count=$ac_count
EOF
```

Run:

```bash
bash scripts/intake/_capture-baseline.sh > tests/fixtures/evaluate-pre-m024-baseline.txt
```

2. **Verify the captured fixture** has at least the four required key=value lines:

```bash
grep -q '^metrics_source=' tests/fixtures/evaluate-pre-m024-baseline.txt
grep -q '^story_count=' tests/fixtures/evaluate-pre-m024-baseline.txt
grep -q '^requirement_count=' tests/fixtures/evaluate-pre-m024-baseline.txt
grep -q '^acceptance_count=' tests/fixtures/evaluate-pre-m024-baseline.txt
```

3. **Edit `scripts/intake/proposal-emit.sh`** per the wiring snippet in the Description. Add the spec-branch sentinel block immediately after the existing paragraph-branch sentinel block. Modify the rationale-substitution `for` loop to also honor `SPEC_AXES_DONE`.

4. **Write the verify script** at `scripts/verify/m024-p02-spec-rationale.sh`:

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p02-spec-rationale.sh
# Verifies proposal-emit.sh wires the spec-branch rationale slot — input_shape
# rationale carries the spec_rationale string from the classifier (not the P01 stub).

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
SPEC="$ROOT/specs/023-github-native-integration/spec.md"

[ -x "$EMIT" ] || { echo "FAIL: $EMIT not executable"; exit 1; }
[ -f "$SPEC" ] || { echo "FAIL: fixture spec missing: $SPEC"; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

emit_out=$(bash "$EMIT" --spec-path "$SPEC" --intake-root "$tmp/intake")
proposal_path=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal_path" ] || { echo "FAIL: emitter did not produce a proposal"; exit 1; }

# input_shape rationale slot must NOT carry P01 stub for spec inputs.
# It must instead reference the spec slug + metrics_source.
if grep -E 'rationale_input_shape.*P01 stub' "$proposal_path" >/dev/null 2>&1; then
  echo "FAIL: spec proposal carries P01-stub rationale on input_shape slot"
  exit 1
fi

# Affirmative: the spec rationale string ("spec <slug> — metrics_source=...") appears.
if ! grep -q 'spec 023-github-native-integration' "$proposal_path"; then
  echo "FAIL: spec rationale does not reference slug 023-github-native-integration"
  exit 1
fi
if ! grep -qE 'metrics_source=(spec_chunks|raw_spec)' "$proposal_path"; then
  echo "FAIL: spec rationale missing metrics_source signal"
  exit 1
fi

echo "PASS: spec-rationale wiring — input_shape slot carries spec rationale, no P01 stub"
exit 0
```

5. **Write the baseline-fixture verify script** at `scripts/verify/m024-p02-evaluate-spec-backcompat.sh` (this is the byte-compat regression check — re-runs the same grep counts and `diff`s against the captured fixture):

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p02-evaluate-spec-backcompat.sh
# Verifies the today-shape evaluation metric output for the captured spec is
# byte-compatible vs tests/fixtures/evaluate-pre-m024-baseline.txt.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SPEC="$ROOT/specs/023-github-native-integration/spec.md"
BASELINE="$ROOT/tests/fixtures/evaluate-pre-m024-baseline.txt"

[ -f "$SPEC" ]     || { echo "FAIL: fixture spec missing: $SPEC"; exit 1; }
[ -f "$BASELINE" ] || { echo "FAIL: baseline fixture missing: $BASELINE"; exit 1; }

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

# Re-run the same metric extraction the baseline used.
story_count=$(grep -cE '^### User Story|^- \*\*US-' "$SPEC" || true)
fr_count=$(grep -cE '^- \*\*FR-' "$SPEC" || true)
ac_count=$(grep -cE '^[0-9]+\. \*\*Given\*\*|^- \*\*Given\*\*' "$SPEC" || true)

# Emit the same key=value shape as the baseline, in the same order.
{
  echo "metrics_source=raw_spec"
  echo "story_count=$story_count"
  echo "requirement_count=$fr_count"
  echo "acceptance_count=$ac_count"
} > "$tmp"

# diff baseline-stripped-of-comments against the live output.
baseline_data=$(mktemp)
trap 'rm -f "$tmp" "$baseline_data"' EXIT
grep -v '^#' "$BASELINE" | grep -v '^$' > "$baseline_data"

if ! diff -q "$baseline_data" "$tmp" >/dev/null 2>&1; then
  echo "FAIL: today-shape metrics drifted from baseline"
  echo "----- baseline -----"; cat "$baseline_data"
  echo "----- live -----"; cat "$tmp"
  exit 1
fi

echo "PASS: evaluate-spec-backcompat — today-shape metrics byte-identical to baseline"
exit 0
```

## Must-Haves

- `tests/fixtures/evaluate-pre-m024-baseline.txt` exists, contains four `key=value` lines (`metrics_source`, `story_count`, `requirement_count`, `acceptance_count`), and a leading `#` comment block naming the source spec + capture date.
- `scripts/intake/proposal-emit.sh` carries a `SPEC_AXES_DONE` sentinel block mirroring the existing `PARA_AXES_DONE` pattern; the rationale-loop guard honors both sentinels.
- The emitted proposal for a spec input does NOT carry the P01-stub rationale on the `input_shape`, `scope_tier`, or `decomposition` slots; instead, the spec rationale string from T01's classifier (referencing the spec slug + `metrics_source` + counts) appears in those slots.
- The baseline fixture is byte-identical to the metric output of the same grep-extraction logic re-run by the backcompat verify — `diff` exits 0.
- All P02 verify scripts respect AD-19 single-script-file shape.
- SB-3 write-confinement: `scripts/intake/_capture-baseline.sh` writes to stdout only; `tests/fixtures/evaluate-pre-m024-baseline.txt` is the only new disk write outside `.orchestrator/intake/<id>/`.

## Verification

```
bash scripts/verify/m024-p02-spec-rationale.sh
bash scripts/verify/m024-p02-evaluate-spec-backcompat.sh
```

Expected output (each exits 0):
- `PASS: spec-rationale wiring — input_shape slot carries spec rationale, no P01 stub`
- `PASS: evaluate-spec-backcompat — today-shape metrics byte-identical to baseline`

## Inputs

### From Previous Tasks

- `scripts/intake/proposal-emit.sh` (modified by T01) — T01 added the `(3b)` spec hook setting `spec_rationale` / `spec_evidence`. T03 wires those variables into the rationale-substitution loop via a `SPEC_AXES_DONE` sentinel.
- `scripts/intake/spec-shape-classify.sh` (from T01) — emits the `rationale_spec=spec <slug> — metrics_source=...` line whose value flows through `spec_rationale` into the proposal body.
- `templates/intake-proposal.md` (from M024/P01/T01) — read-only consumer; the `{{rationale_input_shape}}` / `{{evidence_input_shape}}` placeholders are the swap targets.

### From Disk (Pre-existing)

- `specs/023-github-native-integration/spec.md` — fixture spec for baseline capture.
- `commands/evaluate.md` — authoritative source for the metric-extraction regex set; T03's grep patterns mirror it.
- `grep`, `sed -n`, `echo`, `mktemp`, `diff`, `cat`, `date` — POSIX utilities.

## Constraints

- POSIX sh + bash 3.2 portable.
- The baseline-capture helper (`_capture-baseline.sh`) is a one-shot artifact — invoked once, output committed as the fixture. It is NOT a verify, NOT in the suite, NOT idempotent in the sense of "re-running on a different day produces a different file" (the date in the comment changes).
- The backcompat verify (`m024-p02-evaluate-spec-backcompat.sh`) IS idempotent: same spec + same grep regex → same metrics → byte-identical to the captured fixture.
- AD-19 single-script-file shape: every command in every verify script is a top-level bash invocation; no `<(...)` process substitution, no plain subshells, no `$(...)` containing pipes.
- NG-5: no knowledge writes. The baseline fixture is a test fixture, not a knowledge entry.

## Expected Output

`tests/fixtures/evaluate-pre-m024-baseline.txt` exists with four metric lines + comment header; `scripts/intake/proposal-emit.sh` carries the SPEC_AXES_DONE wiring; both T03 verify scripts exit 0 with `PASS:`.
