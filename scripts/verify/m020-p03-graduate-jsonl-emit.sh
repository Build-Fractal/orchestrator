#!/usr/bin/env bash
# m020-p03-graduate-jsonl-emit.sh — assert graduate.sh emits one
# knowledge_graduate + N-1 knowledge_archive records on a cluster graduate,
# and N knowledge_archive records on a cluster reject.
# Bash 3.2 safe. AD-19 single-script-file shape.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/graduate.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns"
mkdir -p "$tmpdir/orch-state"

for id in MEM930 MEM931 MEM932; do
  cat >"$tmpdir/knowledge/patterns/${id}.md" <<EOF
---
id: ${id}
status: candidate
last_verified: 2026-04-25
---

# ${id}: jsonl fixture
EOF
done

export PROJECT_ROOT="$tmpdir"
export ORCH_ROOT="$tmpdir/orch-state"

LOG="$ORCH_ROOT/execution-log.jsonl"

if ! bash "$SCRIPT" --cluster Cjsonl --rationale "test" MEM930 MEM931 MEM932 >/dev/null 2>&1; then
  echo "FAIL: graduate.sh --cluster exited non-zero in jsonl test"
  exit 1
fi

if [ ! -f "$LOG" ]; then
  echo "FAIL: execution-log.jsonl not created at $LOG"
  exit 1
fi

graduate_count="$(grep -c '"event":"knowledge_graduate"' "$LOG" 2>/dev/null || true)"
archive_count="$(grep -c '"event":"knowledge_archive"' "$LOG" 2>/dev/null || true)"
if [ -z "$graduate_count" ]; then
  graduate_count=0
fi
if [ -z "$archive_count" ]; then
  archive_count=0
fi

if [ "$graduate_count" -ne 1 ]; then
  echo "FAIL: expected 1 knowledge_graduate record, got $graduate_count"
  exit 1
fi
if [ "$archive_count" -ne 2 ]; then
  echo "FAIL: expected 2 knowledge_archive records, got $archive_count"
  exit 1
fi

# Reject path: 2 entries -> 2 knowledge_archive records, 0 graduate.
: >"$LOG"
mkdir -p "$tmpdir/knowledge/patterns2"
for id in MEM940 MEM941; do
  cat >"$tmpdir/knowledge/patterns2/${id}.md" <<EOF
---
id: ${id}
status: candidate
last_verified: 2026-04-25
---

# ${id}: reject jsonl fixture
EOF
done

if ! bash "$SCRIPT" --reject --cluster Cjr --rationale "test" MEM940 MEM941 >/dev/null 2>&1; then
  echo "FAIL: graduate.sh --reject exited non-zero in jsonl test"
  exit 1
fi

reject_archive_count="$(grep -c '"event":"knowledge_archive"' "$LOG" 2>/dev/null || true)"
reject_graduate_count="$(grep -c '"event":"knowledge_graduate"' "$LOG" 2>/dev/null || true)"
if [ -z "$reject_archive_count" ]; then
  reject_archive_count=0
fi
if [ -z "$reject_graduate_count" ]; then
  reject_graduate_count=0
fi

if [ "$reject_archive_count" -ne 2 ]; then
  echo "FAIL: expected 2 knowledge_archive records on reject, got $reject_archive_count"
  exit 1
fi
if [ "$reject_graduate_count" -ne 0 ]; then
  echo "FAIL: expected 0 knowledge_graduate records on reject, got $reject_graduate_count"
  exit 1
fi

echo "PASS: JSONL emission counts match cluster + reject contracts"
exit 0
