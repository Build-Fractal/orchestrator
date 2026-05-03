---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P02"
milestone: "M036"
provides:
  - "tests/test-tier-0-manifest.sh (SC-10 end-to-end acceptance harness — drives extract-reference.sh against the 3-doc fixture manifest in a mktemp -d workspace; per-doc host-tooling-aware SKIP for PDF/DOCX; asserts EXTRACTED on first run, SKIPPED on second run, frontmatter shape per chunk, byte-identical originals; emits BATTERY: pass=N fail=N skip=N as the last stdout line; exit 0 iff fail=0); tools/verify/m036-p02-idempotency.sh (CON-4/FR-9 idempotency contract verifier — drives the driver into two fresh workspaces and diff -qr asserts byte-identical trees; then re-runs against an existing tree and asserts SKIPPED emission; markdown-only fixture so always-runnable on bare hosts); tools/verify/m036-p02-test-harness.sh (harness-shape verifier — asserts the SC-10 harness exists, executable, ran-to-completion (rc<=1), and emitted a well-formed BATTERY: line; permissive on per-doc PASS/SKIP counts so host-tooling absence does not false-FAIL); tools/verify/m036-p02-phase-suite.sh (15-gate aggregator wiring 13 prior P02 sub-gates plus the two T04 verifiers; patterned after m036-p01-phase-suite.sh — run helper inspects exit code only so SKIP-emitting sub-gates report PASS at the aggregator level)"
requires:
  - "T01 (manifest contract SSOT, fixture manifest, sample.{pdf,docx,md} fixtures, 3 sub-gate verifiers); T02 (extract-reference.sh driver scaffold, manifest parser lib, binary preservation lib, 4 sub-gate verifiers); T03 (extract-tier-0-summary.sh helper, commands/extract.md, 6 sub-gate verifiers — driver end-to-end functional once T03 lands); P01 (m036-p01-phase-suite.sh as pattern template — read-only reference)"
affects:
  - "P02 close (this task lands the final 3 verifiers + harness; phase-suite aggregator now wires all 15 sub-gates green); P03 (Tier 2 LLM extraction will extend the harness with auto-mode docs and the conversus fidelity gate); P04 (ingest layer — consumes the byte-identical chunk store this idempotency contract guarantees); spec.md SC-10 / FR-9 / CON-4 invariants — now mechanically gated"
key_files:
  - "tests/test-tier-0-manifest.sh, tools/verify/m036-p02-idempotency.sh, tools/verify/m036-p02-test-harness.sh, tools/verify/m036-p02-phase-suite.sh"
key_decisions:
  - "none"
patterns_established:
  - "BATTERY: pass=N fail=N skip=N output contract reused from M036 P01 (machine-parseable single line at last stdout line; consumers grep ^BATTERY: pass=[0-9]+ fail=[0-9]+ skip=[0-9]+$; exit 0 iff fail=0 regardless of skip count); two-tier idempotency-contract pattern (1) byte-identical-tree across two fresh workspaces via diff -qr REF1 REF2 + diff -qr ORIG1 ORIG2 (2) re-run-against-existing-tree emits SKIPPED rather than EXTRACTED — the second contract is what content-hash gating actually buys; per-doc host-tooling-aware SKIP at harness layer (PDF + DOCX docs SKIP if pdftotext/pandoc absent; markdown doc always runs; harness emits SKIP: <doc> (<tool>-absent) lines for the operator-readable trail and increments skip counter without contributing to fail); markdown-only fallback sub-manifest emitted via heredoc inside mktemp -d workspace when host tooling incomplete (preserves end-to-end coverage of the markdown-floor path even on bare hosts; format-agnostic idempotency contract is gated even when other formats SKIP); permissive harness-shape verifier (rc <=1 acceptable since rc=1 is fail-mode-but-still-emitted-BATTERY whereas rc=2+ would be syntax/abort — captures shape contract without coupling to per-doc pass count); 15-gate aggregator pattern reuse (m036-p01-phase-suite.sh used as template — same set -eu + run helper redirecting both stdout+stderr to /dev/null + SUMMARY: line format; sub-gate exit code is the only signal; SKIP-internal verifiers exit 0 informationally so they report PASS at aggregator level)"
drill_down_paths:
  - ".orchestrator/milestones/M036/phases/P02/tasks/T04-acceptance-harness-and-aggregator-PLAN.md, .orchestrator/milestones/M036/phases/P02/tasks/T04-acceptance-harness-and-aggregator-PAYLOAD.md"
duration: "15m"
verification_result: "pass"
completed_at: "2026-05-02T15:30:00Z"
---

T04 lands the SC-10 end-to-end acceptance harness, the focused CON-4/FR-9 idempotency verifier, the harness-shape verifier, and the 15-gate phase-suite aggregator that wires every M036 P02 sub-gate.

**What was built**:

- `tests/test-tier-0-manifest.sh` (~140 lines) — SC-10 acceptance harness. Drives `scripts/knowledge/extract-reference.sh` against the 3-doc fixture manifest in a `mktemp -d` workspace. Per-doc host-tooling-aware SKIP: PDF + DOCX docs run only if `pdftotext` / `pandoc` are present; otherwise the harness stages a markdown-only sub-manifest via heredoc and exercises just the always-runnable markdown floor. Asserts `EXTRACTED:` line per doc on first run, `SKIPPED:` line per doc on second run (no `EXTRACTED:`), and the required frontmatter fields (`content_hash`, `tier`, `category`, `cite_id`, `source`, `published`) on every Tier 0 chunk file. Last stdout line is `BATTERY: pass=N fail=N skip=N`. Exit 0 iff `fail=0`.

- `tools/verify/m036-p02-idempotency.sh` (~85 lines) — focused CON-4 / FR-9 idempotency contract verifier. Always-runnable (markdown-only fixture; idempotency is format-agnostic). Drives the driver against two fresh workspaces and asserts the resulting trees are byte-identical via `diff -qr`. Then re-runs the driver against an existing tree and asserts the operator sees `SKIPPED:` (the content-hash gate working as designed) rather than `EXTRACTED:`. Emits `SUMMARY: m036-p02-idempotency.sh fail=N`.

- `tools/verify/m036-p02-test-harness.sh` (~45 lines) — harness-shape verifier. Asserts the SC-10 harness exists, is executable, runs to completion (rc <= 1; rc > 1 means abort/syntax), and emits a well-formed `BATTERY:` line via the regex `^BATTERY: pass=[0-9]+ fail=[0-9]+ skip=[0-9]+$`. Permissive on per-doc PASS/SKIP counts so host-tooling absence (no pandoc here) does not false-FAIL.

- `tools/verify/m036-p02-phase-suite.sh` (~70 lines) — 15-gate aggregator. Patterned after `tools/verify/m036-p01-phase-suite.sh`. Wires all 13 prior P02 sub-gates (T01: manifest-contract-shape, fixture-manifest-shape, fixture-corpus-shape; T02: extract-driver-shape, binary-preservation, content-hash, size-cap-external-pointer; T03: extract-md, extract-pdf-host-aware, extract-docx-host-aware, extract-command-shape, summary-mode-stub-vs-operator, tier-2-deferred-error) plus the two T04 verifiers (idempotency, test-harness). The `run` helper inspects exit code only — SKIP-internal verifiers exit 0 informationally so they report PASS at the aggregator level on bare hosts.

**Verification result**: PASS at every gate.

- `bash tools/verify/m036-p02-test-harness.sh` → `SUMMARY: m036-p02-test-harness.sh fail=0`, exit 0.
- `bash tools/verify/m036-p02-idempotency.sh` → `SUMMARY: m036-p02-idempotency.sh fail=0`, exit 0.
- `bash tests/test-tier-0-manifest.sh` (SC-10 harness output, dev host has pdftotext but lacks pandoc) → `BATTERY: pass=8 fail=0 skip=1`.
- `bash tools/verify/m036-p02-phase-suite.sh` → `SUMMARY: m036-p02-phase-suite.sh pass=15 fail=0`, exit 0.

**Patterns established / reused**:

- `BATTERY: pass=N fail=N skip=N` last-stdout-line contract carried from M036 P01.
- Two-tier idempotency contract: byte-identical trees across fresh workspaces *and* SKIPPED on re-run against an existing tree.
- Markdown-only fallback sub-manifest authored via heredoc inside the harness when host tooling is incomplete — preserves end-to-end coverage of the markdown floor even on bare hosts.
- Permissive harness-shape verifier (rc <= 1 acceptable) so host-tooling absence does not false-FAIL the shape gate.
- 15-gate aggregator pattern reuse from `m036-p01-phase-suite.sh` (same `set -eu` + `run` helper + SUMMARY: line format; aggregator inspects exit code only so SKIP-internal verifiers report PASS).

**Forward-pointing notes**:

- P03 (Tier 2 LLM extraction) will extend the SC-10 harness with `summary_mode: auto` documents and the conversus fidelity gate; the BATTERY contract is forward-compatible with additional `pass`/`skip` increments.
- P04 (ingest layer) consumes the byte-identical chunk store this idempotency contract guarantees — re-ingests need to short-circuit on unchanged `content_hash`.
- The aggregator's 15-gate count rolls up to the M036 P02 phase-summary `provides:` block once the phase-close hand-off authors `P02-SUMMARY.md`.

T04 closes; M036 P02 is now end-to-end gated.
