---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M014"
goal: "Ship the M014 Minimal Slice: native `orchestrator:specify` create-path with Section-Contract template SSOT, FR-4 shape linter, FR-12 dual-write runtime-md helper (full surface), FR-5 complexity-probe stub, FR-18 byte-compat fixture, and `AGENTS.md` marker-bounded Recent Changes region byte-equivalent to `CLAUDE.md`'s — closing the M015 bootstrapping irony so every future milestone's spec can be orchestrator-authored."
demo_sentence: "A maintainer runs `bash scripts/specify/specify.sh --description 'Add an opt-in exporter that ships merged-PR diffs to Slack for async review' --slug test-exporter --yes` on a clean project; the command allocates the next sequential spec number, writes `specs/<NNN>-test-exporter/spec.md` byte-matching the Section Contract derived from `templates/spec-template.md`, appends a Recent Changes entry to both `CLAUDE.md` and `AGENTS.md` inside the `# >>> orchestrator:recent-changes >>>` / `# <<< orchestrator:recent-changes <<<` markers, emits a `unit_close` record to `.orchestrator/execution-log.jsonl` with `{specs_scaffolded: 1, dual_writes: 2, elapsed_ms: N}`, and exits zero; `bash scripts/verify/spec-shape-lint.sh specs/<NNN>-test-exporter/spec.md` exits 0 with all structural checks green; `bash tests/test-specify-shape.sh` and `bash tests/test-dual-write-outside-invariant.sh` exit 0; `bash scripts/verify/m014-p01-phase-suite.sh` exits 0 across all seven gates."
risk: "high"
depends_on: []
---

## Must-Haves

<!-- Each truth is a behavioral statement + a single-script-file Check (AD-19).
     Every Check command is a single-invocation script-file shape — no inline
     compound bash, no plain subshells, no $() containing pipes, no process
     substitution. All M014/P01 verification logic lives inside the
     scripts/verify/m014-p01-*.sh files; the Check commands here invoke them. -->

### Truths

- `templates/spec-template.md` is the Section Contract SSOT: it contains, in the FR-2 required order, the frontmatter block (`Feature Specification:`, `Feature Branch:`, `Created:`, `Status:`, `Milestone:`, `Input:`) followed by top-level headings for Problem Statement, User Scenarios & Testing (with `### Minimal Slice (Phase 1 Load-Bearing Scope)` and at least one `### User Story N — <title> (Priority: P1/P2/P3)` subsection bearing `**Why this priority**`, `**Independent Test**`, `**Acceptance Scenarios**`), Edge Cases, Functional Requirements, Success Criteria, Non-Goals, Constraints (with `### Knowledge-Layer Boundary` subsection), Assumptions, Constitution Check, Open Questions (defer to planning), Dependencies, and Downstream Consumers (informational, not binding). Every section body contains at least one `<TODO: ...>` bracketed placeholder that `spec-shape-lint.sh` can detect.
  - Check: `bash scripts/verify/m014-p01-template-ssot.sh`

- `scripts/verify/spec-shape-lint.sh <spec-path>` reads the target spec markdown, derives the required-section list from `templates/spec-template.md` (not hardcoded — FR-2b/FR-4 SSOT discipline), and emits `checks=N passed=M failed=K` to stdout plus one line per failed check to stderr. Detects: missing required sections, sections out of order, missing frontmatter fields (`Feature Branch`, `Created`, `Status`, `Milestone`, `Input`), missing subsections (`Minimal Slice`, `Knowledge-Layer Boundary`), and emits a `todo_count=<N>` informational line (non-zero is a skeleton; zero is authored — not a fail condition). Exits 0 when `failed=0`, exits 1 otherwise. Supports `--help` and `--template <path>` override.
  - Check: `bash scripts/verify/m014-p01-spec-shape-lint.sh`

- `scripts/util/dual-write-runtime-md.sh --marker <region-name> --content <path-to-fragment> [--file CLAUDE.md] [--file AGENTS.md] [--dry-run]` writes the content fragment between literal marker lines `# >>> orchestrator:<region-name> >>>` and `# <<< orchestrator:<region-name> <<<` in each `--file` target. Invariants: (a) bytes outside the markers are preserved — `shasum -a 256` of the outside-markers byte stream is identical pre- and post-write (SC-6a); (b) if markers are absent, they are inserted above the file's first heading (`^#`) or at EOF if no heading; (c) when `.orchestrator/config.yml` has `dual_write_agents: false` at the top level, the helper writes only `CLAUDE.md` and skips `AGENTS.md` with a `SKIPPED: AGENTS.md (dual_write_agents=false)` line on stderr; (d) `--dry-run` emits one JSONL record per would-be write (`{command: "dual-write-runtime-md", action_type: "dual-write-region", target_path, source_ref, description}`) to stdout and makes no disk writes.
  - Check: `bash scripts/verify/m014-p01-dual-write-helper.sh`

- `tests/test-dual-write-outside-invariant.sh` fixture: creates a temp copy of a seed `CLAUDE.md`-like file with known outside-markers bytes, invokes `dual-write-runtime-md.sh` with several distinct content fragments in sequence, and asserts the `shasum -a 256` of the outside-markers byte stream is byte-identical across all writes. Also asserts the `AGENTS.md` sibling file is created when absent and its outside-markers region is preserved on subsequent writes. Exits 0 on green.
  - Check: `bash scripts/verify/m014-p01-dual-write-outside-invariant.sh`

- `scripts/knowledge/spec-complexity-probe.sh <spec-path>` ships as a P01 stub: it reads the target spec, emits exactly one line `probe=below-threshold` to stdout (unconditionally — full probe logic lands in P04), emits structured fields `fr_count=0 user_story_count=0 todo_count=0 contradiction_signals=0` to stderr (all zero in the stub), and exits 0. The stub is wired into the `orchestrator:specify` scaffold flow so the prompt integration point exists but no-ops; P04 replaces the body without touching the caller.
  - Check: `bash scripts/verify/m014-p01-complexity-probe-stub.sh`

- `commands/specify.md` follows the MEM012 command-file structure (YAML frontmatter with `description`, `# orchestrator:specify` title, Prerequisites, Usage, Workflow, Output, Idempotency, Error Handling, Referenced Scripts). Declares three subcommands: `specify` (default — create new spec), `specify --amend <path>` (surface stub — re-run placeholder-region LLM-fill only in P01; full FR-14 three-case semantics land in P04), `specify split <path>` (surface stub — prints `split: decomposition flow lands in P04 per M014 roadmap` to stderr and exits 2). Names `scripts/specify/specify.sh`, `scripts/util/dual-write-runtime-md.sh`, `scripts/verify/spec-shape-lint.sh`, `scripts/knowledge/spec-complexity-probe.sh`, and `templates/spec-template.md` in its Referenced Scripts section.
  - Check: `bash scripts/verify/m014-p01-specify-command.sh`

- `scripts/specify/specify.sh --description <prose> [--slug <slug>] [--milestone <M###>] [--force] [--yes] [--dry-run]` is the create-path implementation. Workflow: (1) preflight `.orchestrator/` exists else exit 2 with pointer to `orchestrator:init`; (2) acquire `scripts/lifecycle/lock-manager.sh` for number-resolution-through-directory-creation to avoid TOCTOU; (3) allocate next sequential spec number (highest existing `specs/NNN-*` + 1); (4) derive slug from `--description` when absent (first-5-words, lowercased, kebab-cased, 40-char truncation); (5) error loudly on slug collision (`specs/<NNN>-<slug>/` exists) unless `--force`; (6) atomically write (temp-file-then-rename) `specs/<NNN>-<slug>/spec.md` from `templates/spec-template.md` with frontmatter populated (`Feature Branch: <NNN>-<slug>`, `Created: <iso-date>`, `Status: Draft`, `Milestone: <M### or TODO>`, `Input: "<description>"`); (7) invoke `scripts/util/dual-write-runtime-md.sh --marker recent-changes --content <tmp-fragment> --file CLAUDE.md --file AGENTS.md` to append a one-line `- <NNN>-<slug>: <description-first-80-chars>` entry to the Recent Changes region of both surfaces; (8) invoke `scripts/knowledge/spec-complexity-probe.sh` end-of-scaffold (stub no-ops in P01); (9) emit one `unit_close` record to `.orchestrator/execution-log.jsonl` with `{command: "orchestrator:specify", specs_scaffolded, dual_writes, elapsed_ms, source: "runtime"}` via the [M019](../../../../milestones/M019/index.md) Tier 1 `emit_tier1_record` library shape; (10) print the written absolute path on stdout; exit 0 on success. Skeleton-only scaffold in v1 (no LLM round-trip in P01 — CC LLM path surfaces the prompt template but does not yet invoke it; `RUNTIME-ASSUMPTIONS.md` records the deferral). `--dry-run` prints a FR-19 JSONL manifest to stdout and makes zero disk writes. `--yes` auto-accepts slug derivation. Passes `scripts/verify/anti-pattern-lint.sh`.
  - Check: `bash scripts/verify/m014-p01-specify-sh.sh`

- `tests/test-specify-shape.sh` is the FR-18 byte-compat fixture test: (1) hermetically copies `templates/spec-template.md` into a scratch dir; (2) invokes `scripts/specify/specify.sh --description '<fixture-prose-50-words>' --slug specify-fixture --yes --dry-run` against the scratch project; (3) runs the live non-dry-run variant into the scratch project; (4) asserts the scaffolded `spec.md`'s section-heading list (extracted via `grep -E '^(#|##|###) '`) byte-matches the derivation from `templates/spec-template.md`; (5) asserts `scripts/verify/spec-shape-lint.sh <scaffolded-path>` exits 0 (checks all green; `todo_count > 0` is expected in a skeleton); (6) asserts `scripts/knowledge/detect-spec-shape.sh --spec-path <scaffolded-path>` exits 0 with `shape=speckit` on stdout (the SC-2 I/O-contract assertion). Exits 0 on green.
  - Check: `bash scripts/verify/m014-p01-specify-shape-test.sh`

- `.orchestrator/config.yml` gains a new `specify:` section (with `complexity_thresholds:` placeholder-only keys `fr_count: 0`, `user_story_count: 0`, `raw_token_count: 0`, `todo_density: 0`, `contradiction_signal_count: 0` — all zero in P01 so the stub probe always returns `below-threshold`; planning re-tunes in P04 per OQ #C-4), `scaffolder_description_min_words: 80`, `scaffolder_llm_on_codex: false` keys, and a new top-level `dual_write_agents: true` key. All keys are additive — existing keys untouched.
  - Check: `bash scripts/verify/m014-p01-config-keys.sh`

- `AGENTS.md` exists at repo root with a marker-bounded `# >>> orchestrator:recent-changes >>>` / `# <<< orchestrator:recent-changes <<<` region populated by the `specify` write-site. The two-line runtime-identification header above the first marker reads `# AGENTS.md — Codex CLI runtime instruction file` followed by a blank line (or a marker-adjacent comment if planning decides byte-identical — P01 picks **byte-identical** per D014/D016 precedent; the header is therefore absent and `AGENTS.md`'s marker content is byte-equivalent to `CLAUDE.md`'s marker content). Outside-markers bytes are created once and then preserved across subsequent writes (SC-6a enforced by `tests/test-dual-write-outside-invariant.sh`).
  - Check: `bash scripts/verify/m014-p01-agents-md-shape.sh`

- `RUNTIME-ASSUMPTIONS.md` exists at repo root with a header, schema (YAML frontmatter + per-entry `## FR-N: <short-name>` sections), and two initial entries: (1) `## FR-3: LLM-assisted scaffold-fill depth` — documents that in P01 the LLM round-trip is deferred (scaffolder is skeleton-only); CC runtime will invoke an LLM via `scripts/dispatch/dispatch-interface.sh` in a future M014 phase; Codex/Cursor runtimes fall back to skeleton-only per CON-2. (2) `## FR-5: Complexity probe contradiction-signal count` — documents that the P01 stub returns zero signals under all runtimes; P04 replaces with full implementation that emits non-zero signals under CC only (LLM pass); Codex/Cursor remain zero. Each entry names the CC assumption, the Codex/Cursor fallback, and the M009 parity-audit obligation.
  - Check: `bash scripts/verify/m014-p01-runtime-assumptions.sh`

- `references/spec-management.md` exists as a partial skeleton documenting: (a) the FR-2 Section Contract order with the `templates/spec-template.md` SSOT pointer; (b) the marker convention for dual-write (`# >>> orchestrator:<region-name> >>>` / `# <<< orchestrator:<region-name> <<<`) with a worked example of the `recent-changes` region; (c) the FR-19 `--dry-run` manifest record shape (`{command, action_type, target_path, source_ref, description}`) pinned M014-local. The file carries a `<!-- partial: P04 completes with pressure-test + decomposition sections -->` HTML comment at EOF. Follows the `references/` README-cross-linked doc pattern (MEM009 documentation-as-verification).
  - Check: `bash scripts/verify/m014-p01-spec-management-reference.sh`

- Every P01-touched and P01-created `.sh` file is Bash 3.2 compatible (no `declare -A`, no `mapfile`, no `${var^^}`, no `<(...)`, no `&>`, no `${var,,}`) and passes `scripts/verify/anti-pattern-lint.sh` (Constitution IX, Constitution XV, SC-9 / CON-6).
  - Check: `bash scripts/verify/m014-p01-bash32-compat.sh`

- Every new command introduced by P01 (`orchestrator:specify`) supports `--dry-run` emitting FR-19-shaped JSONL and `--yes` auto-resolution for interactive prompts. Running `bash scripts/specify/specify.sh --description '<prose>' --slug zero-prompt-test --yes --dry-run` against a scratch project emits zero Claude Code approval prompts (SC-7 inherits M016/[M021](../../../../milestones/M021/index.md) baseline) and makes zero disk writes. Verified against the M021 prompt-corpus fixture at `tests/fixtures/m021-prompt-corpus.txt`.
  - Check: `bash scripts/verify/m014-p01-zero-prompts.sh`

- `bash scripts/verify/m014-p01-phase-suite.sh` orchestrates all thirteen P01 gates (template-ssot, spec-shape-lint, dual-write-helper, dual-write-outside-invariant, complexity-probe-stub, specify-command, specify-sh, specify-shape-test, config-keys, agents-md-shape, runtime-assumptions, spec-management-reference, bash32-compat, zero-prompts) and exits 0 on green, non-zero with a per-gate breakdown otherwise.
  - Check: `bash scripts/verify/m014-p01-phase-suite.sh`

### Artifacts

- `templates/spec-template.md` (min 200 lines, contains "Section Contract") — authored by T01; consumed by every downstream task
- `scripts/verify/spec-shape-lint.sh` (min 120 lines, contains "Section Contract") — FR-4 verifier
- `scripts/util/dual-write-runtime-md.sh` (min 150 lines, contains "orchestrator:") — FR-12 helper (full surface; P02 adds call sites only)
- `scripts/knowledge/spec-complexity-probe.sh` (min 40 lines, contains "below-threshold") — FR-5 stub
- `commands/specify.md` (min 150 lines, contains "Referenced Scripts") — user-facing command definition
- `scripts/specify/specify.sh` (min 250 lines, contains "orchestrator-id") — FR-1 create-path
- `templates/spec-scaffolder-prompt.md` (min 40 lines, contains "Problem Statement") — FR-3 CC LLM round-trip prompt (shipped as the template; invocation deferred)
- `tests/test-specify-shape.sh` (min 80 lines, contains "shape=speckit") — FR-18 byte-compat fixture
- `tests/test-dual-write-outside-invariant.sh` (min 60 lines, contains "shasum") — SC-6a outside-markers invariant
- `.orchestrator/config.yml` (modify — additive `specify:`, `dual_write_agents:` keys; existing keys byte-preserved)
- `AGENTS.md` (create — marker-bounded `orchestrator:recent-changes` region populated by first specify write)
- `RUNTIME-ASSUMPTIONS.md` (create; min 40 lines, contains "FR-3") — D016 registry with FR-3 + FR-5-stub entries
- `references/spec-management.md` (create; min 80 lines, contains "Section Contract") — partial; P04 completes
- `scripts/verify/m014-p01-template-ssot.sh` (min 30 lines, contains "Section Contract")
- `scripts/verify/m014-p01-spec-shape-lint.sh` (min 30 lines, contains "checks=")
- `scripts/verify/m014-p01-dual-write-helper.sh` (min 30 lines, contains "orchestrator:")
- `scripts/verify/m014-p01-dual-write-outside-invariant.sh` (min 30 lines, contains "shasum")
- `scripts/verify/m014-p01-complexity-probe-stub.sh` (min 20 lines, contains "below-threshold")
- `scripts/verify/m014-p01-specify-command.sh` (min 30 lines, contains "Referenced Scripts")
- `scripts/verify/m014-p01-specify-sh.sh` (min 40 lines, contains "scripts/specify/specify.sh")
- `scripts/verify/m014-p01-specify-shape-test.sh` (min 20 lines, contains "test-specify-shape.sh")
- `scripts/verify/m014-p01-config-keys.sh` (min 30 lines, contains "dual_write_agents")
- `scripts/verify/m014-p01-agents-md-shape.sh` (min 30 lines, contains "orchestrator:recent-changes")
- `scripts/verify/m014-p01-runtime-assumptions.sh` (min 30 lines, contains "FR-3")
- `scripts/verify/m014-p01-spec-management-reference.sh` (min 20 lines, contains "Section Contract")
- `scripts/verify/m014-p01-bash32-compat.sh` (min 30 lines, contains "declare -A")
- `scripts/verify/m014-p01-zero-prompts.sh` (min 30 lines, contains "m021-prompt-corpus")
- `scripts/verify/m014-p01-phase-suite.sh` (min 40 lines, contains "m014-p01")
- `tests/fixtures/m014-p01/` (directory with `specify-fixture-prose.txt`, `agents-md-seed.md`, `claude-md-seed.md`, `expected-section-headings.txt`)

### Key Links

- `commands/specify.md` → `scripts/specify/specify.sh` (Referenced Scripts section names the script by path, per MEM012)
- `commands/specify.md` → `templates/spec-template.md` (Workflow references template path)
- `commands/specify.md` → `scripts/util/dual-write-runtime-md.sh` (Workflow references dual-write helper)
- `commands/specify.md` → `scripts/verify/spec-shape-lint.sh` (preflight verifier surfaced in command docs)
- `commands/specify.md` → `scripts/knowledge/spec-complexity-probe.sh` (end-of-scaffold hook surfaced in command docs)
- `scripts/specify/specify.sh` → `templates/spec-template.md` (reads as scaffold source)
- `scripts/specify/specify.sh` → `scripts/util/dual-write-runtime-md.sh` (invokes for Recent Changes dual-write)
- `scripts/specify/specify.sh` → `scripts/knowledge/spec-complexity-probe.sh` (invokes end-of-scaffold; stub no-ops)
- `scripts/specify/specify.sh` → `.orchestrator/execution-log.jsonl` (appends `unit_close` record)
- `scripts/specify/specify.sh` → `scripts/lifecycle/lock-manager.sh` (acquires lock around spec-number resolution)
- `scripts/verify/spec-shape-lint.sh` → `templates/spec-template.md` (derives required-section list from SSOT)
- `scripts/util/dual-write-runtime-md.sh` → `.orchestrator/config.yml` (reads `dual_write_agents:` key)
- `scripts/util/dual-write-runtime-md.sh` → `CLAUDE.md` (target file — first marker-bounded region write site)
- `scripts/util/dual-write-runtime-md.sh` → `AGENTS.md` (target file — first marker-bounded region write site)
- `references/spec-management.md` → `templates/spec-template.md` (documents Section Contract SSOT pointer)
- `references/spec-management.md` → `scripts/util/dual-write-runtime-md.sh` (documents marker convention)
- `references/README.md` → `references/spec-management.md` (new entry in the references index per MEM009)
- `tests/test-specify-shape.sh` → `templates/spec-template.md` (ground truth for section-heading byte-match)
- `tests/test-specify-shape.sh` → `scripts/specify/specify.sh` (system under test)
- `tests/test-specify-shape.sh` → `scripts/knowledge/detect-spec-shape.sh` (SC-2 I/O-contract assertion)
- `tests/test-dual-write-outside-invariant.sh` → `scripts/util/dual-write-runtime-md.sh` (system under test)
- `RUNTIME-ASSUMPTIONS.md` → `commands/specify.md` (cross-links FR-3 scaffolder to command)
- `RUNTIME-ASSUMPTIONS.md` → `scripts/knowledge/spec-complexity-probe.sh` (cross-links FR-5 stub to probe)
- `scripts/verify/m014-p01-phase-suite.sh` → `scripts/verify/m014-p01-template-ssot.sh` (orchestrated gate)
- `scripts/verify/m014-p01-phase-suite.sh` → `scripts/verify/m014-p01-spec-shape-lint.sh` (orchestrated gate)
- `scripts/verify/m014-p01-phase-suite.sh` → `scripts/verify/m014-p01-dual-write-helper.sh` (orchestrated gate)
- `scripts/verify/m014-p01-phase-suite.sh` → `scripts/verify/m014-p01-dual-write-outside-invariant.sh` (orchestrated gate)
- `scripts/verify/m014-p01-phase-suite.sh` → `scripts/verify/m014-p01-complexity-probe-stub.sh` (orchestrated gate)
- `scripts/verify/m014-p01-phase-suite.sh` → `scripts/verify/m014-p01-specify-command.sh` (orchestrated gate)
- `scripts/verify/m014-p01-phase-suite.sh` → `scripts/verify/m014-p01-specify-sh.sh` (orchestrated gate)
- `scripts/verify/m014-p01-phase-suite.sh` → `scripts/verify/m014-p01-specify-shape-test.sh` (orchestrated gate)
- `scripts/verify/m014-p01-phase-suite.sh` → `scripts/verify/m014-p01-config-keys.sh` (orchestrated gate)
- `scripts/verify/m014-p01-phase-suite.sh` → `scripts/verify/m014-p01-agents-md-shape.sh` (orchestrated gate)
- `scripts/verify/m014-p01-phase-suite.sh` → `scripts/verify/m014-p01-runtime-assumptions.sh` (orchestrated gate)
- `scripts/verify/m014-p01-phase-suite.sh` → `scripts/verify/m014-p01-spec-management-reference.sh` (orchestrated gate)
- `scripts/verify/m014-p01-phase-suite.sh` → `scripts/verify/m014-p01-bash32-compat.sh` (orchestrated gate)
- `scripts/verify/m014-p01-phase-suite.sh` → `scripts/verify/m014-p01-zero-prompts.sh` (orchestrated gate)

## Tasks

### T01: `templates/spec-template.md` Section Contract SSOT + `templates/spec-scaffolder-prompt.md` CC LLM prompt

See `tasks/T01-PLAN.md`.

### T02: `scripts/verify/spec-shape-lint.sh` FR-4 verifier (template-derived required-section list)

See `tasks/T02-PLAN.md`.

### T03: `scripts/util/dual-write-runtime-md.sh` FR-12 helper + `.orchestrator/config.yml` `dual_write_agents:` key + `tests/test-dual-write-outside-invariant.sh` SC-6a invariant

See `tasks/T03-PLAN.md`.

### T04: `scripts/knowledge/spec-complexity-probe.sh` FR-5 stub + `RUNTIME-ASSUMPTIONS.md` D016 registry scaffold

See `tasks/T04-PLAN.md`.

### T05: `commands/specify.md` + `scripts/specify/specify.sh` FR-1 create-path + `.orchestrator/config.yml` `specify:` section

See `tasks/T05-PLAN.md`.

### T06: `tests/test-specify-shape.sh` FR-18 byte-compat fixture + `references/spec-management.md` partial

See `tasks/T06-PLAN.md`.

### T07: Phase verification suite — fourteen gates + phase-suite orchestrator

See `tasks/T07-PLAN.md`.

## Task Dependencies

```
T01 ──┬─► T02 ──┐
      │         │
      │         │
      ├─► T04 ──┤
      │         │
T03 ──┤         ├─► T05 ──► T06 ──► T07
      │         │
      └─────────┘
```

T01 ships the template SSOT and the scaffolder prompt template — it is the load-bearing foundation every downstream task consumes. T02 depends on T01 (reads template to derive required-section list). T03 is independent (FR-12 helper is template-unaware); it ships the dual-write helper, the `dual_write_agents:` config key, and the outside-invariant fixture test. T04 depends on T01 only insofar as its `RUNTIME-ASSUMPTIONS.md` entries cross-link to T01 artifacts; the probe stub itself is independent. T05 wires it all together: reads T01 template, invokes T02 as preflight advisory in docs, invokes T03 for Recent Changes dual-write, invokes T04 as end-of-scaffold hook, writes `commands/specify.md` + `scripts/specify/specify.sh` + `specify:` config section. T06 depends on T01 (ground truth) and T05 (system under test); authors the FR-18 fixture and the partial `references/spec-management.md`. T07 depends on all predecessors and orchestrates the gates. Dispatch may execute T01/T03 in parallel; T02 + T04 in parallel after T01 ships; T05 blocks on all four; T06 blocks on T05; T07 blocks on T06.

## Files Likely Touched

- `templates/spec-template.md` (create)
- `templates/spec-scaffolder-prompt.md` (create)
- `scripts/verify/spec-shape-lint.sh` (create)
- `scripts/util/dual-write-runtime-md.sh` (create)
- `scripts/knowledge/spec-complexity-probe.sh` (create)
- `commands/specify.md` (create)
- `scripts/specify/` (create — directory)
- `scripts/specify/specify.sh` (create)
- `.orchestrator/config.yml` (modify — additive `specify:` + `dual_write_agents:` keys)
- `AGENTS.md` (create — populated by first specify write)
- `CLAUDE.md` (modify — marker-bounded Recent Changes region inserted; bytes outside markers preserved byte-identically per SC-6a)
- `RUNTIME-ASSUMPTIONS.md` (create)
- `references/spec-management.md` (create — partial)
- `references/README.md` (modify — add `spec-management.md` entry; additive only, bytes outside the new entry preserved)
- `tests/test-specify-shape.sh` (create)
- `tests/test-dual-write-outside-invariant.sh` (create)
- `tests/fixtures/m014-p01/` (create — directory with prose/seed/expected-heading fixtures)
- `tests/fixtures/m014-p01/specify-fixture-prose.txt` (create)
- `tests/fixtures/m014-p01/agents-md-seed.md` (create)
- `tests/fixtures/m014-p01/claude-md-seed.md` (create)
- `tests/fixtures/m014-p01/expected-section-headings.txt` (create)
- `scripts/verify/m014-p01-template-ssot.sh` (create)
- `scripts/verify/m014-p01-spec-shape-lint.sh` (create)
- `scripts/verify/m014-p01-dual-write-helper.sh` (create)
- `scripts/verify/m014-p01-dual-write-outside-invariant.sh` (create)
- `scripts/verify/m014-p01-complexity-probe-stub.sh` (create)
- `scripts/verify/m014-p01-specify-command.sh` (create)
- `scripts/verify/m014-p01-specify-sh.sh` (create)
- `scripts/verify/m014-p01-specify-shape-test.sh` (create)
- `scripts/verify/m014-p01-config-keys.sh` (create)
- `scripts/verify/m014-p01-agents-md-shape.sh` (create)
- `scripts/verify/m014-p01-runtime-assumptions.sh` (create)
- `scripts/verify/m014-p01-spec-management-reference.sh` (create)
- `scripts/verify/m014-p01-bash32-compat.sh` (create)
- `scripts/verify/m014-p01-zero-prompts.sh` (create)
- `scripts/verify/m014-p01-phase-suite.sh` (create)
