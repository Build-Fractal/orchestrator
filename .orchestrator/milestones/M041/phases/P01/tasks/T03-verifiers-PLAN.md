---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P01"
milestone: "M041"
name: "Verifier scripts + integration smoke test"
depends_on: ["T01", "T02"]
---

## Prerequisites

- `scripts/diagnostics/triage-issue.sh` exists (created by T01)
- `commands/detective.md` exists (created by T02)
- `tools/verify/` directory exists (standard project-owned verifier location)

## Description

Author all P01 verifier scripts under `tools/verify/` with milestone-prefixed filenames (`m041-p01-*`), plus a phase-suite aggregator. Each verifier exercises one must-have truth from the P01 plan. After authoring, run the phase suite to confirm all must-haves pass.

## Steps

1. **Create `tools/verify/m041-p01-triage-report-sections.sh`**:

   ```bash
   #!/usr/bin/env bash
   # Verify triage-issue.sh produces all 6 required body sections
   set -euo pipefail
   output="$(bash scripts/diagnostics/triage-issue.sh --symptom "test symptom for verification" --capture-log 2>/dev/null)"
   missing=""
   for section in "## Symptom" "## Environment" "## Recent Execution Log" "## Relevant Files" "## Disk State" "## Suggested Fix"; do
       if ! echo "$output" | grep -qF "$section"; then
           missing="${missing}  missing: ${section}\n"
       fi
   done
   if [ -n "$missing" ]; then
       printf "FAIL: triage report missing sections:\n%b" "$missing"
       exit 1
   fi
   echo "PASS: all 6 sections present in triage report output"
   ```

2. **Create `tools/verify/m041-p01-suggest-fix-unconditional.sh`**:

   ```bash
   #!/usr/bin/env bash
   # Verify ## Suggested Fix is present WITHOUT --suggest-fix flag
   set -euo pipefail
   output="$(bash scripts/diagnostics/triage-issue.sh --symptom "test symptom" 2>/dev/null)"
   if ! echo "$output" | grep -qF "## Suggested Fix"; then
       echo "FAIL: ## Suggested Fix section missing when --suggest-fix not passed"
       exit 1
   fi
   if ! echo "$output" | grep -qF "No simple fix identified"; then
       echo "FAIL: default text missing in ## Suggested Fix section"
       exit 1
   fi
   echo "PASS: ## Suggested Fix unconditionally present with default text"
   ```

3. **Create `tools/verify/m041-p01-suggest-fix-heuristic.sh`**:

   ```bash
   #!/usr/bin/env bash
   # Verify --suggest-fix populates section when symptom references a non-existent file
   set -euo pipefail
   output="$(bash scripts/diagnostics/triage-issue.sh --symptom "scripts/diagnostics/nonexistent-file-for-test.sh not found" --suggest-fix 2>/dev/null)"
   if ! echo "$output" | grep -qF "## Suggested Fix"; then
       echo "FAIL: ## Suggested Fix section missing with --suggest-fix"
       exit 1
   fi
   # When --suggest-fix is passed with a missing-file symptom, the section should NOT contain the default text
   if echo "$output" | grep -qF "No simple fix identified — run with --suggest-fix"; then
       echo "FAIL: --suggest-fix did not activate heuristic (still shows default text)"
       exit 1
   fi
   echo "PASS: --suggest-fix heuristic activated for missing-file symptom"
   ```

4. **Create `tools/verify/m041-p01-pipe-input.sh`**:

   ```bash
   #!/usr/bin/env bash
   # Verify piped stdin is read as the symptom (FR-10)
   set -euo pipefail
   output="$(echo "piped test symptom for verification" | bash scripts/diagnostics/triage-issue.sh 2>/dev/null)"
   if ! echo "$output" | grep -qF "piped test symptom for verification"; then
       echo "FAIL: piped stdin not read as symptom"
       exit 1
   fi
   if ! echo "$output" | grep -qF "## Symptom"; then
       echo "FAIL: triage report not generated from piped input"
       exit 1
   fi
   echo "PASS: piped stdin read as symptom"
   ```

5. **Create `tools/verify/m041-p01-command-shape.sh`**:

   ```bash
   #!/usr/bin/env bash
   # Verify commands/detective.md exists, passes shape lint, and references triage-issue.sh
   set -euo pipefail
   if [ ! -f commands/detective.md ]; then
       echo "FAIL: commands/detective.md does not exist"
       exit 1
   fi
   # Check frontmatter description field
   if ! grep -q '^description:' commands/detective.md; then
       echo "FAIL: commands/detective.md missing frontmatter description field"
       exit 1
   fi
   # Check reference to triage-issue.sh
   if ! grep -q 'triage-issue\.sh' commands/detective.md; then
       echo "FAIL: commands/detective.md does not reference triage-issue.sh"
       exit 1
   fi
   echo "PASS: commands/detective.md passes shape lint and references triage-issue.sh"
   ```

6. **Create `tools/verify/m041-p01-report-frontmatter.sh`**:

   ```bash
   #!/usr/bin/env bash
   # Verify triage report YAML frontmatter includes required fields
   set -euo pipefail
   output="$(bash scripts/diagnostics/triage-issue.sh --symptom "frontmatter test" 2>/dev/null)"
   missing=""
   for field in "symptom:" "captured_at:" "orchestrator_version:"; do
       if ! echo "$output" | grep -q "^${field}"; then
           missing="${missing}  missing: ${field}\n"
       fi
   done
   if [ -n "$missing" ]; then
       printf "FAIL: triage report frontmatter missing fields:\n%b" "$missing"
       exit 1
   fi
   echo "PASS: triage report frontmatter contains all required fields"
   ```

7. **Create `tools/verify/m041-p01-phase-suite.sh`** (aggregator):

   ```bash
   #!/usr/bin/env bash
   # P01 phase suite aggregator — runs all m041-p01 verifiers
   set -euo pipefail
   cd "$(git rev-parse --show-toplevel)"
   pass=0
   fail=0
   for v in tools/verify/m041-p01-*.sh; do
       [ "$v" = "tools/verify/m041-p01-phase-suite.sh" ] && continue
       name="$(basename "$v" .sh)"
       if bash "$v" >/dev/null 2>&1; then
           echo "PASS: $name"
           pass=$((pass + 1))
       else
           echo "FAIL: $name"
           fail=$((fail + 1))
       fi
   done
   echo "---"
   echo "SUITE: pass=$pass fail=$fail"
   if [ "$fail" -gt 0 ]; then
       exit 1
   fi
   ```

8. **Run the phase suite** to confirm all must-haves pass:
   ```bash
   bash tools/verify/m041-p01-phase-suite.sh
   ```

## Must-Haves

- All 6 individual verifier scripts exist under `tools/verify/m041-p01-*.sh`
- Phase suite aggregator `tools/verify/m041-p01-phase-suite.sh` exists
- Phase suite exits 0 with `pass=6 fail=0`

## Verification

```bash
bash tools/verify/m041-p01-phase-suite.sh
```

## Notes

Expected output from the phase suite:
```
PASS: m041-p01-command-shape
PASS: m041-p01-pipe-input
PASS: m041-p01-report-frontmatter
PASS: m041-p01-suggest-fix-heuristic
PASS: m041-p01-suggest-fix-unconditional
PASS: m041-p01-triage-report-sections
---
SUITE: pass=6 fail=0
```

## Inputs

### From Previous Tasks

- `scripts/diagnostics/triage-issue.sh` (from T01)
  - Key API: `--symptom <text>`, `--capture-log`, `--suggest-fix` flags; piped stdin as symptom when `[ ! -t 0 ]`
  - Key types: stdout is YAML-frontmatter + 6-section Markdown report; exit 0 on success
- `commands/detective.md` (from T02)
  - Key API: frontmatter `description:` field; references `triage-issue.sh` in `## Referenced Scripts`

### From Disk (Pre-existing)

- `tools/verify/` — project-owned verifier directory (standard location per AD-19)

## Constraints

- All verifier filenames must embed the milestone slug as first segment: `m041-p01-<descriptor>.sh`
- Verifiers must use single-script-file shape per AD-19 (no inline compound bash)
- Bash 3.2+ compatible (CON-3)

## Expected Output

7 new files under `tools/verify/`:
- `m041-p01-triage-report-sections.sh`
- `m041-p01-suggest-fix-unconditional.sh`
- `m041-p01-suggest-fix-heuristic.sh`
- `m041-p01-pipe-input.sh`
- `m041-p01-command-shape.sh`
- `m041-p01-report-frontmatter.sh`
- `m041-p01-phase-suite.sh`

All verifiers pass. Phase suite reports `pass=6 fail=0`.
