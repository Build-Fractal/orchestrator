---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P04"
milestone: "M014"
name: "templates/conversus-presets/spec-pressure-test.yml FR-6 red-blue preset + templates/spec-complexity-contradiction-prompt.md + templates/spec-splitter-prompt.md CC LLM prompt bodies"
depends_on: []
---

## Prerequisites

- `templates/conversus-presets/` exists with two existing presets (`normalize-fidelity.yml`, `m013-uat-defect-merge.yml`) — T03 follows their schema.
- `scripts/dispatch/adapters/tool/conversus.sh` exists; reads presets at `<repo-root>/templates/conversus-presets/<preset-name>.yml`. **T03 ships a preset only — no adapter modification per D007 + CON-4**.
- `.orchestrator/memory/constitution.md` exists (arbiter grounding file).
- `templates/gate-result.md` exists (conversus output template).

## Description

Three deliverables, all authored templates — no executable code:

1. `templates/conversus-presets/spec-pressure-test.yml` — FR-6 preset in **red-blue deliberation mode** (charter-adversarial). Blue-advocate argues the draft is shippable; Red-advocate argues the draft has fatal ambiguity / contradiction / scope overreach. Arbiter grounds in the orchestrator constitution (Principles II, III, XV).
2. `templates/spec-complexity-contradiction-prompt.md` — CC LLM prompt body consumed by `scripts/knowledge/spec-complexity-probe.sh` (T02). Instructs the LLM to read a spec markdown and emit exactly one line `contradictions=<N>` to stdout.
3. `templates/spec-splitter-prompt.md` — CC LLM prompt body consumed by `scripts/specify/specify.sh split <path>` (T05). Instructs the LLM to read a large spec and propose a 2–N-way decomposition manifest.

All three files are parseable by downstream consumers without T03-side logic — T03 is pure content, T02 and T04/T05 invoke the conversus adapter / dispatch interface referencing these files.

## Steps

### Step 1: Create `templates/conversus-presets/spec-pressure-test.yml`

Verbatim body:

```yaml
---
schema_version: "1.0"
type: conversus-preset
---

preset_name: spec-pressure-test
description: Red-blue adversarial deliberation gating a draft spec pre-discuss. Blue argues the draft is shippable; red argues the draft has fatal ambiguity, internal contradiction, scope overreach, or insufficient evidence to pass the Constitution II/III/XV gates. The arbiter grounds verdicts in the orchestrator constitution.

mode: red-blue

agents:
  - name: blue-advocate
    system_prompt: |
      You are the Blue Advocate. Your charter is to argue that the draft
      spec is shippable as-is — that its user stories are coherent, its
      functional requirements are complete, its success criteria are
      mechanically verifiable, its constraints are non-contradictory, and
      its scope boundaries are discoverable from the written prose.

      You cite specific section headings, FR numbers, and acceptance
      scenario numbers in your arguments. You quote prose verbatim when
      arguing that a claim is well-supported. You concede specific points
      to the red advocate where the source clearly supports red's
      critique — unconceded points become disputes for the arbiter.

      You do NOT argue that weak evidence is sufficient. You do NOT argue
      that "planning will resolve this later" when the gap concerns the
      spec's own internal coherence. You DO argue when red is
      speculatively inventing problems that the spec actually addresses.

  - name: red-advocate
    system_prompt: |
      You are the Red Advocate. Your charter is to argue that the draft
      spec has at least one fatal flaw — internal contradiction,
      ambiguous requirement whose interpretation changes whether a
      conforming implementation is feasible, scope boundary that is
      neither drawn nor derivable, success criterion that is not
      mechanically verifiable, or constraint that masks a load-bearing
      design decision deferred past planning.

      You raise specific disputes citing the exact section, quote, or
      interplay of requirements that supports the critique. You do NOT
      manufacture disputes where the source is clearly well-written.
      You DO press on disputes even when the blue advocate concedes
      partial counter-evidence — partial concession means the arbiter
      must decide.

      Your charter is preservation of Constitution Principle II
      (Evidence Before Claims): if the spec's claims cannot stand on the
      evidence the spec itself provides, the arbiter should BLOCK and
      route the draft through `orchestrator:discuss` before proceeding.

arbiter:
  grounding_file: .orchestrator/memory/constitution.md
  verdict_contract: PASS|BLOCK
  description: |
    The arbiter reads disputes from both advocates, weighs them against
    the orchestrator constitution (Principle II Evidence Before Claims,
    Principle III Design Before Code, Principle XV Surgical Precision),
    and emits a PASS or BLOCK verdict. A BLOCK verdict names the
    dispute(s) that tipped the decision and the constitution principle
    each dispute violates. Ties resolve in favor of BLOCK — the draft
    remains in review.

    The arbiter does NOT re-litigate the advocate round; it weighs the
    presented disputes. An advocate who fails to present a dispute
    forfeits the point regardless of independent merit.

output:
  template: templates/gate-result.md
  required_fields:
    - verdict
    - disputes
    - rationale
    - source_hash
```

### Step 2: Create `templates/spec-complexity-contradiction-prompt.md`

Verbatim body:

```markdown
---
schema_version: "1.0"
type: llm-prompt
consumer: scripts/knowledge/spec-complexity-probe.sh
---

# Contradiction-Signal Prompt (FR-5)

You are given a draft feature specification as input text. Your task is
to count internal contradiction signals in the spec — places where the
spec asks for a behavior and also asks for that behavior's logical
opposite, or where two requirements cannot both be satisfied.

**Definition of contradiction signal**:

- A requirement pair where FR-X specifies behavior B and FR-Y specifies
  NOT-B, and neither is gated by a condition that would make them
  non-contradictory.
- A user story asking the system to "support both X and its opposite"
  where X and its opposite are mutually exclusive.
- A constraint that mandates a property that the success criteria
  explicitly violate.
- A scope boundary claiming "out of scope: X" while an FR in the same
  spec requires X.

**Not a contradiction**:

- Conditional behaviors (FR-X applies when A; FR-Y applies when NOT-A).
- Requirements that allow operator override (the default and the
  override are both specified).
- Deferrals to a later phase / milestone (spec scope-boundary
  declarations, not contradictions).
- Separate user stories covering different workflows that happen to
  have different defaults.

## Output Format

Emit **exactly one line** on stdout:

```
contradictions=<N>
```

where `<N>` is a non-negative integer. Do NOT emit any other output,
reasoning, or explanation — the consumer (`spec-complexity-probe.sh`)
parses the first matching line only.

If the spec is empty, malformed, or too short to evaluate (fewer than
100 tokens), emit `contradictions=0`.

## Calibration

On a typical well-written draft, emit `0`. On a draft with one obvious
contradiction (e.g., "the command must prompt interactively" + "the
command must never prompt interactively"), emit `1`. Emit higher counts
only when you are confident each one meets the definition above. When
in doubt, undercount.
```

### Step 3: Create `templates/spec-splitter-prompt.md`

Verbatim body:

```markdown
---
schema_version: "1.0"
type: llm-prompt
consumer: scripts/specify/specify.sh split
---

# Spec Splitter Prompt (FR-7)

You are given a draft feature specification as input text. The user has
signaled (via the `orchestrator:specify` three-way prompt `d` path) that
the draft is too large for a single coherent unit of work and should be
decomposed into 2–N sub-specs.

Your task is to propose a decomposition manifest naming each proposed
sub-spec. Each sub-spec should:

- Own a coherent subset of the source spec's user stories (stories move
  as atomic units; do not split a single user story across sub-specs).
- Inherit the functional requirements that its stories depend on.
- Preserve user-story priorities (P1/P2/P3) from the source.
- Stand alone: each sub-spec should be independently testable
  (Independent Test in the spec-kit vocabulary).

You MAY propose a decomposition of 2, 3, or 4 sub-specs. Do not propose
more than 4 — larger decompositions indicate the source isn't ready to
split yet (it needs a discuss round first). Do not propose 1 — that's
below-threshold and the source should stand.

## Output Format

Emit a YAML manifest with frontmatter and an entries list:

```yaml
---
schema_version: "1.0"
type: decomposition-manifest
source_id: <source-spec-id>
created_at: <iso-date>
---

entries:
  - slug: <kebab-case-short-name>
    slice: "<one-line description of the subset this sub-spec owns>"
    inherited_user_stories: ["US-N", "US-M"]
    rationale: "<one-line reason this subset is coherent enough to stand alone>"
  - slug: <kebab-case-short-name>
    slice: "..."
    inherited_user_stories: ["US-K"]
    rationale: "..."
```

Do NOT emit any prose outside the YAML block. The consumer
(`scripts/specify/specify.sh split`) parses the manifest directly.

## Calibration

- If the source spec has 5 user stories that split cleanly into 2
  clusters (e.g., 3 stories that share a workflow + 2 stories that
  share a different workflow), propose 2 sub-specs.
- If the source has 6+ user stories that split into 3 clusters,
  propose 3 sub-specs.
- If the stories are tangled (every story depends on every other
  story's FRs), you may still be required to propose a decomposition —
  do so, and name the coupling in each `rationale:` field so the
  operator can see the cost.
```

### Step 4: Gate verifier — `scripts/verify/m014-p04-pressure-test-preset.sh`

Single-script file. Confirms:

- `templates/conversus-presets/spec-pressure-test.yml` exists.
- Has `preset_name: spec-pressure-test`.
- Has `mode: red-blue`.
- Has two `agents:` entries with names `blue-advocate` and `red-advocate`.
- Has an `arbiter:` block with `grounding_file: .orchestrator/memory/constitution.md` and `verdict_contract: PASS|BLOCK`.
- Has an `output:` block naming `templates/gate-result.md` and required_fields `verdict disputes rationale source_hash`.
- `templates/spec-complexity-contradiction-prompt.md` exists, contains `contradictions=<N>`, is ≥ 40 lines.
- `templates/spec-splitter-prompt.md` exists, contains `decomposition-manifest`, is ≥ 40 lines.

Verbatim body:

```bash
#!/usr/bin/env bash
# Gate: T03 — FR-6 preset + FR-5/FR-7 prompt bodies.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PRESET="${PROJECT_ROOT}/templates/conversus-presets/spec-pressure-test.yml"
P_CONT="${PROJECT_ROOT}/templates/spec-complexity-contradiction-prompt.md"
P_SPLIT="${PROJECT_ROOT}/templates/spec-splitter-prompt.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

[ -f "$PRESET" ]  || fail "spec-pressure-test.yml missing"
[ -f "$P_CONT" ]  || fail "spec-complexity-contradiction-prompt.md missing"
[ -f "$P_SPLIT" ] || fail "spec-splitter-prompt.md missing"

# Preset shape.
grep -qE '^preset_name: *spec-pressure-test' "$PRESET"                 || fail "preset_name missing"
grep -qE '^mode: *red-blue' "$PRESET"                                  || fail "mode: red-blue missing"
grep -qE '^  - name: *blue-advocate' "$PRESET"                         || fail "blue-advocate missing"
grep -qE '^  - name: *red-advocate' "$PRESET"                          || fail "red-advocate missing"
grep -qE '^  grounding_file: *\.orchestrator/memory/constitution\.md' "$PRESET" || fail "grounding_file wrong"
grep -qE '^  verdict_contract: *PASS\|BLOCK' "$PRESET"                 || fail "verdict_contract wrong"
grep -qE '^  template: *templates/gate-result\.md' "$PRESET"           || fail "output template wrong"
grep -qE '^    - *verdict' "$PRESET"                                   || fail "required_fields missing verdict"
grep -qE '^    - *disputes' "$PRESET"                                  || fail "required_fields missing disputes"
grep -qE '^    - *rationale' "$PRESET"                                 || fail "required_fields missing rationale"
grep -qE '^    - *source_hash' "$PRESET"                               || fail "required_fields missing source_hash"

# Contradiction prompt shape.
CLINES="$(wc -l < "$P_CONT")"
if [ "$CLINES" -lt 40 ]; then fail "contradiction prompt too short: $CLINES lines"; fi
grep -qF 'contradictions=' "$P_CONT" || fail "contradiction prompt missing contradictions= output spec"

# Splitter prompt shape.
SLINES="$(wc -l < "$P_SPLIT")"
if [ "$SLINES" -lt 40 ]; then fail "splitter prompt too short: $SLINES lines"; fi
grep -qF 'decomposition-manifest' "$P_SPLIT" || fail "splitter prompt missing decomposition-manifest type"
grep -qF 'inherited_user_stories' "$P_SPLIT" || fail "splitter prompt missing inherited_user_stories field"

# Sanity check: no adapter modification. The adapter file shasum is NOT checked here
# (changes may happen for unrelated reasons); but the adapter path is confirmed unchanged
# via its presence.
ADAPTER="${PROJECT_ROOT}/scripts/dispatch/adapters/tool/conversus.sh"
[ -x "$ADAPTER" ] || fail "conversus adapter missing — T03 assumes D007 reuse discipline"

echo "PASS: pressure-test preset + prompt bodies shipped"
exit 0
```

Make executable.

## Must-Haves

- `templates/conversus-presets/spec-pressure-test.yml` exists with `preset_name`, `mode: red-blue`, `blue-advocate`, `red-advocate`, arbiter grounding in constitution, output template naming gate-result.md with four required fields
- `templates/spec-complexity-contradiction-prompt.md` exists, ≥40 lines, instructs LLM to emit `contradictions=<N>`
- `templates/spec-splitter-prompt.md` exists, ≥40 lines, instructs LLM to emit a YAML decomposition manifest
- **Zero modifications** to `scripts/dispatch/adapters/tool/conversus.sh` (D007 + CON-4)
- `scripts/verify/m014-p04-pressure-test-preset.sh` exists, executable, exits 0

## Verification

```
bash scripts/verify/m014-p04-pressure-test-preset.sh
```

Expected: `PASS: pressure-test preset + prompt bodies shipped`, exit 0.

## Inputs

### From Previous Tasks

None — T03 is independent (parallelizable with T01/T02).

### From Disk (Pre-existing)

- `templates/conversus-presets/normalize-fidelity.yml` — schema reference (T03 mirrors its shape with mode-switch).
- `.orchestrator/memory/constitution.md` — arbiter grounding file (referenced by preset; not modified).
- `templates/gate-result.md` — conversus output template (referenced by preset; not modified).
- `scripts/dispatch/adapters/tool/conversus.sh` — reads presets (not modified by T03).

## Constraints

- **No adapter modification**. T03 ships preset + two prompt files. If the adapter needs extension to support `mode: red-blue`, that is a **separate M011/P07 follow-up** and out of scope for this task. The adapter is expected to either already support red-blue mode or to treat unrecognized modes as a pass-through single-round cooperative exchange. Document this expectation in the gate-verifier commentary.
- **Preset YAML shape is validated by grep** (structural not semantic). Deeper YAML validation (e.g., via `yq` or python) is out of scope — the orchestrator does not require python3 per MEM001.
- **Prompt templates are LLM-consumer-facing**: prose is written for an LLM reader. No project-specific jargon that would only be parseable by a human reader of the orchestrator codebase.
- **Contradiction-signal calibration is conservative** (undercount on doubt). This is T03's explicit instruction to the LLM — keeps false-positive rate low and preserves the `contradiction_signal_count: 1` threshold from T01.
- **Splitter `N<=4` cap** prevents runaway decomposition; documented in the prompt.
- Bash 3.2 compatible; gate passes `scripts/verify/anti-pattern-lint.sh`.

## Expected Output

Files committed:

1. `templates/conversus-presets/spec-pressure-test.yml` (~60 lines)
2. `templates/spec-complexity-contradiction-prompt.md` (~55 lines)
3. `templates/spec-splitter-prompt.md` (~60 lines)
4. `scripts/verify/m014-p04-pressure-test-preset.sh` (~45 lines, executable)

Gate exits 0.
