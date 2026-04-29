---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P03"
milestone: "M028"
provides:
  - "Five new shape-classifier private detectors (_sc_has_cmd_sub_in_pattern AP-010 / FR-8; _sc_has_quoted_arg_newline_hash AP-011 / FR-9; _sc_has_multiline_quoted_script AP-012 / FR-10; _sc_has_unquoted_brace_glob AP-013 / FR-11; _sc_has_xargs_sh_c_compound_body AP-014 / FR-12 with CON-5 one-level-deep body-descent); five new reject branches in classify_command emitting reject:cmd-sub-in-pattern / reject:quoted-arg-newline-hash / reject:multiline-quoted-script / reject:unquoted-brace-glob / reject:xargs-sh-c-compound-body; AP-014 ordered BEFORE the existing AP-009 top-level-count check (load-bearing for SC-6 -- the SE-09 verdict shifts from compound-chain-gt2 to xargs-sh-c-compound-body); AP-010..AP-013 ordered AFTER existing M021 rejects so prior precedence is preserved on shapes M021 already catches; file-header pattern-class-label list extended with the 5 new reject labels; per-task verifier scripts/verify/m028/p03-classifier-new-classes.sh asserting SE-02..SE-05 + SE-09 verbatim verdicts plus AP-014 precedence claim plus ID-27 nested-sh-c boundary plus delegated M021 strict-superset regression via replay-prompt-corpus.sh exit code."
requires:
  - "from:P03/T01 what:ANTIPATTERNS.md AP-010..AP-014 entries with pattern-class-label substrings cmd-sub-in-pattern / quoted-arg-newline-hash / multiline-quoted-script / unquoted-brace-glob / xargs-sh-c-compound-body that the classifier reject labels match byte-for-byte (T05 corpus replay greps the literal class string in the hook's REJECT diagnostic); from:disk what:scripts/verify/lib/shape-classifier.sh the M021 classifier this task extends additively; from:disk what:tests/fixtures/m021-prompt-corpus.txt 20 M021 entries whose verdicts must remain unchanged (CON-7 / SC-8); from:disk what:scripts/verify/replay-prompt-corpus.sh the M021 SC-1 historical regression harness that proves no M021 regression at task time; from:disk what:.orchestrator/milestones/M028/phases/P01/classifier-audit.md verbatim SE-02..SE-09 commands."
affects:
  - "P03/T03 (hook reject_lookup gains case arms keyed on the 5 new pattern-class labels); P03/T04 (corpus extension appends 7 new entries whose EXPECTED_OUTCOME values cite the new reject classes); P03/T05 (replay harness asserts 27/27 verdicts; per-finding verifiers consume the new classifier verdicts)"
key_files:
  - "scripts/verify/lib/shape-classifier.sh,scripts/verify/m028/p03-classifier-new-classes.sh"
key_decisions:
  - "AP-014 ordered BEFORE the existing _sc_count_top_level_stages > 2 check so the more-specific xargs-sh-c-compound-body verdict dominates compound-chain-gt2 on the SE-09 shape (load-bearing for SC-6); without this ordering the SE-09 verdict regresses to compound-chain-gt2 and T05's full-corpus replay reports a verdict mismatch.,AP-010..AP-013 ordered AFTER the existing four M021 reject checks so a backtick-in-regex inside a 3-stage pipeline still rejects as compound-chain-gt2 (the more general rule fires first); the new detectors only catch shapes that no existing rule already covers.,Body-descent at one level only (CON-5) implemented via placeholder substitution -- the inner sh -c '<inner>' is replaced with the literal token OPAQUE in the body string before the counter walks; avoids unbounded recursion and keeps the bash 3.2 implementation flat.,Per-task verifier co-authored with the deliverable per CLAUDE.md hotfix on plan-time verifier-availability cross-check; the auto-loop's mechanical ## Verification step resolves at T02 time without cross-task verifier dependency.,Used the canonical write-summary.sh field name --parent (not the payload-prompt-shown --phase) verified via grep TASK_FIELDS; CLAUDE.md hotfix on the task-mode usage example covers the field-coverage gap separately."
patterns_established:
  - "AP-014 ordering invariant in classify_command: more-specific reject classes are inserted BEFORE more-general ones; documented in classify_command comments AND surfaced as a discrete PASS line in the verifier output so SC-6 is traceable from gate output.,One-level-deep recursion bound (CON-5) via placeholder substitution: nested-shape detectors that need to count internal structure use a bounded strip-and-replace approach -- at depth 1 the inner shape is replaced with a low-information placeholder token (OPAQUE) before the counter walks the cleaned body.,Char-by-char quote-state machines for shape detection: every new detector follows the same pattern as the existing _sc_has_quoted_brace / _sc_count_top_level_stages -- single-quote/double-quote/backslash-escape state transitions on a ${s:$i:1} index walk; bash 3.2 safe (no [[:alpha:]] lookups inside body; no process substitution; no declare -A).,Bash 3.2 string concatenation discipline: ${body}${ch} instead of body+=$ch -- bash 3.2 doesn't have += for strings.,Per-task verifier co-located with the deliverable it asserts (CLAUDE.md hotfix); cross-task verifier dependency rejected; auto-loop ## Verification step always resolves at task time.,Verifier-as-precedence-claim: SC-6 surfaced as a discrete PASS line ("SE-09 verdict precedence: AP-014 over AP-009 (CON-5)") so a reader of the verifier output can trace the precedence claim directly without needing to know the M021 baseline verdict."
drill_down_paths:
  - ".orchestrator/milestones/M028/phases/P03/tasks/T02-classifier-extension-PLAN.md,.orchestrator/milestones/M028/phases/P03/tasks/T01-antipatterns-entries-SUMMARY.md,.orchestrator/milestones/M028/phases/P01/classifier-audit.md,scripts/verify/lib/shape-classifier.sh,scripts/verify/m028/p03-classifier-new-classes.sh,scripts/verify/replay-prompt-corpus.sh"
duration: "45m"
verification_result: "pass"
completed_at: "2026-04-29T17:24:13Z"
---

Extended `scripts/verify/lib/shape-classifier.sh` with five new pattern detectors closing the gap between in-the-wild Claude-Code-prompted shapes and the M021 reject matrix. Closes FR-8 through FR-12 of the M028 spec; preserves CON-7 strict-superset (all 20 M021 corpus entries replay with verdicts unchanged).

**Five new detectors** (all bash 3.2 + POSIX-sh safe; pure-bash character-by-character scanning with quote-state tracking — no jq, no python, no process substitution):

- `_sc_has_cmd_sub_in_pattern` (AP-010 / FR-8): backtick byte inside the first quoted regex argument to grep / sed / awk. Bash 3.2 ERE via `[[ =~ ]]` with parallel single-quote and double-quote regexes.
- `_sc_has_quoted_arg_newline_hash` (AP-011 / FR-9): literal newline byte immediately followed by `#` byte inside a double-quoted CLI argument. Char-by-char scan with quote-state tracking and backslash-escape handling.
- `_sc_has_multiline_quoted_script` (AP-012 / FR-10): multi-line body inside `(node|python|python3|ruby|perl|sh|bash) -e/-c "<body>"`. Locates verb+flag via ERE, then walks past tokens char-by-char, captures the body's opening quote (single or double), scans bytes until matching closing quote or newline.
- `_sc_has_unquoted_brace_glob` (AP-013 / FR-11): raw `{N,M,...}` brace expansion outside both single and double quotes (AP-007 already catches the quoted case). Tracks `${...}` parameter expansion exclusion via prev-char-is-`$` check.
- `_sc_has_xargs_sh_c_compound_body` (AP-014 / FR-12, load-bearing for SC-6): combined connector count from outer-command top-level + sh -c body's top-level > 2. CON-5: body-descent is one level deep — nested `sh -c '<inner>'` inside the body is replaced with the placeholder token `OPAQUE` before counting, so inner connectors do NOT contribute. Uses the existing `_sc_count_top_level_stages` helper twice: once on the cleaned body, once on the outer command.

**`classify_command` precedence** updated per the AP-014-before-AP-009 ordering invariant (load-bearing for SC-6). The new dispatch order is:

1. `nested-cmd-sub` (M021)
2. `xargs-sh-c-compound-body` (NEW — runs BEFORE `compound-chain-gt2` so the more-specific verdict dominates on the SE-09 shape)
3. `compound-chain-gt2` (M021)
4. `heredoc-with-expansion` (M021)
5. `quoted-brace` (M021)
6. `cmd-sub-in-pattern` (NEW — runs AFTER M021 rejects so existing precedence is preserved on shapes M021 already catches; e.g. a backtick inside a regex inside a 3-stage pipeline still rejects as `compound-chain-gt2`)
7. `quoted-arg-newline-hash` (NEW)
8. `multiline-quoted-script` (NEW)
9. `unquoted-brace-glob` (NEW)
10. (rewrite extractors unchanged — preserved verbatim)

**File-header pattern-class-label list** (lines 20-27) extended with the five new reject labels. The contractually-stable label list now carries 6 rewrite + 9 reject classes.

**Per-task verifier `scripts/verify/m028/p03-classifier-new-classes.sh`** authored co-located with this task's deliverable per the CLAUDE.md hotfix on plan-time verifier-availability cross-checks. The verifier sources the classifier and asserts:

- SE-02 verbatim grep+backtick → `reject:cmd-sub-in-pattern`
- SE-03 verbatim newline+# in quoted arg → `reject:quoted-arg-newline-hash`
- SE-04 verbatim multi-line `node -e` body → `reject:multiline-quoted-script`
- SE-05 verbatim unquoted brace glob → `reject:unquoted-brace-glob`
- SE-09 verbatim Finding G screenshot → `reject:xargs-sh-c-compound-body`
- SE-09 verdict precedence: AP-014 dominates AP-009 (recorded as a discrete PASS line so a reader can trace SC-6 directly from the verifier output)
- ID-27 boundary: nested `sh -c` body still rejects as `xargs-sh-c-compound-body` because the outer body's own connectors push combined > 2 even with the inner `sh -c` token treated opaque
- M021 corpus regression delegated to `scripts/verify/replay-prompt-corpus.sh`; verifier asserts that script exits 0 in-line as cheap regression insurance against verdict drift in this commit

**Verification verdict**: PASS. Both `## Verification` commands exit 0:
- `bash scripts/verify/m028/p03-classifier-new-classes.sh` → 8/8 PASS lines.
- `bash scripts/verify/replay-prompt-corpus.sh` → 20/20 entries unchanged, `WOULD_PROMPT=0/20`.

Regression sweep across all M028/P02 verifiers + the P03/T01 verifier: 7/7 PASS (`p02-adapter-absolute-paths.sh`, `p02-hook-self-conformance.sh`, `p02-hook-self-locate.sh`, `p02-hooks-payload-staged.sh`, `p02-repair-fixture.sh`, `p03-antipatterns-entries.sh`, `p03-classifier-new-classes.sh`). The hook self-conformance verifier specifically confirms that the M028 classifier evolution does NOT break the resolution-block conformance T01 established in P02 — the new reject branches only fire for shapes the resolution block does not exhibit.

**Patterns established / reinforced**:

- **AP-014 ordering invariant in classify_command**: more-specific reject classes are inserted BEFORE more-general ones. AP-014 (sh -c body-descent) runs BEFORE the top-level stage check so the SE-09 verdict drifts from `compound-chain-gt2` to `xargs-sh-c-compound-body`. Documented in classify_command comments and in the verifier's PASS line.
- **One-level-deep recursion bound (CON-5) via placeholder substitution**: nested-shape detectors that need to count internal structure use a bounded strip-and-replace approach — at depth 1 the inner shape is replaced with a low-information placeholder token (here `OPAQUE`) before the counter walks the cleaned body. Avoids unbounded recursion and keeps the bash 3.2 implementation flat.
- **Char-by-char quote-state machines for shape detection**: every new detector follows the same pattern as the existing `_sc_has_quoted_brace` / `_sc_count_top_level_stages` — single-quote/double-quote/backslash-escape state transitions on a `${s:$i:1}` index walk. Bash 3.2 safe; no `[[:alpha:]]` lookups inside body, no process substitution, no `declare -A`.
- **Co-locate per-task verifiers with the deliverable they assert** (CLAUDE.md hotfix): the classifier extension's verifier ships in the same task as the classifier extension itself. Cross-task verifier dependency is rejected; the auto-loop's mechanical `## Verification` step always resolves at task time.
- **Bash 3.2 string concatenation discipline**: `${body}${ch}` instead of `body+="$ch"` — bash 3.2 doesn't have `+=` for strings.

**Drift caught at authoring time**: payload's docstring-style usage example for `write-summary.sh` shows `--phase=P03 --milestone=M028` but the script's actual interface uses `--parent=P03 --milestone=M028`. Used the actual interface (verified via `grep TASK_FIELDS scripts/knowledge/write-summary.sh`); CLAUDE.md hotfix on `write-summary.sh` task-mode usage example asks for the example to be expanded to the full 15-field shape but the field-name canonical mapping (`parent`, not `phase`) is unaffected.
