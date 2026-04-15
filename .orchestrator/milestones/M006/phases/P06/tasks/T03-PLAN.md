---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P06"
milestone: "M006"
name: "Verification scripts and final sweep"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01 completed: `CHANGELOG.md` has M002-M006 entries.
- T02 completed: `extension.yml` verified, `check-docs.sh` created,
  `run-doctor.sh` updated, `CLAUDE.md` updated.

## Description

Create all 10 verification scripts referenced in the P06-PLAN.md Truths
section. Each script is a standalone single-file invocation (AD-19
compliant) that checks one specific property. After creating the scripts,
run the full verification suite to confirm all checks pass.

Then run `scripts/diagnostics/run-doctor.sh` as the final sweep to
confirm the entire diagnostics suite passes, including the new
documentation conformance check from T02.

Fix any bugs found during the sweep.

All scripts follow the pattern established in P01-P05:
- Shebang: `#!/usr/bin/env bash`
- `set -eu`
- File existence check with descriptive failure
- Content pattern checks with descriptive failure
- Final `echo "PASS: <description>"` on success

## Steps

### Step 1 — Create CHANGELOG verification scripts

Create five scripts, one per milestone:

**`scripts/verify/m006-p06-changelog-m002.sh`**
Checks that `CHANGELOG.md`:
- Contains a version header for M002 (grep for `## [0.2.0]`)
- Contains "knowledge" (case-insensitive) in the M002 section
- Contains "### Added" under the M002 section

**`scripts/verify/m006-p06-changelog-m003.sh`**
Checks that `CHANGELOG.md`:
- Contains a version header for M003 (grep for `## [0.3.0]`)
- Contains "migrat" (case-insensitive, matches migration/migrate)
- Contains "### Added" under the M003 section

**`scripts/verify/m006-p06-changelog-m004.sh`**
Checks that `CHANGELOG.md`:
- Contains a version header for M004 (grep for `## [0.4.0]`)
- Contains "engine" (case-insensitive) in the M004 section
- Contains "### Added" under the M004 section

**`scripts/verify/m006-p06-changelog-m005.sh`**
Checks that `CHANGELOG.md`:
- Contains a version header for M005 (grep for `## [0.5.0]`)
- Contains "harden" or "diagnostic" or "hash" (case-insensitive)
- Contains "### Added" under the M005 section

**`scripts/verify/m006-p06-changelog-m006.sh`**
Checks that `CHANGELOG.md`:
- Contains a version header for M006 (grep for `## [0.6.0]`)
- Contains "documentation" or "reference" or "architecture.md" (case-insensitive)
- Contains "### Added" under the M006 section

Each script:
```bash
#!/usr/bin/env bash
# Verify CHANGELOG.md contains M00X entry.
set -eu
f="CHANGELOG.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q '## \[0.X.0\]' "$f" || { echo "FAIL: missing M00X version header"; exit 1; }
grep -qi 'keyword' "$f" || { echo "FAIL: missing M00X content keyword"; exit 1; }
echo "PASS: CHANGELOG.md contains M00X entry"
```

### Step 2 — Create extension.yml verification scripts

**`scripts/verify/m006-p06-extyml-commands.sh`**
Extracts every `file:` entry from the `provides.commands` section of
`extension.yml` and verifies each file exists on disk. Uses grep/sed
to parse YAML (no jq dependency).

Pattern:
```bash
#!/usr/bin/env bash
# Verify every command file in extension.yml exists.
set -eu
f="extension.yml"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
missing=0
# Extract command file entries (lines after "commands:" containing "file:")
# within the provides.commands block
while IFS= read -r line; do
  filepath="$(echo "$line" | sed 's/.*file: *//' | sed 's/ *$//')"
  if [ ! -f "$filepath" ]; then
    echo "FAIL: command file missing: $filepath"
    missing=$((missing + 1))
  fi
done <<EOF
$(sed -n '/^  commands:/,/^  [a-z]/{ /file:/p }' "$f")
EOF
if [ "$missing" -gt 0 ]; then
  echo "FAIL: $missing command files missing"
  exit 1
fi
echo "PASS: all command files in extension.yml exist"
```

**`scripts/verify/m006-p06-extyml-scripts.sh`**
Extracts every `file:` entry from the `provides.scripts` section and
verifies each file exists on disk and is executable.

Pattern similar to commands check but for the scripts section. Uses
`test -f` and `test -x` for each entry.

### Step 3 — Create check-docs.sh verification scripts

**`scripts/verify/m006-p06-check-docs-exists.sh`**
Checks that:
- `scripts/diagnostics/check-docs.sh` exists
- File contains "DOCTOR:" output protocol
- File checks for `references/` files
- File checks for `docs/` files

**`scripts/verify/m006-p06-doctor-docs.sh`**
Checks that `scripts/diagnostics/run-doctor.sh`:
- Contains "check-docs" reference (invokes the new check)
- Contains "Documentation" in a `run_check` line

### Step 4 — Create CLAUDE.md verification script

**`scripts/verify/m006-p06-claude-md-status.sh`**
Checks that `CLAUDE.md`:
- Contains a project status line with command count (e.g., "12 commands")
- Contains reference to `docs/` directory in key files
- Contains reference to current milestone activity in recent changes

### Step 5 — Run the full P06 verification suite

Execute all 10 scripts and confirm each exits 0. If any fail,
investigate whether the issue is in the verification script or in
the target artifact, and fix accordingly.

### Step 6 — Run run-doctor.sh as final sweep

Execute `bash scripts/diagnostics/run-doctor.sh` and review the output.
All checks should pass, including:
- Existing checks (orphaned, stale, scope, cost, instructions, providers,
  permissions, constitution, events, hashes, run IDs, recipes, plans)
- New check: Documentation Coverage

If any checks fail:
- Investigate the root cause.
- Fix the issue (whether in a diagnostic script, a documentation file,
  or the codebase).
- Commit fixes with DC-5 references.
- Re-run until all checks pass.

### Step 7 — Final file existence sweep

As a final verification, confirm that every file referenced in
extension.yml, CHANGELOG.md, and CLAUDE.md actually exists on disk.
Any broken references are fixed.

## Must-Haves

- [ ] All 10 verification scripts exist and follow AD-19 single-script-file shape
- [ ] Each script prints "PASS:" on success, "FAIL:" on failure
- [ ] All 10 scripts pass when run against P06 artifacts
- [ ] `run-doctor.sh` passes all checks (including new doc conformance)
- [ ] No broken file references in CHANGELOG.md, extension.yml, or CLAUDE.md
- [ ] Any bugs found during sweep are fixed and committed with DC-5 references

## Verification

Run all scripts in sequence:

```
bash scripts/verify/m006-p06-changelog-m002.sh
bash scripts/verify/m006-p06-changelog-m003.sh
bash scripts/verify/m006-p06-changelog-m004.sh
bash scripts/verify/m006-p06-changelog-m005.sh
bash scripts/verify/m006-p06-changelog-m006.sh
bash scripts/verify/m006-p06-extyml-commands.sh
bash scripts/verify/m006-p06-extyml-scripts.sh
bash scripts/verify/m006-p06-check-docs-exists.sh
bash scripts/verify/m006-p06-doctor-docs.sh
bash scripts/verify/m006-p06-claude-md-status.sh
```

All must exit 0.

Then run the full doctor:

```
bash scripts/diagnostics/run-doctor.sh
```

Must report `Status: HEALTHY`.

## Inputs

### From Previous Tasks

- T01: `CHANGELOG.md` — validation target (M002-M006 entries)
- T02: `extension.yml` — validation target (verified inventory)
- T02: `scripts/diagnostics/check-docs.sh` — validation target (new diagnostic)
- T02: `scripts/diagnostics/run-doctor.sh` — validation target (updated runner)
- T02: `CLAUDE.md` — validation target (updated status)

### From Disk (Pre-existing)

- `scripts/verify/m006-p01-arch-header.sh` — pattern reference for script format
- `scripts/verify/m006-p05-crosslinks.sh` — pattern reference for cross-link checks
- All M006 P01-P05 verification scripts — examples of the established pattern

## Constraints

- **AD-19**: Each verification check is a single script file invocation.
  No inline compound bash (for-loops, if-chains) in Truth check commands.
- **DC-4**: Verify-as-you-write — run each script after creation.
- **DC-5**: Bug fix commits reference the check or doc that surfaced them.
- **DC-6**: Scripts must be Bash 3.2 compatible.
- Each script must produce clear PASS/FAIL output.

## Expected Output

After completing this task:

1. All 10 verification scripts exist under `scripts/verify/m006-p06-*.sh`.
2. All scripts pass against the P06 artifacts.
3. `run-doctor.sh` reports `Status: HEALTHY` with all checks passing.
4. Any bugs found during the final sweep are fixed and committed.
5. The project is ready for M006 phase completion.
