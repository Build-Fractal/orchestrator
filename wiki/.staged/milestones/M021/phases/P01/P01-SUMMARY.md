---
schema_version: "1.0"
type: phase-summary
id: "P01"
parent: "M021"
milestone: "M021"
provides:
  - "scripts/util/with-env.sh wrapper exporting KEY=VALUE assignments before -- into a child command, plus m021-p01-with-env.sh gate, scripts/util/read-range.sh wrapper emitting inclusive 1-indexed line ranges via awk, plus m021-p01-read-range.sh gate, scripts/util/run-probe.sh wrapper invoking staged bash probes from approved roots only, plus m021-p01-run-probe.sh gate, scripts/util/ catalog README + cross-wrapper bash-3.2 compat gate + README catalog gate"
requires:
  - "from:T01 what:with-env.sh; from:T02 what:read-range.sh; from:T03 what:run-probe.sh"
affects:
  - "P01, P01, P01, P02"
key_files:
  - "scripts/util/with-env.sh, scripts/util/read-range.sh, scripts/util/run-probe.sh, scripts/util/README.md,scripts/verify/m021-p01-bash32-compat.sh,scripts/verify/m021-p01-readme-catalog.sh"
key_decisions:
  - "AD-19"
patterns_established:
  - "with-env wrapper replaces inline VAR=val cmd prefix that trips Claude Code safety heuristic, read-range wrapper replaces sed -n 'M,Np' inline shape that trips Claude Code quoted-brace / sed-write heuristic, run-probe wrapper replaces cat>/tmp/x.sh<<EOF / bash /tmp/x.sh shape that trips heredoc-expansion + bare-tmp-invocation heuristics (AD-3); approved-root prefix allowlist (/tmp, /private/tmp, /var/folders, /private/var/folders, <repo>/tmp) gates invocation, phase-aggregator task ships catalog index + cross-wrapper gates without touching per-wrapper code"
drill_down_paths:
  - ".orchestrator/milestones/M021/phases/P01/tasks/T01-SUMMARY.md, .orchestrator/milestones/M021/phases/P01/tasks/T02-SUMMARY.md, .orchestrator/milestones/M021/phases/P01/tasks/T03-SUMMARY.md, .orchestrator/milestones/M021/phases/P01/tasks/T04-SUMMARY.md"
duration: "50m"
verification_result: "pass"
completed_at: "2026-04-17T16:57:43Z"
observability_surfaces:
  - "none"
---

P01 ships the **Wrapper Catalog** — three canonical shell wrappers that replace the recurring inline bash shapes M011/P05–P07 surfaced as Claude Code safety-prompt triggers, plus a catalog index and two cross-wrapper gates enforcing Bash-3.2 compatibility and README structure.

## What Was Built

- `scripts/util/with-env.sh` — exports `KEY=VALUE` assignments before `--` into a child command (replaces inline `VAR=val bash cmd`, which trips simple-expansion heuristics). Validates LHS via nested `case` patterns (Bash-3.2 safe). 6 gate assertions pass.
- `scripts/util/read-range.sh` — emits an inclusive 1-indexed line range via `awk` (replaces `sed -n 'M,Np' file`, misclassified as a write by the parser). 7 gate assertions pass, including invalid-range exit 2.
- `scripts/util/run-probe.sh` — invokes a staged bash probe from an approved root prefix allow-list (`/tmp`, `/private/tmp`, `/var/folders`, `/private/var/folders`, `<repo>/tmp`). Replaces `cat > /tmp/x.sh <<EOF … EOF; bash /tmp/x.sh` (heredoc-expansion + bare-tmp invocation). 7 gate assertions pass.
- `scripts/util/README.md` — catalog index with one-line usage examples for each wrapper, [M011](../../../../milestones/M011/index.md) screenshot replacement notes, exit codes, and composition patterns. README-catalog gate enforces structure.
- `scripts/verify/m021-p01-bash32-compat.sh` — `bash -n` parse + grep for forbidden Bash-4 constructs (`declare -A`, `mapfile`, `readarray`, `${var,,}`, `${var^^}`, `${!prefix*}`) across all three wrappers.
- `scripts/verify/m021-p01-readme-catalog.sh` — asserts README names each wrapper with a Usage line and the `## Wrapper Catalog` heading.

## Key Decisions

- **AD-19 inline-shape rule** applies to inline bash *tool calls*, not the internal bash of wrapper scripts. Each gate is invoked via a single-script-file `Check:`; the wrappers themselves use richer bash internally (functions, conditionals, arithmetic) without risk.
- **Plan deviation (T01)**: the plan's LHS validation glob `[A-Za-z_][A-Za-z_0-9]*=*` rejected single-letter keys (`A=1`), inconsistent with its own gate assertions. Replaced with a nested `case` that validates via negated-class patterns — same semantic intent, Bash 3.2 safe, gate passes.
- **Plan deviation (T03)**: macOS BSD `mktemp /tmp/m021-p01-probe.XXXXXX.sh` does not expand `X`s when a trailing suffix is present — it creates a literal `XXXXXX.sh` file. Switched to suffix-free `/tmp/m021-p01-probe.XXXXXX` in gate-level mktemp calls. Wrapper itself unchanged.
- **Compat gate scope (T04)**: added `${!prefix*}` indirect expansion to the forbidden-construct list (payload Constraints listed it alongside the five the plan grep enumerated). No false positives against the three wrappers.

## Patterns Established

- **Shape-replacement wrapper pattern**: each wrapper absorbs exactly one recurring inline-bash shape that M011 screenshots identified as a safety-prompt trigger. Consumers invoke the wrapper via a single-script-file tool call; the richer bash stays inside.
- **Approved-root prefix allow-list** (`run-probe.sh`): gates probe-script invocation to a closed set of canonical prefixes, handling both macOS `/tmp ↔ /private/tmp` and `/var/folders ↔ /private/var/folders` symlink variants.
- **Phase aggregator task**: T04 ships catalog index + cross-wrapper gates without touching per-wrapper code. Keeps the wrapper tasks (T01–T03) independently verifiable while still enforcing cross-cutting invariants (Bash 3.2, README structure) mechanically.

## Verification Results

Phase suite `bash scripts/verify/run-suite.sh m021 P01` reports PASS: 5 / FAIL: 0 across all five P01 gates. External-modification check: no external modifications. All four task summaries present and complete.

## Downstream Impact

P02 (Linter v2) consumes these wrappers by name in its remediation-hint text. P03 (Pre-Bash Hook) rewrites inline shapes to wrapper invocations. P04 (Replay Corpus) validates that wrapper-based rewrites eliminate the would-prompt count.
