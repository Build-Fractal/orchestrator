---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P07"
milestone: "M011"
provides:
  - "docs/ingesting-arbitrary-specs.md user guide (222 lines, 8 sections) covering the format-agnostic ingest pipeline, the --review/--no-review/--force flag semantics, BLOCK-verdict resolution, stub modes for CI, graceful degradation for the optional conversus binary, and extension to M013/M014 gate presets; executable bits on all 16 P07 verify scripts; closure of M011/P07 with full green suite (16/16 PASS) and no P06 regressions (9/9 PASS)"
requires:
  - "from:T01 what:detect-spec-shape.sh+normalize-spec.sh+spec-normalizer-prompt.md+NORMALIZER_STUB fixture; from:T02 what:conversus.sh adapter+commands/conversus-gate.md+normalize-fidelity preset+gate-result-{pass,block}.md fixtures; from:T03 what:intensity-gate.sh ingest-stage+commands/ingest.md 6-step pipeline+--review/--no-review/--force semantics; from:P06 what:m011-p06-commands-preserve-references.sh pattern; from:disk what:scripts/knowledge/ingest-spec.sh+scripts/state/spec-metrics.sh+scripts/verify/run-suite.sh"
affects:
  - "M011/P07 closure gate; M011 milestone-level closeout is now unblocked; future M013/M014 gate-preset work reuses the e2e gate shape; docs/ directory gains a sixth user guide (ingesting-arbitrary-specs.md)"
key_files:
  - "docs/ingesting-arbitrary-specs.md, tests/fixtures/arbitrary-prd.md, tests/fixtures/normalized-stub.md, scripts/verify/m011-p07-e2e-arbitrary-spec.sh, scripts/verify/m011-p07-gate-pass-block.sh, scripts/verify/m011-p07-intensity-policy.sh, scripts/verify/m011-p07-bash32-compat.sh, scripts/verify/m011-p07-evidence-present.sh, scripts/verify/m011-p07-commands-preserve-references.sh, .orchestrator/milestones/M011/phases/P07/evidence/detect-shape.txt, .orchestrator/milestones/M011/phases/P07/evidence/normalize-transcript.txt, .orchestrator/milestones/M011/phases/P07/evidence/gate-result.md, .orchestrator/milestones/M011/phases/P07/evidence/chunker-transcript.txt, .orchestrator/milestones/M011/phases/P07/evidence/timing.txt, .orchestrator/milestones/M011/phases/P07/evidence/normalized-spec.md"
key_decisions:
  - "T04 is pure-additive on top of T01/T02/T03 with no modification to prior task outputs; stub-mode e2e determinism via NORMALIZER_STUB=1+CONVERSUS_STUB=1 (CI-safe, no live agent); preserve-references regression extended from P06 to P07 by locking in 8 new ingest.md bullets (shape-detect, normalize, adapter, conversus-gate, intensity-gate, normalizer-template, preset, gate-result) on top of the 6 P06 bullets; elapsed_seconds timing budget 120s (vs P06's 60s) because P07 adds two stages; docs guide follows the existing 5-guide convention in docs/ with cross-links to commands/ingest.md and commands/conversus-gate.md"
patterns_established:
  - "stub-mode-determinism pattern: pair NORMALIZER_STUB+CONVERSUS_STUB env vars for deterministic CI e2e of LLM/external-tool pipelines; dogfood evidence gate pattern (file-exists + token-contains + integer-timing-budget) extended phase-over-phase (P06 -> P07); preserved-references regression pattern extended phase-over-phase with additive token lists; sandboxed mktemp -d + EXIT-trap cleanup for stateful e2e gates (continues M011/P06 convention); BLOCK-plus-force shim pattern: inline bash shim script written to TMP simulates commands/ingest.md Step 5 FORCE: audit-trail line without depending on the ingest.md wrapper logic itself"
drill_down_paths:
  - ".orchestrator/milestones/M011/phases/P07/tasks/T04-PAYLOAD.md, .orchestrator/milestones/M011/phases/P07/P07-PLAN.md"
duration: "40m"
verification_result: "pass"
completed_at: "2026-04-17T12:09:59Z"
---

T04 closes out M011/P07 as a pure-additive dogfood + gating task: one new user guide, one new in-repo fixture set, and one fully verified end-to-end gate suite. No T01/T02/T03 production artifacts were modified. The task already had its fixtures (tests/fixtures/arbitrary-prd.md at 58 lines foreign-shaped, tests/fixtures/normalized-stub.md at 74 lines spec-kit-shaped, tests/fixtures/gate-result-{pass,block}.md backstops from T02), all six target verify scripts (m011-p07-e2e-arbitrary-spec.sh, -gate-pass-block.sh, -intensity-policy.sh, -bash32-compat.sh, -evidence-present.sh, -commands-preserve-references.sh), and the five dogfood evidence artifacts under .orchestrator/milestones/M011/phases/P07/evidence/ (detect-shape.txt, normalize-transcript.txt, gate-result.md, chunker-transcript.txt, timing.txt=elapsed_seconds=3) already landed during the iteration.

T04 delivered the missing user guide docs/ingesting-arbitrary-specs.md (222 lines, 8 sections: Overview, Quickstart, When the fidelity gate fires, Interpreting BLOCK verdicts, --force escape hatch, Stub modes for CI, Graceful degradation, Extending to new gate points, See also) cross-linking commands/ingest.md, commands/conversus-gate.md, templates/spec-normalizer-prompt.md, templates/conversus-presets/normalize-fidelity.yml, and templates/gate-result.md. Executable bits set on all P07 verify scripts.

Verification: the six target scripts pass individually; scripts/verify/run-suite.sh m011 P07 -> PASS: 16 / FAIL: 0; scripts/verify/run-suite.sh m011 P06 -> PASS: 9 / FAIL: 0 (no regression). bash32-compat gate PASS across 20 files (4 production + 16 verify scripts). The e2e gate completes the full detect->normalize->gate->ingest->metrics pipeline in elapsed_seconds=4, well under the 120s budget. Gate PASS/BLOCK/BLOCK+--force decision arms verified independently. No deviations from the task plan.
