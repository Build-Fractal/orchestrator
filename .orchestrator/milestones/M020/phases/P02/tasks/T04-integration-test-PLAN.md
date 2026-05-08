---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P02"
milestone: "M020"
name: "Integration test (tests/test-knowledge-query.sh covering SC-1 + SC-7)"
depends_on: ["T03"]
---

## Prerequisites

- T01 + T02: `scripts/knowledge/query.sh` is contract-stable.
- T03: `scripts/dispatch/dispatch-interface.sh --query` passthrough is byte-equivalent to direct `query.sh` invocation.
- All T01 + T02 + T03 per-task verifiers pass.

## Description

Land the cross-cutting integration test `tests/test-knowledge-query.sh` that exercises Success Criteria SC-1 + SC-7 from spec 025 against the dispatch-wrapper entry point (the path M024 will use). Where the per-task verifiers in T01–T03 each isolate a single contract clause, this test asserts the end-to-end behavior:

- **SC-1**: `bash scripts/knowledge/query.sh --topic <X>` against a fixture with three graduated + two candidate entries on topic X (matching by both `topic:` field and `tags[]` membership) returns exactly the three graduated entries; `--format ids` emits stdout matching `^entry_id=<ID>$` lines only for graduated entries; ranking places `topic:`-field exact matches before tag-only matches; exit 0. `--format json` against the same fixture emits a JSON document parseable by `jq` with a `matches` array of length 3 in rank order.
- **SC-7**: A dispatch-payload-assembly run invoking `query.sh` emits zero writes to `knowledge/**`; `git status knowledge/` reports a clean tree post-dispatch.

The test follows orchestrator test conventions per MEM002:
- `pass()` / `fail()` helpers using parallel indexed arrays (Bash 3.2 safe).
- Per-case assertions in numbered cases.
- Final summary `PASS: <N>/<N> cases | <name>` line on stdout, exit 0; or `FAIL:` summary on stdout, exit 1.

## Steps

### Step 1: Create `tests/test-knowledge-query.sh`

Path: `/Users/brettkellgren/Sites/orchestrator/tests/test-knowledge-query.sh`

```bash
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
```

`chmod +x tests/test-knowledge-query.sh`.

### Step 2: Run the test

```
bash tests/test-knowledge-query.sh
```

Expected: `PASS: <N>/<N> cases | tests/test-knowledge-query.sh (SC-1 + SC-7)` on stdout, exit 0. The exact `<N>` depends on whether `jq` is present (7 if absent, 9 if present).

## Must-Haves

- `tests/test-knowledge-query.sh` exists, is executable, ≥80 lines, contains the literal string `SC-1`.
- The test exercises BOTH direct `query.sh` invocation AND the `dispatch-interface.sh --query` passthrough wrapper.
- The test asserts SC-1 (default-state-filter graduated-only return, ranking, ids + json shapes) and SC-7 (read-only invariant via pre/post hash snapshot).
- The test follows MEM002 conventions: `pass()` / `fail()` helpers, structured `PASS:` / `FAIL:` summary line, exit 0 on pass.
- The test gracefully skips JSON shape cases when `jq` is not installed (degraded-mode soft-pass per orchestrator convention).

## Verification

```
bash tests/test-knowledge-query.sh
```

Must print a `PASS:` summary and exit 0.

## Inputs

### From Previous Tasks

- `scripts/knowledge/query.sh` (T01 + T02)
  - Key API: `bash query.sh --topic <X> [--state <S>] [--format ids|json]`.
  - Default state filter: `graduated`. Default format: `ids`. Ranking: topic-field tier > tag tier; ties by `last_verified` desc.
- `scripts/dispatch/dispatch-interface.sh` (T03)
  - Key API: `bash dispatch-interface.sh --query --topic <X> [...]` exec-passes through to query.sh with byte-equivalent stdout/stderr/exit code.

### From Disk (Pre-existing)

- `tests/AGENTS.md` — orchestrator test conventions (MEM002). T04 follows the established pattern: pass()/fail() helpers, structured summary, fixture in tempdir, no test-state leak into source tree.
- `jq` (optional) — JSON shape cases skipped when absent.

## Constraints

- **AD-19 / MEM001**: the test's `Check:` invocation is a single-script-file shape. The test body uses pipes internally (find | sort | while; printf | jq) — that is permitted because the body runs inside a script file, not in a `Check:` line.
- **MEM002**: pass()/fail() helpers with parallel-indexed-array semantics; no `declare -A`. Bash 3.2 safe.
- **FR-8 / CON-1 / SC-7**: SC-7 cases compare pre/post hash snapshots — the test itself MUST NOT touch the live `knowledge/**` tree. All fixture state lives in `mktemp -d`.
- **CON-2**: SC-1 JSON cases assert metadata-only fields (id, title, status, rank). The test does not assert any body content.
- **MEM002 fixture pattern**: tempdir with `trap 'rm -rf' EXIT` cleanup; `PROJECT_ROOT` env var override per the 4-rule resolver (matches T01–T03 verifier convention).
- **Principle VI**: all assertions read filesystem state; no in-memory caches.

## Expected Output

After this task:

1. `tests/test-knowledge-query.sh` exists, is executable, is ≥80 lines, and contains the literal string `SC-1`.
2. `bash tests/test-knowledge-query.sh` exits 0 with `PASS: <N>/<N> cases | tests/test-knowledge-query.sh (SC-1 + SC-7)`.
3. `git status knowledge/` is clean (the test uses tempdir fixtures only).
4. The phase rollup `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M020/phases/P02` returns PASS — all phase truths green.

**Done when**: the integration test passes; the phase-level rollup passes; `git status knowledge/` is empty.
