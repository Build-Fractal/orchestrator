---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P02"
milestone: "M020"
name: "Query surface core (--topic + --state + match rule + ranking + --format ids)"
depends_on: []
---

## Prerequisites

- P01: `knowledge/conventions/MEM031.md` defines the closed enum `{candidate, graduated, archived}` and the FR-10 default (absent → `graduated` on read).
- P01: `scripts/knowledge/lib/frontmatter.sh` exposes `fm_read_status <file>` returning one of `candidate|graduated|archived`. Header carries the operator-invoked guard for the WRITE helpers; the READ helper (`fm_read_status`) is documented as safe from any context including dispatches.
- Pre-existing on disk:
  - `scripts/knowledge/lib/index-utils.sh` (`get_project_root` honors `PROJECT_ROOT` env var per the 4-rule resolver — confirmed in P01 T03 plan deviation note).
  - `scripts/knowledge/lib/detail-utils.sh` (read helpers; not strictly required by T01 but available).
  - The live `knowledge/**/MEM*.md` tree DOES NOT carry `topic:` or `tags[]` frontmatter fields today (verified at P02 plan-time by grepping the tree). T01's matching logic MUST handle absent fields gracefully — an entry with no `topic:` and no `tags[]` simply never matches via either path. T01's contract tests use ephemeral fixture entries that DO carry both fields.

## Description

Create `scripts/knowledge/query.sh` — the dispatch-callable knowledge query surface satisfying FR-2 sub-clauses (a) through (e) plus `--format ids` from sub-clause (f). T02 extends the same file with `--format json` and the no-match diagnostic; do NOT pre-implement T02's surface here (Surgical Precision / CON-4 / Principle XV).

Scope (T01):
- `--topic <X>` (required), `--state <S>` (optional, default `graduated`), `--format ids` (default; treat `--format json` as "not yet supported in T01" by accepting the flag silently and still emitting `ids` — T02 will replace).
- Matching: case-insensitive whole-string equality against frontmatter `topic:` field; OR case-folded membership in `tags[]` list. Per FR-2 sub-clause (b) the topic-keyword index is the case-folded set of `tags[]` values rebuilt lazily on each query (per AD-2). "Lazily" = re-walked from disk on every invocation, no persistent cache (Principle VI).
- State filter: when `--state <S>` is supplied, only entries with that exact `status:` are returned. Default state filter when `--state` is unspecified is `graduated` only. `fm_read_status` already handles the FR-10 default for entries lacking the field.
- Ranking: `topic:`-field exact matches rank above tag-only matches; ties within a tier broken by `last_verified` descending (date string comparison — ISO 8601 sorts lexicographically).
- Output: `--format ids` (default) emits one `entry_id=<ID>` line per match in rank order. No JSON in T01.
- Read-only: NEVER write to `knowledge/**`. The script must not source any helper from `frontmatter.sh` other than `fm_read_status`.
- Bash 3.2 compatible. AD-19 shape compliant. MEM001 prefixed-output conventions.

Out of scope (deferred to T02, T03, T04):
- `--format json` real implementation (T02).
- Empty-result `no-matches` diagnostic field (T02).
- Side-effect-free invariant verifier (T02).
- `dispatch-interface.sh` wrapper (T03).
- Integration test (T04).

## Steps

### Step 1: Create `scripts/knowledge/query.sh`

Path: `/Users/brettkellgren/Sites/spec-kit-orchestrator/scripts/knowledge/query.sh`

Reference implementation (verbatim — mandatory shape):

```bash
#!/usr/bin/env bash
# scripts/knowledge/query.sh — FR-2 dispatch-callable knowledge query surface
#
# Usage: query.sh --topic <X> [--state <S>] [--format ids|json]
#
# FR-2 deterministic semantics:
#   (a) case-insensitive whole-string equality against frontmatter `topic:`
#   (b) topic-keyword index = case-folded set of `tags[]` values, rebuilt
#       lazily on every query (no persistent cache; Principle VI)
#   (c) match: entry's `topic:` equals X (case-insensitive) OR X (case-folded)
#       appears in entry's `tags[]` list
#   (d) state filter: --state <S> returns only that status; default is
#       `graduated` only
#   (e) ranking: topic-field matches > tag-only matches; ties broken by
#       `last_verified` descending
#   (f) output: --format ids (default) emits `entry_id=<ID>` per line; T02
#       extends with --format json
#
# FR-8 / CON-1: read-only. Never writes to knowledge/**. Sources only
# fm_read_status from frontmatter.sh. Schema-authority constraint per
# knowledge/conventions/MEM031.md — read-only consumer of the closed enum.
#
# Bash 3.2 compatible. AD-19 single-script-file shape (no inline compounds).
# MEM001 structured prefixed output.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/index-utils.sh
. "$SCRIPT_DIR/lib/index-utils.sh"
# shellcheck source=lib/frontmatter.sh
. "$SCRIPT_DIR/lib/frontmatter.sh"

usage() {
  cat >&2 <<'EOF'
Usage: query.sh --topic <X> [--state <S>] [--format ids|json]

Resolves a knowledge query against knowledge/**/MEM*.md per FR-2.
Default state filter: graduated. Default format: ids.
Read-only — never writes to knowledge/**.
EOF
  exit 1
}

topic=""
state_filter="graduated"
format="ids"

while [ $# -gt 0 ]; do
  case "$1" in
    --topic)
      [ $# -lt 2 ] && usage
      topic="$2"
      shift 2
      ;;
    --state)
      [ $# -lt 2 ] && usage
      state_filter="$2"
      shift 2
      ;;
    --format)
      [ $# -lt 2 ] && usage
      format="$2"
      shift 2
      ;;
    --help|-h)
      usage
      ;;
    *)
      echo "FAIL: unknown argument: $1" >&2
      usage
      ;;
  esac
done

[ -z "$topic" ] && { echo "FAIL: --topic <X> is required" >&2; usage; }

# Validate format flag (T01 only emits ids; --format json is reserved for T02).
case "$format" in
  ids|json) ;;
  *)
    echo "FAIL: --format must be one of {ids, json}, got: $format" >&2
    exit 1
    ;;
esac

# Validate state filter against the closed enum (MEM031).
case "$state_filter" in
  candidate|graduated|archived) ;;
  *)
    echo "FAIL: --state must be one of {candidate, graduated, archived}, got: $state_filter" >&2
    exit 1
    ;;
esac

PROJECT_ROOT_DIR="$(get_project_root)"
KNOWLEDGE_DIR="$PROJECT_ROOT_DIR/knowledge"

if [ ! -d "$KNOWLEDGE_DIR" ]; then
  # Empty domain — no entries at all. Emit empty result (T02 will add
  # the no-matches diagnostic line; T01 just exits 0 with no output).
  exit 0
fi

# Case-fold the query for matching.
topic_lc="$(printf '%s' "$topic" | tr '[:upper:]' '[:lower:]')"

# Working buffers held in tempfile (Bash 3.2: no associative arrays).
# Format per line:  <rank-tier>\t<last_verified>\t<entry_id>\t<title>\t<status>
# rank-tier: 0 = topic-field hit, 1 = tag-only hit. Sort numeric asc on tier,
# then last_verified desc inside tier (ISO 8601 sorts lexicographically).
buf="$(mktemp -t m020-p02-query.XXXXXX)"
trap 'rm -f "$buf"' EXIT

# Walk all knowledge/**/MEM*.md files. find -type f handles arbitrary depth;
# excluding archive/ (which holds historical material; no current entries).
find "$KNOWLEDGE_DIR" -type f -name 'MEM*.md' -not -path '*/archive/*' \
  | sort \
  | while IFS= read -r file; do
      # Read entry status via the FR-10 default-aware helper.
      status="$(fm_read_status "$file")"
      [ "$status" = "$state_filter" ] || continue

      # Extract entry id from filename (matches MEM###.md convention).
      entry_id="$(basename "$file" .md)"

      # Extract topic field (single-line scalar, optional quotes).
      topic_field="$(awk '
        /^---$/ { n++; if (n>=2) exit; next }
        n==1 && /^topic:[[:space:]]/ {
          sub(/^topic:[[:space:]]*/, "")
          sub(/[[:space:]]+$/, "")
          sub(/^"/, ""); sub(/"$/, "")
          print
          exit
        }
      ' "$file")"
      topic_field_lc="$(printf '%s' "$topic_field" | tr '[:upper:]' '[:lower:]')"

      # Extract tags[] — supports flow style `tags: [a, b, c]` or block style
      # `tags:` followed by `  - a` lines. Emit one tag per line, case-folded.
      tags_lc="$(awk '
        BEGIN { infm=0; intags=0 }
        /^---$/ { infm++; if (infm>=2) exit; next }
        infm==1 && /^tags:[[:space:]]*\[/ {
          line = $0
          sub(/^tags:[[:space:]]*\[/, "", line)
          sub(/\][[:space:]]*$/, "", line)
          n = split(line, a, ",")
          for (i = 1; i <= n; i++) {
            t = a[i]
            sub(/^[[:space:]]+/, "", t); sub(/[[:space:]]+$/, "", t)
            sub(/^"/, "", t); sub(/"$/, "", t)
            if (t != "") print tolower(t)
          }
          intags = 0
          next
        }
        infm==1 && /^tags:[[:space:]]*$/ { intags = 1; next }
        infm==1 && intags == 1 && /^[[:space:]]+-[[:space:]]/ {
          t = $0
          sub(/^[[:space:]]+-[[:space:]]+/, "", t)
          sub(/[[:space:]]+$/, "", t)
          sub(/^"/, "", t); sub(/"$/, "", t)
          if (t != "") print tolower(t)
          next
        }
        infm==1 && intags == 1 && /^[A-Za-z_]/ { intags = 0 }
      ' "$file")"

      # Extract title from first H1 line (`# MEMxxx: Title text`).
      title="$(awk '/^# / { sub(/^# /, ""); print; exit }' "$file")"

      # Extract last_verified for ranking tiebreak (ISO 8601 string).
      last_verified="$(awk '
        /^---$/ { n++; if (n>=2) exit; next }
        n==1 && /^last_verified:[[:space:]]/ {
          sub(/^last_verified:[[:space:]]*/, "")
          sub(/[[:space:]]+$/, "")
          sub(/^"/, ""); sub(/"$/, "")
          print
          exit
        }
      ' "$file")"

      # Determine rank tier.
      tier=""
      if [ -n "$topic_field_lc" ] && [ "$topic_field_lc" = "$topic_lc" ]; then
        tier="0"
      elif printf '%s\n' "$tags_lc" | grep -qx -- "$topic_lc"; then
        tier="1"
      fi
      [ -z "$tier" ] && continue

      # Emit a buffer line. last_verified empty ⇒ default to lowest sort key
      # so tagged-but-undated entries land last within their tier.
      printf '%s\t%s\t%s\t%s\t%s\n' "$tier" "${last_verified:-0000-00-00}" "$entry_id" "$title" "$status" >>"$buf"
    done

# Sort: tier ascending (numeric), last_verified descending (reverse string).
# Bash 3.2 + macOS sort: -k1,1n then -k2,2r.
sorted="$(sort -t '	' -k1,1n -k2,2r "$buf")"

if [ -z "$sorted" ]; then
  # Empty result. T01 exits 0 with no stdout for ids format. T02 will add
  # the explicit `no-matches` diagnostic for both formats.
  exit 0
fi

# T01 emits only ids format. T02 will replace this block with format-aware
# emission. Even if --format json is passed in T01, we currently emit ids;
# T02 closes that gap and the m020-p02-query-format-json.sh verifier (T02
# artifact) is the contract gate.
printf '%s\n' "$sorted" | while IFS=$'\t' read -r _tier _lv id _title _status; do
  printf 'entry_id=%s\n' "$id"
done

exit 0
```

`chmod +x scripts/knowledge/query.sh`.

**AD-19 review of the script body**: the inline pipe inside `find … | sort | while IFS= read -r …` is part of the script body (NOT a verifier `Check:` invocation), so the harness shape-guard does not apply — it only inspects bash invocations made directly through the tool harness. The `Check:` commands in this plan all use single-script-file shape. Same applies to the awk programs: they live inside a script file, not in a `Check:` line.

### Step 2: Create `scripts/verify/m020-p02-query-help.sh`

Path: `/Users/brettkellgren/Sites/spec-kit-orchestrator/scripts/verify/m020-p02-query-help.sh`

```bash
#!/usr/bin/env bash
# m020-p02-query-help.sh — assert query.sh --help enumerates the FR-2 flags.
# Bash 3.2 safe.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/query.sh"

if [ ! -x "$SCRIPT" ]; then
  echo "FAIL: query.sh missing or not executable at $SCRIPT"
  exit 1
fi

out="$(bash "$SCRIPT" --help 2>&1 || true)"

for needle in "--topic" "--state" "--format"; do
  case "$out" in
    *"$needle"*) ;;
    *)
      echo "FAIL: query.sh --help does not mention $needle"
      exit 1
      ;;
  esac
done

echo "PASS: query.sh --help enumerates --topic, --state, --format"
exit 0
```

`chmod +x` the script.

### Step 3: Create `scripts/verify/m020-p02-query-default-state-filter.sh`

Path: `/Users/brettkellgren/Sites/spec-kit-orchestrator/scripts/verify/m020-p02-query-default-state-filter.sh`

```bash
#!/usr/bin/env bash
# m020-p02-query-default-state-filter.sh — assert default state filter is
# `graduated` only (FR-2 sub-clause d). Bash 3.2 safe. AD-19 shape compliant.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/query.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns"

# Three entries on topic "auth": one graduated, one candidate, one archived.
for trip in "MEM700:graduated" "MEM701:candidate" "MEM702:archived"; do
  id="${trip%%:*}"
  st="${trip##*:}"
  cat >"$tmpdir/knowledge/patterns/${id}.md" <<EOF
---
id: ${id}
topic: "auth"
tags: []
last_verified: 2026-04-25
status: ${st}
---

# ${id}: ${st} fixture
EOF
done

export PROJECT_ROOT="$tmpdir"

out="$(bash "$SCRIPT" --topic auth 2>/dev/null)"

case "$out" in
  *"entry_id=MEM700"*) ;;
  *)
    echo "FAIL: graduated entry MEM700 missing from default-filter result. Got: $out"
    exit 1
    ;;
esac

case "$out" in
  *"entry_id=MEM701"*)
    echo "FAIL: candidate entry MEM701 leaked through default state filter. Got: $out"
    exit 1
    ;;
  *) ;;
esac

case "$out" in
  *"entry_id=MEM702"*)
    echo "FAIL: archived entry MEM702 leaked through default state filter. Got: $out"
    exit 1
    ;;
  *) ;;
esac

echo "PASS: default state filter returns only graduated entries"
exit 0
```

`chmod +x` the script.

### Step 4: Create `scripts/verify/m020-p02-query-match-rule.sh`

Path: `/Users/brettkellgren/Sites/spec-kit-orchestrator/scripts/verify/m020-p02-query-match-rule.sh`

```bash
#!/usr/bin/env bash
# m020-p02-query-match-rule.sh — assert FR-2 sub-clauses (a, b, c):
# topic-field equality (case-insensitive) OR tags[] membership (case-folded).
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/query.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns"

# MEM710: topic field "auth"; tags empty.
cat >"$tmpdir/knowledge/patterns/MEM710.md" <<'EOF'
---
id: MEM710
topic: "auth"
tags: []
last_verified: 2026-04-25
status: graduated
---

# MEM710: topic-field hit
EOF

# MEM711: topic empty; tags include "Auth" (case mismatch).
cat >"$tmpdir/knowledge/patterns/MEM711.md" <<'EOF'
---
id: MEM711
topic: ""
tags: [Auth, persistence]
last_verified: 2026-04-25
status: graduated
---

# MEM711: tag hit (case-folded)
EOF

# MEM712: topic field different; tags do not include auth.
cat >"$tmpdir/knowledge/patterns/MEM712.md" <<'EOF'
---
id: MEM712
topic: "rendering"
tags: [shaders]
last_verified: 2026-04-25
status: graduated
---

# MEM712: no-match
EOF

# MEM713: topic field "AUTH" (case-insensitive equality must hit).
cat >"$tmpdir/knowledge/patterns/MEM713.md" <<'EOF'
---
id: MEM713
topic: "AUTH"
tags: []
last_verified: 2026-04-25
status: graduated
---

# MEM713: case-insensitive topic hit
EOF

export PROJECT_ROOT="$tmpdir"
out="$(bash "$SCRIPT" --topic auth 2>/dev/null)"

for id in MEM710 MEM711 MEM713; do
  case "$out" in
    *"entry_id=${id}"*) ;;
    *)
      echo "FAIL: expected match ${id} missing. Got: $out"
      exit 1
      ;;
  esac
done

case "$out" in
  *"entry_id=MEM712"*)
    echo "FAIL: non-matching MEM712 leaked. Got: $out"
    exit 1
    ;;
  *) ;;
esac

echo "PASS: query.sh honors topic-field + tags[] match rule (case-insensitive)"
exit 0
```

`chmod +x` the script.

### Step 5: Create `scripts/verify/m020-p02-query-ranking.sh`

Path: `/Users/brettkellgren/Sites/spec-kit-orchestrator/scripts/verify/m020-p02-query-ranking.sh`

```bash
#!/usr/bin/env bash
# m020-p02-query-ranking.sh — assert FR-2 sub-clause (e):
# topic-field hits rank above tag-only hits; ties broken by last_verified desc.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/query.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns"

# Two topic-field hits with different last_verified, two tag-only hits with
# different last_verified. Expected order:
#   1. MEM720 (topic-field, last_verified=2026-04-20)
#   2. MEM721 (topic-field, last_verified=2026-04-10)
#   3. MEM722 (tag-only,    last_verified=2026-04-15)
#   4. MEM723 (tag-only,    last_verified=2026-04-05)

cat >"$tmpdir/knowledge/patterns/MEM720.md" <<'EOF'
---
id: MEM720
topic: "auth"
tags: []
last_verified: 2026-04-20
status: graduated
---

# MEM720: topic recent
EOF

cat >"$tmpdir/knowledge/patterns/MEM721.md" <<'EOF'
---
id: MEM721
topic: "auth"
tags: []
last_verified: 2026-04-10
status: graduated
---

# MEM721: topic older
EOF

cat >"$tmpdir/knowledge/patterns/MEM722.md" <<'EOF'
---
id: MEM722
topic: ""
tags: [auth]
last_verified: 2026-04-15
status: graduated
---

# MEM722: tag recent
EOF

cat >"$tmpdir/knowledge/patterns/MEM723.md" <<'EOF'
---
id: MEM723
topic: ""
tags: [auth]
last_verified: 2026-04-05
status: graduated
---

# MEM723: tag older
EOF

export PROJECT_ROOT="$tmpdir"
out="$(bash "$SCRIPT" --topic auth 2>/dev/null)"

# Capture the rank order as a single string for comparison.
expected="entry_id=MEM720
entry_id=MEM721
entry_id=MEM722
entry_id=MEM723"

if [ "$out" != "$expected" ]; then
  echo "FAIL: rank order mismatch."
  echo "Expected:"
  echo "$expected"
  echo "Got:"
  echo "$out"
  exit 1
fi

echo "PASS: query.sh ranks topic-field hits above tag hits; ties by last_verified desc"
exit 0
```

`chmod +x` the script.

### Step 6: Create `scripts/verify/m020-p02-query-format-ids.sh`

Path: `/Users/brettkellgren/Sites/spec-kit-orchestrator/scripts/verify/m020-p02-query-format-ids.sh`

```bash
#!/usr/bin/env bash
# m020-p02-query-format-ids.sh — assert default --format ids emits
# `^entry_id=<ID>$` lines only (FR-2 sub-clause f, T01 scope).
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/query.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns"

cat >"$tmpdir/knowledge/patterns/MEM730.md" <<'EOF'
---
id: MEM730
topic: "auth"
tags: []
last_verified: 2026-04-25
status: graduated
---

# MEM730: ids fixture
EOF

export PROJECT_ROOT="$tmpdir"
out="$(bash "$SCRIPT" --topic auth 2>/dev/null)"

if ! printf '%s\n' "$out" | grep -qx 'entry_id=MEM730'; then
  echo "FAIL: ids format did not emit ^entry_id=MEM730$. Got: $out"
  exit 1
fi

# Also assert NO non-matching prefix lines slipped in.
non_match="$(printf '%s\n' "$out" | grep -v -E '^entry_id=' || true)"
if [ -n "$non_match" ]; then
  echo "FAIL: ids format emitted non-id lines: $non_match"
  exit 1
fi

# Explicit --format ids must produce the same output.
out2="$(bash "$SCRIPT" --topic auth --format ids 2>/dev/null)"
if [ "$out" != "$out2" ]; then
  echo "FAIL: explicit --format ids differs from default. default=$out explicit=$out2"
  exit 1
fi

echo "PASS: --format ids emits entry_id=<ID> lines only (default)"
exit 0
```

`chmod +x` the script.

## Must-Haves

- `scripts/knowledge/query.sh` exists, is executable, and accepts `--topic <X>` (required), `--state <S>` (default `graduated`), `--format ids|json` (default `ids`).
- `--topic` matching honors FR-2 sub-clauses (a, b, c): case-insensitive `topic:` equality OR case-folded `tags[]` membership.
- Default state filter is `graduated` (FR-2 sub-clause d).
- Ranking honors FR-2 sub-clause (e): topic-field tier above tag tier; ties broken by `last_verified` descending.
- `--format ids` (default) emits `^entry_id=<ID>$` lines only (FR-2 sub-clause f).
- Bash 3.2 + AD-19 + MEM001 conventions throughout.
- Sources `scripts/knowledge/lib/frontmatter.sh` only for `fm_read_status` (read-only consumer).
- All five T01 verifiers exist, are executable, and exit 0 with `PASS:` lines.

## Verification

```
bash scripts/verify/m020-p02-query-help.sh
bash scripts/verify/m020-p02-query-default-state-filter.sh
bash scripts/verify/m020-p02-query-match-rule.sh
bash scripts/verify/m020-p02-query-ranking.sh
bash scripts/verify/m020-p02-query-format-ids.sh
```

Each must print a `PASS:` line and exit 0.

## Inputs

### From Previous Tasks

- `scripts/knowledge/lib/frontmatter.sh` (P01 T02)
  - Key API: `fm_read_status <file>` → echoes one of `candidate|graduated|archived`. Returns `graduated` for entries with no `status:` line per FR-10.
  - Sourced; query.sh does not call any mutation helper.
- `knowledge/conventions/MEM031.md` (P01 T01) — closed enum vocabulary used as the validation set for `--state`.

### From Disk (Pre-existing)

- `scripts/knowledge/lib/index-utils.sh` — provides `get_project_root` (honors `PROJECT_ROOT` env var per the 4-rule resolver). T01 sources this for fixture isolation in verifiers.

## Constraints

- **AD-19 / MEM001**: every `Check:` and verification command in this plan is a single-script-file invocation. The query.sh body uses pipes internally but the Check lines do not.
- **Bash 3.2**: no associative arrays, no `mapfile`, no `<<<` here-strings inside command-substitution-with-pipes. Use parallel indexed arrays or tempfile buffers.
- **CON-1 / FR-8 (read-only-during-dispatch)**: query.sh MUST NOT write to `knowledge/**`. It MAY create tempfiles outside `knowledge/**` (the rank buffer in `mktemp -t`). T02 ships the side-effect-free verifier that enforces this contract.
- **CON-4 (Surgical Precision)**: query.sh sources only `index-utils.sh` and `frontmatter.sh`. It does NOT modify any pre-existing file.
- **Principle XIV (No Speculative Complexity)**: T01 implements exact-match + topic-keyword-index only. NO semantic/embedding logic. NO persistent index cache.
- **Principle VI (State On Disk Is Truth)**: the topic-keyword index is rebuilt on every query (lazy, no disk cache).
- **FR-9 (schema authority)**: query.sh is a READ-ONLY consumer of MEM031's closed enum. It does NOT introduce new frontmatter fields or rename existing ones.

## Expected Output

After this task:

1. `scripts/knowledge/query.sh` exists, is executable, and is at least 120 lines.
2. All five T01 verifiers exist under `scripts/verify/`, are executable, and pass.
3. `git status knowledge/` is clean (T01 did not touch the live tree; only verifiers' tempdirs).
4. `git status scripts/` shows the new files added; no pre-existing scripts modified.

**Done when**: all five verifiers print `PASS:` and exit 0; `git status knowledge/` is empty.
