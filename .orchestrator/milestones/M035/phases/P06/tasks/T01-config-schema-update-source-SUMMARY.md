---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P06"
milestone: "M035"
provides:
  - "update_source-config-schema (scripts/state/read-config.sh:17 VALID_KEYS append) + D012 decision (update_source: git|npm|homebrew|none enumeration + AD-5 detection default + FR-16 none opt-out) + task-grain verifier (m035-p06-config-schema-shape.sh BATTERY pass=7)"
requires:
  - "from:M027/P02-P03 what:VALID_KEYS-multi-key-co-location-append-pattern from:M035/P05-T01 what:D-row-heading-shape-continuity-D007-D011"
affects:
  - "P06/T02 (consumes registered key for run-update.sh dispatch + AD-5 detection + value-enumeration enforcement),P06/T03 (consumes registered key for JSONL update_source field emission),P06/T04 (consumes D012 + key for commands/update.md doc)"
key_files:
  - "scripts/state/read-config.sh,.orchestrator/DECISIONS.md,tools/verify/m035-p06-config-schema-shape.sh"
key_decisions:
  - "D012 (update_source config schema: git|npm|homebrew|none enumeration + AD-5 detection default + null-sentinel parity + none opt-out FR-16-compliant)"
patterns_established:
  - "schema-agnostic-VALID_KEYS-append,D-row-heading-shape-continuity-D007-D011-cohort,verifier-anchor-disambiguation-heading-or-table-row"
drill_down_paths:
  - ".orchestrator/milestones/M035/phases/P06/tasks/T01-config-schema-update-source-PLAN.md"
duration: "20m"
verification_result: "pass"
completed_at: "2026-05-09T23:21:37Z"
---

## What was built

T01 ships the `update_source` schema registration that lets every downstream P06 consumer (T02 dispatch, T03 JSONL emission, T04 doc) read the channel selector via the existing `read-config.sh` pipeline rather than ad-hoc-grepping `.orchestrator/config.yml`.

1. **`scripts/state/read-config.sh`** — single-line append at line 17: `update_source` joins the canonical `VALID_KEYS` space-separated string at end-of-list position (after `display_thresholds.compression_savings_pct`), per the M027 P02/P03 multi-key co-location pattern. No CLI-shape change. Value-enumeration enforcement (`git|npm|homebrew|none` set membership) stays out of `read-config.sh` and is T02's `run-update.sh` dispatch responsibility — `read-config.sh` is intentionally schema-agnostic on values; it only validates keys.

2. **D012 in `.orchestrator/DECISIONS.md`** — appended in the prevailing `### D### — title` heading-shape used by D007–D011 (the P03/P04/P05 cohort), with the Date / Phase / Status block + body + Rationale (4 numbered points) + Bound-to + Cross-references. Records the four-value enumeration, the AD-5 detection default, the `none` opt-out (FR-16 compliant — no new suppression knob), and the curl-pipe-bash → `npm` collapse (D007/D009 single-source-of-truth).

3. **`tools/verify/m035-p06-config-schema-shape.sh`** — single-script-file verifier (~140 lines, AD-19 / CON-2 bash 3.2 + POSIX-sh, no compound chains, no plain subshells, sources `scripts/lib/errors.sh`). Asserts 7 shape invariants: registration, VALID_KEYS whitespace-separated-token regex, D012 anchor (heading-shape OR table-row), D012 proximity to `update_source` (within 30 lines), and three fixture-driven reads (npm verbatim, invalid_value verbatim, absent → null/empty). Cleanup trap on `/tmp/m035-p06-t01-config-fixture-$$/`.

## Patterns established

- **Schema-agnostic VALID_KEYS append** — registering a new top-level scalar key is a single-line edit at `read-config.sh:17`. Value-enumeration enforcement lives in the consumer, not the reader. Mirrors the M027 P02/P03 precedent for `compression.*` and `model_routing_regression.*` (which DO have nested-block walkers because they're dotted), keeping the simple-scalar path unchanged.
- **D-row heading-shape continuity** — D012 follows D007–D011's `### D### — title` heading-shape rather than the older D001–D006 7-column table-row shape. Recent D-rows (P03/P04/P05) have all migrated; D012 maintains the streak. The verifier accepts both shapes (`### D012 ` heading OR `| D012 |` table-row) for robustness against future authors.
- **Verifier-anchor disambiguation** — the literal token `D012` may appear in body text of older D-rows (e.g. line 169's narrative reference). The proximity check in this verifier anchors on the heading-shape (`^### D012 ` or `| D012 |`) before applying the 30-line proximity check, avoiding false-positive matches on retrospective mentions.

## Verification

- `bash tools/verify/m035-p06-config-schema-shape.sh` → `BATTERY: pass=7 fail=0`
- All 7 PASS lines match the plan's Expected Output verbatim.

## Caveats

- The plan Step 3 enumeration listed 8 sub-assertions but the Expected Output shows 7 PASS lines. Resolved by collapsing "file readable" + "file contains update_source" into a single assertion (#1) — the readable + contains pair is logically the registration-presence check the Expected Output names. Final battery: 7 assertions, 7 PASS lines, matches Expected Output verbatim.
- `read-config.sh` accepts both positional-key `read-config.sh <key>` and `--key <name>` forms; the verifier uses positional + `--project <fixture-yml>` to mirror the canonical CLI shape used by sibling verifiers.
- Two unrelated unstaged files (`templates/phase-plan.md`, `.orchestrator/direct-mode-execution-log.jsonl`) were left untouched per the dispatch instructions — they are operator-owned WIP.

## Out-of-scope-found

- **T02 territory (`scripts/lifecycle/run-update.sh`)** — value-enumeration enforcement, AD-5 detection logic, and `none` opt-out dispatch all live in T02. T01 only registers the key in the schema layer.
- **T03 territory (JSONL emission)** — T01 makes `update_source` readable by T03's emitter but does not author the emission pathway.
- **T04 territory (`commands/update.md` doc)** — D012 cross-references `commands/update.md § Update sources`, but the doc itself is T04's responsibility.
