---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P03"
milestone: "M020"
provides:
  - "scripts/verify/knowledge-schema-lint.sh — FR-9 + SC-8 schema-authority enforcement gate covering three failure shapes (unauthorized-field, vocabulary-drift, malformed-frontmatter); embeds the M020-authorized field allowlist as canonical machine-readable encoding of D024 + MEM031; per-task contract verifiers scripts/verify/m020-p03-schema-lint-contract.sh and scripts/verify/m020-p03-schema-lint-vocabulary-drift.sh exercising the lint against tempdir fixtures and the live tree"
requires:
  - "from:M020/P01 what:knowledge/conventions/MEM031.md (closed-enum vocabulary), .orchestrator/DECISIONS.md D024 (status: field authorization)"
affects:
  - "M020/P03 phase-level verification, future schema-evolution handshakes (D-row → MEM031 → lint allowlist)"
key_files:
  - "scripts/verify/knowledge-schema-lint.sh,scripts/verify/m020-p03-schema-lint-contract.sh,scripts/verify/m020-p03-schema-lint-vocabulary-drift.sh"
key_decisions:
  - "none-new"
patterns_established:
  - "closed-enum lint pattern (structural-only, read-only, fixture-tested via tempdir + heredoc, single-script Check shape); authorized-field allowlist as newline-separated heredoc-fed string for bash 3.2 iteration without associative arrays; tempdir + trap-EXIT-rm-rf for negative-test fixtures so the live knowledge/ tree is never touched by verifiers; process-substitution-inside-script-body is AD-19-safe because the harness shape-guard inspects Bash tool-call shapes not script internals"
drill_down_paths:
  - ".orchestrator/milestones/M020/phases/P03/tasks/T03-schema-authority-lint-PAYLOAD.md"
duration: "20m"
verification_result: "pass"
completed_at: "2026-04-25T14:37:50Z"
---

## What was built

Three files created under `scripts/verify/`:

1. **`scripts/verify/knowledge-schema-lint.sh`** — the FR-9 + SC-8 schema-authority enforcement gate. Walks `<root>/knowledge/**/MEM*.md` (excluding `archive/`) and emits one of three structured FAIL diagnostics on violations:
   - `unauthorized-field file=<path> field=<name>` for any frontmatter key outside the M020-authorized allowlist.
   - `vocabulary-drift file=<path> field=status value=<value> allowed={candidate,graduated,archived}` for any `status:` value outside the MEM031 closed enum.
   - `malformed-frontmatter file=<path> reason=<missing-leading-delimiter|missing-closing-delimiter>` for missing leading or trailing `---` block.
   On a clean tree it exits 0 with `PASS: scanned <N> entries; 0 violations`.
2. **`scripts/verify/m020-p03-schema-lint-contract.sh`** — asserts the lint exits 0 against the live tree AND exits non-zero with `unauthorized-field` against a fixture introducing an out-of-allowlist key.
3. **`scripts/verify/m020-p03-schema-lint-vocabulary-drift.sh`** — asserts the lint rejects `status: deprecated` with the `vocabulary-drift` diagnostic AND accepts every canonical enum value (`candidate`, `graduated`, `archived`) without false positives.

The lint embeds the M020-authorized field allowlist directly (the source of truth that must move in lockstep with [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) D-rows and [`knowledge/conventions/MEM031.md`](../../../../../knowledge/conventions/MEM031.md)). Authorized fields: `id, scope_tags, category, confidence, created_at, last_verified, hit_count, source_unit, source_type, supersedes, superseded_by, relates_to, content_hash, status, decision_history, archived_into, topic, tags`.

## Key decisions

- **Allowlist embedded in the lint script, not externalized to YAML or MEM031**. Per the payload's rationale: the schema-extension handshake is D-row → MEM031 → lint allowlist. Externalizing the list would invite drift between MEM031 prose and the enforced contract; embedding keeps the lint as the canonical machine-readable encoding.
- **`topic` and `tags` codified in the authorized set** even though they predate M020 — FR-2 / P02 query semantics already use them, so they MUST pass the lint or the live tree would false-positive. Verified by running the lint against the 31 live entries (PASS).
- **Process substitution `< <(find ...)` lives inside the script body, not on Check lines**. AD-19 / MEM031 / AP-009 govern Bash *tool-call* shapes, not script internals. The three Verification commands in the task plan are all single `bash <script>` invocations, satisfying the harness shape-guard.

## Patterns established

- Closed-enum lint pattern: structural-only, read-only, fixture-tested via tempdir + heredoc, single-script Check shape. Reusable for future schema-evolution gates (e.g. `category:` or `confidence:` if they ever close their enums).
- Negative-test fixtures live in `mktemp -d` tempdirs with a `trap 'rm -rf' EXIT` cleanup — the live `knowledge/` tree is never touched by verifiers.
- Authorized-field allowlist as a newline-separated heredoc-fed string (bash 3.2 — no associative arrays); iteration via `while IFS= read -r authorized; do ... done <<EOF $AUTHORIZED_FIELDS EOF`.

## Verification results

All three Verification commands from the task plan pass:

- `bash scripts/verify/m020-p03-schema-lint-contract.sh` → `PASS: schema-lint accepts live tree + rejects unauthorized field`
- `bash scripts/verify/m020-p03-schema-lint-vocabulary-drift.sh` → `PASS: schema-lint rejects vocabulary drift, accepts every valid enum value`
- `bash scripts/verify/knowledge-schema-lint.sh` → `PASS: scanned 31 entries; 0 violations`

Additionally verified out-of-band (not in the plan's Verification block but listed as a Must-Have):

- Malformed-frontmatter detection: tested both `missing-leading-delimiter` and `missing-closing-delimiter` cases via tempdir fixture — both return exit 1 with the expected diagnostic shape.

## Plan deviations

- None. The lint script and the two verifiers were transcribed from the payload exactly. The malformed-frontmatter case isn't included in the canonical Verification block of the plan but was exercised out-of-band to satisfy the corresponding Must-Have.

## Downstream impact

- **P03 phase verification** consumes all three scripts — the contract and vocabulary-drift verifiers are per-task gates; the lint itself is the phase-level live-tree gate.
- **Future schema evolutions** must update three locations in lockstep: [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) (new D-row), [`knowledge/conventions/MEM031.md`](../../../../../knowledge/conventions/MEM031.md) (vocabulary append), and `scripts/verify/knowledge-schema-lint.sh` (allowlist append). The lint is the executable enforcement of the prose contract.
- **`git status knowledge/` is non-empty** at task close, but every modification predates T03 — they are `hit_count` updates from prior P03 task dispatches (visible at the bottom of the dispatch payload). T03 itself touched zero files under `knowledge/**`.
