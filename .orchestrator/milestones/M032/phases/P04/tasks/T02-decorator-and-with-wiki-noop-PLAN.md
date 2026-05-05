---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P04"
milestone: "M032"
name: "FR-20 code-shorthand decorator stub + SC-9 acceptance script + --with-wiki no-op in-flight repair"
depends_on: []
---

## Prerequisites

- P02 closed (`wiki/glossary.md` exists; US-6 format invariant — `### TERM`
  headings + adjacent one-line definitions — is the parser surface the
  decorator binds against). Verified by:
  - `[ -f wiki/glossary.md ]`
  - `grep -q '^### ' wiki/glossary.md`
- P03 closed (`scripts/lifecycle/wiki-init.sh` exists with the case
  statement at lines 50–79 from P02/T01 + P03/T01 + P03/T02; T02
  amends this case statement). Verified by:
  - `[ -f scripts/lifecycle/wiki-init.sh ]`
  - `grep -q -- '--with-giscus) WITH_GISCUS=1' scripts/lifecycle/wiki-init.sh`
- The P03 SC-5 dry-run follow-up note in P03-SUMMARY.md documents the
  `--with-wiki` rejection issue. Verified by:
  - `grep -q -- '--with-wiki' .orchestrator/milestones/M032/phases/P03/P03-SUMMARY.md`

## Description

T02 lands two surfaces:

1. **FR-20 code-shorthand decorator stub** — `scripts/wiki/wiki-decorate-codes.sh`
   is a new build-time decorator implementing US-8's three acceptance
   scenarios at the documented stub scope. Per the spec, US-8 is P3
   priority and the post-launch wiki-UX-deep proposal owns the polish;
   M032's job is to ship the surface so the decorator interface
   exists and downstream proposals build against a known shape.

2. **`--with-wiki` no-op in-flight repair** — carried forward from the
   P03/T04 SC-5 dry-run finding documented in P03-SUMMARY.md.
   `wiki-init.sh`'s case statement rejects `--with-wiki` as an unknown
   argument (line 78: `*) echo "FAIL: wiki-init: unknown argument '$1'"`).
   The flag is structurally redundant on the wiki-init surface — wiki-init
   IS the wiki-init step — but operators (and `init-project.sh`'s FR-11
   passthrough) chain the flag through unmodified. Rejecting it surfaces
   a confusing fail in the canonical `init --with-wiki --with-giscus
   --deploy` chain. The repair is two lines: a `--with-wiki) shift ;;`
   case arm consuming the flag silently, plus a documenting comment.

### FR-20 decorator interface and behavior

```
bash scripts/wiki/wiki-decorate-codes.sh \
  --in <input-page>.md \
  --glossary <glossary-page>.md \
  --out <output-page>.md
```

The script:

1. Reads `--in` page contents into memory (or temp file).
2. Parses the `--glossary` page for `### TERM` headings — for each
   heading, extracts the term name (whatever follows `### `) and the
   immediately-following one-line definition (the next non-blank line,
   stripped of leading/trailing whitespace, capped at the first 80
   chars to keep title-slot decoration concise).
3. If `--glossary` is omitted or the file does not exist, falls back to
   scanning the codebase for `### CODE` definition patterns (best-
   effort: walk a small set of paths — `.orchestrator/`, `references/`,
   `commands/` — for `### <CODE>` headings); if no glossary surface
   resolves, skips decoration entirely with a debug-level diagnostic
   to stderr (`debug: wiki-decorate-codes: no glossary resolved, skipping
   decoration`) and copies `--in` byte-identical to `--out`.
4. Regex-scans the input page for the four documented patterns:
   - `[A-Z]{2,4}-\d+` (e.g. `AP-009`, `MIT-001`, `DR-STACK-001`)
   - `M\d{3}` (e.g. `M032`)
   - `DR-[A-Z]+-\d+` (subset of pattern 1; explicit for documentation)
   - `AP-\d+` (subset of pattern 1; explicit for documentation)
5. For each match: if the matched code resolves against the glossary
   (case-sensitive lookup against `### TERM` heading names), rewrite:
   - First occurrence per page: `CODE` → `[CODE (Title)](#anchor)` where
     `<anchor>` is the slug derived from `CODE` lowercased + non-
     alphanumeric collapsed to `-` (e.g. `M032` → `#m032`,
     `DR-STACK-001` → `#dr-stack-001`).
   - Subsequent occurrences: `CODE` → `[CODE](#anchor)` (link-only, no
     title repeat per US-8 AS-2).
6. Patterns matching the regex but unresolved against the glossary are
   left byte-identical (no broken-link noise per US-8 AS-1 / Finding G).
7. Writes the rewritten content to `--out`.

The script ships with **deliberately narrow surface** per the P3 stub
framing:
- No in-place rewrite of the full wiki tree (operator runs the decorator
  manually against individual pages).
- No integration into `wiki-generate-nav.sh` or `mkdocs build` hooks.
- No glossary auto-derivation from the codebase beyond the simple
  fallback in step 3 (best-effort `### CODE` walk).

The README/inline comments at the script head document the post-launch
polish surface explicitly per Principle XIV.

### `--with-wiki` no-op repair

In `scripts/lifecycle/wiki-init.sh`, locate the case statement (~line
50–79). Add a new case arm BEFORE the `*)` catch-all:

```sh
    --with-wiki) shift ;;  # M032/P04/T02 in-flight repair: --with-wiki is consumed
                           # by init-project.sh's FR-11 passthrough; wiki-init.sh
                           # itself IS the wiki-init step, so the flag is structurally
                           # redundant here but accepted for FR-11 passthrough symmetry.
                           # Surfaced in P03/T04 SC-5 dry-run; documented in
                           # P03-SUMMARY.md operator follow-ups.
```

The change is two lines (one case arm + the comment block). Zero
behavioral change in any non-`--with-wiki` codepath; the only new
behavior is "wiki-init.sh accepts `--with-wiki` without failing".

## Steps

1. **Author `scripts/wiki/wiki-decorate-codes.sh`**. Single-script-file
   shape per AD-19; bash 3.2 compatible per MEM001. The skeleton:

   ```bash
   #!/usr/bin/env bash
   # scripts/wiki/wiki-decorate-codes.sh
   # M032/P04/T02 — FR-20 build-time code-shorthand decorator (US-8 P3 stub).
   # Surface exists; polish deferred to post-launch wiki-UX-deep proposal.
   #
   # Interface:
   #   bash scripts/wiki/wiki-decorate-codes.sh --in <page> --glossary <glossary> --out <page>
   #
   # Patterns scanned: [A-Z]{2,4}-\d+, M\d{3}, DR-[A-Z]+-\d+, AP-\d+
   # First-occurrence-per-page: CODE → [CODE (Title)](#anchor)
   # Subsequent occurrences: CODE → [CODE](#anchor)
   # Unresolved patterns: byte-identical (Finding G)
   #
   # Stub-shaped scope: no full-tree rewrite, no mkdocs hook integration,
   # no codebase glossary auto-derivation beyond simple fallback.
   set -uo pipefail
   IN=""; GLOSS=""; OUT=""
   while [ $# -gt 0 ]; do
     case "$1" in
       --in) IN="$2"; shift 2 ;;
       --in=*) IN="${1#--in=}"; shift ;;
       --glossary) GLOSS="$2"; shift 2 ;;
       --glossary=*) GLOSS="${1#--glossary=}"; shift ;;
       --out) OUT="$2"; shift 2 ;;
       --out=*) OUT="${1#--out=}"; shift ;;
       *) echo "FAIL: wiki-decorate-codes: unknown argument '$1'" >&2; exit 2 ;;
     esac
   done
   [ -n "$IN" ] || { echo "FAIL: --in is required" >&2; exit 2; }
   [ -n "$OUT" ] || { echo "FAIL: --out is required" >&2; exit 2; }
   [ -f "$IN" ] || { echo "FAIL: --in file does not exist: $IN" >&2; exit 2; }

   # Glossary fallback: missing-or-absent → debug stderr and copy byte-identical.
   if [ -z "$GLOSS" ] || [ ! -f "$GLOSS" ]; then
     echo "debug: wiki-decorate-codes: no glossary resolved, skipping decoration" >&2
     cp "$IN" "$OUT"
     exit 0
   fi

   # Parse glossary: each `### TERM` heading + immediately following non-blank line.
   # Build a parallel-scalar registry term_<i>=CODE / title_<i>=Title.
   # ... (extract via awk or grep+while-read with /tmp work file)
   # Apply rewrite rules: first occurrence titled, subsequent link-only.
   # Use sed with careful escape handling for the `(Title)` literal.
   # Output via cp/mv with idempotent overwrite of $OUT.
   ```

   The implementing agent fills the body. Verbosity guidance per
   `commands/plan-phase.md`: this is INTERFACE specification + KEY
   ALGORITHMIC SHAPE — exact regex literals matter (verbatim above);
   internal accumulator structure (parallel scalars vs temp file) is
   the agent's choice subject to bash 3.2 + MEM001 constraints.

2. **Author `tests/m032-acceptance/p0X-code-decorator.sh`** (SC-9).
   Single-script-file shape; trap-EXIT cleanup; three assertion groups
   per US-8 AS-1/AS-2/AS-3.

   ```bash
   #!/usr/bin/env bash
   # SC-9 — verifies FR-20 code-shorthand decorator (US-8 P3 stub).
   set -uo pipefail
   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
   PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
   FIXTURE="/tmp/m032-p04-sc9-fixture-$$"
   trap 'rm -rf "$FIXTURE"' EXIT INT TERM
   mkdir -p "$FIXTURE"
   pass=0; fail=0
   say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
   say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

   # AS-1: three known + one unknown
   cat > "$FIXTURE/page.md" <<'EOF'
   See M032 + AP-009 + DR-STACK-001 + XYZ-999 for context.
   EOF
   cat > "$FIXTURE/gloss.md" <<'EOF'
   ### M032

   Wiki Distribution and Init Integration

   ### AP-009

   Compound chain

   ### DR-STACK-001

   Stack Decision
   EOF
   bash "$PROJECT_ROOT/scripts/wiki/wiki-decorate-codes.sh" \
     --in "$FIXTURE/page.md" --glossary "$FIXTURE/gloss.md" --out "$FIXTURE/out1.md"
   if grep -q 'M032 (Wiki Distribution and Init Integration)' "$FIXTURE/out1.md" \
      && grep -q 'AP-009 (Compound chain)' "$FIXTURE/out1.md" \
      && grep -q 'DR-STACK-001 (Stack Decision)' "$FIXTURE/out1.md" \
      && grep -qF 'XYZ-999' "$FIXTURE/out1.md" \
      && ! grep -q 'XYZ-999 (' "$FIXTURE/out1.md"; then
     say_pass 'AS-1: three known decorated + one unknown byte-identical'
   else
     say_fail 'AS-1: decoration mismatch'
   fi

   # AS-2: first occurrence titled, subsequent link-only
   cat > "$FIXTURE/page2.md" <<'EOF'
   M032 mention M032 again
   EOF
   bash "$PROJECT_ROOT/scripts/wiki/wiki-decorate-codes.sh" \
     --in "$FIXTURE/page2.md" --glossary "$FIXTURE/gloss.md" --out "$FIXTURE/out2.md"
   # First occurrence has '(Wiki Distribution and Init Integration)'; second does not repeat the title.
   _occurrences_titled=$(grep -c '(Wiki Distribution and Init Integration)' "$FIXTURE/out2.md" || true)
   if [ "$_occurrences_titled" -eq 1 ]; then
     say_pass 'AS-2: first-titled subsequent-link-only'
   else
     say_fail "AS-2: expected exactly 1 titled occurrence, got $_occurrences_titled"
   fi

   # AS-3: missing glossary → no error, no decoration
   bash "$PROJECT_ROOT/scripts/wiki/wiki-decorate-codes.sh" \
     --in "$FIXTURE/page.md" --glossary "$FIXTURE/missing.md" --out "$FIXTURE/out3.md"
   _rc=$?
   if [ "$_rc" -eq 0 ] && diff -q "$FIXTURE/page.md" "$FIXTURE/out3.md" >/dev/null; then
     say_pass 'AS-3: missing glossary → exit 0 + byte-identical copy'
   else
     say_fail "AS-3: rc=$_rc or output not byte-identical"
   fi

   printf 'RESULT: SC-9 pass=%d fail=%d\n' "$pass" "$fail"
   [ "$fail" -eq 0 ]
   ```

3. **Amend `scripts/lifecycle/wiki-init.sh`** with the `--with-wiki`
   no-op case arm. Locate the case statement (lines 50–79; matches
   pattern `case "$1" in`); add the new arm BEFORE the `*)` catch-all:

   ```sh
       --with-wiki) shift ;;  # M032/P04/T02 in-flight repair: --with-wiki is consumed
                              # by init-project.sh's FR-11 passthrough; wiki-init.sh
                              # itself IS the wiki-init step, so the flag is structurally
                              # redundant here but accepted for FR-11 passthrough symmetry.
                              # Surfaced in P03/T04 SC-5 dry-run; documented in
                              # P03-SUMMARY.md operator follow-ups.
   ```

4. **Author the three verifier scripts** under `tools/verify/`:

   - `m032-p04-decorator-shape.sh` — asserts `wiki-decorate-codes.sh`
     exists, is executable, contains the four documented regex
     literals, contains the `--in`/`--glossary`/`--out` interface, and
     contains the stub-shaped framing comment.
   - `m032-p04-acceptance-shape-sc9.sh` — asserts the SC-9 script
     exists, is executable, contains the FR-20/US-8 token surface,
     contains the three AS labels, and contains the trap-EXIT cleanup
     pattern.
   - `m032-p04-with-wiki-noop.sh` — asserts:
     - `scripts/lifecycle/wiki-init.sh` contains `--with-wiki) shift`
       (the no-op case arm).
     - Running `bash scripts/lifecycle/wiki-init.sh --with-wiki
       --project-dir <fresh-fixture>` does NOT exit 2 with "unknown
       argument" diagnostic (uses `M032_WIKI_INIT_FORCE_EXIT` or a
       `tests/fixtures/m032-fresh-project-fixture/` invocation; the
       verifier captures stderr and asserts no `unknown argument`
       string is present).
     - The verifier may stub the rest of the wiki-init flow (e.g. by
       running `--project-dir /tmp/empty-fixture-$$` which fails
       earlier on `python3` probe or git-remote probe — the test is
       only that the `--with-wiki` parse step does not fail).

5. **Make new scripts executable**:
   ```
   chmod +x scripts/wiki/wiki-decorate-codes.sh
   chmod +x tests/m032-acceptance/p0X-code-decorator.sh
   chmod +x tools/verify/m032-p04-decorator-shape.sh
   chmod +x tools/verify/m032-p04-acceptance-shape-sc9.sh
   chmod +x tools/verify/m032-p04-with-wiki-noop.sh
   ```

6. **Run T02 verifiers locally** to confirm green:
   - `bash tools/verify/m032-p04-decorator-shape.sh`
   - `bash tools/verify/m032-p04-acceptance-shape-sc9.sh`
   - `bash tools/verify/m032-p04-with-wiki-noop.sh`
   - `bash tests/m032-acceptance/p0X-code-decorator.sh`

7. **Run sibling-phase regression check**:
   - `bash tools/verify/m032-p02-phase-suite.sh`
   - `bash tools/verify/m032-p03-phase-suite.sh`

   Both should remain green at their close-time numbers. The
   `--with-wiki` case-arm addition is strictly additive (the case
   statement rejects unknown args; adding a recognized arm widens the
   accepted set without affecting any other arm).

## Must-Haves

- `scripts/wiki/wiki-decorate-codes.sh` exists with the documented `--in`/`--glossary`/`--out` interface, the four regex pattern literals, the first-occurrence-titled / subsequent-link-only rewrite rule, the missing-glossary fallback, and the stub-shaped framing comment
- `scripts/lifecycle/wiki-init.sh` accepts `--with-wiki` as documented no-op (case arm with comment block citing FR-11 passthrough symmetry rationale)
- `tests/m032-acceptance/p0X-code-decorator.sh` exists and exercises US-8 AS-1 (three known + one unknown), AS-2 (first-titled / subsequent-link-only), AS-3 (missing-glossary fallback) against `/tmp/m032-p04-sc9-fixture-$$/` with trap-EXIT cleanup
- `tools/verify/m032-p04-decorator-shape.sh` + `m032-p04-acceptance-shape-sc9.sh` + `m032-p04-with-wiki-noop.sh` ship green
- P02 + P03 phase-suites remain green post-T02

## Verification

```bash
bash tools/verify/m032-p04-decorator-shape.sh
```

```bash
bash tools/verify/m032-p04-acceptance-shape-sc9.sh
```

```bash
bash tools/verify/m032-p04-with-wiki-noop.sh
```

```bash
bash tests/m032-acceptance/p0X-code-decorator.sh
```

```bash
bash tools/verify/m032-p02-phase-suite.sh
```

```bash
bash tools/verify/m032-p03-phase-suite.sh
```

## Notes

Expected output: each verifier's final line is `SUMMARY: <name>.sh
pass=N fail=0` (or equivalent `RESULT:` envelope) and exits 0. P02
remains 12/12; P03 remains 10/10.

Verifier-contract-over-verifier-skeleton latitude: the decorator's
internal rewrite implementation (sed with escape handling vs awk vs
pure-bash string manipulation) is the implementing agent's choice. The
contract is the input/output behavior asserted by SC-9 — three AS
groups all green. If sed escape handling proves too brittle for the
glossary's title content (titles may contain `&`, `/`, parens), use a
literal-string-replacement helper or process via temp file. If the
on-disk rewrite logic must take a different approach to ship working,
ship the contract intent rather than the literal sed sketch. This is
the canonical M032 P03 pattern (see P03/T03's manual-empty-then-
regenerate course-correction).

The `--with-wiki` no-op repair must be idempotent — re-running the
verifier multiple times produces identical state. The case-arm consumes
the flag with `shift`; no global variable is touched; no side effect
fires.

The decorator's stub-shaped framing is load-bearing per Principle XIV.
The README / inline comment at the script head MUST explicitly cite
"post-launch wiki-UX-deep proposal owns the polish" so future
maintainers do not "fix" the narrowness by expanding scope without a
spec amendment.

Bash 3.2 gotcha: the SC-9 acceptance script uses `_occurrences_titled=$(grep -c ... || true)`
under `set -uo pipefail` per the P02/T03 patterns-established gotcha
(silent abort when `grep -c` returns 0 otherwise).

## Inputs

### From Previous Tasks

(None — T02 has zero upstream task dependencies inside P04.)

### From Disk (Pre-existing)

- `wiki/glossary.md` (P02/T03 surface) — the US-6 format invariant
  parser source. Key shape: `### TERM` headings with one-line
  definitions in the immediately-following non-blank line. T02's
  decorator parses this format. Today the orchestrator's glossary
  contains three entries (Constitution, Knowledge Graph, Milestone) —
  the decorator works correctly against any number of entries from
  zero up.
- `scripts/lifecycle/wiki-init.sh` (P02/T01 + P03 amendments) — the
  case statement T02 amends with `--with-wiki) shift ;;`. T02's
  amendment is purely additive; no other case arm is modified.
- `.orchestrator/milestones/M032/phases/P03/P03-SUMMARY.md` — documents
  the `--with-wiki` rejection follow-up. T02 cites this in the inline
  comment block.
- `tests/fixtures/m032-fresh-project-fixture/` (P01/T03 fixture) —
  available for the `m032-p04-with-wiki-noop.sh` verifier's stubbed
  invocation if needed.

## Constraints

- Single-script-file shape per AD-19.
- bash 3.2 compatibility (per MEM001) — no `declare -A`, no process
  substitution, no compound-chain-gt2.
- Verifier scripts under `tools/verify/m032-p04-*`.
- Acceptance script under `tests/m032-acceptance/p0X-code-decorator.sh`.
- The decorator's stub-shaped scope is non-negotiable per Principle XIV
  — no full-tree rewrite, no mkdocs hook integration, no codebase
  glossary auto-derivation beyond the simple fallback.
- The `--with-wiki` no-op is two lines (case arm + comment block); no
  other modification to `wiki-init.sh` is in scope for T02 (T01 and
  T03 do not touch this file; P03's amendments are preserved verbatim).
- T02 does NOT touch any sibling-task deliverable (T01 scanner;
  T03 SC-11; T04 battery; T05 close ceremony).

## Expected Output

After T02 completes:

- `scripts/wiki/wiki-decorate-codes.sh` exists, is executable, and runs
  successfully against fixture pages + glossaries.
- `scripts/lifecycle/wiki-init.sh` accepts `--with-wiki` without error.
- `tests/m032-acceptance/p0X-code-decorator.sh` exits 0 (all three AS
  groups green).
- Three new verifier scripts under `tools/verify/m032-p04-*` are
  present, executable, and exit 0.
- P02 + P03 phase-suites remain green at their close numbers.
