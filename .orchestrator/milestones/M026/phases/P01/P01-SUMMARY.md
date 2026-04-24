---
schema_version: "1.0"
type: phase-summary
id: "P01"
parent: "M026"
milestone: "M026"
provides:
  - "16-row authoritative conversus OSS/paid parity matrix; DC-6 synthesis-crux spike Verdict: GO; ollama + pipx environment probe; nine non-advisory verification gates + advisory summary-shape gate + phase-suite orchestrator; dual-written M026/P01 Recent Changes fragment in CLAUDE.md + AGENTS.md"
requires:
  - "readable ~/Sites/conversus-oss + ~/Sites/conversus trees; scripts/util/dual-write-runtime-md.sh (M014/P01 artifact); M025/P01 bash32-compat + phase-suite pattern references"
affects:
  - "M026/P02 unblocked by gate=GO; OQ-2 narrow-scope triggered narrows P02 scope to FR-1/FR-2 resolver flip; OQ-3/OQ-5 operator decisions pending; adapter code at conversus.sh:285-322 requires zero changes; future paid-feature re-incorporation preserved via dual-edition escape hatch"
key_files:
  - ".orchestrator/milestones/M026/M026-CONVERSUS-PARITY.md,.orchestrator/milestones/M026/phases/P01/SPIKE-SYNTHESIS-CRUX.md,.orchestrator/milestones/M026/phases/P01/P01-SPIKE-GATE.md,.orchestrator/milestones/M026/phases/P01/OLLAMA-PROBE.md,.orchestrator/milestones/M026/phases/P01/P01-VERIFICATION.md,scripts/verify/m026-p01-phase-suite.sh"
key_decisions:
  - "OQ-2 narrow-scope triggered (drifted+absent=5>3); Verdict: GO; FR-8 fallback posture = skip-on-429 with known-upstream-429 annotation; adapter requires zero code changes for OSS; OSS venv install gate deferred to operator pre-P02"
patterns_established:
  - "parity-matrix fixed-vocabulary verdict pattern; binary GO/NO-GO gate-file with machine-readable single-line value; read-only env probe writing probe-report artifact; AD-19 single-script-file verification shape with self-excluding violation-pattern lint; M025/P01 phase-suite + bash32-compat idiom reused"
drill_down_paths:
  - ".orchestrator/milestones/M026/M026-CONVERSUS-PARITY.md,.orchestrator/milestones/M026/phases/P01/SPIKE-SYNTHESIS-CRUX.md,.orchestrator/milestones/M026/phases/P01/OLLAMA-PROBE.md,.orchestrator/milestones/M026/phases/P01/P01-VERIFICATION.md"
duration: "1620"
verification_result: "partial"
completed_at: "2026-04-24T00:18:42Z"
observability_surfaces:
  - "none"
---

Verdict: GO

P01 closes with a binary GO from the DC-6 synthesis-crux spike. The authoritative parity matrix at `.orchestrator/milestones/M026/M026-CONVERSUS-PARITY.md` captures 16 rows (11 verified-identical, 3 verified-drifted, 2 verified-absent, 0 verified-moot) from symmetrical fs-inspection of `~/Sites/conversus-oss` and `~/Sites/conversus` on 2026-04-23. OQ-2 narrow-scope threshold triggered (drifted+absent=5 > 3) — P02 ships the resolver flip + Recent Changes + dogfood smoke-test fixtures; dual-edition-test generalization and preset-migration follow-ups defer to a later milestone.

Three substantive findings frame P02 planning: (1) the adapter's read-back + linter invocation at `conversus.sh:285-322` requires **zero code changes** — OSS ships `linter.output_contract` byte-identical to paid, writes synthesis to the same `summary/final.md` path via `OutputManager.get_synthesis_path()`, and emits a strict-superset JSON key set that includes all three adapter-consumed keys at exact nesting. P02 needs only the FR-1/FR-2 resolver flip. (2) The 2 verified-absent rows are PR #28 (claude-code tool-use) and PR #29 (anthropic 429 retry + concurrency=1), both paid-only features OSS lacks. OSS is not a subset of paid — they are siblings with divergent history since the Apache-2.0 extraction at commit `1bfd62c`. Per the operator's stated posture (project_m026_oss_posture.md), M026 focuses on OSS exclusively for now but preserves the paid-edition escape hatch for future paid-feature re-incorporation. (3) The four "smoke-confirmed drift" rows from oss-early-review.md turned out to be orchestrator-preset drift, not OSS-vs-paid drift — both conversus editions behave identically on YAML frontmatter rejection, `agents[].role` requirement, `prompt:` (not `system_prompt:`), and `output: <string>`. The real drift is between our orchestrator presets and both conversus editions, a synth-layer concern orthogonal to the migration that can be addressed independently.

Two environment observations block-or-gate P02: (a) ollama absent on the operator machine, so FR-8 OSS-branch falls back to `skip-on-429` with `known-upstream-429` annotation per OQ-3. (b) The OSS venv itself (`~/.local/pipx/venvs/conversus-oss`) is not yet installed — only the paid venv exists. Per OQ-5, P02 must decide ship-with-fallback (FR-8 auto-skips OSS-branch tests on machines where the OSS venv is absent) or gate-on-install (operator `pipx install conversus-oss` before P02 dispatch so FR-8 has real two-edition coverage). Recommendation is gate-on-install.

Nine non-advisory gates are in place under `scripts/verify/m026-p01-*.sh` plus one advisory (`summary-shape-when-present`) and one phase-suite orchestrator. All nine suite gates green (`SUMMARY: m026-p01-phase-suite.sh pass=9 fail=0`). CLAUDE.md + AGENTS.md Recent Changes regions carry the dual-written M026/P01 fragment. See `M026-CONVERSUS-PARITY.md` for the authoritative drift ledger and `SPIKE-SYNTHESIS-CRUX.md` for the GO rationale.
