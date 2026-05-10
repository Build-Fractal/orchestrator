---
schema_version: "1.0"
type: phase-plan
phase: "P02"
milestone: "M013"
goal: "Ship the M013 US-1 Projection create path: `orchestrator:github init` (subcommand md + `scripts/integrations/github-init.sh`) with `scripts/integrations/github-common.sh` shared helpers, `gh auth status` + sub-issue REST + label-collision preflights (FR-2, FR-14 adopt-mode / `--strict-labels` refuse-mode), lazy Issue/sub-issue projection with `<!-- orchestrator-id: <id> -->` marker emit (FR-4) and search-before-create idempotency, FR-15 `--dry-run` manifest format pinned for P03/P04 reuse, sidecar population of `repo_slug` + `project_v2_id` + `items.<orchestrator-id>` entries on first successful live run, and `references/github-integration.md` extensions covering auth modes + sub-issue representation modes + partial mapping table (milestone/phase/task ↔ GitHub resources). Re-init adoption (FR-14 sidecar-absent + marker-bearing remote), FR-5 three-shape GraphQL CI lint, and mapping-table chunk/AC/verification-status rows are deliberately deferred to P03 per D015."
demo_sentence: "On a clean orchestrator project with at least one in-flight milestone (≥2 phases, ≥3 tasks), running `bash scripts/integrations/github-init.sh --dry-run` prints an upsert manifest naming the Milestone/Project v2/labels/`label:phase` Issues/task sub-issues that would be created (zero `gh` write calls, ≤60s runtime) while `scripts/integrations/github-status.sh` continues to report `STATUS: pending-operator-complete`; on a real invocation against a test repo with authenticated `gh`, a second `--dry-run` with no orchestrator-state delta produces an empty upsert manifest (`upserts=0 skipped=N`) via marker search-before-create, the sidecar at `.orchestrator/integrations/github.json` is populated with `repo_slug`, `project_v2_id`, and one `items.<orchestrator-id>` entry per projected phase/task (each carrying `issue_number`, `project_v2_attached`, `status_field_synced`, `last_attempt_at`, `last_error: null`, `schema_version: 1`), every projected Issue body contains exactly one `<!-- orchestrator-id: M###-P##[-T##] -->` marker verified byte-identical via `shasum`, and `bash scripts/verify/m013-p02-phase-suite.sh` exits 0 across all nine gates."
risk: "high"
depends_on: ["P01"]
---

## Must-Haves

<!-- Each truth is a behavioral statement + a single-script-file Check (AD-19).
     Every Check command is a single-invocation script-file shape — no inline
     compound bash, no plain subshells, no $() containing pipes, no process
     substitution. All M013/P02 verification logic lives inside the
     scripts/verify/m013-p02-*.sh files; the Check commands here invoke them.

     Fixture-driven (zero live `gh` calls in CI). The live-call contract is
     documented in references/github-integration.md P02 extensions and attested
     by the P02 dogfood run at operator milestone close — NOT by any gate. -->

### Truths

- `scripts/integrations/github-common.sh` defines pure shell helpers that compute orchestrator IDs (`orchestrator_id_for <milestone-dir> <phase-id> [<task-id>]` → prints `M###-P##[-T##]`), emit the canonical marker (`emit_marker <id>` → prints `<!-- orchestrator-id: <id> -->` verbatim), search a body blob for exactly one marker (`find_marker_in_body <body-file> <id>` → exit 0 if exactly one, 1 otherwise), and read/write top-level sidecar fields without jq (Bash 3.2 grep/sed; AWK for `items.*` upserts). The file sources cleanly with `set -u`, exits non-zero on missing args, and exposes zero network side-effects (the bash32-compat gate and the anti-pattern-lint gate both green on it).
  - Check: `bash scripts/verify/m013-p02-github-common.sh`

- `scripts/integrations/github-init.sh` implements the US-1 create path: on `--dry-run` it emits the FR-15 manifest to stdout (zero `gh` write calls, REST read calls allowed only for preflight); on a live run with `gh` authenticated it creates the Milestone, Project v2, required labels (`phase`, `task`, `uat-bug`, `spec-gap`), one `label:phase` Issue per in-flight-or-ready phase (lazy projection per US-1 AS-4a; Planning-state phases NOT projected), one task sub-issue per task under each phase Issue, attaches every Issue to the Project v2, and writes back into `.orchestrator/integrations/github.json`: `repo_slug` + `project_v2_id` + one `items.<orchestrator-id>` entry per created Issue. Every Issue body contains exactly one `<!-- orchestrator-id: M###-P##[-T##] -->` marker (verified via `shasum` byte-identity read-back — ported from [M012](../../../../milestones/M012/index.md) marker-bounded-atomic-writes pattern); re-running init with no orchestrator-state delta produces `upserts=0` via marker search-before-create.
  - Check: `bash scripts/verify/m013-p02-github-init-fixture.sh`

- `scripts/integrations/github-init.sh --dry-run` preflights `gh auth status`, sub-issue REST availability, and label-collision — producing exactly one of these exit behaviors: (a) PASS with manifest printed when all preflights green; (b) FAIL with specific missing-scope diagnostic when `gh auth status` reports stale/missing/scopeless per FR-2 (`integration-auth-failed: missing scope <name>` wording); (c) FAIL with `integration-labels-collision` diagnostic when `--strict-labels` is set and a pre-existing label with non-matching color/description exists; (d) WARN (exit 0) with `sub-issue-mode: labeled-fallback` when sub-issue REST endpoint probe returns HTTP 404/501, falling back to `parent:<phase-id>` / `child:<task-id>` labels plus reciprocal body-link mode. The selected sub-issue mode is written into the sidecar as `sub_issue_mode: native|labeled-fallback`.
  - Check: `bash scripts/verify/m013-p02-github-init-preflight.sh`

- `scripts/integrations/github-init.sh --dry-run` manifest format is stable and reusable by P03 re-init and P04 sync `--dry-run`: first-line header `MANIFEST: <upserts> <skipped> <errors>`, then one line per projected resource of shape `UPSERT: <resource-kind> <orchestrator-id> <target> [reason]` where `<resource-kind>` is one of `milestone|project-v2|label|phase-issue|task-subissue|project-v2-item`, `<orchestrator-id>` is the M###-P##[-T##] id (or `-` for repo-level resources), `<target>` is a GitHub URL or object identifier, `[reason]` is `create|adopt|skip-existing-marker`. Exit 0 on well-formed manifest; non-zero on preflight failure.
  - Check: `bash scripts/verify/m013-p02-dry-run-manifest.sh`

- `commands/github-init.md` follows the MEM012 command-file structure (YAML frontmatter with `description`, Title, Prerequisites / State Check, Core Workflow numbered, Output, Idempotency, Error Handling, Referenced Scripts) and names `scripts/integrations/github-init.sh`, `scripts/integrations/github-common.sh`, and `scripts/integrations/github-status.sh` in its Referenced Scripts section. The `--dry-run` flag is documented as the canonical read-only preview and as the format shared with P03 `orchestrator:github sync --dry-run`.
  - Check: `bash scripts/verify/m013-p02-github-init-command.sh`

- `references/github-integration.md` gains three new sections replacing the `TODO P02` stubs left by P01 (no section owned by P01 is rewritten — only the three stubs are filled): (a) **Auth Modes** — PAT classic / PAT fine-grained / GitHub App installation / `gh` OAuth, each with required-scopes row and token-storage note; (b) **Sub-Issue Representation Modes** — `native` (GitHub sub-issue REST) vs `labeled-fallback` (`parent:<phase-id>` / `child:<task-id>` + reciprocal body links) with preflight semantics; (c) **Partial Mapping Table (P02)** — milestone↔Milestone, phase↔`label:phase` Issue, task↔sub-issue; the chunk↔custom-field, AC↔checklist-item, and verification-status↔Project-v2-status-field rows are present with the cell value `_deferred to P03_` (table scaffolding shipped now so P03 fills cells in place).
  - Check: `bash scripts/verify/m013-p02-reference-extensions.sh`

- `scripts/integrations/github-init.sh` respects the P01-established pending-sentinel discipline: under auto-mode (no TTY) with absent sidecar it writes a `pending`-sentinel sidecar via the P01 `sidecar-init-pending.sh` helper and exits 0 with `STATUS: pending-operator-complete` without calling `gh` for writes; live Issue/Project creation fires only when the operator explicitly invokes `github-init.sh` interactively (with a TTY) or passes `--i-am-operator`. This preserves SC-7 zero-prompts under auto-mode.
  - Check: `bash scripts/verify/m013-p02-auto-mode-pending.sh`

- Every P02-touched or P02-created `.sh` file is Bash 3.2 compatible (no `declare -A`, no `mapfile`/`readarray`, no `${var^^}`/`${var,,}`, no `<(...)`/`>(...)`, no `&>`/`|&`) and passes `scripts/verify/anti-pattern-lint.sh` (Constitution IX, Constitution XV, SC-6, MEM001).
  - Check: `bash scripts/verify/m013-p02-bash32-compat.sh`

- `bash scripts/verify/m013-p02-phase-suite.sh` orchestrates all eight P02 gates (github-common, github-init-fixture, github-init-preflight, dry-run-manifest, github-init-command, reference-extensions, auto-mode-pending, bash32-compat) in dependency order and exits 0 on green, non-zero with a per-gate PASS/FAIL breakdown otherwise.
  - Check: `bash scripts/verify/m013-p02-phase-suite.sh`

### Artifacts

- `scripts/integrations/github-common.sh` (min 120 lines, contains "orchestrator_id_for")
- `scripts/integrations/github-init.sh` (min 200 lines, contains "pending-operator-complete")
- `commands/github-init.md` (min 50 lines, contains "github-init.sh")
- `references/github-integration.md` (min 240 lines, contains "Auth Modes") — modify-in-place extension of P01 skeleton
- `templates/github-integration-sidecar.json` (min 18 lines, contains "sub_issue_mode") — modify-in-place, add `sub_issue_mode: pending` field to schema + `_schema_docs` entry
- `tests/fixtures/m013-p02/` (directory tree with `orchestrator-state/` seed layout + `expected-manifest.txt` snapshot + `gh-stub-responses/` for preflight probes)
- `scripts/verify/m013-p02-github-common.sh` (min 40 lines, contains "orchestrator_id_for")
- `scripts/verify/m013-p02-github-init-fixture.sh` (min 60 lines, contains "items")
- `scripts/verify/m013-p02-github-init-preflight.sh` (min 40 lines, contains "integration-auth-failed")
- `scripts/verify/m013-p02-dry-run-manifest.sh` (min 40 lines, contains "MANIFEST:")
- `scripts/verify/m013-p02-github-init-command.sh` (min 25 lines, contains "Referenced Scripts")
- `scripts/verify/m013-p02-reference-extensions.sh` (min 40 lines, contains "Auth Modes")
- `scripts/verify/m013-p02-auto-mode-pending.sh` (min 30 lines, contains "pending-operator-complete")
- `scripts/verify/m013-p02-bash32-compat.sh` (min 30 lines, contains "declare -A")
- `scripts/verify/m013-p02-phase-suite.sh` (min 50 lines, contains "m013-p02")

### Key Links

- `commands/github-init.md` → `scripts/integrations/github-init.sh` (Referenced Scripts section names the script by path, per MEM012)
- `commands/github-init.md` → `scripts/integrations/github-common.sh` (shared helper dependency declared)
- `commands/github-init.md` → `scripts/integrations/github-status.sh` (documents post-init verification path)
- `scripts/integrations/github-init.sh` → `scripts/integrations/github-common.sh` (sources the helpers)
- `scripts/integrations/github-init.sh` → `scripts/integrations/sidecar-init-pending.sh` (reuses P01 bootstrap under auto-mode)
- `scripts/integrations/github-init.sh` → `templates/github-integration-sidecar.json` (populated on live run; schema is the authority)
- `scripts/integrations/github-init.sh` → `.orchestrator/integrations/github.json` (writes sidecar field updates)
- `references/github-integration.md` → `templates/github-integration-sidecar.json` (documents the `sub_issue_mode` addition)
- `references/github-integration.md` → `commands/github-init.md` (cross-links the new subcommand)
- `references/README.md` → `references/github-integration.md` (no change; entry exists from P01 — P02 extends the doc in place)
- `scripts/verify/m013-p02-phase-suite.sh` → `scripts/verify/m013-p02-github-common.sh` (orchestrated gate)
- `scripts/verify/m013-p02-phase-suite.sh` → `scripts/verify/m013-p02-github-init-fixture.sh` (orchestrated gate)
- `scripts/verify/m013-p02-phase-suite.sh` → `scripts/verify/m013-p02-github-init-preflight.sh` (orchestrated gate)
- `scripts/verify/m013-p02-phase-suite.sh` → `scripts/verify/m013-p02-dry-run-manifest.sh` (orchestrated gate)
- `scripts/verify/m013-p02-phase-suite.sh` → `scripts/verify/m013-p02-github-init-command.sh` (orchestrated gate)
- `scripts/verify/m013-p02-phase-suite.sh` → `scripts/verify/m013-p02-reference-extensions.sh` (orchestrated gate)
- `scripts/verify/m013-p02-phase-suite.sh` → `scripts/verify/m013-p02-auto-mode-pending.sh` (orchestrated gate)
- `scripts/verify/m013-p02-phase-suite.sh` → `scripts/verify/m013-p02-bash32-compat.sh` (orchestrated gate)

## Tasks

### T01: `scripts/integrations/github-common.sh` shared helpers + P02 test fixture scaffolding

See `tasks/T01-PLAN.md`.

### T02: `scripts/integrations/github-init.sh` — create-path implementation (preflights + lazy projection + sidecar population)

See `tasks/T02-PLAN.md`.

### T03: FR-15 `--dry-run` manifest emission + format contract

See `tasks/T03-PLAN.md`.

### T04: `commands/github-init.md` subcommand definition

See `tasks/T04-PLAN.md`.

### T05: `references/github-integration.md` P02 extensions — Auth Modes + Sub-Issue Modes + Partial Mapping Table

See `tasks/T05-PLAN.md`.

### T06: `templates/github-integration-sidecar.json` schema extension — `sub_issue_mode` field

See `tasks/T06-PLAN.md`.

### T07: Phase verification suite — eight gates + phase-suite orchestrator

See `tasks/T07-PLAN.md`.

## Task Dependencies

```
T01 ──► T02 ──► T03 ──┐
  │                   │
  │     T06 ──────────┤
  │                   │
  └───► T04 ──────────┤
                      │
        T05 ──────────┴──► T07
```

T01 authors the shared helper library (`github-common.sh`) + fixture tree that T02/T03 consume. T02 ships `github-init.sh` create-path (auth/sub-issue/label preflights + lazy Issue/sub-issue projection + marker emit + sidecar population). T03 ships the `--dry-run` manifest format; it lives inside `github-init.sh` but has a dedicated gate because its format is load-bearing for P03 re-init + P04 sync. T04 ships the command markdown (MEM012 structure). T05 extends `references/github-integration.md` with the three P02 sections. T06 adds `sub_issue_mode` to the sidecar template schema. T07 closes the suite with eight gates + phase-suite orchestrator. Dispatch may execute T04/T05/T06 in parallel once T01 completes; T02 depends on T01; T03 depends on T02; T07 depends on all predecessors.

## Files Likely Touched

- `scripts/integrations/github-common.sh` (create)
- `scripts/integrations/github-init.sh` (create)
- `commands/github-init.md` (create)
- `references/github-integration.md` (modify — fill `TODO P02` stubs in place; P01-authored sections stay byte-identical)
- `templates/github-integration-sidecar.json` (modify — add `sub_issue_mode` field + `_schema_docs` entry)
- `tests/fixtures/m013-p02/` (create — directory tree)
- `tests/fixtures/m013-p02/orchestrator-state/` (create — seed milestone/phase/task structure for fixture-driven dry-run)
- `tests/fixtures/m013-p02/expected-manifest.txt` (create — pinned `--dry-run` output snapshot)
- `tests/fixtures/m013-p02/gh-stub-responses/` (create — canned `gh api` / `gh auth status` responses for preflight probes)
- `scripts/verify/m013-p02-github-common.sh` (create)
- `scripts/verify/m013-p02-github-init-fixture.sh` (create)
- `scripts/verify/m013-p02-github-init-preflight.sh` (create)
- `scripts/verify/m013-p02-dry-run-manifest.sh` (create)
- `scripts/verify/m013-p02-github-init-command.sh` (create)
- `scripts/verify/m013-p02-reference-extensions.sh` (create)
- `scripts/verify/m013-p02-auto-mode-pending.sh` (create)
- `scripts/verify/m013-p02-bash32-compat.sh` (create)
- `scripts/verify/m013-p02-phase-suite.sh` (create)
