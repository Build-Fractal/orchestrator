---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P07"
milestone: "M011"
provides:
  - "commands/ingest.md updated 6-step pre-chunker pipeline (detect-shape -> normalize-if-foreign -> resolve-policy -> fidelity-gate -> chunker -> rebuild), three new user-facing flags (--review / --no-review / --force-after-BLOCK) with FORCE: audit-trail marker, eight new Reference Files bullets preserving all six P06 bullets; scripts/engine/intensity-gate.sh registers new 'ingest' stage (Quick=normalize; Standard/Full=normalize,fidelity-gate) with error-message update listing ingest in the expected-stage vocabulary; scripts/verify/m011-p07-intensity-ingest-stage.sh (9 PASS assertions: gate exists, 'ingest)' case label, Quick/Standard/Full exact execute+skip lines, invalid-intensity rejection); scripts/verify/m011-p07-ingest-doc-updates.sh (17 PASS assertions: doc exists, line-count >= 140, --review / --no-review / --force tokens, detect-spec-shape.sh + normalize-spec.sh + adapters/tool/conversus.sh + intensity-gate.sh --stage ingest literals, FORCE: marker, normalization-before-gate assurance window, all six P06 Reference File bullets preserved)"
requires:
  - "from:T01 what:detect-spec-shape.sh+normalize-spec.sh+spec-normalizer-prompt.md; from:T02 what:conversus.sh adapter+conversus-gate.md+normalize-fidelity preset+gate-result template; from:M008 what:intensity-gate.sh 7-stage matrix; from:P06 what:commands/ingest.md thin-wrapper + six Reference File bullets to preserve"
affects:
  - "T04 e2e wire consumes the new 6-step pipeline; T04 preserved-references regression guards the newly-added Reference File bullets; downstream orchestrator:evaluate and orchestrator:roadmap benefit from normalized-before-chunker input; M011 close-out gate includes these two verify scripts"
key_files:
  - "commands/ingest.md, scripts/engine/intensity-gate.sh, scripts/verify/m011-p07-intensity-ingest-stage.sh, scripts/verify/m011-p07-ingest-doc-updates.sh"
key_decisions:
  - "workflow renumbered 1->10 with new steps 2-5 inserted ahead of original ingest-spec.sh invocation (now step 6), preserving the full original 1-6 Workflow content verbatim in renumbered slots 1 and 6-10; --force flag given dual documented semantics (P06 re-ingest-confirmation bypass AND P07 BLOCK-verdict bypass) under a single flag name with clarifying note in Usage section; --review / --no-review overrides applied at the command layer (ingest.md) not in intensity-gate.sh itself so the gate remains a pure matrix resolver; Error Handling section gained a 'Pre-chunker pipeline errors (P07)' subsection heading so the seven new error modes are grouped and the total line count comfortably exceeds the >=140 threshold the verify script asserts; grep -Fq -- idiom used for every --flag token in both verify scripts (MEM012 BSD-grep safety)"
patterns_established:
  - "intensity-gate stage registration idiom continues from P05 roadmap stage: minimal case-row insertion BEFORE the catch-all *), update the catch-all error message to include the new stage in its expected-list; command-doc P07 pipeline augmentation pattern: renumber existing steps, insert new steps in-place, preserve every original bullet+reference verbatim so preserve-references regression continues to pass; verify-script 'within-3-lines' phrase-window assertion via grep -n -B 2 -A 2 + piped grep -Fq checks (used to assert the 'normalized artifact BEFORE fidelity gate' narrative without pinning exact wording)"
drill_down_paths:
  - ".orchestrator/milestones/M011/phases/P07/tasks/T03-PAYLOAD.md"
duration: "45m"
verification_result: "pass"
completed_at: "2026-04-17T11:48:51Z"
---

T03 wired the T01 + T02 deliverables into the user-facing ingest pipeline. Two source-file edits and two new verify scripts; no other production artifacts touched. commands/ingest.md now documents a 6-step pre-chunker pipeline (shape detection -> conditional normalization -> intensity-gate policy resolution -> conditional fidelity gate -> chunker -> rebuild+report) with three new flags (--review force-gate-on, --no-review force-gate-off, --force now carrying dual P06-re-ingest + P07-BLOCK-bypass semantics); scripts/engine/intensity-gate.sh registers the eighth stage 'ingest' with the Quick=normalize / Standard+=normalize,fidelity-gate matrix and an updated catch-all error message. Both new verify scripts are Bash 3.2 compatible, single-script-file invokable (AD-19), and use the grep -Fq -- idiom for every --flag token (MEM012 BSD-grep safety). Verification: scripts/verify/m011-p07-intensity-ingest-stage.sh -> 9/9 PASS; scripts/verify/m011-p07-ingest-doc-updates.sh -> 17/17 PASS; scripts/verify/m011-p06-commands-preserve-references.sh regression re-check -> PASS (evaluate.md and roadmap.md untouched). No deviations from the task plan.
