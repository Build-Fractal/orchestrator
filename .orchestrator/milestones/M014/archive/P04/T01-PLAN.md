---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P04"
milestone: "M014"
name: "Calibration corpus + complexity-threshold pinning in .orchestrator/config.yml + CALIBRATION-MEMO.md design memo"
depends_on: []
---

## Prerequisites

No upstream task dependencies within P04 (T01 is the seed). Pre-existing disk state:

- `.orchestrator/config.yml` has a `specify.complexity_thresholds:` block with all-zero values from M014/P01/T05:
  - `fr_count: 0`, `user_story_count: 0`, `raw_token_count: 0`, `todo_density: 0`, `contradiction_signal_count: 0`.
- Retrospective specs for calibration exist at `specs/011-spec-management/spec.md`, `specs/016-autonomous-hardening/spec.md`, `specs/021-autonomous-hardening-v2/spec.md`, `specs/022-spec-wiki/spec.md`, `specs/023-github-native-integration/spec.md`, `specs/024-spec-management-extended/spec.md`.
- No `tests/fixtures/m014-p04/` directory yet.
- No `CALIBRATION-MEMO.md` yet.

## Description

Two deliverables:

1. **Calibration corpus + design memo** documenting retrospective labels across six shipped specs, the numeric cutoffs chosen, and the design rationale. This is the **most judgment-heavy task in P04** — threshold selection has no "right answer"; the memo is the evidence trail.

2. **Pinned threshold values** in `.orchestrator/config.yml` under `specify.complexity_thresholds:` (replacing the all-zero stub values) plus a new top-level `specify.contradiction_signal_criterion: cc-llm-or-zero` key documenting the CC-runtime-gated source of contradiction signals.

The retrospective labels (demo sentence): M016 and M021 are **below-threshold** (small, coherent hardening specs — no contradictions, ≤3 user stories, no FR-list); M013, M011, and M024 are **above-threshold** (large specs with ≥15 FRs or ≥5 user stories — M013/M024 both passed M014/P04's intended `fr_count>=15 OR user_story_count>=5` gate); M022 is **borderline** (10 FRs, 5 user stories — lands above-threshold on `user_story_count>=5` but not `fr_count>=15`, documenting the OR-semantics).

## Steps

### Step 1: Label the retrospective corpus

Measure six specs against the four heuristic dimensions (FR count, user-story count, raw-token count via `wc -w`, `<TODO>` count) and decide whether each is above-threshold or below-threshold given the intended M014/P04 gate. Use `grep -cE` patterns:

- **FR count**: `grep -cE '^- \*\*FR-[0-9]+|^### FR-[0-9]+|^\*\*FR-[0-9]+' <spec-path>`
- **User-story count**: `grep -cE '^### User (Story|Scenario)' <spec-path>`
- **Raw token count**: `wc -w < <spec-path>`
- **TODO count**: `grep -cE '<TODO' <spec-path>`

Approximate measured values (planning reference — T02 reads these at gate time for threshold sanity checks; numeric drift over time is expected and acceptable):

| Spec | FR count | User stories | Tokens | TODO | Label | Primary reason |
|---|---|---|---|---|---|---|
| M011 (011-spec-management) | 16 | 5 | ~3500 | 0 | above | `fr_count>=15 OR user_story_count>=5` |
| M013 (023-github-native-integration) | 18 | 6 | ~9000 | 0 | above | `fr_count>=15 OR user_story_count>=5` |
| M016 (016-autonomous-hardening) | 0 | 3 | ~3000 | 0 | below | neither gate; hardening-spec exception does not apply |
| M021 (021-autonomous-hardening-v2) | 0 | 5 | ~5000 | 0 | borderline→below | `user_story_count=5` hits gate but hardening-spec exception applies (`fr_count=0` strong signal) |
| M022 (022-spec-wiki) | 10 | 5 | ~4500 | 0 | above | `user_story_count>=5` |
| M024 (024-spec-management-extended) | 20 | 5 | ~14000 | 0 | above | `fr_count>=15 OR user_story_count>=5` |

### Step 2: Write `tests/fixtures/m014-p04/corpus-labels.tsv`

Create `tests/fixtures/m014-p04/` directory. Write TSV with header + one row per corpus spec. Exact content:

```
spec_id	spec_path	fr_count	user_story_count	raw_token_count	todo_count	expected_label	primary_reason
M011	specs/011-spec-management/spec.md	16	5	3500	0	above-threshold	fr_count>=15
M013	specs/023-github-native-integration/spec.md	18	6	9000	0	above-threshold	user_story_count>=5
M016	specs/016-autonomous-hardening/spec.md	0	3	3000	0	below-threshold	hardening-spec-exception
M021	specs/021-autonomous-hardening-v2/spec.md	0	5	5000	0	below-threshold	hardening-spec-exception
M022	specs/022-spec-wiki/spec.md	10	5	4500	0	above-threshold	user_story_count>=5
M024	specs/024-spec-management-extended/spec.md	20	5	14000	0	above-threshold	fr_count>=15
```

Use literal tabs between columns. Note: `fr_count`, `user_story_count`, `raw_token_count`, `todo_count` are the *approximate measured* values at planning time; T02's gate verifier re-measures and allows small drift (±20% on tokens, exact match on heuristic counts is NOT required because spec edits over time shift counts).

### Step 3: Pin thresholds in `.orchestrator/config.yml`

Replace the all-zero `complexity_thresholds` block with the pinned values. Edit-in-place, preserving every other key byte-identically (additive-only discipline per P01/T05 pattern).

Target final state of the `specify:` section:

```yaml
specify:
  complexity_thresholds:
    fr_count: 15              # T01 calibration — gate threshold (above if >= this)
    user_story_count: 5       # T01 calibration — gate threshold (above if >= this)
    raw_token_count: 8000     # T01 calibration — gate threshold (above if >= this)
    todo_density: 0.5         # T01 calibration — todo / (todo + authored-section) ratio above
    contradiction_signal_count: 1  # Any LLM-detected signal trips the probe
  contradiction_signal_criterion: cc-llm-or-zero  # Non-CC runtimes emit zero
  hardening_spec_exception: true  # fr_count==0 treated as strong below-threshold signal
  scaffolder_description_min_words: 80
  scaffolder_llm_on_codex: false
```

**Semantics**: above-threshold fires if **any** of: `fr_count >= 15`, `user_story_count >= 5`, `raw_token_count >= 8000`, `todo_density >= 0.5`, `contradiction_signal_count >= 1`, **EXCEPT** when `hardening_spec_exception: true` AND `fr_count == 0` — in that case the probe returns below-threshold regardless of user-story count (M016 + M021 precedent). `todo_density` is computed as TODO count / (TODO count + number of `^## ` sections); 0.5 means half the section headings still hold TODO placeholders — a useful skeleton-vs-authored signal.

### Step 4: Write `.orchestrator/milestones/M014/phases/P04/CALIBRATION-MEMO.md`

Verbatim skeleton (task agent fills prose within these sections; total ~120-180 lines expected):

```markdown
---
schema_version: "1.0"
type: design-memo
milestone: "M014"
phase: "P04"
task: "T01"
subject: "FR-5 spec-complexity-probe threshold calibration"
created_at: "2026-04-23"
---

# Calibration Memo: FR-5 Spec-Complexity-Probe Thresholds

## Intent

Per the M014 roadmap P04 boundary-map directive, T01 labels a retrospective corpus of shipped specs as above-threshold or below-threshold, then pins the numeric cutoffs in `.orchestrator/config.yml` that T02's full probe body will consume.

## Retrospective Corpus

Six specs shipped under the post-M011 spec-kit regime:

<!-- Reproduce the TSV table in markdown -->

| Spec | FR | US | Tok | TODO | Label | Reason |
|---|---|---|---|---|---|---|
| M011 (011-spec-management) | 16 | 5 | ~3500 | 0 | above | `fr_count>=15` |
| M013 (023-github-native-integration) | 18 | 6 | ~9000 | 0 | above | `user_story_count>=5` |
| M016 (016-autonomous-hardening) | 0 | 3 | ~3000 | 0 | below | hardening-spec exception |
| M021 (021-autonomous-hardening-v2) | 0 | 5 | ~5000 | 0 | below | hardening-spec exception |
| M022 (022-spec-wiki) | 10 | 5 | ~4500 | 0 | above | `user_story_count>=5` |
| M024 (024-spec-management-extended) | 20 | 5 | ~14000 | 0 | above | `fr_count>=15` |

## Cutoffs

- `fr_count: 15` — above at `>=15`. Rationale: M011/M013/M024 have ≥16 FRs and are all acknowledged as deliberation-worthy; M022 has 10 FRs but passed discuss cleanly (below on this axis). 15 leaves headroom under 16 without catching 10.
- `user_story_count: 5` — above at `>=5`. Rationale: 5+ user stories is where we observe story-overlap disputes (M013 US-3/US-4 overlap flagged in D014 deliberation; M022 US-1/US-2 overlap observed at discuss). M016 at 3 stories had zero overlap churn.
- `raw_token_count: 8000` — above at `>=8000`. Rationale: orders of magnitude; M013 at ~9000 and M024 at ~14000 are the two token-scale outliers. M022 at ~4500 stays below; M016 at ~3000 is well below. Cutoff placed between M013 and M022.
- `todo_density: 0.5` — above at `>=0.5` (half of sections still hold TODO placeholders). Rationale: this is a skeleton-vs-authored signal. A freshly-scaffolded spec has density close to 1.0; an authored spec has density close to 0.0. 0.5 flags specs where the author ran `orchestrator:specify` and immediately ran `discuss` without filling sections.
- `contradiction_signal_count: 1` — above at `>=1`. Any LLM-detected contradiction signal trips the probe. Rationale: contradictions are binary — one contradiction is enough to warrant pressure-testing. CC-only per CON-2; non-CC runtimes emit zero signals unconditionally.

## Hardening-Spec Exception

M016 and M021 are hardening milestones with zero FR-list (behavioral fix milestones, not feature milestones). User-story count alone flags M021 at 5 stories, but M021 was never contentious — the stories are small and well-scoped. We add `hardening_spec_exception: true` with the rule: **if `fr_count == 0`, override above-threshold to below-threshold regardless of user-story count**. This keeps hardening milestones fast-path even as they grow story counts.

The alternative — relax `user_story_count` to `>=6` — was rejected because M011 at 5 user stories *did* need pressure-testing (the US-3/US-5 interaction was nuanced). The hardening-spec exception is more precise.

## What We're NOT Claiming

- Threshold values are **planning-pinned defaults**, not empirically-optimal values. CON-9 (Dogfood is the truth signal) covers re-tuning without a milestone amendment.
- The corpus is six specs — too small for statistical confidence. This is a judgment call, documented.
- The LLM contradiction-signal pass is the **only** CC-specific criterion; the other four heuristics are runtime-agnostic. Codex/Cursor users can still get a useful above-threshold verdict from FR/story/token/TODO dimensions alone.

## Re-Tuning Triggers

- If T02 ships and a downstream milestone-author reports "probe fired above-threshold on a spec that was clearly trivial," investigate whether `fr_count` or `user_story_count` should move up.
- If M019 Tier 2+3 observability ships and we have 10+ more scaffolded specs to analyze, re-run T01-style labeling and consider tightening cutoffs.
- Contradiction-signal LLM false-positive rate should be measured; if it exceeds 20% (LLM flagged contradictions that weren't real), raise the `contradiction_signal_count` threshold to `2`.

## Cross-References

- `.orchestrator/config.yml` — pinned values
- `tests/fixtures/m014-p04/corpus-labels.tsv` — machine-readable corpus
- `scripts/knowledge/spec-complexity-probe.sh` (T02 deliverable) — consumer
- `RUNTIME-ASSUMPTIONS.md` FR-5 — CC-only contradiction-signal pass
- Roadmap M014 P04 boundary map — calibration-corpus directive
```

### Step 5: Gate verifier — `scripts/verify/m014-p04-complexity-thresholds-pinned.sh`

Single-script file that confirms:

- `.orchestrator/config.yml` has non-zero `fr_count`, `user_story_count`, `raw_token_count`, `contradiction_signal_count` under `specify.complexity_thresholds:`.
- `.orchestrator/config.yml` has `contradiction_signal_criterion: cc-llm-or-zero`.
- `.orchestrator/config.yml` has `hardening_spec_exception: true`.
- `tests/fixtures/m014-p04/corpus-labels.tsv` exists, has header + 6 data rows.
- `CALIBRATION-MEMO.md` exists, has the `## Retrospective Corpus`, `## Cutoffs`, `## Hardening-Spec Exception` headings.

Verbatim body:

```bash
#!/usr/bin/env bash
# Gate: T01 — complexity-threshold calibration & pinning.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG="${PROJECT_ROOT}/.orchestrator/config.yml"
MEMO="${PROJECT_ROOT}/.orchestrator/milestones/M014/phases/P04/CALIBRATION-MEMO.md"
TSV="${PROJECT_ROOT}/tests/fixtures/m014-p04/corpus-labels.tsv"

fail() { echo "FAIL: $*" >&2; exit 1; }

[ -f "$CONFIG" ] || fail "config.yml missing"
[ -f "$MEMO" ]   || fail "CALIBRATION-MEMO.md missing"
[ -f "$TSV" ]    || fail "corpus-labels.tsv missing"

# Non-zero pinned values under specify.complexity_thresholds:
# Extract the block and check each numeric key individually.
grep -qE '^ *fr_count: *15' "$CONFIG"                       || fail "fr_count not pinned to 15"
grep -qE '^ *user_story_count: *5' "$CONFIG"                || fail "user_story_count not pinned to 5"
grep -qE '^ *raw_token_count: *8000' "$CONFIG"              || fail "raw_token_count not pinned to 8000"
grep -qE '^ *todo_density: *0\.5' "$CONFIG"                 || fail "todo_density not pinned to 0.5"
grep -qE '^ *contradiction_signal_count: *1' "$CONFIG"      || fail "contradiction_signal_count not pinned to 1"
grep -qE '^ *contradiction_signal_criterion: *cc-llm-or-zero' "$CONFIG" || fail "contradiction_signal_criterion key missing"
grep -qE '^ *hardening_spec_exception: *true' "$CONFIG"     || fail "hardening_spec_exception key missing"

# TSV: header + 6 data rows.
LINES="$(wc -l < "$TSV")"
if [ "$LINES" -lt 7 ]; then fail "corpus-labels.tsv has $LINES lines, expected >=7"; fi
grep -qE '^spec_id' "$TSV" || fail "TSV missing header"
grep -qE '^M016' "$TSV"    || fail "TSV missing M016 row"
grep -qE '^M024' "$TSV"    || fail "TSV missing M024 row"

# Memo has required sections.
grep -qE '^## Retrospective Corpus' "$MEMO"     || fail "memo missing Retrospective Corpus section"
grep -qE '^## Cutoffs' "$MEMO"                  || fail "memo missing Cutoffs section"
grep -qE '^## Hardening-Spec Exception' "$MEMO" || fail "memo missing Hardening-Spec Exception section"

echo "PASS: complexity-thresholds pinned + memo + corpus shipped"
exit 0
```

Make executable.

## Must-Haves

- `.orchestrator/config.yml` `specify.complexity_thresholds:` block has all five threshold keys pinned to the non-zero calibration values (`fr_count=15`, `user_story_count=5`, `raw_token_count=8000`, `todo_density=0.5`, `contradiction_signal_count=1`)
- `.orchestrator/config.yml` has `specify.contradiction_signal_criterion: cc-llm-or-zero` and `specify.hardening_spec_exception: true` keys
- `tests/fixtures/m014-p04/corpus-labels.tsv` exists with header + 6 data rows covering M011/M013/M016/M021/M022/M024
- `.orchestrator/milestones/M014/phases/P04/CALIBRATION-MEMO.md` exists with Retrospective Corpus, Cutoffs, Hardening-Spec Exception sections
- `scripts/verify/m014-p04-complexity-thresholds-pinned.sh` exists, executable, exits 0

## Verification

```
bash scripts/verify/m014-p04-complexity-thresholds-pinned.sh
```

Expected: `PASS: complexity-thresholds pinned + memo + corpus shipped`, exit 0.

## Inputs

### From Previous Tasks

None — T01 is the seed of P04.

### From Disk (Pre-existing)

- `.orchestrator/config.yml` — existing `specify:` section (all-zero threshold values from P01/T05) to be edited in place
- `specs/011-spec-management/spec.md`, `specs/023-github-native-integration/spec.md`, `specs/016-autonomous-hardening/spec.md`, `specs/021-autonomous-hardening-v2/spec.md`, `specs/022-spec-wiki/spec.md`, `specs/024-spec-management-extended/spec.md` — retrospective corpus (read-only reference)
- `scripts/verify/anti-pattern-lint.sh` — lint compliance verifier

## Constraints

- The edit to `.orchestrator/config.yml` is **additive-only on keys** (new keys fine) but **value-replace on existing keys** (the five zero values become the pinned values). Every other byte of the file must be byte-identical pre- and post-edit (P01/T05 precedent). Use temp-file-then-rename atomicity.
- The corpus TSV rows use *literal tab characters* (not spaces) — verifiable by `grep -cP '\t'` returning 7 (header + 6 data rows, each with 7 tabs = 7 columns).
- The memo is a design document, not a spec. It follows the D016 format loosely (`## `-prefixed sections, no YAML schema enforcement) and carries a minimal YAML frontmatter naming milestone/phase/task.
- The threshold values are planning-pinned defaults documented in the memo — they are **not** claimed as empirically optimal. Language in the memo must say "planning-pinned" or "planning-set default," never "optimal" or "validated."
- Bash 3.2 compatible; passes `scripts/verify/anti-pattern-lint.sh`.

## Expected Output

Files committed:

1. `.orchestrator/config.yml` — modified (5 threshold values pinned; 2 new keys added; otherwise byte-identical)
2. `tests/fixtures/m014-p04/corpus-labels.tsv` — created (~10 lines)
3. `.orchestrator/milestones/M014/phases/P04/CALIBRATION-MEMO.md` — created (~180 lines)
4. `scripts/verify/m014-p04-complexity-thresholds-pinned.sh` — created (~40 lines, executable)

Gate exits 0.
