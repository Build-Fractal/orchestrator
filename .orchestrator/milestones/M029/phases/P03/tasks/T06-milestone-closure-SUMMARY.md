---
schema_version: "1.0"
type: task-summary
id: "T06"
parent: "P03"
milestone: "M029"
provides:
  - "SC-11 milestone-grain run-acceptance-battery.sh chaining all three per-phase batteries + SC-11 self + SC-12 validator hook + emitting BATTERY: pass=14 fail=0; SC-12 m029-p03-validate-milestone-pass.sh hook asserting validate-milestone.sh M029 VALIDATE: PASS exit 0; m029-p03-run-acceptance-battery-shape.sh shape verifier; m029-p03-closure-ceremony-shape.sh asserts four closure-ceremony artifacts; M029-VALIDATED empty marker file per M032 precedent; M029-SUMMARY.md canonical 16-field milestone-summary frontmatter + body via write-summary.sh milestone with --body-file flag; milestone-grain unit_close JSONL record auto-emitted by write-summary.sh milestone (record_type:unit_close + granularity:milestone + unitId:M029 per M019 emitter convention NOT plan-stated event:unit_close); P01-SUMMARY.md key_files in-flight repair (trailing slash on two fixture-directory references status-json-executing.fixture/ + status-json-degraded.fixture/ per validate-milestone.sh path-shape convention); CLAUDE.md update marking M029 closed + Next up shifted to M035 P00+P01"
requires:
  - "P02,P03/T01,P03/T02,P03/T03,P03/T04,P03/T05"
affects:
  - "none (terminal task in M029)"
key_files:
  - "tests/m029-acceptance/run-acceptance-battery.sh,tools/verify/m029-p03-run-acceptance-battery-shape.sh,tools/verify/m029-p03-validate-milestone-pass.sh,tools/verify/m029-p03-closure-ceremony-shape.sh,.orchestrator/milestones/M029/M029-VALIDATED,.orchestrator/milestones/M029/M029-SUMMARY.md,.orchestrator/milestones/M029/phases/P03/P03-SUMMARY.md,.orchestrator/milestones/M029/phases/P01/P01-SUMMARY.md,.orchestrator/milestones/M029/execution-log.jsonl,CLAUDE.md"
key_decisions:
  - "closure-ceremony shape verifier asserts on emitter shape not plan-stated schema (record_type:unit_close per write-summary.sh actual; verifier-contract-over-verifier-skeleton from M032 extended); in-flight repair for P01-SUMMARY directory-vs-file path-shape (M032 lineage extended); milestone-grain run-acceptance-battery.sh chains per-phase batteries + SC-11 self + SC-12 validator hook with mid-author WARN: skip branch idempotent on re-run; AD-19 straight-line bash for all four T06 verifiers + battery; MEM001 Bash 3.2 (parallel scalars + case + printf, no herestring, no compound chains); CON-1/FR-14 read-only with documented closure-ceremony write sites (M029-VALIDATED + M029-SUMMARY.md + execution-log.jsonl unit_close append per the M032/M033 precedent); body-file pattern for long bodies (avoids inline-body curly-brace AP-007 risk); empty M029-VALIDATED marker file per M032 precedent"
patterns_established:
  - "milestone-grain run-acceptance-battery.sh shape; closure-ceremony shape verifier asserts on emitter shape not plan-stated schema (verifier-contract-over-verifier-skeleton from M032 extended); in-flight repair for P01-SUMMARY directory-vs-file path-shape (M032 lineage extended); body-file pattern for write-summary.sh with long bodies; empty M029-VALIDATED marker file per M032 precedent"
drill_down_paths:
  - "N/A (T06 is terminal)"
duration: "90m"
verification_result: "pass"
completed_at: "2026-05-06T05:12:36Z"
---

T06 ships the M029 milestone closure ceremony — the SC-11/SC-12 surfaces (milestone-grain acceptance battery + validate-milestone hook) plus the four closure-ceremony artifacts (M029-VALIDATED marker, M029-SUMMARY.md, milestone-grain unit_close JSONL record, closure-ceremony shape verifier).

**Deliverables shipped:**

1. **`tests/m029-acceptance/run-acceptance-battery.sh`** (SC-11) — milestone-grain battery chaining the three per-phase batteries (P01: SC-1..SC-4; P02: SC-5/6/13/14; P03: SC-7/8/9/10) + SC-11 self + SC-12 validator hook. Emits `BATTERY: pass=14 fail=0` on full pass. AD-19 straight-line bash, MEM001 Bash 3.2 (parallel scalars, `case`, `printf`), no `<<<` herestring, no compound chains.

2. **`tools/verify/m029-p03-run-acceptance-battery-shape.sh`** — shape verifier asserting per-phase battery references + SC-12 validator-hook reference + `BATTERY: pass=` literal + `Total: 14` SC-accounting comment + behavioural exit 0 with `BATTERY: pass=14 fail=0` emitted. 9 assertions, all PASS.

3. **`tools/verify/m029-p03-validate-milestone-pass.sh`** (SC-12) — invokes `bash scripts/verify/validate-milestone.sh` on `.orchestrator/milestones/M029` and asserts: validator + milestone dir present, exit 0, `VALIDATE: PASS` line present, `checks passed` token present, P03 referenced, no `VALIDATE: FAIL` lines. 7 assertions, all PASS.

4. **`tools/verify/m029-p03-closure-ceremony-shape.sh`** — asserts the four closure-ceremony artifacts: M029-VALIDATED marker present, M029-SUMMARY.md present with canonical 16-field frontmatter (`type: milestone-summary` + `verification_result: "pass"` + `completed_at:` + `id: "M029"`), execution-log.jsonl carries milestone-grain unit_close (`record_type:"unit_close"` + `granularity:"milestone"` + `M029` substring per the M019 emitter convention — NOT the plan-stated `event:"unit_close"`), and the SC-12 verifier exits 0. 10 assertions, all PASS.

5. **`.orchestrator/milestones/M029/M029-VALIDATED`** — empty marker file per M032 precedent.

6. **`.orchestrator/milestones/M029/M029-SUMMARY.md`** — canonical 16-field milestone-summary frontmatter (`schema_version`, `type: milestone-summary`, `id: "M029"`, `parent: "037-roadmap-visibility-cli-ux"`, `milestone: "M029"`, `provides`, `requires`, `affects`, `key_files`, `key_decisions`, `patterns_established`, `drill_down_paths`, `duration: "525m"`, `verification_result: "pass"`, `completed_at: 2026-05-06T05:05:50Z`, `observability_surfaces`) + body covering Phase Rollup, Cross-Phase Inheritance Patterns, Verification at Close, What Was Deferred (FR-11/FR-12 cut), Key Decisions, Patterns Established, Post-Close Handoff (M035 P00+P01 next), Acceptance Evidence. Authored via `scripts/knowledge/write-summary.sh milestone --body-file=...` (avoids inline-body curly-brace AP-007 risk).

7. **Milestone-grain `unit_close` JSONL record** appended to `.orchestrator/milestones/M029/execution-log.jsonl` — auto-emitted by `write-summary.sh milestone` per the M019 emitter convention. Shape: `{"record_type":"unit_close","granularity":"milestone","unitId":"M029","milestone":"M029","phase":"","task":"","duration_s":31500,"outcome":"pass","completed_at":"2026-05-06T05:05:50Z",...}` — note `record_type` not the plan-stated `event` field.

**In-flight repair:**

- **P01-SUMMARY.md `key_files` directory references** — `validate-milestone.sh` treats `key_files` paths without trailing `/` as files; two P01 fixture-directory references (`status-json-executing.fixture`, `status-json-degraded.fixture`) lacked the trailing slash and registered as missing files. Repaired by appending `/` to both paths. Mirrors M032's in-flight-repair convention (sibling-phase verifier-contract drift repaired in the closure task that surfaces it). Without this repair, `validate-milestone.sh M029` reported 63/66 with three failures; after repair, 101/101 PASS.

- **`unit_close` emitter shape — verifier-contract-over-verifier-skeleton** — Plan stated the JSONL record uses `event:"unit_close"`; the actual `write-summary.sh` emitter uses `record_type:"unit_close"` with `granularity:"milestone"`. Closure verifier asserts on the actual emitter shape (M032 lineage extended).

**Verification:**

- `bash tests/m029-acceptance/run-acceptance-battery.sh` → `BATTERY: pass=14 fail=0` exit 0.
- `bash tools/verify/m029-p03-validate-milestone-pass.sh` → `pass=7 fail=0` exit 0.
- `bash tools/verify/m029-p03-run-acceptance-battery-shape.sh` → `pass=9 fail=0` exit 0.
- `bash tools/verify/m029-p03-closure-ceremony-shape.sh` → `pass=10 fail=0` exit 0.
- `bash scripts/verify/validate-milestone.sh .orchestrator/milestones/M029` → `VALIDATE: PASS — 101/101 checks passed` exit 0.

**Patterns established:**

- **Milestone-grain run-acceptance-battery.sh** chains per-phase batteries + SC-11 self + SC-12 validator hook + emits `BATTERY: pass=N fail=M` canonical line. Mid-author WARN: skip branch handles bootstrapping when SC-12 verifier not yet on disk; once T06 lands the verifier the branch never fires (idempotent on re-run).

- **Closure-ceremony shape verifier asserts on emitter shape, not plan-stated schema** — when plan-stated and on-disk shapes differ, the verifier asserts on the actual emitter shape. Verifier-contract-over-verifier-skeleton from M032 extended.

- **In-flight repair for P01-SUMMARY directory-vs-file path-shape** — M032 in-flight-repair convention extended: sibling-phase verifier-contract drift repaired in the closure task that surfaces it.

**Forward-roadmap update applied:**

- CLAUDE.md Project Status: M029 added to Closed list with closure date 2026-05-06 + 101/101 PASS + `BATTERY: pass=14 fail=0` evidence. "Next up" shifted from M029 to M035 P00+P01 → M035 P02–P06.
- CLAUDE.md Forward Roadmap header: `M029 → M035 P02–P06` → `M035 P00+P01 → M035 P02–P06`. M029 closed annotation added.
- Operator note: M036b deferred-state escape hatch updated from `orchestrator:auto milestone=M029` to `orchestrator:auto milestone=M035`.
- M029 brief summary entry: prose changed from "to-do" pre-close shape to closed-milestone strike-through with shipped-surfaces summary.
