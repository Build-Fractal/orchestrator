---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P03"
milestone: "M020"
name: "schema-authority lint (scripts/verify/knowledge-schema-lint.sh) — FR-9 + SC-8"
depends_on: []
---

## Prerequisites

- P01: [`knowledge/conventions/MEM031.md`](../../../../../knowledge/conventions/MEM031.md) documents the closed enum `{candidate, graduated, archived}` plus the FR-7 `decision_history:` and FR-3 `archived_into:` companion-field shapes.
- P01: [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) D024 authorizes the `status:` closed-enum field as the load-bearing M020 schema-evolution row.
- P03 phase plan authorizes `decision_history:` and `archived_into:` as additional M020-authorized companion fields (per the M020 ROADMAP cross-cutting "Schema authority enforcement" concern).
- Live `knowledge/**/MEM*.md` tree is the canonical baseline — the lint must exit 0 against it (no false positives on existing entries).

## Description

Create `scripts/verify/knowledge-schema-lint.sh` — the FR-9 + SC-8 enforcement gate. The lint scans every `knowledge/**/MEM*.md` (excluding `archive/`) and emits a non-zero exit on any of:

1. **Unauthorized field**: a frontmatter key that is not in the M020-authorized field set (see Authorized Field Set below). Diagnostic: `FAIL: unauthorized-field file=<path> field=<name>`.
2. **Vocabulary drift**: a `status:` value not in the MEM031 closed enum `{candidate, graduated, archived}`. Diagnostic: `FAIL: vocabulary-drift file=<path> field=status value=<value> allowed={candidate,graduated,archived}`.
3. **Malformed frontmatter delimiters**: missing leading `---` or trailing `---` block in an `MEM*.md` file. Diagnostic: `FAIL: malformed-frontmatter file=<path>`.

The lint exits 0 with a `PASS: scanned <N> entries; 0 violations` line on a clean tree. It exits 1 with one or more `FAIL:` lines on violations.

The lint takes an optional `--root <dir>` argument (default `.`) so it can be exercised against fixture trees. With no argument, it walks `<root>/knowledge/**/MEM*.md`.

### Authorized Field Set (M020-authorized)

The lint's authorized-field allowlist:

```
id
scope_tags
category
confidence
created_at
last_verified
hit_count
source_unit
source_type
supersedes
superseded_by
relates_to
content_hash
status
decision_history
archived_into
topic
tags
```

Rationale: `id..content_hash` are the pre-M020 baseline (per existing entry headers across the live tree). `status, decision_history, archived_into` are the M020 schema-evolution additions per D024 + the P03 phase plan. `topic, tags` are referenced by FR-2 / P02 query semantics (already implicitly used) — codifying them in the authorized set prevents false-positives against entries that adopt them.

The list is hardcoded in the lint script. If a future milestone needs to extend the schema, the handshake is: D-row in [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) -> append to MEM031 -> append to this lint's authorized list. Per the M020 ROADMAP cross-cutting concern.

Out of scope:
- Schema-evolution migration. The lint does NOT auto-fix violations — it only reports them.
- Cross-entry consistency (e.g. `archived_into` pointing at a non-existent canonical id). That's a richer verifier and lands in a future milestone if needed.
- Live-tree mutation. The lint is read-only.

## Steps

### Step 1: Create `scripts/verify/knowledge-schema-lint.sh`

Path: `/Users/brettkellgren/Sites/orchestrator/scripts/verify/knowledge-schema-lint.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/knowledge-schema-lint.sh — FR-9 schema-authority enforcement
# (SC-8). Scans knowledge/**/MEM*.md (excluding archive/) for:
#
#   1. Unauthorized frontmatter fields (additions outside the M020-authorized
#      set). Source of truth: knowledge/conventions/MEM031.md + the authorized
#      field allowlist embedded below (extend via D-row + MEM031 + this list).
#
#   2. Vocabulary drift on status: (closed enum {candidate, graduated, archived}).
#
#   3. Malformed frontmatter (missing leading or trailing `---`).
#
# Exit 0 + PASS line on a clean tree; exit 1 with FAIL lines on violations.
#
# Usage:
#   knowledge-schema-lint.sh [--root <dir>]
#       --root: directory containing knowledge/. Default: $(pwd).
#
# Read-only. No file mutations. Bash 3.2 compatible. AD-19 single-script-file
# shape. MEM001 prefixed-output conventions.

set -u

ROOT="."
while [ $# -gt 0 ]; do
  case "$1" in
    --root)
      [ $# -lt 2 ] && { echo "FAIL: --root requires a value" >&2; exit 1; }
      ROOT="$2"; shift 2 ;;
    --help|-h)
      cat >&2 <<'EOF'
Usage: knowledge-schema-lint.sh [--root <dir>]
Scans <root>/knowledge/**/MEM*.md (excluding archive/) for unauthorized
frontmatter fields, vocabulary drift on status, and malformed frontmatter.
EOF
      exit 0 ;;
    *)
      echo "FAIL: unknown argument: $1" >&2
      exit 1 ;;
  esac
done

KNOWLEDGE_DIR="$ROOT/knowledge"
if [ ! -d "$KNOWLEDGE_DIR" ]; then
  echo "FAIL: knowledge directory not found at $KNOWLEDGE_DIR"
  exit 1
fi

# --- Authorized field set (extend via D-row + MEM031 update + this list) ---
AUTHORIZED_FIELDS="id
scope_tags
category
confidence
created_at
last_verified
hit_count
source_unit
source_type
supersedes
superseded_by
relates_to
content_hash
status
decision_history
archived_into
topic
tags"

# --- Closed-enum vocabulary for status (MEM031) ---
STATUS_ENUM="candidate graduated archived"

violations=0
scanned=0

# Walk every knowledge/**/MEM*.md outside archive/.
while IFS= read -r file; do
  scanned=$(( scanned + 1 ))

  # --- 1. Frontmatter delimiter sanity ---
  first_line="$(head -n 1 "$file")"
  if [ "$first_line" != "---" ]; then
    echo "FAIL: malformed-frontmatter file=$file reason=missing-leading-delimiter"
    violations=$(( violations + 1 ))
    continue
  fi

  # Find the line number of the SECOND `---` (closing fence).
  closing_line="$(awk '/^---$/{n++; if (n==2){print NR; exit}}' "$file")"
  if [ -z "$closing_line" ]; then
    echo "FAIL: malformed-frontmatter file=$file reason=missing-closing-delimiter"
    violations=$(( violations + 1 ))
    continue
  fi

  # --- 2. Extract top-level frontmatter keys (lines like `key:` or `key: value`,
  # ignoring nested keys that begin with whitespace). ---
  keys="$(awk '
    NR == 1 { next }
    /^---$/ { exit }
    /^[A-Za-z_][A-Za-z0-9_]*:/ {
      sub(/:.*$/, "")
      print
    }
  ' "$file")"

  # --- 3. Check each key against the authorized set ---
  while IFS= read -r key; do
    [ -z "$key" ] && continue
    found=0
    while IFS= read -r authorized; do
      [ -z "$authorized" ] && continue
      if [ "$key" = "$authorized" ]; then
        found=1
        break
      fi
    done <<EOF
$AUTHORIZED_FIELDS
EOF
    if [ "$found" -eq 0 ]; then
      echo "FAIL: unauthorized-field file=$file field=$key"
      violations=$(( violations + 1 ))
    fi
  done <<EOF
$keys
EOF

  # --- 4. Check status vocabulary if present ---
  status_val="$(awk '
    /^---$/ { n++; if (n>=2) exit; next }
    n==1 && /^status:[[:space:]]/ {
      sub(/^status:[[:space:]]*/, "")
      sub(/[[:space:]]+$/, "")
      sub(/^"/, ""); sub(/"$/, "")
      print
      exit
    }
  ' "$file")"

  if [ -n "$status_val" ]; then
    found=0
    for allowed in $STATUS_ENUM; do
      if [ "$status_val" = "$allowed" ]; then
        found=1
        break
      fi
    done
    if [ "$found" -eq 0 ]; then
      echo "FAIL: vocabulary-drift file=$file field=status value=$status_val allowed={candidate,graduated,archived}"
      violations=$(( violations + 1 ))
    fi
  fi
done < <(find "$KNOWLEDGE_DIR" -type f -name 'MEM*.md' -not -path '*/archive/*' | sort)

if [ "$violations" -gt 0 ]; then
  echo "FAIL: scanned $scanned entries; $violations violations"
  exit 1
fi

echo "PASS: scanned $scanned entries; 0 violations"
exit 0
```

`chmod +x scripts/verify/knowledge-schema-lint.sh`.

**AD-19 review of the script body**: the inline `< <(find ...)` process substitution lives INSIDE the lint script body, not on a Check line. The Check lines in this plan are all single `bash <script>` invocations. The harness shape-guard inspects bash invocations made directly through the tool harness, not the contents of script files. (P01 + P02 verifiers use the same pattern.)

### Step 2: Create `scripts/verify/m020-p03-schema-lint-contract.sh`

Path: `/Users/brettkellgren/Sites/orchestrator/scripts/verify/m020-p03-schema-lint-contract.sh`

```bash
#!/usr/bin/env bash
# m020-p03-schema-lint-contract.sh — assert the schema-authority lint:
#   1. Exits 0 against the live knowledge/**/MEM*.md tree.
#   2. Exits non-zero against a fixture introducing an unauthorized field.
# Bash 3.2 safe. AD-19 single-script-file shape.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LINT="$ROOT/scripts/verify/knowledge-schema-lint.sh"

if [ ! -x "$LINT" ]; then
  echo "FAIL: knowledge-schema-lint.sh missing or not executable at $LINT"
  exit 1
fi

# --- Case 1: live tree must pass ---
if ! bash "$LINT" --root "$ROOT" >/dev/null 2>&1; then
  out="$(bash "$LINT" --root "$ROOT" 2>&1 || true)"
  echo "FAIL: schema-lint failed against the live knowledge tree:"
  echo "$out"
  exit 1
fi

# --- Case 2: unauthorized-field fixture must fail ---
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns"

cat >"$tmpdir/knowledge/patterns/MEM800.md" <<'EOF'
---
id: MEM800
status: candidate
unauthorized_field: "this should fail the lint"
last_verified: 2026-04-25
---

# MEM800: unauthorized-field fixture
EOF

set +e
out2="$(bash "$LINT" --root "$tmpdir" 2>&1)"
rc2=$?
set -e

if [ "$rc2" -eq 0 ]; then
  echo "FAIL: schema-lint accepted unauthorized field. Output: $out2"
  exit 1
fi

case "$out2" in
  *"unauthorized-field"*"unauthorized_field"*) ;;
  *)
    echo "FAIL: schema-lint diagnostic missing 'unauthorized-field' for the offending field. Got: $out2"
    exit 1 ;;
esac

echo "PASS: schema-lint accepts live tree + rejects unauthorized field"
exit 0
```

`chmod +x` the script.

### Step 3: Create `scripts/verify/m020-p03-schema-lint-vocabulary-drift.sh`

Path: `/Users/brettkellgren/Sites/orchestrator/scripts/verify/m020-p03-schema-lint-vocabulary-drift.sh`

```bash
#!/usr/bin/env bash
# m020-p03-schema-lint-vocabulary-drift.sh — assert the schema-authority lint
# rejects status: values outside the MEM031 closed enum.
# Bash 3.2 safe. AD-19 single-script-file shape.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LINT="$ROOT/scripts/verify/knowledge-schema-lint.sh"

if [ ! -x "$LINT" ]; then
  echo "FAIL: knowledge-schema-lint.sh missing or not executable at $LINT"
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns"

cat >"$tmpdir/knowledge/patterns/MEM801.md" <<'EOF'
---
id: MEM801
status: deprecated
last_verified: 2026-04-25
---

# MEM801: vocabulary-drift fixture
EOF

set +e
out="$(bash "$LINT" --root "$tmpdir" 2>&1)"
rc=$?
set -e

if [ "$rc" -eq 0 ]; then
  echo "FAIL: schema-lint accepted status=deprecated. Output: $out"
  exit 1
fi

case "$out" in
  *"vocabulary-drift"*"deprecated"*) ;;
  *)
    echo "FAIL: schema-lint diagnostic missing 'vocabulary-drift' + offending value. Got: $out"
    exit 1 ;;
esac

# Also assert each canonical status value passes (no false positive for valid enum).
for valid in candidate graduated archived; do
  cat >"$tmpdir/knowledge/patterns/MEM801.md" <<EOF
---
id: MEM801
status: ${valid}
last_verified: 2026-04-25
---

# MEM801: ${valid} fixture
EOF
  if ! bash "$LINT" --root "$tmpdir" >/dev/null 2>&1; then
    echo "FAIL: schema-lint rejected valid status='$valid'"
    exit 1
  fi
done

echo "PASS: schema-lint rejects vocabulary drift, accepts every valid enum value"
exit 0
```

`chmod +x` the script.

## Must-Haves

- `scripts/verify/knowledge-schema-lint.sh` exists, is executable, and exits 0 against the live `knowledge/**/MEM*.md` tree.
- The lint exits non-zero with `unauthorized-field` diagnostic on a fixture introducing a frontmatter key outside the authorized set.
- The lint exits non-zero with `vocabulary-drift` diagnostic on a fixture with `status:` outside the MEM031 closed enum.
- The lint exits non-zero with `malformed-frontmatter` diagnostic on a fixture missing leading or trailing `---`.
- The lint accepts `--root <dir>` so it can be exercised against fixture trees without polluting the live tree.
- Bash 3.2 + AD-19 + MEM001 conventions throughout.
- The two T03 verifiers (`m020-p03-schema-lint-contract.sh` + `m020-p03-schema-lint-vocabulary-drift.sh`) exist, are executable, and exit 0 with `PASS:` lines.

## Verification

```
bash scripts/verify/m020-p03-schema-lint-contract.sh
bash scripts/verify/m020-p03-schema-lint-vocabulary-drift.sh
bash scripts/verify/knowledge-schema-lint.sh
```

The first two are the per-task contract verifiers; the third is the lint itself running against the live tree (must exit 0).

## Inputs

### From Previous Tasks

- [`knowledge/conventions/MEM031.md`](../../../../../knowledge/conventions/MEM031.md) (P01) — documents the closed enum `{candidate, graduated, archived}`. The lint embeds the enum directly (`STATUS_ENUM="candidate graduated archived"`) and relies on MEM031 as the human-facing source of truth.
- [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) D024 (P01) — authorizing decision for the `status:` field. The lint's authorized field set is the canonical encoding of D024 + the P03 archive-companion-field schema-evolution note.

### From Disk (Pre-existing)

- Live `knowledge/**/MEM*.md` tree — the lint MUST pass against the current tree (no false positives on existing entries). The authorized field set was derived by enumerating actual frontmatter keys across `knowledge/patterns/`, `knowledge/conventions/`, `knowledge/lessons/`.

## Constraints

- **AD-19 / MEM001**: every Check command in this plan is a single-script-file invocation. The lint internally uses pipes and process substitution, but only inside the script body — not on Check lines.
- **Bash 3.2**: no associative arrays, no `mapfile`. The authorized-field allowlist is a newline-separated string; iteration uses `while read` against a heredoc.
- **CON-1 / FR-8 (read-only)**: the lint never writes to `knowledge/**`. It is callable from any context, including dispatches, without violating the dispatch-isolation invariant.
- **CON-4 (Surgical Precision)**: T03 creates new files only — no pre-existing helper or script is modified.
- **Principle XIV (No Speculative Complexity)**: the lint is structural only — no cross-entry consistency checks, no graph-walk, no archive-pointer validation. If those become valuable, they ship as separate verifiers under future D-rows.
- **FR-9 (schema authority)**: the lint IS the SC-8 enforcement gate. It is the first-class verifier the M020 ROADMAP cross-cutting concern names by path.

## Expected Output

After this task:

1. `scripts/verify/knowledge-schema-lint.sh` exists, is executable, and exits 0 against the live tree.
2. `scripts/verify/m020-p03-schema-lint-contract.sh` exists, is executable, and exits 0.
3. `scripts/verify/m020-p03-schema-lint-vocabulary-drift.sh` exists, is executable, and exits 0.
4. `git status knowledge/` is clean (T03 verifiers use tempdirs; live tree never touched).

**Done when**: all three commands print `PASS:` and exit 0; `git status knowledge/` is empty.
