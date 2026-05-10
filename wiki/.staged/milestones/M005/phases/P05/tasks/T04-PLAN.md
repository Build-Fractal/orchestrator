---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P05"
milestone: "M005"
name: "Create check-providers.sh and wire into run-doctor.sh"
depends_on: ["T03"]
---

## Description

Create two deliverables:

1. **`scripts/diagnostics/check-providers.sh`** — a diagnostic script
   that validates execution provider scripts against the convention
   documented in `references/provider-convention.md`. It scans scripts
   under `scripts/providers/` (the conventional location for provider
   scripts) and checks each for required structural elements:
   - Bash shebang (`#!/usr/bin/env bash` or `#!/bin/bash`)
   - Error mode (`set -eu` or `set -euo pipefail`)
   - Required argument parsing (`--task`, `--phase`, `--output`)
   - `emit_result` call (required for structured completion)
   - Library sourcing (`errors.sh`, `events.sh`)

   The check emits structured output following the `DOCTOR:` pattern:
   `DOCTOR:PROVIDERS status=<ok|warn|skip> files=N issues=N`

   When no provider scripts exist under `scripts/providers/`, the check
   emits `status=skip` with a reason — this is normal during development
   before any providers are written. The convention exists (from T03) to
   guide future provider authors; the check validates conformance when
   providers appear.

2. **Updated `scripts/diagnostics/run-doctor.sh`** — adds a `run_check`
   call for "Provider Conformance" that invokes `check-providers.sh`,
   following the same pattern as the existing checks.

### Check Design

The check is intentionally lenient: it performs static grep-based analysis
(like check-instructions.sh), not runtime execution. It validates structure,
not behavior. Warnings are informational — they help provider authors catch
common omissions, not block development.

The check looks for patterns, not exact code. For example, `--task` parsing
is detected by grepping for `--task)` or `--task ` in the script, not by
executing the script with test arguments.

## Steps

### Step 1 — Create `scripts/diagnostics/check-providers.sh`

```bash
#!/usr/bin/env bash
# scripts/diagnostics/check-providers.sh — Provider convention conformance check.
#
# Scans provider scripts (scripts/providers/*.sh by default) for required
# structural elements defined in references/provider-convention.md.
#
# Usage: check-providers.sh [--root <project-root>]
#
# Output: DOCTOR:PROVIDERS status=<ok|warn|skip> files=N issues=N
#
# Bash 3.2 compatible. AD-6 conformance.
set -eu

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"

while [ $# -gt 0 ]; do
  case "$1" in
    --root) PROJECT_ROOT="$2"; shift 2 ;;
    *) echo "check-providers.sh: unknown option: $1" >&2; exit 1 ;;
  esac
done

PROVIDERS_DIR="$PROJECT_ROOT/scripts/providers"

# --- No providers directory or no provider scripts: skip ---
if [ ! -d "$PROVIDERS_DIR" ]; then
  printf 'DOCTOR:PROVIDERS status=skip files=0 issues=0 reason=no_providers_dir\n'
  exit 0
fi

FILES=""
for f in "$PROVIDERS_DIR"/*.sh; do
  [ -f "$f" ] || continue
  FILES="${FILES}${f}
"
done

if [ -z "$FILES" ]; then
  printf 'DOCTOR:PROVIDERS status=skip files=0 issues=0 reason=no_provider_scripts\n'
  exit 0
fi

total_files=0
total_issues=0
details=""

# --- Required checks per provider script ---
# Each check greps for a pattern; absence is an issue.
while IFS= read -r file; do
  [ -z "$file" ] && continue
  total_files=$((total_files + 1))
  file_issues=0
  bname="$(basename "$file")"

  # 1. Bash shebang
  head_line="$(head -1 "$file")"
  case "$head_line" in
    '#!/usr/bin/env bash'|'#!/bin/bash') ;;
    *)
      file_issues=$((file_issues + 1))
      details="${details}  ISSUE: ${bname} — missing bash shebang
"
      ;;
  esac

  # 2. Error mode (set -eu or set -euo pipefail)
  if ! grep -qE '^set -e' "$file"; then
    file_issues=$((file_issues + 1))
    details="${details}  ISSUE: ${bname} — missing set -e error mode
"
  fi

  # 3. --task argument parsing
  if ! grep -q '\-\-task' "$file"; then
    file_issues=$((file_issues + 1))
    details="${details}  ISSUE: ${bname} — missing --task argument handling
"
  fi

  # 4. --phase argument parsing
  if ! grep -q '\-\-phase' "$file"; then
    file_issues=$((file_issues + 1))
    details="${details}  ISSUE: ${bname} — missing --phase argument handling
"
  fi

  # 5. --output argument parsing
  if ! grep -q '\-\-output' "$file"; then
    file_issues=$((file_issues + 1))
    details="${details}  ISSUE: ${bname} — missing --output argument handling
"
  fi

  # 6. emit_result call
  if ! grep -q 'emit_result' "$file"; then
    file_issues=$((file_issues + 1))
    details="${details}  ISSUE: ${bname} — missing emit_result call
"
  fi

  # 7. errors.sh sourcing
  if ! grep -q 'errors\.sh' "$file"; then
    file_issues=$((file_issues + 1))
    details="${details}  ISSUE: ${bname} — does not source errors.sh
"
  fi

  # 8. events.sh sourcing
  if ! grep -q 'events\.sh' "$file"; then
    file_issues=$((file_issues + 1))
    details="${details}  ISSUE: ${bname} — does not source events.sh
"
  fi

  total_issues=$((total_issues + file_issues))
done <<FILES_EOF
$FILES
FILES_EOF

# --- Emit structured result ---
if [ "$total_issues" -eq 0 ]; then
  status="ok"
else
  status="warn"
fi

printf 'DOCTOR:PROVIDERS status=%s files=%d issues=%d\n' "$status" "$total_files" "$total_issues"
if [ -n "$details" ]; then
  printf '%s' "$details"
fi
```

Make executable:

```bash
chmod +x scripts/diagnostics/check-providers.sh
```

### Step 2 — Wire check-providers.sh into run-doctor.sh

Add a `run_check` call to `scripts/diagnostics/run-doctor.sh` after the
existing "Instruction Conformance" check and before the Summary section:

```bash
run_check "Provider Conformance" "$SCRIPT_DIR/check-providers.sh" --root "$PROJECT_ROOT"
```

This follows the same pattern as the five existing checks. The
`--root "$PROJECT_ROOT"` argument tells `check-providers.sh` where to
find the `scripts/providers/` directory.

### Step 3 — Verify the integration

Run run-doctor.sh and confirm the new check appears:

```bash
bash scripts/diagnostics/run-doctor.sh --root .
```

Expected output should include a section:

```
--- Provider Conformance ---
DOCTOR:PROVIDERS status=skip files=0 issues=0 reason=no_providers_dir
```

The `status=skip` is expected because no `scripts/providers/` directory
exists yet. The check gracefully handles this case.

## Must-Haves

From phase plan, this task addresses:

- **Truths**: "Provider conformance check script exists at
  `scripts/diagnostics/check-providers.sh` and validates provider scripts
  against the convention" and "`scripts/diagnostics/run-doctor.sh` includes
  a `run_check` call for Provider Conformance that invokes check-providers.sh."
- **Artifacts**: `scripts/diagnostics/check-providers.sh` (create, min 40
  lines, contains "DOCTOR:PROVIDERS"), `scripts/diagnostics/run-doctor.sh`
  (modify, contains "check-providers.sh").

## Verification

Run the verification scripts:

```bash
bash scripts/verify/p05-check-providers.sh
bash scripts/verify/p05-doctor-integration.sh
```

Both should print PASS.

Smoke test check-providers.sh directly:

```bash
bash scripts/diagnostics/check-providers.sh --root .
```

Should output `DOCTOR:PROVIDERS status=skip files=0 issues=0 reason=no_providers_dir`
(since no providers directory exists yet).

### Files Touched By This Task

- `scripts/diagnostics/check-providers.sh` (create)
- `scripts/diagnostics/run-doctor.sh` (modify)

## Inputs

### From Previous Tasks

- T03: `references/provider-convention.md` must exist. Defines the
  convention that `check-providers.sh` validates against. The check
  script enforces the structural requirements documented there (shebang,
  argument parsing, emit_result, library sourcing).

### From Disk (Pre-existing)

- `scripts/diagnostics/run-doctor.sh` — the existing doctor script.
  Current structure after P04's T02 modification:
  - Lines 58-62: six `run_check` calls (orphaned, stale, scope, cost,
    instructions)
  - The new `run_check` call goes after the "Instruction Conformance"
    line and before the `# Summary` comment.

- `scripts/diagnostics/check-instructions.sh` — reference for the
  `DOCTOR:` structured output pattern and the `--root` argument
  convention. The `check-providers.sh` script follows the same pattern.

- `scripts/diagnostics/check-permissions.sh` — another reference for
  the diagnostic check pattern. Shows `DOCTOR:PERMISSIONS` structured
  output.

## Expected Output

After completing this task:

1. `scripts/diagnostics/check-providers.sh` exists, is chmod +x, has at
   least 40 lines, scans `scripts/providers/*.sh` for convention
   compliance, and emits `DOCTOR:PROVIDERS status=<ok|warn|skip> files=N issues=N`.
2. When no providers exist, reports `status=skip` (not an error).
3. `scripts/diagnostics/run-doctor.sh` includes a `run_check` call for
   "Provider Conformance" after "Instruction Conformance".
4. `bash scripts/verify/p05-check-providers.sh` prints PASS.
5. `bash scripts/verify/p05-doctor-integration.sh` prints PASS.
6. `bash scripts/diagnostics/run-doctor.sh --root .` includes
   "Provider Conformance" in its output.
7. `git status` shows 1 new file (`check-providers.sh`) and 1 modified
   file (`run-doctor.sh`). Nothing else touched.
