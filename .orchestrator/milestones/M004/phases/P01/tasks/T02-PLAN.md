---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01"
milestone: "M004"
name: "Antipattern Register"
depends_on: [T01]
---

## Description

Create `ANTIPATTERNS.md` at the orchestrator root as an append-only register of observed antipatterns. Each entry references a real incident from M001-M003 as evidence. Antipattern entries are permanent (AD-11: no staleness decay, no lifecycle management) and serve as structural warnings that recur regardless of context.

## Steps

### Step 1: Create ANTIPATTERNS.md

Create the file `ANTIPATTERNS.md` (at the project root, NOT inside `.specify/`) with the structure below. The file must contain:

1. A header explaining the purpose and append-only policy
2. At least 2 antipattern entries, each with:
   - ID: `AP-NNN` (sequential)
   - Name: short descriptive name
   - Observed In: milestone reference (M001, M002, or M003)
   - Principle Violated: reference to constitution principle by number
   - Description: what went wrong
   - Evidence: specific file paths and line numbers from the real incident
   - Remedy: what to do instead

Write the following content to `ANTIPATTERNS.md`:

```markdown
# Antipattern Register

Append-only register of observed antipatterns from real orchestrator development.
Entries are permanent — they do not decay or expire (see constitution, AD-11).
Each entry references a real incident as evidence.

When adding a new entry: use the next sequential `AP-NNN` ID, reference the
milestone where the antipattern was observed, cite the constitution principle
it violates, and include specific file paths as evidence.

## AP-001: Platform-Specific Bash Syntax in Portable Scripts

**Observed In**: M002, M003 (audit)
**Principle Violated**: IX (Reproducibility Over Convenience)
**Related Constitution Constraint**: Bash 3.2 compatibility (NFR-200)

**Description**: Process substitution used as a redirection target (`done < <(command)`) in two files. This syntax is valid in Bash 4+ but fails silently or with cryptic errors on macOS's default Bash 3.2. The scripts passed all tests on the development machine (which had Bash 5 via Homebrew) but would fail on a clean macOS installation.

**Evidence**:
- `scripts/dispatch/build-context.sh:689` — `done < <(find ...)`
- `scripts/verify/check-scope.sh:102` — `done < <(git diff ...)`
- Discovered during M002+M003 audit (see `.specify/orchestrator/handoff-m002-m003-audit-fixes.md`, CRITICAL 1)

**Remedy**: Use temp-file pattern for feeding command output into while loops:
```
_tmp="$(mktemp)"
command > "$_tmp"
while IFS= read -r line; do ...; done < "$_tmp"
rm -f "$_tmp"
```
Or use a pipe: `command | while IFS= read -r line; do ...; done` (noting that the loop body runs in a subshell and cannot set parent variables).

## AP-002: Platform-Divergent sed In-Place Editing

**Observed In**: M001 (audit)
**Principle Violated**: IX (Reproducibility Over Convenience)
**Related Constitution Constraint**: Bash 3.2 compatibility (NFR-200)

**Description**: Five locations used `sed -i.bak` which creates `.bak` backup files on macOS (BSD sed requires an argument to `-i`). GNU sed treats `.bak` as the backup suffix. The project already had a portable `sed_i` helper in 3 other scripts, but the pattern was not consistently applied. Result: junk `.bak` files accumulating in the working directory on macOS.

**Evidence**:
- `scripts/lifecycle/sync-roadmap.sh:82,91` — `sed -i.bak` calls
- `scripts/lifecycle/lock-manager.sh:189,193,196` — `sed -i.bak` calls
- 3 other scripts already used `sed_i` helper correctly
- Discovered during M002+M003 audit (see `.specify/orchestrator/handoff-m002-m003-audit-fixes.md`, CRITICAL 2)

**Remedy**: Use a portable `sed_i` helper function in every script that needs in-place editing:
```
sed_i() {
  if sed --version 2>/dev/null | grep -q GNU; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}
```
Better: extract `sed_i` into a shared utility (`scripts/util/sed-i.sh`) and source it — same pattern as `json_field` extraction (see Knowledge Base, Audit Remediation Patterns).

## AP-003: Missing Double-Sourcing Guards on Library Files

**Observed In**: M002 (audit)
**Principle Violated**: VIII (No Dead Infrastructure) — sourcing a library twice wastes context and can cause re-initialization bugs
**Related Constitution Constraint**: NFR-203 (all libraries with double-sourcing guards)

**Description**: Seven library files created during M002 P01 lacked idempotent sourcing guards. When a script sources library A which also sources library B, and the script independently sources library B, the library B code runs twice. For stateless utilities this is merely wasteful; for libraries that initialize state (counters, temp files), it causes subtle bugs.

**Evidence**:
- `scripts/knowledge/lib/staleness.sh` — no guard
- `scripts/knowledge/lib/index-utils.sh` — no guard
- `scripts/knowledge/lib/graph-utils.sh` — no guard
- `scripts/knowledge/lib/format-utils.sh` — no guard
- `scripts/knowledge/lib/manifest-utils.sh` — no guard
- `scripts/knowledge/lib/telemetry-utils.sh` — no guard
- `scripts/knowledge/lib/routing-utils.sh` — no guard
- Discovered during M002+M003 audit (see `.specify/orchestrator/handoff-m002-m003-audit-fixes.md`, MEDIUM)

**Remedy**: Every sourced library file must include this guard at the very top (after the shebang, before any other code):
```
[ -n "${_LIBNAME_SOURCED:-}" ] && return 0
_LIBNAME_SOURCED=1
```
Where `LIBNAME` is a unique identifier derived from the filename (e.g., `_STALENESS_SOURCED` for `staleness.sh`).
```

### Step 2: Verify antipattern entries reference constitution

Confirm that `ANTIPATTERNS.md` references the constitution file. The entries reference principles by number (VIII, IX) which are defined in `.specify/memory/constitution.md`.

### Step 3: Verify

Run these verification commands:

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
echo "=== T02 Verification ==="

# At least 2 AP entries
count=$(grep -c '^## AP-' ANTIPATTERNS.md)
test "$count" -ge 2 && echo "PASS: $count antipattern entries" || echo "FAIL: only $count entries"

# References real milestones
grep -q 'M00[123]' ANTIPATTERNS.md && echo "PASS: References M001-M003" || echo "FAIL: No milestone references"

# Minimum line count
lines=$(wc -l < ANTIPATTERNS.md | tr -d ' ')
test "$lines" -ge 40 && echo "PASS: $lines lines (min 40)" || echo "FAIL: only $lines lines"

# Contains AP- pattern
grep -q 'AP-' ANTIPATTERNS.md && echo "PASS: Contains AP- entries" || echo "FAIL: No AP- entries"

# References constitution
grep -q 'constitution' ANTIPATTERNS.md && echo "PASS: References constitution" || echo "FAIL: No constitution reference"
```

## Must-Haves

### Truths

- ANTIPATTERNS.md has at least 2 antipattern entries with real incident references
  - Check: `test "$(grep -c '^## AP-' ANTIPATTERNS.md)" -ge 2`
- Antipattern entries reference specific milestones (M001, M002, or M003) as evidence
  - Check: `grep -q 'M00[123]' ANTIPATTERNS.md`

### Artifacts

- `ANTIPATTERNS.md` (min 40 lines, contains "AP-")

### Key Links

- `ANTIPATTERNS.md` → `.specify/memory/constitution.md` (antipatterns reference constitutional principles)

## Verification

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
echo "=== T02 Verification ==="
count=$(grep -c '^## AP-' ANTIPATTERNS.md)
test "$count" -ge 2 && echo "PASS: $count antipattern entries" || echo "FAIL: only $count entries"
grep -q 'M00[123]' ANTIPATTERNS.md && echo "PASS: References M001-M003" || echo "FAIL: No milestone references"
lines=$(wc -l < ANTIPATTERNS.md | tr -d ' ')
test "$lines" -ge 40 && echo "PASS: $lines lines (min 40)" || echo "FAIL: only $lines lines"
grep -q 'AP-' ANTIPATTERNS.md && echo "PASS: Contains AP- entries" || echo "FAIL: No AP- entries"
grep -q 'constitution' ANTIPATTERNS.md && echo "PASS: References constitution" || echo "FAIL: No constitution reference"
```

## Inputs

### From Previous Tasks

- `.specify/memory/constitution.md` (from T01)
  - Key API: N/A (document, not code)
  - Key types: Principles VIII-XIII are defined and numbered, referenced by roman numeral in antipattern entries (e.g., "Principle IX (Reproducibility Over Convenience)")
  - Behavioral contract: The constitution is now v2.0.0 with 13 principles. Antipattern entries should reference principle numbers that exist in the updated constitution.

### From Disk (Pre-existing)

- `.specify/orchestrator/handoff-m002-m003-audit-fixes.md` — Source of real incident evidence for antipattern entries. CRITICAL 1: process substitution, CRITICAL 2: sed -i.bak, MEDIUM: missing double-sourcing guards.
- `.specify/orchestrator/KNOWLEDGE.md` — Lessons L001 and L002 (PID detection issues) provide additional incident evidence if more antipatterns are needed.
- `specs/004-engine-architecture/spec.md` — FR-233 requires ANTIPATTERNS.md with append-only entries referencing real incidents.
- `.specify/orchestrator/milestones/M004/M004-CONTEXT.md` — AD-11 establishes that antipattern entries are permanent with no staleness decay.

## Expected Output

The file `ANTIPATTERNS.md` at the project root containing:
- Header with purpose and append-only policy explanation
- At least 3 antipattern entries (AP-001, AP-002, AP-003) each with: ID, name, observed-in milestone, violated principle, description, evidence with file paths, and remedy
- References to constitution principles VIII and IX (from T01)
- References to milestones M001, M002, M003 as evidence sources
