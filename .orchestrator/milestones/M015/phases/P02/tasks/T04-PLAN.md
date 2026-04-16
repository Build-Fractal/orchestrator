---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P02"
milestone: "M015"
name: "Remove bridge rule from resolve-root.sh"
depends_on: [T03]
---

## Prerequisites

- Working in repo root: `/Users/brettkellgren/Sites/lakeledger/spec-kit-orchestrator`
- T02 is complete: `.orchestrator/` exists with the full state tree.
- T03 is complete: `.orchestrator/memory/constitution.md` exists, `.specify/memory/` is gone.
- `scripts/state/resolve-root.sh` contains the five-rule resolver from M008:
  - Rule 1: `ORCHESTRATOR_ROOT` env var
  - Rule 2: `state_root` field in `.orchestrator/config.yml` or `.specify/orchestrator/config.yml`
  - Rule 3: `.orchestrator/` directory exists
  - Rule 4: `.specify/orchestrator/` directory exists (bridge — to be removed)
  - Rule 5: default to `.orchestrator/`
- The resolver has a header comment block starting at line 1 that enumerates the five rules.

## Description

Remove the `.specify/orchestrator/` bridge rule (Rule 4) from `scripts/state/resolve-root.sh`. Renumber the former Rule 5 to Rule 4 without changing its behavior. Update the header comment block to reflect the new four-rule ordering. Also remove `.specify/orchestrator/config.yml` from Rule 2's config-file probe list — after this cutover, no config file ever lives at that path.

The resolver's semantics for rules 1, 2 (first candidate `.orchestrator/config.yml`), 3, and 5-becomes-4 (default) are UNCHANGED. Only the bridge rule and the secondary config-file probe are removed.

This task only modifies `scripts/state/resolve-root.sh`. The resolver's downstream consumers (auto.md, dispatch scripts, diagnostics) are updated by T05's reference sweep.

## Steps

1. Read the current content of `scripts/state/resolve-root.sh` to confirm the line ranges are as expected (Rule 4 block at lines 78–82 in the pre-modification file; five-rule enumeration in the header at lines 5–9).

2. Rewrite `scripts/state/resolve-root.sh` to the exact content below. This is a full-file rewrite, not a surgical patch — the changes touch the header comment, the config-file probe list, the rule numbering, and the rule-4 removal, so a full rewrite is cleaner than multiple Edits.

   ```bash
   #!/usr/bin/env bash
   # scripts/state/resolve-root.sh — Resolve the orchestrator state root.
   #
   # Resolution precedence (highest first):
   #   1. ORCHESTRATOR_ROOT env var (explicit override)
   #   2. state_root field in .orchestrator/config.yml
   #   3. .orchestrator/ directory (standalone canonical)
   #   4. Default: .orchestrator/ (new projects)
   #
   # Usage:
   #   resolve-root.sh                  -> emits repo-relative root to stdout
   #   resolve-root.sh --verbose        -> emits "root=<path>" plus "source=<precedence-rule>"
   #   resolve-root.sh --absolute       -> emits absolute path to stdout
   #
   # Exit: 0 on success. 1 on malformed argument.
   # Bash 3.2 compatible (MEM001).

   set -u

   VERBOSE=0
   ABSOLUTE=0

   while [[ $# -gt 0 ]]; do
     case "$1" in
       --verbose) VERBOSE=1; shift ;;
       --absolute) ABSOLUTE=1; shift ;;
       -h|--help)
         sed -n '2,16p' "$0"
         exit 0 ;;
       *)
         echo "ERROR: unknown argument '$1'" >&2
         exit 1 ;;
     esac
   done

   # Determine repo root. Walk up from $PWD looking for .git.
   repo_root="$PWD"
   while [[ "$repo_root" != "/" ]]; do
     if [[ -d "$repo_root/.git" ]] || [[ -f "$repo_root/.git" ]]; then
       break
     fi
     repo_root="$(dirname "$repo_root")"
   done
   if [[ "$repo_root" = "/" ]]; then
     repo_root="$PWD"
   fi

   resolved=""
   source_rule=""

   # Rule 1: env var
   if [[ -n "${ORCHESTRATOR_ROOT:-}" ]]; then
     resolved="$ORCHESTRATOR_ROOT"
     source_rule="env:ORCHESTRATOR_ROOT"
   fi

   # Rule 2: config file state_root field
   if [[ -z "$resolved" ]]; then
     cfg="$repo_root/.orchestrator/config.yml"
     if [[ -f "$cfg" ]]; then
       candidate="$(grep -E '^state_root:' "$cfg" 2>/dev/null | head -n 1 | sed -E 's/^state_root:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/')"
       if [[ -n "$candidate" ]]; then
         resolved="$candidate"
         source_rule="config:$cfg"
       fi
     fi
   fi

   # Rule 3: .orchestrator/ exists
   if [[ -z "$resolved" ]] && [[ -d "$repo_root/.orchestrator" ]]; then
     resolved=".orchestrator"
     source_rule="existing:.orchestrator"
   fi

   # Rule 4: default
   if [[ -z "$resolved" ]]; then
     resolved=".orchestrator"
     source_rule="default"
   fi

   # Strip trailing slash if any
   resolved="${resolved%/}"

   if [[ "$ABSOLUTE" = "1" ]]; then
     case "$resolved" in
       /*) : ;;
       *)  resolved="$repo_root/$resolved" ;;
     esac
   fi

   if [[ "$VERBOSE" = "1" ]]; then
     echo "root=$resolved"
     echo "source=$source_rule"
   else
     echo "$resolved"
   fi
   ```

3. Confirm file is executable: `chmod +x scripts/state/resolve-root.sh` (it was already executable; this is a no-op but harmless).

4. Run the T01-written no-bridge verifier:

   ```
   bash scripts/verify/m015-p02-resolver-no-bridge.sh
   ```

   Expected: `PASS: resolver has no bridge rule`. Exit 0.

5. Run the T01-written resolver-resolves-new verifier:

   ```
   bash scripts/verify/m015-p02-resolver-resolves-new.sh
   ```

   Expected: `PASS: resolver resolves to .orchestrator via existing:.orchestrator rule`. Exit 0.

6. Sanity-check the resolver directly. All three commands below must exit 0:

   ```
   bash scripts/state/resolve-root.sh
   bash scripts/state/resolve-root.sh --verbose
   bash scripts/state/resolve-root.sh --absolute
   ```

   The first emits `.orchestrator`. The second emits `root=.orchestrator` and `source=existing:.orchestrator`. The third emits an absolute path ending in `/.orchestrator`.

## Must-Haves

- `scripts/state/resolve-root.sh` no longer contains the bridge rule (Rule 4): no `bridge:.specify/orchestrator` string, no directory test against `.specify/orchestrator`, no resolved assignment to `.specify/orchestrator`, no "migration bridge" phrase in the header.
- `scripts/state/resolve-root.sh` no longer probes `.specify/orchestrator/config.yml` in Rule 2 — only `.orchestrator/config.yml`.
- The resolver correctly emits `root=.orchestrator` + `source=existing:.orchestrator` when run from the repo root with no env overrides.
- `bash scripts/verify/m015-p02-resolver-no-bridge.sh` PASSes.
- `bash scripts/verify/m015-p02-resolver-resolves-new.sh` PASSes.

## Verification

Run:

```
bash scripts/verify/m015-p02-resolver-no-bridge.sh
bash scripts/verify/m015-p02-resolver-resolves-new.sh
```

Each must print a `PASS:` line and exit 0.

## Inputs

### From Previous Tasks

- `scripts/verify/m015-p02-resolver-no-bridge.sh` (from T01)
  - Key API: takes no arguments. Exit 0 with `PASS: resolver has no bridge rule` on success.
  - Behavioral contract: greps `scripts/state/resolve-root.sh` for absence of `bridge:.specify/orchestrator`, the directory test `-d "$repo_root/.specify/orchestrator"`, the assignment `resolved=".specify/orchestrator"`, and the phrase `migration bridge`.

- `scripts/verify/m015-p02-resolver-resolves-new.sh` (from T01)
  - Key API: takes no arguments. Exit 0 with `PASS: resolver resolves to .orchestrator via existing:.orchestrator rule` on success.
  - Behavioral contract: runs `bash scripts/state/resolve-root.sh --verbose` with `ORCHESTRATOR_ROOT` unset, asserts stdout contains `root=.orchestrator` and `source=existing:.orchestrator`.

### From Disk (Pre-existing)

- `scripts/state/resolve-root.sh` — five-rule resolver from M008. Rewrite to the four-rule form in Step 2.
- `.orchestrator/config.yml` — exists after T02 with `state_root: ".orchestrator"`. Rule 2 of the new resolver reads this file.
- `.orchestrator/` directory — exists after T02. Rule 3 of the new resolver matches this.

## Constraints

- Preserve Bash 3.2 compatibility: no `declare -A`, no `mapfile`, no `${var,,}` casing.
- Preserve the exact stdout format: `<path>` on default, `root=<path>\nsource=<rule>` on `--verbose`, absolute path on `--absolute`. Downstream consumers parse these shapes.
- Preserve rule semantics for rules 1, 3, and default (formerly 5): no behavioral change.
- Preserve rule 2's semantics for the `.orchestrator/config.yml` candidate. Only remove the second candidate (`.specify/orchestrator/config.yml`) from the probe list, because no config file will ever live at that path post-cutover.
- Preserve the `source=` rule label strings: `env:ORCHESTRATOR_ROOT`, `config:<path>`, `existing:.orchestrator`, `default`. Downstream consumers (including tests) may match on these literals.
- Update the `sed -n '2,17p'` line-range in the `--help` branch to match the new header block length (line 2 through line 16 in the rewritten file). If the rewritten header is exactly 16 lines + the `set -u` line, use `sed -n '2,16p'`.
- Do NOT add any new rule. The resolver is strictly simpler after this task, not more complex.
- Do NOT touch any other file in this task.

## Expected Output

After this task:
- `git status` shows `scripts/state/resolve-root.sh` modified.
- `git diff scripts/state/resolve-root.sh` shows removal of the Rule 4 block, removal of `.specify/orchestrator/config.yml` from the config probe loop, renumbering of the former Rule 5 comment to Rule 4, and header comment update from five rules to four.
- `bash scripts/verify/m015-p02-resolver-no-bridge.sh` prints `PASS: resolver has no bridge rule`.
- `bash scripts/verify/m015-p02-resolver-resolves-new.sh` prints `PASS: resolver resolves to .orchestrator via existing:.orchestrator rule`.
- `bash scripts/state/resolve-root.sh --verbose` prints:
  ```
  root=.orchestrator
  source=existing:.orchestrator
  ```
