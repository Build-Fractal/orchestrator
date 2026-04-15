---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P07"
milestone: "M003"
name: "Thread Resolved Target Root Through Pipeline"
depends_on: []
---

## Prerequisites

These files already exist on disk and form the input boundary for this task:

- `scripts/state/resolve-root.sh` — M008 5-rule state-root resolver. Supports `--absolute` (emit absolute path), `--verbose`, default (emit repo-relative path). Exit 0 on success, 1 on malformed argument. Reads `ORCHESTRATOR_ROOT` env, then `.orchestrator/config.yml` / `.specify/orchestrator/config.yml` `state_root:` field, then `.orchestrator/`, then `.specify/orchestrator/`, then defaults to `.orchestrator`.
- `scripts/migrate/migrate.sh` — current migration entry point (448 lines). Already parses `--path`, `--source`, `--recent-count`, `--output`, `--merge`/`--force`/`--abort`. Currently sets `target_root="${opt_output:-$(pwd)}"` near line 403 and passes that to every transform call. No reference to the resolver yet.
- `scripts/migrate/transform/milestone-rollup.sh` — accepts `<intermediate_dir> <target_root> <milestone_id> [--tier ...]`. Hardcodes `${target_root}/.specify/orchestrator/milestones/summaries` at line 92 and `${target_root}/.specify/orchestrator/milestones/rollups` at line 96.
- `scripts/migrate/transform/active-milestone.sh` — accepts `<intermediate_dir> <target_root> <milestone_id>`. Hardcodes `${target_root}/.specify/orchestrator/milestones/M001` at line 68.
- `scripts/migrate/transform/milestone-tiering.sh` — accepts `<intermediate_dir> <target_root> [--recent-count N]`. Hardcodes `${target_root}/.specify/orchestrator/milestones/summaries` and `.../rollups` at lines 58–59. Re-invokes `active-milestone.sh` and `milestone-rollup.sh` with `$target_root` (the same surface the caller passes in).
- `scripts/migrate/transform/{knowledge.sh,knowledge-index.sh,decisions.sh,requirements.sh,telemetry-aggregator.sh,report.sh}` — already accept `target_root` as their second positional argument and write under it; we will not modify them.

## Description

Make `migrate.sh` resolve its target root via the M008 5-rule resolver when `--output` is not provided, and stop having the transform scripts hardcode the `.specify/orchestrator/` segment. The `target_root` value passed to every transform script becomes the absolute path of the orchestrator state root (e.g. `/path/to/repo/.orchestrator` or `/path/to/repo/.specify/orchestrator` or whatever `ORCHESTRATOR_ROOT` says) — not a project-root path with `.specify/orchestrator/` appended downstream.

After this task, every transform script writes directly under `$target_root/...` with no `.specify/orchestrator/` literal anywhere in `scripts/migrate/`.

## Steps

### Step 1: Update `scripts/migrate/migrate.sh` — resolver wiring

Find the existing `target_root` assignment (currently around line 403):

```bash
target_root="${opt_output:-$(pwd)}"
```

Replace with:

```bash
# Resolve target root via M008 5-rule resolver (AD-13).
# --output takes precedence (offline extraction path).
if [ -n "$opt_output" ]; then
    target_root="$opt_output"
    log_info "Target root (from --output): $target_root"
else
    target_root="$(bash "$(dirname "${BASH_SOURCE[0]}")/../state/resolve-root.sh" --absolute)"
    log_info "Target root (from resolve-root.sh): $target_root"
fi
export MIGRATE_TARGET_ROOT="$target_root"
mkdir -p "$target_root"
```

Notes:
- `bash …/state/resolve-root.sh --absolute` is invoked, not sourced, because the resolver is `set -u` and uses positional argument parsing that would clobber `$@` of the caller.
- `MIGRATE_TARGET_ROOT` is exported so verify scripts can grep for it in log output and so future transforms can read it from env if needed.
- `mkdir -p "$target_root"` is safe whether the path exists or not.

### Step 2: Update `scripts/migrate/transform/milestone-rollup.sh`

Replace line 92:
```bash
out_dir="${target_root}/.specify/orchestrator/milestones/summaries"
```
with:
```bash
out_dir="${target_root}/milestones/summaries"
```

Replace line 96:
```bash
out_dir="${target_root}/.specify/orchestrator/milestones/rollups"
```
with:
```bash
out_dir="${target_root}/milestones/rollups"
```

Update the header `Usage:` comment (lines 14, 16) so the documented output paths drop the `.specify/orchestrator/` prefix.

### Step 3: Update `scripts/migrate/transform/active-milestone.sh`

Replace line 68:
```bash
ms_dir="${target_root}/.specify/orchestrator/milestones/M001"
```
with:
```bash
ms_dir="${target_root}/milestones/M001"
```

### Step 4: Update `scripts/migrate/transform/milestone-tiering.sh`

Replace lines 58–59:
```bash
mkdir -p "${target_root}/.specify/orchestrator/milestones/summaries"
mkdir -p "${target_root}/.specify/orchestrator/milestones/rollups"
```
with:
```bash
mkdir -p "${target_root}/milestones/summaries"
mkdir -p "${target_root}/milestones/rollups"
```

The two re-invocations of child transforms further down the file (lines 179, 187, 197) already pass `$target_root` through unchanged — no edit needed there.

### Step 5: Sanity scan for residual literals

After edits, run a manual sanity check:

```bash
grep -rn '\.specify/orchestrator' scripts/migrate/
```

The only acceptable matches are inside comments that explicitly document the M008 bridge path. Any code-path occurrence is a regression. (T05 will land an automated check for this.)

## Must-Haves

This task addresses these phase truths:

- `migrate.sh` sources / invokes `scripts/state/resolve-root.sh` and computes the target root via the 5-rule resolver when `--output` is not provided.
- No migration transform script writes a hardcoded `.specify/orchestrator/` path; every output path is derived from the `target_root` argument passed in by `migrate.sh`.
- Bash 3.2 compatibility preserved (no `declare -A`, no `< <(…)`, no `|&`, no `${var,,}`).

## Verification

Run, in this order:

```
bash scripts/migrate/migrate.sh --help
bash scripts/migrate/migrate.sh --path /tmp/does-not-exist --output /tmp/p07-t01-smoke --force
```

Expected behavior:
- `--help` exits 0.
- The `--path /tmp/does-not-exist` invocation exits non-zero with the existing "Source path does not exist" error — but BEFORE that error, the wiring change still must compile, so a Bash syntax error in the new block is the failure mode this catches.

Then run a positive smoke:

```
bash scripts/migrate/migrate.sh --path . --output /tmp/p07-t01-smoke --force
```

Expected log contains a line like:
```
[INFO]  Target root (from --output): /tmp/p07-t01-smoke
```

Final structural sanity check (T05 will automate this):

```
grep -rn '\.specify/orchestrator' scripts/migrate/migrate.sh scripts/migrate/transform/
```

Only comment-only matches are acceptable.

## Inputs

### From Previous Tasks

None — T01 is the leaf task in this phase.

### From Disk (Pre-existing)

- `scripts/state/resolve-root.sh` — invoked as `bash <path> --absolute`; emits one absolute path on stdout. Exit 0 success.
- `scripts/migrate/migrate.sh` — modify `target_root` assignment block.
- `scripts/migrate/transform/milestone-rollup.sh`, `active-milestone.sh`, `milestone-tiering.sh` — modify the lines listed in Steps 2–4.

## Constraints

- **Bash 3.2 only** (MEM001). No `declare -A`, no `mapfile`/`readarray`, no `< <(...)`, no `|&`, no `${var,,}`.
- **Do not change transform script signatures**: every transform still takes `<intermediate_dir> <target_root> [...]` positionals. We are changing the *interpretation* of `target_root` (now: the orchestrator state root, absolute), not the calling convention.
- **Do not modify** `transform/knowledge.sh`, `transform/knowledge-index.sh`, `transform/decisions.sh`, `transform/requirements.sh`, `transform/telemetry-aggregator.sh`, `transform/report.sh` — they already write under `$target_root/...` directly and will pick up the new semantics without edits.
- **Source-directory non-destructiveness** (AD-10) — no writes outside `$target_root`.
- The `--output` flag MUST continue to win over the resolver (offline extraction path stays intact).

## Expected Output

After this task:
- `migrate.sh` logs the resolved target root and exports `MIGRATE_TARGET_ROOT`.
- All four modified transform scripts write directly under `$target_root/...` (no embedded `.specify/orchestrator/` segment).
- `grep -rn '\.specify/orchestrator' scripts/migrate/` returns matches only inside comments.
- `scripts/migrate/migrate.sh --help` still exits 0; running without `--path` still exits 1.
