#!/usr/bin/env bash
# tools/verify/m044-p02-t02-flat-knowledge.sh
# M044/P02/T02 (FR-2/SC-7): flat `## K###` knowledge survives the compression
# filter and the inject path. (a) a flat entry trailing a dropped frontmatter
# entry survives kf_filter_stream; (b) a pure-flat stream passes through; (c) the
# wrapper empty-detections count flat headings, not just `---` fences; (d) an
# append-knowledge bullet is independently scope-resolved by filter_knowledge.
# Bash 3.2. Emits PASS:/FAIL:; exit 0 on PASS, 1 on FAIL.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

fail=0
source scripts/lib/knowledge-filter.sh

TD="$(mktemp -d)"
trap 'rm -rf "$TD"' EXIT
DL="$TD/drop.txt"
ST="$TD/stats.txt"
printf 'superseded\nexperimental\n' > "$DL"

# (a) mixed stream — superseded frontmatter MEM (single-hash heading) followed by
#     a flat ## K### entry. The flat entry must survive; only the MEM is dropped.
mixed_out="$(printf -- '---\nid: MEM099\nstatus: superseded\n---\n# MEM099: Old\nold body\n\n## K001: Flat [project]\nflat body\n' | kf_filter_stream "$DL" "$ST")"
if ! printf '%s' "$mixed_out" | grep -qF '## K001: Flat [project]'; then
  echo "FAIL: flat ## K001 entry dropped from mixed stream. Got: $mixed_out"
  fail=1
fi
if printf '%s' "$mixed_out" | grep -qF 'MEM099'; then
  echo "FAIL: superseded MEM099 was NOT dropped from mixed stream"
  fail=1
fi
if ! grep -qF 'dropped_ids=MEM099' "$ST"; then
  echo "FAIL: stats did not record MEM099 as dropped. Stats: $(cat "$ST")"
  fail=1
fi

# (b) pure-flat stream — passes through unchanged, nothing dropped.
flat_out="$(printf -- '## K001: First [project]\nbody one\n\n## K002: Second [project]\nbody two\n' | kf_filter_stream "$DL" "$ST")"
if ! printf '%s' "$flat_out" | grep -qF '## K001: First [project]'; then
  echo "FAIL: pure-flat K001 missing"
  fail=1
fi
if ! printf '%s' "$flat_out" | grep -qF '## K002: Second [project]'; then
  echo "FAIL: pure-flat K002 missing"
  fail=1
fi
if ! grep -qF 'dropped_count=0' "$ST"; then
  echo "FAIL: pure-flat stream reported drops. Stats: $(cat "$ST")"
  fail=1
fi

# (c) wrapper empty-detections count flat headings (^## ), not just ^---$.
if ! grep -qF "grep -cE '^---\$|^## '" scripts/dispatch/build-context.sh; then
  echo "FAIL: build-context.sh empty-detection not updated to count flat headings"
  fail=1
fi
if ! grep -qF "grep -cE '^---\$|^## '" scripts/dispatch/lib/section-handlers.sh; then
  echo "FAIL: section-handlers.sh empty-detection not updated to count flat headings"
  fail=1
fi

# (d) append-knowledge bullet is independently scope-resolved by filter_knowledge.
KF="$TD/KNOWLEDGE.md"
printf '# Knowledge Base\n\n' > "$KF"
printf '## K050: Out of scope [milestone:M099]\nbody\n\n' >> "$KF"
bash scripts/knowledge/append-knowledge.sh "$KF" "In-scope ambient note" "milestone:M044" >/dev/null 2>&1
fk_out="$(bash scripts/dispatch/scope-filter.sh "$KF" "M044/P02" --type knowledge 2>/dev/null)"
if ! printf '%s' "$fk_out" | grep -qF 'In-scope ambient note'; then
  echo "FAIL: append-knowledge [milestone:M044] bullet not resolved by filter_knowledge for M044. Got: $fk_out"
  fail=1
fi
if printf '%s' "$fk_out" | grep -qF 'Out of scope'; then
  echo "FAIL: out-of-scope [milestone:M099] entry leaked into M044 filter output"
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "PASS: flat ## K### survives compression filter + inject path; append-knowledge bullet scope-resolved"
  exit 0
fi
exit 1
