---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P04"
milestone: "M031"
name: "Drift fix on commands/evaluate.md + references/tier-definitions.md, auto_proceed default + CHANGELOG entry, SC-9 + SC-10 acceptance tests"
depends_on: []
---

## Prerequisites

- `commands/evaluate.md` exists at the project root and contains the legacy line `- Direct routing to the host runtime's native workflow with no orchestrator overhead` somewhere in the Tier A description block (currently around line 22) AND the legacy line `- Do NOT create any orchestrator directory structure (FR-003)` (currently around line 139). Confirmed at plan-authoring time via `grep -n` (see Description below).
- `references/tier-definitions.md` exists at the project root and contains the legacy line `- Direct routing to the host runtime's native workflow with no orchestrator overhead` somewhere in the Tier A description block (currently around line 22). Confirmed at plan-authoring time via `grep -n`.
- `templates/orchestrator-config-default.yml` exists at the project root and currently shows `auto_proceed: true` at line 27. (The flip from `false` to `true` already landed in the working tree at session entry — T01's job is to commit that state cleanly with the surrounding doc-block update naming the M031 flip + an explicit reference to the `quick_knowledge_token_budget` knob so the doctor amendment in T02 can grep for the knob name as the M031-config detector.)
- `CHANGELOG.md` exists at the project root with an `## [Unreleased]` section at the top.
- `tests/m031-acceptance/` directory exists (P00–P03 already populated it).
- `tools/verify/` directory exists (P01–P03 already populated it).
- `scripts/verify/check-must-haves.sh` exists and accepts a phase DIRECTORY (not a plan filename) as its single argument.

## Description

T01 ships the **prose-level** closures for M031:

1. **`commands/evaluate.md` drift fix (FR-14)** — remove the two pre-M024 phrasings that contradict the post-M024 routing table:
   - Around line 22 (the line `- Direct routing to the host runtime's native workflow with no orchestrator overhead`) — delete this bullet from whatever Tier A description block it sits under, or reword the entire block so the canonical Tier A description reads "single dispatch with knowledge + compression via the Quick profile."
   - Around line 139 (the line `- Do NOT create any orchestrator directory structure (FR-003)`) — delete this bullet AND the surrounding paragraph that instructs the agent to "route directly to standard spec-kit commands." The replacement prose says: "Tier A invokes `orchestrator:dispatch` with the Quick profile (knowledge + compression unconditional per M031). `.orchestrator/` (config, knowledge, integrations) is always present; only `.orchestrator/milestones/M###/` scaffolding is conditional on Tier B/C."
   - Final state: post-fix file contains zero matches for `no orchestrator overhead` and zero matches for `Do NOT create any orchestrator directory`. The post-fix file contains exactly one canonical Tier A description.

2. **`references/tier-definitions.md` drift fix (FR-15)** — remove the matching `- Direct routing to the host runtime's native workflow with no orchestrator overhead` bullet (around line 22) and reconcile the Tier A entry so it says: "single dispatch with knowledge + compression via the Quick profile. `.orchestrator/` (config, knowledge, integrations) is always present; only `.orchestrator/milestones/M###/` scaffolding is conditional." Final state: post-fix file contains zero matches for `no orchestrator overhead`; canonical Tier A description present; explicit statement that `.orchestrator/` is always present.

3. **`templates/orchestrator-config-default.yml` flip confirmation (FR-16, AD-8)** — the file currently shows `auto_proceed: true` at line 27 (already flipped in the working tree). T01 commits that state clean. T01 ALSO amends the surrounding doc-comment block (lines 14–26 of the existing file) to:
   - Name M031 explicitly as the flip's owner.
   - Reference the `quick_knowledge_token_budget` knob immediately above or below the `auto_proceed` line so the doctor amendment in T02 can grep for both literal substrings as a single contiguous block.
   - Document the recovery path: "operators who prefer the pre-M031 behavior should add an explicit `auto_proceed: false` line to their `.orchestrator/config.yml`."

4. **`CHANGELOG.md` M031 entry (AD-9 CHANGELOG portion)** — under the existing `## [Unreleased]` section, add an `### M031 — right-sized entry` heading (or equivalent) with bullet points naming the **compound** behavioral change:
   - The `auto_proceed` default flip from `false` to `true`.
   - The unconditional Quick-profile knowledge + compression injection (the pre-M031 `commands/dispatch.md:21` skip branch is gone).
   - Both literal strings `auto_proceed` and `quick_knowledge_token_budget` MUST appear in the entry.
   - The literal string `compound` MUST appear in the entry (single co-located note rather than two separate items per the AD-9 reasoning).
   - The recovery path: "add `auto_proceed: false` to `.orchestrator/config.yml` to keep the pre-M031 behavior."

5. **SC-9 doc-drift verifier** — author `tests/m031-acceptance/doc-drift-verifier.sh` (FR-17). POSIX-bash per CON-6 / DC-7 (no `[[ ]]`, no bash 4 features, no `declare -A`). Asserts:
   - Zero matches for `no orchestrator overhead` in `commands/evaluate.md`.
   - Zero matches for `Do NOT create any orchestrator directory` in `commands/evaluate.md`.
   - At least one match for the canonical Tier A descriptor (e.g. `Quick profile` or `knowledge + compression`) in `commands/evaluate.md`.
   - Zero matches for `no orchestrator overhead` in `references/tier-definitions.md`.
   - At least one match for `Quick profile` in `references/tier-definitions.md`.
   - Emits `RESULT: SC-9 pass` on success; exits 0. Emits `RESULT: SC-9 fail` and exits 1 on any assertion failure.

6. **SC-10 auto-proceed default test** — author `tests/m031-acceptance/test-auto-proceed-default.sh`. Asserts:
   - `grep -c '^auto_proceed: true' templates/orchestrator-config-default.yml` returns >= 1.
   - `grep -c 'auto_proceed' CHANGELOG.md` returns >= 1.
   - `grep -c 'quick_knowledge_token_budget' CHANGELOG.md` returns >= 1.
   - `grep -c 'compound' CHANGELOG.md` returns >= 1.
   - Emits `RESULT: SC-10 pass` on success; exits 0.

7. **Six shape verifiers** under `tools/verify/`:
   - `m031-p04-evaluate-md-drift-shape.sh` — asserts the absence-checks above against `commands/evaluate.md`.
   - `m031-p04-tier-definitions-drift-shape.sh` — asserts the absence-checks above against `references/tier-definitions.md`.
   - `m031-p04-auto-proceed-default-shape.sh` — asserts `auto_proceed: true` literal at the start of a line in the template.
   - `m031-p04-changelog-shape.sh` — asserts the M031 entry exists with the four required substrings.
   - `m031-p04-test-doc-drift-shape.sh` — asserts the SC-9 test exists, executable, contains the two prohibited-phrasing literals, and references both target files.
   - `m031-p04-test-auto-proceed-shape.sh` — asserts the SC-10 test exists, executable, references the template + CHANGELOG.

   All shape verifiers use AD-19 single-script-file shape (no inline compound bash, no process substitution, no plain subshells in the verifier body), emit `SUMMARY: <basename> pass=N fail=M`, and exit 0 iff `fail == 0`.

## Steps

1. **Plan-time prerequisite confirmation** — at plan-authoring time, the planner ran `grep -n "no orchestrator overhead" commands/evaluate.md` and `grep -n "Do NOT create any orchestrator directory" commands/evaluate.md` and `grep -n "no orchestrator overhead" references/tier-definitions.md` and confirmed the legacy phrasings are present (line 22 in evaluate.md for the first phrasing, line 139 in evaluate.md for the second, line 22 in tier-definitions.md for the third). The executor at task-time should re-confirm these exist before editing — if any phrasing is already absent, the file may have been partially fixed in a prior session and the executor should skip that specific Edit but still confirm the post-fix shape via the SC-9 verifier.

2. **Edit `commands/evaluate.md`** to remove the legacy phrasings.
   - Use the `Read` tool to see the current file shape around lines 14–30 (the input-shape table block) and around lines 100–145 (the pre-M024 Tier A routing block).
   - For the line `- Direct routing to the host runtime's native workflow with no orchestrator overhead` near line 22: locate the surrounding bullet block. If the block describes Tier A, replace the bullet with `- Single dispatch with knowledge + compression via the Quick profile (M031: build-context.sh always runs; the Quick profile scopes traversal to 1-hop touched-file hits)`. If the block describes a different tier and the legacy line is mis-attributed, delete the bullet outright.
   - For the line `- Do NOT create any orchestrator directory structure (FR-003)` near line 139: locate the surrounding paragraph or bullet list. Replace the entire pre-M024 block with prose that says: "Tier A invokes `orchestrator:dispatch` with the Quick profile (knowledge + compression unconditional per M031). `.orchestrator/` (config, knowledge, integrations) is always present; only `.orchestrator/milestones/M###/` scaffolding is conditional on Tier B/C."
   - Verify post-edit: the file no longer contains the literal substrings `no orchestrator overhead` OR `Do NOT create any orchestrator directory`.

3. **Edit `references/tier-definitions.md`** to remove the legacy phrasing.
   - Use the `Read` tool to see the current file shape around lines 14–35 (the Tier A description block).
   - For the line `- Direct routing to the host runtime's native workflow with no orchestrator overhead` near line 22: replace the bullet with `- Single dispatch with knowledge + compression via the Quick profile (M031: build-context.sh always runs)`.
   - Add a sentence (in the Tier A entry, either above the bullet list or at the end of the block): "`.orchestrator/` (config, knowledge, integrations) is always present; only `.orchestrator/milestones/M###/` scaffolding is conditional on Tier B/C."
   - Verify post-edit: the file no longer contains `no orchestrator overhead`; both `Quick profile` and `.orchestrator/` are present.

4. **Confirm + amend `templates/orchestrator-config-default.yml`**.
   - Use the `Read` tool to see the current file content (especially lines 14–30).
   - Confirm `auto_proceed: true` is the active value at line 27. (If for any reason the value is not `true`, change it to `true`.)
   - Update the comment block immediately preceding the `auto_proceed` line (lines 14–26) so it reads as a single contiguous block naming both `auto_proceed` AND `quick_knowledge_token_budget` AND M031. Add a comment line of approximately this shape:

     ```
     # M031 (right-sized entry, 2026-05-01) flipped this default from false
     # to true and made Quick-profile knowledge injection unconditional. Set
     # quick_knowledge_token_budget below to tune the Quick-profile knowledge
     # ceiling. Operators who prefer the pre-M031 behavior should add an
     # explicit `auto_proceed: false` line to their .orchestrator/config.yml.
     ```

   - If `quick_knowledge_token_budget` is not already present in the file (P01 should have added it), append a stanza below the `auto_proceed` line:

     ```yaml
     # quick_knowledge_token_budget — advisory ceiling for Quick-profile
     # knowledge injection (enforced by M018 tier-2 snip). Default 800.
     quick_knowledge_token_budget: 800
     ```

   - Final state: the file contains both `auto_proceed: true` AND `quick_knowledge_token_budget` literals AND a comment naming `M031`.

5. **Add the M031 entry to `CHANGELOG.md`**.
   - Use the `Read` tool to see the current `## [Unreleased]` section.
   - Insert under `## [Unreleased]` (or directly below it) a new sub-section with this content (verbatim):

     ```markdown
     ### Changed (M031 — right-sized entry)
     - Compound behavioral change: `auto_proceed` config default flips from `false` to `true`, AND Quick-profile dispatches now inject knowledge + compression unconditionally (the pre-M031 `commands/dispatch.md:21` skip branch is gone). Operators upgrading from pre-M031 see both changes simultaneously on first post-M031 dispatch.
     - New config knob `quick_knowledge_token_budget` (default 800 tokens) tunes the Quick-profile knowledge ceiling; M018 tier-2 snip enforces it as an advisory ceiling per AD-13.
     - New config knob `entry_routing_confidence_floor` (default 0.7) gates the `orchestrator:do <task>` universal-entry routing; verdicts below the floor produce an explicit Tier A vs Tier B prompt rather than a silent guess.
     - Recovery: operators who prefer the pre-M031 auto-proceed behavior should add an explicit `auto_proceed: false` line to their `.orchestrator/config.yml`.
     ```

   - Final state: the CHANGELOG contains the literals `M031` AND `auto_proceed` AND `quick_knowledge_token_budget` AND `compound` (note: the word "compound" appears in the first bullet's "Compound behavioral change" phrasing).

6. **Author `tests/m031-acceptance/doc-drift-verifier.sh`** (≥ 40 lines, executable, POSIX-bash). Body shape:

   ```bash
   #!/usr/bin/env bash
   # tests/m031-acceptance/doc-drift-verifier.sh
   # M031/P04/T01 — SC-9 doc-drift verifier (FR-17).
   #
   # Asserts commands/evaluate.md and references/tier-definitions.md
   # contain the canonical Tier A description and zero matches for the
   # pre-M024 prohibited phrasings. POSIX-bash per CON-6 / DC-7 — runs
   # under bash 3.2 + dash + sh without modification.
   #
   # Emits RESULT: SC-9 pass (exit 0) or RESULT: SC-9 fail (exit 1).

   set -u
   PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   EVAL_MD="$PROJECT_ROOT/commands/evaluate.md"
   TIER_DEF="$PROJECT_ROOT/references/tier-definitions.md"

   pass=0
   fail=0

   check_absent() {
     # $1 file, $2 needle, $3 label
     if grep -q -F -- "$2" "$1"; then
       printf 'FAIL: %s -- %s contains "%s"\n' "$3" "$1" "$2"
       fail=$((fail + 1))
     else
       printf 'PASS: %s\n' "$3"
       pass=$((pass + 1))
     fi
   }

   check_present() {
     # $1 file, $2 needle, $3 label
     if grep -q -F -- "$2" "$1"; then
       printf 'PASS: %s\n' "$3"
       pass=$((pass + 1))
     else
       printf 'FAIL: %s -- %s missing "%s"\n' "$3" "$1" "$2"
       fail=$((fail + 1))
     fi
   }

   check_absent  "$EVAL_MD"  "no orchestrator overhead"          "evaluate.md drift phrasing 1"
   check_absent  "$EVAL_MD"  "Do NOT create any orchestrator directory" "evaluate.md drift phrasing 2"
   check_present "$EVAL_MD"  "Quick profile"                     "evaluate.md canonical Tier A descriptor"
   check_absent  "$TIER_DEF" "no orchestrator overhead"          "tier-definitions.md drift phrasing"
   check_present "$TIER_DEF" "Quick profile"                     "tier-definitions.md canonical Tier A descriptor"

   printf 'SC-9 totals: pass=%d fail=%d\n' "$pass" "$fail"
   if [ "$fail" -eq 0 ]; then
     printf 'RESULT: SC-9 pass\n'
     exit 0
   fi
   printf 'RESULT: SC-9 fail\n'
   exit 1
   ```

   `chmod +x tests/m031-acceptance/doc-drift-verifier.sh`.

7. **Author `tests/m031-acceptance/test-auto-proceed-default.sh`** (≥ 30 lines, executable). Body shape:

   ```bash
   #!/usr/bin/env bash
   # tests/m031-acceptance/test-auto-proceed-default.sh
   # M031/P04/T01 — SC-10 auto-proceed default test.
   #
   # Asserts auto_proceed: true is the committed default and CHANGELOG.md
   # names the M031 compound flip per AD-9.
   #
   # Emits RESULT: SC-10 pass (exit 0) or RESULT: SC-10 fail (exit 1).

   set -u
   PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   TEMPLATE="$PROJECT_ROOT/templates/orchestrator-config-default.yml"
   CHANGELOG="$PROJECT_ROOT/CHANGELOG.md"

   pass=0
   fail=0

   check_present() {
     if grep -q -F -- "$2" "$1"; then
       printf 'PASS: %s\n' "$3"
       pass=$((pass + 1))
     else
       printf 'FAIL: %s -- %s missing "%s"\n' "$3" "$1" "$2"
       fail=$((fail + 1))
     fi
   }

   check_present "$TEMPLATE"  "auto_proceed: true"          "auto_proceed: true literal in template"
   check_present "$CHANGELOG" "M031"                        "CHANGELOG names M031"
   check_present "$CHANGELOG" "auto_proceed"                "CHANGELOG names auto_proceed"
   check_present "$CHANGELOG" "quick_knowledge_token_budget" "CHANGELOG names quick_knowledge_token_budget"
   check_present "$CHANGELOG" "compound"                    "CHANGELOG names the compound flip"

   printf 'SC-10 totals: pass=%d fail=%d\n' "$pass" "$fail"
   if [ "$fail" -eq 0 ]; then
     printf 'RESULT: SC-10 pass\n'
     exit 0
   fi
   printf 'RESULT: SC-10 fail\n'
   exit 1
   ```

   `chmod +x tests/m031-acceptance/test-auto-proceed-default.sh`.

8. **Author the six shape verifiers under `tools/verify/`**. Each follows the AD-19 single-script-file shape: a header comment block (≥ 15 lines documenting the gate's contract), a `pass=0; fail=0` accumulator, a sequence of `check_literal` / `check_absent` assertions using `grep -qF -- "$needle" "$file"`, a final `printf 'SUMMARY: <basename> pass=%d fail=%d\n' "$pass" "$fail"` line, and `exit 0` iff `fail == 0`. NO inline compound bash, NO process substitution, NO plain subshells, NO `$(...)` containing pipes inside conditionals (BSD grep on macOS rejects bare `--task` / `--no-prompt-mode` flag-tokens unless the `-q -F -- "$needle"` form is used — match the P03 helper convention exactly).

   For each verifier below, use the M031/P02/P03 verifier shape as the canonical template (`tools/verify/m031-p03-do-md-shape.sh` is a good reference). Each verifier MUST be ≥ its declared min-line count from the phase plan's Artifacts section.

   - **`tools/verify/m031-p04-evaluate-md-drift-shape.sh`** (≥ 25 lines):
     - `check_absent commands/evaluate.md "no orchestrator overhead"`
     - `check_absent commands/evaluate.md "Do NOT create any orchestrator directory"`
     - `check_present commands/evaluate.md "Quick profile"`

   - **`tools/verify/m031-p04-tier-definitions-drift-shape.sh`** (≥ 25 lines):
     - `check_absent references/tier-definitions.md "no orchestrator overhead"`
     - `check_present references/tier-definitions.md "Quick profile"`
     - `check_present references/tier-definitions.md ".orchestrator/"`

   - **`tools/verify/m031-p04-auto-proceed-default-shape.sh`** (≥ 20 lines):
     - `check_present templates/orchestrator-config-default.yml "auto_proceed: true"`
     - `check_present templates/orchestrator-config-default.yml "M031"`
     - `check_present templates/orchestrator-config-default.yml "quick_knowledge_token_budget"`

   - **`tools/verify/m031-p04-changelog-shape.sh`** (≥ 25 lines):
     - `check_present CHANGELOG.md "M031"`
     - `check_present CHANGELOG.md "auto_proceed"`
     - `check_present CHANGELOG.md "quick_knowledge_token_budget"`
     - `check_present CHANGELOG.md "compound"`

   - **`tools/verify/m031-p04-test-doc-drift-shape.sh`** (≥ 20 lines):
     - `check_present tests/m031-acceptance/doc-drift-verifier.sh "SC-9"`
     - `check_present tests/m031-acceptance/doc-drift-verifier.sh "evaluate.md"`
     - `check_present tests/m031-acceptance/doc-drift-verifier.sh "tier-definitions.md"`
     - `check_present tests/m031-acceptance/doc-drift-verifier.sh "no orchestrator overhead"` (the test asserts ABSENCE in the targets but the test file ITSELF must contain the prohibited phrasing as a `grep -qF` needle — this is the verifier's needle inventory, not a doc violation)
     - The shape verifier is itself reading prose surfaces; ensure the absence-check on the target files is left to the SC-9 verifier itself, not duplicated here.

   - **`tools/verify/m031-p04-test-auto-proceed-shape.sh`** (≥ 20 lines):
     - `check_present tests/m031-acceptance/test-auto-proceed-default.sh "SC-10"`
     - `check_present tests/m031-acceptance/test-auto-proceed-default.sh "auto_proceed"`
     - `check_present tests/m031-acceptance/test-auto-proceed-default.sh "CHANGELOG"`

   `chmod +x tools/verify/m031-p04-*.sh` for the six shape verifiers above.

9. **Run each new verifier locally to confirm exit 0 + pass=K fail=0**:

   ```bash
   bash tests/m031-acceptance/doc-drift-verifier.sh
   ```

   ```bash
   bash tests/m031-acceptance/test-auto-proceed-default.sh
   ```

   ```bash
   bash tools/verify/m031-p04-evaluate-md-drift-shape.sh
   ```

   ```bash
   bash tools/verify/m031-p04-tier-definitions-drift-shape.sh
   ```

   ```bash
   bash tools/verify/m031-p04-auto-proceed-default-shape.sh
   ```

   ```bash
   bash tools/verify/m031-p04-changelog-shape.sh
   ```

   ```bash
   bash tools/verify/m031-p04-test-doc-drift-shape.sh
   ```

   ```bash
   bash tools/verify/m031-p04-test-auto-proceed-shape.sh
   ```

10. **Commit T01 deliverables** with a multi-line message via `-F` (NOT inline HEREDOC — the AP-008 shape-guard rejects the heredoc-with-expansion form per CLAUDE.md). Use the `Write` tool to author a commit message file at `/tmp/m031-p04-t01-commit-msg.txt`, then `git commit -F /tmp/m031-p04-t01-commit-msg.txt`. Suggested commit subject: `M031/P04/T01: drift fix on evaluate.md + tier-definitions.md, M031 CHANGELOG entry, SC-9 + SC-10 acceptance tests`.

## Must-Haves

This task addresses the following Must-Haves from `P04-PLAN.md`:
- "`commands/evaluate.md` post-fix contains zero matches for the pre-M024 Tier A 'no orchestrator overhead' / 'Do NOT create any orchestrator directory' phrasings" (Truth #1; Check via `m031-p04-evaluate-md-drift-shape.sh`)
- "`references/tier-definitions.md` post-fix matches `commands/evaluate.md` and explicitly states that `.orchestrator/` (config, knowledge, integrations) is always present" (Truth #2; Check via `m031-p04-tier-definitions-drift-shape.sh`)
- "`templates/orchestrator-config-default.yml` declares `auto_proceed: true` as the active default" (Truth #3; Check via `m031-p04-auto-proceed-default-shape.sh`)
- "`CHANGELOG.md` carries an M031 entry naming the compound behavioral change" (Truth #4; Check via `m031-p04-changelog-shape.sh`)
- "`tests/m031-acceptance/doc-drift-verifier.sh` (SC-9, FR-17) exists, is executable, and exits 0" (Truth #7; Check via `m031-p04-test-doc-drift-shape.sh`)
- "`tests/m031-acceptance/test-auto-proceed-default.sh` (SC-10) exists, is executable, and exits 0" (Truth #8; Check via `m031-p04-test-auto-proceed-shape.sh`)

## Verification

```bash
bash tests/m031-acceptance/doc-drift-verifier.sh
```

```bash
bash tests/m031-acceptance/test-auto-proceed-default.sh
```

```bash
bash tools/verify/m031-p04-evaluate-md-drift-shape.sh
```

```bash
bash tools/verify/m031-p04-tier-definitions-drift-shape.sh
```

```bash
bash tools/verify/m031-p04-auto-proceed-default-shape.sh
```

```bash
bash tools/verify/m031-p04-changelog-shape.sh
```

```bash
bash tools/verify/m031-p04-test-doc-drift-shape.sh
```

```bash
bash tools/verify/m031-p04-test-auto-proceed-shape.sh
```

## Notes

- Each `RESULT: SC-N pass` line and each `SUMMARY: <basename> pass=N fail=0` line is the contract envelope downstream tasks (T04 battery, T05 phase-suite) consume by exit code, NOT by parsing — exit codes are load-bearing.
- The SC-9 verifier and the `m031-p04-test-doc-drift-shape.sh` shape verifier serve different layers: SC-9 reads the production target files (`commands/evaluate.md` + `references/tier-definitions.md`); the shape verifier reads only the SC-9 test source itself (asserts the test's needle inventory).
- Per the M031 plan-time discipline rule for AD-19 single-script-file shape, every Truth `Check:` command in this task plan is a literal `bash <path>` invocation — no inline compound bash, no process substitution, no plain subshells.
- POSIX-bash discipline (CON-6 / DC-7): the SC-9 doc-drift verifier uses only POSIX-portable constructs (`[ "$a" = "$b" ]`, not `[[ ]]`; `$((...))` arithmetic; `printf` not `echo -e`). Other T01 deliverables (shape verifiers, SC-10 test) MAY use bash 3.2 features but stay POSIX-compatible where feasible.
- The CHANGELOG bullet text is verbatim from this task plan; the executor pastes it as-is. Modifying the bullet text risks failing the SC-10 test or the changelog-shape verifier.
- The `auto_proceed: true` value is already present in the working tree (line 27 of the template at task entry). T01 confirms + commits that state — it is not a fresh edit if the working-tree value is already correct.
- **Real-app smoke test pending** (plan-time discipline rule 5): T01 ships only structural verifiers. Production confirmation that an operator running `orchestrator:dispatch` against a project with the new `auto_proceed: true` default sees the expected behavior is the M033 onboarding milestone's job; T01's gates confirm the contract surface.

## Inputs

### From Previous Tasks

None. T01 is the first task of P04 with no upstream task dependencies.

### From Previous Phases

- **P01 (FR-4 / FR-5 amendment to `commands/dispatch.md` + `templates/orchestrator-config-default.yml`)** — P01 amended `commands/dispatch.md:21` to remove the Quick-skip branch and added the `quick_knowledge_token_budget` config knob. T01's CHANGELOG entry must align with P01's framing: "knowledge + compression unconditional via the Quick profile."
- **P03 (`commands/do.md` universal-entry skill)** — P03 shipped the `orchestrator:do <task>` command. T01's evaluate.md replacement prose for the pre-M024 Tier A block can reference `orchestrator:dispatch` (the Quick-profile dispatch surface) rather than the universal-entry surface — the universal entry is documented in `commands/do.md`, evaluate.md remains the Tier A↔Tier B↔Tier C decision surface.

### From Disk (Pre-existing)

- `commands/evaluate.md` — read for the legacy phrasing locations (lines 22 and 139 at plan-authoring time).
- `references/tier-definitions.md` — read for the legacy phrasing location (line 22 at plan-authoring time).
- `templates/orchestrator-config-default.yml` — read for the existing comment block (lines 14–26) and the active `auto_proceed: true` line (line 27).
- `CHANGELOG.md` — read for the `## [Unreleased]` section header.
- `tools/verify/m031-p03-do-md-shape.sh` — read as the reference template for shape-verifier authoring (header comment + `check_present` / `check_absent` helper + `printf 'SUMMARY: ...'` final line).

## Constraints

- **Bash 3.2 compatibility** (MEM001) for shape verifiers and SC-10 test.
- **POSIX-bash compatibility** (CON-6 / DC-7) for the SC-9 doc-drift verifier so M009 can extend without rewrite.
- **AD-19 single-script-file shape**: all Truth `Check:` invocations and verifier internal patterns. No `$(...)` containing pipes inside conditionals; no plain subshells; no inline compound bash.
- **No edits to `scripts/intake/`, `scripts/dispatch/`, or `commands/dispatch.md`** in T01. Those surfaces belong to P01–P03; T01 is prose + acceptance-test scope only.
- **No edits to `tools/verify/m031-p01-*.sh`, `m031-p02-*.sh`, or `m031-p03-*.sh`** in T01.
- **CON-7 / D020**: no scaffold-placeholder marker bracket-TODO byte pattern in any new file.
- **SC-12 scope-guard**: T01 must NOT touch `knowledge/**`, `scripts/cost/`, `scripts/dispatch/adapters/router/`, or `scripts/auto/loop/`. The shape verifiers contain literal references to these paths (block-list patterns) — the carve-out logic in T05's scope-guard distinguishes "literal pattern in source" from "actual diff touches the path."
- **Verifier path discipline** (AD-19 + M032 Finding A): project-owned slug-bearing verifiers live under `tools/verify/`, NOT `scripts/verify/`.
- **Commit shape**: multi-line messages MUST use `git commit -F <message-file>`. The AP-008 shape-guard rejects the inline HEREDOC form per CLAUDE.md.

## Expected Output

After T01 completes:

1. `commands/evaluate.md` modified — zero matches for `no orchestrator overhead` and zero matches for `Do NOT create any orchestrator directory`; canonical Tier A description present.
2. `references/tier-definitions.md` modified — zero matches for `no orchestrator overhead`; canonical Tier A description present; explicit `.orchestrator/` always-present statement.
3. `templates/orchestrator-config-default.yml` confirmed/modified — `auto_proceed: true`; comment block names M031 + `quick_knowledge_token_budget`.
4. `CHANGELOG.md` modified — M031 entry contains all four required substrings (`M031`, `auto_proceed`, `quick_knowledge_token_budget`, `compound`).
5. `tests/m031-acceptance/doc-drift-verifier.sh` (≥ 40 lines, executable, POSIX-bash) — exits 0 with `RESULT: SC-9 pass`.
6. `tests/m031-acceptance/test-auto-proceed-default.sh` (≥ 30 lines, executable) — exits 0 with `RESULT: SC-10 pass`.
7. Six shape verifiers under `tools/verify/m031-p04-*.sh` (evaluate-md-drift, tier-definitions-drift, auto-proceed-default, changelog, test-doc-drift, test-auto-proceed) — each exits 0 with `SUMMARY: <basename> pass=N fail=0`.

T01 leaves the prose-level closures committed and the SC-9 + SC-10 gates green. T02 picks up with the active doctor compound-change comms surface.
