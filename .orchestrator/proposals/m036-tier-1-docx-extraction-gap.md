# Brief — M036 Tier 1 DOCX extraction gap (B6)

**Status:** Deferred — M030/M036-extraction lineage; not blocking M035 launch.
**Authored:** 2026-05-06.
**Surfaced by:** PBJ-central-mono-repo M036 reference-corpus ingest dogfood, 2026-05-06.

## Problem

In pbj-central-mono-repo's M036 corpus (145 chunks):

- 50+ SimplePBJ training-material chunks have **only metadata `.md`**
  (frontmatter present, body=`|`); no `.text.md` Tier 1 sibling.
- Real CMS audit-letter DOCX chunks in the same dir **DO have `.text.md`
  siblings**.

So the deterministic Tier 1 DOCX extractor handled some DOCX inputs but
not others. Hypothesis: SimplePBJ training-material DOCX files have a
structural pattern (embedded media, complex tables, specific Word style
inheritance, image-only pages) that the current extractor falls back
from without surfacing the failure.

## Why this is separate from M036a P03 source-doc fix

M036a P03 (closed 2026-05-02 + 2026-05-06 source-doc fix) addresses
**Tier 2 LLM extraction with conversus fidelity gating**. Tier 1
extraction (deterministic shell adapter, lossy plain-text floor) is a
distinct stage upstream — it produces the `.text.md` that Tier 2 reads
as `--source` for fidelity gating.

The pbj-central operator already filed an unrelated `extract-reference.sh`
patch handoff (`UPSTREAM-PATCH-HANDOFF-extract-list-fields.md`, drops
list fields) which is in the same lineage. **B6 may be a separate
extraction codepath issue, or a related symptom of the same fragility.**
Both belong here, not in wiki domain.

## Investigation hooks

- `scripts/knowledge/extract-reference.sh` — top-level driver.
- `scripts/knowledge/lib/extract-tier-1-*.sh` — adapters per format
  (PDF, DOCX, XLSX, MD).
- The DOCX adapter likely uses `pandoc` or `docx2txt` or a python lib;
  understanding which and why some DOCX inputs fail without flagging
  the failure is the first step.

Repro: snapshot one of pbj-central's silently-failed SimplePBJ DOCX
files (with operator consent — could be sensitive training material;
operator can sanitize first), feed it through `extract-reference.sh`,
observe whether Tier 1 silently produces empty `.text.md` or skips
emission entirely.

## Acceptance shape

- Tier 1 DOCX extractor either succeeds on all well-formed DOCX
  inputs, or surfaces a structured failure (chunk frontmatter +
  manifest entry + actionable diagnostic) that operators can triage.
- Silent-skip path eliminated. Either it works or it tells you why
  it didn't.
- Regression fixture: synthetic DOCX with embedded media + complex
  table + Word styles, exercising the failure mode.

## Sequencing

Demand-driven post-launch fast-follow. M035 launch is the priority;
M036b post-launch slice (P08–P09) is the natural home for operator-
facing extraction-quality work. **Not blocking M035.**

The pbj-central operator's existing patch handoff
(`UPSTREAM-PATCH-HANDOFF-extract-list-fields.md`) is queued for the same
M036b/P09 operator-facing-scale-UX phase; this brief stacks alongside it.
