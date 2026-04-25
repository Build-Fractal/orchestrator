---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "M026/P02"
milestone: "M026"
provides:
  - "adapter edition-detection resolver (CONVERSUS_EDITION env primary + pip-show metadata probe fallback); check stdout now emits edition= and reason= lines after available=/conversus_path=; new _resolve_edition helper is callable by T02/T03 consumers"
requires:
  - "P01 parity matrix addendum (.orchestrator/milestones/M026/M026-CONVERSUS-PARITY.md) establishing single-venv reality; P01 operator state from OLLAMA-PROBE.md confirming OSS installed at ~/.local/pipx/venvs/conversus/"
affects:
  - "T02 (JSONL edition field consumes resolver output); T03 (dual-edition test shape consumes resolver output); T04 (gate verdict reliability); downstream invocations from specify.sh and github-common.sh"
key_files:
  - "scripts/dispatch/adapters/tool/conversus.sh (modified, +75 lines); scripts/verify/m026-p02-edition-detection-contract.sh (created); scripts/verify/m026-p02-adapter-invariants.sh (created)"
key_decisions:
  - "env-var primary over metadata-only to let operators declare edition without venv probe; fallthrough-with-stderr-warning on invalid CONVERSUS_EDITION values (never silently accept); conversus-oss tried FIRST in user-local fallback order (OSS-primary posture per project_m026_oss_posture.md); stub mode always emits edition=unknown reason=stub (stub is edition-agnostic by design)"
patterns_established:
  - "two-tier detection (env-var declaration + metadata probe) pattern reusable for future runtime identification; stderr for warnings / stdout for structured fields (DC-5) enforced in resolver; line-order stability as verifiable contract (available=/conversus_path=/edition=/reason=)"
drill_down_paths:
  - "scripts/dispatch/adapters/tool/conversus.sh:_resolve_edition (new helper); scripts/dispatch/adapters/tool/conversus.sh:_resolve_binary (amended to emit edition/reason and call _resolve_edition on every success branch); scripts/verify/m026-p02-edition-detection-contract.sh (18 PASS assertions); scripts/verify/m026-p02-adapter-invariants.sh (29 PASS assertions)"
duration: "40"
verification_result: "pass"
completed_at: "2026-04-24T18:31:28Z"
---

T01 extends the conversus tool adapter with edition detection (oss|paid|unknown) using the single-venv-aware strategy mandated by the M026/P01 parity matrix. The resolver emits two new lines (edition= and reason=) on check stdout after the existing available=/conversus_path= lines, preserving line-order stability for parser contracts. Primary detection is CONVERSUS_EDITION=oss|paid (operator declaration). Fallback is pip show conversus against the resolved venv Python, parsing Home-page — a match on conversus-oss yields oss, any other non-empty Home-page yields paid, and probe failure yields unknown reason=metadata-probe-failed. Stub mode is edition-agnostic (unknown reason=stub). The user-local fallback order was extended to try ~/Sites/conversus-oss/ before ~/Sites/conversus/ to match OSS-primary project posture.\n\nVerification: scripts/verify/m026-p02-edition-detection-contract.sh (18 PASS assertions covering stub, env-override oss/paid, invalid-edition fallthrough with stderr warning, line ordering, and real-binary OSS metadata probe) exits 0; scripts/verify/m026-p02-adapter-invariants.sh (29 PASS assertions covering Bash 3.2 tokens, 0/1/2 exit-code contract, gate-result frontmatter key-set, D019 TODO pre-flight block, full env-var set including CONVERSUS_EDITION, filename-routed adapter invariant) exits 0; tests/test-conversus-adapter-shim.sh stub-path regression still passes (integration section gated by CONVERSUS_INTEGRATION=1 correctly skipped). Line delta on the adapter is +75, within the +80 budget.
