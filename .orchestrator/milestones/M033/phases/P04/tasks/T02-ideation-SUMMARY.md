---
schema_version: "1.0"
type: task-summary
id: "T02-ideation"
parent: "P04"
milestone: "M033"
provides:
  - "commands/ideation.md (FR-10 doc surface) + scripts/lifecycle/ideation.sh (FR-10 driver: 7-question grilling-protocol flow + CON-6 resume + MIT-007 third-arg wiring on every ask_one + opt-in --with-conversus-stress-test default OFF per #Q-7) + tools/verify/m033-p04-ideation-md-shape.sh (19 PASS) + tools/verify/m033-p04-ideation-sh-shape.sh (29 PASS, MIT-007 token-count assertion load-bearing)"
requires:
  - "from:M033/P02/T03+T04 what:scripts/lifecycle/grilling-shell.sh ask_one + closed _GRILLING_CONTRADICTION_PAIRS SSOT; from:M033/P02/T01 what:scripts/util/jsonl-event-emitter.sh emit ideation_completed; from:M033/P02/T02 what:scripts/util/start-state-markers.sh write ideation; from:M033/P02/T05 what:references/m033-fr21-dual-write-convention.md FR-21 SSOT; from:M014 what:scripts/util/dual-write-runtime-md.sh --root --marker --append-entry; from:M011/P07 what:scripts/dispatch/adapters/tool/conversus.sh stress-test (opt-in)"
affects:
  - "P04"
key_files:
  - "commands/ideation.md,scripts/lifecycle/ideation.sh,tools/verify/m033-p04-ideation-md-shape.sh,tools/verify/m033-p04-ideation-sh-shape.sh"
key_decisions:
  - "MIT-007-wiring-via-ideate_one-helper-passing-PARTIAL_ANSWERS-as-third-arg-on-every-ask_one-call;CON-6-resume-via-in-flight-scan-of-intake-dir-for-partial-answers-yml-with-fewer-than-7-keys-before-honoring-M033_IDEATION_TIMESTAMP-env-override;recommendations-are-placeholder-operator-supplied-because-ideation-has-no-domain-specific-default;negative-grep-skip-comment-lines-via-grep-Ev-leading-hash-so-doc-text-mentioning-declare-A-or-process-substitution-doesnt-trip-the-MEM001-negative-assertions;Q-7-stress-test-flag-gated-by-fixed-string-shape-WITH_STRESS_TEST-eq-1-rather-than-regex-which-needed-escaping"
patterns_established:
  - "ideate_one helper as MIT-007 third-arg wiring proof-point: every ask_one invocation in driver routes through one function that always supplies the partial-answers.yml path; verifier asserts via token-count grep on ask_one calls (≥4 whitespace-tokens proves function-name + 3 args);CON-6 in-flight resume scan: ls intake-dir then count keys per partial-answers.yml takes precedence over M033_IDEATION_TIMESTAMP env override which itself takes precedence over fresh date -u timestamp;case-statement-per-index for parallel indexed array dereference (bash 3.2 — no nameref ${!var} game);sourceability-of-grilling-shell with ideate_one wrapper to set _GRILLING_CURRENT_QKEY before each ask_one (matches constitution-author.sh pattern);negative-grep-skips-comment-lines via grep -Ev leading-hash so doc-prose negative assertions aren't tripped by self-reference"
drill_down_paths:
  - ".orchestrator/milestones/M033/phases/P04/tasks/T02-ideation-PAYLOAD.md"
duration: "45m"
verification_result: "pass"
completed_at: "2026-05-04T14:18:09Z"
---

T02 ships the FR-10 ideation surface — orchestrator:ideation command-doc + the FR-10 driver running a 7-question grilling-protocol-shaped flow consuming P02's ask_one API, persisting partial answers to partial-answers.yml after each question per CON-6, passing the partial-answers file as the third arg on every ask_one invocation per MIT-007, and emitting an ideation-pre-spec.md with 7 H2 sections in execution order. Closed 7-question key set: problem-statement, target-user, mvp-boundary, top-user-stories, success-metric, top-risks, top-non-goals. Optional --with-conversus-stress-test (default OFF per #Q-7) appends an Adversarial Findings section when the conversus adapter is available; missing-binary path is non-fatal (stderr diagnostic only). FR-20 marker write (ideation.complete), FR-22 JSONL event emit (ideation_completed), FR-21 dual-write fragment (recent-changes marker). Functional smoke confirmed end-to-end (7 H2 sections written, marker created, JSONL line emitted with correct event_type and payload). Resume smoke confirmed: pre-seeded partial with 3 answered keys → 3 skip lines emitted, 4 remaining qkeys asked. Both shape verifiers green: md=19/0, sh=29/0. check-plans.sh advisory only (status=warn heuristic_risk=146 — pre-existing baseline, no T02 contribution since the new plan files use single-script invocation shape per AD-19).
