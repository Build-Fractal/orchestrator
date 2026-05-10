---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P01"
milestone: "M036"
provides:
  - "tests/test-tier-1-adapters.sh (SC-9 acceptance harness invoking all four real Tier 1 adapters against real binary fixtures with host-tooling-aware SKIP per adapter; emits BATTERY: pass=N fail=N skip=N summary line; exit 0 iff fail=0),tools/verify/m036-p01-registry-all-live.sh (registry contract verifier asserting all four formats at status=live via per-format awk single-script extraction),tools/verify/m036-p01-test-harness.sh (harness shape verifier asserting harness exists+executable+ran-to-completion+emitted-BATTERY-line; permissive on per-adapter PASS/SKIP counts so host-tooling absence does not false-FAIL),tools/verify/m036-p01-phase-suite.sh (8-gate aggregator wiring all M036 P01 sub-gates — fixture-corpus-shape + probe-shape + 4 per-adapter verifiers + registry-all-live + test-harness — patterned after m036-p00-phase-suite.sh)"
requires:
  - "from:T01 what:tests/fixtures/m036-tier-1-adapters/+expected/ corpus and tools/verify/m036-p01-fixture-corpus-shape.sh+m036-p01-probe-shape.sh; from:T02 what:scripts/dispatch/adapters/format/markdown.sh+pdf.sh and tools/verify/m036-p01-markdown-adapter.sh+m036-p01-pdf-adapter.sh; from:T03 what:scripts/dispatch/adapters/format/docx.sh+xlsx.sh+lib/xlsx-to-csv.py and registry.tsv all-live state and tools/verify/m036-p01-docx-adapter.sh+m036-p01-xlsx-adapter.sh; from:P00/T03 what:tools/verify/m036-p00-phase-suite.sh as template/shape reference for the new P01 aggregator"
affects:
  - "P01 closes (all 8 must-haves PASS),P02 (Tier 0 manifest + extract command consumes the same registry contract gate),P03 (Tier 2 LLM extraction and conversus fidelity gate fall through to Tier 1 adapters via the same registry rows),P05 (graph schema extension can rely on Tier 1 adapters being live),M036 phase-suite aggregator pattern reusable for P02-P09"
key_files:
  - "tests/test-tier-1-adapters.sh,tools/verify/m036-p01-registry-all-live.sh,tools/verify/m036-p01-test-harness.sh,tools/verify/m036-p01-phase-suite.sh"
key_decisions:
  - "none"
patterns_established:
  - "host-tooling-aware SKIP at the harness level (per-adapter case checks command -v tool or python3 -c import openpyxl BEFORE invoking the adapter; SKIP increments a separate counter that does not contribute to the fail count — the contract is fail=0 not skip=0; mirrors the per-adapter verifier shape from T02 m036-p01-pdf-adapter.sh and T03 m036-p01-xlsx-adapter.sh),BATTERY: pass=N fail=N skip=N output contract (machine-parseable single line; consumers grep for ^BATTERY: and parse pass= and fail= explicitly; exit 0 iff fail=0 regardless of skip count),permissive harness shape verifier (m036-p01-test-harness.sh accepts rc 0 or 1 as ran-to-completion since rc=1 is fail-mode-but-still-emitted-BATTERY whereas rc=2+ would be syntax/abort — captures shape contract without coupling to per-adapter pass count),per-format awk single-script extraction (awk -F TAB -v f=format dollar1==f print dollar3 registry.tsv — one tool one invocation no pipe; classifies clean under AD-19 / AP-009),8-gate phase-suite aggregator pattern reuse (m036-p00-phase-suite.sh used as template — same set -eu + run helper + SUMMARY: line format; per-adapter SKIPs at sub-gate verifier level still report PASS at aggregator level since aggregator inspects exit code only)"
drill_down_paths:
  - ".orchestrator/milestones/M036/phases/P01/tasks/T04-acceptance-harness-and-aggregator-PAYLOAD.md,.orchestrator/milestones/M036/phases/P01/tasks/T04-acceptance-harness-and-aggregator-PLAN.md"
duration: "20m"
verification_result: "pass"
completed_at: "2026-05-02T12:27:43Z"
---

T04 lands the four remaining surfaces that close M036 P01:

1. **tests/test-tier-1-adapters.sh** (228 lines) — SC-9 acceptance harness. Per Plan-Time Discipline rule 5 + CON-3 amended, invokes real adapter scripts against real binary fixtures under tests/fixtures/m036-tier-1-adapters/ (no mocks at the adapter boundary). Host-tooling-aware: each adapter case checks its host tool first (command -v pdftotext / pandoc / python3 + python3 -c "import openpyxl") and SKIPs if absent rather than failing. Emits one PASS:/FAIL:/SKIP: line per adapter and a final BATTERY: pass=P fail=F skip=S summary line. Exit 0 iff fail=0; SKIPs are not failures. Bash 3.2 / POSIX-sh + single-script-file shape per AD-19.

2. **tools/verify/m036-p01-registry-all-live.sh** (45 lines) — registry contract verifier. Reads scripts/dispatch/adapters/format/registry.tsv and uses one awk -F TAB invocation per format to extract the status field, then asserts status=live for each of markdown / pdf / docx / xlsx. Emits PASS:/FAIL: per row and a SUMMARY: line. Single awk per format keeps the classifier shape clean (one tool, no pipe).

3. **tools/verify/m036-p01-test-harness.sh** (66 lines) — harness shape verifier. Asserts (a) harness file exists, (b) is executable (-x), (c) ran to completion (rc in 0 or 1 — captures both fail=0 success and any-fail mode without coupling to per-adapter outcome), (d) stdout contains a ^BATTERY: line. Permissive by design so host-tooling absence does not produce a false-FAIL at the harness-shape level — the per-adapter verifiers (called from the aggregator) catch per-adapter regressions.

4. **tools/verify/m036-p01-phase-suite.sh** (55 lines) — 8-gate phase-suite aggregator. Patterned exactly after tools/verify/m036-p00-phase-suite.sh: same set -eu + run helper + SUMMARY: line format. Wires all 8 P01 sub-gates in T-task order (T01: fixture-corpus-shape + probe-shape; T02: markdown-adapter + pdf-adapter; T03: docx-adapter + xlsx-adapter; T04: registry-all-live + test-harness). Per-adapter SKIPs (pdf/docx/xlsx on hosts without the host tool) still report PASS at the aggregator level since the verifiers exit 0 informationally on SKIP and the aggregators run helper only inspects exit code.

**Verification results (live, dev host):**

- bash tools/verify/m036-p01-registry-all-live.sh: 4 PASS lines + SUMMARY: m036-p01-registry-all-live pass=4 fail=0; exit 0.
- bash tools/verify/m036-p01-test-harness.sh: 4 PASS lines + SUMMARY: m036-p01-test-harness pass=4 fail=0; exit 0.
- bash tools/verify/m036-p01-phase-suite.sh: 8 PASS lines + SUMMARY: m036-p01-phase-suite.sh pass=8 fail=0; exit 0.
- bash tests/test-tier-1-adapters.sh: PASS markdown byte-identical; PASS pdf all-tokens-present; SKIP docx (pandoc absent); SKIP xlsx (python3 or openpyxl absent); BATTERY: pass=2 fail=0 skip=2; exit 0. The 2 SKIPs are the documented expected behavior on the dev host (probe-extraction-tools.sh confirms pandoc=missing, openpyxl=missing). Once host tooling is installed (brew install pandoc; python3 -m pip install --user openpyxl) the battery converges to pass=4 fail=0 skip=0.
- bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M036/phases/P01: 41 PASS / 0 FAIL across all 8 truths, 22 artifact checks (existence + line-count + content-pattern), and 8 key-link checks. Every M036 P01 phase-plan must-have green.

**Idempotency (CON-4):** confirmed. Two consecutive bash tests/test-tier-1-adapters.sh runs produced byte-identical stdout (diff -q showed no differences). Counter values stable; mktemp randomness is contained in temp-dir paths that are not surfaced to the BATTERY: line. SKIP/PASS posture stable across runs.

**Single-script-file shape compliance (AD-19 / AP-009):** every Check: in the phase-plan and every Verification line in the task plan is a single-script-file invocation (bash path). Inside the verifiers and harness, internal logic uses sequential statements and the canonical if-cmd-then control-flow form (the same shape m036-p00-phase-suite.sh uses in production). No compound chains greater than 2, no command-substitution-with-pipes, no process substitution.

**No deviations from plan.** T04 ran the payload Steps 1-4 as specified; no mid-task corrections needed. SKIP outcomes on this host (docx, xlsx) are the planned and documented expected behavior under the host-tooling-aware skip semantic established in T02 + T03.

**Phase P01 closes:** all 8 P01 must-haves PASS, the SC-9 harness emits BATTERY: pass=2 fail=0 skip=2 (exit 0), and the phase-suite aggregator reports SUMMARY: m036-p01-phase-suite.sh pass=8 fail=0. Downstream phases (P02 Tier 0 manifest + extract command, P03 Tier 2 LLM + conversus fidelity gate, P04 ingest, P05 graph) are now unblocked.
