---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P02"
milestone: "M013"
name: "scripts/integrations/github-common.sh shared helpers + P02 test fixture scaffolding"
depends_on: []
---

## Prerequisites

- Bash 3.2 target — no `declare -A`, no `mapfile`/`readarray`, no `<(...)`/`>(...)`, no `&>`/`|&`, no `${var^^}`/`${var,,}` (MEM001, Constitution IX, IX).
- The AD-19 harness safety heuristic above the allow list rejects inline compound bash in user-facing `Check:` commands. **This constraint applies to the `Check:` lines in phase/task plans, NOT to the internals of the scripts themselves.** The scripts may freely use `if`, `for`, `while`, `case`, `$(...)`, etc. (all standard Bash 3.2 control flow). Verify scripts *invoke* those scripts with a single-script-file shape.
- The M013/P01 pending-sentinel bootstrap helper `scripts/integrations/sidecar-init-pending.sh` and `scripts/integrations/github-status.sh` exist and are Bash 3.2 clean. T02 will source/invoke `github-common.sh`; this task ships the library only.
- Known orchestrator bug: `scripts/lifecycle/phase-transition.sh` crashes on non-numeric `duration:` fields under `set -euo pipefail`. Do NOT author a helper that emits non-numeric duration values. (`write-summary.sh` still requires all 15 frontmatter fields explicitly.)
- FR-4 marker format is exactly `<!-- orchestrator-id: M###-P##[-T##] -->` — three zero-padded digits for milestone, two for phase and task. This is documented in `references/github-integration.md` P01 skeleton section "<!-- orchestrator-id: ... --> Marker Format" and is the SSOT the helpers encode.

## Description

Author `scripts/integrations/github-common.sh` — a pure shell helper library consumed by T02's `github-init.sh`. The library contains:

1. **Orchestrator-ID derivation**: given a milestone directory (e.g. `.orchestrator/milestones/M013/`) and a phase ID (`P02`) and optional task ID (`T03`), compute the orchestrator-id `M###-P##[-T##]` deterministically.
2. **Marker emit/search primitives**: emit the literal FR-4 HTML-comment marker; search an Issue body blob for exactly one marker matching a given id (exit 0 = unique, 1 = zero, 2 = duplicate).
3. **Sidecar cache upsert**: read/write top-level fields (`repo_slug`, `project_v2_id`, `sub_issue_mode`) and insert/replace `items.<id>` entries in `.orchestrator/integrations/github.json` without jq hard-dep (AWK for JSON object insertion; grep/sed for top-level field updates; matches P01's pattern in `sidecar-init-pending.sh`).
4. **Preflight helpers (stubbed at T01; populated by T02)**: thin wrappers around `gh auth status`, `gh api /repos/<slug>/issues` (sub-issue REST availability probe), and `gh label list` (label-collision preflight). T01 defines the function contracts + echo-stub bodies that T02 fills with real `gh` invocations guarded by the `--dry-run` flag.

Also ship the **P02 fixture tree** at `tests/fixtures/m013-p02/` so T02/T03 gates have reproducible inputs without live `gh` calls.

## Steps

### Step 1: Create `scripts/integrations/github-common.sh`

Write the file with exact header and function contracts below. All functions use local variables and parallel indexed arrays — never `declare -A`. Every function documents its exit semantics.

```bash
#!/usr/bin/env bash
# scripts/integrations/github-common.sh — Shared helpers for M013 GitHub integration.
#
# Sourced by scripts/integrations/github-init.sh (P02) and will be sourced
# by scripts/integrations/github-sync.sh (P04) and scripts/integrations/github-init.sh
# P03 re-adoption branch. Pure functions only — no side effects at source time.
#
# Bash 3.2 compatible (MEM001, Constitution IX). No jq hard dep.
# No gh subprocess calls from functions documented below unless the caller
# explicitly passes --live (T02 adds that plumbing; T01 ships echo-stubs).

set -u

# --- Orchestrator-ID derivation ------------------------------------------------

# orchestrator_id_for <milestone-dir> <phase-id> [<task-id>]
# Prints deterministic id: M###-P##[-T##]. Exits 2 on bad input.
orchestrator_id_for() {
  # milestone-dir basename must match ^M[0-9]{3}$; phase-id ^P[0-9]{2}$; task-id ^T[0-9]{2}$.
  # If any arg is malformed, echo to stderr and return 2.
  # Implementation uses basename + bash regex [[ "$x" =~ ^M[0-9]{3}$ ]] which is 3.2-safe.
  :
}

# --- Marker primitives ---------------------------------------------------------

MARKER_PREFIX='<!-- orchestrator-id: '
MARKER_SUFFIX=' -->'

# emit_marker <orchestrator-id>
# Prints the FR-4 marker line (no trailing newline control — stdout only).
emit_marker() { :; }

# find_marker_in_body <body-file-path> <orchestrator-id>
# Exit 0 if file contains exactly one matching marker line.
# Exit 1 if zero matches. Exit 2 if >1 matches (collision; caller should
# surface a label-collision / duplicate-marker diagnostic).
find_marker_in_body() { :; }

# shasum_marker_byte_identity <body-file-path> <orchestrator-id>
# For FR-4's byte-identity verification (M012 marker-bounded-atomic-writes pattern):
# computes shasum of the expected marker line and of the line actually present in
# the body, exits 0 if identical, 1 otherwise. Useful for post-create verification.
shasum_marker_byte_identity() { :; }

# --- Sidecar field read/write (top-level) --------------------------------------

# sidecar_path [<project-root>]
# Prints the absolute path to .orchestrator/integrations/github.json.
sidecar_path() { :; }

# sidecar_get_field <field-name> [<project-root>]
# Prints the top-level JSON string/integer value (verbatim, unquoted).
# Exits 0 on hit, 1 if field absent, 2 if sidecar absent.
sidecar_get_field() { :; }

# sidecar_set_top_field <field-name> <new-value> [<project-root>]
# Updates a top-level JSON string field in place (replaces "pending" with
# the real value, or replaces any prior string). Bash 3.2 + sed only.
# Exits 0 on success, 2 if sidecar absent, 3 if field absent.
sidecar_set_top_field() { :; }

# --- Per-item cache upsert -----------------------------------------------------

# sidecar_upsert_item <orchestrator-id> <issue-number> <project-v2-attached> \
#                     <status-field-synced> <last-attempt-iso8601> [<project-root>]
# Inserts or replaces the items.<orchestrator-id> object. Per-item schema pinned
# at P01 (issue_number, project_v2_attached, status_field_synced, last_attempt_at,
# last_error, schema_version). last_error is written as null on successful upsert.
# AWK-based JSON object insertion — no jq dependency.
# Exits 0 on success, 2 if sidecar absent, 3 on malformed args.
sidecar_upsert_item() { :; }

# sidecar_item_exists <orchestrator-id> [<project-root>]
# Exit 0 if items.<orchestrator-id> has a cache entry, 1 otherwise.
sidecar_item_exists() { :; }

# --- gh preflight stubs (T01 ships echo-stubs; T02 fills in live calls) --------

# gh_auth_preflight
# T01 stub: prints "AUTH: stub-ok" and returns 0.
# T02 impl: wraps `gh auth status` + scope enumeration, returns 0 on green,
# exits 1 with `integration-auth-failed: missing scope <name>` on red.
gh_auth_preflight() { :; }

# gh_subissue_rest_preflight <repo-slug>
# T01 stub: prints "SUBISSUE_MODE: native" and returns 0.
# T02 impl: probes sub-issue REST endpoint; returns mode {native|labeled-fallback}
# and logs fallback reason.
gh_subissue_rest_preflight() { :; }

# gh_label_collision_preflight <repo-slug> <strict-mode-flag>
# T01 stub: prints "LABELS: no-collision" and returns 0.
# T02 impl: enumerates pre-existing labels matching {phase, task, uat-bug, spec-gap};
# adopt by default, refuse on --strict-labels collision with non-matching color.
gh_label_collision_preflight() { :; }
```

Fill in the implementations of `orchestrator_id_for`, the two marker functions, `sidecar_path`, `sidecar_get_field`, `sidecar_set_top_field`, `sidecar_item_exists`, and `sidecar_upsert_item`. Leave the three `gh_*_preflight` helpers as echo-stubs returning 0 — T02 fills them.

### Step 2: Create fixture tree at `tests/fixtures/m013-p02/`

```
tests/fixtures/m013-p02/
├── orchestrator-state/                # Seed layout matching a minimal orchestrator project.
│   └── .orchestrator/
│       └── milestones/
│           └── M013/
│               ├── M013-ROADMAP.md    # Single in-flight phase + two tasks for dry-run.
│               └── phases/
│                   ├── P02/
│                   │   ├── P02-PLAN.md
│                   │   └── tasks/
│                   │       ├── T01-PLAN.md
│                   │       └── T02-PLAN.md
│                   └── P03/
│                       └── P03-PLAN.md  # Planning-state phase — must NOT project (AS-4a).
├── expected-manifest.txt                # Pinned dry-run output snapshot (T03 gate uses this).
└── gh-stub-responses/
    ├── auth-status-green.txt            # Mock `gh auth status` passing output.
    ├── auth-status-missing-scope.txt    # Mock `gh auth status` with missing `project` scope.
    ├── subissue-rest-available.json     # Mock `gh api /repos/.../issues/.../sub_issues` 200.
    ├── subissue-rest-unavailable.json   # Mock endpoint returning 404.
    ├── labels-empty.json                # Mock `gh label list` with zero matches.
    └── labels-collision.json            # Mock with pre-existing `phase` label wrong color.
```

The `P02-PLAN.md` and task-plan files in the seed may be stubs (a single YAML frontmatter block is sufficient — the dry-run walker only reads `phase:` / `task:` ids from frontmatter). Put at least two tasks under P02 and zero tasks under P03 so AS-4a lazy-projection logic (Planning-state phase with zero tasks) is exercised.

### Step 3: Verify the helper library sources cleanly

Add a self-check at the end of `github-common.sh`:

```bash
# If sourced directly as the main script, print a friendly usage hint and exit 0.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  echo "scripts/integrations/github-common.sh: this is a helper library; source it, don't run it."
  echo "Public functions: orchestrator_id_for, emit_marker, find_marker_in_body, shasum_marker_byte_identity,"
  echo "                  sidecar_path, sidecar_get_field, sidecar_set_top_field,"
  echo "                  sidecar_upsert_item, sidecar_item_exists,"
  echo "                  gh_auth_preflight, gh_subissue_rest_preflight, gh_label_collision_preflight."
  exit 0
fi
```

## Must-Haves

From the P02-PLAN:

- `scripts/integrations/github-common.sh` exists, is ≥120 lines, contains the string `orchestrator_id_for`, sources with `set -u` cleanly, and is Bash 3.2 compatible.
- The file defines (even as stubs) every function listed in Step 1.
- The fixture tree under `tests/fixtures/m013-p02/` exists with the seed orchestrator-state subdirectory and the six `gh-stub-responses/` files.

## Verification

Run these single-script-file checks (no compound bash):

```bash
bash scripts/verify/m013-p02-github-common.sh
```

Expected: `PASS: github-common.sh <N> public functions defined, sources cleanly, Bash 3.2 clean.` and exit 0. The gate itself is authored in T07 — this task pre-declares the contract the gate will enforce.

Spot check fixture tree exists:

```bash
ls tests/fixtures/m013-p02/orchestrator-state/.orchestrator/milestones/M013/M013-ROADMAP.md
ls tests/fixtures/m013-p02/gh-stub-responses/auth-status-green.txt
```

## Inputs

### From Previous Tasks

None — this is the first task in P02.

### From Disk (Pre-existing)

- `scripts/integrations/sidecar-init-pending.sh` (from M013/P01/T01)
  - Key API: `sidecar-init-pending.sh [--root <dir>]` — writes `pending`-sentinel sidecar; exits 2 if target exists.
  - Used by: T02's auto-mode path will invoke this.
- `scripts/integrations/github-status.sh` (from M013/P01/T02)
  - Key API: prints `STATUS: {absent|pending-operator-complete|configured}`; supports `--init-pending` bootstrap flag.
  - Used by: T02's operator-handoff reporting.
- `templates/github-integration-sidecar.json` (from M013/P01/T01)
  - Canonical schema source; top-level fields `schema_version, repo_slug, project_v2_id, sync_mode, recommended_cron, custom_field_mappings, items`.
  - T06 will extend this schema with `sub_issue_mode`; T01 reads it only as a reference.
- `references/github-integration.md` (from M013/P01/T06)
  - Documents the marker format T01 encodes in `emit_marker`.
- `scripts/verify/anti-pattern-lint.sh` (M016/[M021](../../../../../milestones/M021/index.md) invariant)
  - Used by T07 bash32-compat gate.

## Constraints

- **Knowledge-Layer Boundary (FR-9 + D014)**: this task MUST NOT modify any `knowledge/spec/**/SPEC-*.md` frontmatter. It MUST NOT add review-state lifecycle, query-surface, or clustering primitives. [M020](../../../../../milestones/M020/index.md) owns schema extension.
- **FR-12 Claude-Code-only v1**: no multi-runtime abstractions. `github-common.sh` is shell-agnostic but its consumers are single-runtime in v1.
- **AD-19 `Check:` shape**: verify scripts invoke single-script-file shape only. The helper library internals are unconstrained (standard Bash 3.2 control flow is fine inside the library; the safety heuristic only fires on `Check:` lines in plans).
- **No live `gh` calls at T01**: the three `gh_*_preflight` helpers are echo-stubs. T02 fills them. CI must pass without a real `gh` login.
- **No schema changes to M011/[M012](../../../../../milestones/M012/index.md) artifacts**: do not touch `KNOWLEDGE-INDEX.md`, `knowledge/spec/`, `scripts/knowledge/rebuild-index.sh`, or any `wiki/` file.
- **Bash 3.2**: no `declare -A`, no `mapfile`/`readarray`, no `<(...)`/`>(...)`, no `&>`/`|&`, no `${var^^}`/`${var,,}`. Use parallel indexed arrays and sed/awk/grep.
- **`set -u` clean**: all variables initialized before first read.
- **Zero `gh` subprocess calls** from library functions at T01 scope.

## Expected Output

Running the T07 gate `bash scripts/verify/m013-p02-github-common.sh` after T01 lands reports:

```
PASS: github-common.sh present at scripts/integrations/github-common.sh
PASS: orchestrator_id_for emits M013-P02 for (M013-dir, P02)
PASS: orchestrator_id_for emits M013-P02-T03 for (M013-dir, P02, T03)
PASS: orchestrator_id_for rejects malformed phase id
PASS: emit_marker emits '<!-- orchestrator-id: M013-P02 -->'
PASS: find_marker_in_body finds unique marker (exit 0)
PASS: find_marker_in_body reports duplicate (exit 2)
PASS: sidecar_path resolves to .orchestrator/integrations/github.json
PASS: sidecar_get_field returns pending for fresh sentinel
PASS: sidecar_set_top_field replaces repo_slug in place
PASS: sidecar_upsert_item inserts items.M013-P02 entry
PASS: bash -n github-common.sh (Bash 3.2 syntax check)
PASS: anti-pattern-lint clean
PASS: github-common.sh 13/13 assertions, Bash 3.2 clean.
```

Exit 0.
