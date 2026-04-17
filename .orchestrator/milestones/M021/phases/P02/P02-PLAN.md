---
schema_version: "1.0"
type: phase-plan
phase: "P02"
milestone: "M021"
goal: "Extend scripts/verify/anti-pattern-lint.sh with five new Class B shape detectors (simple-expansion, redirect-cmd-sub, quoted-brace, heredoc-expansion, task-plan-compound), widen its scan scope to include scripts/dispatch/lib/ and .orchestrator/milestones/**/tasks/*-PAYLOAD.md, establish the <!-- agent-facing --> opt-in marker for specs/references/docs, append AP-005..AP-009 to ANTIPATTERNS.md citing M011 screenshots, and ship two gate scripts (m021-p02-linter-v2.sh, m021-p02-linter-scope.sh) that lock in both pattern coverage and scope boundaries — without regressing any M016 Class A detection."
demo_sentence: "A developer seeds a task-PAYLOAD.md bash fence with `echo \"RC=$?\"`; running `bash scripts/verify/anti-pattern-lint.sh` exits non-zero, names the file+line, identifies the pattern class (simple-expansion), and points remediation at `scripts/util/with-env.sh`. Running `bash scripts/verify/run-suite.sh m021 P02` reports PASS for both the v2 coverage gate and the scope gate."
risk: "medium"
depends_on: ["P01"]
---

## Must-Haves

### Truths

<!-- Each truth is a behavioral statement + a single-script-file Check (AD-19).
     All Check: commands use single-invocation script-file shape.
     No inline compound bash, no plain subshells, no $(...) with pipes. -->

- `scripts/verify/anti-pattern-lint.sh` detects all three M016 Class A patterns (command substitution `$(...)`, backtick command substitution, brace expansion `{a,b}`) on the same fixtures M016 used — v2 is a strict superset, no regression.
  - Check: `bash scripts/verify/m021-p02-linter-v2.sh`
- `scripts/verify/anti-pattern-lint.sh` detects five new Class B patterns and names each by class: `simple-expansion` (e.g. `echo "RC=$?"`, `$VAR` inside a bash-fenced tool-call line), `redirect-cmd-sub` (e.g. `foo > "$(cmd)"`), `quoted-brace` (e.g. `awk 'BEGIN{…}'` inside a double-quoted wrapper argument), `heredoc-expansion` (`<<EOF` blocks containing `$VAR` or `$(...)`), and `task-plan-compound` (inline `for …; do …; done`, `if …; then …; fi`, `cd X && Y`, `a; b` chains inside task-PAYLOAD bash fences).
  - Check: `bash scripts/verify/m021-p02-linter-v2.sh`
- Each Class B violation message carries a remediation hint that names a specific wrapper under `scripts/util/` (`with-env.sh`, `read-range.sh`, `run-probe.sh`) and the matching `ANTIPATTERNS.md#AP-00X` anchor.
  - Check: `bash scripts/verify/m021-p02-linter-v2.sh`
- `scripts/verify/anti-pattern-lint.sh` scans `commands/**/*.md`, `templates/**/*.md`, `scripts/dispatch/lib/**/*.sh`, and `.orchestrator/milestones/**/tasks/*-PAYLOAD.md` by default, and treats files under `specs/`, `references/`, and `docs/` as out-of-scope unless they contain a literal `<!-- agent-facing -->` HTML-comment marker.
  - Check: `bash scripts/verify/m021-p02-linter-scope.sh`
- M016 suppression semantics remain intact: lines inside fenced code blocks annotated with `# FORBIDDEN` or `# lint-ignore` are not flagged, and `ANTIPATTERNS.md` itself is excluded from scanning.
  - Check: `bash scripts/verify/m021-p02-linter-v2.sh`
- `ANTIPATTERNS.md` contains five new append-only entries AP-005 through AP-009, each naming (a) the Class B pattern, (b) M011/P05–P07 as the observed-in milestone, (c) a specific remediation wrapper from P01, and (d) at least one screenshot-derived evidence line.
  - Check: `bash scripts/verify/m021-p02-linter-v2.sh`
- `references/engine.md` (or an equivalent reference doc) documents the `<!-- agent-facing -->` marker convention in a dedicated subsection — what it does, which directories require it, and an example of its placement.
  - Check: `bash scripts/verify/m021-p02-linter-scope.sh`

### Artifacts

- `scripts/verify/anti-pattern-lint.sh` (modified — adds five Class B detectors, widened file discovery, marker opt-in; must retain all three Class A checks; min 280 lines, contains `simple-expansion`, `redirect-cmd-sub`, `quoted-brace`, `heredoc-expansion`, `task-plan-compound`, `agent-facing`)
- `ANTIPATTERNS.md` (modified — appends AP-005..AP-009; min 180 lines total, contains `AP-005`, `AP-006`, `AP-007`, `AP-008`, `AP-009`, `M011`)
- `scripts/verify/m021-p02-linter-v2.sh` (create, min 60 lines, contains `PASS`, `Class A`, `Class B`, `task-PAYLOAD`)
- `scripts/verify/m021-p02-linter-scope.sh` (create, min 40 lines, contains `PASS`, `agent-facing`, `specs`, `references`)
- `tests/fixtures/m021-p02/class-a-cmd-sub.md` (create, min 5 lines, contains `$(date`)
- `tests/fixtures/m021-p02/class-a-backtick.md` (create, min 5 lines, contains `` ` ``)
- `tests/fixtures/m021-p02/class-a-brace.md` (create, min 5 lines, contains `{a,b}`)
- `tests/fixtures/m021-p02/class-b-simple-expansion.md` (create, min 5 lines, contains `RC=$?`)
- `tests/fixtures/m021-p02/class-b-redirect-cmd-sub.md` (create, min 5 lines, contains `"$(`)
- `tests/fixtures/m021-p02/class-b-quoted-brace.md` (create, min 5 lines, contains `awk`)
- `tests/fixtures/m021-p02/class-b-heredoc-expansion.md` (create, min 5 lines, contains `<<EOF`)
- `tests/fixtures/m021-p02/class-b-task-plan-compound-PAYLOAD.md` (create, min 5 lines, contains `for `)
- `tests/fixtures/m021-p02/suppressed.md` (create, min 8 lines, contains `FORBIDDEN`)
- `tests/fixtures/m021-p02/clean.md` (create, min 5 lines, contains `PASS`)
- `tests/fixtures/m021-p02/scope-excluded-spec.md` (create, min 5 lines, contains `$(date`)
- `tests/fixtures/m021-p02/scope-opted-in-spec.md` (create, min 5 lines, contains `agent-facing`)
- `references/engine.md` (modified — appends one subsection describing the `<!-- agent-facing -->` marker; min 260 lines total, contains `agent-facing`)

### Key Links

- `scripts/verify/anti-pattern-lint.sh` → `scripts/util/with-env.sh` (simple-expansion remediation hint names this path)
- `scripts/verify/anti-pattern-lint.sh` → `scripts/util/read-range.sh` (redirect-cmd-sub / quoted-brace remediation hints name this path)
- `scripts/verify/anti-pattern-lint.sh` → `scripts/util/run-probe.sh` (heredoc-expansion / task-plan-compound remediation hints name this path)
- `scripts/verify/anti-pattern-lint.sh` → `ANTIPATTERNS.md` (each violation message cites `AP-00X` anchor)
- `scripts/verify/m021-p02-linter-v2.sh` → `scripts/verify/anti-pattern-lint.sh` (invokes via `--fixture <path>` for each seed)
- `scripts/verify/m021-p02-linter-scope.sh` → `scripts/verify/anti-pattern-lint.sh` (invokes over a tree that includes specs-like + marker-opted files)
- `ANTIPATTERNS.md` → `scripts/util/with-env.sh`, `scripts/util/read-range.sh`, `scripts/util/run-probe.sh` (AP-005..AP-009 remedy sections name the three P01 wrappers)
- `references/engine.md` → `scripts/verify/anti-pattern-lint.sh` (marker-convention subsection names the linter)

## Tasks

### T01: Extend anti-pattern-lint.sh with five Class B detectors + scope widening + marker opt-in

See `tasks/T01-PLAN.md`.

### T02: Append AP-005..AP-009 to ANTIPATTERNS.md with M011 evidence + P01 wrapper remedies

See `tasks/T02-PLAN.md`.

### T03: Ship scripts/verify/m021-p02-linter-v2.sh + fixture seeds under tests/fixtures/m021-p02/

See `tasks/T03-PLAN.md`.

### T04: Ship scripts/verify/m021-p02-linter-scope.sh + document marker convention in references/engine.md

See `tasks/T04-PLAN.md`.

## Task Dependencies

```
T01 → T03
T01 → T04
T02 → T03
T02 → T04
```

T01 delivers the linter mechanics (new detectors, scope widening, marker opt-in). T02 delivers the remediation-text anchor targets in `ANTIPATTERNS.md`. Both are prerequisites for T03 (whose gate asserts both Class A + Class B pattern coverage and the presence of AP-005..AP-009 remedy text) and T04 (whose gate asserts scope boundary enforcement and that the marker convention is documented). T03 and T04 are mutually independent and may run in parallel after T01 and T02 both complete.

## Files Likely Touched

- `scripts/verify/anti-pattern-lint.sh` (modify)
- `ANTIPATTERNS.md` (modify — append AP-005..AP-009)
- `scripts/verify/m021-p02-linter-v2.sh` (create)
- `scripts/verify/m021-p02-linter-scope.sh` (create)
- `tests/fixtures/m021-p02/class-a-cmd-sub.md` (create)
- `tests/fixtures/m021-p02/class-a-backtick.md` (create)
- `tests/fixtures/m021-p02/class-a-brace.md` (create)
- `tests/fixtures/m021-p02/class-b-simple-expansion.md` (create)
- `tests/fixtures/m021-p02/class-b-redirect-cmd-sub.md` (create)
- `tests/fixtures/m021-p02/class-b-quoted-brace.md` (create)
- `tests/fixtures/m021-p02/class-b-heredoc-expansion.md` (create)
- `tests/fixtures/m021-p02/class-b-task-plan-compound-PAYLOAD.md` (create)
- `tests/fixtures/m021-p02/suppressed.md` (create)
- `tests/fixtures/m021-p02/clean.md` (create)
- `tests/fixtures/m021-p02/scope-excluded-spec.md` (create)
- `tests/fixtures/m021-p02/scope-opted-in-spec.md` (create)
- `references/engine.md` (modify — append agent-facing marker subsection)

## Boundary Assertion

- **Produces exactly**: the linter extension, two new gate scripts, a dedicated fixture directory under `tests/fixtures/m021-p02/`, five new AP entries in `ANTIPATTERNS.md`, and one new subsection in `references/engine.md`. Nothing else.
- **Does not touch**: `scripts/util/*.sh` (P01 territory — referenced by path only), `scripts/hooks/pre-bash-shape-guard.sh` (P03), `.claude/settings.json` (P03), `tests/fixtures/m021-prompt-corpus.txt` (P04), `scripts/verify/lib/shape-classifier.sh` (P03 — linter uses its own file-oriented regexes per AD of roadmap's "Shape-classifier single source of truth" note).
- **Consumes**: the three wrappers from P01 by path (remediation-hint text names them). No runtime dependency — P01 only needs to have shipped so the paths referenced in AP-005..AP-009 and in the linter hints actually exist.
- **Fixture isolation**: all seeded files live under `tests/fixtures/m021-p02/` which is outside the linter's default scan roots (`commands/`, `templates/`, `scripts/dispatch/lib/`, `.orchestrator/milestones/**/tasks/*-PAYLOAD.md`). The main-project linter sweep will never traverse them. Fixtures are fed to the linter explicitly via `--fixture <path>` from the two gate scripts.
