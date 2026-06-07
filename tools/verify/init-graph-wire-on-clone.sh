#!/usr/bin/env bash
# tools/verify/init-graph-wire-on-clone.sh
# Cloned-project onboarding: `orchestrator:init` rebuilds the gitignored
# knowledge.db when a committed corpus is present, and `orchestrator:doctor`
# (read-only) reports a missing/stale graph DB with the fix command.
# Bash 3.2. Emits PASS:/FAIL:; exit 0 on PASS, 1 on FAIL.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"
fail=0
CHECK="scripts/diagnostics/check-knowledge-activation.sh"

# --- 1. init auto-rebuilds the graph on a cloned-style corpus (no knowledge.db) ---
H="$(mktemp -d)"
P="$(mktemp -d)"
trap 'rm -rf "$H" "$P"' EXIT
echo '{"name":"clone-fixture"}' > "$P/package.json"
mkdir -p "$P/knowledge/conventions"
cat > "$P/knowledge/conventions/MEM900.md" <<'EOF'
---
id: MEM900
scope_tags: "[project]"
category: conventions
confidence: 0.9
created_at: 2026-06-07
last_verified: 2026-06-07
hit_count: 1
---

# MEM900: committed corpus entry

body
EOF
printf '# Knowledge Index\nMEM900 | [project] | conventions | 0.9 | 2026-06-07 | verified:2026-06-07 | hits:1 | committed corpus entry\n' > "$P/KNOWLEDGE-INDEX.md"
# Pre-state: corpus present, NO knowledge.db (the fresh-clone condition).
if [ -f "$P/knowledge.db" ]; then echo "FAIL: fixture unexpectedly has knowledge.db"; fail=1; fi

out="$(HOME="$H" bash scripts/lifecycle/init-project.sh --project-dir "$P" --runtime claude-code 2>/tmp/init-graph.err)"
rc=$?
if [ "$rc" -ne 0 ]; then
  echo "FAIL: init exited $rc"; cat /tmp/init-graph.err; exit 1
fi
if ! printf '%s' "$out" | grep -q 'knowledge_graph=rebuilt'; then
  echo "FAIL: init SUMMARY did not report knowledge_graph=rebuilt. Got: $(printf '%s' "$out" | grep '^SUMMARY:')"
  fail=1
fi
if [ ! -f "$P/knowledge.db" ]; then
  echo "FAIL: init did not create knowledge.db"
  fail=1
fi

# --- 2. greenfield init is a no-op for the graph (no corpus) ---
H2="$(mktemp -d)"; P2="$(mktemp -d)"
echo '{"name":"greenfield"}' > "$P2/package.json"
out2="$(HOME="$H2" bash scripts/lifecycle/init-project.sh --project-dir "$P2" --runtime claude-code 2>/dev/null)"
if ! printf '%s' "$out2" | grep -q 'knowledge_graph=none'; then
  echo "FAIL: greenfield init should report knowledge_graph=none. Got: $(printf '%s' "$out2" | grep '^SUMMARY:')"
  fail=1
fi
rm -rf "$H2" "$P2"

# --- 3. doctor (read-only) flags a missing graph DB with the fix command ---
D="$(mktemp -d)"
mkdir -p "$D/knowledge/conventions" "$D/.orchestrator"
cat > "$D/knowledge/conventions/MEM901.md" <<'EOF'
---
id: MEM901
category: conventions
---
# MEM901: x
body
EOF
printf '# Knowledge Index\nMEM901 | [project] | conventions | 0.9 | 2026-06-07 | verified:2026-06-07 | hits:1 | x\n' > "$D/KNOWLEDGE-INDEX.md"
printf '| D001 | Decision | Choice | arch | M001/P01 | Rationale |\n' > "$D/.orchestrator/DECISIONS.md"
dout="$(bash "$CHECK" --root "$D" 2>/dev/null)"
if ! printf '%s' "$dout" | grep -q 'status=warn'; then
  echo "FAIL: doctor did not warn on missing knowledge.db. Got: $dout"; fail=1
fi
if ! printf '%s' "$dout" | grep -q 'stale-graph-db'; then
  echo "FAIL: doctor symptoms missing stale-graph-db. Got: $dout"; fail=1
fi
if ! printf '%s' "$dout" | grep -q 'rebuild-index.sh'; then
  echo "FAIL: doctor GAP line lacks the rebuild-index.sh fix command"; fail=1
fi
# After a rebuild, doctor returns to ok.
bash scripts/knowledge/rebuild-index.sh --root "$D" >/dev/null 2>&1
dout2="$(bash "$CHECK" --root "$D" 2>/dev/null)"
if ! printf '%s' "$dout2" | grep -q 'status=ok'; then
  echo "FAIL: doctor did not return to ok after rebuild. Got: $dout2"; fail=1
fi
rm -rf "$D"

if [ "$fail" -eq 0 ]; then
  echo "PASS: init auto-wires the graph on clone; doctor diagnoses a missing/stale graph DB read-only"
  exit 0
fi
exit 1
