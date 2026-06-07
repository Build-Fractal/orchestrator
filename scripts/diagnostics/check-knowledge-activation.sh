#!/usr/bin/env bash
# scripts/diagnostics/check-knowledge-activation.sh
# M044/P01/T04 (FR-15 / FR-9-enforcement / SC-11 / CON-5): the SINGLE
# consolidated knowledge-activation doctor check. Reports three silent-
# degradation symptoms in one surface (reconciles, not duplicates,
# papercut-doctor-knowledge-gap-surface.md):
#
#   1. 0-mem-on-mature        — the project is mature (milestone SUMMARY or a
#                               decisions row on disk) yet KNOWLEDGE-INDEX.md
#                               carries zero MEM entries. The load-bearing
#                               silent-degradation case -> status=fail.
#   2. vestigial-index        — a divergent KNOWLEDGE-INDEX.md exists at the
#                               historical .orchestrator/ location, shadowing
#                               the canonical get_index_path() root copy -> warn.
#   3. runtime-memory-divergence — decisions landed in an execution log's `note`
#                               fields while DECISIONS.md is empty/absent (the
#                               two-store divergence behind 0-MEM injects) -> warn.
#   4. stale-graph-db         — a real corpus (≥1 MEM/SPEC/REF under knowledge/)
#                               exists but knowledge.db is missing or stale (the
#                               cloned-project case — the DB is gitignored). The
#                               fix is rebuild-index.sh, which orchestrator:init
#                               now runs automatically -> warn.
#
# Emits: per-symptom detail lines + `DOCTOR:KNOWLEDGE_ACTIVATION status=ok|warn|fail symptoms=<csv|none>`
# File-based detection only (no SQL). Deterministic (fixed symptom order, no
# wall-clock). Bash 3.2.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

while [ $# -gt 0 ]; do
  case "$1" in
    --root) PROJECT_ROOT="$2"; shift 2 ;;
    --root=*) PROJECT_ROOT="${1#--root=}"; shift ;;
    *) shift ;;
  esac
done

# Source framework libs from the script's own tree (LIB_ROOT), NOT from the
# target PROJECT_ROOT — the libs are framework code, the data is the project's.
# (In normal use the two coincide; they diverge only under fixture testing.)
LIB_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROV_LIB="$LIB_ROOT/scripts/dispatch/lib/knowledge-provenance.sh"
if [ -r "$PROV_LIB" ]; then
  # shellcheck source=/dev/null
  . "$PROV_LIB" 2>/dev/null || true
fi
# Canonical index path of the TARGET project, resolved via get_index_path
# (FR-11) with PROJECT_ROOT pointed at the target.
IDX_LIB="$LIB_ROOT/scripts/knowledge/lib/index-utils.sh"
CANON_INDEX="$PROJECT_ROOT/KNOWLEDGE-INDEX.md"
if [ -r "$IDX_LIB" ]; then
  # shellcheck source=/dev/null
  . "$IDX_LIB" 2>/dev/null || true
  if command -v get_index_path >/dev/null 2>&1; then
    CANON_INDEX="$(PROJECT_ROOT="$PROJECT_ROOT" get_index_path 2>/dev/null || printf '%s' "$CANON_INDEX")"
  fi
fi

# --- Symptom 1: 0-MEM on a mature project ---
sym_zeromem=0
is_mature=0
if command -v kp_is_mature >/dev/null 2>&1; then
  is_mature="$(kp_is_mature "$PROJECT_ROOT" 2>/dev/null || printf '0')"
fi
index_mem_count=0
if [ -f "$CANON_INDEX" ]; then
  index_mem_count="$(grep -cE '^MEM[0-9]' "$CANON_INDEX" 2>/dev/null | tr -d ' ' || true)"
  index_mem_count="${index_mem_count:-0}"
fi
if [ "$is_mature" = "1" ] && [ "$index_mem_count" -eq 0 ]; then
  sym_zeromem=1
  echo "GAP: mature project with 0 MEM entries in $(basename "$CANON_INDEX") — knowledge not activating"
fi

# --- Symptom 2: vestigial/divergent index path ---
sym_vestigial=0
VESTIGIAL_INDEX="$PROJECT_ROOT/.orchestrator/KNOWLEDGE-INDEX.md"
if [ -f "$VESTIGIAL_INDEX" ] && [ "$VESTIGIAL_INDEX" != "$CANON_INDEX" ]; then
  sym_vestigial=1
  echo "GAP: divergent index at .orchestrator/KNOWLEDGE-INDEX.md shadows the canonical $(basename "$CANON_INDEX")"
fi

# --- Symptom 3: runtime-memory divergence ---
# Decisions present in an execution log's note fields while DECISIONS.md is
# empty/absent (decisions landed somewhere dispatch never reads).
sym_runtime=0
DECISIONS="$PROJECT_ROOT/.orchestrator/DECISIONS.md"
decisions_rows=0
if [ -f "$DECISIONS" ]; then
  decisions_rows="$(grep -cE '^\| D[0-9]' "$DECISIONS" 2>/dev/null | tr -d ' ' || true)"
  decisions_rows="${decisions_rows:-0}"
fi
if [ "$decisions_rows" -eq 0 ]; then
  log_hit=""
  if [ -d "$PROJECT_ROOT/.orchestrator" ]; then
    log_hit="$(find "$PROJECT_ROOT/.orchestrator" -name 'execution-log.jsonl' -exec grep -liE '"note"[^}]*(decision|decided|chose)' {} \; 2>/dev/null | head -1 || true)"
  fi
  if [ -n "$log_hit" ]; then
    sym_runtime=1
    echo "GAP: decision-shaped notes in execution-log.jsonl but DECISIONS.md is empty — decisions not graduated to .orchestrator/"
  fi
fi

# --- Symptom 4: missing/stale graph DB (cloned-project onboarding case) ---
# knowledge.db is a generated artifact (gitignored), so a fresh clone has the
# committed corpus but no DB until it is rebuilt. Graph-mode queries degrade
# until then. Read-only diagnosis only — the fix is `rebuild-index.sh` (which
# `orchestrator:init` now runs automatically). Fires only when a real corpus
# exists (≥1 MEM/SPEC/REF detail file under knowledge/), so a greenfield or
# index-only project never trips it.
sym_graphdb=0
KNOWLEDGE_DIR="$PROJECT_ROOT/knowledge"
GRAPH_DB="$PROJECT_ROOT/knowledge.db"
if [ -d "$KNOWLEDGE_DIR" ]; then
  corpus_hit="$(find "$KNOWLEDGE_DIR" -name 'MEM*.md' -o -name 'SPEC-*.md' -o -name 'REF-*.md' 2>/dev/null | head -1)"
  if [ -n "$corpus_hit" ]; then
    if [ ! -f "$GRAPH_DB" ]; then
      sym_graphdb=1
      echo "GAP: knowledge corpus present but knowledge.db is missing (fresh clone?) — run: bash scripts/knowledge/rebuild-index.sh  (orchestrator:init does this automatically)"
    elif [ -n "$(find "$KNOWLEDGE_DIR" -name '*.md' -newer "$GRAPH_DB" -print 2>/dev/null | head -1)" ]; then
      sym_graphdb=1
      echo "GAP: knowledge.db is stale (older than a knowledge entry) — run: bash scripts/knowledge/rebuild-index.sh"
    fi
  fi
fi

# --- Aggregate (fixed symptom order) ---
symptoms=""
if [ "$sym_zeromem" -eq 1 ]; then symptoms="${symptoms}${symptoms:+,}0-mem-on-mature"; fi
if [ "$sym_vestigial" -eq 1 ]; then symptoms="${symptoms}${symptoms:+,}vestigial-index"; fi
if [ "$sym_runtime" -eq 1 ]; then symptoms="${symptoms}${symptoms:+,}runtime-memory-divergence"; fi
if [ "$sym_graphdb" -eq 1 ]; then symptoms="${symptoms}${symptoms:+,}stale-graph-db"; fi

status="ok"
if [ "$sym_zeromem" -eq 1 ]; then
  status="fail"
elif [ "$sym_vestigial" -eq 1 ] || [ "$sym_runtime" -eq 1 ] || [ "$sym_graphdb" -eq 1 ]; then
  status="warn"
fi

if [ -z "$symptoms" ]; then
  symptoms="none"
fi

echo "DOCTOR:KNOWLEDGE_ACTIVATION status=${status} symptoms=${symptoms}"
exit 0
