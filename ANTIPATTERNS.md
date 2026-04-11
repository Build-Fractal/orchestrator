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
