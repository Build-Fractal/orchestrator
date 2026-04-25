---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "M026/P02"
milestone: "M026"
provides:
  - "dual-edition regression test with visible-skip annotations for OSS and paid Conversus editions; sample-spec.md fixture; shape-not-value (DC-4) sorted-key diff verification"
requires:
  - "T01 (adapter edition=/reason= lines); tests/fixtures/gate-result-pass.md; conversus pipx venv metadata at ~/.local/pipx/venvs/conversus"
affects:
  - "tests/test-conversus-adapter-shim.sh; tests/fixtures/sample-spec.md; scripts/verify/m026-p02-dual-edition-test-shape.sh"
key_files:
  - "tests/test-conversus-adapter-shim.sh,tests/fixtures/sample-spec.md,scripts/verify/m026-p02-dual-edition-test-shape.sh"
key_decisions:
  - "OQ-3 resolution: ollama absent means OSS-Anthropic branch skips with known-upstream-429 annotation (visible-skip); DC-4: SC-6 key-set diff is shape-not-value; AD-6: sections 1/1b/2 untouched, net-new section 3 replaces the prior real-binary mock-provider block"
patterns_established:
  - "visible-skip (annotated SKIP: line) over silent-skip for unavailable edition branches; dual-edition detection via pip-show Home-page probe reusing adapter's metadata probe; sorted-key diff of gate-result frontmatter as DC-4 contract"
drill_down_paths:
  - ".orchestrator/milestones/M026/phases/P01/OLLAMA-PROBE.md,.orchestrator/milestones/M026/phases/P01/M026-CONVERSUS-PARITY.md,references/architecture.md#conversus-adapter-operator-notes"
duration: "15"
verification_result: "pass"
completed_at: "2026-04-24T22:16:03Z"
---

Section 3 of tests/test-conversus-adapter-shim.sh replaced with a CONVERSUS_INTEGRATION=1 gated dual-edition block. Under the current operator environment (OSS installed, paid absent, no ANTHROPIC_API_KEY, no ollama, no CONVERSUS_PROVIDER=claude-code), both branches visible-skip: OSS with 'SKIP: known-upstream-429 (OSS lacks PR #29...)', paid with 'SKIP: paid build not installed'. Both SKIPs print to stdout and the test exits 0. Sections 1, 1b, 2 untouched per AD-6. When both editions actually run, the shape-not-value contract (DC-4, SC-6) is enforced via diff -q on sorted gate-result frontmatter key sets — verdict values are never compared. Created scripts/verify/m026-p02-dual-edition-test-shape.sh (10 assertions, all passing) covering: section-3 marker + CONVERSUS_INTEGRATION=1 guard ordering, OSS known-upstream-429 literal, paid 'paid build not installed' literal, SC-6 sorted-key diff pattern, shim-without-integration exit 0, shim-with-integration exit 0 plus both visible-skip annotations printed. Created tests/fixtures/sample-spec.md (10 lines: title + user story + FR-1) reused from the stub-mode integration path. Regression guards (edition-detection-contract, adapter-invariants, jsonl-edition-field) still pass. Line delta on shim test: +80/-30 (net +50), well under the payload budget of +90.
