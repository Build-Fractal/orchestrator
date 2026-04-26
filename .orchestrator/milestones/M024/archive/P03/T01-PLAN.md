---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P03"
milestone: "M024"
name: "Paragraph classifier — replace P01 stubs for paragraph branch"
depends_on: []
---

## Prerequisites

- P01 complete: `templates/intake-proposal.md`, `scripts/intake/proposal-emit.sh`, `scripts/intake/shape-detect.sh`, `scripts/intake/intake-id-allocate.sh` all exist and are executable.
- The proposal emitter (`scripts/intake/proposal-emit.sh`) currently writes the P01 stub axis values (`scope_tier=A`, `decomposition=single-task`, `recommended_command=orchestrator:dispatch`, all axis rationales = `"P01 stub — deep classifier ships in a later phase."`) for every input shape. T01 replaces those stubs **only for the paragraph branch**; spec / idea / fragment / empty branches retain P01 stubs (those land in later phases).
- Bash 3.2 + POSIX sh portable. AD-19 single-script-file shape — no inline compound bash, no plain subshells, no `$(...)` containing pipes.

## Description

Author `scripts/intake/paragraph-classify.sh` — a pure classifier that reads a paragraph-shaped input from `--input <string>` and emits four key=value stdout lines to be consumed by `proposal-emit.sh`:

```
scope_tier=<A|B|C>
decomposition=<single-task|single-phase|milestone-with-phases|multi-milestone>
recommended_command=<orchestrator:dispatch|orchestrator:specify>
rationale_paragraph=<one-line evidence string citing word-count + structural-marker counts>
```

Then wire the classifier into `scripts/intake/proposal-emit.sh` so that when `input_shape=paragraph`, the emitter substitutes the four classifier outputs in place of the P01 stub values **for those three axes plus the paragraph rationale slot**. The other three axes (`design_gate`, `conversus_gate`, `intensity` — already wired in P01 via `intensity-recommend.sh`) are not modified by T01. P04 wires conversus, P07 wires design.

### Heuristic rules (resolves spec #Q-1 paragraph-branch tier mapping)

Order of evaluation (first match wins):

1. **Tier C trigger** — paragraph mentions any of the lexical markers `milestone`, `phases`, `roadmap`, `multi-phase`, `cross-phase` (case-insensitive, word-boundary), OR the paragraph contains 3+ structural FR-bullet markers (`^-[[:space:]]+FR-`). Emit `scope_tier=C`, `decomposition=milestone-with-phases`, `recommended_command=orchestrator:specify`.

2. **Tier B trigger** — word count 31–80 AND not Tier-C-triggered. Emit `scope_tier=B`, `decomposition=single-phase`, `recommended_command=orchestrator:specify`.

3. **Tier A default** — word count ≤30 AND not Tier-C-triggered. Emit `scope_tier=A`, `decomposition=single-task`, `recommended_command=orchestrator:dispatch`.

The `rationale_paragraph` line names the matched rule and the supporting count: e.g., `rationale_paragraph=paragraph 47 words, 0 FR-bullets, 0 milestone-markers — Tier B single-phase`.

### Wiring into proposal-emit.sh

In `scripts/intake/proposal-emit.sh`, immediately after the existing intensity-fallback block (after the `intensity` variable is set), add a paragraph-branch hook:

```bash
# (3a) Paragraph deep classifier (P03 — replaces P01 stubs for paragraph shape).
PARA_CLASSIFY="$ROOT/scripts/intake/paragraph-classify.sh"
if [ "$input_shape" = "paragraph" ] && [ -x "$PARA_CLASSIFY" ]; then
  pc_out=$(bash "$PARA_CLASSIFY" --input "$INPUT" 2>/dev/null || true)
  pc_tier=$(echo "$pc_out" | sed -n 's/^scope_tier=//p')
  pc_decomp=$(echo "$pc_out" | sed -n 's/^decomposition=//p')
  pc_cmd=$(echo "$pc_out" | sed -n 's/^recommended_command=//p')
  pc_rat=$(echo "$pc_out" | sed -n 's/^rationale_paragraph=//p')
  case "$pc_tier" in A|B|C) scope_tier="$pc_tier" ;; esac
  case "$pc_decomp" in single-task|single-phase|milestone-with-phases|multi-milestone) decomposition="$pc_decomp" ;; esac
  case "$pc_cmd" in orchestrator:dispatch|orchestrator:specify) recommended_command="$pc_cmd" ;; esac
  if [ -n "$pc_rat" ]; then
    paragraph_rationale="$pc_rat"
    paragraph_evidence="word-count + structural-marker classification (see scripts/intake/paragraph-classify.sh)"
  fi
fi
```

Then, in the existing rationale-substitution loop near the end of the script, **before** the loop runs, special-case the three paragraph-touched axes when a `paragraph_rationale` value is set:

```bash
# Paragraph branch overrides P01 stubs for tier / decomposition / recommended_command.
if [ -n "${paragraph_rationale:-}" ]; then
  swap rationale_scope_tier "$paragraph_rationale"
  swap evidence_scope_tier  "$paragraph_evidence"
  swap rationale_decomposition "$paragraph_rationale"
  swap evidence_decomposition  "$paragraph_evidence"
  # input_shape rationale stays at the P01 stub (shape itself was already deeply detected).
  PARA_AXES_DONE=1
fi
```

And modify the existing `for axis in input_shape scope_tier decomposition design_gate conversus_gate intensity; do` loop so it skips `scope_tier` and `decomposition` when `PARA_AXES_DONE=1`:

```bash
for axis in input_shape scope_tier decomposition design_gate conversus_gate intensity; do
  if [ "${PARA_AXES_DONE:-0}" = "1" ] && [ "$axis" = "scope_tier" -o "$axis" = "decomposition" ]; then
    continue
  fi
  swap "rationale_${axis}" "$stub_rationale"
  swap "evidence_${axis}" "$stub_evidence"
done
```

## Steps

1. **Create the classifier** at `scripts/intake/paragraph-classify.sh`:

```bash
#!/usr/bin/env bash
# scripts/intake/paragraph-classify.sh
# M024/P03/T01 — Paragraph-branch axis classifier (resolves #Q-1 paragraph tier mapping).
#
# Input:
#   --input <string>   The paragraph-shaped input.
#
# Output (stdout, four lines):
#   scope_tier=<A|B|C>
#   decomposition=<single-task|single-phase|milestone-with-phases|multi-milestone>
#   recommended_command=<orchestrator:dispatch|orchestrator:specify>
#   rationale_paragraph=<one-line evidence string>
#
# Exit 0 on success, 2 on usage error.

set -u

usage() {
  echo "usage: paragraph-classify.sh --input <string>" >&2
  exit 2
}

INPUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --input) INPUT="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) usage ;;
  esac
done

[ -n "$INPUT" ] || usage

# Word count.
words=$(echo "$INPUT" | tr -s '[:space:]' '\n' | grep -c .)

# Structural FR-bullet count.
fr_bullets=$(echo "$INPUT" | grep -cE '^-[[:space:]]+FR-' || true)

# Tier C lexical triggers (case-insensitive, word-boundary).
tier_c_markers=0
if echo "$INPUT" | grep -qiE '\bmilestone\b|\bphases\b|\broadmap\b|\bmulti-phase\b|\bcross-phase\b'; then
  tier_c_markers=1
fi

# Decision table.
if [ "$tier_c_markers" -eq 1 ] || [ "$fr_bullets" -ge 3 ]; then
  echo "scope_tier=C"
  echo "decomposition=milestone-with-phases"
  echo "recommended_command=orchestrator:specify"
  echo "rationale_paragraph=paragraph $words words, $fr_bullets FR-bullets, $tier_c_markers milestone-markers — Tier C milestone-with-phases"
  exit 0
fi

if [ "$words" -ge 31 ] && [ "$words" -le 80 ]; then
  echo "scope_tier=B"
  echo "decomposition=single-phase"
  echo "recommended_command=orchestrator:specify"
  echo "rationale_paragraph=paragraph $words words, $fr_bullets FR-bullets, 0 milestone-markers — Tier B single-phase"
  exit 0
fi

# Tier A default.
echo "scope_tier=A"
echo "decomposition=single-task"
echo "recommended_command=orchestrator:dispatch"
echo "rationale_paragraph=paragraph $words words, $fr_bullets FR-bullets, 0 milestone-markers — Tier A single-task"
exit 0
```

2. **Make it executable**: `chmod +x scripts/intake/paragraph-classify.sh`.

3. **Edit `scripts/intake/proposal-emit.sh`** per the wiring snippets in the Description. Add the `(3a)` paragraph hook block after the existing intensity-fallback block, and modify the rationale-loop to skip `scope_tier` / `decomposition` when paragraph axes have been overridden.

4. **Write the verify script** at `scripts/verify/m024-p03-paragraph-classify.sh`:

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p03-paragraph-classify.sh
# Verifies paragraph-classify.sh produces non-stub axis values across the three
# tier-bucket cases AND that proposal-emit.sh wires the classifier when input_shape=paragraph.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CLASSIFY="$ROOT/scripts/intake/paragraph-classify.sh"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"

[ -x "$CLASSIFY" ] || { echo "FAIL: $CLASSIFY not executable"; exit 1; }
[ -x "$EMIT" ]     || { echo "FAIL: $EMIT not executable"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Tier A case (~15 words, no markers).
out_a=$(bash "$CLASSIFY" --input "Add a last-seen timestamp to the status command output and cache it for five seconds.")
echo "$out_a" | grep -q '^scope_tier=A$'         || { echo "FAIL: tier-A case did not classify A — got: $out_a"; exit 1; }
echo "$out_a" | grep -q '^decomposition=single-task$' || { echo "FAIL: tier-A decomposition wrong"; exit 1; }
echo "$out_a" | grep -q '^recommended_command=orchestrator:dispatch$' || { echo "FAIL: tier-A command wrong"; exit 1; }

# Tier B case (50-ish words, no Tier-C markers).
para_b="We should redesign the status command output to include a last-seen timestamp, a cache layer with five-second TTL, and a no-cache flag for callers that need fresh data. Also consider a verbose mode that prints the underlying lock-manager state for debugging stuck locks across runs."
out_b=$(bash "$CLASSIFY" --input "$para_b")
echo "$out_b" | grep -q '^scope_tier=B$'         || { echo "FAIL: tier-B case did not classify B — got: $out_b"; exit 1; }
echo "$out_b" | grep -q '^decomposition=single-phase$' || { echo "FAIL: tier-B decomposition wrong"; exit 1; }
echo "$out_b" | grep -q '^recommended_command=orchestrator:specify$' || { echo "FAIL: tier-B command wrong"; exit 1; }

# Tier C case — milestone marker triggers C.
para_c="Plan a new milestone with multiple phases that overhauls the status command surface."
out_c=$(bash "$CLASSIFY" --input "$para_c")
echo "$out_c" | grep -q '^scope_tier=C$'         || { echo "FAIL: tier-C case did not classify C — got: $out_c"; exit 1; }
echo "$out_c" | grep -q '^decomposition=milestone-with-phases$' || { echo "FAIL: tier-C decomposition wrong"; exit 1; }

# End-to-end: emitter consumes classifier on paragraph branch.
emit_out=$(bash "$EMIT" --input "$para_b" --intake-root "$tmp/intake")
proposal_path=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal_path" ] || { echo "FAIL: emitter did not produce a proposal"; exit 1; }
grep -q '^scope_tier: "B"' "$proposal_path"      || { echo "FAIL: proposal scope_tier not B"; exit 1; }
grep -q '^decomposition: "single-phase"' "$proposal_path" || { echo "FAIL: proposal decomposition not single-phase"; exit 1; }
if grep -q 'P01 stub — deep classifier ships' "$proposal_path"; then
  # P01 stub may still appear for design_gate / conversus_gate / input_shape — those are not P03 scope.
  # But it MUST NOT appear in the scope_tier or decomposition rationale lines.
  if grep -E '(rationale_scope_tier|rationale_decomposition|Rationale.*Tier).*P01 stub' "$proposal_path" >/dev/null 2>&1; then
    echo "FAIL: paragraph proposal still carries P01-stub rationale on scope_tier/decomposition"
    exit 1
  fi
fi

echo "PASS: paragraph-classify.sh — tier A/B/C cases + emitter wiring"
exit 0
```

## Must-Haves

- `scripts/intake/paragraph-classify.sh` exists, is executable, and emits the four required key=value stdout lines on every paragraph input.
- The three tier buckets (A: ≤30 words; B: 31–80 words; C: any milestone-lexical-marker OR ≥3 FR-bullets) are deterministic — same input → same classification.
- `scripts/intake/proposal-emit.sh` invokes the classifier when `input_shape=paragraph` and substitutes the classifier's `scope_tier`, `decomposition`, `recommended_command`, and `rationale_paragraph` into the proposal frontmatter / body.
- The emitted proposal for a paragraph input does NOT carry the P01-stub rationale string (`P01 stub — deep classifier ships in a later phase.`) on the `scope_tier` or `decomposition` rationale lines.
- The classifier writes nothing to disk — pure stdout (SB-3 invariant).
- AD-19 harness shape: every external invocation is single-script-file form.

## Verification

```
bash scripts/verify/m024-p03-paragraph-classify.sh
```

Expected output (exit 0): `PASS: paragraph-classify.sh — tier A/B/C cases + emitter wiring`

## Inputs

### From Previous Tasks

- `scripts/intake/proposal-emit.sh` (from M024/P01/T04) — modified by this task. Key API (existing): `bash proposal-emit.sh --input <s> [--spec-path <p>] [--intake-root <d>]` → emits `proposal_path=<absolute path>`. Internal hook variables this task adds: `paragraph_rationale`, `paragraph_evidence`, `PARA_AXES_DONE`.
- `scripts/intake/shape-detect.sh` (from M024/P01/T03) — read-only consumer; classifies inputs into `paragraph` shape that this task's classifier deepens.
- `templates/intake-proposal.md` (from M024/P01/T01) — read-only consumer; the frontmatter keys `scope_tier`, `decomposition`, `recommended_command` and body slots `rationale_scope_tier` / `evidence_scope_tier` / `rationale_decomposition` / `evidence_decomposition` are the substitution targets.

### From Disk (Pre-existing)

- `grep`, `tr`, `sed -n`, `echo` — POSIX utilities. No `awk` required for the classifier itself.

## Constraints

- POSIX sh + bash 3.2 portable.
- Pure classifier — no disk writes, no temp files, no subprocess fanout. Reads `--input` from argv only.
- AD-19 single-script-file shape: every command in the verify script is a top-level bash invocation; no inline compound bash, no plain subshells, no `$(...)` containing pipes.
- The classifier is idempotent: identical input → byte-identical stdout.
- No conversus invocations, no knowledge writes (NG-2, NG-5).

## Expected Output

`scripts/intake/paragraph-classify.sh` exists and is executable; `scripts/intake/proposal-emit.sh` wires the classifier on the paragraph branch; `scripts/verify/m024-p03-paragraph-classify.sh` exits 0 with `PASS:`.
