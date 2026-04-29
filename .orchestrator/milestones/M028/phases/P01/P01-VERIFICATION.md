---
schema_version: "1.0"
type: phase-verification
phase: "P01"
milestone: "M028"
verified_at: "2026-04-29T00:00:00Z"
collapse_decision: "full-5-phase"
---

# M028/P01 — Phase Verification (Collapse Decision Evidence)

## Cited Inputs

- `.orchestrator/milestones/M028/phases/P01/classifier-audit.md` (T01 deliverable — verbatim replay of every M028 source event through the M021 classifier `scripts/verify/lib/shape-classifier.sh` git SHA `12fcd98`).
- `tests/fixtures/m028-pre-repair-snapshot.json` (T02 deliverable; consumed by P02 `--repair` verifier as the canonical pre-repair `~/.claude/settings.json` shape).
- `specs/031-autonomous-hardening-v3/spec.md` (canonical source of source-event verbatim commands and Findings A–G evidence narration).
- `.orchestrator/milestones/M028/M028-CONTEXT.md` (Architectural Decisions — option-(a) replanning hook authority for the Replanning trigger note below).

## Cited fixtures

- `tests/fixtures/m028-pre-repair-snapshot.json` is referenced by path only; T03 does not read its content. The fixture is consumed by P02's `install-claude-code.sh --repair --dry-run` verifier per `M028-CONTEXT.md` Architectural Decisions.

## Per-Screenshot Causal Trace

One section per source event from T01's audit, in audit order. Attribution applies the rubric documented in `T03-collapse-decision-evidence-PLAN.md` step 2; "Resolved by Finding A alone" means the only attribution is Finding A AND the existing classifier verdict is `REJECT` (i.e., the hook would have fired correctly in-tree and only failed because hook portability was missing in a downstream project).

### SE-01: Finding A — hook fails-open in consumer project (bbt-companion)

- **Source**: Finding A, screenshots 4–7 (2026-04-25/26 sweep, paths under `/Users/brettkellgren/Sites/bbt-companion/...`)
- **Verbatim command**: see `classifier-audit.md` SE-01 "Verbatim command" — recorded as a non-firing event class; the in-family commands are SE-02..SE-05.
- **Existing-classifier verdict**: `not-applicable: hook-never-invoked (portability gap)` — the hook never ran because `$CLAUDE_PROJECT_DIR` resolved to a non-orchestrator repo and `pre-bash-shape-guard.sh:39-42` falls through to `exit 0`.
- **Root-cause attribution**: A
- **Resolved-by-Finding-A-alone**: NO
- **Rationale**: SE-01 is the family observation, not a single classifiable command. Per rubric step 2 row 1, attribution to A requires `verdict = REJECT` (hook would have rejected if it had run). Here the in-family verdicts (SE-02..SE-05) are all `allow`, so even with hook portability fixed the underlying shapes would still slip through. SE-01 documents the portability gap but does not, on its own, satisfy the "Resolved by Finding A alone" condition.

### SE-02: Finding B #1 — backtick-in-grep-regex (Screenshot 4)

- **Source**: Finding B #1, Screenshot 4 (2026-04-26)
- **Verbatim command**: see `classifier-audit.md` SE-02 — `grep '^- \`bash scripts/util/' commands/dispatch.md` (literal backtick inside grep regex).
- **Existing-classifier verdict**: `allow`
- **Root-cause attribution**: B
- **Resolved-by-Finding-A-alone**: NO
- **Rationale**: Rubric row 2 — verdict is `allow` and shape matches the reserved AP-010 (`cmd-sub-in-pattern`). The classifier under-matches; hook portability alone does not change the verdict. Finding A does not apply because the rubric row-1 trigger requires `verdict = REJECT`.

### SE-03: Finding B #2 — quoted-arg-newline-hash (Screenshot 3)

- **Source**: Finding B #2, Screenshot 3 (2026-04-25)
- **Verbatim command**: see `classifier-audit.md` SE-03 — `bash scripts/state/auto-state.sh set --last-action "T01 done\n# trailing comment"` (newline + `#` inside quoted arg).
- **Existing-classifier verdict**: `allow`
- **Root-cause attribution**: B
- **Resolved-by-Finding-A-alone**: NO
- **Rationale**: Rubric row 2 — verdict is `allow` and the shape matches reserved AP-011 (`quoted-arg-newline-hash`). Classifier under-match; A does not apply.

### SE-04: Finding B #3 — multiline-quoted-script (Screenshot 5)

- **Source**: Finding B #3, Screenshot 5 (2026-04-26)
- **Verbatim command**: see `classifier-audit.md` SE-04 — `node -e "const x = 1;\nconsole.log(x);\n"` (multi-line quoted body).
- **Existing-classifier verdict**: `allow`
- **Root-cause attribution**: B
- **Resolved-by-Finding-A-alone**: NO
- **Rationale**: Rubric row 2 — verdict is `allow` and the shape matches reserved AP-012 (`multiline-quoted-script`). Classifier under-match; A does not apply.

### SE-05: Finding B #4 — unquoted-brace-glob (Screenshot 6)

- **Source**: Finding B #4, Screenshot 6 (2026-04-26)
- **Verbatim command**: see `classifier-audit.md` SE-05 — `ls .orchestrator/milestones/M0{2,3,4,5}/M*-SUMMARY.md` (raw `{2,3,4,5}` outside quotes).
- **Existing-classifier verdict**: `allow`
- **Root-cause attribution**: B
- **Resolved-by-Finding-A-alone**: NO
- **Rationale**: Rubric row 2 — verdict is `allow` and the shape matches reserved AP-013 (`unquoted-brace-glob`). AP-007 only catches brace expansion inside quotes; the unquoted form is the gap. Classifier under-match; A does not apply.

### SE-06: Finding C — investigation compound chain (Screenshot 1)

- **Source**: Finding C, Screenshot 1 (2026-04-25)
- **Verbatim command**: see `classifier-audit.md` SE-06 — `grep -n classify_command scripts/verify/lib/shape-classifier.sh; echo "---"; grep -n reject_lookup scripts/hooks/pre-bash-shape-guard.sh`.
- **Existing-classifier verdict**: `reject:compound-chain-gt2` (AP-009 fired correctly)
- **Root-cause attribution**: E
- **Resolved-by-Finding-A-alone**: NO
- **Rationale**: Rubric row 5 — agent-constructed `grep …; echo "---"; grep …` shape, the canonical "agents invent compound shells" symptom that motivates the investigation-pattern wrapper class. The verdict is correctly `REJECT` (AP-009 already catches it), so this is not a classifier under-match (rubric row 7 does not apply); the remediation is providing the `grep-files.sh` wrapper so agents do not need to invent the shape. Finding A does not apply because the event was observed in-tree.

### SE-07: Finding D — destructive rm + && + ls (Screenshot 2)

- **Source**: Finding D, Screenshot 2 (2026-04-25)
- **Verbatim command**: see `classifier-audit.md` SE-07 — `/bin/rm -f .orchestrator/milestones/M028/phases/P01/*.txt && ls .orchestrator/milestones/M028/phases/P01/*.txt 2>&1`.
- **Existing-classifier verdict**: `allow`
- **Root-cause attribution**: D
- **Resolved-by-Finding-A-alone**: NO
- **Rationale**: Rubric row 4 — `/bin/rm` chained with `&&` and an `ls` verification tail. AP-009 does not reject because the top-level connector count is exactly 2 (the `2>&1` redirect does not count as a connector). Remediation is the `cleanup-stale-results.sh` wrapper, not hook portability or classifier extension.

### SE-08: Finding F — Stop-hook `command not found` (operator-reported)

- **Source**: Finding F, operator-reported during M018 close (2026-04-28)
- **Verbatim command**: see `classifier-audit.md` SE-08 — not a Bash classification target; failure surface is the runtime adapter (`scripts/dispatch/adapters/runtime/claude-code.sh:170-189`) emitting bare names like `orchestrator-post-verify` plus the absent install-side dedup in `scripts/util/settings-merge.sh`.
- **Existing-classifier verdict**: `not-applicable: adapter+installer issue (FR-3, FR-4, FR-5, FR-7)`
- **Root-cause attribution**: F
- **Resolved-by-Finding-A-alone**: NO (excluded from Bash-classification denominator)
- **Rationale**: Rubric row 3 — Stop-hook `command not found` naming `orchestrator-post-verify`. Adapter+installer issue, not classifier; per the audit Preface and the spec's Non-Goals, SE-08 is not a Bash classification target and is excluded from the collapse denominator. F ships in P02 alongside Finding A per the M028-CONTEXT sibling-fold non-negotiable.

### SE-09: Finding G — xargs sh -c body-descent (2026-04-28 22:25)

- **Source**: Finding G, operator screenshot 2026-04-28 22:25 (orchestrator's own repo — not a downstream-portability event)
- **Verbatim command**: see `classifier-audit.md` SE-09 — `find .orchestrator -name "T*-SUMMARY.md" -not -path "*/M066/*" 2>/dev/null | head -3 | xargs -I{} sh -c 'echo "═══ {} ═══"; head -20 "{}"'`.
- **Existing-classifier verdict**: `reject:compound-chain-gt2` (AP-009 fired on the top-level pipeline, not on the sh -c body)
- **Root-cause attribution**: G
- **Resolved-by-Finding-A-alone**: NO
- **Rationale**: The classifier does reject pre-prompt, but Claude Code's "Yes, and don't ask again for:" UI offered the literal byte-segment `xargs -I{} sh -c 'echo "═══ {} ═══"; head -20 "{}"'` as an allowlist target — accepting that rule would silently degrade the shape guard for the embedded `<body>` path. AP-014 (`xargs-sh-c-compound-body`) is reserved precisely so the classifier rejects on body-descent reasoning rather than top-level connector count, taking the bypass surface off the table. Per the M028-CONTEXT CON-5 body-descent depth, the classifier descends one level into `sh -c '<body>'`. Finding A does not apply (event was in-tree on the orchestrator repo, not in a downstream project).

## Collapse Decision

- **Bash-classification source events**: 7 (excludes Finding F Stop-hook event SE-08 — adapter+installer issue, not Bash classification per the audit Preface and FR-3/FR-4/FR-5/FR-7 narration). The 7 are SE-01, SE-02, SE-03, SE-04, SE-05, SE-06, SE-07, SE-09. (SE-01 is the family-observation row; the operator-distinct command shapes among the 7 are SE-02 through SE-09 minus SE-08, with SE-01 carrying the portability-gap class.)
- **Resolved by Finding A alone**: 0 of 7
- **Threshold**: M ≥ (N − 1) = 6
- **Decision**: `full-5-phase`
- **Rationale**: Per the per-screenshot causal trace above, *zero* Bash-classification source events are resolved by hook portability alone. The four B-family events (SE-02..SE-05) all have existing classifier verdict `allow` and require classifier extension (AP-010/011/012/013) regardless of where the hook fires. SE-06 (Finding E investigation-pattern wrapper) and SE-07 (Finding D destructive-op wrapper) are remediation-class issues independent of hook portability. SE-09 (Finding G) was observed in-tree on the orchestrator repo with the hook running, so hook portability is irrelevant; AP-014 body-descent is the load-bearing fix to neutralize the "don't ask again" allowlist bypass surface. SE-01 captures the portability gap as a family observation but, because its in-family commands (SE-02..SE-05) all yield `allow`, hook portability does not eliminate the in-the-wild failures it represents. The empirical M ≥ 6 threshold from the spec's collapse hypothesis is not met (0 ≤ 5); the milestone ships as roadmapped — P02 (hook portability + adapter+installer dedup, Findings A + F sibling-folded), P03 (classifier extension AP-010..AP-014), P04 (investigation-pattern wrappers including `cleanup-stale-results.sh` + `grep-files.sh`), P05 (cross-project verifier suite + downstream fixture).
- **Replanning trigger**: Decision is `full-5-phase`, so P02–P05 stay as-roadmapped per `M028-CONTEXT.md` Architectural Decisions option-(a). The planner does not enter `replanning`; no phases are marked stale. The collapse-to-2-PRs branch is not exercised. The arithmetic above (M = 0, N = 7, threshold = 6, 0 < 6) is the reproducible record from `classifier-audit.md` + the rubric in `T03-collapse-decision-evidence-PLAN.md` step 2.

## Corpus Staging List (consumed by P03)

- **Target count**: 7 (per FR-13 — five new APs plus regression coverage)
- **Authored count**: 5
- **Discrepancy rationale**: T03 stages 5 candidate corpus entries — one per under-matched B/G shape mapped one-to-one to the five reserved AP-IDs (AP-010, AP-011, AP-012, AP-013, AP-014). Two further entries are P03's authoring concern, not T03's: P03 will append (a) one negative-control entry exercising the M021 corpus regression invariant CON-7 / SC-8 (for example a benign `bash scripts/verify/run-suite.sh` invocation that must remain `allow` under both M021 and M028 classifiers), and (b) one boundary-case entry for AP-014 confirming the one-level body-descent depth bound (CON-5) — `sh -c '… sh -c '<inner>' …'` opaque-treatment evidence. T03's deliverable is the AP-anchored attribution shape that drives 5 of the 7 entries; P03 owns the regression and depth-bound padding to land FR-13's "seven" target.

### Candidate corpus entries

#### Candidate 1

- **Source event**: SE-02 (Finding B #1, Screenshot 4)
- **Verbatim command**: see `classifier-audit.md` SE-02 — `grep '^- \`bash scripts/util/' commands/dispatch.md`
- **Expected M028-classifier verdict**: `REJECT: AP-010 — cmd-sub-in-pattern (literal backtick inside grep regex parses as command-substitution attempt by Claude Code's pre-shape parser)`
- **Reject_lookup remediation target**: remediation hint only — guide the agent to escape the backtick (`\\\``) or use a fixed-string pattern (`grep -F`); no orchestrator-side wrapper for "search for backtick-bearing literals".

#### Candidate 2

- **Source event**: SE-03 (Finding B #2, Screenshot 3)
- **Verbatim command**: see `classifier-audit.md` SE-03 — `bash scripts/state/auto-state.sh set --last-action "T01 done\n# trailing comment"`
- **Expected M028-classifier verdict**: `REJECT: AP-011 — quoted-arg-newline-hash (newline followed by # inside a quoted arg trips Claude Code's path-validation heuristic)`
- **Reject_lookup remediation target**: remediation hint only — guide the agent to single-line quoted arguments and replace the trailing-comment shape with a separate setter call.

#### Candidate 3

- **Source event**: SE-04 (Finding B #3, Screenshot 5)
- **Verbatim command**: see `classifier-audit.md` SE-04 — `node -e "const x = 1;\nconsole.log(x);\n"`
- **Expected M028-classifier verdict**: `REJECT: AP-012 — multiline-quoted-script (multi-line quoted body hits Claude Code's ansi_c_string parser fallthrough)`
- **Reject_lookup remediation target**: `scripts/util/node-eval.sh` — wrapper that takes a script path argument and runs `node` against it, removing the multi-line quoted-body need.

#### Candidate 4

- **Source event**: SE-05 (Finding B #4, Screenshot 6)
- **Verbatim command**: see `classifier-audit.md` SE-05 — `ls .orchestrator/milestones/M0{2,3,4,5}/M*-SUMMARY.md`
- **Expected M028-classifier verdict**: `REJECT: AP-013 — unquoted-brace-glob (raw {a,b,c} outside quotes triggers brace-expansion heuristics not caught by AP-007's quoted form)`
- **Reject_lookup remediation target**: `scripts/util/peek-files.sh` — wrapper for the "show first N lines of files matching pattern" investigation shape, removing the brace-expansion need; or remediation hint to enumerate paths explicitly.

#### Candidate 5

- **Source event**: SE-09 (Finding G, 2026-04-28 22:25)
- **Verbatim command**: see `classifier-audit.md` SE-09 — `find .orchestrator -name "T*-SUMMARY.md" -not -path "*/M066/*" 2>/dev/null | head -3 | xargs -I{} sh -c 'echo "═══ {} ═══"; head -20 "{}"'`
- **Expected M028-classifier verdict**: `REJECT: AP-014 — xargs-sh-c-compound-body (combined top-level + sh -c body connectors > 2; classifier descends one level per CON-5)`
- **Reject_lookup remediation target**: `scripts/util/peek-files.sh` — same wrapper as Candidate 4; covers the "list-and-peek" investigation shape so agents do not need the xargs/sh-c construction.

## Notes

- The audit's SE-08 (Finding F Stop-hook) does not appear in the corpus staging list because it is not a Bash classification target — its remediation is the runtime adapter fix (FR-3/FR-4) plus install-side dedup (FR-5) shipped in P02 alongside Finding A.
- SE-06 (Finding C / E) does not appear in the corpus staging list because the existing AP-009 already rejects the shape correctly; its remediation is a wrapper (`grep-files.sh`) that ships in P04, not a classifier extension.
- SE-07 (Finding D) does not appear in the corpus staging list because AP-009's connector threshold is intentionally not lowered (would break the M021 regression baseline per CON-7); its remediation is the `cleanup-stale-results.sh` destructive-op wrapper that ships in P04.
- The discrepancy rationale above (5 vs. 7) is the operator-confirmed shape per the T03 task plan: T03's job is to land the AP-anchored list mechanically derivable from the audit; P03 reconciles to FR-13's count by adding regression + boundary entries.
