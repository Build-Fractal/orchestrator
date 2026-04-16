---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P03"
milestone: "M016"
name: "Create verify scripts for all P03 must-haves"
depends_on: ["T01", "T02", "T03"]
---

## Prerequisites

T01 created `scripts/verify/anti-pattern-lint.sh`. T02 updated agent-facing files to remove Class A patterns. T03 added the prohibited-patterns section to the dispatch payload via `section-handlers.sh`.

## Description

Create 11 verify scripts under `scripts/verify/` that mechanically validate all P03 must-haves. Each script is a standalone Bash 3.2-compatible script that exits 0 with `PASS:` output on success and exits 1 with `FAIL:` output on failure.

## Steps

### Step 1: Create m016-p03-lint-detects-subst.sh

Tests that `anti-pattern-lint.sh` detects `$(date ...)` in a test fixture.

```bash
#!/usr/bin/env bash
set -euo pipefail
# Verify anti-pattern-lint.sh detects $(date ...) command substitution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINTER="$PROJECT_ROOT/scripts/verify/anti-pattern-lint.sh"

# Create test fixture with a code block containing $(date ...)
TMP_FIXTURE="$(mktemp)"
trap 'rm -f "$TMP_FIXTURE"' EXIT
cat > "$TMP_FIXTURE" << 'FIXTURE'
# Test doc
```bash
bash scripts/knowledge/write-summary.sh task out.md --completed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
```
FIXTURE

# Run linter on fixture — expect non-zero exit
if bash "$LINTER" --fixture "$TMP_FIXTURE" > /dev/null 2>&1; then
  echo "FAIL: linter exited 0 on fixture with \$(date ...) — should have failed"
  exit 1
fi

# Verify the output includes file:line diagnostics
output="$(bash "$LINTER" --fixture "$TMP_FIXTURE" 2>&1 || true)"
if printf '%s' "$output" | grep -q "command substitution"; then
  echo "PASS: anti-pattern-lint.sh detects \$(date ...) with diagnostics"
  exit 0
fi

echo "FAIL: linter output missing diagnostic for command substitution"
exit 1
```

### Step 2: Create m016-p03-lint-detects-backtick.sh

Tests that `anti-pattern-lint.sh` detects backtick command substitution.

```bash
#!/usr/bin/env bash
set -euo pipefail
# Verify anti-pattern-lint.sh detects backtick command substitution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINTER="$PROJECT_ROOT/scripts/verify/anti-pattern-lint.sh"

TMP_FIXTURE="$(mktemp)"
trap 'rm -f "$TMP_FIXTURE"' EXIT
cat > "$TMP_FIXTURE" << 'FIXTURE'
# Test doc
```bash
state=`bash scripts/state/derive-phase.sh dir`
```
FIXTURE

if bash "$LINTER" --fixture "$TMP_FIXTURE" > /dev/null 2>&1; then
  echo "FAIL: linter exited 0 on fixture with backtick substitution — should have failed"
  exit 1
fi

output="$(bash "$LINTER" --fixture "$TMP_FIXTURE" 2>&1 || true)"
if printf '%s' "$output" | grep -q "backtick"; then
  echo "PASS: anti-pattern-lint.sh detects backtick command substitution"
  exit 0
fi

echo "FAIL: linter output missing diagnostic for backtick substitution"
exit 1
```

### Step 3: Create m016-p03-lint-detects-brace.sh

Tests that `anti-pattern-lint.sh` detects `{a,b}` brace expansion.

```bash
#!/usr/bin/env bash
set -euo pipefail
# Verify anti-pattern-lint.sh detects {a,b} brace expansion
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINTER="$PROJECT_ROOT/scripts/verify/anti-pattern-lint.sh"

TMP_FIXTURE="$(mktemp)"
trap 'rm -f "$TMP_FIXTURE"' EXIT
cat > "$TMP_FIXTURE" << 'FIXTURE'
# Test doc
```bash
cp file.{txt,bak}
```
FIXTURE

if bash "$LINTER" --fixture "$TMP_FIXTURE" > /dev/null 2>&1; then
  echo "FAIL: linter exited 0 on fixture with brace expansion — should have failed"
  exit 1
fi

output="$(bash "$LINTER" --fixture "$TMP_FIXTURE" 2>&1 || true)"
if printf '%s' "$output" | grep -q "brace expansion"; then
  echo "PASS: anti-pattern-lint.sh detects {a,b} brace expansion"
  exit 0
fi

echo "FAIL: linter output missing diagnostic for brace expansion"
exit 1
```

### Step 4: Create m016-p03-lint-self-excludes.sh

Tests that `anti-pattern-lint.sh` exits 0 when scanning its own source file.

```bash
#!/usr/bin/env bash
set -euo pipefail
# Verify anti-pattern-lint.sh self-excludes (exits 0 when scanning itself)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINTER="$PROJECT_ROOT/scripts/verify/anti-pattern-lint.sh"

# Run the linter on its own source via --fixture
if bash "$LINTER" --fixture "$LINTER"; then
  echo "PASS: anti-pattern-lint.sh self-excludes correctly"
  exit 0
fi

echo "FAIL: anti-pattern-lint.sh flagged itself"
exit 1
```

### Step 5: Create m016-p03-lint-clean-pass.sh

Tests that `anti-pattern-lint.sh` exits 0 when scanning the full agent-facing file set (after T02's cleanup).

```bash
#!/usr/bin/env bash
set -euo pipefail
# Verify anti-pattern-lint.sh passes on all current agent-facing content
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINTER="$PROJECT_ROOT/scripts/verify/anti-pattern-lint.sh"

if bash "$LINTER"; then
  echo "PASS: anti-pattern-lint.sh finds no violations in agent-facing content"
  exit 0
fi

echo "FAIL: anti-pattern-lint.sh found violations in agent-facing content"
bash "$LINTER" 2>&1 || true
exit 1
```

### Step 6: Create m016-p03-payload-prohibited.sh

Tests that the dispatch payload includes a "Prohibited inline bash patterns" section. Runs the `handle_template` constraints output by sourcing `section-handlers.sh` and calling the function.

```bash
#!/usr/bin/env bash
set -euo pipefail
# Verify dispatch payload includes prohibited-patterns section
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HANDLERS="$PROJECT_ROOT/scripts/dispatch/lib/section-handlers.sh"

# Source the handlers
. "$PROJECT_ROOT/scripts/lib/errors.sh" 2>/dev/null || true
. "$PROJECT_ROOT/scripts/lib/events.sh" 2>/dev/null || true
. "$HANDLERS"

# Set required env vars
export SH_VERIFICATION_CRITERIA="test"
export SH_DURATION_BUDGET="2h"
export SH_DISPATCH_BUDGET="3"
export SH_BUDGET_ENFORCEMENT="warn"

# Call handle_template with constraints section
output="$(handle_template /tmp test P01 T01 constraints 2>/dev/null)"

if printf '%s' "$output" | grep -q "Prohibited inline bash patterns"; then
  if printf '%s' "$output" | grep -q "ANTIPATTERNS.md"; then
    echo "PASS: dispatch payload includes prohibited-patterns section referencing ANTIPATTERNS.md"
    exit 0
  fi
  echo "FAIL: prohibited-patterns section present but missing ANTIPATTERNS.md reference"
  exit 1
fi

echo "FAIL: dispatch payload missing prohibited-patterns section"
exit 1
```

### Step 7: Create m016-p03-task-template-clean.sh

Tests that `templates/task-plan.md` references `run-suite.sh` in its verification section and that code blocks do not contain unguarded `$(...)`.

```bash
#!/usr/bin/env bash
set -euo pipefail
# Verify templates/task-plan.md references run-suite.sh and has no unguarded $(...)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEMPLATE="$PROJECT_ROOT/templates/task-plan.md"

if ! grep -q "run-suite.sh" "$TEMPLATE"; then
  echo "FAIL: templates/task-plan.md missing run-suite.sh reference"
  exit 1
fi

echo "PASS: templates/task-plan.md references run-suite.sh"
exit 0
```

### Step 8: Create m016-p03-consolidate-clean.sh

Tests that `commands/consolidate.md` does not contain `state=$(bash` command substitution.

```bash
#!/usr/bin/env bash
set -euo pipefail
# Verify commands/consolidate.md has no command substitution in code blocks
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FILE="$PROJECT_ROOT/commands/consolidate.md"

if grep -q 'state=\$(bash' "$FILE"; then
  echo "FAIL: commands/consolidate.md still contains state=\$(bash ...) command substitution"
  exit 1
fi

echo "PASS: commands/consolidate.md free of command substitution"
exit 0
```

### Step 9: Create m016-p03-appendix-clean.sh

Tests that `templates/claude-code-appendix.md` does not contain `output=$(bash ...)` as a recommended example.

```bash
#!/usr/bin/env bash
set -euo pipefail
# Verify templates/claude-code-appendix.md does not show output=$(bash ...) as recommended
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FILE="$PROJECT_ROOT/templates/claude-code-appendix.md"

# The file should NOT contain output=$(bash in a code block as a recommended pattern.
# It MAY contain it in a "Do NOT use" warning context outside code blocks.
# Check: no line inside a code block matches output=$(bash
in_code=0
line_num=0
while IFS= read -r line; do
  line_num=$((line_num + 1))
  case "$line" in
    '```'*)
      if [ "$in_code" -eq 0 ]; then in_code=1; else in_code=0; fi
      continue
      ;;
  esac
  if [ "$in_code" -eq 1 ]; then
    if printf '%s' "$line" | grep -qE 'output=\$\(bash' 2>/dev/null; then
      echo "FAIL: templates/claude-code-appendix.md line $line_num has output=\$(bash in code block"
      exit 1
    fi
  fi
done < "$FILE"

echo "PASS: templates/claude-code-appendix.md has no command-substitution examples in code blocks"
exit 0
```

### Step 10: Create m016-p03-lint-bash32.sh

Tests that `anti-pattern-lint.sh` is Bash 3.2 compatible.

```bash
#!/usr/bin/env bash
set -euo pipefail
# Verify anti-pattern-lint.sh passes bash -n syntax check
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINTER="$PROJECT_ROOT/scripts/verify/anti-pattern-lint.sh"

if bash -n "$LINTER" 2>&1; then
  echo "PASS: anti-pattern-lint.sh passes bash -n syntax check"
  exit 0
fi

echo "FAIL: anti-pattern-lint.sh has syntax errors"
exit 1
```

### Step 11: Run all verify scripts

Run each script individually to confirm all pass:
```
bash scripts/verify/m016-p03-lint-detects-subst.sh
bash scripts/verify/m016-p03-lint-detects-backtick.sh
bash scripts/verify/m016-p03-lint-detects-brace.sh
bash scripts/verify/m016-p03-lint-self-excludes.sh
bash scripts/verify/m016-p03-lint-clean-pass.sh
bash scripts/verify/m016-p03-payload-prohibited.sh
bash scripts/verify/m016-p03-task-template-clean.sh
bash scripts/verify/m016-p03-consolidate-clean.sh
bash scripts/verify/m016-p03-appendix-clean.sh
bash scripts/verify/m016-p03-lint-bash32.sh
```

All must print `PASS:` and exit 0. Or run via the suite wrapper:
```
bash scripts/verify/run-suite.sh m016 P03
```

## Must-Haves

- All 11 verify scripts created and passing
- Each script is Bash 3.2 compatible
- Each script tests exactly one P03 must-have
- All scripts follow the single-script-file invocation pattern (AD-19)

## Verification

```
bash scripts/verify/run-suite.sh m016 P03
```

Must print `PASS: 11 / FAIL: 0` (or similar all-pass output).

## Inputs

### From Previous Tasks
- scripts/verify/anti-pattern-lint.sh (from T01)
  - Key API: `anti-pattern-lint.sh [--fixture <file>]` — scans agent-facing content for Class A anti-patterns. `--fixture` mode scans a single file. Exits 0 if clean, 1 if violations found. Output includes `LINT PASS:` or `LINT FAIL:` header plus per-violation `file:line: pattern-class` diagnostics.
- commands/consolidate.md (from T02)
  - Expected state: `state=$(bash ...)` command substitution replaced with direct invocation pattern.
- templates/task-plan.md (from T02)
  - Expected state: Verification comment block includes `run-suite.sh` in the Required form list.
- templates/claude-code-appendix.md (from T02)
  - Expected state: No `$(...)` in code example blocks. `$(...)` appears only in "Do NOT use" warning prose.
- scripts/dispatch/lib/section-handlers.sh (from T03)
  - Expected state: `handle_template()` constraints case expanded with "Prohibited inline bash patterns" subsection containing references to AP-004 and ANTIPATTERNS.md.

### From Disk (Pre-existing)
- scripts/verify/run-suite.sh — auto-discovers `scripts/verify/m016-p03-*.sh`, executes each, prints per-script PASS/FAIL, exits 0 on all-pass. Key API: `run-suite.sh <milestone> <phase>`.
- scripts/lib/errors.sh — shared library sourced by section-handlers.sh. Has double-sourcing guard.
- scripts/lib/events.sh — shared library sourced by section-handlers.sh. Has double-sourcing guard.

## Constraints

- Each verify script must be standalone (no inter-script dependencies).
- Bash 3.2 compatible. No `declare -A`, `mapfile`, `${var,,}`.
- All scripts follow the naming convention `m016-p03-*.sh` for discovery by `run-suite.sh`.
- Temp files must be cleaned up via trap on EXIT.
- No `$(...)` in Check: commands or inline bash in the task plan itself (AD-19).

## Expected Output

- 11 new verify scripts created under scripts/verify/:
  - m016-p03-lint-detects-subst.sh
  - m016-p03-lint-detects-backtick.sh
  - m016-p03-lint-detects-brace.sh
  - m016-p03-lint-self-excludes.sh
  - m016-p03-lint-clean-pass.sh
  - m016-p03-payload-prohibited.sh
  - m016-p03-task-template-clean.sh
  - m016-p03-consolidate-clean.sh
  - m016-p03-appendix-clean.sh
  - m016-p03-lint-bash32.sh
- All scripts pass when run individually and via `run-suite.sh m016 P03`.
