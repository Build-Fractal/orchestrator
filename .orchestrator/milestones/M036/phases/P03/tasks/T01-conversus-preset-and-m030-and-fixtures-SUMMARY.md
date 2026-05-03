---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P03"
milestone: "M036"
provides:
  - "templates/conversus-presets/tier-2-fidelity.yml (~50-line conversus preset declaring extractor-advocate + fidelity-advocate cooperative agents and a constitution-grounded arbiter with verdict_contract PASS|BLOCK and a gate-result.md output template; structural template re-uses normalize-fidelity.yml shape from M011/P07); templates/model-routing.yml additive task_type: block (extraction: claude-code: smart; codex-cli + cursor inherit; CON-3 closure preserved — symbolic tier names only, no new hardcoded model IDs); tests/fixtures/m036-p03-tier-2/sample.md (synthetic PBJ-staffing markdown source); tests/fixtures/m036-p03-tier-2/extract-manifest.yaml (single-doc manifest cite_id tier2-fixture-01 at tier 2 + summary_mode auto); 3 single-script-file shape verifiers (m036-p03-conversus-preset-shape.sh, m036-p03-m030-task-type-extraction.sh, m036-p03-fixture-corpus-shape.sh) each with set -eu strict + grep -qF -e flag-safety + structured PASS:/FAIL:/SUMMARY: stdout"
requires:
  - "P02 closed (P02-SUMMARY.md on disk); templates/conversus-presets/normalize-fidelity.yml (structural template); templates/model-routing.yml (M030 SSOT, closed 2026-05-01); scripts/dispatch/adapters/tool/conversus.sh (preset-name resolution contract from M011/P07)"
affects:
  - "P03/T02 (Tier 2 LLM helper consumes the new task_type.extraction routing row and the fixture manifest); P03/T03 (gate helper consumes the tier-2-fidelity preset by name; driver auto-branch consumes the fixture corpus); P03/T04 (acceptance harness consumes the fixture manifest + corpus)"
key_files:
  - "templates/conversus-presets/tier-2-fidelity.yml, templates/model-routing.yml, tests/fixtures/m036-p03-tier-2/sample.md, tests/fixtures/m036-p03-tier-2/extract-manifest.yaml, tools/verify/m036-p03-conversus-preset-shape.sh, tools/verify/m036-p03-m030-task-type-extraction.sh, tools/verify/m036-p03-fixture-corpus-shape.sh"
key_decisions:
  - "none"
patterns_established:
  - "P03 inherits the M036 verifier conventions intact: milestone-prefixed slug (m036-p03-*), AD-19 single-script-file shape, grep -qF -e token-loop body for leading-dash safety, structured PASS:/FAIL:/SUMMARY: stdout, set -eu strict, ROOT resolution via ${ORCHESTRATOR_ROOT:-$(pwd)}; conversus-preset reuse pattern (the new tier-2-fidelity.yml structurally mirrors normalize-fidelity.yml — same top-level shape preset_name+description+agents+arbiter+output, same arbiter contract grounding_file+verdict_contract+description, same output required_fields list — so M011/P07's gate adapter resolves it without code changes); additive amendment to M030 SSOT (task_type: block appended after cost_rates: with explicit FR-19 + CON-3 callouts in YAML comments; pre-existing routing/resolution/cost_rates sections byte-identical pre/post); CON-3 spot-check verifier pattern (count hardcoded model IDs via grep -cE 'claude-(haiku|sonnet|opus)-4-' and assert preserved-baseline; for templates that name model IDs in documentation comments AS WELL as in resolution: blocks the baseline includes both groups — the invariant is 'no NEW hardcoded model ID added outside resolution:', not 'count exactly 3'); fixture-corpus minimalism for LLM-mocked paths (single markdown source + minimal manifest; no binaries because the LLM shim is mocked via EXTRACT_TIER_2_DISPATCH in T02 — inverts P02's fixture-binary-reuse pattern for the Tier 2 path)"
drill_down_paths:
  - ".orchestrator/milestones/M036/phases/P03/tasks/T01-conversus-preset-and-m030-and-fixtures-PAYLOAD.md"
duration: "20m"
verification_result: "pass"
completed_at: "2026-05-02T15:37:33Z"
---

T01 lands the M036 P03 declarative substrate: the tier-2-fidelity conversus preset, the additive `task_type:` row in the M030 routing SSOT, the P03 Tier 2 fixture corpus (one markdown source + manifest declaring `tier: 2` + `summary_mode: "auto"`), and three single-script-file shape verifiers gating each artifact.

**What was built**:

- `templates/conversus-presets/tier-2-fidelity.yml` — new conversus preset (~50 lines). Declares two cooperative agents: `extractor-advocate` (charter: structural preservation — heading hierarchy, table structure, figure captions, footnotes, citation markers) and `fidelity-advocate` (charter: content fidelity — no paraphrase, summarisation, or invention; defends Spec NG-5-NEW). Constitution-grounded arbiter (`grounding_file: .orchestrator/memory/constitution.md`) emits `verdict_contract: PASS|BLOCK` with ties resolving in favour of preservation. Output template + required-fields list (`verdict, disputes, rationale, source_hash`) match the project's existing `gate-result.md` shape used by M011/P07's normalize-fidelity preset.

- `templates/model-routing.yml` — additive `task_type:` block appended after the existing `cost_rates:` section. Declares `task_type.extraction.claude-code: smart` (citation-grade fidelity per CC default) plus `codex-cli: inherit` and `cursor: inherit` per the launch-posture inherit-fallback rule. CON-3 closure preserved: NO new hardcoded model IDs added — the `task_type:` rows are symbolic (`smart` / `inherit`), and the only places where concrete model IDs (`claude-haiku-4-5`, `claude-sonnet-4-7`, `claude-opus-4-7`) appear remain the existing `resolution:` block (3 occurrences) plus the documentation comment block above it (3 occurrences). Pre-existing content is byte-identical.

- `tests/fixtures/m036-p03-tier-2/sample.md` — synthetic PBJ-staffing markdown source with two `## Section` headings + bulleted definitions list. Markdown chosen for CON-3 (deterministic CI; no PDF/DOCX in P03 — Tier 2 LLM extraction is exercised against the markdown source via a stub-dispatch shim landed in T02).

- `tests/fixtures/m036-p03-tier-2/extract-manifest.yaml` — single-document manifest at `cite_id: tier2-fixture-01`, `category: glossary`, `tier: 2`, `summary_mode: "auto"`. Per-doc fields cover the full chunk-frontmatter contract (`source`, `published`, `version`, `topic_tags`, `applies_to_field`).

- Three shape verifiers under `tools/verify/m036-p03-*`:
  - `m036-p03-conversus-preset-shape.sh` (6 checks): preset existence + 5 token-presence (`preset_name: tier-2-fidelity`, `extractor-advocate`, `fidelity-advocate`, `verdict_contract: PASS|BLOCK`, `grounding_file: .orchestrator/memory/constitution.md`).
  - `m036-p03-m030-task-type-extraction.sh` (5 checks): 4 token-presence (`task_type:`, `extraction:`, `claude-code: smart`, `FR-19`) plus a CON-3 spot-check counting hardcoded model IDs and asserting the count is preserved at the pre-T01 baseline of 6.
  - `m036-p03-fixture-corpus-shape.sh` (5 checks): `sample.md` + `extract-manifest.yaml` existence + 3 manifest-token checks (`tier: 2`, `summary_mode: "auto"`, `cite_id: "tier2-fixture-01"`).

**Mid-task correction**:

- The CON-3 closure spot-check in `m036-p03-m030-task-type-extraction.sh` was authored from the task plan's stated baseline of 3 hardcoded model IDs but the actual pre-T01 baseline (verified against `git show HEAD:templates/model-routing.yml`) is 6 — the regex `claude-(haiku|sonnet|opus)-4-` matches both the 3 occurrences inside the `resolution:` block AND the 3 occurrences inside the documentation comment block (lines 56–58) that names them by reference. The CON-3 invariant ("T01 must NOT add a NEW hardcoded model ID outside `resolution:`") is preserved unchanged; only the literal expected-count constant in the verifier was corrected from 3 to 6 with an explanatory comment naming both contributing groups. The task plan's intent (additive-only amendment, no fourth concrete model ID anywhere) survives byte-identically; only the verifier's literal count constant was rebased to the true baseline. Classification: descriptive defect in the task plan, not a correctness issue.

**Verification**:

- `m036-p03-conversus-preset-shape.sh` exits 0 with `SUMMARY: ... fail=0` (6 PASS lines).
- `m036-p03-m030-task-type-extraction.sh` exits 0 with `SUMMARY: ... fail=0` (5 PASS lines including the corrected CON-3 spot-check).
- `m036-p03-fixture-corpus-shape.sh` exits 0 with `SUMMARY: ... fail=0` (5 PASS lines).

All three T01 truth-checks PASS. No upstream-touch (P02 closed artifacts byte-identical; M030 closure invariants intact — the `routing:` and `resolution:` and `cost_rates:` sections are byte-identical pre/post).

**Forward notes**:

- T02 consumes the new conversus preset (passed by name through `gate <preset> <artifact> <output>`), the `task_type.extraction` routing row (resolved by M030's `select-model.sh` adapter), and the fixture manifest. T02 lands `scripts/knowledge/lib/extract-tier-2-llm.sh` (pure helpers `extract_tier_2_dispatch` mockable via `EXTRACT_TIER_2_DISPATCH=stub:<canned-file>` + `extract_tier_2_emit_unit_close` writing one well-formed JSONL `unit_close` record per Tier 2 invocation).
- T03 lands the gate helper (`scripts/knowledge/lib/extract-tier-2-gate.sh`) plus the auto-branch wiring inside `scripts/knowledge/extract-reference.sh` that replaces the P02 hard-error seam (`generate_tier_0_summary auto ...` for `tier=2` returns sentinel; driver dispatches Tier 2 + gate; promote on PASS, retain block on BLOCK).
- T04 lands the acceptance harness `tests/test-tier-2-extraction-with-gate.sh` (drives PASS + BLOCK paths via `CONVERSUS_STUB=1`) plus the two `canned-structured*.md` fixtures and the phase-suite aggregator. The cross-task ordering note in the phase plan documents that the T03 verifiers `m036-p03-tier-2-pass-end-to-end.sh` and `m036-p03-tier-2-block-retention.sh` (which reference the canned fixtures) become green retroactively under the auto-loop's first-fail-retry once T04 lands.
- The fixture-corpus pattern (single markdown source + minimal manifest) intentionally inherits from M036 P02's fixture-binary reuse principle but inverts to "no binaries at all" because Tier 2 doesn't need a host-tool extractor — the LLM-call shim is mocked via `EXTRACT_TIER_2_DISPATCH` in T02.
