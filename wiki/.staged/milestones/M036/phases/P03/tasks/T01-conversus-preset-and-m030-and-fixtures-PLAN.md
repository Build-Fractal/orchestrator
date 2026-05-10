---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P03"
milestone: "M036"
name: "Conversus preset + M030 task-type=extraction registration + Tier 2 fixture corpus"
depends_on: []
---

## Prerequisites

- P02 closed (`P02-SUMMARY.md` exists at [`.orchestrator/milestones/M036/phases/P02/P02-SUMMARY.md`](../../../../../milestones/M036/phases/P02/P02-SUMMARY.md)).
- `scripts/dispatch/adapters/tool/conversus.sh` exists and exposes the `gate <preset> <artifact> <output>` subcommand (M011/P07 — verified at planning time).
- `templates/conversus-presets/normalize-fidelity.yml` exists (used as the structural template for the new preset).
- `templates/model-routing.yml` exists ([M030](../../../../../milestones/M030/index.md) SSOT — closed 2026-05-01).

Verified at plan-authoring time: all four files present.

## Description

Land the SSOT artifacts the rest of P03 consumes:

1. A new conversus preset `templates/conversus-presets/tier-2-fidelity.yml` declaring two cooperative agents (`extractor-advocate` argues every heading/table/figure-caption from the source is preserved in the structured-Markdown output; `fidelity-advocate` argues no content was paraphrased, summarised, or invented) plus a constitution-grounded arbiter emitting PASS|BLOCK.
2. An additive amendment to `templates/model-routing.yml` — adds a top-level `task_type:` section keyed by `extraction:` mapping to a symbolic tier (`smart` for citation-grade fidelity per CC default). **CON-3 closure preserved**: no hardcoded model IDs outside the existing `resolution:` block.
3. A P03 fixture corpus under `tests/fixtures/m036-p03-tier-2/`: a manifest declaring one tier-2 doc + a markdown source file. Markdown is chosen for CON-3 (deterministic CI; no PDF/DOCX in this leg — the Tier 2 LLM extraction path is exercised against a markdown source via the stub-dispatch shim in T02).

Three shape verifiers under `tools/verify/m036-p03-*`.

## Steps

### Step 1 — Author the conversus preset

Create `templates/conversus-presets/tier-2-fidelity.yml`:

```yaml
---
schema_version: "1.0"
type: conversus-preset
---

preset_name: tier-2-fidelity
description: Two-agent cooperative deliberation gating a Tier 2 LLM-extracted structured-Markdown artifact against its source binary's preserved Tier 1 plain-text floor.

agents:
  - name: extractor-advocate
    system_prompt: |
      You argue that the structured-Markdown output preserves every
      heading hierarchy, table structure, figure caption, footnote, and
      citation marker present in the source. You raise a dispute for any
      heading that was dropped or merged, any table that was flattened
      to prose, any figure caption removed, any citation marker silently
      dropped, or any block-level structural element substituted with a
      different one. Your charter is structural preservation — if the
      source had a section, the structured-Markdown must still have it
      (verbatim where the source's prose is well-formed, or with the
      same heading/structure label where the prose was reflowed).

  - name: fidelity-advocate
    system_prompt: |
      You argue that the structured-Markdown output contains no content
      that was paraphrased, summarised, or invented. You raise a dispute
      for any sentence whose meaning was changed during reflow, any
      requirement-shaped statement that was added but does not appear in
      the source, any technical term that was substituted with a
      different term, or any number/date/identifier that was altered.
      Your charter is content fidelity — Tier 2 is structural extraction,
      NOT summarisation or paraphrase (Spec NG-5-NEW); you defend that
      invariant.

arbiter:
  grounding_file: .orchestrator/memory/constitution.md
  verdict_contract: PASS|BLOCK
  description: |
    The arbiter reads disputes from both advocates, weighs them against
    the orchestrator constitution (Principle II Evidence Before Claims,
    Principle XV Surgical Precision), and emits PASS or BLOCK. Ties
    resolve in favour of preservation: PASS only when both advocates
    raise no unresolved disputes. Either advocate raising one or more
    unresolved disputes yields BLOCK with the dispute list as rationale.

output:
  template: templates/gate-result.md
  required_fields:
    - verdict
    - disputes
    - rationale
    - source_hash
```

### Step 2 — Amend the M030 routing table

Append a new top-level `task_type:` section to `templates/model-routing.yml` (after the `cost_rates:` block, additive only). Open the file, find the last line, append:

```yaml

# ---------- M036/P03: task_type registration (FR-19) ----------
#
# task_type-scoped routing. The default routing path keys on
# (character × runtime); some task types (notably reference-corpus
# extraction in M036/P03) bypass the character classifier and resolve
# directly to a symbolic tier. This section is additive — its absence
# preserves pre-M036 behavior.
#
# CON-3 invariant: hardcoded model IDs MUST appear ONLY in the
# resolution: section. The task_type: rows below are symbolic.

task_type:
  extraction:
    claude-code: smart
    codex-cli: inherit
    cursor: inherit
```

Use the `Edit` tool. Old string: the final line `    output_per_mtok: 75.00`. New string: `    output_per_mtok: 75.00` followed by the YAML block above (newline-separated). Preserve all existing content byte-identically.

### Step 3 — Create the fixture corpus

Create `tests/fixtures/m036-p03-tier-2/sample.md`:

```markdown
# Tier 2 Fixture — PBJ Staffing Sample

This is a fixture markdown file used by M036 P03's Tier 2 acceptance
harness. The structured-extraction stub treats this content as if it
were a regulatory document with multiple headings.

## Section 1 — Definitions

- `staff_count`: the number of nursing staff on duty in a measurement window.
- `census`: the number of residents in a facility at a measurement instant.

## Section 2 — Calculation

The hours-per-resident-day metric divides total nursing hours by the
resident census, summed across the measurement window.
```

Create `tests/fixtures/m036-p03-tier-2/extract-manifest.yaml`:

```yaml
schema_version: "1.0"
type: extract-manifest
milestone: "M036"
size_cap_bytes: 10485760

documents:
  - cite_id: "tier2-fixture-01"
    source_path: "sample.md"
    category: "glossary"
    source: "internal-glossary"
    published: "2026-05-02"
    version: "p03-fixture"
    topic_tags: ["pbj-staffing", "definitions"]
    applies_to_field: ["staff_count", "census"]
    tier: 2
    summary_mode: "auto"
```

(The two `canned-structured*.md` files referenced by `EXTRACT_TIER_2_DISPATCH=stub:*` are authored in T04 alongside the acceptance harness — see Cross-task ordering note in the phase plan.)

### Step 4 — Author shape verifiers

Author `tools/verify/m036-p03-conversus-preset-shape.sh`:

```bash
#!/usr/bin/env bash
# tools/verify/m036-p03-conversus-preset-shape.sh -- M036 P03 T01.
# Asserts the tier-2-fidelity conversus preset exists and declares the
# required agent + arbiter shape per FR-18.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
PRESET="$ROOT/templates/conversus-presets/tier-2-fidelity.yml"
fail=0
if [ -f "$PRESET" ]; then
  echo "PASS: preset exists $PRESET"
else
  echo "FAIL: preset missing $PRESET"
  fail=$((fail + 1))
fi
checkpat() {
  local pat="$1"
  if grep -qF -e "$pat" "$PRESET"; then
    echo "PASS: '$pat' in $(basename "$PRESET")"
  else
    echo "FAIL: '$pat' missing in $(basename "$PRESET")"
    fail=$((fail + 1))
  fi
}
checkpat "preset_name: tier-2-fidelity"
checkpat "extractor-advocate"
checkpat "fidelity-advocate"
checkpat "verdict_contract: PASS|BLOCK"
checkpat "grounding_file: .orchestrator/memory/constitution.md"
echo "SUMMARY: m036-p03-conversus-preset-shape.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

Author `tools/verify/m036-p03-m030-task-type-extraction.sh`:

```bash
#!/usr/bin/env bash
# tools/verify/m036-p03-m030-task-type-extraction.sh -- M036 P03 T01.
# Asserts templates/model-routing.yml carries the additive
# task_type.extraction row pointing at "smart" for claude-code, and
# CON-3 closure is preserved (no NEW hardcoded model IDs added outside
# the existing resolution: block).
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
ROUTING="$ROOT/templates/model-routing.yml"
fail=0
if [ ! -f "$ROUTING" ]; then
  echo "FAIL: routing file missing $ROUTING"
  echo "SUMMARY: m036-p03-m030-task-type-extraction.sh fail=1"
  exit 1
fi
checkpat() {
  local pat="$1"
  if grep -qF -e "$pat" "$ROUTING"; then
    echo "PASS: '$pat' in $(basename "$ROUTING")"
  else
    echo "FAIL: '$pat' missing in $(basename "$ROUTING")"
    fail=$((fail + 1))
  fi
}
checkpat "task_type:"
checkpat "extraction:"
checkpat "claude-code: smart"
checkpat "FR-19"
# CON-3 spot-check: count hardcoded model IDs. Pre-T01 baseline = 3
# (claude-haiku-4-5, claude-sonnet-4-7, claude-opus-4-7) all under
# resolution:. T01 amendment must NOT add a fourth.
hardcoded=$(grep -cE 'claude-(haiku|sonnet|opus)-4-' "$ROUTING")
if [ "$hardcoded" -eq 3 ]; then
  echo "PASS: hardcoded model ID count preserved at 3 (CON-3 closure)"
else
  echo "FAIL: hardcoded model ID count drifted ($hardcoded; expected 3 — CON-3 violation)"
  fail=$((fail + 1))
fi
echo "SUMMARY: m036-p03-m030-task-type-extraction.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

Author `tools/verify/m036-p03-fixture-corpus-shape.sh`:

```bash
#!/usr/bin/env bash
# tools/verify/m036-p03-fixture-corpus-shape.sh -- M036 P03 T01.
# Asserts the P03 Tier 2 fixture corpus is on disk: sample.md exists,
# extract-manifest.yaml exists, manifest declares tier: 2 + summary_mode:
# auto for one document.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
FX="$ROOT/tests/fixtures/m036-p03-tier-2"
fail=0
checkfile() {
  local p="$1"
  if [ -f "$p" ]; then
    echo "PASS: exists $p"
  else
    echo "FAIL: missing $p"
    fail=$((fail + 1))
  fi
}
checkfile "$FX/sample.md"
checkfile "$FX/extract-manifest.yaml"
if [ -f "$FX/extract-manifest.yaml" ]; then
  if grep -qF -e "tier: 2" "$FX/extract-manifest.yaml"; then
    echo "PASS: manifest declares tier: 2"
  else
    echo "FAIL: manifest missing tier: 2"
    fail=$((fail + 1))
  fi
  if grep -qF -e 'summary_mode: "auto"' "$FX/extract-manifest.yaml"; then
    echo "PASS: manifest declares summary_mode: auto"
  else
    echo "FAIL: manifest missing summary_mode: auto"
    fail=$((fail + 1))
  fi
  if grep -qF -e 'cite_id: "tier2-fixture-01"' "$FX/extract-manifest.yaml"; then
    echo "PASS: manifest declares cite_id tier2-fixture-01"
  else
    echo "FAIL: manifest missing cite_id tier2-fixture-01"
    fail=$((fail + 1))
  fi
fi
echo "SUMMARY: m036-p03-fixture-corpus-shape.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

Make the three new verifiers executable: `chmod +x tools/verify/m036-p03-{conversus-preset-shape,m030-task-type-extraction,fixture-corpus-shape}.sh`.

## Must-Haves

(Subset of phase must-haves T01 addresses)

- The conversus preset `tier-2-fidelity.yml` exists at `templates/conversus-presets/tier-2-fidelity.yml`, declares two agents and the PASS|BLOCK arbiter contract.
- The M030 routing table at `templates/model-routing.yml` recognises `task_type.extraction` (additive; CON-3 preserved).

## Verification

```bash
bash tools/verify/m036-p03-conversus-preset-shape.sh
```

```bash
bash tools/verify/m036-p03-m030-task-type-extraction.sh
```

```bash
bash tools/verify/m036-p03-fixture-corpus-shape.sh
```

## Inputs

### From Previous Tasks

(none — T01 is the foundational task in P03)

### From Disk (Pre-existing)

- `templates/conversus-presets/normalize-fidelity.yml` — structural template; the new preset re-uses the agent/arbiter/output YAML shape (top-level `preset_name`, `agents:` list of `{name, system_prompt}`, `arbiter:` block with `grounding_file`/`verdict_contract`/`description`, `output:` with `template` + `required_fields`).
- `templates/model-routing.yml` — M030 SSOT. Contains `routing:` (character → tier), `resolution:` (tier × runtime → model ID), `cost_rates:`. T01 appends a `task_type:` block at the end without modifying existing rows.
- `scripts/dispatch/adapters/tool/conversus.sh` — provides `gate <preset-name> <artifact> <output>` (called by T03's gate helper). Resolves `<preset-name>` to `templates/conversus-presets/<preset-name>.yml`. The preset filename slug `tier-2-fidelity` is the contract.

## Constraints

- CON-2 (Bash 3.2 / POSIX-sh).
- CON-3 (no live LLM in CI — fixture is markdown only; no PDF/DOCX/binary fixtures in P03).
- CON-3 closure invariant for templates/model-routing.yml (no new hardcoded model IDs outside `resolution:`).
- AD-19 single-script-file shape for verifier `Check:` invocations.
- Verifier filename milestone-prefixed slug `m036-p03-*` per the post-[M031](../../../../../milestones/M031/index.md) plan-phase contract.
- Verifiers use `grep -qF -e "$pat"` (not `grep -qF "$pat"`) so leading-dash tokens like `-N` or `--manifest` are not misinterpreted as flags by BSD-grep on macOS — pattern carried from M036/P02 mid-phase correction (see P02 SUMMARY).

## Expected Output

After T01 completes:

- `templates/conversus-presets/tier-2-fidelity.yml` exists (~50 lines).
- `templates/model-routing.yml` has a new `task_type:` block at the end; existing content byte-identical.
- `tests/fixtures/m036-p03-tier-2/{sample.md,extract-manifest.yaml}` exist.
- 3 new executable verifier scripts under `tools/verify/m036-p03-*`.
- All three verifiers exit 0 on this branch.

## Notes

The two `canned-structured*.md` fixtures are authored in T04 (alongside the acceptance harness) — T03 verifiers `m036-p03-tier-2-pass-end-to-end.sh` and `m036-p03-tier-2-block-retention.sh` reference them but go green retroactively under the auto-loop's first-fail-retry. This pattern is documented under "Cross-task ordering" in the P03 plan and was previously exercised at M036/P02/T02.
