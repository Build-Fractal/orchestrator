---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P04"
milestone: "M016"
name: "Create verify scripts for P04 must-haves"
depends_on: ["T01"]
---

## Prerequisites

T01 has promoted safe tool wildcards to `.claude/settings.json`. The settings file now contains entries for `sed *`, `awk *`, `/usr/bin/sed *`, `grep *`, `wc *`, `chmod *`, `mkdir *`, `touch *`, `cat *`, `head *`, `tail *`, `mv *`, `cp *`, `find *`, and other Unix tools.

## Description

Create the verify scripts that mechanically check P04's must-haves: that `settings.json` contains the required tool wildcards, that `/usr/bin/sed *` is present for macOS, and that the dogfood evidence directory contains the attestation file. These scripts are invoked by the phase's Truth Check commands and by `run-suite.sh m016 P04`.

## Steps

### Step 1: Create settings wildcards verify script

Create `scripts/verify/m016-p04-settings-wildcards.sh`:

```bash
#!/usr/bin/env bash
# scripts/verify/m016-p04-settings-wildcards.sh
# Verify that .claude/settings.json contains wildcard entries for common
# Unix tools needed during autonomous execution.
# Bash 3.2 compatible.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SETTINGS="$PROJECT_ROOT/.claude/settings.json"

if [ ! -f "$SETTINGS" ]; then
  echo "FAIL: settings.json not found at $SETTINGS"
  exit 1
fi

missing=""
for tool in "sed" "awk" "grep" "wc" "chmod" "mkdir" "touch" "cat" "head" "tail" "mv" "cp" "find"; do
  pattern="\"Bash($tool *)\""
  if ! grep -qF "Bash($tool *)" "$SETTINGS"; then
    missing="$missing $tool"
  fi
done

if [ -n "$missing" ]; then
  echo "FAIL: settings.json missing wildcards for:$missing"
  exit 1
fi

echo "PASS: settings.json contains all required Unix tool wildcards"
exit 0
```

### Step 2: Create /usr/bin/sed verify script

Create `scripts/verify/m016-p04-settings-usrbin-sed.sh`:

```bash
#!/usr/bin/env bash
# scripts/verify/m016-p04-settings-usrbin-sed.sh
# Verify that .claude/settings.json contains /usr/bin/sed wildcard
# for macOS path resolution.
# Bash 3.2 compatible.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SETTINGS="$PROJECT_ROOT/.claude/settings.json"

if grep -qF 'Bash(/usr/bin/sed *)' "$SETTINGS"; then
  echo "PASS: settings.json contains /usr/bin/sed wildcard"
  exit 0
fi

echo "FAIL: settings.json missing /usr/bin/sed wildcard"
exit 1
```

### Step 3: Create evidence-exists verify script

Create `scripts/verify/m016-p04-evidence-exists.sh`:

```bash
#!/usr/bin/env bash
# scripts/verify/m016-p04-evidence-exists.sh
# Verify that the dogfood evidence directory contains the zero-prompts
# attestation file with the expected structure.
# Bash 3.2 compatible.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
EVIDENCE_DIR="$PROJECT_ROOT/.orchestrator/milestones/M016/phases/P04/evidence"
ATTEST="$EVIDENCE_DIR/zero-prompts-attestation.md"

fail_count=0
pass_count=0

pass() { echo "  PASS: $1"; pass_count=$((pass_count + 1)); }
fail() { echo "  FAIL: $1"; fail_count=$((fail_count + 1)); }

# Check evidence directory exists
if [ -d "$EVIDENCE_DIR" ]; then
  pass "evidence directory exists"
else
  fail "evidence directory not found at $EVIDENCE_DIR"
fi

# Check attestation file exists
if [ -f "$ATTEST" ]; then
  pass "attestation file exists"
else
  fail "attestation file not found"
fi

# Check attestation contains prompt_count: 0
if [ -f "$ATTEST" ] && grep -q 'prompt_count: 0' "$ATTEST"; then
  pass "attestation contains prompt_count: 0"
else
  fail "attestation missing prompt_count: 0"
fi

# Check attestation contains phase execution table
if [ -f "$ATTEST" ] && grep -q '| P01' "$ATTEST"; then
  pass "attestation contains phase execution evidence"
else
  fail "attestation missing phase execution evidence"
fi

# Summary
echo ""
total=$((pass_count + fail_count))
if [ "$fail_count" -eq 0 ]; then
  echo "PASS: dogfood evidence complete ($pass_count/$total checks)"
  exit 0
else
  echo "FAIL: dogfood evidence incomplete ($fail_count failures out of $total checks)"
  exit 1
fi
```

### Step 4: Run all verify scripts

Run each script individually to confirm they pass:

```
bash scripts/verify/m016-p04-settings-wildcards.sh
bash scripts/verify/m016-p04-settings-usrbin-sed.sh
bash scripts/verify/m016-p04-evidence-exists.sh
```

All must print `PASS:` and exit 0. Note: `m016-p04-evidence-exists.sh` depends on T02 having created the attestation file. If T02 has not run yet, this script will fail -- that is expected and correct.

### Step 5: Run the full P04 suite via run-suite.sh

After T02 is also complete, validate the full suite:

```
bash scripts/verify/run-suite.sh m016 P04
```

Expected: all scripts pass, exit 0.

## Must-Haves

- `.claude/settings.json` allow list contains wildcard entries for `sed`, `awk`, `grep`, `wc`, `chmod`, `mkdir`, `touch`, `cat`, `head`, `tail`, `mv`, `cp`, and `find`
- `.claude/settings.json` allow list contains `/usr/bin/sed *` entry for macOS path resolution
- Dogfood evidence directory contains a zero-prompts attestation file

## Verification

```
bash scripts/verify/m016-p04-settings-wildcards.sh
bash scripts/verify/m016-p04-settings-usrbin-sed.sh
bash scripts/verify/m016-p04-evidence-exists.sh
```

Each must print `PASS:` and exit 0.

## Inputs

### From Previous Tasks

- `.claude/settings.json` (from T01) -- project-level settings with promoted tool wildcards. The allow list contains entries matching the pattern `"Bash(<tool> *)"` for each Unix tool. Check with: `grep -F 'Bash(sed *)' .claude/settings.json`.
- `.orchestrator/milestones/M016/phases/P04/evidence/zero-prompts-attestation.md` (from T02) -- attestation file with YAML frontmatter containing `prompt_count: 0` and a markdown body with phase execution table. Only needed for the `m016-p04-evidence-exists.sh` script.

### From Disk (Pre-existing)

- `scripts/verify/run-suite.sh` -- from P02. API: `bash scripts/verify/run-suite.sh <milestone> <phase>`. Auto-discovers `scripts/verify/<milestone>-<phase>-*.sh` scripts and runs them. Prints per-script PASS/FAIL and summary tally.

## Constraints

- All scripts must be Bash 3.2 compatible (no `declare -A`, `mapfile`, `${var,,}`).
- All scripts must use single-script-file invocation shape per AD-19.
- Scripts use the project's `pass()`/`fail()` pattern with summary counts (MEM002).
- Scripts must use `SCRIPT_DIR` / `PROJECT_ROOT` resolution pattern (MEM001).

## Expected Output

- `scripts/verify/m016-p04-settings-wildcards.sh` created and passing.
- `scripts/verify/m016-p04-settings-usrbin-sed.sh` created and passing.
- `scripts/verify/m016-p04-evidence-exists.sh` created and passing.
- No other files modified.
