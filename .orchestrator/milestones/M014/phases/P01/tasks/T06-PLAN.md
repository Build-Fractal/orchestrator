---
schema_version: "1.0"
type: task-plan
task: "T06"
phase: "P01"
milestone: "M014"
name: "tests/test-specify-shape.sh FR-18 byte-compat fixture + references/spec-management.md partial"
depends_on: ["T01", "T02", "T05"]
---

## Prerequisites

Three upstream tasks must be green:

- T01: `templates/spec-template.md` + `tests/fixtures/m014-p01/specify-fixture-prose.txt` + `tests/fixtures/m014-p01/expected-section-headings.txt` ready.
- T02: `scripts/verify/spec-shape-lint.sh` ready.
- T05: `scripts/specify/specify.sh` + `commands/specify.md` + `.orchestrator/config.yml` `specify:` section ready.

Pre-existing disk state:

- `scripts/knowledge/detect-spec-shape.sh` exists (M011) — the SC-2 I/O-contract asserter.
- `references/` exists with 15 existing reference docs.
- `references/README.md` is the references index.

## Description

Ship two artifacts:

1. `tests/test-specify-shape.sh` — the FR-18 byte-compat fixture test. Asserts that `scripts/specify/specify.sh` against the canonical fixture prose produces a `spec.md` whose section-heading list byte-matches the derivation from `templates/spec-template.md`, passes `scripts/verify/spec-shape-lint.sh`, and passes `scripts/knowledge/detect-spec-shape.sh` with `shape=speckit` (SC-2 I/O-contract assertion).

2. `references/spec-management.md` — the partial reference doc per SC-11. P01 ships the Section Contract SSOT pointer, the dual-write marker convention, and the FR-19 `--dry-run` manifest record shape. P04 completes the doc with pressure-test + decomposition sections.

## Steps

### Step 1: Create `tests/test-specify-shape.sh`

Verbatim body:

```bash
#!/usr/bin/env bash
# tests/test-specify-shape.sh — FR-18 byte-compat fixture test.
# Asserts scripts/specify/specify.sh produces a spec.md whose section-heading
# list byte-matches the derivation from templates/spec-template.md, passes
# spec-shape-lint.sh, and passes detect-spec-shape.sh with shape=speckit.
# Bash 3.2 compatible.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

TEMPLATE="${PROJECT_ROOT}/templates/spec-template.md"
EXPECTED_HEADINGS="${PROJECT_ROOT}/tests/fixtures/m014-p01/expected-section-headings.txt"
FIXTURE_PROSE="${PROJECT_ROOT}/tests/fixtures/m014-p01/specify-fixture-prose.txt"
SPECIFY="${PROJECT_ROOT}/scripts/specify/specify.sh"
SHAPE_LINT="${PROJECT_ROOT}/scripts/verify/spec-shape-lint.sh"
SHAPE_DETECT="${PROJECT_ROOT}/scripts/knowledge/detect-spec-shape.sh"
DUAL_WRITE="${PROJECT_ROOT}/scripts/util/dual-write-runtime-md.sh"
PROBE="${PROJECT_ROOT}/scripts/knowledge/spec-complexity-probe.sh"

for f in "$TEMPLATE" "$EXPECTED_HEADINGS" "$FIXTURE_PROSE" "$SPECIFY" "$SHAPE_LINT" "$SHAPE_DETECT" "$DUAL_WRITE" "$PROBE"; do
  if [ ! -e "$f" ]; then
    echo "FAIL: upstream artifact missing: $f" >&2; exit 1
  fi
done

# Hermetic scratch project.
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

mkdir -p "$SCRATCH/.orchestrator" "$SCRATCH/templates" "$SCRATCH/scripts/util" "$SCRATCH/scripts/specify" "$SCRATCH/scripts/knowledge" "$SCRATCH/scripts/verify" "$SCRATCH/scripts/lifecycle" "$SCRATCH/specs" "$SCRATCH/tests/fixtures/m014-p01"

cp "$TEMPLATE" "$SCRATCH/templates/"
cp "$DUAL_WRITE" "$SCRATCH/scripts/util/"
cp "$SPECIFY" "$SCRATCH/scripts/specify/"
cp "$PROBE" "$SCRATCH/scripts/knowledge/"
cp "$SHAPE_LINT" "$SCRATCH/scripts/verify/"
if [ -f "$PROJECT_ROOT/scripts/lifecycle/lock-manager.sh" ]; then
  cp "$PROJECT_ROOT/scripts/lifecycle/lock-manager.sh" "$SCRATCH/scripts/lifecycle/"
fi
cp "$FIXTURE_PROSE" "$SCRATCH/tests/fixtures/m014-p01/"
cp "$EXPECTED_HEADINGS" "$SCRATCH/tests/fixtures/m014-p01/"

cat > "$SCRATCH/.orchestrator/config.yml" <<'EOF'
schema_version: "1.0"
dual_write_agents: true
EOF

cat > "$SCRATCH/CLAUDE.md" <<'EOF'
# CLAUDE.md fixture
EOF

FIXTURE_TEXT="$(cat "$FIXTURE_PROSE")"

# --- Dry-run exercise ---
DRY_OUT="$(bash "$SCRATCH/scripts/specify/specify.sh" --description "$FIXTURE_TEXT" --slug specify-fixture --yes --dry-run 2>&1 || true)"
if [ $? -ne 0 ]; then
  echo "FAIL: --dry-run exited non-zero" >&2; exit 1
fi
echo "$DRY_OUT" | grep -qE '"action_type":"scaffold-spec"' || {
  echo "FAIL: --dry-run missing scaffold-spec manifest record" >&2; exit 1
}

# --- Live run ---
cd "$SCRATCH"
WRITTEN="$(bash "$SCRATCH/scripts/specify/specify.sh" --description "$FIXTURE_TEXT" --slug specify-fixture --yes 2>&1 | tail -1)"
cd "$PROJECT_ROOT"

if [ ! -f "$WRITTEN" ]; then
  echo "FAIL: specify.sh live run did not produce spec.md at $WRITTEN" >&2; exit 1
fi

# --- Section-heading byte-match against expected ---
# Expected headings include the literal `{{feature_title}}` and `<TODO: ...>`
# placeholders. The scaffolder has substituted `{{feature_title}}` with the
# actual slug; so compare after normalizing both streams.
ACTUAL="$(mktemp)"
EXP_NORM="$(mktemp)"
grep -E '^#+[[:space:]]' "$WRITTEN" > "$ACTUAL"
sed -e 's/{{[^}]*}}/__PLACEHOLDER__/g' "$EXPECTED_HEADINGS" > "$EXP_NORM"
sed -e 's/^# Feature Specification:.*/# Feature Specification: __PLACEHOLDER__/' -i '' "$ACTUAL" 2>/dev/null || \
  sed -e 's/^# Feature Specification:.*/# Feature Specification: __PLACEHOLDER__/' "$ACTUAL" > "${ACTUAL}.norm" && mv "${ACTUAL}.norm" "$ACTUAL"

if ! diff -q "$EXP_NORM" "$ACTUAL" >/dev/null 2>&1; then
  echo "FAIL: scaffolded section headings diverge from expected" >&2
  diff "$EXP_NORM" "$ACTUAL" >&2 || true
  rm -f "$ACTUAL" "$EXP_NORM"
  exit 1
fi
rm -f "$ACTUAL" "$EXP_NORM"

# --- spec-shape-lint passes ---
bash "$SHAPE_LINT" "$WRITTEN" >/dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "FAIL: spec-shape-lint.sh failed on scaffolded spec" >&2; exit 1
fi

# --- SC-2 I/O-contract: detect-spec-shape reports shape=speckit ---
SHAPE_OUT="$(bash "$SHAPE_DETECT" --spec-path "$WRITTEN" 2>/dev/null)"
if ! echo "$SHAPE_OUT" | grep -qE '^shape=speckit'; then
  echo "FAIL: detect-spec-shape.sh did not report shape=speckit; got: $SHAPE_OUT" >&2
  exit 1
fi

echo "PASS: tests/test-specify-shape.sh"
exit 0
```

Make executable: `chmod +x tests/test-specify-shape.sh`.

**Note on the `sed -i` portability quirk**: The fallback `sed -e '...' "$ACTUAL" > "${ACTUAL}.norm" && mv ...` handles macOS's BSD `sed` which requires an argument after `-i`, while GNU sed does not. Prefer the no-`-i` pattern for portability.

### Step 2: Create `references/spec-management.md`

Verbatim body:

```markdown
# Spec Management Reference

Authored by M014. Partial in P01 — documents the Section Contract SSOT pointer, the dual-write marker convention, and the FR-19 `--dry-run` manifest record shape. P04 completes this document with pressure-test and decomposition sections.

## Section Contract

The `templates/spec-template.md` file is the canonical Section Contract SSOT. Every spec scaffolded by `orchestrator:specify` conforms to this shape; `scripts/verify/spec-shape-lint.sh` derives its required-section list from this template (not hardcoded).

Required top-level sections, in order:

1. YAML frontmatter block + `# Feature Specification: <title>` heading
2. `## Problem Statement`
3. `## User Scenarios & Testing *(mandatory)*`
   - `### Minimal Slice (Phase 1 Load-Bearing Scope)` subsection
   - `### User Story N — <title> (Priority: PN)` — at least one
4. `## Edge Cases`
5. `## Functional Requirements`
6. `## Success Criteria`
7. `## Non-Goals`
8. `## Constraints`
   - `### Knowledge-Layer Boundary (<milestone> vs. <owning-knowledge-milestone>)` subsection
9. `## Assumptions`
10. `## Constitution Check`
11. `## Open Questions (defer to planning)`
12. `## Dependencies`
13. `## Downstream Consumers (informational, not binding)`

**I/O contract**: the scaffolded output is a superset of the spec-kit `spec-template.md` vocabulary, so `scripts/knowledge/detect-spec-shape.sh` reports `shape=speckit` without renormalization. `scripts/knowledge/ingest-spec.sh` takes the fast path (no normalization required).

Placeholder convention: unpopulated content is bracketed `<TODO: ...>`. Authored content replaces placeholders as-is; `spec-shape-lint.sh` emits `todo_count=N` informationally (non-zero means skeleton, zero means authored).

## Dual-Write Marker Convention

The FR-12 runtime-instruction dual-write helper (`scripts/util/dual-write-runtime-md.sh`) writes content between marker lines of exactly this shape:

```
# >>> orchestrator:<region-name> >>>
<content lines>
# <<< orchestrator:<region-name> <<<
```

The region-name is passed via `--marker <region>`. The current write-sites (P01):

| Region | Written by | Shape |
|---|---|---|
| `recent-changes` | `orchestrator:specify` | one-line `- <slug>: <description-first-80-chars>` per scaffolded spec |

P02 extends this table with `orchestrator:init` and `orchestrator:consolidate` write-sites.

### Byte-preservation invariant (SC-6a)

Bytes outside the marker region are byte-identical pre- and post-write. `shasum -a 256` of the outside-markers byte stream is invariant across any number of writes. The test `tests/test-dual-write-outside-invariant.sh` enforces this contract.

### `dual_write_agents: false` gate

When `.orchestrator/config.yml` has `dual_write_agents: false` at the top level, the helper writes only `CLAUDE.md` and skips `AGENTS.md` with a `SKIPPED: AGENTS.md (dual_write_agents=false)` line on stderr. Operators on pure-Claude-Code projects opt out cleanly; default is `true`.

## `--dry-run` Manifest Shape (FR-19)

Every M014 command's `--dry-run` flag emits structured JSONL records to stdout, one record per proposed action. Record shape:

```json
{
  "command": "<command-name>",
  "action_type": "<action-type>",
  "target_path": "<absolute-or-repo-relative-path>",
  "source_ref": "<template-or-fragment-path>",
  "description": "<human-readable-one-line-summary>"
}
```

Defined `action_type` values (M014-local; additional values permitted in later phases; removal requires a D-row):

| action_type | Emitter | Target |
|---|---|---|
| `scaffold-spec` | `orchestrator:specify` | `specs/<NNN>-<slug>/spec.md` |
| `dual-write-region` | `scripts/util/dual-write-runtime-md.sh`, `orchestrator:specify` | `CLAUDE.md`, `AGENTS.md` |
| `classify-comment` (P03) | `orchestrator:comments` | in-memory classification result |
| `apply-amendment` (P03) | `orchestrator:comments` | `specs/<NNN>-<slug>/spec.md` |
| `append-decision` (P03) | `orchestrator:comments` | `.orchestrator/DECISIONS.md` |

M013's `--dry-run` format is not retrofitted by M014 (see spec §FR-19).

## Failure Semantics

Inherited from M016/M021 zero-prompt discipline and M013/FR-13 strict-mode precedent:

- Missing prerequisites (`.orchestrator/` absent, templates missing): exit 2 with diagnostic pointing to the install path (`orchestrator:init`) or the missing artifact.
- Slug collision without `--force`: exit 1, mention the `--force` override.
- Dual-write failure mid-run: `unit_close` records `dual_writes` count < 2 so operators can detect partial writes in the execution log.
- Execution-log append failure: **warn on stderr but do not fail the command** — observability is best-effort, not load-bearing on scaffold success.

<!-- partial: P04 completes with pressure-test + decomposition sections -->
```

### Step 3: Update `references/README.md`

Append a one-line entry for the new doc. Read the existing file first to understand its format, then insert the new entry alphabetically or at the next logical position (depending on existing pattern — prefer appending if no strict order is enforced).

Expected diff: one new line added of the form:
```
- `references/spec-management.md` — Section Contract SSOT, dual-write marker convention, and `--dry-run` manifest shape. (M014/P01; P04 completes)
```

Outside this insertion, bytes are byte-preserved.

### Step 4: Create gate verifiers

#### `scripts/verify/m014-p01-specify-shape-test.sh`

```bash
#!/usr/bin/env bash
# Gate: run the FR-18 byte-compat fixture test.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TEST="${PROJECT_ROOT}/tests/test-specify-shape.sh"

if [ ! -x "$TEST" ]; then
  echo "FAIL: tests/test-specify-shape.sh missing or not executable" >&2; exit 1
fi

bash "$TEST"
exit $?
```

#### `scripts/verify/m014-p01-spec-management-reference.sh`

```bash
#!/usr/bin/env bash
# Gate: verify references/spec-management.md shape.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOC="${PROJECT_ROOT}/references/spec-management.md"
IDX="${PROJECT_ROOT}/references/README.md"

if [ ! -f "$DOC" ]; then
  echo "FAIL: references/spec-management.md missing" >&2; exit 1
fi

grep -qE '^# Spec Management Reference' "$DOC" || {
  echo "FAIL: top-level heading missing" >&2; exit 1
}
grep -qE '^## Section Contract' "$DOC" || {
  echo "FAIL: Section Contract section missing" >&2; exit 1
}
grep -qE '^## Dual-Write Marker Convention' "$DOC" || {
  echo "FAIL: Dual-Write Marker Convention section missing" >&2; exit 1
}
grep -qF 'orchestrator:<region-name>' "$DOC" || {
  echo "FAIL: marker convention literal absent" >&2; exit 1
}
grep -qE '^## `--dry-run` Manifest Shape' "$DOC" || {
  echo "FAIL: --dry-run Manifest Shape section missing" >&2; exit 1
}
grep -qF 'partial: P04' "$DOC" || {
  echo "FAIL: partial-completion sentinel absent (expected HTML comment referencing P04)" >&2; exit 1
}

# references/README.md references the new doc.
if [ -f "$IDX" ]; then
  grep -qF 'spec-management.md' "$IDX" || {
    echo "FAIL: references/README.md missing entry for spec-management.md" >&2; exit 1
  }
fi

echo "PASS: references/spec-management.md shape verified"
exit 0
```

Make both executable.

## Must-Haves

- `tests/test-specify-shape.sh` exists, is executable, exits 0 end-to-end
- The fixture test asserts: section-heading byte-match against `tests/fixtures/m014-p01/expected-section-headings.txt` (normalized for `{{placeholder}}` / populated-slug diffs); `scripts/verify/spec-shape-lint.sh` structural PASS; `scripts/knowledge/detect-spec-shape.sh` reports `shape=speckit`
- The fixture test exercises both `--dry-run` and live scaffold paths
- `references/spec-management.md` exists with Section Contract, Dual-Write Marker Convention, `--dry-run` Manifest Shape sections, and the `partial: P04` HTML comment sentinel
- `references/README.md` gains an entry for `spec-management.md`; all other references/README.md bytes preserved
- `scripts/verify/m014-p01-specify-shape-test.sh` and `scripts/verify/m014-p01-spec-management-reference.sh` exist, are executable, exit 0
- Both new shell scripts are Bash 3.2 compatible and pass `scripts/verify/anti-pattern-lint.sh`

## Verification

```
bash scripts/verify/m014-p01-specify-shape-test.sh
```

Expected: `PASS: tests/test-specify-shape.sh`, exit 0.

```
bash scripts/verify/m014-p01-spec-management-reference.sh
```

Expected: `PASS: references/spec-management.md shape verified`, exit 0.

```
bash scripts/verify/anti-pattern-lint.sh --fixture tests/test-specify-shape.sh
```

Expected: exit 0.

## Inputs

### From Previous Tasks

- `templates/spec-template.md` (from T01) — ground truth for heading extraction.
- `tests/fixtures/m014-p01/expected-section-headings.txt` (from T01) — expected heading list.
- `tests/fixtures/m014-p01/specify-fixture-prose.txt` (from T01) — fixture description.
- `scripts/verify/spec-shape-lint.sh` (from T02) — structural verifier.
- `scripts/specify/specify.sh` (from T05) — system under test.

### From Disk (Pre-existing)

- `scripts/knowledge/detect-spec-shape.sh` (M011) — SC-2 I/O-contract asserter; emits `shape=speckit\n` on stdout.
- `references/README.md` — references index; gains one new entry.
- `scripts/verify/anti-pattern-lint.sh` — lint compliance verifier.

## Constraints

- The heading byte-match is normalized for the `{{feature_title}}` → `<actual-title>` substitution that the scaffolder performs. Use `__PLACEHOLDER__` normalization on both sides before `diff` (see verbatim body Step 1 for the pattern).
- `tests/test-specify-shape.sh` must be hermetic — it copies all required scripts/templates into a scratch temp dir and invokes them there; no modification of the repo-root filesystem.
- `references/spec-management.md` is **partial** — it must carry the `<!-- partial: P04 completes with pressure-test + decomposition sections -->` HTML comment so downstream readers know it is incomplete.
- `references/README.md` additions are byte-surgical — the rest of the file is preserved.
- Bash 3.2 compatible; passes `scripts/verify/anti-pattern-lint.sh`.

## Expected Output

Files committed:

1. `tests/test-specify-shape.sh` — FR-18 byte-compat fixture (~140 lines, executable)
2. `references/spec-management.md` — SC-11 partial reference doc (~90 lines)
3. `references/README.md` — modify (add one line referencing new doc)
4. `scripts/verify/m014-p01-specify-shape-test.sh` — shape-test gate (~15 lines, executable)
5. `scripts/verify/m014-p01-spec-management-reference.sh` — reference-doc gate (~35 lines, executable)

Both gate verifiers exit 0.
