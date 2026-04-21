---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P01"
milestone: "M012"
name: "Phase verification suite — nine gates + phase-suite orchestrator"
depends_on: ["T04"]
---

## Prerequisites

- T01–T04 complete: `wiki/` skeleton, scanner, stub generator, nav generator all shipped. `wiki/docs/**` is populated. `wiki/mkdocs.yml` has the marker-bounded `nav:` block.
- No M012/P01 verify scripts exist yet.

## Description

Ship the full P01 verification suite. One script per phase-plan Truth `Check:` entry, plus the phase-suite orchestrator that runs them all. Each script is a single-invocation shape (AD-19 compliant so auto-mode never prompts). Scripts read-only except for the phase-suite orchestrator, which creates a summary file in a `/tmp` scratch location for its own reporting but does not touch repo state.

Nine gates:

1. `m012-p01-wiki-self-contained.sh` — `wiki/` + `scripts/wiki/` together are removable without breaking the orchestrator's own tests.
2. `m012-p01-requirements-pinned.sh` — `wiki/requirements.txt` has ≥ 4 `==` pins; no `>=`, no `~=`, no open ranges.
3. `m012-p01-include-plugin.sh` — every stub under `wiki/docs/` carries an `include-markdown` directive referencing an existing `.orchestrator/**.md` path.
4. `m012-p01-ssot.sh` — no stub's body reproduces canonical content: every stub is ≤ 25 lines, every stub has at most one `include-markdown` directive, and for each stub the referenced canonical file exists.
5. `m012-p01-exclusion-policy.sh` — scanner output (and therefore the generated stubs + nav) contains zero paths under `.orchestrator/scratch/`, `.orchestrator/tmp/`, `.orchestrator/config/`, and zero non-`.md` paths.
6. `m012-p01-nav-structure.sh` — `wiki/mkdocs.yml` contains a `nav:` block between the M012-P01 markers; top-level entries appear in order Home / Constitution / Decisions / Knowledge / Milestone Summary / Milestones / Archive; every scanner record has a matching nav leaf.
7. `m012-p01-serve-smoke.sh` — runs `bash scripts/wiki/wiki-serve.sh --probe`. If mkdocs is not on PATH, exits 0 with a `SKIP:` message (Tier 1 static only; Tier 4 UAT covers it). Otherwise relies on mkdocs strict build.
8. `m012-p01-index-placeholder.sh` — `wiki/docs/index.md` exists, contains the word `placeholder`, is ≤ 30 lines.
9. `m012-p01-bash32-compat.sh` — every `.sh` file under `scripts/wiki/` and `scripts/verify/m012-p01-*.sh` is free of `declare -A`, `mapfile`, `${var^^}`, `<(...)`, `&>`, Bash 4-only features. Excludes inline comments that mention these strings by requiring the match to be non-comment code.

Plus the orchestrator:

10. `m012-p01-phase-suite.sh` — invokes all nine gates in order, prints a pass/fail line per gate, exits 0 only if all nine pass.

## Steps

1. **Create `scripts/verify/m012-p01-wiki-self-contained.sh`**:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m012-p01-wiki-self-contained.sh — M012/P01 SC-10 gate.
   #
   # Asserts wiki/ and scripts/wiki/ are the only places M012 P01 code lives,
   # so removing those trees does not break the orchestrator itself.
   #
   # Check list:
   #   1. wiki/ exists and contains mkdocs.yml, requirements.txt, docs/.
   #   2. scripts/wiki/ exists and contains wiki-scan-sources.sh,
   #      wiki-generate-stubs.sh, wiki-generate-nav.sh, wiki-serve.sh.
   #   3. No file outside wiki/, scripts/wiki/, scripts/verify/m012-p01-*.sh,
   #      and .orchestrator/milestones/M012/ imports / sources a wiki script.
   #
   # Bash 3.2 compatible. Single-script-file shape.
   ```

   Use `grep -rl 'scripts/wiki/'` (ignoring `wiki/`, `scripts/wiki/`, `scripts/verify/m012-p01-`, `.orchestrator/milestones/M012/`). Any hit → FAIL.

2. **Create `scripts/verify/m012-p01-requirements-pinned.sh`**:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m012-p01-requirements-pinned.sh — asserts exact-pin discipline.
   # Requires ≥4 lines of shape `<pkg>==<ver>`. No `>=`, `~=`, `<`, empty version.
   ```

   Use `grep -c '^[a-zA-Z0-9_-]\+==' wiki/requirements.txt` ≥ 4, and `grep -E '(>=|~=|<|!=)' wiki/requirements.txt` must emit nothing.

3. **Create `scripts/verify/m012-p01-include-plugin.sh`**:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m012-p01-include-plugin.sh — every stub references an
   # existing .orchestrator/**.md path via include-markdown.
   #
   # 1. wiki/mkdocs.yml has `include-markdown` listed under `plugins:`.
   # 2. For every .md under wiki/docs/ that is NOT wiki/docs/index.md,
   #    wiki/docs/README.md, or a section-index `index.md`, the file
   #    contains `include-markdown "<path>"`. Extract <path>, resolve
   #    against the stub's directory, confirm the target file exists.
   ```

   Use `find wiki/docs -type f -name '*.md'`, filter out the three exclusions, extract each `include-markdown` path, resolve and stat. FAIL on any miss.

4. **Create `scripts/verify/m012-p01-ssot.sh`**:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m012-p01-ssot.sh — no duplicate artifact bodies.
   #
   # For every stub under wiki/docs/:
   #   - Line count ≤ 25.
   #   - Exactly one `include-markdown` directive, OR zero (section indexes).
   #   - No raw body beyond frontmatter + comment + include directive + bullets.
   #
   # Additional: no file under wiki/docs/ has a byte-identical match to any
   # file under .orchestrator/ (SSOT enforcement — no silent copies).
   ```

   Use `wc -l` per stub (note: avoid `$()` with pipe in Checks, but this is inside the verify script itself — MEM004 carve-out). SSOT compare via `cmp` file-to-file for suspiciously large stubs (>25 lines): since they shouldn't exist at all, the line-count gate is the primary guard; the byte-compare check is belt-and-suspenders.

5. **Create `scripts/verify/m012-p01-exclusion-policy.sh`**:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m012-p01-exclusion-policy.sh — scanner emits no excluded paths.
   #
   # Runs bash scripts/wiki/wiki-scan-sources.sh and asserts:
   #   - Zero lines contain `.orchestrator/scratch/`.
   #   - Zero lines contain `.orchestrator/tmp/`.
   #   - Zero lines contain `.orchestrator/config/`.
   #   - Every line's rel-path ends in `.md`.
   #   - No rel-path contains `PLANNING-PAYLOAD` or `VERIFICATION`.
   #   - Every rel-path starts with `.orchestrator/`.
   #
   # Also asserts wiki/docs/**.md stubs (via include-markdown refs) do not
   # reference any excluded path.
   ```

6. **Create `scripts/verify/m012-p01-nav-structure.sh`**:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m012-p01-nav-structure.sh — nav top-level + completeness.
   #
   # Checks:
   #   1. wiki/mkdocs.yml has exactly one `nav:` at column 0.
   #   2. The marker pair `# >>> M012-P01 nav ...` / `# <<< M012-P01 nav end`
   #      both appear, once each.
   #   3. Top-level nav labels (Home, Constitution, Decisions, Knowledge,
   #      Milestone Summary, Milestones, Archive) appear in order within
   #      the marker region.
   #   4. For every scanner record, the corresponding stub path appears at
   #      least once in the nav block (asserts completeness).
   ```

   Use `awk` with a state machine bounded by markers to extract the nav block, then grep for each label in order.

7. **Create `scripts/verify/m012-p01-serve-smoke.sh`**:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m012-p01-serve-smoke.sh — mkdocs strict build probe.
   #
   # Runs `bash scripts/wiki/wiki-serve.sh --probe` and checks exit code.
   # If mkdocs is not on PATH, emits `SKIP: mkdocs not installed` and exits 0.
   # The skip is Tier 1 acceptable; UAT (Tier 4) exercises the actual build.
   ```

   Use `command -v mkdocs` to detect; skip-exit on miss.

8. **Create `scripts/verify/m012-p01-index-placeholder.sh`**:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m012-p01-index-placeholder.sh — index.md is a placeholder.
   # Checks: file exists, contains "placeholder", ≤ 30 lines.
   ```

9. **Create `scripts/verify/m012-p01-bash32-compat.sh`**:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m012-p01-bash32-compat.sh — scans P01-touched .sh files.
   #
   # Target set:
   #   scripts/wiki/wiki-scan-sources.sh
   #   scripts/wiki/wiki-generate-stubs.sh
   #   scripts/wiki/wiki-generate-nav.sh
   #   scripts/wiki/wiki-serve.sh
   #   scripts/verify/m012-p01-*.sh   (this script is self-inclusive)
   #
   # Forbidden patterns (match non-comment, non-string code):
   #   declare -A
   #   mapfile
   #   readarray
   #   ${var^^} / ${var,,}
   #   <(...)   (process substitution)
   #   >(...)   (process substitution)
   #   &>       (Bash 4 merge redirect)
   #
   # Emits FAIL: <file>:<line> <pattern> per hit. PASS with count otherwise.
   ```

   Use `grep -nE` against each file. Filter out lines that match `^[[:space:]]*#` (comments). Accept that string-literal occurrences are rare enough that a comment filter is sufficient; false positives here are acceptable because fix is trivial (paraphrase the mention).

10. **Create `scripts/verify/m012-p01-phase-suite.sh`** — the orchestrator:

    ```bash
    #!/usr/bin/env bash
    # scripts/verify/m012-p01-phase-suite.sh — orchestrates all nine M012/P01 gates.
    #
    # Runs each gate script as a subprocess and aggregates results.
    # Emits one `GATE: <name> PASS|FAIL` line per gate to stdout.
    # Prints `SUMMARY: <passed>/<total> gates passed` at end (stderr).
    # Exit 0 iff all nine gates exit 0.
    #
    # Bash 3.2 compatible. Single-script-file shape (no compound bash).
    ```

    Use a simple indexed-array of script basenames and a plain `for name in "${gates[@]}"; do ... done` loop — NOT inside a Check command (Checks invoke this script; the loop inside the script is fine).

    ```bash
    gates=(
      "m012-p01-wiki-self-contained.sh"
      "m012-p01-requirements-pinned.sh"
      "m012-p01-include-plugin.sh"
      "m012-p01-ssot.sh"
      "m012-p01-exclusion-policy.sh"
      "m012-p01-nav-structure.sh"
      "m012-p01-serve-smoke.sh"
      "m012-p01-index-placeholder.sh"
      "m012-p01-bash32-compat.sh"
    )
    passed=0
    total=${#gates[@]}
    for g in "${gates[@]}"; do
      if bash "$PROJECT_ROOT/scripts/verify/$g"; then
        printf 'GATE: %s PASS\n' "$g"
        passed=$((passed + 1))
      else
        printf 'GATE: %s FAIL\n' "$g"
      fi
    done
    printf 'SUMMARY: %d/%d gates passed\n' "$passed" "$total" >&2
    [ "$passed" -eq "$total" ]
    ```

11. **Mark every verify script executable** (`chmod 755`).

12. **Smoke-run the phase-suite once** (manual; do NOT embed as a Check): `bash scripts/verify/m012-p01-phase-suite.sh` — expect `9/9 gates passed`. If one fails, fix the underlying T01–T04 output until all pass.

## Must-Haves

- All nine gate scripts exist under `scripts/verify/m012-p01-*.sh` and are executable.
- `scripts/verify/m012-p01-phase-suite.sh` exists and is executable.
- Every gate is a single-invocation Bash 3.2 script — no compound bash, no subshell compound commands, no `$()` containing pipes in the Check command layer.
- Running `bash scripts/verify/m012-p01-phase-suite.sh` against the T01–T04 output exits 0.
- Every gate emits `PASS: <name> ...` on success to stdout and `FAIL: <name> ...` with a pointer on failure.
- `scripts/verify/m012-p01-serve-smoke.sh` gracefully SKIPs when `mkdocs` is not installed.

## Verification

- `bash scripts/verify/m012-p01-phase-suite.sh` — the suite's own exit code is the phase's exit code.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M012/phases/P01` — confirms artifact paths + patterns (every verify script file appears in the Artifacts section with min-lines + pattern).
- Self-test: run the phase-suite twice in a row; exit code must be identical (no hidden state).

Manual smoke check during this task (run once; do NOT embed as a Check):

1. `bash scripts/verify/m012-p01-phase-suite.sh` — expect 9/9 green.
2. Temporarily rename `wiki/mkdocs.yml` away; rerun — expect `m012-p01-include-plugin.sh` (or another config-dependent gate) to FAIL. Restore.
3. Temporarily add an extra body paragraph to one stub; rerun — expect `m012-p01-ssot.sh` to FAIL on the line-count threshold. Revert.

## Inputs

### From Previous Tasks

- **T01**: `wiki/requirements.txt`, `wiki/mkdocs.yml` (base), `wiki/docs/index.md`, `scripts/wiki/wiki-serve.sh`.
- **T02**: `scripts/wiki/wiki-scan-sources.sh` — contract as documented in T02.
- **T03**: `wiki/docs/**/*.md` stubs — each ≤ 25 lines, each with exactly one `include-markdown` directive; section indexes with lightweight bullet lists.
- **T04**: `wiki/mkdocs.yml` now has the marker-bounded `nav:` block with Home / Constitution / Decisions / Knowledge / Milestone Summary / Milestones / Archive top-level order.

### Scanner Output Contract (reproduced for zero-context execution)

- Line format: `<category>|<rel-path>|<title>`.
- Category enum: `top:constitution`, `top:decisions`, `top:knowledge`, `top:milestone-summary`, `milestone:<M###>`, `archive:<M###>`.
- No line contains `.orchestrator/scratch/`, `.orchestrator/tmp/`, `.orchestrator/config/`.
- Every `<rel-path>` ends in `.md` and starts with `.orchestrator/`.

### From Disk (Pre-existing)

- `.orchestrator/milestones/M012/M012-ROADMAP.md` — ground truth for the Boundary Map (nav structure, exclusion policy).
- `.orchestrator/memory/constitution.md` — Principle VI (SSOT) + Principle VIII (Bash 3.2).

## Constraints

- **Bash 3.2** — every verify script. MEM001.
- **MEM004 carve-out** — these are verification scripts, not agent-facing content; pipes, `$()`, `awk` are allowed inside the scripts.
- **Single-script-file `Check:` shape (AD-19)** — every Truth `Check:` in P01-PLAN.md invokes one `bash scripts/verify/m012-p01-*.sh`. The logic inside the script can use whatever internal Bash it wants, bounded by the bash-3.2 compat gate.
- **Read-only** — gates never modify repo state. The phase-suite may write to `/tmp/` for intermediate state; that is acceptable and is cleaned on exit via `trap`.
- **Graceful skip for missing `mkdocs`** — the serve-smoke gate must not hard-fail on a sandbox without mkdocs; it emits `SKIP:` and exits 0. This keeps auto-mode progress on CI boxes that don't have mkdocs installed; Tier 4 UAT exercises the real thing.
- **Deterministic** — same T01–T04 output → same exit code across runs.
- **No global state** — each gate is independently invokable. The phase-suite orchestrator is optional scaffolding, not a dependency of individual gates.

## Expected Output

- Ten `.sh` files under `scripts/verify/` with `m012-p01-*` prefix, all executable, all Bash 3.2 compliant.
- `bash scripts/verify/m012-p01-phase-suite.sh` exits 0 against clean T01–T04 output.
- Each gate, run individually, emits `PASS:`/`FAIL:` structured output and exits 0/1 deterministically.
- Removing any single verify script causes the phase-suite to FAIL on that gate without side effects on the other eight.
