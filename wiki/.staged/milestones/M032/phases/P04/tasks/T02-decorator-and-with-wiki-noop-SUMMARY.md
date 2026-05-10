---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P04"
milestone: "M032"
provides:
  - "FR-20 build-time code-shorthand decorator stub at scripts/wiki/wiki-decorate-codes.sh (US-8 P3 stub scope per Principle XIV; --in/--glossary/--out interface; four documented regex pattern literals scanned via grep -oE union; first-occurrence-titled / subsequent-link-only rewrite per US-8 AS-2; missing-glossary fallback prints "no glossary resolved, skipping decoration" to stderr and copies --in byte-identical per AS-3 + Finding G; unresolved candidates left byte-identical per AS-1; bash 3.2 compatible parallel-scalar G_CODE_<i>/G_TITLE_<i> registry); SC-9 acceptance script tests/m032-acceptance/p0X-code-decorator.sh exercising AS-1 (three known + one unknown), AS-2 (first-titled subsequent-link-only), AS-3 (missing-glossary fallback) against /tmp/m032-p04-sc9-fixture-PID/ with trap-EXIT cleanup (3/3 PASS); --with-wiki no-op in-flight repair on scripts/lifecycle/wiki-init.sh case statement (single case arm "--with-wiki) shift ;;" with FR-11 passthrough symmetry comment block citing P03/T04 SC-5 dry-run follow-up); three project-owned verifiers tools/verify/m032-p04-decorator-shape.sh (22/22 PASS) + tools/verify/m032-p04-acceptance-shape-sc9.sh (21/21 PASS) + tools/verify/m032-p04-with-wiki-noop.sh (9/9 PASS)"
requires:
  - "P02,P03"
affects:
  - "P04/T03,P04/T04,P04/T05,M033/P05"
key_files:
  - "scripts/wiki/wiki-decorate-codes.sh,scripts/lifecycle/wiki-init.sh,tests/m032-acceptance/p0X-code-decorator.sh,tools/verify/m032-p04-decorator-shape.sh,tools/verify/m032-p04-acceptance-shape-sc9.sh,tools/verify/m032-p04-with-wiki-noop.sh"
key_decisions:
  - "FR-20,FR-11,US-8,US-8-AS-1,US-8-AS-2,US-8-AS-3,SC-9,AD-19,MEM001,MEM029,Finding-G,Principle-XIV"
patterns_established:
  - "parallel-scalar G_CODE_<i>/G_TITLE_<i> glossary registry as bash 3.2 substitute for associative arrays; pure-shell ### TERM heading parser with intermediary _h3_prefix var to disambiguate bash 3.2 parameter-expansion parser quirk on multi-hash strip (mirror of P02/T03 MEM029-class pattern); literal-string replace_first/replace_all helpers via case glob substring extraction (avoids sed escape headaches when titles contain & / parens); split-at-first-occurrence pattern (prefix_part + titled + literal_replace_all on suffix_part) to avoid nested-link failure mode where titled replacement contains the original CODE substring; sentinel-strip pattern preserves trailing newlines through command substitution (cat IN; printf X then strip X suffix); regex-union grep -oE covering M### plus [A-Z]{2,}-[A-Z0-9-]*\d+ with awk uniq-preserving-order for first-appearance candidate list; case-sensitive glossary lookup as Finding G discipline (unresolved candidates left byte-identical -- no broken-link noise); FR-11 passthrough symmetry case-arm pattern (--with-wiki) shift) for FR-15-style flag chains where downstream consumer flags are accepted as no-op rather than rejected as unknown; M032_WIKI_INIT_FORCE_EXIT=99 short-circuit verifier pattern exercising argument-parse path without firing python3/pip3/git-remote heavy work; decorator-shape verifier comment-strip pattern (grep -v hash before grepping for forbidden tokens to avoid tripping on documentation comment block); stub-shaped framing comment as load-bearing per Principle XIV (P3 stub + post-launch wiki-UX-deep proposal owner cited inline so future maintainers cannot expand scope without spec amendment)"
drill_down_paths:
  - ".orchestrator/milestones/M032/phases/P04/tasks/T02-decorator-and-with-wiki-noop-PAYLOAD.md,.orchestrator/milestones/M032/phases/P04/tasks/T02-decorator-and-with-wiki-noop-PLAN.md"
duration: "110m"
verification_result: "pass"
completed_at: "2026-05-05T04:30:07Z"
---

## What Shipped

T02 lands two surfaces on M032/P04, both narrowly scoped and orthogonal:

1. **FR-20 build-time code-shorthand decorator stub** at
   `scripts/wiki/wiki-decorate-codes.sh` — the US-8 P3 surface ships at
   stub scope per Principle XIV. The decorator interface
   (`--in <page> --glossary <glossary> --out <page>`) exists with the
   four documented regex patterns scanned, the first-occurrence-titled /
   subsequent-link-only rewrite rule per AS-2, the missing-glossary
   fallback per AS-3 + Finding G, and the byte-identical pass-through
   for unresolved candidates per AS-1. The post-launch wiki-UX-deep
   proposal owns the polish; the framing comment block at the script
   head explicitly cites that ownership so future maintainers cannot
   expand scope without a spec amendment.

2. **`--with-wiki` no-op in-flight repair** on
   `scripts/lifecycle/wiki-init.sh` — carried forward from the P03/T04
   SC-5 dry-run finding documented in P03-SUMMARY.md operator follow-ups.
   `wiki-init.sh`'s case statement was rejecting `--with-wiki` as
   unknown argument (line 78: `*) echo "FAIL: wiki-init: unknown
   argument '$1'"`), confusing operators (and `init-project.sh`'s FR-11
   passthrough) chaining the canonical
   `init --with-wiki --with-giscus --deploy` flow. The repair is two
   semantic lines: a `--with-wiki) shift ;;` case arm consuming the
   flag silently, plus a comment block citing the FR-11 passthrough
   symmetry rationale.

### Surfaces shipped

1. **`scripts/wiki/wiki-decorate-codes.sh`** (new):
   - Argument parsing: `--in <page>`, `--glossary <glossary>`,
     `--out <page>` with both space-separated and `=`-suffixed forms.
   - Glossary parsing: `### TERM` headings paired with
     immediately-following non-blank one-line definitions, capped at 80
     chars. Stored in parallel-scalar `G_CODE_<i>` / `G_TITLE_<i>`
     arrays per MEM001 (no `declare -A` on bash 3.2).
   - Candidate extraction: single `grep -oE`-pass union of `M[0-9]{3}`
     and `[A-Z]{2,}-[A-Z0-9-]*[0-9]+` (broader than the documented
     `[A-Z]{2,4}-\d+` literal to cover `DR-STACK-001`-class codes;
     `lookup_title()` case-sensitive glossary check filters spurious
     hits per Finding G).
   - First-appearance ordering preserved via
     `awk '!seen[$0]++'`; per-candidate rewrite splits the haystack at
     the first occurrence (prefix + titled-link), then runs
     literal-string `replace_all` on the suffix only with the
     link-only form. This avoids the nested-link failure mode where
     the titled replacement itself contains the original CODE
     substring.
   - Title-slot decoration uses bash literal-string substitution
     (`case "$haystack" in *"$needle"*) ${haystack%%"$needle"*}...`)
     instead of `sed` to dodge sed's special-char escape headaches when
     titles contain `&`, `/`, parens.
   - Missing-glossary fallback: prints `debug: wiki-decorate-codes: no
     glossary resolved, skipping decoration` to stderr and `cp "$IN"
     "$OUT"` per AS-3.
   - Trailing-newline preservation via sentinel pattern
     (`var="$(cmd; printf 'X')"; var="${var%X}"`) at every
     command-substitution boundary.
   - Stub-shaped framing comment block at the script head explicitly
     cites Principle XIV + post-launch wiki-UX-deep proposal ownership.

2. **`scripts/lifecycle/wiki-init.sh`** (modified, two-line repair):
   - New case arm `--with-wiki) shift ;;` inserted before the `*)`
     catch-all in the argument-parse loop (line 78 area). Comment
     block cites FR-11 passthrough symmetry rationale and the
     P03/T04 SC-5 dry-run discovery context.
   - Zero behavioral change in any non-`--with-wiki` codepath; the
     change is strictly additive (case statement widens accepted set
     without affecting any other arm).

3. **`tests/m032-acceptance/p0X-code-decorator.sh`** (new SC-9):
   - Three assertion groups: AS-1 (three known + one unknown decoded
     correctly with XYZ-999 byte-identical), AS-2 (single titled
     occurrence + remaining link-only), AS-3 (missing-glossary →
     exit 0 + diff-clean against input).
   - Throwaway-fixture pattern at `/tmp/m032-p04-sc9-fixture-$$/`
     with `trap 'rm -rf "$FIXTURE"' EXIT INT TERM` cleanup per the
     P03/T04 throwaway-fixture-protocol convention.
   - `set -uo pipefail`-safe `grep -c ... || true` pattern under
     command-substitution per the P02/T03 patterns-established gotcha
     (silent abort when count == 0 otherwise).

4. **Three project-owned verifiers** under `tools/verify/m032-p04-*`:
   - `m032-p04-decorator-shape.sh` (22/22 PASS) — interface tokens,
     four documented regex literals, rewrite-rule documentation
     tokens, missing-glossary fallback tokens, stub-framing tokens
     (P3 stub + post-launch wiki-UX-deep + Principle XIV), bash 3.2
     compatibility check (comment-stripped to avoid tripping on
     "no declare -A" comment block).
   - `m032-p04-acceptance-shape-sc9.sh` (21/21 PASS) — SC-9 / FR-20 /
     US-8 / Finding G token surface, three AS labels, trap-EXIT
     cleanup pattern, canonical `/tmp/m032-p04-sc9-fixture-$$`
     fixture path, decorator interface tokens, RESULT envelope.
   - `m032-p04-with-wiki-noop.sh` (9/9 PASS) — static-text check for
     the `--with-wiki) shift` case arm + FR-11 + P03/T04 + M032/P04/T02
     comment-block tokens, behavioral check via
     `M032_WIKI_INIT_FORCE_EXIT=99` short-circuit (rc=99 from FORCE_EXIT
     means parse path reached without "unknown argument" stderr),
     composability check (`--with-wiki --with-giscus` both consumed).

## Verification Results

- `tools/verify/m032-p04-decorator-shape.sh`: **22/22 PASS**
- `tools/verify/m032-p04-acceptance-shape-sc9.sh`: **21/21 PASS**
- `tools/verify/m032-p04-with-wiki-noop.sh`: **9/9 PASS**
- `tests/m032-acceptance/p0X-code-decorator.sh`: **3/3 PASS** (AS-1 +
  AS-2 + AS-3 all green; SC-9 acceptance contract).
- `tools/verify/m032-p02-phase-suite.sh`: **12/12 PASS** (sibling-phase
  regression baseline preserved).
- `tools/verify/m032-p03-phase-suite.sh`: **10/10 PASS** (sibling-phase
  regression baseline preserved).

## Key Decisions

- **FR-20 stub scope (Principle XIV)**: the decorator ships at
  P3-stub fidelity. No full-tree rewrite, no `mkdocs build` hook
  integration, no codebase glossary auto-derivation beyond the simple
  fallback. Polish is owned by the post-launch wiki-UX-deep proposal,
  cited verbatim in the script-head framing comment so future
  maintainers cannot expand scope without a spec amendment.
- **AS-1 / Finding G byte-identical fallback**: regex-matching
  candidates that do not resolve against the glossary are left
  byte-identical — no broken-link noise. Case-sensitive glossary
  lookup acts as the natural filter for false positives (e.g.
  `XYZ-999` matches the `[A-Z]{2,}-[A-Z0-9-]*[0-9]+` regex but the
  glossary lookup returns empty title, so the candidate is skipped).
- **AS-2 split-at-first-occurrence rewrite**: the haystack is split at
  the first occurrence of the CODE token, the titled form replaces it,
  and the link-only form replace_all runs ONLY on the right-hand
  suffix. This avoids the nested-link failure mode where the titled
  replacement (`[CODE (Title)](#anchor)`) itself contains the original
  CODE substring and would be re-matched.
- **AS-3 missing-glossary fallback**: missing or absent `--glossary`
  prints a single debug-level diagnostic to stderr and copies `--in`
  byte-identical to `--out` with exit 0. The codebase walk fallback
  documented in payload step 3 is deliberately omitted at this stub
  scope (deferred to post-launch wiki-UX-deep).
- **FR-11 passthrough symmetry case-arm pattern**: `--with-wiki) shift ;;`
  accepts the flag as no-op rather than rejecting as unknown, because
  the canonical FR-15 flag chain (`init --with-wiki --with-giscus
  --deploy`) propagates `--with-wiki` through `init-project.sh`'s
  passthrough envelope. `wiki-init.sh` itself IS the wiki-init step,
  so the flag is structurally redundant at this layer; rejecting it
  was a P03/T04 SC-5 dry-run failure-mode.

## Patterns Established

- **Parallel-scalar `G_CODE_<i>`/`G_TITLE_<i>` glossary registry** as
  bash 3.2 substitute for `declare -A` (mirrors MEM001 + MEM027
  parallel-scalar pattern); `lookup_title()` walks the registry with
  case-sensitive `=` comparison.
- **`_h3_prefix=\"### \"` intermediary variable for `${line#$_h3_prefix}`
  parameter expansion** — bash 3.2's parser confuses `${line#### }`
  with literal-`#` strip; resolved via the same intermediary-variable
  workaround established in P02/T03 (MEM029-class pattern).
- **Literal-string `replace_first`/`replace_all` helpers** via case
  glob `${haystack%%"$needle"*}` + `${haystack#*"$needle"}` substring
  extraction — avoids sed escape headaches when replacement strings
  contain `&`, `/`, parens. Cleaner than `sed` for arbitrary-content
  replacement.
- **Split-at-first-occurrence pattern** (prefix_part + titled +
  `literal_replace_all` on suffix_part only) to avoid the nested-link
  failure mode where the first replacement contains the original
  needle as substring.
- **Sentinel-strip pattern for trailing-newline preservation through
  command substitution**: `var="$(cmd; printf 'X')"; var="${var%X}"`.
  Applied at every command-substitution boundary in the rewrite
  pipeline. Required because POSIX command substitution strips
  trailing newlines.
- **Regex-union candidate extraction with first-appearance preserving
  uniq**: `grep -oE '(M[0-9]{3}|[A-Z]{2,}-[A-Z0-9-]*[0-9]+)' | awk
  '!seen[$0]++'`. Single pass over input; no per-pattern re-scan.
- **Case-sensitive glossary-lookup as Finding G discipline filter**:
  the regex extractor is intentionally broader than the documented
  patterns (covers `DR-STACK-001`-class codes); the case-sensitive
  glossary `=` check filters false positives without regex narrowing.
- **FR-11 passthrough symmetry case-arm pattern**: when a FR-15-style
  flag chain propagates a downstream-consumer flag through to a sub-tool
  that does not own the flag's behavior, the sub-tool accepts the flag
  as `shift ;;` no-op rather than rejecting as unknown. Avoids the
  confusing-fail mode where a flag chain known-good at the entry point
  surfaces a parse error inside the dispatched sub-tool.
- **`M032_WIKI_INIT_FORCE_EXIT=99` short-circuit verifier pattern**:
  exercises the argument-parse path without firing python3/pip3 +
  git-remote + mkdocs heavy work. rc=99 from the FORCE_EXIT path is
  the positive signal that the parse step reached the post-parse
  short-circuit point.
- **Decorator-shape verifier comment-strip pattern**:
  `grep -v '^[[:space:]]*#' "$DECORATOR" | grep -qE 'declare -A'`
  strips comment lines before checking for forbidden tokens, so the
  documentation comment block ("no declare -A, no process
  substitution") does not trip the check.
- **Stub-shaped framing comment as load-bearing per Principle XIV**:
  the script-head comment block explicitly cites the P3 framing,
  post-launch proposal ownership, and the non-negotiable scope
  boundaries. The decorator-shape verifier asserts these tokens are
  present so the framing cannot drift over time.

## Affects Downstream

- **P04/T03 (SC-11 doctor-no-warnings + self-application)** — inherits
  the now-fixed `--with-wiki` no-op so `init --with-wiki` end-to-end
  flows pass through `wiki-init.sh` cleanly.
- **P04/T04 (acceptance battery)** — picks up
  `tests/m032-acceptance/p0X-code-decorator.sh` as the SC-9 entry in
  the three-category aggregator (pass / skip / fail).
- **P04/T05 (phase-suite + close ceremony)** — picks up
  `tools/verify/m032-p04-decorator-shape.sh` +
  `m032-p04-acceptance-shape-sc9.sh` + `m032-p04-with-wiki-noop.sh`
  as three new gates in the P04 phase-suite aggregator.
- **M033/P05 (`init --with-wiki` paired-launch)** — inherits the
  `--with-wiki` passthrough-symmetry repair; the canonical
  `init --with-wiki --with-giscus --deploy` chain now flows end-to-end
  through both `init-project.sh` and `wiki-init.sh` without parse
  errors.
- **Post-launch wiki-UX-deep proposal** — owns the FR-20 polish
  surface (full-tree rewrite, mkdocs hook integration, codebase
  auto-derivation). The decorator interface shipped at P04/T02 is the
  contract that proposal builds against.

