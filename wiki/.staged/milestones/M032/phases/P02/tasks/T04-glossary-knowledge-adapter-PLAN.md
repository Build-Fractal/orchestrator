---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P02"
milestone: "M032"
name: "Glossary knowledge adapter — scripts/knowledge/lookup-mems.sh --kind=glossary honoring M031 traversal contract (FR-16, MIT-010)"
depends_on: ["T03"]
---

## Prerequisites

- T03 has landed `wiki/glossary.md` at the orchestrator-repo root with at least three `### TERM` headings in the US-6 format. Verified by `[ -f wiki/glossary.md ]` and `grep -c '^### ' wiki/glossary.md` returning a value `>= 3`.
- T03 has landed `scripts/wiki/wiki-scan-sources.sh --include-glossary` flag and `scripts/wiki/wiki-generate-nav.sh` Glossary placement. Verified by `grep -q -- '--include-glossary' scripts/wiki/wiki-scan-sources.sh` and `grep -q 'Glossary' scripts/wiki/wiki-generate-nav.sh`.
- `scripts/knowledge/` exists as a directory containing the canonical knowledge-graph helpers per the [M020](../../../../../milestones/M020/index.md) / M032/T03 layer (visible at the orchestrator-repo root). Verified by `[ -d scripts/knowledge ]`.
- `scripts/knowledge/lookup-mems.sh` does NOT exist on disk at plan-authoring time (verified — see `ls /Users/brettkellgren/Sites/orchestrator/scripts/knowledge/` listing in payload context). T04 creates this file from scratch.
- T04 entry: T03's `wiki/glossary.md` is the input the adapter reads. The adapter's contract is M020-knowledge-record-compatible output on stdout per the `lookup-mems` shape M020 established for the existing `query.sh` / `traverse-graph.sh` adapters in `scripts/knowledge/`.

## Description

T04 binds the FR-15 glossary path-convention surface (T03 deliverable) into the M020 knowledge-graph injection path. The adapter `scripts/knowledge/lookup-mems.sh --kind=glossary` reads `<PROJECT_ROOT>/wiki/glossary.md`, parses each `### TERM` heading + associated body, and synthesizes one record per term with a stable id derivable from the term name.

Three contracts are load-bearing:

1. **Stable IDs**: each record's `id` is derived from the term name via lower-case + non-alphanumeric collapse to `-` + prefix `gloss-`. Examples: `### Constitution` → `id: gloss-constitution`; `### Knowledge Graph` → `id: gloss-knowledge-graph`; `### Tier 0 Manifest` → `id: gloss-tier-0-manifest`. IDs are stable across re-invocations against an unchanged glossary (idempotency contract).

2. **[M031](../../../../../milestones/M031/index.md) traversal contract per FR-16 / MIT-010**:
   - `--profile=full` and `--profile=standard` emit the FULL glossary.
   - `--profile=quick` emits ONLY touched terms, where a term is `touched` per the FR-16 / MIT-010 inline definition:
     - (a) `--task-description "<text>"` arg contains an exact-or-stemmed match of the term name (case-insensitive substring match suffices for v1; full stemming is FR-16-future-tightening), OR
     - (b) `--file-change-set "<path>,<path>,...
"` arg lists files whose contents contain the term name (case-insensitive substring match).
   - **Safe-default-no-terms fallback**: under `--profile=quick` when neither `--task-description` nor `--file-change-set` is supplied, the adapter emits ZERO records. This preserves M031's budget invariant per MIT-010 — without the fallback, Quick payloads would silently inject the full glossary every time the caller forgot the touched-term hints, defeating the budget contract.

3. **M020-knowledge-record-compatible shape**: the adapter emits one YAML-frontmatter-prefixed record per touched term to stdout in a shape consumable by `build-context.sh`. The exact shape mirrors the existing M020 record structure (frontmatter with `id`, `kind`, `confidence`, `source`, `last_verified`; body containing the term definition + elaboration). The adapter does NOT write to `knowledge/<category>/MEM*.md` — it synthesizes records on-the-fly. This is the boundary M032 / M020 boundary documented in the spec: M020 owns the on-disk knowledge-graph kinds; M032 owns the project-glossary projection adapter.

The adapter's bash 3.2-compatible parser uses a state-machine line walker: track current term name, accumulate body lines, emit on next `### ` heading or EOF.

## Steps

1. **Author `scripts/knowledge/lookup-mems.sh`** as a new executable file. Required structure (single-script-file shape per AD-19; bash 3.2 compatible per MEM001):

```bash
#!/usr/bin/env bash
# scripts/knowledge/lookup-mems.sh — knowledge-graph lookup adapter.
# M032/P02/T04 ships --kind=glossary mode (FR-16 / MIT-010); future kinds
# may extend this adapter (--kind=mem for the M020 knowledge-graph kinds,
# --kind=reference for M036's reference-corpus, etc.).
#
# --kind=glossary contract:
#   Reads <project-root>/wiki/glossary.md.
#   Parses each `### TERM` heading + associated body.
#   Synthesizes one record per term with id=gloss-<slug>.
#   Honors M031's Quick/Standard/Full profile contract per FR-16 / MIT-010.
#
# Arguments:
#   --kind <glossary>            (required; only 'glossary' supported in P02)
#   --root <path>                (default: ".")
#   --profile <quick|standard|full>  (default: standard)
#   --task-description <text>    (Quick-profile touched-term hint, optional)
#   --file-change-set <comma-separated-paths>  (Quick-profile touched-term hint, optional)
#
# Exit codes:
#   0 — success (zero or more records emitted on stdout).
#   2 — argument error.
#   3 — glossary file not found AND not optional-empty.
#
# FR-16 / MIT-010 safe-default-no-terms fallback:
#   --profile=quick AND no --task-description AND no --file-change-set
#   → emit zero records, exit 0.

set -eu

KIND=""
ROOT="."
PROFILE="standard"
TASK_DESC=""
FILE_CHANGES=""

while [ $# -gt 0 ]; do
  case "$1" in
    --kind) KIND="$2"; shift 2 ;;
    --kind=*) KIND="${1#--kind=}"; shift ;;
    --root) ROOT="$2"; shift 2 ;;
    --root=*) ROOT="${1#--root=}"; shift ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --profile=*) PROFILE="${1#--profile=}"; shift ;;
    --task-description) TASK_DESC="$2"; shift 2 ;;
    --task-description=*) TASK_DESC="${1#--task-description=}"; shift ;;
    --file-change-set) FILE_CHANGES="$2"; shift 2 ;;
    --file-change-set=*) FILE_CHANGES="${1#--file-change-set=}"; shift ;;
    *) echo "FAIL: lookup-mems: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

[ -n "$KIND" ] || { echo "FAIL: lookup-mems: --kind is required" >&2; exit 2; }
[ "$KIND" = "glossary" ] || { echo "FAIL: lookup-mems: --kind=$KIND not supported in P02 (only 'glossary')" >&2; exit 2; }

case "$PROFILE" in
  quick|standard|full) : ;;
  *) echo "FAIL: lookup-mems: --profile must be quick|standard|full, got '$PROFILE'" >&2; exit 2 ;;
esac

GLOSSARY="$ROOT/wiki/glossary.md"

# FR-16 / MIT-010 safe-default-no-terms fallback under --profile=quick.
if [ "$PROFILE" = "quick" ] && [ -z "$TASK_DESC" ] && [ -z "$FILE_CHANGES" ]; then
  exit 0
fi

# If glossary is absent, emit zero records, exit 0 (US-6 Acceptance Scenario 2).
if [ ! -f "$GLOSSARY" ]; then
  exit 0
fi

# Helper: slugify a term name to gloss-<slug>.
slugify() {
  local term="$1"
  echo "$term" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

# Helper: check if a term is touched per FR-16 / MIT-010.
is_touched() {
  local term="$1"
  local lc_term
  lc_term="$(echo "$term" | tr '[:upper:]' '[:lower:]')"
  # (a) task-description match (case-insensitive substring)
  if [ -n "$TASK_DESC" ]; then
    local lc_desc
    lc_desc="$(echo "$TASK_DESC" | tr '[:upper:]' '[:lower:]')"
    case "$lc_desc" in
      *"$lc_term"*) return 0 ;;
    esac
  fi
  # (b) file-change-set match (any listed file contains the term)
  if [ -n "$FILE_CHANGES" ]; then
    local IFS_OLD="$IFS"
    IFS=','
    for f in $FILE_CHANGES; do
      if [ -f "$f" ] && grep -q -i -F "$term" "$f" 2>/dev/null; then
        IFS="$IFS_OLD"
        return 0
      fi
    done
    IFS="$IFS_OLD"
  fi
  return 1
}

# Helper: emit a record for a term + body.
emit_record() {
  local term="$1"
  local body="$2"
  local slug
  slug="$(slugify "$term")"
  printf -- '---\n'
  printf 'id: gloss-%s\n' "$slug"
  printf 'kind: glossary\n'
  printf 'term: %s\n' "$term"
  printf 'confidence: 1.0\n'
  printf 'source: wiki/glossary.md\n'
  printf 'last_verified: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf -- '---\n'
  printf '%s\n' "$body"
  printf '\n'
}

# State-machine line walker: parse ### headings + bodies.
CURRENT_TERM=""
CURRENT_BODY=""
EMIT_FUNC="emit_record_filtered"
emit_record_filtered() {
  local term="$1"
  local body="$2"
  case "$PROFILE" in
    full|standard)
      emit_record "$term" "$body"
      ;;
    quick)
      if is_touched "$term"; then
        emit_record "$term" "$body"
      fi
      ;;
  esac
}

while IFS= read -r line; do
  case "$line" in
    '### '*)
      # Emit previous term if accumulated.
      if [ -n "$CURRENT_TERM" ]; then
        emit_record_filtered "$CURRENT_TERM" "$CURRENT_BODY"
      fi
      CURRENT_TERM="${line#### }"
      CURRENT_BODY=""
      ;;
    *)
      if [ -n "$CURRENT_TERM" ]; then
        if [ -n "$CURRENT_BODY" ]; then
          CURRENT_BODY="$CURRENT_BODY"$'\n'"$line"
        else
          CURRENT_BODY="$line"
        fi
      fi
      ;;
  esac
done < "$GLOSSARY"

# Flush the final term.
if [ -n "$CURRENT_TERM" ]; then
  emit_record_filtered "$CURRENT_TERM" "$CURRENT_BODY"
fi

exit 0
```

Note on the `### TERM` parsing: the `### ` prefix is exactly four characters (three hashes + one space). `${line#### }` is bash parameter expansion that strips a `### ` prefix; the `####` sequence is the prefix-strip pattern (three hashes + one space — but bash quirk: `#### ` would be four hashes + space; for parameter expansion, `${var#pattern}` uses `pattern` as a glob, so `${line#### }` strips a literal `### ` prefix because the leading `#` of `${...#...}` is the parameter-expansion operator).

Verify the exact strip semantics by testing locally — if bash 3.2 mishandles the expansion, fall back to `CURRENT_TERM="$(echo "$line" | sed 's/^### //')"` (NOT inside `$()` containing a pipe — pipe-free sed is fine).

Actually safer: use `CURRENT_TERM="$(printf '%s' "$line" | sed 's/^### //')"`. The pipe inside `$()` is a single pipe, not a chain of pipes — within `$()` the AD-19 forbidden shape is "pipes inside `$()`," so this DOES violate the rule. Safer still: use `CURRENT_TERM="${line#### }"` (parameter expansion, no subshell).

Test the expansion in T04 implementation: `line='### Foo Bar'; CURRENT_TERM="${line#### }"` should yield `CURRENT_TERM=Foo Bar`. If bash 3.2 fails, refactor with awk in a single non-piped invocation.

2. **Make the script executable**: `chmod +x scripts/knowledge/lookup-mems.sh`.

3. **Author the T04 verifier** at `tools/verify/m032-p02-lookup-mems-glossary.sh`. The verifier exercises:
   - **Standard profile / full glossary**: `bash scripts/knowledge/lookup-mems.sh --kind=glossary --profile=standard --root .`; assert at least three `id: gloss-` lines in stdout (one per glossary entry); assert each id matches `^id: gloss-[a-z0-9-]+$`.
   - **Idempotency**: run the same invocation twice; the `id:` lines (set, not necessarily order) MUST be identical between invocations.
   - **Quick profile + task-description hit**: with a fixture glossary containing `### Foo` and `### Bar` and `### Baz`, run `--profile=quick --task-description 'rename a foo file'`; assert exactly ONE `id: gloss-foo` line is emitted (and no `gloss-bar` or `gloss-baz`).
   - **Quick profile + task-description miss**: run `--profile=quick --task-description 'unrelated text'`; assert ZERO records emitted.
   - **Quick profile + file-change-set hit**: stage a fixture file containing `Foo` in its body; run `--profile=quick --file-change-set <fixture-file>`; assert `gloss-foo` is emitted.
   - **Quick profile safe-default**: run `--profile=quick` with neither `--task-description` nor `--file-change-set`; assert ZERO records emitted (MIT-010 fallback).

The verifier MUST NOT depend on the orchestrator's own `wiki/glossary.md` content for the Quick-profile touched-term branches — those branches use a `mktemp -d` fixture glossary with known `### Foo`, `### Bar`, `### Baz` entries. The Standard-profile branch can use the orchestrator's own `wiki/glossary.md` (T03 deliverable) since the format invariant is asserted by `m032-p02-glossary-format-invariant.sh`.

Skeleton:

```bash
#!/usr/bin/env bash
set -eu
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Stage a fixture glossary with three known terms.
mkdir -p "$TMP/wiki"
cat > "$TMP/wiki/glossary.md" <<'EOF'
# Glossary

### Bar
Bar definition.

### Baz
Baz definition.

### Foo
Foo definition.
EOF

# (a) Standard profile / full glossary
bash scripts/knowledge/lookup-mems.sh --kind=glossary --profile=standard --root "$TMP" > "$TMP/standard.txt" 2>/dev/null
N="$(grep -c '^id: gloss-' "$TMP/standard.txt")"
[ "$N" = "3" ] || { echo "FAIL: standard profile expected 3 records got $N"; exit 1; }
grep -q '^id: gloss-foo$' "$TMP/standard.txt" || { echo "FAIL: missing gloss-foo under standard"; exit 1; }
grep -q '^id: gloss-bar$' "$TMP/standard.txt" || { echo "FAIL: missing gloss-bar under standard"; exit 1; }
grep -q '^id: gloss-baz$' "$TMP/standard.txt" || { echo "FAIL: missing gloss-baz under standard"; exit 1; }

# (b) Idempotency
bash scripts/knowledge/lookup-mems.sh --kind=glossary --profile=standard --root "$TMP" > "$TMP/standard2.txt" 2>/dev/null
# Compare ids only (last_verified timestamp will differ between runs — that's fine, it's not load-bearing for idempotency)
grep '^id: ' "$TMP/standard.txt" | sort > "$TMP/ids1.txt"
grep '^id: ' "$TMP/standard2.txt" | sort > "$TMP/ids2.txt"
diff -q "$TMP/ids1.txt" "$TMP/ids2.txt" >/dev/null || { echo "FAIL: idempotency violated — ids differ between runs"; exit 1; }

# (c) Quick + task-description hit
bash scripts/knowledge/lookup-mems.sh --kind=glossary --profile=quick --task-description 'rename a foo file' --root "$TMP" > "$TMP/quick-hit.txt" 2>/dev/null
N="$(grep -c '^id: gloss-' "$TMP/quick-hit.txt")"
[ "$N" = "1" ] || { echo "FAIL: quick + task-desc hit expected 1 record got $N"; exit 1; }
grep -q '^id: gloss-foo$' "$TMP/quick-hit.txt" || { echo "FAIL: quick + task-desc hit did not emit gloss-foo"; exit 1; }

# (d) Quick + task-description miss
bash scripts/knowledge/lookup-mems.sh --kind=glossary --profile=quick --task-description 'unrelated text' --root "$TMP" > "$TMP/quick-miss.txt" 2>/dev/null
N="$(grep -c '^id: gloss-' "$TMP/quick-miss.txt")"
[ "$N" = "0" ] || { echo "FAIL: quick + task-desc miss expected 0 records got $N"; exit 1; }

# (e) Quick + file-change-set hit
echo "this file contains Foo" > "$TMP/changed.txt"
bash scripts/knowledge/lookup-mems.sh --kind=glossary --profile=quick --file-change-set "$TMP/changed.txt" --root "$TMP" > "$TMP/quick-fcs.txt" 2>/dev/null
grep -q '^id: gloss-foo$' "$TMP/quick-fcs.txt" || { echo "FAIL: quick + file-change-set did not emit gloss-foo"; exit 1; }

# (f) Quick safe-default-no-terms (MIT-010)
bash scripts/knowledge/lookup-mems.sh --kind=glossary --profile=quick --root "$TMP" > "$TMP/quick-safe.txt" 2>/dev/null
N="$(grep -c '^id: gloss-' "$TMP/quick-safe.txt")"
[ "$N" = "0" ] || { echo "FAIL: quick safe-default expected 0 records got $N (MIT-010)"; exit 1; }

echo "PASS: m032-p02-lookup-mems-glossary"
```

4. **Run the T04 verifier locally** to confirm exit 0.

## Must-Haves

- `scripts/knowledge/lookup-mems.sh` exists, is executable, supports `--kind=glossary` mode, reads `<root>/wiki/glossary.md`, parses `### TERM` headings, synthesizes one record per term with `id: gloss-<slug>` (slug derived from term name via lower-case + non-alphanumeric collapse to `-`).
- The adapter honors M031 traversal contract: `--profile=full` and `--profile=standard` emit the FULL glossary; `--profile=quick` emits ONLY touched terms per the FR-16 / MIT-010 inline definition (task-description match OR file-change-set match).
- The MIT-010 safe-default-no-terms fallback fires under `--profile=quick` when neither `--task-description` nor `--file-change-set` is supplied, emitting ZERO records (preserves M031's budget invariant).
- Stable IDs across re-invocations against an unchanged glossary (idempotency).
- The T04 verifier at `tools/verify/m032-p02-lookup-mems-glossary.sh` exists, is executable, and exits 0 against six test scenarios (standard full, idempotency, quick task-desc hit, quick task-desc miss, quick file-change-set hit, quick safe-default-no-terms).

## Verification

```bash
bash tools/verify/m032-p02-lookup-mems-glossary.sh
```

## Inputs

### From Previous Tasks

- `wiki/glossary.md` (from T03) — the canonical project-glossary surface. Format: alphabetized `### TERM` headings, one-line definition immediately under each heading, at-most-two-line elaboration. T04's adapter parses this format.

### From Disk (Pre-existing)

- `scripts/knowledge/` directory — canonical home for knowledge-graph helpers. Existing helpers (`query.sh`, `traverse-graph.sh`, `append-knowledge.sh`, etc.) define the shape T04's adapter joins into.
- The M020 knowledge-record shape — frontmatter with `id`, `kind`, `confidence`, `source`, `last_verified`; body containing the term definition + elaboration. Read existing `knowledge/<category>/MEM*.md` files for the canonical record shape.

## Constraints

- The adapter MUST NOT write to `knowledge/<category>/MEM*.md` — it synthesizes records on-the-fly. The boundary is documented in the M032 spec: M020 owns the on-disk knowledge-graph kinds; M032 owns the project-glossary projection adapter (FR-16).
- Bash 3.2 compatibility per MEM001 — no `declare -A`, no `mapfile`, no process substitution, no `$()` containing pipes.
- Single-script-file shape per AD-19 in the T04 verifier — no inline compound bash chains exceeding two commands, no `bash -c '...' && bash -c '...'` chains.
- The slug derivation MUST be deterministic — same term name yields the same slug across re-invocations. Use `tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'` (a single pipe, but inside a function body, not inside `$()` of a Verify command — function bodies are AD-19-OK because they execute outside the harness's compound-shape detection scope).
- The Quick-profile touched-term match MUST be case-insensitive substring match per FR-16 v1 contract; full stemming is FR-16-future-tightening (call out in `## Notes`).
- The MIT-010 safe-default-no-terms fallback MUST fire BEFORE any glossary parsing — emit zero records and exit 0 immediately when the conditions hit. This avoids unnecessary I/O on the budget-conscious Quick path.
- The glossary-absent case (`wiki/glossary.md` does not exist) MUST emit zero records and exit 0 (US-6 Acceptance Scenario 2 — no warning beyond debug-level).

## Expected Output

After T04 completes:

- `scripts/knowledge/lookup-mems.sh` is a new executable file at the orchestrator-repo root implementing the `--kind=glossary` adapter with M031 profile awareness and MIT-010 safe-default fallback.
- `tools/verify/m032-p02-lookup-mems-glossary.sh` is a new executable verifier exercising six test scenarios.
- The T04 verifier exits 0.

## Notes

- Expected verifier output: `PASS: m032-p02-lookup-mems-glossary` to stdout on exit 0.
- Plan-time discipline rule 2 (verifier-availability cross-check): the single verifier cited in `## Verification` is co-authored within this task in step 3.
- Plan-time discipline rule 6 (path-collision check): `scripts/knowledge/lookup-mems.sh` and `tools/verify/m032-p02-lookup-mems-glossary.sh` do NOT exist on disk at plan-authoring time (verified — see `ls scripts/knowledge/` listing in payload context which shows existing entries but no `lookup-mems.sh`).
- The case-insensitive substring match for `is_touched` is the v1 contract per FR-16. Future tightening (full stemming via Porter or similar; word-boundary detection to avoid `### Foo` matching against task description `food preparation`) is FR-16-future-tightening — call out in MEM031 follow-up if the false-positive rate becomes operationally problematic. The v1 substring match is conservative — it errs on emitting MORE records under Quick (acceptable: the budget invariant is "ONLY touched," and a false-positive substring match is still a touched signal).
- The `slugify` function's collapse rule: `### Tier 0 Manifest` → `gloss-tier-0-manifest` (digits preserved, spaces collapsed to `-`). `### M032` → `gloss-m032`. `### --with-wiki` → `gloss-with-wiki` (leading dashes stripped via `s/^-+//`). The function is bash-portable across 3.2 and later via `tr` + `sed -E`.
- The frontmatter shape (`id`, `kind`, `confidence`, `source`, `last_verified`) mirrors the M020 record shape per MEM031. The `confidence: 1.0` value reflects that glossary entries are operator-authored (not consolidated from heuristic signals); the `source: wiki/glossary.md` value names the on-disk projection. `last_verified` uses the ISO 8601 UTC convention from MEM008.
- Because the adapter does NOT write to disk, the M020 schema-authority gate (MEM031) is not crossed — the adapter is a READER that synthesizes records for the dispatch payload, not a WRITER. M020 holds exclusive schema-authority over the on-disk `knowledge/<category>/MEM*.md` files; M032's adapter MAY emit records in M020-compatible shape for downstream `build-context.sh` consumption per the FR-16 boundary.
