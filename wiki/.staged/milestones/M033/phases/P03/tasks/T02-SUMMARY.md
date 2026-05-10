---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "M033/P03"
milestone: "M033"
provides:
  - "commands/constitution.md (FR-3 documented surface),scripts/lifecycle/constitution-author.sh (FR-3 driver implementing 5-8-question grilling-protocol flow + lint gate + write + marker + JSONL event + dual-write fragment),tools/verify/m033-p03-constitution-md-shape.sh (T02 shape verifier 13 PASS),tools/verify/m033-p03-constitution-author-sh-shape.sh (T02 shape + standalone-gate dogfood verifier 26 PASS)"
requires:
  - "from:P03/T01 what:templates/constitution-starters/web-saas+cli-tool+library starters and constitution-shape-lint.sh and standalone-gate.sh; from:P02/T01 what:scripts/util/jsonl-event-emitter.sh; from:P02/T02 what:scripts/util/start-state-markers.sh; from:P02/T03+T04 what:scripts/lifecycle/grilling-shell.sh; from:M014 what:scripts/util/dual-write-runtime-md.sh"
affects:
  - "T03,T04,T05"
key_files:
  - "commands/constitution.md,scripts/lifecycle/constitution-author.sh,tools/verify/m033-p03-constitution-md-shape.sh,tools/verify/m033-p03-constitution-author-sh-shape.sh"
key_decisions:
  - "capture-resolved-answers-via-accumulator-rather-than-stdout-capture-because-stdout-capture-would-hide-ask_one-prompts-from-operator;use-actual-helper-flag-API-(--marker-recent-changes-+---append-entry)-rather-than-the-shorthand-(append-fragment)-the-FR-21-SSOT-text-suggests-because-the-helper-does-not-implement-an-append-subcommand;stack-specific-questions-do-not-substitute-placeholders-(closed-vocab-stays-at-3)-but-flow-to-the-accumulator-+-glossary-writer-so-MIT-007-+-FR-18-still-fire"
patterns_established:
  - "ask_one-uncaptured-stdout-+-accumulator-readback-pattern-for-resolved-answer-extraction;parallel-indexed-arrays-(placeholders+answers+u_qkeys+u_questions+u_recommendations)-for-bash-3.2-MEM001-compatibility;sed-i.bak-with-pre-escaped-value-for-POSIX-portable-placeholder-substitution-with-operator-supplied-content;rc-zero-then-cmd-or-rc-dollar-question-pattern-for-allowing-set-e-coexistence-with-explicit-rc-checks"
drill_down_paths:
  - ".orchestrator/milestones/M033/phases/P03/tasks/T02-constitution-author-PLAN.md"
duration: "50m"
verification_result: "pass"
completed_at: "2026-05-04T11:52:18Z"
---

T02 ships the FR-3 orchestrator-native constitution-authoring path. commands/constitution.md (MEM012 shape) documents the surface; scripts/lifecycle/constitution-author.sh implements it: argument parsing (--stack closed enum web-saas|cli-tool|library, --project-dir, --force, --yes), starter load from T01, sequential ask_one grilling-protocol flow (3 universal placeholders project_type/primary_constraint/target_user + 2-3 stack-specific follow-ups for 5-8 total questions per FR-3), placeholder substitution via sed -i.bak (Bash 3.2 parallel indexed arrays), $EDITOR hand-off (--yes / EDITOR=cat bypass), FR-5 lint gate (no partial write on lint fail per US-2 AS-5), write to project-dir/.orchestrator/memory/constitution.md, FR-20 start-state marker, FR-22 constitution_authored JSONL event with stack+force fields, FR-21 dual-write recent-changes fragment via the actual helper flag API. Idempotency: re-run without --force = byte-identical preservation + no-changes diagnostic + no-changes JSONL event (US-2 AS-2). --force = WARN to stderr + regenerate (US-2 AS-3). Unknown --stack = exit non-zero with v1 list + Q-2 expansion-path pointer (US-2 AS-4). Two T02 verifiers: m033-p03-constitution-md-shape.sh (13/13 PASS) and m033-p03-constitution-author-sh-shape.sh (26/26 PASS) including standalone-gate dogfood. End-to-end functional smoke (11/11 PASS) confirms driver runs, writes constitution, lint passes, marker + JSONL event emitted, idempotent re-run, byte-identical preservation, unknown-stack rejection. standalone-gate.sh constitution now reports pass=7 skip=0 fail=0 (T01s 5-PASS-2-SKIP collapses to 7-PASS-0-SKIP per T05/SC-2 expectation). Two minor deviations from PLAN: (1) the driver does not capture ask_one stdout (capture would hide prompts from the operator) - instead reads the resolved answer from the accumulator file; (2) the dual-write helper does not implement an append subcommand so the driver uses --marker recent-changes + --append-entry which is the helpers actual API. Both deviations preserve every load-bearing token the verifiers grep for.
