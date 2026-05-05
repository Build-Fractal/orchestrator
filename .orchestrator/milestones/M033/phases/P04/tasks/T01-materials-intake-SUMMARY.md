---
schema_version: "1.0"
type: task-summary
id: "T01-materials-intake"
parent: "M033/P04"
milestone: "M033"
provides:
  - "commands/materials-intake.md FR-9 surface;scripts/lifecycle/materials-intake.sh FR-9 deterministic driver with 3 closed-enum SSOT blocks + filename-heuristic labeling + 3-category CON-4 drift detection + terminal/file-based reconciliation UX + byte-deterministic reconciled pre-spec + FR-20 marker + FR-22 JSONL emit + FR-21 dual-write fragment;tools/verify/m033-p04-materials-intake-md-shape.sh (19 PASS);tools/verify/m033-p04-materials-intake-sh-shape.sh (28 PASS)"
requires:
  - "from:M033/P01/T01 what:tests/fixtures/m033-pbj-materials-fixture/;from:M033/P02/T03+T04 what:scripts/lifecycle/grilling-shell.sh ask_one API;from:M033/P02/T01 what:scripts/util/jsonl-event-emitter.sh materials_intake_completed event;from:M033/P02/T02 what:scripts/util/start-state-markers.sh materials-intake subflow;from:M014 closed what:scripts/util/dual-write-runtime-md.sh --root/--marker/--append-entry API;from:M033/P02/T05 what:references/m033-fr21-dual-write-convention.md SSOT"
affects:
  - "M033/P04/T05"
key_files:
  - "commands/materials-intake.md;scripts/lifecycle/materials-intake.sh;tools/verify/m033-p04-materials-intake-md-shape.sh;tools/verify/m033-p04-materials-intake-sh-shape.sh"
key_decisions:
  - "deterministic-not-LLM-detector-uses-grep-awk-sed-only-no-model-routing;byte-deterministic-prespec-body-no-embedded-timestamps-only-directory-name-timestamp-pinned-via-M033_INTAKE_TIMESTAMP;ask_one-per-item-with-_GRILLING_CURRENT_QKEY-empty-because-labeling-and-reconciliation-are-independent-of-contradiction-detection;closed-resolution-enum-(accept-primary-accept-supplementary-manual-edit-defer)-enforced-via-case-validation-with-fallback-to-accept-primary-on-unrecognized;README-oracle-excluded-from-intake-via-basename-pattern-match-because-the-fixture-README-is-ground-truth-not-a-material;optional-materials_intake_stub-rewiring-in-start.sh-deferred-to-T05-cross-phase-regression-per-plan-Notes"
patterns_established:
  - "4-fenced-SSOT-blocks-pattern-(material-extensions+labeling-enum+drift-categories+resolution-enum)-with-load-bearing-token-grep-tripwires-for-shape-verifier;recommend_label-filename-heuristic-via-uppercase-tr-+-case-glob-pattern-match;3-detector-pipeline-(id-misalignment-via-asymmetric-token-reference-+-scheme-contradiction-via-key-value-extraction-and-cross-doc-diff-+-orphan-reference-via-ref-vs-def-set-difference)-running-sequentially-with-de-duped-output-accumulator;byte-deterministic-prespec-pattern-(env-pinned-directory-name-timestamp-NOT-embedded-in-body-+-canonical-section-ordering-by-label-category-+-cat-of-source-material-bodies-verbatim-+-provenance-comments-as-trailing-Reconciliation-Log-section);ask_one-output-capture-via-sed-extraction-of-answer-token-(out=$(ask_one ...);label=$(echo "$out" | sed -n s/^answer: //p | tail -1));parallel-bash-3.2-safe-detector-output-via-sort-u-+-grep-c-counting-with-||true-tolerance"
drill_down_paths:
  - ".orchestrator/milestones/M033/phases/P04/tasks/T01-materials-intake-PLAN.md;.orchestrator/milestones/M033/phases/P04/tasks/T01-materials-intake-PAYLOAD.md"
duration: "85m"
verification_result: "pass"
completed_at: "2026-05-04T14:06:22Z"
---

T01 ships the FR-9 materials-intake surface for M033 (Project Onboarding Experience): the orchestrator-native command + driver that takes heterogeneous PBJ-shape source materials, labels them against the closed labeling enum (primary | supplementary | decision-history | out-of-scope), runs deterministic CON-4 drift detection across the closed three-category enum (id-misalignment | scheme-contradiction | orphan-reference), reconciles via terminal-interactive UX for <= M033_CONFLICT_FILE_THRESHOLD (default 5 per #Q-6) conflicts (file-based UX above the threshold), and emits a byte-deterministic reconciled pre-spec consumed verbatim by orchestrator:specify --description.

Four artifacts shipped:

1. commands/materials-intake.md (206 lines) — canonical command-doc per MEM012. YAML frontmatter description: field; `# orchestrator:materials-intake` title; Prerequisites / Core Workflow (7 numbered sections) / Output / Idempotency / Error Handling / Referenced Scripts / Spec References sections. Names FR-9, CON-4, CON-5, FR-20, FR-21, FR-22, SC-4, US-4 AS-2, US-4 AS-5, #Q-6. Documents the deterministic-not-LLM invariant explicitly. References the PBJ fixture as the SC-4 oracle.

2. scripts/lifecycle/materials-intake.sh (767 lines, executable) — the FR-9 driver. Bash 3.2 compatible (MEM001). Three fenced SSOT blocks: material-extensions (.md / .pdf / .json / .txt), labeling-enum (4 tokens), drift-categories (3 tokens), plus a resolution-enum block (4 tokens). Flag set: --project-dir, --yes, --resolve. Sources scripts/lifecycle/grilling-shell.sh for ask_one. Helpers: enumerate_materials (extension scan + textutil/pdftotext probe with surfaced missing-binary diagnostic), recommend_label (filename-heuristic), label_material (per-material ask_one with closed-enum validation), detect_id_misalignment / detect_scheme_contradiction / detect_orphan_reference (three deterministic detectors), detect_drift (orchestrator with de-dup), surface_conflicts, reconcile_terminal (per-conflict ask_one with closed resolution enum), reconcile_file_based (above-threshold UX writes conflicts.md with re-invoke diagnostic), emit_reconciled_prespec (byte-deterministic body — no embedded timestamps; directory-name timestamp pinnable via M033_INTAKE_TIMESTAMP for SC-4). Main flow: enumerate -> label -> US-4 AS-5 all-out-of-scope fallback -> detect drift -> threshold-branched reconcile -> emit prespec -> FR-20 marker write -> FR-22 JSONL emit -> FR-21 dual-write fragment.

3. tools/verify/m033-p04-materials-intake-md-shape.sh (executable) — 19 PASS / 0 FAIL. Asserts file existence, line count >= 60, frontmatter description, MEM012 title, FR-9 / CON-4 / deterministic invariant tokens, driver reference, all 4 labeling enum tokens, all 3 drift category tokens, threshold env var, output artifacts, fixture reference.

4. tools/verify/m033-p04-materials-intake-sh-shape.sh (executable) — 28 PASS / 0 FAIL. Asserts existence + executable, line count >= 250, the three fenced SSOT block markers, ask_one + grilling-shell sourcing, full flag set, drift category tokens, output artifacts (reconciled-pre-spec.md, conflicts.md, materials_intake_completed event, materials-intake.complete marker), dual-write helper invocation, textutil / pdftotext probes, threshold + timestamp env vars, MEM001 negatives (no declare -A, no process substitution), CON-4 negatives (no claude-code, no conversus, no model_routing).

Functional smoke run against the PBJ fixture (--yes, M033_INTAKE_TIMESTAMP pinned) executed end-to-end, hit the file-based UX path correctly (14 conflicts > 5 threshold), wrote conflicts.md, exited 0 with the re-invoke diagnostic. T05 owns SC-4 calibration of the detector-vs-oracle line-by-line match per the plan Notes.

No deviations from the plan. The optional materials_intake_stub rewiring in start.sh is deferred to T05 cross-phase regression check per the plan Notes.
