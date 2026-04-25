---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P01"
milestone: "M014"
name: "scripts/knowledge/spec-complexity-probe.sh FR-5 stub + RUNTIME-ASSUMPTIONS.md D016 registry scaffold"
depends_on: []
---

## Prerequisites

No upstream task dependencies (parallelizable with T01/T02/T03). Pre-existing disk state:

- `scripts/knowledge/` exists with several knowledge-handling scripts (`ingest-spec.sh`, `detect-spec-shape.sh`, etc.).
- No `RUNTIME-ASSUMPTIONS.md` file exists at repo root — T04 creates it.
- `scripts/verify/anti-pattern-lint.sh` is the lint compliance verifier.

## Description

Ship two small artifacts:

1. `scripts/knowledge/spec-complexity-probe.sh` — the FR-5 complexity probe **stub**. Per the P01 boundary map, this stub unconditionally emits `probe=below-threshold` so that `scripts/specify/specify.sh` (T05) can wire the call without its behavior branching on probe output in P01. Full probe logic (FR count, user-story count, `<TODO>` density, contradiction-signal count via CC LLM pass) lands in P04.

2. `RUNTIME-ASSUMPTIONS.md` — the D016 registry file. Per D016, every CC-only path landed by this milestone must be logged here for the M009 runtime-parity audit to consume as a punch-list. T04 ships the file scaffold with two initial entries: FR-3 (LLM-assisted scaffolder, surface deferred in P01) and FR-5 (contradiction-signal probe, stubbed in P01).

## Steps

### Step 1: Create `scripts/knowledge/spec-complexity-probe.sh`

Verbatim body:

```bash
#!/usr/bin/env bash
# scripts/knowledge/spec-complexity-probe.sh — FR-5 complexity probe (P01 stub).
#
# P01: unconditionally emits probe=below-threshold. Structured fields are all
# zero. The full probe logic ships in M014/P04; this stub exists so
# scripts/specify/specify.sh can wire the call at end-of-scaffold without its
# behavior branching on probe output.
#
# Usage: spec-complexity-probe.sh <spec-path>
#   <spec-path>   Path to a spec markdown file. Must exist.
#
# Emits to stdout (single line):
#   probe=below-threshold
# Emits to stderr (structured fields):
#   fr_count=0
#   user_story_count=0
#   todo_count=0
#   contradiction_signals=0
#
# Exit 0 on success; 1 if <spec-path> is missing or unreadable.
# Bash 3.2 compatible.

set -u

if [ $# -lt 1 ]; then
  echo "usage: spec-complexity-probe.sh <spec-path>" >&2
  exit 1
fi

SPEC_PATH="$1"
if [ ! -f "$SPEC_PATH" ]; then
  echo "spec-complexity-probe.sh: not found: $SPEC_PATH" >&2
  exit 1
fi

# Stub verdict — P01 boundary map. Full logic in P04.
echo "probe=below-threshold"

{
  echo "fr_count=0"
  echo "user_story_count=0"
  echo "todo_count=0"
  echo "contradiction_signals=0"
} >&2

exit 0
```

Make executable: `chmod +x scripts/knowledge/spec-complexity-probe.sh`.

### Step 2: Create `RUNTIME-ASSUMPTIONS.md`

Verbatim body:

```markdown
---
schema_version: "1.0"
type: runtime-assumptions-registry
created_at: "2026-04-22"
last_updated: "2026-04-22"
---

# Runtime Assumptions Registry

Per Decision D016, this file logs every CC-only (Claude-Code-only) path introduced by the orchestrator. M009's runtime-parity audit consumes this file as a punch-list: each entry names the Claude-Code-specific assumption, the Codex CLI / Cursor fallback shipped in v1, and the runtime-parity obligation for future work.

Every new entry is **append-only**: register CC-only paths as they are introduced; remove an entry only when runtime parity is achieved and verified.

## Entry Schema

Each entry lives under a `## FR-N: <short-name>` heading with four required subsections:

- **Claude Code assumption** — what the CC-only path does (LLM round-trip, specific API, etc.).
- **Codex/Cursor fallback** — the non-LLM path shipped in v1 that these runtimes fall through to. Must be fully functional, never silently degraded.
- **Milestone / phase** — `M###/P##` that introduced the assumption.
- **M009 obligation** — what the runtime-parity audit needs to do to close this entry (re-implement under Codex/Cursor, accept CC-only as permanent, etc.).

## Entries

### FR-3: LLM-assisted scaffold-fill depth (`orchestrator:specify`)

- **Claude Code assumption**: under CC runtime, `scripts/specify/specify.sh` will invoke an LLM round-trip via `scripts/dispatch/dispatch-interface.sh` using `templates/spec-scaffolder-prompt.md` to populate first-pass prose for Problem Statement and at least one User Story stub when `--description` exceeds 80 words.
- **Codex/Cursor fallback**: skeleton-only scaffold (all sections present, all content `<TODO: ...>` placeholder). Fully functional — the maintainer fills every section by hand, exactly as the M013 and M014 specs were hand-authored.
- **Milestone / phase**: M014/P01 surface; M014/P04 (or later) invocation.

  In P01, the LLM invocation is **not yet wired** — the template and the runtime-dispatch surface ship, but `scripts/specify/specify.sh` is skeleton-only across all runtimes. The CC-only invocation is deferred to a later M014 phase per Phase Sequencing table (spec.md §Phase Sequencing).
- **M009 obligation**: re-implement LLM-assisted fill under Codex CLI (via Codex's API or external LLM round-trip) and Cursor. Until then, document CC-only as the canonical scaffold path.

### FR-5: Complexity probe contradiction-signal count (`scripts/knowledge/spec-complexity-probe.sh`)

- **Claude Code assumption**: under CC runtime (in M014/P04), the probe will invoke an LLM pass to count contradiction signals ("should support both X and its opposite", mutually-exclusive requirements, etc.) in the draft spec prose. The signal count feeds the US-3 three-way (y/n/d) prompt.
- **Codex/Cursor fallback**: zero contradiction signals counted (LLM pass skipped); the probe still emits the structured fields (`fr_count`, `user_story_count`, `todo_count`, `contradiction_signals=0`) so downstream consumers can parse output uniformly.
- **Milestone / phase**: M014/P01 stub; M014/P04 full implementation.

  In P01, the probe unconditionally emits `probe=below-threshold` with all structured fields at zero. The stub exists so `scripts/specify/specify.sh` can wire the call without branching on probe output in P01. P04 replaces the body; the caller is unchanged.
- **M009 obligation**: re-implement the contradiction-signal LLM pass under Codex/Cursor (or document zero-signal as permanent fallback if LLM round-trip under those runtimes proves prohibitively expensive for the value delivered).

## Cross-References

- `commands/specify.md` — FR-3 scaffolder surface
- `scripts/specify/specify.sh` — FR-3 invocation site (invocation deferred per P01 boundary map)
- `scripts/knowledge/spec-complexity-probe.sh` — FR-5 stub (P01) → full (P04)
- `templates/spec-scaffolder-prompt.md` — FR-3 CC LLM prompt body
- `.orchestrator/DECISIONS.md` D016 — origin of the `RUNTIME-ASSUMPTIONS.md` discipline

<!-- Future entries land below this line as new CC-only paths are introduced.
     Append-only per D016. Do not reorder or delete existing entries. -->
```

### Step 3: Create gate verifiers

#### `scripts/verify/m014-p01-complexity-probe-stub.sh`

```bash
#!/usr/bin/env bash
# Gate: verify spec-complexity-probe.sh stub behavior.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PROBE="${PROJECT_ROOT}/scripts/knowledge/spec-complexity-probe.sh"

if [ ! -x "$PROBE" ]; then
  echo "FAIL: scripts/knowledge/spec-complexity-probe.sh missing or not executable" >&2
  exit 1
fi

# Run against an existing spec file.
TARGET="${PROJECT_ROOT}/specs/024-spec-management-extended/spec.md"
if [ ! -f "$TARGET" ]; then
  echo "FAIL: target spec missing: $TARGET" >&2; exit 1
fi

STDOUT="$(bash "$PROBE" "$TARGET" 2>/dev/null)"
RC=$?
if [ $RC -ne 0 ]; then
  echo "FAIL: probe exited $RC (expected 0)" >&2; exit 1
fi

echo "$STDOUT" | grep -qF 'probe=below-threshold' || {
  echo "FAIL: probe stdout missing probe=below-threshold" >&2; exit 1;
}

STDERR_FILE="$(mktemp)"
bash "$PROBE" "$TARGET" >/dev/null 2> "$STDERR_FILE"
grep -qF 'fr_count=0' "$STDERR_FILE" || {
  echo "FAIL: probe stderr missing fr_count=0" >&2; rm -f "$STDERR_FILE"; exit 1;
}
grep -qF 'contradiction_signals=0' "$STDERR_FILE" || {
  echo "FAIL: probe stderr missing contradiction_signals=0" >&2; rm -f "$STDERR_FILE"; exit 1;
}
rm -f "$STDERR_FILE"

# Missing-arg case.
bash "$PROBE" >/dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "FAIL: probe with no args exited 0 (expected non-zero)" >&2; exit 1
fi

# Non-existent path case.
bash "$PROBE" /tmp/does-not-exist-m014-p01.md >/dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "FAIL: probe against missing path exited 0 (expected non-zero)" >&2; exit 1
fi

echo "PASS: complexity-probe stub verified"
exit 0
```

#### `scripts/verify/m014-p01-runtime-assumptions.sh`

```bash
#!/usr/bin/env bash
# Gate: verify RUNTIME-ASSUMPTIONS.md shape and entries.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REGISTRY="${PROJECT_ROOT}/RUNTIME-ASSUMPTIONS.md"

if [ ! -f "$REGISTRY" ]; then
  echo "FAIL: RUNTIME-ASSUMPTIONS.md missing at repo root" >&2; exit 1
fi

# Required sections and entries.
grep -qF 'type: runtime-assumptions-registry' "$REGISTRY" || {
  echo "FAIL: frontmatter type missing" >&2; exit 1;
}
grep -qF '# Runtime Assumptions Registry' "$REGISTRY" || {
  echo "FAIL: top-level heading missing" >&2; exit 1;
}
grep -qF '## Entry Schema' "$REGISTRY" || {
  echo "FAIL: ## Entry Schema section missing" >&2; exit 1;
}
grep -qE '^### FR-3: LLM-assisted scaffold-fill depth' "$REGISTRY" || {
  echo "FAIL: FR-3 entry missing" >&2; exit 1;
}
grep -qE '^### FR-5: Complexity probe contradiction-signal count' "$REGISTRY" || {
  echo "FAIL: FR-5 entry missing" >&2; exit 1;
}

# Each entry has the four required subsections.
grep -qF 'Claude Code assumption' "$REGISTRY" || {
  echo "FAIL: 'Claude Code assumption' subsection absent" >&2; exit 1;
}
grep -qF 'Codex/Cursor fallback' "$REGISTRY" || {
  echo "FAIL: 'Codex/Cursor fallback' subsection absent" >&2; exit 1;
}
grep -qF 'M009 obligation' "$REGISTRY" || {
  echo "FAIL: 'M009 obligation' subsection absent" >&2; exit 1;
}
grep -qF 'D016' "$REGISTRY" || {
  echo "FAIL: D016 cross-reference absent" >&2; exit 1;
}

echo "PASS: RUNTIME-ASSUMPTIONS.md shape verified"
exit 0
```

Make both executable.

## Must-Haves

- `scripts/knowledge/spec-complexity-probe.sh` exists, is executable, emits `probe=below-threshold` on stdout, emits structured zero-valued fields on stderr, exits 0 when given a valid spec path
- The probe exits non-zero with no args and with a missing-path arg
- `RUNTIME-ASSUMPTIONS.md` exists at repo root with frontmatter, schema documentation, and the two required entries (FR-3, FR-5)
- Every entry has the four required subsections (Claude Code assumption, Codex/Cursor fallback, Milestone/phase, M009 obligation)
- `RUNTIME-ASSUMPTIONS.md` cross-references D016 and the relevant scripts/commands
- `scripts/verify/m014-p01-complexity-probe-stub.sh` exists, is executable, exits 0
- `scripts/verify/m014-p01-runtime-assumptions.sh` exists, is executable, exits 0
- Both new shell scripts are Bash 3.2 compatible and pass `scripts/verify/anti-pattern-lint.sh`

## Verification

```
bash scripts/verify/m014-p01-complexity-probe-stub.sh
```

Expected: `PASS: complexity-probe stub verified`, exit 0.

```
bash scripts/verify/m014-p01-runtime-assumptions.sh
```

Expected: `PASS: RUNTIME-ASSUMPTIONS.md shape verified`, exit 0.

```
bash scripts/verify/anti-pattern-lint.sh --fixture scripts/knowledge/spec-complexity-probe.sh
```

Expected: exit 0.

## Inputs

### From Previous Tasks

None — T04 is independent.

### From Disk (Pre-existing)

- `specs/024-spec-management-extended/spec.md` — used as a non-trivial target for the stub probe run.
- `.orchestrator/DECISIONS.md` — D016 text referenced by the registry (read-only reference).
- `scripts/verify/anti-pattern-lint.sh` — lint compliance verifier.

## Constraints

- The stub **unconditionally** emits `probe=below-threshold`. Do not add any FR-count or TODO-count logic — that is P04's responsibility.
- The structured fields on stderr must include `fr_count=`, `user_story_count=`, `todo_count=`, `contradiction_signals=` — downstream (P04) consumers rely on stable field names.
- `RUNTIME-ASSUMPTIONS.md` is append-only per D016; do not add extra entries speculatively. P01 lands exactly two entries (FR-3, FR-5).
- Bash 3.2 compatible; passes `scripts/verify/anti-pattern-lint.sh`.

## Expected Output

Files committed:

1. `scripts/knowledge/spec-complexity-probe.sh` — FR-5 stub (~40 lines, executable)
2. `RUNTIME-ASSUMPTIONS.md` — D016 registry (~60 lines)
3. `scripts/verify/m014-p01-complexity-probe-stub.sh` — stub gate (~50 lines, executable)
4. `scripts/verify/m014-p01-runtime-assumptions.sh` — registry gate (~40 lines, executable)

Both gate verifiers exit 0.
