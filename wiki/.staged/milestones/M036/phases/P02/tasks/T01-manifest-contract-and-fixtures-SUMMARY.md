---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P02"
milestone: "M036"
provides:
  - "references/extract-manifest-contract.md (M036 SSOT manifest contract — top-level + per-document field declarations + 3-mode summary enum + default-tier-resolution table + tier output layout + idempotency + cross-references); tests/fixtures/m036/extract-manifest.yaml (3-doc fixture manifest covering cms-rule + training-material + glossary at summary_mode=operator); tests/fixtures/m036/sample.md (synthetic glossary fixture); tests/fixtures/m036/sample.pdf + sample.docx (byte-copies of P01 Tier 1 fixtures); .gitignore _originals/ entry per CON-7 (b); 3 single-script-file shape verifiers (m036-p02-manifest-contract-shape.sh, m036-p02-fixture-manifest-shape.sh, m036-p02-fixture-corpus-shape.sh)"
requires:
  - "P00 (reference-taxonomy.md, reference-source-types.yaml, reference-frontmatter-contract.md); P01 (sample.pdf + sample.docx fixtures byte-copied from tests/fixtures/m036-tier-1-adapters/)"
affects:
  - "P02/T02 (extract command + driver authored against this manifest contract); P02/T03+ (verifiers consume the fixture corpus)"
key_files:
  - "references/extract-manifest-contract.md, tests/fixtures/m036/extract-manifest.yaml, tests/fixtures/m036/sample.md, tests/fixtures/m036/sample.pdf, tests/fixtures/m036/sample.docx, tools/verify/m036-p02-manifest-contract-shape.sh, tools/verify/m036-p02-fixture-manifest-shape.sh, tools/verify/m036-p02-fixture-corpus-shape.sh, .gitignore"
key_decisions:
  - "none"
patterns_established:
  - "P02 inherits the M036 verifier conventions intact: milestone-prefixed slug (m036-p02-*), AD-19 single-script-file shape, grep -qF token-loop body, structured PASS:/FAIL:/SUMMARY: stdout, set -eu strict, ROOT resolution via ${ORCHESTRATOR_ROOT:-$(pwd)}; fixture-binary reuse pattern (P01 PDF + DOCX byte-copied into P02 fixture dir avoids re-authoring fragile minimal binaries — both already exercised by P01 host-aware verifiers); manifest-contract SSOT lockstep declared at file head (Principle XI cross-reference paragraph naming the two consumers — driver + lib helper — with the explicit lockstep-update rule for any field change)"
drill_down_paths:
  - ".orchestrator/milestones/M036/phases/P02/tasks/T01-manifest-contract-and-fixtures-PAYLOAD.md"
duration: "15m"
verification_result: "pass"
completed_at: "2026-05-02T13:00:00Z"
---

T01 lands the M036 P02 declarative substrate: the manifest-contract SSOT, the 3-doc fixture manifest, three byte-stable fixture documents (one synthetic Markdown + two P01-byte-copied binaries), the CON-7 `_originals/` `.gitignore` line, and three single-script-file shape verifiers gating the contract + manifest + fixture corpus.

**What was built**:

- `references/extract-manifest-contract.md` — M036 manifest-contract SSOT. Declares the top-level `version` + `documents:` array + per-document fields (`cite_id`, `path`, `category`, `tier`, `summary_mode` enum {operator|stub|auto}, optional `tags`, optional `version`). Documents the default-tier-resolution table (cms-rule→2, training-material→2, glossary→2, regulatory-doc→1) sourced from `references/reference-source-types.yaml`. Specifies tier output layout under `knowledge/reference/<category>/REF-<cite_id>.md` (manifest entry) + `_originals/<source>/<filename>` (binary preservation, FR-14) + `*.tier1.txt` (Tier 1 plain-text). Cross-reference paragraph names the two downstream consumers (`scripts/knowledge/extract-reference.sh` + `scripts/knowledge/lib/extract-manifest.sh`) and the lockstep rule per Principle XI.

- `tests/fixtures/m036/extract-manifest.yaml` — 3-doc fixture manifest at `version: 1`. Doc 1: `policy-001` (cms-rule, tier 1, summary_mode operator) → byte-copy of P01 sample.pdf. Doc 2: `training-002` (training-material, tier 1, summary_mode operator) → byte-copy of P01 sample.docx. Doc 3: `glossary-003` (glossary, tier 1, summary_mode operator) → synthetic Markdown.

- `tests/fixtures/m036/sample.md` — synthetic glossary content (5 terms; min-line gate 10).

- `tests/fixtures/m036/sample.pdf` + `sample.docx` — byte-identical copies of P01 fixtures (`tests/fixtures/m036-tier-1-adapters/sample.pdf|.docx`). No re-authoring of fragile minimal binaries; both files are already exercised end-to-end by P01's host-aware verifiers.

- `.gitignore` append: `_originals/` (CON-7 (b) — binary preservation outputs are git-excluded; SHA-256 content-hash is the durable fingerprint).

- Three shape verifiers under `tools/verify/m036-p02-*`:
  - `manifest-contract-shape.sh` (13 checks): SSOT existence + 13 required-token presence (top-level version field, documents array marker, per-document field names, summary-mode enum values, tier-resolution table marker, output-layout markers, lockstep cross-reference paragraph).
  - `fixture-manifest-shape.sh` (7 checks): file exists + version: 1 + documents: marker + cite_id triplet (policy-001, training-002, glossary-003) + each at summary_mode: operator.
  - `fixture-corpus-shape.sh` (4 checks): all four fixture files exist (sample.md min-lines + .pdf and .docx byte-identical to P01 corpus + extract-manifest.yaml exists).

**Verification**: 3/3 task-scoped truths PASS. Aggregate must-haves: pass=24, fail=0 (13 + 7 + 4). All declared artifact paths existed-clear at plan time (path-collision rule 6 honored).

**Forward notes**:
- T02 (driver + binary preservation lib) consumes this manifest contract and fixture corpus. No driver-side validation is implemented yet; manifest validation is a T02 deliverable.
- T03 consumes the same fixture corpus to exercise per-tier extraction (markdown passthrough, pdf via P01 adapter, docx via P01 adapter — host-aware SKIP cascade).
- The fixture-binary reuse pattern (byte-copying P01 binaries into a per-phase fixture dir) avoids each phase re-authoring fragile minimal binaries; documented as a P02-established pattern for future phases under M036.
