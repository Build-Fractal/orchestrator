---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P01"
milestone: "M036"
provides:
  - "markdown.sh adapter (passthrough cat),pdf.sh adapter (pdftotext -layout shell-out),registry.tsv markdown+pdf rows flipped from stub to live,m036-p01-markdown-adapter.sh verifier (2 checks: exit-0 + byte-identical),m036-p01-pdf-adapter.sh verifier (2 anchor checks + 5 token checks; host-tooling-aware skip when pdftotext absent)"
requires:
  - "from:T01 what:tests/fixtures/m036-tier-1-adapters/sample.md+sample.pdf+expected/sample-pdf.txt; from:P00/T02 what:scripts/dispatch/adapters/format/registry.tsv (stub rows for markdown+pdf)"
affects:
  - "P01/T03 (docx+xlsx adapters land remaining stubs),P01/T04 (registry-all-live aggregator),P01 phase-suite"
key_files:
  - "scripts/dispatch/adapters/format/markdown.sh,scripts/dispatch/adapters/format/pdf.sh,scripts/dispatch/adapters/format/registry.tsv,tools/verify/m036-p01-markdown-adapter.sh,tools/verify/m036-p01-pdf-adapter.sh"
key_decisions:
  - "none"
patterns_established:
  - "Tier 1 deterministic shell adapter shape -- input path as positional arg 1; stdout = extracted text; exit 0 success / 1 missing-input / 2 missing-host-tool; set -eu strict; bash 3.2 / POSIX-sh per CON-2; behavioral verifier shape -- capture adapter stdout to TMPDIR file; assert exit code; assert structural property (byte-identity for passthrough; token allowlist for lossy extractor); single-script-file invocation per AD-19 / AP-009; host-tooling-aware skip semantic -- verifier first probes command -v <tool> and emits SKIP: <tool>-absent + exit 0 informationally when missing (avoids false-FAIL on hosts lacking optional host tools); parallels the docx and xlsx verifier posture in T03; allowlist file format -- one token per line; blank lines + #-comment lines ignored; consumed via while IFS= read -r token loop; matched with grep -q -F (fixed-string) so no regex surprises with token characters"
drill_down_paths:
  - ".orchestrator/milestones/M036/phases/P01/tasks/T02-markdown-and-pdf-adapters-PAYLOAD.md"
duration: "15m"
verification_result: "pass"
completed_at: "2026-05-02T12:11:53Z"
---

T02 lands the two simplest Tier 1 live format adapters and flips their registry rows from stub to live. Both adapters follow the sibling convention from native.sh / speckit.sh in the same directory: positional input path; stdout-only output; clear non-zero exit codes for missing input vs missing host tool.

**Adapters delivered**:

- scripts/dispatch/adapters/format/markdown.sh — pure passthrough (cat). The Tier 1 contract for already-normalized markdown is verbatim preservation, and cat is the correct semantic. 17 lines including header. Exit 0 success, 1 on missing input.
- scripts/dispatch/adapters/format/pdf.sh — shells out to pdftotext -layout <input> - (poppler-utils). The -layout flag preserves visual ordering, which is load-bearing for tabular regulatory PDFs (the M036 reference-corpus use case). 23 lines including header. Exit 0 success, 1 on missing input, 2 on missing pdftotext (with pointer to scripts/lifecycle/probe-extraction-tools.sh for install hints).

**Registry update**: scripts/dispatch/adapters/format/registry.tsv markdown and pdf rows flipped from status=stub to status=live; notes column rewritten from 'P01 deliverable -- ...' to a one-line behavioral description ('markdown -> passthrough (cat)' and 'pdf -> pdftotext -layout (poppler-utils host dependency)'). docx and xlsx rows left at stub for T03.

**Verifiers delivered**:

- tools/verify/m036-p01-markdown-adapter.sh — captures adapter stdout to a TMPDIR file; asserts exit 0 + byte-identity vs the source fixture via diff -q. Both checks PASS (pass=2 fail=0).
- tools/verify/m036-p01-pdf-adapter.sh — host-tooling-aware: probes command -v pdftotext first; if absent emits SKIP: pdftotext-absent and exits 0 informationally (CI hosts without poppler-utils don't false-FAIL the suite). When present: captures adapter stdout, asserts exit 0, asserts non-empty output, then iterates the token allowlist at tests/fixtures/m036-tier-1-adapters/expected/sample-pdf.txt (M036, pdf, fixture, body, text) asserting each appears in the extracted stdout via grep -q -F. All 7 checks PASS on this dev host (pdftotext present at /opt/homebrew/bin/pdftotext).

**Verification results (live, run on the dev host)**:

- bash tools/verify/m036-p01-markdown-adapter.sh -> SUMMARY: m036-p01-markdown-adapter pass=2 fail=0; exit 0.
- bash tools/verify/m036-p01-pdf-adapter.sh -> SUMMARY: m036-p01-pdf-adapter pass=7 fail=0; exit 0.
- bash scripts/dispatch/adapters/format/markdown.sh tests/fixtures/m036-tier-1-adapters/sample.md -> emits the fixture's 116 bytes verbatim.
- bash scripts/dispatch/adapters/format/pdf.sh tests/fixtures/m036-tier-1-adapters/sample.pdf -> emits 'M036 pdf fixture body text'.

All four invocations from the task plan's Verification block succeed on the dev host.

**Patterns established (forward-pointing for T03 docx + xlsx)**:

The host-tooling-aware skip semantic in m036-p01-pdf-adapter.sh is the model T03 will reuse for docx (pandoc dep) and xlsx (xlsx2csv / openpyxl dep). The behavioral-verifier shape (capture stdout to TMP; assert exit code; assert structural property; emit PASS/FAIL/SUMMARY in the canonical format; single-script-file invocation) is the M036 P01 verifier template for the remaining tier-1-adapter checks.

**No deviations from plan**. T02 ran as specified in the payload Steps 1–5; no mid-task corrections needed; no concerns raised.
