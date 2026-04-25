---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "M026/P03"
milestone: "M026"
provides:
  - "adapter preset-frontmatter parser (_read_preset_edition_required helper, awk-only Bash 3.2 compatible) and paid-only-on-OSS refusal diagnostic in conversus.sh gate subcommand body; test fixture preset (tests/fixtures/preset-edition-required-paid.yml) with edition_required: paid frontmatter; verifier scripts/verify/m026-p03-edition-required-diagnostic.sh exercising FR-11/SC-7 contract via three orthogonal cases"
requires:
  - "from:P02/T01 what:adapter check stdout edition= line (resolver contract from _resolve_binary/_resolve_edition); pre-existing tests/fixtures/gate-result-pass.md and gate-result-block.md (untouched stub-mode hermeticity); pre-existing templates/conversus-presets/normalize-fidelity.yml (Case C backward-compat baseline)"
affects:
  - "T02 (doc-surface coverage and ingest/specify command surfaces; T03/T04/T05 phase-suite gates roll up T01 verifier; downstream M026/P03 phase-summary author cites the FR-10/FR-11 contract; preset authors must add edition_required: paid to any future paid-binary-dependent presets"
key_files:
  - "scripts/dispatch/adapters/tool/conversus.sh (modified, +35 lines: header comment +7, _read_preset_edition_required helper +18, diagnostic block +20); tests/fixtures/preset-edition-required-paid.yml (created, 11 lines); scripts/verify/m026-p03-edition-required-diagnostic.sh (created, 56 lines)"
key_decisions:
  - "refuse only on edition=oss (explicit), proceed on edition=unknown (false-positive avoidance — no clear remediation path); FAIL: stderr prefix kept per adapter convention rather than FR-11 literal ERROR: (SC-7 case-insensitive regex matches body either way); diagnostic body rephrased to literal 'paid-only surface' wording so SC-7 regex paid-only.*CONVERSUS_EDITION=paid matches; placement after _bin_path guard but before _conv_tmp creation (no upstream work on refusal); awk-only frontmatter parser (no python, no yq) for Bash 3.2 + minimal-deps discipline"
patterns_established:
  - "frontmatter-keyed adapter behavior gating (preset declares contract, adapter enforces) reusable for future runtime-required-feature gating; awk frontmatter scanner pattern (fm++ on ---, exit on fm>=2) as POSIX-portable YAML-front-matter parse; refusal diagnostic shape (literal substring matched by case-insensitive regex) decouples human-prose from machine-verifiable contract"
drill_down_paths:
  - "scripts/dispatch/adapters/tool/conversus.sh:_read_preset_edition_required (new helper); scripts/dispatch/adapters/tool/conversus.sh:gate (diagnostic block after _bin_path guard); scripts/verify/m026-p03-edition-required-diagnostic.sh (6 PASS assertions, 3 cases A/B/C); tests/fixtures/preset-edition-required-paid.yml (fixture preset)"
duration: "25m"
verification_result: "pass"
completed_at: "2026-04-25T00:03:03Z"
---

T01 ships the FR-10 preset-edition_required parser plus the FR-11 paid-only-on-OSS refusal diagnostic in the conversus tool adapter. The new awk-only _read_preset_edition_required helper (defined before the case SUBCMD block) reads the top-level edition_required: key from a preset's YAML frontmatter, returning empty when absent (backward-compatible). The diagnostic block in the gate subcommand body fires after the _resolve_binary probe and _bin_path guard, but before any heavy side-effect (_conv_tmp creation, conversus run subprocess). When the preset declares edition_required: paid AND the resolved edition is exactly oss, the adapter emits a FAIL: line containing literal 'paid-only surface' and 'CONVERSUS_EDITION=paid' to stderr and exits 1. Stub mode is preserved as edition-agnostic per P02/T03 (the stub short-circuit at line ~269 fires before the diagnostic block). Refusal on edition=unknown is intentionally NOT triggered — the inline comment documents this as false-positive avoidance, since the operator already has a declarative escape hatch via CONVERSUS_EDITION=paid. Verification: scripts/verify/m026-p03-edition-required-diagnostic.sh exits 0 with pass=6 fail=0 across three cases (A: refuses paid-required+oss with SC-7 regex on stderr; B: stub-mode unaffected; C: backward-compat for presets without edition_required). All three M011/P07 invariant gates (m011-p07-conversus-adapter-shape.sh, m011-p07-gate-pass-block.sh, m011-p07-bash32-compat.sh) exit 0 with their pre-existing assertion counts (18/1/21 PASS), confirming CON-1..CON-5 invariants and AD-7 revise-in-place are preserved. Adapter delta: +35 lines, well within the +35 budget.
