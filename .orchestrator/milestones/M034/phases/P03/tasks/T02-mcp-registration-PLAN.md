---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P03"
milestone: "M034"
name: "Non-clobbering .cursor/mcp.json registration (FR-10 / CON-6)"
depends_on: ["T01"]
---

## Prerequisites

- `scripts/lifecycle/review-gate-mcp-server.sh` exists (T01) — the server the registration points at.
- `scripts/dispatch/adapters/runtime/cursor.sh` exists with `--probe` / `--register` / `--hook-config` modes (the `--hook-config` block at ~line 236 is the structural model for `--mcp-config`) — verified on disk.
- `packaging/install/install-cursor.sh` exists with the Stage 3 hooks-wiring block (~line 288) as the structural model for a new MCP-registration stage — verified on disk.
- `jq` on PATH.

## Description

Wire the T01 server into Cursor via the install path with a **non-clobbering
merge** into `.cursor/mcp.json` (FR-10 / CON-6 / D-P03-4). Three pieces: a
`merge-mcp-config.sh` jq merge helper (the CON-6 primitive), a `--mcp-config` mode
on the `cursor.sh` runtime adapter (emits the server-entry fragment, mirroring
`--hook-config`), and a registration stage in `install-cursor.sh` that calls both.

## Steps

### 1. Author `scripts/lifecycle/merge-mcp-config.sh`

Bash + jq. Non-clobbering, idempotent merge of one named server entry into a
`.cursor/mcp.json` `mcpServers` object (D-P03-4). Contract:

```bash
#!/usr/bin/env bash
# scripts/lifecycle/merge-mcp-config.sh — M034 P03 (FR-10 / CON-6).
#
# Non-clobbering merge of the orchestrator review-gate server entry into a
# .cursor/mcp.json. MERGE, not overwrite (CON-6): operator-authored mcpServers
# entries are preserved byte-for-byte; only `.mcpServers["<name>"]` is set/replaced.
# Idempotent (re-run leaves exactly one orchestrator entry). Absent target -> create
# with only our entry. Malformed existing JSON -> FAIL CLOSED (exit 2, no write).
#
# Usage:
#   merge-mcp-config.sh --target <.cursor/mcp.json> --name <server-name> --entry <json>
#     [--dry-run]
#
# Exit: 0 merged/created (or would_write on --dry-run); 1 bad args; 2 malformed
# target (fail-closed).
#
# CON-1: bash 3.2 / POSIX-sh single file. jq REQUIRED.
set -u
```

Logic:
1. Parse `--target` / `--name` / `--entry` / `--dry-run`. `--entry` is a JSON
   object string (the server entry, e.g.
   `{"command":"bash","args":["…/review-gate-mcp-server.sh"]}`).
2. Validate `--entry` is valid JSON (`jq -e . <<<"$entry"`); else exit 1.
3. If the target file exists:
   - Validate it is parseable JSON: `jq -e . "$target" >/dev/null 2>&1`; if NOT,
     print `FAIL: malformed .cursor/mcp.json — preserving operator file` and **exit
     2** (fail closed, no write — CON-6).
   - Merge: `jq --arg n "$name" --argjson e "$entry" '.mcpServers = ((.mcpServers // {}) + {($n): $e})' "$target"` → atomic tmpfile + `mv`. (`+` right-biased so a re-run replaces only our key; every other `mcpServers` key and every other top-level key is preserved.)
4. If the target file is absent: create it with `jq -n --arg n "$name" --argjson e "$entry" '{mcpServers:{($n):$e}}'` (mkdir -p the `.cursor/` dir first).
5. `--dry-run`: print `would_write=<target>` and exit 0 without writing.
6. On success print `merged=<target> name=<name>` and exit 0.

Use the AD-19 helper-function carve-out for the jq+mv chain (define a
`_write_atomic` function) so no inline call-site trips AP-009.

### 2. Add `--mcp-config` mode to `scripts/dispatch/adapters/runtime/cursor.sh`

Mirror the existing `--hook-config` block (at ~line 236). Add `--mcp-config` to
the arg parser (`MODE="mcp-config"`) and a new mode block BEFORE the final "no
recognized mode" error. It emits the `.cursor/mcp.json` server-entry fragment as a
two-line `name=` + `entry=` pair so `install-cursor.sh` can parse it (mirroring how
`--register` emits `count=`):

```bash
# --- MCP-config mode (M034 P03 / FR-10) ---
if [[ "$MODE" = "mcp-config" ]]; then
  # The review-gate stdio MCP server entry for .cursor/mcp.json. Cursor spawns
  # it per session and tears it down on EOF (#Q-5). When --project-dir is given,
  # emit an absolute server path (the staged copy travels with scripts/);
  # otherwise a project-relative default.
  if [[ -n "${PROJECT_DIR:-}" ]] && [[ "${PROJECT_DIR}" != "/" ]]; then
    server_path="${PROJECT_DIR}/scripts/lifecycle/review-gate-mcp-server.sh"
  else
    server_path="./scripts/lifecycle/review-gate-mcp-server.sh"
  fi
  echo "name=orchestrator-review-gate"
  echo "entry={\"command\":\"bash\",\"args\":[\"${server_path}\"]}"
  exit 0
fi
```

Also extend the adapter's usage/header comment to list `--mcp-config`, and the
final no-mode error message to include it.

### 3. Add a registration stage to `packaging/install/install-cursor.sh`

Insert a new stage AFTER the Stage 3 hooks-wiring block (~line 315, before Stage
3.5 git pre-commit). Mirror the hooks-wiring shape but call the merge helper
(D-P03-4 — merge, not preserve-with-WARN):

```bash
# --- 3.6 MCP review-gate server registration (M009 FR-6 -> M034 FR-10). ---
# Register the orchestrator review-gate stdio MCP server in .cursor/mcp.json via
# a NON-CLOBBERING merge (CON-6): operator MCP servers are preserved; only our
# `orchestrator-review-gate` entry is set/replaced (idempotent). A malformed
# operator mcp.json fails closed (the merge helper exits 2; we WARN + skip).
log "registering review-gate MCP server via adapter --mcp-config + merge-mcp-config.sh"
mcp_wired=0
mcp_out="$(bash "$ADAPTER" --mcp-config --project-dir "$PROJECT_DIR" 2>/dev/null)"
mcp_name="$(printf '%s\n' "$mcp_out" | sed -n 's/^name=//p' | head -n 1)"
mcp_entry="$(printf '%s\n' "$mcp_out" | sed -n 's/^entry=//p' | head -n 1)"
mcp_target="$PROJECT_DIR/.cursor/mcp.json"
if [ -z "$mcp_name" ] || [ -z "$mcp_entry" ]; then
  echo "WARN: adapter --mcp-config produced no server entry; skipping MCP registration" >&2
elif [ "$DRY_RUN" = "1" ]; then
  bash "$REPO_ROOT/scripts/lifecycle/merge-mcp-config.sh" \
    --target "$mcp_target" --name "$mcp_name" --entry "$mcp_entry" --dry-run || true
  mcp_wired=1
else
  if bash "$REPO_ROOT/scripts/lifecycle/merge-mcp-config.sh" \
       --target "$mcp_target" --name "$mcp_name" --entry "$mcp_entry"; then
    mcp_wired=1
  else
    echo "WARN: merge-mcp-config.sh failed (malformed operator mcp.json?); preserving operator file, mcp_wired=0" >&2
  fi
fi
```

Add `mcp_wired=${mcp_wired}` to the final `SUMMARY:` line (~line 595).

### 4. Co-author `tools/verify/m034-p03-registration.sh`

Hermetic verifier (scratch `.cursor/mcp.json`), asserting FR-10/CON-6:
1. **create** — merge into an absent target → file created with exactly our
   `mcpServers.orchestrator-review-gate` entry.
2. **preserve** — seed a target with an operator entry
   (`{"mcpServers":{"operator-thing":{"command":"x"}}}`), merge → BOTH
   `operator-thing` AND `orchestrator-review-gate` present (operator entry
   byte-intact; assert via `jq -e '.mcpServers["operator-thing"].command=="x"'`).
3. **idempotent** — merge twice → exactly one `orchestrator-review-gate` key
   (`jq '.mcpServers | keys | length'` unchanged on the second run).
4. **fail-closed** — seed a malformed target (`{not json`), merge → exit 2 and the
   file is UNCHANGED (operator content preserved).
5. **wiring** — assert `install-cursor.sh` references `merge-mcp-config.sh` and
   `cursor.sh` references `mcp-config` (the install path is wired).

Print `PASS: m034-p03 registration` / `FAIL: m034-p03 registration — <reason>`.

## Must-Haves

- `scripts/lifecycle/merge-mcp-config.sh` merges non-clobbering + idempotent into `.cursor/mcp.json`, creates an absent target, and fails closed on malformed JSON.
- `cursor.sh --mcp-config` emits a `name=`/`entry=` server fragment for `orchestrator-review-gate`.
- `install-cursor.sh` calls `merge-mcp-config.sh` in a registration stage and reports `mcp_wired=` in its SUMMARY.

## Verification

```bash
bash tools/verify/m034-p03-registration.sh
```

## Inputs

### From Disk (Pre-existing)
- `scripts/dispatch/adapters/runtime/cursor.sh` — modes parsed in a `while`/`case` (`--probe`/`--register`/`--hook-config`); `MODE` dispatched in sequential `if [[ "$MODE" = … ]]` blocks; `PROJECT_DIR` already parsed. The `--hook-config` block (~line 236) emits a heredoc fragment + `exit 0` — copy its shape.
- `packaging/install/install-cursor.sh` — Stage 3 (~line 288) wires `.cursor/hooks.json` via `$ADAPTER --hook-config` then writes the file; `$ADAPTER` = the cursor runtime adapter; `$REPO_ROOT` resolved at top; `DRY_RUN`/`PROJECT_DIR`/`log()` in scope; final `SUMMARY:` line at ~line 595.
- `scripts/lifecycle/review-gate-mcp-server.sh` (T01) — the registration target server.

## Constraints

- CON-1: bash 3.2 / POSIX-sh single file; jq permitted. Atomic tmpfile + `mv` for writes; AD-19 carve-out for the jq+mv chain.
- CON-6: MERGE — never overwrite the operator's `.cursor/mcp.json`. Preserve all non-`orchestrator-review-gate` keys. Malformed operator file = fail closed (exit 2, no write).
- D-P03-4: idempotent — a second merge leaves exactly one `orchestrator-review-gate` entry.
- The `install-cursor.sh` edit is ADDITIVE (a new stage + one SUMMARY field); it must not alter the hooks-wiring, git-pre-commit, config-staging, or asset-staging stages.

## Expected Output

See `## Notes`.

## Notes

`bash tools/verify/m034-p03-registration.sh` prints `PASS: m034-p03 registration`
and exits 0 when create / preserve / idempotent / fail-closed all hold and the
install path is wired. Otherwise `FAIL: m034-p03 registration — <reason>` + exit 1.
