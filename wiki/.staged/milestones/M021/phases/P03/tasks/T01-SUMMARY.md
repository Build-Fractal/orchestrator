---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P03"
milestone: "M021"
provides:
  - "scripts/verify/lib/shape-classifier.sh sourceable pure-function library exposing classify_command that maps a Bash command string to one of allow / rewrite:<result> / reject:<pattern-class> across the closed 10-pattern matrix (6 rewrites + 4 rejects per AD-2)"
requires:
  - "from:P01 what:scripts/util/with-env.sh; from:P01 what:scripts/util/read-range.sh; from:P01 what:scripts/util/run-probe.sh; from:P02 what:AP-005..AP-009 pattern-class naming"
affects:
  - "P03,P03/T02,P03/T05"
key_files:
  - "scripts/verify/lib/shape-classifier.sh"
key_decisions:
  - "AD-2,AD-19"
patterns_established:
  - "rejects-dominate-rewrites precedence; character-by-character top-level stage counter with quote+paren+backtick state tracking (Bash 3.2 safe); quoted-vs-unquoted heredoc opener discrimination; variable-assembled ERE for single-quote class membership; redirect-cmd-sub emits deterministic rewrite to read-range.sh with runtime args deferred (plan option (a))"
drill_down_paths:
  - ".orchestrator/milestones/M021/phases/P03/tasks/T01-PLAN.md,.orchestrator/milestones/M021/phases/P03/tasks/T01-PAYLOAD.md"
duration: "40m"
verification_result: "pass"
completed_at: "2026-04-17T19:28:43Z"
---

T01 ships scripts/verify/lib/shape-classifier.sh — a 532-line Bash 3.2 sourceable library exposing classify_command <cmd-string>.

Public API: classify_command prints exactly one line — allow / rewrite:<cmd> / reject:<pattern-class>. Private _sc_* helpers implement the 10 detectors. All ten pattern-class labels appear verbatim in source.

PATTERN PRECEDENCE (rejects dominate): nested-cmd-sub -> compound-chain-gt2 (>2 stages) -> heredoc-with-expansion -> quoted-brace -> then rewrites: cat-heredoc-exec -> trailing-rc-echo -> sed-n-range -> cd-and-bash -> var-inline-bash -> redirect-cmd-sub -> fall-through to allow.

REWRITE-6 DECISION (plan author-point): chose option (a) per plan default — redirect-cmd-sub emits fixed "rewrite:bash scripts/util/read-range.sh" (no args) to force the deterministic path. If dogfood surfaces semantic mismatch, P04 can promote to reject.

MUST-HAVES: All pass. bash -n exits 0. Zero forbidden Bash-4 constructs in code (only a comment mentions bash-4 expansion syntax). 14 pattern-class label occurrences. Source-time emits nothing. Double-source guard verified. File length 532 >= 160.

SELF-VERIFY PROBES (all produce expected output):
- "bash scripts/verify/run-suite.sh m021 P03" -> allow
- "ls scripts/" -> allow
- sed -n with quoted M,Np and a file -> rewrite:bash scripts/util/read-range.sh file.md 10 20
- nested command substitution -> reject:nested-cmd-sub
- Two-stage chains (a && b, a | b) -> allow (per plan AD interpretation)
- Three-stage chains (a && b && c, a | b | c, a ; b ; c) -> reject:compound-chain-gt2
- cat > /tmp/x.sh heredoc then ; bash /tmp/x.sh -> rewrite:bash scripts/util/run-probe.sh /tmp/x.sh
- K1=v1 K2=v2 bash scripts/foo.sh -> rewrite:bash scripts/util/with-env.sh K1=v1 K2=v2 -- bash scripts/foo.sh
- Quoted heredoc opener <<'EOF' with $HOME body -> allow (quoted opener suppresses expansion)
- Unquoted <<EOF with $HOME body -> reject:heredoc-with-expansion
- "foo { bar" (brace in double quotes) -> reject:quoted-brace
- "${HOME}" -> allow (parameter expansion exempt)
- Redirect to command substitution with >, >>, 2>&1> -> rewrite:bash scripts/util/read-range.sh
- Trailing ; echo RC=$? and ; echo "RC=$?" both strip correctly

P04 REPLAY-CORPUS EDGE CASES TO WATCH:
1. _sc_extract_sed_n_args only matches exact leading "sed -n 'M,Np' file" shape. Does NOT handle unquoted-range form "sed -n M,Np file" or single-line "sed -n '5p' file". Confirm [M011](../../../../../milestones/M011/index.md) screenshots show quoted-range canonical form; if not, broaden the ERE.
2. _sc_extract_cat_heredoc_exec uses literal substring search for "bash <path>" after the heredoc. Paths with regex metacharacters are safe but paths containing spaces would break detection. M011 tmp paths never contain spaces, so this should be fine in practice.
3. var-inline-bash only matches when the command AFTER assignments starts with "bash ". Prefixes like "FOO=bar python ..." or "FOO=bar ./script" fall through to allow. Intentional (wrapper targets bash per P01 signature) but P04 should confirm no screenshots require broader coverage.
4. _sc_count_top_level_stages treats single "|" as one stage operator and "||" as one stage operator (the && / || branch short-circuits before single-pipe fires). Verified both 2-stage "a|b" and 3-stage "a|b|c" produce correct counts.
5. quoted-brace detector only inspects content inside double-quoted strings; literal "{" outside any quote is allowed (common in jq filters as arguments or shell brace groups). A jq filter wrapped in double quotes like ".[] | {a:.b}" WOULD be rejected. If P04 surfaces this as a false positive, the detector will need a jq-aware carve-out or a looser match (e.g., only flag "{ " with trailing space).
6. redirect-cmd-sub ERE requires an optional double-quote between the redirect operator and $(. Unquoted form like "cmd > $(foo)" does NOT match. If M011 screenshots include the unquoted form, add it to the alternation.
7. compound-chain-gt2 counter also bumps on subshell parens "(cmd1; cmd2; cmd3)" but these are tracked inside paren depth and correctly suppressed — verified with nested probe.

DEVIATIONS FROM PLAN: None structural. Helper API matches the plan comment block verbatim. The plan skeleton alternation is (\\>|\\>\\>|2\\>\\&1\\>); I reordered so >> is tried before > to avoid a greedier > match on some platforms. Semantically identical.

NO TOUCHES: .claude/settings.json (T03 territory), scripts/hooks/pre-bash-shape-guard.sh (T02 territory), scripts/verify/m021-p03-hook-integration.sh (T05 territory). scripts/verify/lib/ directory created and contains only shape-classifier.sh as specified.
