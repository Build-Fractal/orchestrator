---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P07"
milestone: "M003"
name: "Write Seven Verify Scripts"
depends_on: ["T01", "T02", "T03", "T04"]
---

## Prerequisites

T01–T04 have all landed:

- T01 — `migrate.sh` invokes `bash scripts/state/resolve-root.sh --absolute` (when `--output` not given), exports `MIGRATE_TARGET_ROOT`, and emits a `Target root (from …)` log line. Transforms no longer hardcode `.specify/orchestrator/`.
- T02 — `lib/idempotency.sh::check_existing_state` probes both layouts (orchestrator-root markers + `.orchestrator/` / `.specify/orchestrator/` subdirs).
- T03 — `migrate.sh` ends with a `P04 — Knowledge Index + Graph Rebuild` step calling `bash scripts/knowledge/rebuild-index.sh --root "$target_root"`.
- T04 — `commands/migrate.md` contains AD-13/AD-14/AD-15 sections and references `resolve-root.sh`, `rebuild-index.sh`, `detect-overlap.sh`.

## Description

Create seven verify scripts under `scripts/verify/m003-p07-*.sh`. Each is a single-script-file invocation per AD-19, prints `PASS:` on success and `FAIL:` on failure, exits 0 / 1. They are wired into the phase plan's Truth `Check:` lines and into the standard `check-must-haves.sh` run.

The scripts perform STATIC checks (Tier 1) — they grep the modified files for proxy patterns. They are NOT end-to-end tests of migration behavior; that is P08's job.

## Steps

For each script below, create the file under `scripts/verify/`, `chmod +x` it, and verify it passes after T01–T04. Each script begins with `#!/usr/bin/env bash` and `set -eu`.

### Script 1: `m003-p07-migrate-sources-resolver.sh`

```bash
#!/usr/bin/env bash
set -eu
f="scripts/migrate/migrate.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'resolve-root.sh' "$f" || { echo "FAIL: migrate.sh does not invoke resolve-root.sh"; exit 1; }
grep -q 'MIGRATE_TARGET_ROOT' "$f" || { echo "FAIL: migrate.sh does not export MIGRATE_TARGET_ROOT"; exit 1; }
grep -qE '\-\-absolute' "$f" || { echo "FAIL: migrate.sh does not call resolve-root.sh --absolute"; exit 1; }
echo "PASS: migrate.sh wires resolve-root.sh and exports MIGRATE_TARGET_ROOT"
```

### Script 2: `m003-p07-no-hardcoded-state-paths.sh`

```bash
#!/usr/bin/env bash
set -eu
# Find any .specify/orchestrator literal in code lines (not comments).
# Code-line heuristic: line does not start (after optional whitespace) with '#'.
hits=0
for f in scripts/migrate/migrate.sh scripts/migrate/transform/milestone-rollup.sh scripts/migrate/transform/active-milestone.sh scripts/migrate/transform/milestone-tiering.sh; do
  test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
  while IFS= read -r line; do
    case "$line" in
      \#*|"") continue ;;
      *[[:space:]]\#*) continue ;;
    esac
    case "$line" in
      *.specify/orchestrator*) hits=$((hits+1)); echo "  hit in $f: $line" ;;
    esac
  done < "$f"
done
if [ "$hits" -gt 0 ]; then
  echo "FAIL: found $hits hardcoded .specify/orchestrator path(s) in migration code"
  exit 1
fi
echo "PASS: no hardcoded .specify/orchestrator paths in migration code"
```

(The `case` against `*[[:space:]]\#*` filters trailing-comment lines. The `while IFS= read -r line; do ... done < "$f"` is a clean redirect, not a process substitution — Bash 3.2 safe and AD-19 safe.)

### Script 3: `m003-p07-rebuild-index-wired.sh`

```bash
#!/usr/bin/env bash
set -eu
f="scripts/migrate/migrate.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'rebuild-index.sh' "$f" || { echo "FAIL: migrate.sh does not invoke rebuild-index.sh"; exit 1; }
grep -qE -- '--root[[:space:]]+"\$' "$f" || grep -qE -- '--root[[:space:]]+"\$\{?MIGRATE_TARGET_ROOT' "$f" || grep -qE -- '--root[[:space:]]+"\$target_root' "$f" || { echo "FAIL: rebuild-index.sh not invoked with --root <resolved>"; exit 1; }
echo "PASS: migrate.sh invokes rebuild-index.sh --root <resolved> as final step"
```

### Script 4: `m003-p07-idempotency-dual-root.sh`

```bash
#!/usr/bin/env bash
set -eu
f="scripts/migrate/lib/idempotency.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q '\.orchestrator' "$f" || { echo "FAIL: idempotency.sh does not probe .orchestrator/"; exit 1; }
grep -q '\.specify/orchestrator' "$f" || { echo "FAIL: idempotency.sh does not probe .specify/orchestrator/"; exit 1; }
grep -q 'KNOWLEDGE-INDEX.md' "$f" || { echo "FAIL: idempotency.sh missing KNOWLEDGE-INDEX.md probe"; exit 1; }
echo "PASS: idempotency.sh probes both .orchestrator/ and .specify/orchestrator/"
```

### Script 5: `m003-p07-migrate-md-documents-ads.sh`

```bash
#!/usr/bin/env bash
set -eu
f="commands/migrate.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'AD-13' "$f" || { echo "FAIL: commands/migrate.md missing AD-13 reference"; exit 1; }
grep -q 'AD-14' "$f" || { echo "FAIL: commands/migrate.md missing AD-14 reference"; exit 1; }
grep -q 'AD-15' "$f" || { echo "FAIL: commands/migrate.md missing AD-15 reference"; exit 1; }
grep -q 'resolve-root' "$f" || { echo "FAIL: commands/migrate.md missing resolve-root reference"; exit 1; }
grep -q 'detect-overlap' "$f" || { echo "FAIL: commands/migrate.md missing detect-overlap reference"; exit 1; }
grep -q 'rebuild-index' "$f" || { echo "FAIL: commands/migrate.md missing rebuild-index reference"; exit 1; }
echo "PASS: commands/migrate.md documents AD-13/14/15 and references all three scripts"
```

### Script 6: `m003-p07-bash32-compat.sh`

```bash
#!/usr/bin/env bash
set -eu
files="scripts/migrate/migrate.sh scripts/migrate/transform/milestone-rollup.sh scripts/migrate/transform/active-milestone.sh scripts/migrate/transform/milestone-tiering.sh scripts/migrate/lib/idempotency.sh"
for f in $files; do
  test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
done
# Strip comments and blank lines, then scan for Bash 4+ constructs.
hits=0
for f in $files; do
  if grep -nE '^[[:space:]]*[^#].*(declare -A|mapfile|readarray|\|&|\$\{[A-Za-z_][A-Za-z0-9_]*,,\}|\$\{[A-Za-z_][A-Za-z0-9_]*\^\^\})' "$f"; then
    hits=$((hits+1))
  fi
done
if [ "$hits" -gt 0 ]; then
  echo "FAIL: Bash 3.2 incompatible constructs found in migration scripts"
  exit 1
fi
echo "PASS: all modified migration scripts are Bash 3.2 compatible"
```

### Script 7: `m003-p07-cli-contract.sh`

```bash
#!/usr/bin/env bash
set -eu
f="scripts/migrate/migrate.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
# --help should exit 0
if ! bash "$f" --help >/dev/null 2>&1; then
  echo "FAIL: migrate.sh --help did not exit 0"
  exit 1
fi
# Without --path, should exit non-zero (usage error)
if bash "$f" >/dev/null 2>&1; then
  echo "FAIL: migrate.sh without --path should exit non-zero"
  exit 1
fi
# Help text must still list the documented flags
help_out="$(bash "$f" --help 2>&1)"
for flag in --path --source --recent-count --output --merge --force --abort; do
  case "$help_out" in
    *"$flag"*) ;;
    *) echo "FAIL: --help missing documented flag $flag"; exit 1 ;;
  esac
done
echo "PASS: migrate.sh CLI contract intact (--help works, --path required, all flags listed)"
```

### Step 8: chmod +x and run all seven

```
chmod +x scripts/verify/m003-p07-*.sh
for f in scripts/verify/m003-p07-*.sh; do
  echo "=== $f ==="
  bash "$f" || { echo "VERIFY FAILED: $f"; exit 1; }
done
echo "ALL P07 VERIFY SCRIPTS PASS"
```

If any script fails, the failure is in the corresponding T01–T04 task, not in T05 — fix the upstream task, do not loosen the verify check.

## Must-Haves

This task addresses ALL phase truths by wiring their `Check:` commands to real, passing scripts:

- migrate sources resolver — Script 1
- no hardcoded state paths — Script 2
- rebuild-index wired — Script 3
- idempotency dual-root — Script 4
- migrate.md documents ADs — Script 5
- Bash 3.2 compat — Script 6
- CLI contract intact — Script 7

## Verification

After all seven scripts exist and are executable:

```
bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M003/phases/P07
```

Expected: every truth Check returns PASS. Any FAIL points to the upstream task that left the corresponding artifact in the wrong state.

## Inputs

### From Previous Tasks

- All T01–T04 outputs. The verify scripts intentionally do NOT read those tasks' files except via `grep`.

### From Disk (Pre-existing)

- `scripts/verify/check-must-haves.sh` — the orchestrator's standard Tier 1 driver. Reads `P07-PLAN.md`'s Must-Haves section and runs each truth Check command.
- Existing examples to mirror style (do not modify): `scripts/verify/m002-p02-bash32-compat.sh`, `scripts/verify/m002-p05-record-telemetry-fields.sh`.

## Constraints

- **AD-19 single-script-file shape**: each verify script is one file invoked as `bash <path>`. No process substitution, no `( ... )` subshells, no `$(...)` containing pipes, no inline `for`/`while`/`if` chains in the Truth `Check:` line itself (the Check line is just `bash scripts/verify/m003-p07-<name>.sh`).
- **Bash 3.2 compatibility** in the verify scripts themselves (MEM001) — same constraints they enforce.
- **Tier 1 only** — these are static grep-based checks. Behavioral verification (does migration actually work end-to-end?) is P08's job.
- **No false negatives on legitimate refactors**: use broad regex alternation (e.g. accept either `MIGRATE_TARGET_ROOT` or `target_root` in Script 3) when matching by name, per the plan-phase command's guidance on Tier 1 fragility.
- **No `find`-with-pipes**: scripts use `for f in ...` glob loops or simple `grep` invocations only.
- **chmod +x** every new script; verify scripts must be executable per existing `scripts/verify/` convention.

## Expected Output

After this task, `scripts/verify/m003-p07-*.sh` contains exactly seven scripts, all executable, all passing when T01–T04 are correctly landed. `bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M003/phases/P07` reports PASS for every truth.
