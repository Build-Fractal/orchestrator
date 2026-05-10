---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P02"
milestone: "M036"
provides:
  - "scripts/knowledge/lib/extract-tier-0-summary.sh (pure helpers — generate_tier_0_summary <mode> <category> <cite_id> <operator-summary> <tier> with operator|stub|auto modes; extract_tier_1_via_registry <src> <out> <registry> resolving md|pdf|docx|xlsx → adapter via registry.tsv awk lookup, with xlsx multi-output --out-dir contract + marker file; sourced by scripts/knowledge/extract-reference.sh; no top-level I/O per MEM004); commands/extract.md (~80 lines — Prerequisites + Inputs + Output + Idempotency + Error Handling + Referenced Scripts + Reference Files sections; declares EXTRACTED:/SKIPPED: stdout protocol; documents --manifest/--reference-root/--originals-root/--summary-mode/--size-cap-bytes flags; explicitly defers Tier 2 + summary_mode:auto to P03); 6 verifiers under tools/verify/m036-p02-* (extract-md.sh — markdown floor end-to-end, no host-dep, 4 checks; extract-pdf-host-aware.sh — host-aware SKIP on pdftotext-absent, 2 checks when present; extract-docx-host-aware.sh — host-aware SKIP on pandoc-absent, 2 checks when present; extract-command-shape.sh — 9 token-presence checks against commands/extract.md using grep -qF -e form for leading-dash safety; summary-mode-stub-vs-operator.sh — drives driver twice with different summary_modes, asserts both bodies present and distinct; tier-2-deferred-error.sh — asserts tier:2 + summary_mode:auto exits non-zero with stderr naming both 'P03' and 'not implemented')"
requires:
  - "T01 (manifest contract SSOT, fixture manifests, sample.{pdf,docx,md} fixtures); T02 (driver scaffold, manifest parser lib, binary preservation lib — driver sources T03's lib/extract-tier-0-summary.sh at top); P00 (reference-source-types.yaml for default-tier resolution); P01 (registry.tsv + format adapters — markdown.sh, pdf.sh, docx.sh, xlsx.sh — invoked by extract_tier_1_via_registry)"
affects:
  - "T04 (acceptance harness + phase-suite aggregator gates the now-complete driver end-to-end including the T02 behavioural verifiers that depended on T03's helper)"
key_files:
  - "scripts/knowledge/lib/extract-tier-0-summary.sh, commands/extract.md, scripts/knowledge/extract-reference.sh, tools/verify/m036-p02-extract-md.sh, tools/verify/m036-p02-extract-pdf-host-aware.sh, tools/verify/m036-p02-extract-docx-host-aware.sh, tools/verify/m036-p02-extract-command-shape.sh, tools/verify/m036-p02-summary-mode-stub-vs-operator.sh, tools/verify/m036-p02-tier-2-deferred-error.sh"
key_decisions:
  - "none"
patterns_established:
  - "Registry-driven Tier 1 dispatch pattern (extension → registry.tsv awk-lookup → adapter path → invocation): the driver delegates ALL Tier 1 host-tool knowledge to the format adapters (P01) via the registry table (P00); extract_tier_1_via_registry holds zero per-format logic beyond the extension→fmt label mapping; new formats land entirely as new registry rows + adapters with no driver edits required; xlsx-style multi-output adapters get a marker-file convention (text-output-path holds a pointer line referencing the per-sheet CSV directory) preserving the single-text-output-path contract that downstream chunks key on; cross-task ordering pattern carried from T02 (T02's behavioural verifiers exercise properties needing T03's helper — verifiers authored in T02 alongside the driver they test, become green only after T03 lands the helper the driver sources; auto-loop's first-fail-retry handles ordering at execute time); grep flag-safety carried into all 6 T03 verifiers — grep -qF -e \"$pat\" form so leading-dash tokens like '--manifest' are not misinterpreted as flags (initial author of m036-p02-extract-command-shape.sh used grep -qF \"$pat\" and hit BSD-grep flag-rejection during first run; corrected mid-task); Tier 2 / summary_mode:auto deferred-error pattern — auto mode in P02 hard-errors with stderr naming the future phase ('P03') and the actionable hint ('not implemented' + 'use summary_mode: operator or stub instead'); makes the seam to P03 explicit and gives operators an actionable error rather than a silent fall-through"
drill_down_paths:
  - ".orchestrator/milestones/M036/phases/P02/tasks/T03-summary-and-command-doc-PLAN.md, .orchestrator/milestones/M036/phases/P02/tasks/T03-summary-and-command-doc-PAYLOAD.md"
duration: "20m"
verification_result: "pass"
completed_at: "2026-05-02T15:00:00Z"
---

T03 lands the summary helper, the Tier 1 registry-dispatch leg, the `commands/extract.md` command document, and the 6 T03-specific verifiers. The driver authored in T02 was already wired to source `lib/extract-tier-0-summary.sh` and call `generate_tier_0_summary` + `extract_tier_1_via_registry`; T03 supplies the pure-helper file those calls bind to. With T03 closed, the M036 P02 extract path is end-to-end functional and T02's amber behavioural verifier (`m036-p02-size-cap-external-pointer.sh`) is now green.

**What was built**:

- `scripts/knowledge/lib/extract-tier-0-summary.sh` (~96 lines, was already on disk from a prior attempt — verified shape against the plan, no edits required). Two pure functions:
  - `generate_tier_0_summary <mode> <category> <cite_id> <operator-summary> <tier>` — `operator` mode echoes the operator-supplied summary verbatim (errors on empty per the manifest's `summary:` requirement); `stub` mode emits a deterministic placeholder `[stub-summary] <category>: <cite_id>`; `auto` mode hard-errors with stderr naming `P03` and `not implemented` plus the actionable hint to use operator/stub or wait for P03.
  - `extract_tier_1_via_registry <src> <out> <registry-tsv>` — extension-to-format mapping (`md|markdown|pdf|docx|xlsx`); registry awk-lookup for the adapter row (column 1 = format, column 2 = adapter path); resolves repo-relative adapter paths against `${ORCHESTRATOR_ROOT:-$(pwd)}`; xlsx adapters get the multi-output `--out-dir` contract with a marker-file written at the text-output-path; non-xlsx adapters write stdout directly to the text-output-path. Bash 3.2 / POSIX-sh; no top-level I/O.

- `commands/extract.md` (77 lines, was already on disk — verified shape and content against the plan, no edits required). Sections: Prerequisites (host-tool list + manifest convention), Inputs (5 flags), Output (`_originals/...`, `REF-<category>-<cite_id>.md` Tier 0 chunk, `REF-...text.md` Tier 1 file, EXTRACTED:/SKIPPED: stdout protocol), Idempotency (CON-4 + content_hash gate), Error Handling (5 error classes including the Tier 2 / summary_mode:auto P03 deferral), Referenced Scripts, Reference Files. Distinguishes `orchestrator:extract` from `orchestrator:ingest` per the M036 spec.

- `scripts/knowledge/extract-reference.sh` (173 lines, was already on disk from T02 with the T03 source-line `. "$HERE/lib/extract-tier-0-summary.sh"` and T03 call sites already wired). Verified the registry-dispatch and Tier 0 summary call signatures match the helper authored in step 1.

- 6 T03-specific verifiers under `tools/verify/m036-p02-*`:
  - `extract-md.sh` — drives the driver against a markdown-only manifest in a mktemp workspace; asserts chunk file + text file exist, operator summary appears in chunk body, `EXTRACTED: md-fixture-01 ...` line emitted on stdout. No host-tool dependency (markdown adapter is a passthrough).
  - `extract-pdf-host-aware.sh` — probes `pdftotext`; SKIPs on absent. When present, drives PDF-only manifest, asserts text file exists with non-empty body.
  - `extract-docx-host-aware.sh` — probes `pandoc`; SKIPs on absent. When present, drives DOCX-only manifest, asserts text file exists with non-empty body.
  - `extract-command-shape.sh` — 9 token-presence checks against `commands/extract.md` (the 6 required `##` headings + `--manifest` + `EXTRACTED:` + `SKIPPED:`). Uses `grep -qF -e "$pat"` form for leading-dash safety.
  - `summary-mode-stub-vs-operator.sh` — drives the driver twice in `op/` and `stub/` workspaces against a markdown fixture, asserts the operator-mode chunk contains the supplied summary string and the stub-mode chunk contains the deterministic `[stub-summary] glossary: mode-fixture-01` placeholder.
  - `tier-2-deferred-error.sh` — drives the driver with `tier: 2` + `summary_mode: auto`, asserts non-zero exit + stderr names both `P03` and `not implemented`.

**Verification result — PASS**:

All 6 T03 verifiers run green on this host:

- `m036-p02-extract-md.sh` → `SUMMARY: m036-p02-extract-md.sh fail=0`, exit 0. (4/4 PASS — chunk exists, text exists, operator summary in chunk body, EXTRACTED: line emitted.)
- `m036-p02-extract-pdf-host-aware.sh` → `SUMMARY: m036-p02-extract-pdf-host-aware.sh fail=0`, exit 0. (2/2 PASS — text file exists, text file non-empty bytes=28; pdftotext is present on this host.)
- `m036-p02-extract-docx-host-aware.sh` → `SKIP: pandoc-absent`, exit 0. (Host-aware skip working as designed; pandoc not installed on this host. Verifier behaviour matches T02's pattern; will run live on hosts with pandoc.)
- `m036-p02-extract-command-shape.sh` → `SUMMARY: m036-p02-extract-command-shape.sh fail=0`, exit 0. (9/9 PASS after one mid-run fix: original `grep -qF "$pat"` form misinterpreted `--manifest` as a grep flag; corrected to `grep -qF -e "$pat"` per the T02-established pattern.)
- `m036-p02-summary-mode-stub-vs-operator.sh` → `SUMMARY: m036-p02-summary-mode-stub-vs-operator.sh fail=0`, exit 0. (2/2 PASS — operator summary present in op-mode chunk, stub summary present in stub-mode chunk.)
- `m036-p02-tier-2-deferred-error.sh` → `SUMMARY: m036-p02-tier-2-deferred-error.sh fail=0`, exit 0. (3/3 PASS — driver exited rc=1, stderr names 'P03', stderr names 'not implemented'.)

**Cross-task ordering — T02's amber verifier now green**:

T02 closed `done_with_concerns` because `m036-p02-size-cap-external-pointer.sh` was failing with `lib/extract-tier-0-summary.sh: No such file or directory` (the driver sourced a T03 file that hadn't landed yet). With the helper now on disk, that verifier was re-run independently and reports `SUMMARY: m036-p02-size-cap-external-pointer.sh fail=0`, exit 0 (2/2 PASS — external_pointer recorded in chunk, binary not copied above cap). The cross-task ordering pattern documented in T02's plan (`Plan-Time Discipline rule 2`, "auto-loop's first-fail-retry handles ordering at execute time") played out exactly as designed.

T02's other two amber verifiers (`m036-p02-binary-preservation.sh`, `m036-p02-content-hash.sh`) require pandoc + pdftotext to drive the full 3-doc fixture corpus; on this host (pandoc absent) they SKIP cleanly (exit 0). On a fully-tooled host they would now run end-to-end against the T03-completed driver.

**Forward notes for T04**:

- T04 (acceptance harness + phase-suite aggregator) has the full P02 verifier surface to gate against: 4 T01 truth-check verifiers (manifest/fixture shape) + 4 T02 verifiers (driver shape, binary preservation, content hash, size-cap external pointer) + 6 T03 verifiers (extract-md, extract-pdf-host-aware, extract-docx-host-aware, extract-command-shape, summary-mode-stub-vs-operator, tier-2-deferred-error) = 14 verifiers total under `tools/verify/m036-p02-*`.
- The host-aware SKIP pattern across `m036-p02-*` verifiers is consistent: `SKIP: <tool>-absent` + exit 0 is treated as informational PASS by the aggregator (matches the T02-established convention, which itself carried forward the M036/P01 host-aware verifier convention).
- No new host-tool dependencies introduced by T03 (Tier 1 leg uses the P01-blessed tools; Tier 2 not in scope). The acceptance harness can rely on the same probe-and-skip story T02 set up.
- The Tier 2 / summary_mode:auto error path tested by `tier-2-deferred-error.sh` is the explicit P03 seam — when P03 lands the conversus-routed Tier 2 path, this verifier should be replaced (or the assertion inverted) so the success path goes green instead of asserting the deferred-error.
