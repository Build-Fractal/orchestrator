---
schema_version: "1.0"
type: phase-plan
phase: "P02"
milestone: "M036"
goal: "Tier 0 manifest + `orchestrator:extract` command (synchronous Tier 0/1 path) + binary preservation, with content-hash gating, size-cap external-storage hook, and stub-tolerant Tier 0 summary."
demo_sentence: "Operator runs `bash scripts/knowledge/extract-reference.sh --manifest tests/fixtures/m036/extract-manifest.yaml` against a 3-doc fixture (1 PDF, 1 DOCX, 1 already-md). Afterwards: each doc has a manifest entry under `knowledge/reference/<cat>/REF-*.md` with summary + tags + content_hash; original binaries exist under `.orchestrator/knowledge/reference/_originals/<source>/<filename>`; Tier 1 plain-text files exist alongside as `REF-*.text.md`; command exits 0 with `EXTRACTED:` lines per doc."
risk: "high"
depends_on: ["P00", "P01"]
---

## Boundary Map

**Produces:**

- `commands/extract.md` — `orchestrator:extract` command document (UX shape, lifecycle, idempotency, error handling). Mirrors `commands/ingest.md` structure.
- `scripts/knowledge/extract-reference.sh` — Bash 3.2 driver (manifest reader + per-doc orchestration + content-hash gating + EXTRACTED:/SKIPPED: structured output).
- `scripts/knowledge/lib/extract-manifest.sh` — pure manifest-parsing helpers (one document record at a time; no file I/O at module level; sourced by the driver).
- `scripts/knowledge/lib/extract-binary-preservation.sh` — pure helpers: sha256 of a file, copy-under-_originals, external-pointer-frontmatter shape (size-cap policy enforcement).
- `scripts/knowledge/lib/extract-tier-0-summary.sh` — pure helper for the Tier 0 summary-generation pass. Three modes: `operator` (manifest-supplied summary string passes through), `stub` (deterministic placeholder for CI / Tier 2-deferred), `auto` (P02 errors with a clear "Tier 2 not implemented until P03" message — wires the seam P03 fills).
- `references/extract-manifest-contract.md` — manifest schema SSOT (Principle XI). Documents top-level fields, per-document fields, default-tier resolution rules (delegating to `references/reference-source-types.yaml`), summary-mode enum, size-cap policy.
- `tests/fixtures/m036/extract-manifest.yaml` — fixture manifest declaring 3 documents (1 cms-rule PDF, 1 training-material DOCX, 1 glossary already-md), with operator-supplied summaries (CON-3-compatible, no live LLM in CI).
- `tests/fixtures/m036/sample.pdf`, `tests/fixtures/m036/sample.docx`, `tests/fixtures/m036/sample.md` — 3-doc fixture binary corpus. `sample.pdf` and `sample.docx` are byte-copies of the existing P01 binaries at `tests/fixtures/m036-tier-1-adapters/sample.pdf` / `sample.docx` so adapter behaviour is already exercised; `sample.md` is a tiny markdown floor.
- `tests/test-tier-0-manifest.sh` — SC-10 acceptance harness (real adapter binaries + real manifest end-to-end; emits `BATTERY: pass=N fail=N` summary line; idempotent via `diff -q` on a second run).
- `.gitignore` — add `.orchestrator/knowledge/reference/_originals/` per CON-7 (b) — operators opt-in to commit binaries by listing exceptions.
- `tools/verify/m036-p02-manifest-contract-shape.sh` — Truth verifier (manifest contract reference exists with required field names).
- `tools/verify/m036-p02-fixture-manifest-shape.sh` — Truth verifier (fixture manifest validates against the contract).
- `tools/verify/m036-p02-fixture-corpus-shape.sh` — Truth verifier (3 fixture binaries exist at expected paths).
- `tools/verify/m036-p02-extract-driver-shape.sh` — Truth verifier (driver script exists, executable, declares `--manifest` flag, sources lib helpers).
- `tools/verify/m036-p02-binary-preservation.sh` — Truth verifier (driver run produces `_originals/<source>/<filename>` byte-identical copy; content_hash in chunk frontmatter matches `shasum -a 256` of binary). Host-aware SKIP if `pdftotext`/`pandoc` absent (then driver short-circuits Tier 1, but binary preservation + Tier 0 summary still run — the SKIP is a safety net).
- `tools/verify/m036-p02-content-hash.sh` — Truth verifier (chunk frontmatter `content_hash` matches the computed hash of the source binary).
- `tools/verify/m036-p02-size-cap-external-pointer.sh` — Truth verifier (drives the driver against a synthetic manifest entry whose `size_cap_bytes_override: 1` forces the smallest fixture above the cap; assert chunk frontmatter contains `external_pointer:` and no copy under `_originals/`). All operations on a `mktemp -d` workspace under `tmp/`.
- `tools/verify/m036-p02-extract-md.sh` — Truth verifier (markdown floor goes through Tier 1 passthrough + Tier 0 summary; chunk file contains the operator-supplied summary; emits one `EXTRACTED:` line for the markdown doc).
- `tools/verify/m036-p02-extract-pdf-host-aware.sh` — Truth verifier (PDF doc; SKIP if `pdftotext` absent; on present-host, asserts `REF-cms-rule-*.text.md` exists with non-empty body).
- `tools/verify/m036-p02-extract-docx-host-aware.sh` — Truth verifier (DOCX doc; SKIP if `pandoc` absent; on present-host, asserts `REF-training-material-*.text.md` exists with non-empty body).
- `tools/verify/m036-p02-idempotency.sh` — Truth verifier (driver run twice on unchanged inputs; second run emits `SKIPPED:` for every doc; `diff -q` of the entire `<workspace>/knowledge/reference` tree across runs reports no changes).
- `tools/verify/m036-p02-extract-command-shape.sh` — Truth verifier (`commands/extract.md` exists with required headings: `## Prerequisites`, `## Inputs`, `## Output`, `## Idempotency`, `## Error Handling`, `## Referenced Scripts`).
- `tools/verify/m036-p02-summary-mode-stub-vs-operator.sh` — Truth verifier (drives driver in `--summary-mode=stub` and `--summary-mode=operator`; asserts summary string differs deterministically per mode).
- `tools/verify/m036-p02-tier-2-deferred-error.sh` — Truth verifier (drives the driver against a manifest entry declaring `tier: 2` with `summary_mode: auto`; asserts non-zero exit and stderr names "P03" + "not implemented" — the seam P03 fills).
- `tools/verify/m036-p02-test-harness.sh` — Truth verifier (SC-10 harness exists, executable, ran-to-completion, emitted `BATTERY:` line; permissive on per-doc PASS/SKIP counts).
- `tools/verify/m036-p02-phase-suite.sh` — phase-suite aggregator (wires every M036 P02 sub-gate above; same shape as `tools/verify/m036-p01-phase-suite.sh`).

**Consumes:**

- P00 SSOTs (read-only):
  - `references/reference-taxonomy.md` — closed taxonomy used for `category` validation.
  - `references/reference-source-types.yaml` — per-category default tier (read by extract driver to resolve `tier:` when manifest entry omits it).
  - `references/reference-frontmatter-contract.md` — frontmatter shape every emitted chunk MUST satisfy.
  - `tools/verify/lib/p00-validate-chunk-frontmatter.sh` — invoked at the end of extraction to validate the emitted chunk's `category` + `tier` (defence-in-depth; manifest-time validation done in driver).
- P01 Tier 1 adapters (live):
  - `scripts/dispatch/adapters/format/markdown.sh` — passthrough (Tier 1 leg for `.md` files).
  - `scripts/dispatch/adapters/format/pdf.sh` — `pdftotext -layout` (Tier 1 leg for `.pdf`).
  - `scripts/dispatch/adapters/format/docx.sh` — `pandoc -t plain` (Tier 1 leg for `.docx`).
  - `scripts/dispatch/adapters/format/registry.tsv` — adapter dispatch table (driver maps file-extension → registry row → adapter path).
- P01 fixture binaries (re-used):
  - `tests/fixtures/m036-tier-1-adapters/sample.pdf` — copied to `tests/fixtures/m036/sample.pdf`. Re-using a known-good binary avoids re-creating fragile minimal-PDFs in this phase.
  - `tests/fixtures/m036-tier-1-adapters/sample.docx` — copied to `tests/fixtures/m036/sample.docx`.
- Existing project tooling:
  - `shasum -a 256` (BSD/macOS) and `sha256sum` (GNU/Linux) — driver probes both, fails clearly if neither present (this is a launch-host constraint already; the orchestrator is CC-only at launch and macOS dev hosts ship `shasum`).
  - `mktemp` — POSIX standard.
  - `bash 3.2` — per CON-2.

## Plan-Time Discipline checks performed

1. **Prerequisite-existence verification** — every upstream path the task plans cite was checked on disk before authoring:
   - `references/reference-taxonomy.md` — exists (P00 deliverable).
   - `references/reference-source-types.yaml` — exists (P00 deliverable).
   - `references/reference-frontmatter-contract.md` — exists (P00 deliverable).
   - `tools/verify/lib/p00-validate-chunk-frontmatter.sh` — exists, executable (P00 T03 deliverable).
   - `scripts/dispatch/adapters/format/markdown.sh` / `pdf.sh` / `docx.sh` — exist, executable (P01 deliverables).
   - `scripts/dispatch/adapters/format/registry.tsv` — exists with all four rows `status=live` (P01 close).
   - `tests/fixtures/m036-tier-1-adapters/sample.pdf` / `sample.docx` — exist on disk (P01 T01 deliverables; re-used by this phase).
   - `tools/verify/m036-p01-phase-suite.sh` — exists (P01 T04 deliverable; pattern-template for the P02 aggregator).
2. **Verifier-availability cross-check** — every command in each task's `## Verification` section resolves to either (a) a framework-owned verifier already on disk (`scripts/verify/check-must-haves.sh`) or (b) an `m036-p02-*.sh` verifier scheduled as a deliverable inside *that same task*. Cross-task verifier dependencies: NONE. The phase-suite aggregator (T04) wires sibling verifiers but doesn't run them as part of its own `## Verification` block.
3. **Classifier-shape pre-validation** — every Truth `Check:` and every `## Verification` line uses the single-script-file shape `bash <path>.sh [args]`. No inline compounds, no plain subshells, no `$()` containing pipes, no process substitution. `classify_command` would return `single-script-file`. The driver script *body* uses `grep | sed` pipelines (legal inside a script body — only the *invocation* shape is classified per AD-19). Sample classifier traces recorded in T02 plan prose.
4. **`run-probe.sh` scope discipline** — every verifier invocation targets a repo-resident path under `tools/verify/...` directly via `bash <path>`. No `run-probe.sh` wrapping (these verifiers live in the project tree, not under `/tmp` / `/var/folders` / `<repo>/tmp/`). `run-probe.sh` IS used inside `m036-p02-size-cap-external-pointer.sh` and `m036-p02-tier-2-deferred-error.sh` for the sub-process driver runs against *staged* manifests under `mktemp -d` workspaces inside `tmp/` — those are the canonical staged-throwaway use case.
5. **Real-DB / real-app smoke discipline** — Not SQL-bound. Analogous discipline (real-binary smoke) IS satisfied: `tests/test-tier-0-manifest.sh` invokes the real driver against the real fixture binaries, exercising real `shasum` + real Tier 1 adapters end-to-end. No mocks at the driver boundary; the only mock surface is the Tier 0 LLM call, which is gated by `--summary-mode=stub|operator` (CI-deterministic) per CON-3 ("no live LLM calls in CI") + spec line "summary (LLM-generated at extract time OR human-authored — operator may override)".
6. **Path-collision check** — every `create` deliverable path in `## Files Likely Touched` was checked via `ls`:
   - `commands/extract.md` — does NOT exist (confirmed via `ls -la`; only `commands/ingest.md` is present). Clear.
   - `scripts/knowledge/extract-reference.sh` — does NOT exist. Clear.
   - `scripts/knowledge/lib/extract-*.sh` (3 files) — none exist. Clear.
   - `references/extract-manifest-contract.md` — does NOT exist. Clear.
   - `tests/fixtures/m036/` (entire dir) — does NOT exist (only `tests/fixtures/m036-tier-1-adapters/` and `tests/fixtures/m036-p05-baseline/` are present). Clear.
   - `tests/test-tier-0-manifest.sh` — does NOT exist. Clear.
   - `tools/verify/m036-p02-*.sh` (15 verifiers + 1 aggregator) — none exist (verified by `ls /tools/verify/ | grep '^m036-p02-'` returning nothing). Clear.
   - `.gitignore` (modify) — exists; modification is additive (append a single line for `_originals/`).
   - All paths use the milestone-prefixed `m036-p02-*` slug per the "milestone slug REQUIRED" naming convention.

## Must-Haves

### Truths

<!-- Each Truth's Check is a single-script-file invocation (AD-19 / AP-009).
     All verifier slugs are milestone-prefixed (m036-p02-*) per the
     "milestone slug REQUIRED" naming convention. All verifiers live under
     tools/verify/ (project-owned, slug-bearing).

     Host-tooling-aware SKIP semantic: per-adapter verifiers (PDF, DOCX)
     probe `command -v` first and emit `SKIP: <tool>-absent` + exit 0 when
     the host tool is missing. The aggregator inspects exit code only; SKIP
     reports as PASS at the aggregator level. Mirrors the M036/P01 pattern. -->

- The manifest contract reference doc declares the required top-level + per-document fields and the summary-mode enum.
  - Check: `bash tools/verify/m036-p02-manifest-contract-shape.sh`
- The fixture manifest at `tests/fixtures/m036/extract-manifest.yaml` validates against the manifest contract (declares 3 documents covering `cms-rule`, `training-material`, `glossary` categories).
  - Check: `bash tools/verify/m036-p02-fixture-manifest-shape.sh`
- The 3-doc fixture corpus exists with one binary per format (PDF, DOCX, MD).
  - Check: `bash tools/verify/m036-p02-fixture-corpus-shape.sh`
- The extract driver `scripts/knowledge/extract-reference.sh` exists, is executable, accepts `--manifest <path>`, and sources the lib helpers.
  - Check: `bash tools/verify/m036-p02-extract-driver-shape.sh`
- Running the driver against the fixture manifest preserves each binary at `.orchestrator/knowledge/reference/_originals/<source>/<filename>` byte-identical to the source.
  - Check: `bash tools/verify/m036-p02-binary-preservation.sh`
- Each emitted chunk's `content_hash` frontmatter field matches `shasum -a 256` of the source binary.
  - Check: `bash tools/verify/m036-p02-content-hash.sh`
- A document whose size exceeds the configured size cap (override-driven for the test) records `external_pointer:` in chunk frontmatter and is NOT copied under `_originals/`.
  - Check: `bash tools/verify/m036-p02-size-cap-external-pointer.sh`
- Markdown floor extraction: `sample.md` produces a `REF-glossary-*.md` chunk file with operator-supplied summary; one `EXTRACTED:` line for the doc.
  - Check: `bash tools/verify/m036-p02-extract-md.sh`
- PDF extraction (host-aware SKIP if `pdftotext` absent): `sample.pdf` produces a `REF-cms-rule-*.text.md` Tier 1 plain-text file alongside the chunk.
  - Check: `bash tools/verify/m036-p02-extract-pdf-host-aware.sh`
- DOCX extraction (host-aware SKIP if `pandoc` absent): `sample.docx` produces a `REF-training-material-*.text.md` Tier 1 plain-text file alongside the chunk.
  - Check: `bash tools/verify/m036-p02-extract-docx-host-aware.sh`
- Re-running the driver on an unchanged manifest emits `SKIPPED:` for every doc and `git status` of the chunk store is clean (idempotency, CON-4).
  - Check: `bash tools/verify/m036-p02-idempotency.sh`
- The `commands/extract.md` command document exists with the required headings (Prerequisites, Inputs, Output, Idempotency, Error Handling, Referenced Scripts).
  - Check: `bash tools/verify/m036-p02-extract-command-shape.sh`
- `--summary-mode=stub` and `--summary-mode=operator` produce different deterministic summary strings; both are emitted into chunk frontmatter without invoking any external LLM provider.
  - Check: `bash tools/verify/m036-p02-summary-mode-stub-vs-operator.sh`
- A manifest entry declaring `tier: 2` with `summary_mode: auto` exits non-zero with a stderr message naming "P03" and "not implemented" (the Tier 2 seam P03 fills).
  - Check: `bash tools/verify/m036-p02-tier-2-deferred-error.sh`
- The SC-10 acceptance harness `tests/test-tier-0-manifest.sh` exists, is executable, ran-to-completion, and emitted a `BATTERY:` summary line.
  - Check: `bash tools/verify/m036-p02-test-harness.sh`

### Artifacts

- `commands/extract.md` (min 60 lines, contains "extract")
- `scripts/knowledge/extract-reference.sh` (min 80 lines, contains "EXTRACTED:")
- `scripts/knowledge/lib/extract-manifest.sh` (min 30 lines, contains "manifest")
- `scripts/knowledge/lib/extract-binary-preservation.sh` (min 30 lines, contains "shasum")
- `scripts/knowledge/lib/extract-tier-0-summary.sh` (min 25 lines, contains "summary_mode")
- `references/extract-manifest-contract.md` (min 50 lines, contains "summary_mode")
- `tests/fixtures/m036/extract-manifest.yaml` (min 20 lines, contains "documents:")
- `tests/fixtures/m036/sample.md` (min 1 lines, contains "M036")
- `tests/test-tier-0-manifest.sh` (min 30 lines, contains "BATTERY:")
- `tools/verify/m036-p02-phase-suite.sh` (min 30 lines, contains "SUMMARY: m036-p02-phase-suite.sh")

### Key Links

- `commands/extract.md` → `scripts/knowledge/extract-reference.sh` (command document references the driver script)
- `scripts/knowledge/extract-reference.sh` → `scripts/knowledge/lib/extract-manifest.sh` (driver sources the manifest helper)
- `scripts/knowledge/extract-reference.sh` → `scripts/knowledge/lib/extract-binary-preservation.sh` (driver sources the preservation helper)
- `scripts/knowledge/extract-reference.sh` → `scripts/knowledge/lib/extract-tier-0-summary.sh` (driver sources the summary helper)
- `scripts/knowledge/extract-reference.sh` → `scripts/dispatch/adapters/format/registry.tsv` (driver reads adapter registry to resolve format → adapter path)
- `references/extract-manifest-contract.md` → `references/reference-source-types.yaml` (manifest contract cross-references the per-category default-tier SSOT)
- `references/extract-manifest-contract.md` → `references/reference-frontmatter-contract.md` (manifest contract cross-references the chunk frontmatter SSOT)
- `tests/test-tier-0-manifest.sh` → `scripts/knowledge/extract-reference.sh` (the SC-10 harness exercises the driver)
- `tools/verify/m036-p02-phase-suite.sh` → `tools/verify/m036-p02-binary-preservation.sh` (aggregator wires the sub-gate)

## Tasks

### T01: Manifest contract reference + fixture corpus + .gitignore update

See `tasks/T01-manifest-contract-and-fixtures-PLAN.md`. Authors `references/extract-manifest-contract.md` (the manifest schema SSOT), the fixture manifest at `tests/fixtures/m036/extract-manifest.yaml`, the 3-doc fixture corpus at `tests/fixtures/m036/sample.{pdf,docx,md}` (PDF and DOCX byte-copied from P01's adapter fixtures; MD authored fresh), and appends the `_originals/` line to `.gitignore` per CON-7 (b). Lands shape verifiers `m036-p02-manifest-contract-shape.sh`, `m036-p02-fixture-manifest-shape.sh`, `m036-p02-fixture-corpus-shape.sh`.

### T02: Extract driver + binary-preservation + content-hash + size-cap

See `tasks/T02-driver-and-preservation-PLAN.md`. Authors `scripts/knowledge/extract-reference.sh` (the driver), the manifest-parsing helper at `scripts/knowledge/lib/extract-manifest.sh`, and the binary-preservation helper at `scripts/knowledge/lib/extract-binary-preservation.sh`. Implements content-hash gating (FR-9 invariant), `_originals/<source>/<filename>` preservation (FR-14), and the size-cap external-storage hook (CON-7). Lands verifiers `m036-p02-extract-driver-shape.sh`, `m036-p02-binary-preservation.sh`, `m036-p02-content-hash.sh`, `m036-p02-size-cap-external-pointer.sh`.

### T03: Tier 0 summary helper + Tier 1 leg orchestration + commands/extract.md

See `tasks/T03-summary-and-command-doc-PLAN.md`. Authors `scripts/knowledge/lib/extract-tier-0-summary.sh` (three modes: `operator`, `stub`, `auto` — `auto` errors on Tier 2 with "P03 not implemented" pointing at the next-phase seam), wires the Tier 1 leg (driver invokes the registry-resolved adapter for `tier: 1` and `tier: 2` docs, emitting `REF-*.text.md`), and authors `commands/extract.md` (mirrors `commands/ingest.md` shape). Lands verifiers `m036-p02-extract-md.sh`, `m036-p02-extract-pdf-host-aware.sh`, `m036-p02-extract-docx-host-aware.sh`, `m036-p02-extract-command-shape.sh`, `m036-p02-summary-mode-stub-vs-operator.sh`, `m036-p02-tier-2-deferred-error.sh`.

### T04: SC-10 harness + idempotency + phase-suite aggregator

See `tasks/T04-acceptance-harness-and-aggregator-PLAN.md`. Authors `tests/test-tier-0-manifest.sh` (the SC-10 acceptance harness running real adapters against real binary fixtures, emitting `BATTERY: pass=N fail=N skip=N`), the idempotency verifier (`m036-p02-idempotency.sh`) which exercises the driver twice and `diff -q`s the chunk-store tree, the harness-shape verifier (`m036-p02-test-harness.sh`), and the phase-suite aggregator (`m036-p02-phase-suite.sh`) wiring all 16 sub-gates.

## Task Dependencies

```
T01 (manifest contract + fixtures + .gitignore)
   |
   +--> T02 (driver + preservation + content-hash)
   |
   T02 --> T03 (summary helper + Tier 1 leg + commands/extract.md)
            |
            T03 --> T04 (SC-10 harness + idempotency + phase-suite)
```

T02 must run after T01 (fixtures and the manifest contract are read by the driver). T03 must run after T02 (the summary helper is wired into the driver authored in T02; the Tier 1 leg orchestration extends the driver). T04 depends on T03 because the SC-10 battery exercises every code path the prior tasks added (preservation + content-hash + summary modes + Tier 1 leg + idempotency).

## Files Likely Touched

- `commands/extract.md` (create)
- `scripts/knowledge/extract-reference.sh` (create)
- `scripts/knowledge/lib/extract-manifest.sh` (create)
- `scripts/knowledge/lib/extract-binary-preservation.sh` (create)
- `scripts/knowledge/lib/extract-tier-0-summary.sh` (create)
- `references/extract-manifest-contract.md` (create)
- `tests/fixtures/m036/extract-manifest.yaml` (create)
- `tests/fixtures/m036/sample.pdf` (create — byte-copy from `tests/fixtures/m036-tier-1-adapters/sample.pdf`)
- `tests/fixtures/m036/sample.docx` (create — byte-copy from `tests/fixtures/m036-tier-1-adapters/sample.docx`)
- `tests/fixtures/m036/sample.md` (create)
- `tests/test-tier-0-manifest.sh` (create)
- `.gitignore` (modify — append `.orchestrator/knowledge/reference/_originals/` line per CON-7 (b))
- `tools/verify/m036-p02-manifest-contract-shape.sh` (create)
- `tools/verify/m036-p02-fixture-manifest-shape.sh` (create)
- `tools/verify/m036-p02-fixture-corpus-shape.sh` (create)
- `tools/verify/m036-p02-extract-driver-shape.sh` (create)
- `tools/verify/m036-p02-binary-preservation.sh` (create)
- `tools/verify/m036-p02-content-hash.sh` (create)
- `tools/verify/m036-p02-size-cap-external-pointer.sh` (create)
- `tools/verify/m036-p02-extract-md.sh` (create)
- `tools/verify/m036-p02-extract-pdf-host-aware.sh` (create)
- `tools/verify/m036-p02-extract-docx-host-aware.sh` (create)
- `tools/verify/m036-p02-idempotency.sh` (create)
- `tools/verify/m036-p02-extract-command-shape.sh` (create)
- `tools/verify/m036-p02-summary-mode-stub-vs-operator.sh` (create)
- `tools/verify/m036-p02-tier-2-deferred-error.sh` (create)
- `tools/verify/m036-p02-test-harness.sh` (create)
- `tools/verify/m036-p02-phase-suite.sh` (create)
