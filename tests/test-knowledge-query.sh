#!/usr/bin/env bash
# tests/test-knowledge-query.sh — SC-1 + SC-7 integration test for the
# M020/P02 query surface. Exercises both the direct query.sh entry point
# AND the dispatch-interface --query passthrough.
#
# MEM002 conventions: pass()/fail() with parallel arrays, structured
# PASS:/FAIL: summary line on stdout. Bash 3.2 safe.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
QUERY="$ROOT/scripts/knowledge/query.sh"
DISPATCH="$ROOT/scripts/dispatch/dispatch-interface.sh"

pass_count=0
fail_count=0
fail_messages=""

pass() {
  pass_count=$((pass_count + 1))
}

fail() {
  fail_count=$((fail_count + 1))
  fail_messages="$fail_messages
  - $1"
}

# --- Fixture: three graduated + two candidate entries on topic "auth" ---
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns" "$tmpdir/knowledge/conventions"

# Graduated entries (must be returned by SC-1).
cat >"$tmpdir/knowledge/patterns/MEM800.md" <<'EOF'
---
id: MEM800
topic: "auth"
tags: []
last_verified: 2026-04-25
status: graduated
---

# MEM800: graduated topic-field hit (most recent)
EOF

cat >"$tmpdir/knowledge/patterns/MEM801.md" <<'EOF'
---
id: MEM801
topic: "auth"
tags: []
last_verified: 2026-04-15
status: graduated
---

# MEM801: graduated topic-field hit (older)
EOF

cat >"$tmpdir/knowledge/conventions/MEM802.md" <<'EOF'
---
id: MEM802
topic: ""
tags: [auth, persistence]
last_verified: 2026-04-20
status: graduated
---

# MEM802: graduated tag-only hit
EOF

# Candidate entries (must be EXCLUDED from default-state-filter result).
cat >"$tmpdir/knowledge/patterns/MEM803.md" <<'EOF'
---
id: MEM803
topic: "auth"
tags: []
last_verified: 2026-04-22
status: candidate
---

# MEM803: candidate (excluded by default filter)
EOF

cat >"$tmpdir/knowledge/patterns/MEM804.md" <<'EOF'
---
id: MEM804
topic: ""
tags: [auth]
last_verified: 2026-04-21
status: candidate
---

# MEM804: candidate tag (excluded by default filter)
EOF

# --- Snapshot for SC-7 (no writes to knowledge/) ---
files_before="$tmpdir/files-before.txt"
hashes_before="$tmpdir/hashes-before.txt"
find "$tmpdir/knowledge" -type f -name 'MEM*.md' | sort > "$files_before"
while IFS= read -r f; do
  if command -v md5 >/dev/null 2>&1; then
    md5 -q "$f"
  else
    md5sum "$f" | awk '{print $1}'
  fi
done < "$files_before" > "$hashes_before"

export PROJECT_ROOT="$tmpdir"

# === SC-1 ids format: graduated-only return + ranking ========================

# Case 1: --format ids returns exactly the three graduated entries in rank
#         order: MEM800 (topic recent) > MEM801 (topic older) > MEM802 (tag).
out_ids="$(bash "$QUERY" --topic auth 2>/dev/null)"
expected_ids="entry_id=MEM800
entry_id=MEM801
entry_id=MEM802"
if [ "$out_ids" = "$expected_ids" ]; then
  pass
else
  fail "SC-1 ids order mismatch. expected:\n$expected_ids\ngot:\n$out_ids"
fi

# Case 2: candidate entries excluded by default state filter.
case "$out_ids" in
  *MEM803*)
    fail "SC-1 candidate MEM803 leaked through default filter"
    ;;
  *MEM804*)
    fail "SC-1 candidate MEM804 leaked through default filter"
    ;;
  *)
    pass
    ;;
esac

# Case 3: every emitted line matches ^entry_id=<ID>$ (no diagnostic lines).
non_id_lines="$(printf '%s\n' "$out_ids" | grep -v -E '^entry_id=MEM[0-9]+$' || true)"
if [ -z "$non_id_lines" ]; then
  pass
else
  fail "SC-1 non-id-shape lines in default ids output: $non_id_lines"
fi

# === SC-1 json format: matches[] of length 3 in rank order ===================

if command -v jq >/dev/null 2>&1; then
  out_json="$(bash "$QUERY" --topic auth --format json 2>/dev/null)"

  # Case 4: parseable.
  if printf '%s' "$out_json" | jq -e . >/dev/null 2>&1; then
    pass
  else
    fail "SC-1 json output not parseable. got: $out_json"
  fi

  # Case 5: matches array length 3.
  n="$(printf '%s' "$out_json" | jq '.matches | length' 2>/dev/null || echo 0)"
  if [ "$n" = "3" ]; then
    pass
  else
    fail "SC-1 json matches length expected 3, got $n. out: $out_json"
  fi

  # Case 6: ids in rank order: MEM800, MEM801, MEM802.
  ids_in_order="$(printf '%s' "$out_json" | jq -r '.matches[].id' | tr '\n' ',' | sed 's/,$//')"
  if [ "$ids_in_order" = "MEM800,MEM801,MEM802" ]; then
    pass
  else
    fail "SC-1 json rank order expected MEM800,MEM801,MEM802 got $ids_in_order"
  fi
else
  echo "(jq not installed; skipping SC-1 json shape cases)"
fi

# === SC-1 dispatch-wrapper byte-equivalence =================================

# Case 7: ids stdout via --query wrapper equals direct invocation.
out_wrapped="$(bash "$DISPATCH" --query --topic auth 2>/dev/null)"
if [ "$out_wrapped" = "$out_ids" ]; then
  pass
else
  fail "SC-1 dispatch-wrapper ids stdout differs from direct"
fi

# === SC-7 read-only invariant ================================================

# Run a battery through both entry points covering matched + unmatched +
# state-filtered + format-toggled paths.
bash "$QUERY"    --topic auth                       >/dev/null 2>&1 || true
bash "$QUERY"    --topic auth --state candidate     >/dev/null 2>&1 || true
bash "$QUERY"    --topic auth --format json         >/dev/null 2>&1 || true
bash "$QUERY"    --topic missing                    >/dev/null 2>&1 || true
bash "$DISPATCH" --query --topic auth               >/dev/null 2>&1 || true
bash "$DISPATCH" --query --topic auth --format json >/dev/null 2>&1 || true

# Re-snapshot.
files_after="$tmpdir/files-after.txt"
hashes_after="$tmpdir/hashes-after.txt"
find "$tmpdir/knowledge" -type f -name 'MEM*.md' | sort > "$files_after"
while IFS= read -r f; do
  if command -v md5 >/dev/null 2>&1; then
    md5 -q "$f"
  else
    md5sum "$f" | awk '{print $1}'
  fi
done < "$files_after" > "$hashes_after"

# Case 8: file set unchanged.
if diff -q "$files_before" "$files_after" >/dev/null; then
  pass
else
  fail "SC-7 file set under knowledge/ changed across query battery"
fi

# Case 9: every file's content hash unchanged.
if diff -q "$hashes_before" "$hashes_after" >/dev/null; then
  pass
else
  fail "SC-7 at least one knowledge file's content hash changed"
fi

# === Summary =================================================================

total=$((pass_count + fail_count))
if [ $fail_count -eq 0 ]; then
  echo "PASS: ${pass_count}/${total} cases | tests/test-knowledge-query.sh (SC-1 + SC-7)"
  exit 0
else
  echo "FAIL: ${pass_count}/${total} cases | tests/test-knowledge-query.sh"
  echo "Failures:${fail_messages}"
  exit 1
fi
