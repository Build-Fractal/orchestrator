---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P02"
milestone: "M033"
provides:
  - "scripts/lifecycle/grilling-shell.sh-MIT-007-contradiction-and-FR-18-glossary,tests/m033-acceptance/p07-grilling-shell.sh,tools/verify/m033-p02-grilling-shell-contradiction-detection.sh,tools/verify/m033-p02-glossary-writer-shape.sh,tools/verify/m033-p02-acceptance-shape-sc11.sh"
requires:
  - "from:P02/T03-what:grilling-shell.sh-stubs-and-SSOT-markers"
affects:
  - "P03,P04,P05"
key_files:
  - "scripts/lifecycle/grilling-shell.sh,tests/m033-acceptance/p07-grilling-shell.sh,tools/verify/m033-p02-grilling-shell-contradiction-detection.sh,tools/verify/m033-p02-glossary-writer-shape.sh,tools/verify/m033-p02-acceptance-shape-sc11.sh"
key_decisions:
  - "none"
patterns_established:
  - "caller-set-bash-vars-for-ask_one-cross-cutting-context,accumulator-append-only-after-contradiction-clean,awk-single-pass-alphabetized-insert,closed-vocabulary-SSOT-block-via-IFS-newline-for-loop"
drill_down_paths:
  - ".orchestrator/milestones/M033/phases/P02/tasks/T04-grilling-shell-glossary-and-contradiction-PAYLOAD.md"
duration: "58m"
verification_result: "pass"
completed_at: "2026-05-04T03:51:32Z"
---

T04 layers the load-bearing logic onto T03 grilling-shell core: MIT-007 contradiction detection, FR-18 inline glossary writer, and the SC-11 acceptance script.

What was built

- scripts/lifecycle/grilling-shell.sh extended in-place. The two reserved fenced SSOT blocks are populated. The contradiction-pairs block carries 9 mutually-exclusive value triples in question-key:value-a:value-b shape covering target-user, deployment-target, and auth-model. The glossary-triggers block carries 4 question keys: domain-term-defined, acronym-resolved, convention-named, framework-chosen. The two stub bodies are replaced in place with real implementations and the public ask_one signature is unchanged.

- _grilling_check_contradiction body, 83 lines. Reads caller-set _GRILLING_CURRENT_QKEY. Scans the accumulator context_file for prior answers under that qkey via grep then tail then sed in three sequential steps with no internal pipes per bash 3.2 plus AP-007 constraint. Iterates the contradiction-pairs SSOT block via IFS newline for-loop and cut -d colon -f extraction. On contradiction match the function prints contradiction colon qkey prior equals new equals to stdout, then prompts on stderr for reconciliation. Reconciliation accepts r or R or empty as re-prompt return code 2, accepts bang followed by reason as accept-with-attestation printing attestation colon reason on stdout and returning zero, and rejects unrecognized input back to re-prompt return code 2.

- ask_one body extended to handle the contradiction return code. On return code 2 ask_one re-prompts the operator on stderr for an alternative answer, runs the contradiction check once more, and emits contradiction-unresolved diagnostic on second contradiction. On contradiction-clean path or attestation-accepted path ask_one then runs the glossary update, then appends the resolved answer to the accumulator under qkey colon resolved shape so subsequent invocations under the same accumulator see it.

- _grilling_glossary_update body, 78 lines. Reads caller-set _GRILLING_CURRENT_QKEY and matches against the glossary-triggers SSOT set via IFS newline for-loop. Non-trigger qkeys return zero with no file write. On a trigger the function resolves PROJECT_DIR or falls back to PWD, derives the glossary path at PROJECT_DIR slash wiki slash glossary.md, makes the wiki dir, and runs idempotency check via grep dash qF for term colon space definition. Identical entries return zero with no write so byte equality is preserved. New entries are written via awk single-pass alphabetized-insert that streams the existing file and inserts the new term colon definition before the first existing term that sorts greater. End-block fallback appends if no greater term is found, and a missing-file path writes the entry as the only line.

- tests/m033-acceptance/p07-grilling-shell.sh, executable, 12 checks pass. Test 1 covers FR-17 ordering by asserting recommendation colon precedes answer colon for the y-keystroke path. Test 2 covers the n-keystroke explicit-answer path resolving to fastify. Test 3 covers MIT-007 by pre-populating the accumulator with target-user colon consumer, then invoking ask_one with recommendation enterprise under the same qkey, and asserting contradiction colon target-user prior equals consumer new equals enterprise appears, then asserting attestation colon still-the-right-call appears, then asserting answer colon enterprise appears. Test 4 covers FR-18 alphabetized insert by pre-populating wiki glossary with alpha and gamma entries, triggering framework-chosen with answer beta, and asserting beta lands between alpha and gamma. Test 5 covers FR-18 idempotency via cmp dash s against the Test 4 snapshot. Test 6 covers non-trigger no-op for qkey stack.

- tools/verify/m033-p02-grilling-shell-contradiction-detection.sh, 10 checks pass. Asserts the contradiction-pairs SSOT block carries at least 3 pairs in the documented shape, the MIT-007 token and contradiction colon load-bearing token appear, the function name is defined, the body is non-trivial above 5 lines, and a sandboxed functional smoke test surfaces contradiction colon target-user against a pre-contradicting accumulator and emits attestation on accept-with-attestation reconciliation.

- tools/verify/m033-p02-glossary-writer-shape.sh, 10 checks pass. Asserts the glossary-triggers SSOT block carries at least 3 trigger keys, the FR-18 and glossary.md and wiki slash tokens appear, the function name is defined, the body is non-trivial above 10 lines, the alphabetized-insert mechanism is documented or awk is used, and a sandboxed functional smoke test writes a beta entry under PROJECT_DIR slash wiki slash glossary.md and a re-trigger leaves the file byte-identical.

- tools/verify/m033-p02-acceptance-shape-sc11.sh, 12 checks pass. Asserts the acceptance script exists and is executable, carries SC-11 and FR-17 and FR-18 and MIT-007 tokens, references grilling-shell.sh and glossary.md, asserts the four load-bearing tokens recommendation colon, answer colon, contradiction colon, and emits a SUMMARY line.

Verification result

- bash tools/verify/m033-p02-grilling-shell-shape.sh exits 0, pass equals 25, fail equals 0. T03 verifier regression preserved.
- bash tools/verify/m033-p02-grilling-shell-contradiction-detection.sh exits 0, pass equals 10, fail equals 0.
- bash tools/verify/m033-p02-glossary-writer-shape.sh exits 0, pass equals 10, fail equals 0.
- bash tools/verify/m033-p02-acceptance-shape-sc11.sh exits 0, pass equals 12, fail equals 0.
- bash tests/m033-acceptance/p07-grilling-shell.sh exits 0, pass equals 12, fail equals 0.

Patterns established

- caller-set bash variable convention for ask_one cross-cutting context: _GRILLING_CURRENT_QKEY and _GRILLING_CURRENT_DEFINITION are read by the helpers without polluting the FR-17 three-arg public API.
- accumulator append after contradiction-clean path so the accumulator only ever contains accepted answers, never contradiction-aborted ones.
- awk single-pass alphabetized-insert pattern preserves operator-edited comment lines and non-entry lines transparently.
- closed-vocabulary SSOT block populated as a multi-line bash string parsed via IFS newline for-loop with cut field extraction, bash 3.2 safe.

Notes

- For the P02 stub-mode escape valve, all wiki glossary writes are fixture-local under mktemp dir staging; the M032 with-wiki real surface lands later. The same code path becomes real in M033 P05 with no source change.
- The reconciliation UX, r or bang-reason, is intentionally minimal at v1 per Constitution-XIV. Friendly-tester signal in the M033 launch pass will inform any post-launch expansion.
