---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P04"
milestone: "M024"
name: "auto_proceed config key — defaults file + read-config.sh valid-keys"
depends_on: []
---

## Prerequisites

- P01 complete: the `.orchestrator/intake/<id>/proposal.md` shape exists; the proposal frontmatter already carries `auto_proceeded: <bool>` and `proceeded_at: <iso8601-or-null>` keys (P01 + P03 wiring).
- `scripts/state/read-config.sh` exists at HEAD with the four-layer (env > local > project > defaults) resolver and a `VALID_KEYS` constant.
- `templates/orchestrator-config-default.yml` exists at HEAD with the existing top-level keys (`default_tier`, `verification_commands`, etc.) and an `autonomy:` block.

## Description

Add `auto_proceed` to the `VALID_KEYS` constant in `scripts/state/read-config.sh` and ship the default in `templates/orchestrator-config-default.yml`. This is **purely additive plumbing** — no resolver code changes, no behavior change in any other script. The existing `read_yaml_value` helper handles the new key as-is; the existing four-layer precedence (env > local > project > defaults) applies.

The key is named `auto_proceed` (not `evaluate.auto_proceed` despite the spec's prose) because:

1. The current `read-config.sh` `VALID_KEYS` shape is a flat space (`default_tier`, `dispatch_budget`, `budget_enforcement`, etc.) — there is no nested-block resolver path for top-level keys (the `autonomy:` block is the existing exception, with its own resolver hooks; we are not adding a second exception in P04).
2. The CLI shape is `read-config.sh auto_proceed` — flat key matches existing call sites.
3. Within `templates/orchestrator-config-default.yml` the key lives at the top level with an inline comment naming the FR-3 / NG-6 fast-path semantics. The spec's `evaluate.auto_proceed` naming is honored at the documentation surface (the comment block) but the resolver key itself is the flat `auto_proceed`. AD-17 — document actual behavior, do not invent new resolver semantics.

The default ships as `true` (FR-3: auto-proceed default-on). Operators disable it with `auto_proceed: false` in `orchestrator-config.yml`.

## Steps

1. **Edit `scripts/state/read-config.sh`** — extend the `VALID_KEYS` constant (currently a single space-separated string) to include `auto_proceed`. Locate the line that reads:

   ```bash
   VALID_KEYS="default_tier verification_commands context_verbosity git_isolation dispatch_budget duration_budget budget_enforcement session_weight_limit"
   ```

   and replace with:

   ```bash
   VALID_KEYS="default_tier verification_commands context_verbosity git_isolation dispatch_budget duration_budget budget_enforcement session_weight_limit auto_proceed"
   ```

   No other code changes — the existing `key_valid` loop, the existing `read_yaml_value` helper, and the existing env-var path (`SPECKIT_ORCHESTRATOR_AUTO_PROCEED`) all handle the new key as-is.

2. **Edit `templates/orchestrator-config-default.yml`** — add a new top-level block immediately above the `autonomy:` block:

   ```yaml
   # Universal intake routing fast-path (M024 — FR-3, NG-6, #Q-7)
   # When auto_proceed is true (default) AND a proposal lands at all four:
   #   scope_tier == "A"        AND
   #   intensity == "Quick"     AND
   #   conversus_gate == "none" AND
   #   design_gate == "none"
   # …`orchestrator:evaluate` flips `auto_proceeded: true` in the emitted
   # proposal frontmatter and dispatches without an approval prompt. Any
   # condition violation (or this key set to false) routes the proposal
   # through the operator approve / revise / cancel gate as before.
   #
   # Set to false project-wide to disable the fast-path entirely (every
   # proposal halts at the approval gate). Per AD-1 there is no per-invocation
   # CLI flag — this is a project-config-only knob (#Q-7).
   auto_proceed: true              # true (default) | false
   ```

3. **Author the per-task verifies.** Two single-script-file verifies cover this task:

   **`scripts/verify/m024-p04-config-auto-proceed-key.sh`** — exercises the four-layer resolver against a tmp project with each layer in turn.

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m024-p04-config-auto-proceed-key.sh
   # Verifies auto_proceed is a valid config key resolved through all four layers.

   set -u
   ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   READ="$ROOT/scripts/state/read-config.sh"
   DEFAULTS="$ROOT/templates/orchestrator-config-default.yml"

   [ -x "$READ" ]      || { echo "FAIL: $READ not executable"; exit 1; }
   [ -f "$DEFAULTS" ]  || { echo "FAIL: $DEFAULTS not present"; exit 1; }

   tmp="$(mktemp -d)"
   trap 'rm -rf "$tmp"' EXIT

   # Layer 4 (defaults) — must return true.
   v=$(bash "$READ" auto_proceed --defaults "$DEFAULTS")
   [ "$v" = "true" ] || { echo "FAIL: defaults layer returned '$v', expected 'true'"; exit 1; }

   # Layer 3 (project) override — false wins.
   project="$tmp/orchestrator-config.yml"
   echo "auto_proceed: false" > "$project"
   v=$(bash "$READ" auto_proceed --defaults "$DEFAULTS" --project "$project")
   [ "$v" = "false" ] || { echo "FAIL: project layer returned '$v', expected 'false'"; exit 1; }

   # Layer 2 (local) override — true wins back.
   local_cfg="$tmp/orchestrator-config.local.yml"
   echo "auto_proceed: true" > "$local_cfg"
   v=$(bash "$READ" auto_proceed --defaults "$DEFAULTS" --project "$project" --local "$local_cfg")
   [ "$v" = "true" ] || { echo "FAIL: local layer returned '$v', expected 'true'"; exit 1; }

   # Layer 1 (env) override — false wins.
   v=$(SPECKIT_ORCHESTRATOR_AUTO_PROCEED=false bash "$READ" auto_proceed --defaults "$DEFAULTS" --project "$project" --local "$local_cfg")
   [ "$v" = "false" ] || { echo "FAIL: env layer returned '$v', expected 'false'"; exit 1; }

   echo "PASS: read-config.sh — auto_proceed resolves through all four layers (defaults true; project/local/env override)"
   exit 0
   ```

   **`scripts/verify/m024-p04-config-template.sh`** — asserts the defaults template documents the key inline.

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m024-p04-config-template.sh
   # Verifies templates/orchestrator-config-default.yml ships auto_proceed: true
   # with the inline documentation block.

   set -u
   ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   F="$ROOT/templates/orchestrator-config-default.yml"

   [ -f "$F" ] || { echo "FAIL: $F missing"; exit 1; }

   grep -q '^auto_proceed: true' "$F" \
     || { echo "FAIL: auto_proceed: true default not present in $F"; exit 1; }

   grep -q 'fast-path' "$F" \
     || { echo "FAIL: defaults file missing inline 'fast-path' documentation comment"; exit 1; }

   grep -q 'FR-3' "$F" \
     || { echo "FAIL: defaults file missing FR-3 anchor in inline documentation"; exit 1; }

   echo "PASS: orchestrator-config-default.yml — auto_proceed default + FR-3 inline doc present"
   exit 0
   ```

4. **Make verifies executable**: `chmod +x scripts/verify/m024-p04-config-auto-proceed-key.sh` and `chmod +x scripts/verify/m024-p04-config-template.sh` (two single-script-file commands; do not chain).

## Must-Haves

- `scripts/state/read-config.sh` `VALID_KEYS` constant contains `auto_proceed` as a space-delimited token.
- `read-config.sh auto_proceed --defaults templates/orchestrator-config-default.yml` returns the literal string `true` (no `null`, no error).
- `templates/orchestrator-config-default.yml` contains a line `^auto_proceed: true$` and an inline comment naming "fast-path" and `FR-3`.
- All four resolver layers (env / local / project / defaults) work for the new key without any code change beyond the `VALID_KEYS` extension.
- AD-19 single-script-file shape: every external command in the verifies is a top-level invocation; no inline compound bash, no plain subshells, no `$(... | ...)`.

## Verification

```
bash scripts/verify/m024-p04-config-auto-proceed-key.sh
bash scripts/verify/m024-p04-config-template.sh
```

Each exits 0 with `PASS: read-config.sh — auto_proceed resolves through all four layers (defaults true; project/local/env override)` and `PASS: orchestrator-config-default.yml — auto_proceed default + FR-3 inline doc present` respectively.

## Inputs

### From Previous Tasks

- None. T01 is the first task in P04 and depends only on pre-existing P01 / pre-M024 infrastructure.

### From Disk (Pre-existing)

- `scripts/state/read-config.sh` — pre-existing four-layer config resolver. Key API: `read-config.sh <key> [--defaults <file>] [--project <file>] [--local <file>]` returns the resolved value to stdout, or `null` if unresolved. The `VALID_KEYS` constant on line 17 gates accepted keys; an unknown key exits 1 with `unknown config key '<key>'`.
- `templates/orchestrator-config-default.yml` — pre-existing defaults file consumed by the resolver's layer 4. Top-level flat keys (`default_tier`, `verification_commands`, etc.) plus a nested `autonomy:` block.
- `sed -i.bak`, `grep`, `cat`, `mktemp`, environment variable substitution — POSIX utilities.

## Constraints

- POSIX sh + bash 3.2 portable. No `declare -A`. No `[[ ]]` extensions in the verify script bodies (the existing `read-config.sh` uses `[[ ]]` already; we do not change that).
- Writes only to `scripts/state/read-config.sh` and `templates/orchestrator-config-default.yml` (SB-3).
- AD-19 single-script-file shape: every external invocation is a top-level command; no inline compound bash, no plain subshells, no `$(... | ...)` containing pipes.
- No new resolver code path. The existing `read_yaml_value` + four-layer precedence handles the key.
- AD-1 commit: project-config-only knob, no CLI flag (#Q-7).
- AD-17: document actual behavior (the resolver is flat-key only at the top level; the inline comment block in the defaults file documents the fast-path semantics in prose, not via a nested `evaluate:` resolver block).

## Expected Output

`scripts/state/read-config.sh` and `templates/orchestrator-config-default.yml` are modified; the two T01 verifies (`m024-p04-config-auto-proceed-key.sh`, `m024-p04-config-template.sh`) exist, are executable, and both exit 0 with `PASS:` lines.
