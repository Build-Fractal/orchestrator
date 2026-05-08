# M007 Integration Handoff — Wire SQLite Graph Backend Into Execution Pipeline

## Context

M007 (Graph-Enhanced Knowledge Retrieval) built a SQLite graph backend for the knowledge system: `graph-db.sh` library, `rebuild-index.sh` populating `knowledge.db`, rewritten `traverse-graph.sh` with recursive CTEs, `scope-filter.sh --graph` mode, `--provenance` mode, and graph diagnostics. **All 24 verification scripts pass.**

**The problem:** The orchestrator's execution pipeline doesn't use any of it. The graph backend is wired in code but never initialized — `knowledge.db` is never created during autonomous execution, so every graph feature silently no-ops. This handoff describes the 4 surgical fixes needed to close the integration gap.

## Project

- **Repo:** `/Users/brettkellgren/Sites/lakeledger/orchestrator`
- **Architecture:** spec-kit extension, pure Bash 3.2 (no Python, no associative arrays)
- **Key constraint:** AD-19 — no compound bash in verification Check: commands (use wrapper scripts)
- **Key constraint:** Atomic file operations via temp-file-then-mv pattern throughout

---

## Fix 1: Add `knowledge.db` to `.gitignore`

**File:** `.gitignore`
**What:** Add knowledge.db and its SQLite WAL/SHM files as ignored derived artifacts.
**Where:** After line 16 (after `.specify/extensions/.backup/`), add:

```
# Knowledge graph database (derived artifact — rebuilt by rebuild-index.sh)
knowledge.db
knowledge.db-shm
knowledge.db-wal
```

**Why:** `knowledge.db` is rebuilt from `knowledge/{category}/MEM###.md` files by `rebuild-index.sh`. It should never be committed.

---

## Fix 2: Auto-rebuild knowledge index before dispatch

**File:** `scripts/lifecycle/auto-loop.sh`
**What:** Call `rebuild-index.sh` before the first context build in each auto-loop iteration, ensuring `knowledge.db` exists and is current.

**Where:** The script defines `PROJECT_ROOT` at line 58 and script paths at lines 60-72. Add `REBUILD_INDEX` to the script paths block:

```bash
# At line 72, after RUN_COMMANDS, add:
REBUILD_INDEX="$PROJECT_ROOT/scripts/knowledge/rebuild-index.sh"
```

**Where to call it:** Right before "Step A: Derive state" (line 373). The pause check exits at line 372. Insert between the pause check and Step A:

Current code at lines 371-374:
```bash
  exit 11
fi

# --- Step A: Derive state and identify next task ---
```

Insert after `fi` (line 372), before Step A (line 373):

```bash
# --- Ensure knowledge graph is current before dispatch ---
if [ -f "$REBUILD_INDEX" ]; then
  bash "$REBUILD_INDEX" --root "$PROJECT_ROOT" >/dev/null 2>&1 || true
fi
```

**Why:** `rebuild-index.sh` is idempotent — it scans all `knowledge/{category}/MEM###.md` files and rebuilds both `KNOWLEDGE-INDEX.md` and `knowledge.db` atomically. Running it before each iteration ensures the graph is current when `traverse-graph.sh` and `scope-filter.sh --graph` run during context assembly. The `>/dev/null 2>&1 || true` suppresses output and swallows errors (if no knowledge dir exists, it exits 1 — safe to ignore).

**Performance:** For <1000 entries, rebuild takes <100ms. Acceptable per-iteration overhead.

---

## Fix 3: Enable `--graph` mode in scope-filter.sh calls

**File:** `scripts/dispatch/lib/section-handlers.sh`
**What:** When `knowledge.db` exists, pass `--graph` to `scope-filter.sh` instead of parsing the flat `KNOWLEDGE-INDEX.md`.

**Where:** The `scope-filter.sh` call is at lines 240-241:

```bash
  bash "$_SH_SCOPE_FILTER" "$knowledge_index" "${milestone}/${phase}" \
    --type knowledge $dep_flag > "$filtered_file" 2>/dev/null || true
```

**Change to:** Add a `--graph` flag when `knowledge.db` exists. The variable `_SH_PROJECT_ROOT` is defined at line 25 of section-handlers.sh. Add a DB existence check and modify the call:

Before the scope-filter call (before line 236), add:

```bash
  # Check if graph database is available for enhanced filtering
  local graph_flag=""
  local db_file="${_SH_PROJECT_ROOT}/knowledge.db"
  if [ -f "$db_file" ]; then
    graph_flag="--graph"
  fi
```

Then modify lines 240-241 to:

```bash
  bash "$_SH_SCOPE_FILTER" "$knowledge_index" "${milestone}/${phase}" \
    --type knowledge $dep_flag $graph_flag > "$filtered_file" 2>/dev/null || true
```

**Why:** When `--graph` is passed, `scope-filter.sh` queries `knowledge.db` directly via SQL with proper scope/confidence/category filtering, instead of parsing the flat pipe-delimited `KNOWLEDGE-INDEX.md` with grep/awk. The flat file path remains as fallback when `knowledge.db` doesn't exist.

**Note:** The `$knowledge_index` positional arg is still passed but ignored in `--graph` mode (scope-filter.sh skips file existence and type detection checks when `--graph` is active — see lines 67 and 72 of scope-filter.sh).

---

## Fix 4: Increase traverse-graph.sh hop depth

**File:** `scripts/dispatch/lib/section-handlers.sh`
**What:** Increase the `--max-depth` from 1 to 2 and `--max-entries` from 5 to 10 in the `traverse-graph.sh` call. The entire point of M007 was enabling multi-hop retrieval — the current call negates that.

**Where:** Lines 270-271:

```bash
    bash "$_SH_TRAVERSE_GRAPH" --id "$eid" --max-depth 1 --max-entries 5 \
      >> "$related_file" 2>/dev/null || true
```

**Change to:**

```bash
    bash "$_SH_TRAVERSE_GRAPH" --id "$eid" --hops 2 --max-entries 10 \
      >> "$related_file" 2>/dev/null || true
```

**Why:** With `--max-depth 1`, only directly related entries are found — identical to the old BFS behavior. `--hops 2` finds entries 2 relationship hops away, which is the sweet spot: broad enough to surface relevant context, narrow enough to avoid noise. `--max-entries 10` prevents context bloat while allowing the richer results from multi-hop.

**Note:** `--hops` is an alias for `--max-depth` added in M007 P02. Using it signals intent more clearly.

---

## Verification

After making all 4 changes, verify the integration works:

### 1. Run rebuild-index.sh manually to confirm it works
```bash
bash scripts/knowledge/rebuild-index.sh
```
Expected: `REBUILT: KNOWLEDGE-INDEX.md with N entries` and `REBUILT: knowledge.db with N entries, E edges, S scope_tags`

### 2. Verify knowledge.db was created
```bash
test -f knowledge.db && echo "EXISTS" || echo "MISSING"
```

### 3. Run all M007 verification scripts to confirm nothing broke
```bash
for f in scripts/verify/m007-p01-*.sh scripts/verify/m007-p02-*.sh scripts/verify/m007-p03-*.sh scripts/verify/m007-p04-*.sh; do
  bash "$f"
done
```
All 24 should print PASS.

### 4. Verify .gitignore includes knowledge.db
```bash
grep -q 'knowledge.db' .gitignore && echo "PASS" || echo "FAIL"
```

### 5. Verify section-handlers.sh has --graph integration
```bash
grep -q '\-\-graph' scripts/dispatch/lib/section-handlers.sh && echo "PASS" || echo "FAIL"
```

### 6. Verify auto-loop.sh calls rebuild-index.sh
```bash
grep -q 'rebuild-index' scripts/lifecycle/auto-loop.sh && echo "PASS" || echo "FAIL"
```

### 7. Verify traverse-graph.sh uses hops 2
```bash
grep -q 'hops 2' scripts/dispatch/lib/section-handlers.sh && echo "PASS" || echo "FAIL"
```

### 8. Clean up knowledge.db from working dir (it's gitignored now)
```bash
rm -f knowledge.db
```

---

## Commit

After all verifications pass, commit with message:

```
fix: wire M007 SQLite graph backend into execution pipeline

- Add knowledge.db to .gitignore (derived artifact)
- Auto-rebuild knowledge index before each dispatch iteration
- Enable --graph mode in scope-filter.sh when knowledge.db exists
- Increase traverse-graph.sh hop depth from 1 to 2 for multi-hop retrieval

These 4 changes close the integration gap between M007's graph backend
(which builds the capability) and the orchestrator's execution pipeline
(which uses it). Without these, knowledge.db was never created during
autonomous execution, and all graph features silently no-oped.
```

---

## Files Changed (4)

| File | Change |
|------|--------|
| `.gitignore` | Add `knowledge.db`, `knowledge.db-shm`, `knowledge.db-wal` |
| `scripts/lifecycle/auto-loop.sh` | Add `REBUILD_INDEX` path + call before Step A |
| `scripts/dispatch/lib/section-handlers.sh` | Add `--graph` flag to scope-filter call + increase hop depth to 2 |

No new files created. No tests to update. No verification scripts need changes.
