---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P02"
milestone: "M033"
provides:
  - "scripts/lifecycle/grilling-shell.sh-FR-17-core-API,tools/verify/m033-p02-grilling-shell-shape.sh"
requires:
  - "none"
affects:
  - "P02/T04"
key_files:
  - "scripts/lifecycle/grilling-shell.sh,tools/verify/m033-p02-grilling-shell-shape.sh"
key_decisions:
  - "none"
patterns_established:
  - "stub-helper-with-stable-name-for-T04-replacement,reserved-fenced-SSOT-block-markers,sourceability-guard-via-BASH_SOURCE-vs-dollar-zero,recommendation-not-interrogation-prefix-ordering"
drill_down_paths:
  - ".orchestrator/milestones/M033/phases/P02/tasks/T03-grilling-shell-core-PAYLOAD.md"
duration: "35m"
verification_result: "pass"
completed_at: "2026-05-04T03:44:29Z"
---

T03 ships scripts/lifecycle/grilling-shell.sh, the FR-17 reusable conversational-shell module, plus its shape verifier tools/verify/m033-p02-grilling-shell-shape.sh.

What was built

- scripts/lifecycle/grilling-shell.sh, 194 lines. The module exposes a single uniform public function ask_one with three positional args question, recommendation, and an optional context-file. The function names the recommendation FIRST per the recommendation-not-interrogation framing, then prints the question on a single line with a one-keystroke prompt. It reads exactly one line via read -r, treating Y or y or empty as accept-the-recommendation, treating N or n as request-explicit-answer with a stderr re-prompt, and treating any other input as the explicit operator-supplied answer. The resolved value is echoed on stdout with the load-bearing prefix answer followed by a colon and a space. The module is bash 3.2 compatible and uses printf throughout for the load-bearing prefixes.

- Three reserved fenced SSOT comment block markers are present and parseable: grilling-protocol-rules carries the four-rule grilling protocol verbatim; contradiction-pairs and glossary-triggers ship as empty placeholders that T04 will populate in-place without restructuring.

- Two no-op stub helpers are defined with stable names: _grilling_check_contradiction and _grilling_glossary_update. Both take their arguments into local underscore-prefixed vars and return zero. T04 replaces the stub bodies with real MIT-007 contradiction detection and FR-18 glossary writer logic; the function names and signatures are stable across that edit.

- Sourceability guard at end of file: a single if-block compares BASH_SOURCE element zero against dollar-zero. When the file is executed directly the guard prints the API surface; when sourced the guard is a no-op and the function definitions become available to the caller. There is no top-level set hyphen e or set hyphen u or set hyphen o pipefail, and no top-level exit. All non-success paths inside ask_one use return.

- tools/verify/m033-p02-grilling-shell-shape.sh, 259 lines, executable, 25 checks. Asserts the file exists; the four load-bearing tokens ask_one, recommendation colon, answer colon, FR-17, CON-5, and MIT-007 appear; all three fenced openers are present; no top-level set or exit directives leak; both stub helpers are defined; sourcing the module in a sandboxed subshell exits zero; declare hyphen capital F reports ask_one as a function after sourcing; a functional smoke test pipes the letter y as stdin and invokes ask_one with question What is your stack and recommendation web-saas, then asserts both recommendation colon web-saas and answer colon web-saas appear in stdout in that order; the ask_one body contains no nested self-invocation lines; and printf is used for both load-bearing prefixes.

Verification result

bash tools/verify/m033-p02-grilling-shell-shape.sh reports SUMMARY: m033-p02-grilling-shell-shape.sh pass=25 fail=0, exit zero.

T04 contract preservation

Stubs are callable, the names _grilling_check_contradiction and _grilling_glossary_update are stable, the three SSOT block markers are reserved and parseable for in-place population, the ask_one three-arg public API is stable, and T04 reads caller-set bash vars _GRILLING_CURRENT_QKEY and _GRILLING_CURRENT_DEFINITION when populating the glossary writer body.
