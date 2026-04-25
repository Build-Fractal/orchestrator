---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P05"
milestone: "M020"
name: "Feature-vector extension + P05 jaccard-validation re-run"
depends_on: []
---

## Prerequisites

- P01: `scripts/knowledge/lib/jaccard.sh` exposes `pairwise_jaccard <file-a> <file-b>` and `_jaccard_extract_tokens <file>`. The current feature vector (CON-5 baseline) is `title + topic + tags[] + first-paragraph words capped at 50 tokens`.
- P01: `scripts/knowledge/lib/jaccard.sh validate <knowledge-root>` writes a validation report. P01 wrote the report at `.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md` and recommended extending the feature vector for P05 (top observed similarity 0.2000 against the live tree at the baseline vector — too narrow for the 0.7 default threshold).
- P01 jaccard-validation-report.md (Feature-Vector Sanity Check section) explicitly recommends adding (a) `relates_to[]` edges, (b) `source_unit` (provenance co-occurrence), and (c) full body word-set capped at 200 tokens (rather than just first paragraph at 50 tokens).
- M020-CONTEXT.md DC-3 / Principle XIV: extension MUST be evidence-driven. P01's recommendation is the evidence.
- The schema-authority gate (FR-9, P03 schema lint) covers `relates_to[]` and `source_unit` — both fields are pre-existing on entries written before M020 (e.g. MEM029, MEM030, MEM001). P05/T02 only TOKENIZES them in the feature vector — it does not introduce them, so no D-row is required (CON-4 byte-equivalent on disk).

## Description

Modify `scripts/knowledge/lib/jaccard.sh` IN PLACE to extend the CON-5 feature vector with three additional sources, then re-run validate against the live tree and persist the regenerated report at `.orchestrator/milestones/M020/phases/P05/jaccard-validation-report.md`.

The extended feature vector (CON-5 v2) is:

```
title          (frontmatter or H1 fallback, as before)
topic          (frontmatter)
tags[]         (frontmatter, raw line)
relates_to[]   (frontmatter, raw line — NEW IN P05)
source_unit    (frontmatter, raw line — NEW IN P05)
body words     (full body after the second `---` and after the H1 line,
                cap moved from 50 first-paragraph tokens to 200 full-body
                tokens — NEW IN P05)
```

`pairwise_jaccard`'s callable contract is unchanged (same arity, same stdout shape `similarity=N.NNNN`). Only the internal `_jaccard_extract_tokens` function changes — it reads two additional frontmatter fields and broadens the body-window from first-paragraph-50 to full-body-200.

After modification, T02 also regenerates the P05 validation report by invoking `bash scripts/knowledge/lib/jaccard.sh validate knowledge/` (which writes to the P01 path) and then COPIES (or RE-RUNS targeting) the report at `.orchestrator/milestones/M020/phases/P05/jaccard-validation-report.md`. The simplest design is to run validate against the live tree with the extended vector and capture stdout-and-side-effect artifact at the P05 path; T02 documents the explicit copy step rather than modifying validate's hardcoded output path (which is a P01-owned contract).

## Steps

### Step 1: Modify `scripts/knowledge/lib/jaccard.sh` — extend `_jaccard_extract_tokens`

Path: `/Users/brettkellgren/Sites/spec-kit-orchestrator/scripts/knowledge/lib/jaccard.sh`

The current implementation reads `title`, `topic`, `tags`, then derives a first-paragraph body capped at 50 tokens. Replace the `_jaccard_extract_tokens` function body with the extended version below. Leave the file's documentation header untouched aside from updating CON-5 reference comments to read "CON-5 v2 (P05 extension: + relates_to[] + source_unit + body cap 200 full-body tokens)".

Replace this block (current `_jaccard_extract_tokens`):

```bash
_jaccard_extract_tokens() {
  local file="$1"
  # Title: prefer frontmatter title:, fall back to H1 `# MEMNNN: <title>`.
  local title
  title="$(fm_field "$file" "title" 2>/dev/null || true)"
  if [ -z "$title" ]; then
    title="$(grep -m1 '^# ' "$file" | sed 's/^# [A-Za-z0-9-]*:[[:space:]]*//' || true)"
  fi
  # Topic
  local topic
  topic="$(fm_field "$file" "topic" 2>/dev/null || true)"
  # Tags (raw line; tokenizer below splits on non-alphanumerics).
  local tags
  tags="$(fm_field "$file" "tags" 2>/dev/null || true)"

  # First-paragraph: lines after the second `---`, skipping the H1, until
  # the first blank line. Cap at 50 tokens at the tokenizer stage.
  local body_start
  body_start="$(awk '/^---$/{n++; if (n==2) {print NR+1; exit}}' "$file")"
  # After the H1 we may hit blank lines before the first paragraph; only
  # treat a blank line as paragraph terminator after at least one content
  # line has been emitted. `got` flips on H1; `printed` flips on the first
  # non-blank content line after the H1.
  local first_para
  first_para="$(awk -v s="${body_start:-1}" 'NR>=s {
    if (/^# /) { got=1; next }
    if (!got) next
    if (/^$/) { if (printed) exit; else next }
    printed=1; print
  }' "$file")"

  # Concatenate sources, normalize, emit one token per line, cap 50.
  printf "%s %s %s %s\n" "$title" "$topic" "$tags" "$first_para" \
    | tr 'A-Z' 'a-z' \
    | tr -c 'a-z0-9' '\n' \
    | grep -v '^$' \
    | head -50
}
```

with this extended version:

```bash
# CON-5 v2 (P05 extension): feature vector = title + topic + tags[] +
# relates_to[] + source_unit + body words capped at 200 full-body tokens.
# Reason: P01 jaccard-validation-report.md recommended widening the vector
# after observing top similarity 0.2000 against the live tree at the v1
# vector (title + topic + tags + first-paragraph-50). Vector v2 admits the
# natural inter-entry signal (relates_to graph edges + provenance co-
# occurrence + broader body co-occurrence) without admitting noise.
_jaccard_extract_tokens() {
  local file="$1"
  # Title: prefer frontmatter title:, fall back to H1 `# MEMNNN: <title>`.
  local title
  title="$(fm_field "$file" "title" 2>/dev/null || true)"
  if [ -z "$title" ]; then
    title="$(grep -m1 '^# ' "$file" | sed 's/^# [A-Za-z0-9-]*:[[:space:]]*//' || true)"
  fi
  # Topic
  local topic
  topic="$(fm_field "$file" "topic" 2>/dev/null || true)"
  # Tags (raw line; tokenizer below splits on non-alphanumerics).
  local tags
  tags="$(fm_field "$file" "tags" 2>/dev/null || true)"
  # Relates_to (raw line; same tokenization treatment as tags) — P05 NEW.
  local relates_to
  relates_to="$(fm_field "$file" "relates_to" 2>/dev/null || true)"
  # Source_unit (raw scalar; e.g. M026/P02) — P05 NEW.
  local source_unit
  source_unit="$(fm_field "$file" "source_unit" 2>/dev/null || true)"

  # Body words: lines after the second `---`, skipping the H1 line itself,
  # but NOT terminating at the first blank line — full body up to 200 tokens
  # at the tokenizer stage. P05 widening from first-paragraph-50.
  local body_start
  body_start="$(awk '/^---$/{n++; if (n==2) {print NR+1; exit}}' "$file")"
  local body
  body="$(awk -v s="${body_start:-1}" 'NR>=s {
    if (/^# /) { got=1; next }
    if (!got) next
    print
  }' "$file")"

  # Concatenate sources, normalize, emit one token per line, cap 200.
  printf "%s %s %s %s %s %s\n" "$title" "$topic" "$tags" "$relates_to" "$source_unit" "$body" \
    | tr 'A-Z' 'a-z' \
    | tr -c 'a-z0-9' '\n' \
    | grep -v '^$' \
    | head -200
}
```

Three changes to note:

1. Two new local frontmatter reads: `relates_to` and `source_unit`.
2. Body extraction no longer terminates at blank lines (full body, not first paragraph).
3. Token cap moved from `head -50` to `head -200`.

### Step 2: Update the file header comment

Update lines near the top of `lib/jaccard.sh` that currently read:

```
# CON-5 feature vector:
#   frontmatter `title` + frontmatter `topic` + frontmatter `tags[]` keys
#   + first-paragraph content-words capped at 50 tokens
```

to read:

```
# CON-5 v2 feature vector (P05 extension):
#   frontmatter `title` + frontmatter `topic` + frontmatter `tags[]` keys
#   + frontmatter `relates_to[]` + frontmatter `source_unit`
#   + full-body content-words capped at 200 tokens
#
# Original CON-5 v1 vector (P01) was first-paragraph-50; P01 jaccard-
# validation-report.md recommended widening to v2 after observing top sim
# 0.2000 against the live tree at v1.
```

### Step 3: Run validate against the live tree, write the P05 report

Invoke the validate subcommand:

```
bash scripts/knowledge/lib/jaccard.sh validate knowledge/
```

This writes (per the P01 contract) to `.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md`. The report's content reflects the extended vector now that v2 is live. T02 then COPIES the regenerated report to the P05 canonical path:

```
cp .orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md \
   .orchestrator/milestones/M020/phases/P05/jaccard-validation-report.md
```

After the copy, edit the P05 copy ONLY to:

1. Update the H1 from `# Jaccard Validation Report -- M020/P01` to `# Jaccard Validation Report -- M020/P05 (CON-5 v2)`.
2. Append a paragraph at the end documenting the vector change, the new top observed similarity, and whether the threshold recommendation moved.

The P05 report content MUST contain the literal token `relates_to` (which the verifier asserts) — the easiest way is to include the v2 vector description at the top of the appended paragraph.

The P01 report at the P01 path may or may not be left mutated; T02 elects to LEAVE the P01 report untouched (revert via `git checkout .orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md` after copying) so the P01 historical artifact is preserved byte-equivalently. This avoids a CON-4 violation on a sibling phase's deliverable.

Concrete sequence:

```
# 1. capture the current P01 report so we can restore it
cp .orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md /tmp/p01-report.md.bak

# 2. run validate (rewrites the P01 path with v2-derived data)
bash scripts/knowledge/lib/jaccard.sh validate knowledge/

# 3. copy the v2-derived report to the P05 path
mkdir -p .orchestrator/milestones/M020/phases/P05
cp .orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md \
   .orchestrator/milestones/M020/phases/P05/jaccard-validation-report.md

# 4. restore the P01 report (CON-4 — P01 deliverable preserved)
mv /tmp/p01-report.md.bak .orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md

# 5. edit P05 report header + append v2-context paragraph (manual edit by agent)
```

The agent uses Edit to make changes (5) — change the H1 and append a final paragraph that includes `relates_to`, `source_unit`, the new top observed similarity, and the new threshold recommendation derived from the extended-vector run.

### Step 4: Create `scripts/verify/m020-p05-feature-vector-extension.sh`

Path: `/Users/brettkellgren/Sites/spec-kit-orchestrator/scripts/verify/m020-p05-feature-vector-extension.sh`

```bash
#!/usr/bin/env bash
# m020-p05-feature-vector-extension.sh — assert lib/jaccard.sh has been
# extended with relates_to + source_unit + 200-token body cap, and the
# regenerated validation report exists at the P05 path with the new
# vector signature documented.
# Bash 3.2 safe. AD-19 single-script-file shape.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$ROOT/scripts/knowledge/lib/jaccard.sh"
REPORT="$ROOT/.orchestrator/milestones/M020/phases/P05/jaccard-validation-report.md"

if [ ! -f "$LIB" ]; then
  echo "FAIL: $LIB does not exist"
  exit 1
fi
if [ ! -f "$REPORT" ]; then
  echo "FAIL: $REPORT does not exist (P05 validation report missing)"
  exit 1
fi

# Feature vector extension: lib/jaccard.sh must mention relates_to and source_unit.
if ! grep -q 'relates_to' "$LIB"; then
  echo "FAIL: lib/jaccard.sh does not reference relates_to (vector extension missing)"
  exit 1
fi
if ! grep -q 'source_unit' "$LIB"; then
  echo "FAIL: lib/jaccard.sh does not reference source_unit (vector extension missing)"
  exit 1
fi

# Token cap moved to 200 (was 50). Look for `head -200` literal.
if ! grep -q 'head -200' "$LIB"; then
  echo "FAIL: lib/jaccard.sh does not contain 'head -200' (token cap not raised to 200)"
  exit 1
fi

# Body extraction must not terminate at first blank line — i.e. the printed
# block under NR>=s must not contain `if (/^\$/) { ...; exit; ... }`. We
# settle for asserting the new body-extraction shape by checking the absence
# of the `printed=1` v1 sentinel (which is unique to first-paragraph mode).
if grep -q 'printed=1' "$LIB"; then
  echo "FAIL: lib/jaccard.sh still uses first-paragraph extraction (v1) — printed=1 sentinel found"
  exit 1
fi

# P05 report content: must mention relates_to and source_unit and CON-5 v2.
if ! grep -q 'relates_to' "$REPORT"; then
  echo "FAIL: P05 jaccard-validation-report does not document relates_to in the extended vector"
  exit 1
fi
if ! grep -q 'source_unit' "$REPORT"; then
  echo "FAIL: P05 jaccard-validation-report does not document source_unit in the extended vector"
  exit 1
fi
if ! grep -q 'M020/P05' "$REPORT"; then
  echo "FAIL: P05 jaccard-validation-report does not name M020/P05 in its header"
  exit 1
fi

echo "PASS: feature-vector extension (relates_to + source_unit + body cap 200) + P05 report present"
exit 0
```

`chmod +x scripts/verify/m020-p05-feature-vector-extension.sh`.

## Must-Haves

- `scripts/knowledge/lib/jaccard.sh` extended in place with `relates_to[]` and `source_unit` frontmatter reads added to `_jaccard_extract_tokens`.
- Body extraction widened from first-paragraph-50 to full-body-200 (literal `head -200` in the file; no `printed=1` sentinel left over).
- File-header comment updated to describe the v2 vector and reference the P01 report's recommendation.
- `pairwise_jaccard` callable contract unchanged: same arity, same stdout shape (`similarity=N.NNNN`).
- `.orchestrator/milestones/M020/phases/P05/jaccard-validation-report.md` exists and was regenerated against the live tree using the v2 vector. Contains the literal tokens `relates_to`, `source_unit`, and `M020/P05` (per the verifier).
- The P01 report at `.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md` is preserved byte-equivalent (CON-4 — sibling phase deliverable not mutated by P05 work).
- Bash 3.2 + AD-19 + MEM001 conventions throughout.

## Verification

```
bash scripts/verify/m020-p05-feature-vector-extension.sh
```

Must print a `PASS:` line and exit 0.

Note: T02 deliberately does not include a determinism / pairwise-contract test for the v2 vector — those are covered by the P01 contract verifier (`scripts/verify/m020-p01-jaccard-pairwise-contract.sh`), which exercises `pairwise_jaccard`'s arity + output shape independent of the vector internals. The v2 extension is required to KEEP that P01 verifier green; if it does not, T02 has broken `pairwise_jaccard`'s contract and must be fixed.

## Inputs

### From Previous Tasks

None — T02 has no upstream tasks within this phase.

### From Disk (Pre-existing)

- `scripts/knowledge/lib/jaccard.sh` (P01)
  - Key API: `pairwise_jaccard <file-a> <file-b>` (kept intact); internal `_jaccard_extract_tokens <file>` (extended); `validate <root>` subcommand (unchanged — still writes to the P01 path).
- `.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md` (P01) — the precedent format. T02 captures it pre-validate, restores it post-copy.
- `knowledge/**/MEM*.md` — read-only input to the validate subcommand. Live tree state at task time is fine; the report regenerates from whatever is on disk.
- `scripts/verify/m020-p01-jaccard-pairwise-contract.sh` (P01) — existing verifier the v2 vector must keep green. T02 implicitly passes by preserving `pairwise_jaccard`'s callable contract.

## Constraints

- **AD-19 / MEM001**: every `Check:` and verification command in this plan is a single-script-file invocation. The validate-subcommand internals use awk + temp files but those live inside lib/jaccard.sh, not on Check lines.
- **Bash 3.2**: same convention as P01's lib/jaccard.sh — no associative arrays, no process substitution.
- **CON-1 / FR-8 (read-only-during-dispatch)**: `_jaccard_extract_tokens` is purely a token reader. The validate subcommand's report write hits `.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md` but T02 captures-and-restores that path so net diff is zero on the P01 deliverable; the only NEW write is the P05 path.
- **CON-4 (Surgical Precision)**: the P01 report is preserved byte-equivalent. T02 does not mutate any field of any `MEM*.md` entry under `knowledge/**`. The only feature-vector code change is in `_jaccard_extract_tokens`; all other functions in lib/jaccard.sh are unchanged.
- **CON-5 evolution gate**: M020-CONTEXT.md DC-3 (no speculative complexity) is satisfied because the P01 jaccard-validation-report.md provides the EVIDENCE for the vector extension. The recommendation is data-driven, not preemptive.
- **FR-9 (schema authority)**: `relates_to[]` and `source_unit` are pre-existing fields on entries (e.g. MEM001 has `relates_to: [MEM002, MEM004]`; MEM029 has `source_unit: "M026/P02"`). T02 only reads these fields from frontmatter; no new fields introduced; no D-row required.
- **Principle XIV (No Speculative Complexity)**: T02 implements ONLY the three-source vector extension recommended by the P01 report. No semantic embeddings, no TF-IDF weighting, no per-source weights. Future escalation requires further evidence.
- **Principle XV (Surgical Precision)**: edit-in-place at `_jaccard_extract_tokens` is the minimum surgical change. The validate subcommand, the pairwise primitive, and the file structure are unchanged.

## Expected Output

After this task:

1. `scripts/knowledge/lib/jaccard.sh` is modified in place: `_jaccard_extract_tokens` reads `relates_to` and `source_unit`, body extraction is full-body-200, header comment documents v2.
2. `.orchestrator/milestones/M020/phases/P05/jaccard-validation-report.md` exists and contains `relates_to`, `source_unit`, `M020/P05`, and the regenerated similarity data + threshold recommendation.
3. `.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md` is unchanged from before T02 (`git diff` shows zero lines for that path).
4. The P01 verifier `scripts/verify/m020-p01-jaccard-pairwise-contract.sh` still exits 0 against the v2 vector (pairwise contract preserved).
5. The T02 verifier `scripts/verify/m020-p05-feature-vector-extension.sh` exits 0 with `PASS:`.

**Done when**: `bash scripts/verify/m020-p05-feature-vector-extension.sh` prints `PASS:` and exits 0; `bash scripts/verify/m020-p01-jaccard-pairwise-contract.sh` still exits 0; `git diff .orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md` is empty.
