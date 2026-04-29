---
schema_version: "1.0"
type: phase-plan
phase: "P03"
milestone: "M028"
goal: "Extend the shape classifier with five new pattern classes (AP-010..AP-014), add the matching ANTIPATTERNS.md entries and reject_lookup mappings, append seven verbatim corpus entries, and ship a 27-entry combined-corpus replay harness with per-finding verifiers and a hook self-conformance verifier."
demo_sentence: "A developer runs `bash tests/run-prompt-corpus-replay.sh` against the 27-entry combined corpus (20 M021 + 7 M028); the M028 classifier produces the expected verdict on every line — including AP-014's `sh -c '<body>'` body-descent on the verbatim Finding G screenshot — and the M021 strict-superset gate (FR-22) reports zero regressions."
risk: "medium"
depends_on: ["P01", "P02"]
---

## Must-Haves

### Truths

<!-- All Truth Check commands invoke project-tree verifiers directly per AD-19 and per the
     M028/P02 dogfood finding (run-probe.sh is reserved for staged throwaway probes
     under /tmp, /var/folders, or <repo>/tmp/, NOT a generic invocation harness). Every
     line is single-script-file shape (`bash scripts/verify/m028/<name>.sh`). -->

- ANTIPATTERNS.md carries the five new entries AP-010 through AP-014, each with a Description, Evidence, Remedy, and Cross-Refs section (cross-referencing the corpus fixture, the classifier, the hook reject_lookup, and the matching P04 wrapper or remediation hint).
  - Check: `bash scripts/verify/m028/p03-antipatterns-entries.sh`
- The shape classifier emits the AP-010..AP-014 reject classes verbatim for the five canonical SE-02..SE-05 + SE-09 commands (cmd-sub-in-pattern, quoted-arg-newline-hash, multiline-quoted-script, unquoted-brace-glob, xargs-sh-c-compound-body); the AP-014 verdict takes precedence over AP-009 for the `sh -c '<body>'` shape (CON-5 body-descent).
  - Check: `bash scripts/verify/m028/p03-classifier-new-classes.sh`
- The PreToolUse hook's `reject_lookup` maps every new pattern class (cmd-sub-in-pattern → grep-files.sh hint, quoted-arg-newline-hash → remediation hint, multiline-quoted-script → node-eval.sh, unquoted-brace-glob → peek-files.sh, xargs-sh-c-compound-body → peek-files.sh) and every existing M021 pattern class is preserved unchanged.
  - Check: `bash scripts/verify/m028/p03-reject-lookup-coverage.sh`
- The corpus fixture `tests/fixtures/m021-prompt-corpus.txt` carries 27 entries (20 pre-existing M021 entries unchanged + 7 new M028 entries appended verbatim); each new entry has an `EXPECTED_OUTCOME:` of either `reject:<new-class>` (5 AP-anchored), `allow` (1 negative-control regression entry), or `reject:compound-chain-gt2` (1 AP-014 boundary-case opaque-treatment entry exercising the one-level-deep recursion bound CON-5).
  - Check: `bash scripts/verify/m028/p03-corpus-shape.sh`
- The replay harness `tests/run-prompt-corpus-replay.sh` exists, parses the 27 entries, runs each through the classifier + hook end-to-end, asserts every actual verdict equals the expected verdict, and exits 0 only on 27/27 match (no regression on the 20 pre-existing entries; FR-22 / SC-8).
  - Check: `bash scripts/verify/m028/p03-replay-harness-clean.sh`
- The hook body `scripts/hooks/pre-bash-shape-guard.sh` lints clean against the M028 classifier (every non-comment, non-blank line in the resolution + dispatch blocks classifies as `allow`; AP-009 self-conformance preserved through the P03 classifier evolution).
  - Check: `bash scripts/verify/m028/finding-G-self-conformance.sh`
- Per-finding verifiers exist for B (4 sub-shapes), C (investigation-pattern reject), and G (classifier descent + self-conformance); each is a flat AD-19 single-script-file under `scripts/verify/m028/`; the verifier roll-up `scripts/verify/m028/run-all.sh` exists and invokes A, B, C, F, G in dependency-stable order.
  - Check: `bash scripts/verify/m028/p03-finding-verifiers-present.sh`

### Artifacts

- ANTIPATTERNS.md (min 280 lines, contains "AP-014: xargs sh -c Compound Body")
- scripts/verify/lib/shape-classifier.sh (min 600 lines, contains "xargs-sh-c-compound-body")
- scripts/hooks/pre-bash-shape-guard.sh (min 195 lines, contains "cmd-sub-in-pattern")
- tests/fixtures/m021-prompt-corpus.txt (min 130 lines, contains "AP-014")
- tests/run-prompt-corpus-replay.sh (min 30 lines, contains "EXPECTED_TOTAL=27")
- scripts/verify/m028/finding-B-verifier.sh (min 80 lines, contains "AP-010")
- scripts/verify/m028/finding-C-verifier.sh (min 60 lines, contains "AP-009")
- scripts/verify/m028/finding-G-classifier-verifier.sh (min 60 lines, contains "xargs-sh-c-compound-body")
- scripts/verify/m028/finding-G-self-conformance.sh (min 60 lines, contains "classify_command")
- scripts/verify/m028/run-all.sh (min 40 lines, contains "M028: 7/7")
- scripts/verify/m028/p03-antipatterns-entries.sh (min 30 lines, contains "AP-010")
- scripts/verify/m028/p03-classifier-new-classes.sh (min 60 lines, contains "xargs-sh-c-compound-body")
- scripts/verify/m028/p03-reject-lookup-coverage.sh (min 30 lines, contains "reject_lookup")
- scripts/verify/m028/p03-corpus-shape.sh (min 30 lines, contains "EXPECTED_TOTAL=27")
- scripts/verify/m028/p03-replay-harness-clean.sh (min 30 lines, contains "tests/run-prompt-corpus-replay.sh")
- scripts/verify/m028/p03-finding-verifiers-present.sh (min 30 lines, contains "run-all.sh")

### Key Links

- ANTIPATTERNS.md → tests/fixtures/m021-prompt-corpus.txt (AP-010..AP-014 cross-refs cite the corpus fixture as evidence)
- ANTIPATTERNS.md → shape-classifier.sh (AP-010..AP-014 cross-refs cite the classifier implementation)
- ANTIPATTERNS.md → pre-bash-shape-guard.sh (AP-010..AP-014 cross-refs cite the enforcement hook)
- scripts/verify/lib/shape-classifier.sh → ANTIPATTERNS.md (classifier comment header lists pattern-class labels including the new five)
- scripts/hooks/pre-bash-shape-guard.sh → shape-classifier.sh (reject_lookup case arms reference the classifier's pattern-class labels)
- tests/fixtures/m021-prompt-corpus.txt → shape-classifier.sh (corpus header references the classifier as the verdict source)
- tests/run-prompt-corpus-replay.sh → m021-prompt-corpus.txt (harness reads the corpus fixture)
- tests/run-prompt-corpus-replay.sh → shape-classifier.sh (harness sources the classifier)
- scripts/verify/m028/run-all.sh → finding-A-verifier.sh (roll-up invokes Finding A end-to-end gate from P02)
- scripts/verify/m028/run-all.sh → finding-B-verifier.sh (roll-up invokes Finding B classifier gate from P03)
- scripts/verify/m028/run-all.sh → finding-G-self-conformance.sh (roll-up invokes hook self-conformance gate from P03)
- scripts/verify/m028/finding-G-classifier-verifier.sh → shape-classifier.sh (verifier sources the classifier under test)
- scripts/verify/m028/finding-G-self-conformance.sh → pre-bash-shape-guard.sh (verifier reads the hook source under test)

## Tasks

### T01: ANTIPATTERNS Entries (AP-010 through AP-014)

See `.orchestrator/milestones/M028/phases/P03/tasks/T01-antipatterns-entries-PLAN.md`.

Produces five new entries in `ANTIPATTERNS.md` (AP-010 cmd-sub-in-pattern, AP-011 quoted-arg-newline-hash, AP-012 multiline-quoted-script, AP-013 unquoted-brace-glob, AP-014 xargs-sh-c-compound-body) following the established AP-001..AP-009 shape: Description, Observed In (M028 + screenshot date), Principle Violated, Related Constitution Constraint, Evidence (file paths + corpus IDs that will land in T04), Remedy (escape hint or wrapper path), Cross-Refs (classifier, hook, corpus, P04 wrapper). Each entry must reference the AP-IDs the cross-refs depend on by name without requiring the targets to exist at T01 close (the cross-refs become live as T02..T05 land).

### T02: Classifier Extension

See `.orchestrator/milestones/M028/phases/P03/tasks/T02-classifier-extension-PLAN.md`.

Extends `scripts/verify/lib/shape-classifier.sh::classify_command` with five new private detectors and reject branches:

1. `_sc_has_cmd_sub_in_pattern` — detects literal backtick (`\``) bytes inside the first-position regex argument to `grep`, `sed`, or `awk`. Match shape: `(grep|sed|awk)[[:space:]]+(\-[A-Za-z]+[[:space:]]+)*['"][^'"]*\`[^'"]*['"]`.
2. `_sc_has_quoted_arg_newline_hash` — detects literal newline byte followed by `#` inside a double-quoted CLI arg. Scan with quote-state tracking; on entering `"..."`, look for `\n#` sequence.
3. `_sc_has_multiline_quoted_script` — detects `(node|python|ruby|perl|sh|bash)\s+(-e|-c)\s+"..."` where the quoted body contains a literal newline. Scan the `-e`/`-c` argument's quoted body bytes for `\n`.
4. `_sc_has_unquoted_brace_glob` — detects raw `{N,M,...}` brace expansion outside any quoted region. ERE: `\{[^{}]*,[^{}]*\}` scanned outside `"..."` and `'...'` regions. AP-007 already catches the quoted form; AP-013 catches the unquoted form.
5. `_sc_has_xargs_sh_c_compound_body` (CON-5) — detects `sh -c '<body>'` (or `bash -c`) in the command, extracts the quoted body bytes (one level deep only), counts in-body connectors (`;`, `&&`, `||`, `|`) using the same quote-state tracking as `_sc_count_top_level_stages`, sums with the top-level pipe count from the outer command, and returns 0 if the combined count exceeds 2. The body-descent is bounded to one level (CON-5): if the inner `<body>` itself contains another `sh -c '...'`, treat the inner as opaque and do not recurse further.

The reject-check ordering: AP-014 runs **before** the existing top-level `_sc_count_top_level_stages > 2` check so the more specific verdict (`xargs-sh-c-compound-body`) takes precedence over `compound-chain-gt2` for the SE-09 shape (this is the load-bearing classifier-extension correctness invariant — without it, SE-09 still rejects, but as `compound-chain-gt2`, and the corpus replay verdict drifts from the AP-014 spec). AP-010..AP-013 run after AP-009 to preserve the existing M021 reject-class precedence on already-rejecting shapes.

### T03: Hook Reject Lookup Extension

See `.orchestrator/milestones/M028/phases/P03/tasks/T03-hook-reject-lookup-PLAN.md`.

Extends `scripts/hooks/pre-bash-shape-guard.sh::reject_lookup` with five new case arms mapping each new pattern class to the appropriate wrapper or remediation hint:

| pattern-class                 | wrapper.sh        | AP-ID  |
|-------------------------------|-------------------|--------|
| `cmd-sub-in-pattern`          | `grep-files.sh`   | AP-010 |
| `quoted-arg-newline-hash`     | `read-range.sh`   | AP-011 |
| `multiline-quoted-script`     | `node-eval.sh`    | AP-012 |
| `unquoted-brace-glob`         | `peek-files.sh`   | AP-013 |
| `xargs-sh-c-compound-body`    | `peek-files.sh`   | AP-014 |

Note on AP-011 wrapper choice: there is no orchestrator-side wrapper for "set arbitrary state field with embedded newline" (the spec narrates this is a remediation-hint case only — the hook surfaces the AP-ID and the operator changes their command shape). The reject_lookup table requires SOME wrapper basename per the existing reject_lookup grammar (the hook's diagnostic format is `use scripts/util/<wrapper> instead. See ANTIPATTERNS.md#<AP-ID>`); `read-range.sh` is the closest existing investigation-class wrapper and the AP-011 ANTIPATTERNS.md entry's Remedy section documents the actual fix (single-line quoted args; separate setter call) — the hint is the AP-ID pointer, not the wrapper. P04 author should NOT introduce a wrapper for AP-011 unless future evidence demands it.

The existing four arms (`nested-cmd-sub`, `compound-chain-gt2`, `heredoc-with-expansion`, `quoted-brace`) and the catch-all default arm are preserved verbatim; T03 appends only.

### T04: Corpus Extension (7 New Entries)

See `.orchestrator/milestones/M028/phases/P03/tasks/T04-corpus-extension-PLAN.md`.

Appends seven verbatim entries to `tests/fixtures/m021-prompt-corpus.txt` (existing 20 entries unchanged):

| ID | SE   | Verbatim shape                                                                                                                          | Expected verdict                            |
|----|------|------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------|
| 21 | SE-02 | `grep '^- \`bash scripts/util/' commands/dispatch.md`                                                                                  | `reject:cmd-sub-in-pattern`                 |
| 22 | SE-03 | `bash scripts/state/auto-state.sh set --last-action "T01 done\n# trailing comment"`                                                    | `reject:quoted-arg-newline-hash`            |
| 23 | SE-04 | `node -e "const x = 1;\nconsole.log(x);\n"`                                                                                            | `reject:multiline-quoted-script`            |
| 24 | SE-05 | `ls .orchestrator/milestones/M0{2,3,4,5}/M*-SUMMARY.md`                                                                                | `reject:unquoted-brace-glob`                |
| 25 | SE-09 | `find .orchestrator -name "T*-SUMMARY.md" -not -path "*/M066/*" 2>/dev/null \| head -3 \| xargs -I{} sh -c 'echo "═══ {} ═══"; head -20 "{}"'` | `reject:xargs-sh-c-compound-body`           |
| 26 | regression-N | `bash scripts/verify/run-suite.sh M028 P03` (negative control: must remain `allow` under both M021 and M028)                | `allow`                                     |
| 27 | AP-014 boundary | `find . \| xargs -I{} sh -c 'sh -c "echo nested"; head {}'` (one-level descent ONLY; inner `sh -c` opaque, only OUTER body counts; outer-body has 2 connectors `;` + `;` after the inner-opaque collapse → combined w/ 1 top-level pipe = 3 → reject) | `reject:xargs-sh-c-compound-body`         |

The seven entries together exercise: 5 AP-anchored classifier extensions (FR-8..FR-12), 1 negative-control regression (FR-22 / SC-8), and 1 boundary case for CON-5 one-level-deep descent.

**ID-26 negative-control rationale**: The five AP-anchored entries prove the new reject classes fire; the negative control proves the new classifier does not over-fire on a benign verifier-suite invocation that must remain `allow` under both M021 and M028. This single negative-control entry is the strict-superset proof at the corpus boundary (the 20 unchanged M021 entries provide the bulk regression coverage; ID-26 augments by confirming the new classifier is not greedier on a structurally similar shape).

**ID-27 boundary-case rationale**: SE-09 itself exercises a single-level `xargs sh -c '...'` body. ID-27 exercises a *nested* `sh -c '...sh -c "..."...'` body to lock CON-5 (one-level-deep descent only; the inner `sh -c` is opaque to the connector counter). The expected verdict is still `reject:xargs-sh-c-compound-body` because the outer body's connectors plus the top-level pipe still exceed 2 — but with the inner `sh -c` treated as opaque, not double-counted.

The newline byte in IDs 22 + 23 is encoded as the literal two-byte `\n` sequence (`\` + `n`) inside the `INPUT:` line, matching the existing corpus convention from ID-01 / ID-15 (heredoc bodies). The replay harness's `printf '%b'` decode (line 76 of `scripts/verify/replay-prompt-corpus.sh`, preserved in T05's harness) converts `\n` to a real newline before classification.

The Unicode box-drawing bytes (U+2550 `═`) in ID-25 round-trip through the corpus as literal UTF-8 bytes (3 bytes each: `0xE2 0x95 0x90`); the corpus is UTF-8 throughout. Per spec Edge Cases: "the corpus loader reads lines as raw bytes; comment annotations use `#` only at line start" — preserved.

### T05: Replay Harness + Per-Finding Verifiers + Self-Conformance

See `.orchestrator/milestones/M028/phases/P03/tasks/T05-replay-harness-and-verifiers-PLAN.md`.

Three deliverables:

1. **`tests/run-prompt-corpus-replay.sh`** — new top-level harness. EXPECTED_TOTAL=27. Sources the classifier from `scripts/verify/lib/shape-classifier.sh`, parses the 27-entry corpus, runs each entry through the classifier + the hook end-to-end (synthetic stdin JSON), asserts actual == expected verdict, prints `WOULD_PROMPT=N/27` (where N must be 0 under the hardened classifier), and exits 0 only on 27/27 match. The harness is structurally identical to the existing `scripts/verify/replay-prompt-corpus.sh` (which stays in tree as the M021/SC-1 historical artifact) but parameterized for the M028-extended count.

2. **Per-finding verifiers** — five new flat scripts under `scripts/verify/m028/`:
   - `finding-B-verifier.sh` — exercises the four B-family entries (IDs 21–24) end-to-end through the hook; asserts each emits `REJECT:` + the expected AP-ID on stderr and exit 2.
   - `finding-C-verifier.sh` — proves the SE-06 investigation-compound shape (`grep ...; echo "---"; grep ...`) still rejects under M028 as `compound-chain-gt2` (AP-009 untouched; CON-7 strict-superset).
   - `finding-G-classifier-verifier.sh` — exercises the verbatim Finding G command through the M028 classifier; asserts the verdict is `reject:xargs-sh-c-compound-body` (NOT `reject:compound-chain-gt2`); proves AP-014 takes precedence per CON-5.
   - `finding-G-self-conformance.sh` — reads `scripts/hooks/pre-bash-shape-guard.sh`, sources the M028 classifier, runs `classify_command` on every non-comment non-blank line in the resolution + dispatch blocks (the same scope T01/P02 used for `p02-hook-self-conformance.sh`), asserts every line returns `allow` under the M028-extended classifier (FR-21 self-conformance through P03 evolution).
   - `run-all.sh` — roll-up that invokes all 7 per-finding verifiers (A and F from P02; B, C, G-classifier, G-self-conformance from P03; D and E are P04 deliverables — `run-all.sh` reports 5/7 PASS in P03 and 7/7 PASS once P04 lands; the summary line format is `M028: <pass>/7 findings verified`).

3. **Five plan-level verifiers** for the P03 truth Checks (`p03-antipatterns-entries.sh`, `p03-classifier-new-classes.sh`, `p03-reject-lookup-coverage.sh`, `p03-corpus-shape.sh`, `p03-replay-harness-clean.sh`, `p03-finding-verifiers-present.sh` — six total). Each is a flat AD-19 single-script-file under `scripts/verify/m028/`, bash 3.2 + POSIX-sh-safe, no jq.

## Task Dependencies

```
T01 (ANTIPATTERNS entries) ──┐
                             ├──→ T03 (hook reject_lookup)  ──┐
T02 (classifier detectors) ──┤                                ├──→ T05 (harness + verifiers)
                             └──→ T04 (corpus 7 entries)    ──┘
```

T01 and T02 are independent and can be authored in parallel (T01 is documentation; T02 is classifier code). T03 depends on T01 (it cites AP-IDs in the case arms) and T02 (it case-matches against the new pattern-class labels). T04 depends on T01 (corpus comment annotations cite AP-IDs) and T02 (corpus expected verdicts must match the actual classifier output). T05 depends on T03 + T04 (it exercises the hook + corpus end-to-end). Linear-safe execution order: T01 → T02 → T03 → T04 → T05.

## Files Likely Touched

- ANTIPATTERNS.md (modify — append AP-010 through AP-014, ~80 lines added)
- scripts/verify/lib/shape-classifier.sh (modify — add 5 private detectors and 5 new reject branches in `classify_command`, ~150 lines added)
- scripts/hooks/pre-bash-shape-guard.sh (modify — add 5 new case arms in `reject_lookup`, ~10 lines added)
- tests/fixtures/m021-prompt-corpus.txt (modify — append 7 entries with comment annotations, ~50 lines added)
- tests/run-prompt-corpus-replay.sh (create — ~165 lines, structurally derived from `scripts/verify/replay-prompt-corpus.sh`)
- scripts/verify/m028/finding-B-verifier.sh (create — ~120 lines)
- scripts/verify/m028/finding-C-verifier.sh (create — ~80 lines)
- scripts/verify/m028/finding-G-classifier-verifier.sh (create — ~80 lines)
- scripts/verify/m028/finding-G-self-conformance.sh (create — ~100 lines)
- scripts/verify/m028/run-all.sh (create — ~80 lines)
- scripts/verify/m028/p03-antipatterns-entries.sh (create — ~50 lines)
- scripts/verify/m028/p03-classifier-new-classes.sh (create — ~100 lines)
- scripts/verify/m028/p03-reject-lookup-coverage.sh (create — ~60 lines)
- scripts/verify/m028/p03-corpus-shape.sh (create — ~50 lines)
- scripts/verify/m028/p03-replay-harness-clean.sh (create — ~40 lines)
- scripts/verify/m028/p03-finding-verifiers-present.sh (create — ~50 lines)

## Notes

### Plan-time discoveries

- **Spec-vs-disk corpus count drift**: The spec, roadmap, and SC-1 cite "21 M021 entries" + "28-entry combined corpus"; the actual on-disk corpus has 20 entries (`grep -c '^ID: ' tests/fixtures/m021-prompt-corpus.txt` returns 20). The existing M021 SC-1 harness `scripts/verify/replay-prompt-corpus.sh` hardcodes `EXPECTED_TOTAL=20`. P03 plan resolves this by shipping a **27-entry combined corpus** (20 M021 + 7 M028); FR-22 / SC-8 strict-superset semantics are preserved (all 20 M021 entries produce identical verdicts). The `tests/run-prompt-corpus-replay.sh` new harness uses `EXPECTED_TOTAL=27`. The spec's "21" / "28" wording is captured here as a documented discrepancy; no spec edit is required because the strict-superset invariant (no regression on existing entries; new entries land verbatim) is the load-bearing claim, not the absolute count.

- **AP-014 vs AP-009 verdict precedence (load-bearing)**: The verbatim Finding G command (`find ... | head | xargs sh -c 'echo; head'`) currently classifies as `reject:compound-chain-gt2` (AP-009) because `_sc_count_top_level_stages` counts the two top-level pipes (find→head, head→xargs) plus the trailing xargs token = 3 stages. After AP-014 lands, the verdict must change to `reject:xargs-sh-c-compound-body` so the corpus expected-verdict matches the spec's SC-6 invariant. This requires AP-014 to run **before** the AP-009 top-level-count check in `classify_command`. T02's plan documents this ordering explicitly.

- **Plan-time empirical classifier probes**: The following commands were run at plan-authoring time against `scripts/verify/lib/shape-classifier.sh::classify_command` (per CLAUDE.md plan-time classifier-shape pre-validation discipline) — verdicts captured here as the contract T02 must preserve or extend:
  - `bash scripts/verify/m028/finding-B-verifier.sh` → `allow` (Truth Check shape is safe).
  - `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M028/phases/P03` → `allow` (must-have verifier shape is safe).
  - SE-09 verbatim: `find ... | head -3 | xargs -I{} sh -c "echo a; head -20 b"` → `reject:compound-chain-gt2` (AP-009 fires today; AP-014 must take precedence after T02).
  - SE-05 verbatim: `ls .orchestrator/milestones/M0{2,3,4,5}/M*-SUMMARY.md` → `allow` (gap; AP-013 closes it).
  - SE-04 verbatim: `node -e "const x = 1; console.log(x);"` → `allow` (gap; AP-012 closes it).
  - SE-06 verbatim: `grep -n classify_command scripts/verify/lib/shape-classifier.sh` → `allow` (single-stage grep is correctly allowed; CON-7 baseline).

- **`tests/run-prompt-corpus-replay.sh` does not exist** — confirmed via `find tests -name "*replay*corpus*" -type f` returning only the corpus fixture. The spec/roadmap reference this path; T05 creates it. The existing `scripts/verify/replay-prompt-corpus.sh` stays in tree as the M021/SC-1 historical artifact (it hardcodes `EXPECTED_TOTAL=20` and the M021 contract is "must replay clean against the M021 baseline corpus alone"; the M028 harness is parameterized for the extended count).

### Verification authoring discipline

All `## Verification` sections in T01..T05 plans:
- Invoke project-tree verifiers directly via `bash scripts/verify/m028/<name>.sh` (NEVER through `scripts/util/run-probe.sh`; that wrapper is reserved for staged throwaway probes under `/tmp`/`/var/folders`/`<repo>/tmp/`).
- Contain ONLY executable check commands. Documenting expected output goes in `## Expected Output` or `## Notes` sections (the `auto-loop.sh --step=V` parser eval's every line in fenced blocks under `## Verification` as a shell command; a parser-side defensive verdict-prefix skip is in place at `auto-loop.sh:340-353` but plans do not depend on it).
- Use single-script-file shape per AD-19 — no inline compound bash, no plain subshells, no `$(...)` containing pipes.

### Shape-guard self-conformance carryover

Per CON-3 / FR-21 / SC-9, the shape-guard hook `scripts/hooks/pre-bash-shape-guard.sh` itself must not contain a compound chain exceeding 2 connectors. T03 adds five new case arms — each arm is a single statement (`printf '... AP-NNN\n'`), no chain. The case statement as a whole is `;;`-delimited but the AP-009 classifier is ordering-stable: case-statement bodies have always counted by individual command-line shape, not the case-as-a-whole. P02/T01 codified this in the resolution-block self-conformance scope; P03/T05's `finding-G-self-conformance.sh` extends the scope to include the new reject_lookup arms.

### Helper-function carve-out (AD-19)

Per the M028/P02 dogfood finding (T03/T04/T05 each used the carve-out), bash function bodies are NOT scanned by the AP-009 inline-command-shape classifier. T05's `finding-G-self-conformance.sh` plan documents this explicitly: the verifier may define `compute_classification() { local out; out="$(classify_command "$1" 2>/dev/null)"; echo "$out"; }` at top-of-script and call it inline without triggering the classifier on the function-body's `$(...)` pattern. This carve-out is load-bearing for the verifier's per-line scan; T05 cites it in a comment block.

### Bash 3.2 + POSIX sh compatibility

All five tasks ship bash 3.2 + POSIX-sh-safe code per CON-2:
- No `declare -A` / associative arrays — use case statements or parallel indexed arrays.
- No `mapfile` / `readarray` — use `while IFS= read -r line; do ...; done < tmp.txt`.
- No `<<<` here-strings unless guarded.
- No process substitution (`<(...)`, `>(...)`).
- T02's new `_sc_*` private detectors follow the existing pattern in `scripts/verify/lib/shape-classifier.sh` — character-by-character scanning with quote-state and depth tracking, no regex-feature reliance beyond the bash 3.2 `[[ =~ ]]` ERE subset already used.
