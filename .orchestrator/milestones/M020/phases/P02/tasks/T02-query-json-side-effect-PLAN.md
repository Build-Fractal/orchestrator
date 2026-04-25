---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P02"
milestone: "M020"
name: "Query surface JSON output + no-match diagnostic + side-effect-free invariant"
depends_on: ["T01"]
---

## Prerequisites

- T01: `scripts/knowledge/query.sh` exists with `--topic`, `--state`, `--format` flags; default state filter is `graduated`; default format is `ids`; matching + ranking obey FR-2 sub-clauses (a)–(e); `--format ids` emits `entry_id=<ID>` per match (sub-clause f, ids half).
- T01 ships per-task verifiers under `scripts/verify/m020-p02-query-{help,default-state-filter,match-rule,ranking,format-ids}.sh`. T02 must keep all five passing — extension is in-place, additive.

## Description

Extend `scripts/knowledge/query.sh` in place to ship FR-2 sub-clause (f) JSON output, the US-1 acceptance scenario 3 `no-matches` empty-result diagnostic, and the side-effect-free contract (FR-8 / CON-1 / SC-7) verifier. CON-4 byte-equivalence applies to all T01 surface — only the format-emission block at the tail of the script is rewritten; argument parsing, matching, ranking, and the validation guards are unchanged.

Scope (T02):
- Replace T01's tail-block ids-only emitter with a format-aware emitter:
  - `--format ids` (default): emits one `entry_id=<ID>` line per match in rank order. Empty result: emits a single line `entry_id= no-matches=true` (the explicit `no-matches` diagnostic), exit 0. (Acceptance scenario 3.)
  - `--format json`: emits a single JSON document `{"matches": [{"id": "<ID>", "title": "<title>", "status": "<state>", "rank": <N>}, ...]}`. Empty result: `{"matches": [], "no_matches": true}`. Single document, parseable by `jq`. Exit 0.
- Ship `scripts/verify/m020-p02-query-format-json.sh` (FR-2 sub-clause f / SC-1 JSON half).
- Ship `scripts/verify/m020-p02-query-no-match-empty.sh` (acceptance scenario 3).
- Ship `scripts/verify/m020-p02-query-side-effect-free.sh` (FR-8 / CON-1 / SC-7).

Out of scope:
- Dispatch-interface wrapper (T03).
- Cross-cutting integration test (T04).
- Streaming entry bodies (CON-2 forbids it; metadata only).

## Steps

### Step 1: Replace `query.sh`'s emission tail-block

Open `/Users/brettkellgren/Sites/spec-kit-orchestrator/scripts/knowledge/query.sh`. Locate the T01 final block:

```bash
if [ -z "$sorted" ]; then
  # Empty result. T01 exits 0 with no stdout for ids format. T02 will add
  # the explicit `no-matches` diagnostic for both formats.
  exit 0
fi

# T01 emits only ids format. T02 will replace this block with format-aware
# emission. ...
printf '%s\n' "$sorted" | while IFS=$'\t' read -r _tier _lv id _title _status; do
  printf 'entry_id=%s\n' "$id"
done

exit 0
```

Replace it verbatim with:

```bash
# Empty-result diagnostic (US-1 acceptance scenario 3).
if [ -z "$sorted" ]; then
  case "$format" in
    json)
      printf '{"matches": [], "no_matches": true}\n'
      ;;
    ids|*)
      printf 'entry_id= no-matches=true\n'
      ;;
  esac
  exit 0
fi

# Format-aware emission. Rank values are 1-indexed within the sorted output.
case "$format" in
  json)
    # Single-document JSON. Quote-escape title via awk (handles backslash + ").
    printf '{"matches": ['
    rank=0
    first=1
    printf '%s\n' "$sorted" | while IFS=$'\t' read -r _tier _lv id title status; do
      rank=$((rank + 1))
      esc_title="$(printf '%s' "$title" | awk '{gsub(/\\/,"\\\\"); gsub(/"/,"\\\""); print}')"
      esc_id="$(printf '%s' "$id" | awk '{gsub(/\\/,"\\\\"); gsub(/"/,"\\\""); print}')"
      esc_status="$(printf '%s' "$status" | awk '{gsub(/\\/,"\\\\"); gsub(/"/,"\\\""); print}')"
      if [ $first -eq 0 ]; then
        printf ', '
      fi
      printf '{"id": "%s", "title": "%s", "status": "%s", "rank": %d}' \
        "$esc_id" "$esc_title" "$esc_status" "$rank"
      first=0
    done
    printf ']}\n'
    ;;
  ids|*)
    printf '%s\n' "$sorted" | while IFS=$'\t' read -r _tier _lv id _title _status; do
      printf 'entry_id=%s\n' "$id"
    done
    ;;
esac

exit 0
```

**Note** the `while … done` body runs in a subshell because of the upstream pipe — `rank` and `first` will not survive past the loop. That is fine here: the loop emits as it iterates and there is no post-loop accumulator to read. The `printf ', '` separator-before-element trick is the bash 3.2-safe way to handle "comma between but not before/after" without process substitution.

### Step 2: Header-comment update

At the top of `query.sh`, replace the FR-2 sub-clause (f) line:

```
#   (f) output: --format ids (default) emits `entry_id=<ID>` per line; T02
#       extends with --format json
```

with:

```
#   (f) output: --format ids (default) emits `entry_id=<ID>` per line in
#       rank order; --format json emits a single
#       `{"matches": [{id,title,status,rank}, ...]}` document. Empty result:
#       --format ids emits `entry_id= no-matches=true`; --format json emits
#       `{"matches": [], "no_matches": true}`.
```

(All other lines stay byte-equivalent per CON-4.)

### Step 3: Create `scripts/verify/m020-p02-query-format-json.sh`

Path: `/Users/brettkellgren/Sites/spec-kit-orchestrator/scripts/verify/m020-p02-query-format-json.sh`

```bash
#!/usr/bin/env bash
# m020-p02-query-format-json.sh — assert --format json emits a single
# parseable JSON document with matches[] in rank order (FR-2 sub-clause f,
# SC-1 JSON half).
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/query.sh"

if ! command -v jq >/dev/null 2>&1; then
  echo "PASS: jq not installed; skipping JSON-shape assertion (degraded mode)"
  exit 0
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns"

# Three graduated entries on topic auth.
cat >"$tmpdir/knowledge/patterns/MEM740.md" <<'EOF'
---
id: MEM740
topic: "auth"
tags: []
last_verified: 2026-04-25
status: graduated
---

# MEM740: alpha
EOF

cat >"$tmpdir/knowledge/patterns/MEM741.md" <<'EOF'
---
id: MEM741
topic: "auth"
tags: []
last_verified: 2026-04-15
status: graduated
---

# MEM741: beta
EOF

cat >"$tmpdir/knowledge/patterns/MEM742.md" <<'EOF'
---
id: MEM742
topic: ""
tags: [auth]
last_verified: 2026-04-25
status: graduated
---

# MEM742: gamma
EOF

export PROJECT_ROOT="$tmpdir"
out="$(bash "$SCRIPT" --topic auth --format json 2>/dev/null)"

# 1. Single document — pipe through jq for shape validation.
if ! printf '%s' "$out" | jq -e . >/dev/null 2>&1; then
  echo "FAIL: --format json output is not parseable JSON. Got: $out"
  exit 1
fi

# 2. matches array length 3.
n="$(printf '%s' "$out" | jq '.matches | length')"
if [ "$n" != "3" ]; then
  echo "FAIL: matches array length expected 3, got $n. Out: $out"
  exit 1
fi

# 3. First match must be the topic-recent one (MEM740, rank 1).
first_id="$(printf '%s' "$out" | jq -r '.matches[0].id')"
if [ "$first_id" != "MEM740" ]; then
  echo "FAIL: first match expected MEM740, got $first_id. Out: $out"
  exit 1
fi

# 4. Each match exposes id, title, status, rank.
keys="$(printf '%s' "$out" | jq -r '.matches[0] | keys | sort | join(",")')"
case "$keys" in
  id,rank,status,title) ;;
  *)
    echo "FAIL: matches[].keys expected id,rank,status,title got $keys"
    exit 1
    ;;
esac

# 5. rank values are 1, 2, 3 in array order.
ranks="$(printf '%s' "$out" | jq -r '.matches[].rank' | tr '\n' ',' | sed 's/,$//')"
if [ "$ranks" != "1,2,3" ]; then
  echo "FAIL: rank values expected 1,2,3 got $ranks"
  exit 1
fi

echo "PASS: --format json emits {matches:[{id,title,status,rank}]} parseable by jq with rank ordering"
exit 0
```

`chmod +x` the script.

### Step 4: Create `scripts/verify/m020-p02-query-no-match-empty.sh`

Path: `/Users/brettkellgren/Sites/spec-kit-orchestrator/scripts/verify/m020-p02-query-no-match-empty.sh`

```bash
#!/usr/bin/env bash
# m020-p02-query-no-match-empty.sh — assert empty-result diagnostic per
# US-1 acceptance scenario 3 (returns empty structured result with a
# no-matches diagnostic field; does NOT error).
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/query.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns"

# One unrelated graduated entry.
cat >"$tmpdir/knowledge/patterns/MEM750.md" <<'EOF'
---
id: MEM750
topic: "rendering"
tags: [shaders]
last_verified: 2026-04-25
status: graduated
---

# MEM750: unrelated
EOF

export PROJECT_ROOT="$tmpdir"

# 1. ids format: empty result with diagnostic; exit 0.
out_ids="$(bash "$SCRIPT" --topic auth 2>/dev/null)"
rc=$?
if [ $rc -ne 0 ]; then
  echo "FAIL: --topic auth (no matches) exited $rc; expected 0"
  exit 1
fi
case "$out_ids" in
  *"no-matches=true"*) ;;
  *)
    echo "FAIL: ids no-match output missing no-matches=true. Got: $out_ids"
    exit 1
    ;;
esac

# 2. json format: parseable JSON with empty matches[] and no_matches=true.
out_json="$(bash "$SCRIPT" --topic auth --format json 2>/dev/null)"
case "$out_json" in
  *'"matches": []'*) ;;
  *'"matches":[]'*) ;;
  *)
    echo "FAIL: json no-match output missing empty matches[]. Got: $out_json"
    exit 1
    ;;
esac
case "$out_json" in
  *'"no_matches": true'*) ;;
  *'"no_matches":true'*) ;;
  *)
    echo "FAIL: json no-match output missing no_matches:true. Got: $out_json"
    exit 1
    ;;
esac

echo "PASS: empty-result diagnostic emitted for both ids and json formats; exit 0"
exit 0
```

`chmod +x` the script.

### Step 5: Create `scripts/verify/m020-p02-query-side-effect-free.sh`

Path: `/Users/brettkellgren/Sites/spec-kit-orchestrator/scripts/verify/m020-p02-query-side-effect-free.sh`

```bash
#!/usr/bin/env bash
# m020-p02-query-side-effect-free.sh — assert query.sh writes ZERO files
# under knowledge/** for any invocation (FR-8, CON-1, SC-7).
#
# Strategy: build an isolated knowledge tree, snapshot every file's
# md5/mtime, run a battery of query invocations, re-snapshot, and demand
# byte-equivalence and zero new files.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/query.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns" "$tmpdir/knowledge/conventions"

# Five fixture entries with varied state + topic + tags.
cat >"$tmpdir/knowledge/patterns/MEM760.md" <<'EOF'
---
id: MEM760
topic: "auth"
tags: [auth, persistence]
last_verified: 2026-04-25
status: graduated
---

# MEM760: graduated topic
EOF

cat >"$tmpdir/knowledge/patterns/MEM761.md" <<'EOF'
---
id: MEM761
topic: ""
tags: [auth]
last_verified: 2026-04-20
status: candidate
---

# MEM761: candidate tag
EOF

cat >"$tmpdir/knowledge/patterns/MEM762.md" <<'EOF'
---
id: MEM762
topic: "rendering"
tags: []
last_verified: 2026-04-15
status: archived
---

# MEM762: archived
EOF

cat >"$tmpdir/knowledge/conventions/MEM763.md" <<'EOF'
---
id: MEM763
topic: "AUTH"
tags: []
last_verified: 2026-04-10
status: graduated
---

# MEM763: case-insensitive
EOF

cat >"$tmpdir/knowledge/patterns/MEM764.md" <<'EOF'
---
id: MEM764
topic: "rendering"
tags: [shaders]
last_verified: 2026-04-05
status: graduated
---

# MEM764: unrelated
EOF

# Snapshot 1 — pre-invocation hashes.
snap1="$tmpdir/snap1.txt"
find "$tmpdir/knowledge" -type f -name 'MEM*.md' | sort > "$tmpdir/files-before.txt"
while IFS= read -r f; do
  if command -v md5 >/dev/null 2>&1; then
    md5 -q "$f"
  else
    md5sum "$f" | awk '{print $1}'
  fi
done < "$tmpdir/files-before.txt" > "$snap1"

export PROJECT_ROOT="$tmpdir"

# Battery of invocations covering matched/unmatched/state-filtered/format paths.
bash "$SCRIPT" --topic auth                     >/dev/null 2>&1 || true
bash "$SCRIPT" --topic AUTH                     >/dev/null 2>&1 || true
bash "$SCRIPT" --topic auth --state candidate   >/dev/null 2>&1 || true
bash "$SCRIPT" --topic auth --state archived    >/dev/null 2>&1 || true
bash "$SCRIPT" --topic missing                  >/dev/null 2>&1 || true
bash "$SCRIPT" --topic auth --format json       >/dev/null 2>&1 || true
bash "$SCRIPT" --topic missing --format json    >/dev/null 2>&1 || true

# Snapshot 2 — post-invocation hashes.
find "$tmpdir/knowledge" -type f -name 'MEM*.md' | sort > "$tmpdir/files-after.txt"

# 1. File set must be identical (no new files, no deletions).
if ! diff -q "$tmpdir/files-before.txt" "$tmpdir/files-after.txt" >/dev/null; then
  echo "FAIL: file set under knowledge/ changed across query invocations"
  diff "$tmpdir/files-before.txt" "$tmpdir/files-after.txt" || true
  exit 1
fi

# 2. Each file's content hash must match its pre-invocation snapshot.
snap2="$tmpdir/snap2.txt"
while IFS= read -r f; do
  if command -v md5 >/dev/null 2>&1; then
    md5 -q "$f"
  else
    md5sum "$f" | awk '{print $1}'
  fi
done < "$tmpdir/files-after.txt" > "$snap2"

if ! diff -q "$snap1" "$snap2" >/dev/null; then
  echo "FAIL: at least one knowledge file's content hash changed (FR-8 violation)"
  diff "$snap1" "$snap2" || true
  exit 1
fi

echo "PASS: query.sh produced zero writes to knowledge/ across 7-invocation battery"
exit 0
```

`chmod +x` the script.

## Must-Haves

- `scripts/knowledge/query.sh` `--format json` emits a parseable single JSON document with `matches: [{id, title, status, rank}, ...]`.
- `--format ids` and `--format json` empty-result diagnostics are emitted (`no-matches=true` token / `no_matches: true` key) without erroring (US-1 acceptance scenario 3).
- query.sh writes zero files under `knowledge/**` across a battery of matched + unmatched + state-filtered + format-toggled invocations (FR-8 / CON-1 / SC-7).
- All three new T02 verifiers (`format-json`, `no-match-empty`, `side-effect-free`) exist, are executable, and exit 0.
- All five T01 verifiers continue to pass (additive extension; no T01 contract breaks).

## Verification

```
bash scripts/verify/m020-p02-query-format-json.sh
bash scripts/verify/m020-p02-query-no-match-empty.sh
bash scripts/verify/m020-p02-query-side-effect-free.sh
bash scripts/verify/m020-p02-query-format-ids.sh
bash scripts/verify/m020-p02-query-default-state-filter.sh
bash scripts/verify/m020-p02-query-match-rule.sh
bash scripts/verify/m020-p02-query-ranking.sh
bash scripts/verify/m020-p02-query-help.sh
```

The first three are T02-introduced; the last five are T01-introduced and must continue to pass after T02's in-place edit. All eight must print `PASS:` and exit 0.

## Inputs

### From Previous Tasks

- `scripts/knowledge/query.sh` (T01)
  - Key API: argument parser ingests `--topic`, `--state`, `--format`; matching + ranking already produce a tab-separated buffer with columns `tier\tlast_verified\tentry_id\ttitle\tstatus`; T02 replaces ONLY the tail emission block.
  - Stable contract for T02: the variable `sorted` holds the rank-ordered records; the variable `format` holds the validated user-supplied format; both are populated before the tail block.
- `scripts/verify/m020-p02-query-{help,default-state-filter,match-rule,ranking,format-ids}.sh` (T01) — must continue to pass.

### From Disk (Pre-existing)

- `jq` (optional) — used by the JSON shape verifier when available; gracefully degraded to a soft PASS if absent (orchestrator convention per MEM001).

## Constraints

- **AD-19 / MEM001**: every Check + verification command is single-script-file shape.
- **CON-4 (Surgical Precision)**: T02 modifies ONLY the tail emission block of `query.sh` plus the FR-2 sub-clause (f) header comment. Argument parsing, validation guards, matching, ranking, and walk logic stay byte-equivalent.
- **CON-2 (context budget)**: JSON output ships metadata only (id, title, status, rank). Bodies are NEVER streamed.
- **FR-8 / CON-1 (read-only-during-dispatch)**: side-effect-free invariant is contract-enforced by `m020-p02-query-side-effect-free.sh`.
- **Bash 3.2**: subshell-loop limitations honored — JSON emission uses the comma-before-element pattern instead of a post-loop accumulator.
- **CON-3 (no speculative complexity)**: no semantic embeddings; no persistent index; no streaming output beyond the per-call rank-ordered list.

## Expected Output

After this task:

1. `scripts/knowledge/query.sh` is at least 150 lines (T01 ≥ 120, plus ~30-line emission rewrite).
2. Three new T02 verifier scripts exist under `scripts/verify/`, are executable, and exit 0.
3. All five T01 verifiers continue to pass.
4. `git status knowledge/` is clean.

**Done when**: all eight verifiers (T01 + T02) print `PASS:` and exit 0; `git status knowledge/` is empty.
