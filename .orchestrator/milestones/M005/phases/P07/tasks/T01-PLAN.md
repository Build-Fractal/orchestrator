---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P07"
milestone: "M005"
name: "Autonomy defaults + config schema"
depends_on: []
---

## Description

Create the declarative autonomy policy file, wire it into the orchestrator
config defaults, and register the three new P07 scripts + `autonomy` config
block in `extension.yml`. This task is pure data + manifest changes. No
runtime behavior is introduced — every script P07 will ship in T02/T03 reads
from files produced here.

Per Constitution Principle X (Templating Over Inference) and Principle XI
(Single Source of Truth): policy lives in `templates/autonomy-defaults.yaml`,
mechanics live in scripts. The generator in T02 must have **zero hardcoded
policy** — it reads every rule from this file.

Architectural decisions that constrain this task:
- **AD-8**  Policy in templates, mechanics in scripts.
- **AD-14** Policy file conforms to the same YAML schema constraints as
  `templates/context-recipe.yaml`: max 2 levels of nesting, comma-separated
  inline arrays, parseable without jq by `scripts/lib/recipe-parser.sh`.
- **AD-16** Canonical permissions format v1 is Claude-Code-shaped + metadata.
  The baseline deny / allow lists here are directly emitted by the generator
  into the `permissions.allow` / `permissions.deny` arrays of the canonical
  envelope.
- **AD-20** Baseline allow list MUST include `/tmp/**` and macOS
  `/var/folders/**` read/write patterns plus `Read(//tmp/**)`,
  `Read(//private/tmp/**)`, `Read(//var/folders/**)`.
- **AD-21** Baseline allow list MUST include `ORCH_*=* bash scripts/*`,
  two-variable form, and `.specify/*` equivalents.
- **AD-17** The `.local` override semantics for the autonomy block should be
  key-by-key deep merge. This task must **read** the existing config
  resolution behavior in `scripts/state/read-config.sh` and document whatever
  the current semantics are in `templates/orchestrator-config-default.yml`
  comments. If the current behavior is replace-instead-of-merge, the docs
  here state that.

## Steps

### Step 1 — Create `templates/autonomy-defaults.yaml`

Create a new file at `templates/autonomy-defaults.yaml` with the structure
below. **Schema constraint**: max 2 levels of nesting. Arrays are inline
(comma-separated) when short, block (one-per-line with leading `- `) when
long. Parseable by `scripts/lib/recipe-parser.sh` without jq.

```yaml
# templates/autonomy-defaults.yaml — declarative autonomy policy
#
# Single source of truth for tier→mode mapping, baseline deny list, baseline
# allow list, and introspection rules. Consumed by:
#   - scripts/lifecycle/generate-permissions.sh (reads every section)
#   - scripts/diagnostics/check-permissions.sh  (compares against current state)
#
# Constitution: Principle X (Templating Over Inference), Principle XI (Single
# Source of Truth). Zero hardcoded policy in any script.
#
# Schema: max 2 levels of nesting, inline or block arrays (jq-free).
# Same constraints as templates/context-recipe.yaml.

schema_version: "1.0"

# Tier → autonomy mode mapping (FR-1, AD-7)
# minimal  = Tier A default — only essential reads/edits, no unattended bash
# standard = Tier B default — common toolchains + read/write scripts/
# full     = Tier C default — comprehensive allow list for unattended auto mode
tier_defaults:
  A: minimal
  B: standard
  C: full

# Tier → Claude Code defaultMode mapping
default_mode:
  minimal: default
  standard: acceptEdits
  full: acceptEdits

# Baseline deny list (AD-7: safety via explicit enumeration, never bypass)
# Applies to every mode. Projects can extend via autonomy.deny_patterns,
# cannot remove baseline entries via config. User-authored settings.json files
# keep their own deny list intact (AD-13: additive merge only).
baseline_deny:
  - "Bash(rm -rf /)"
  - "Bash(rm -rf /*)"
  - "Bash(rm -rf ~)"
  - "Bash(rm -rf ~/*)"
  - "Bash(rm -rf $HOME)"
  - "Bash(rm -rf $HOME/*)"
  - "Bash(sudo *)"
  - "Bash(chmod 777 *)"
  - "Bash(chmod -R 777 *)"
  - "Bash(dd *)"
  - "Bash(mkfs *)"
  - "Bash(mkfs.* *)"
  - "Bash(> /dev/sda*)"
  - "Bash(> /dev/disk*)"
  - "Bash(git push --force *)"
  - "Bash(git push -f *)"
  - "Bash(git push * --force*)"
  - "Bash(git push * -f*)"
  - "Bash(git reset --hard origin/*)"
  - "Bash(git reset --hard upstream/*)"
  - "Bash(git clean -fdx*)"
  - "Bash(git branch -D main)"
  - "Bash(git branch -D master)"
  - "Bash(curl * | bash*)"
  - "Bash(curl * | sh*)"
  - "Bash(wget * | bash*)"
  - "Bash(wget * | sh*)"
  - "Bash(curl * | sudo*)"
  - "Bash(npm publish*)"
  - "Bash(yarn publish*)"
  - "Bash(pnpm publish*)"
  - "Bash(cargo publish*)"
  - "Bash(pip upload*)"
  - "Bash(twine upload*)"
  - "Bash(gh release create*)"
  - "Bash(gh repo delete*)"

# Baseline allow list — orchestrator-invariant patterns always emitted
# regardless of project state. Includes:
#   - Core tool primitives (Read/Write/Edit/Glob/Grep/Agent/WebFetch)
#   - Skill(speckit.*) for recursive orchestrator invocation
#   - AD-20 system-temp-directory patterns (/tmp, /var/folders, /private/tmp)
#   - AD-21 env-prefixed orchestrator script invocation patterns
#   - Shell builtins (export, source, flow control, test)
baseline_allow:
  - "Read"
  - "Write"
  - "Edit"
  - "Glob"
  - "Grep"
  - "Agent"
  - "WebSearch"
  - "WebFetch"
  - "NotebookEdit"
  - "Skill(speckit.*)"
  - "Skill(speckit.orchestrator.*)"
  # --- AD-20: system temp directories ---
  - "Read(//tmp/**)"
  - "Read(//private/tmp/**)"
  - "Read(//var/folders/**)"
  - "Bash(cat /tmp/*)"
  - "Bash(cat > /tmp/*)"
  - "Bash(cat >> /tmp/*)"
  - "Bash(ls /tmp/*)"
  - "Bash(ls /tmp)"
  - "Bash(ls /var/folders/*)"
  - "Bash(ls /private/tmp/*)"
  - "Bash(find /tmp/*)"
  - "Bash(find /var/folders/*)"
  - "Bash(find /private/tmp/*)"
  - "Bash(head /tmp/*)"
  - "Bash(tail /tmp/*)"
  - "Bash(wc /tmp/*)"
  - "Bash(wc -l /tmp/*)"
  - "Bash(grep /tmp/*)"
  - "Bash(stat /tmp/*)"
  - "Bash(rm -f /tmp/*)"
  - "Bash(rm -rf /tmp/*)"
  # --- AD-21: env-prefixed orchestrator script invocation ---
  - "Bash(ORCH_*=* bash scripts/*)"
  - "Bash(ORCH_*=* ORCH_*=* bash scripts/*)"
  - "Bash(ORCH_*=* bash .specify/*)"
  - "Bash(ORCH_*=* ORCH_*=* bash .specify/*)"
  - "Bash(ORCH_*=* bash ./scripts/*)"
  - "Bash(ORCH_*=* ORCH_*=* bash ./scripts/*)"
  # --- orchestrator script paths ---
  - "Bash(bash scripts/*)"
  - "Bash(bash .specify/*)"
  - "Bash(bash ./scripts/*)"
  - "Bash(bash ./.specify/*)"
  - "Bash(sh scripts/*)"
  # --- compound-command destinations (the output=$(...) idiom) ---
  - "Bash(output=*)"
  - "Bash(result=*)"
  - "Bash(exit_code=*)"
  - "Bash(status=*)"
  - "Bash(payload=*)"
  - "Bash(state=*)"
  - "Bash(phase=*)"
  - "Bash(task=*)"
  - "Bash(milestone=*)"
  - "Bash(tier=*)"
  - "Bash(count=*)"
  - "Bash(path=*)"
  - "Bash(file=*)"
  - "Bash(dir=*)"
  - "Bash(name=*)"
  - "Bash(value=*)"
  - "Bash(config=*)"
  # --- shell builtins + flow control ---
  - "Bash(export *)"
  - "Bash(source *)"
  - "Bash(. *)"
  - "Bash(set *)"
  - "Bash(eval *)"
  - "Bash(exec *)"
  - "Bash(trap *)"
  - "Bash(for *)"
  - "Bash(if *)"
  - "Bash(while *)"
  - "Bash(until *)"
  - "Bash(case *)"
  - "Bash([ *)"
  - "Bash([[ *)"
  - "Bash(test *)"

# Introspection source → allow-pattern rules (FR-2)
# Generator reads each source at runtime and emits the corresponding patterns.
# Missing sources are skipped silently (AD-11: graceful per-source fallback).
introspection:
  extension_yml: "Bash(bash scripts/*)"      # already in baseline, kept for clarity
  package_json_scripts: "Bash(npm run *)"     # plus Bash(yarn *), Bash(pnpm *)
  makefile_targets: "Bash(make *)"
  toolchain_typescript: "Bash(tsc *)"
  toolchain_rust: "Bash(cargo *)"
  toolchain_go: "Bash(go *)"
  toolchain_python: "Bash(python *)"
  toolchain_ruby: "Bash(bundle *)"
  docker_compose: "Bash(docker compose *)"
  supabase: "Bash(supabase *)"

# Agent host marker directories → which writer to invoke (FR-10)
# NOTE: Per AD-10, .gsd/ is intentionally NOT listed.
agent_hosts:
  claude_code: ".claude/"
  cursor: ".cursor/"
  copilot: ".github/copilot/"
```

### Step 2 — Update `templates/orchestrator-config-default.yml`

Read the existing file first to understand the current shape:

```bash
bash scripts/state/read-config.sh default_tier
```

Then append an `autonomy:` block. The final file should look like:

```yaml
# Speckit-Orchestrator Project Configuration
# Copy to orchestrator-config.yml in your project root and customize.
# See extension.yml config_schema for valid values.

default_tier: null              # Auto-detect. Override: A, B, or C
verification_commands: []       # Run after each task (e.g., ["npm test", "npm run lint"])
context_verbosity: standard     # minimal | standard | full
git_isolation: false            # Use git worktree per milestone
dispatch_budget: null           # Max dispatches per milestone (null = unlimited)
duration_budget: null           # Max cumulative duration (null = unlimited, e.g., "2h")
budget_enforcement: advisory    # advisory (warn only) | enforced (hard stop)

# Autonomy permission generation (P07 — FR-1)
# Policy defaults live in templates/autonomy-defaults.yaml (baseline deny,
# baseline allow, tier→mode mapping, introspection rules). This block lets
# projects override or extend those defaults.
#
# Four-layer resolution (FR-1): env > .local > project > defaults. The .local
# override of the autonomy: block uses key-by-key semantics matching the rest
# of read-config.sh — setting only extra_allow leaves mode, generate_on_init,
# and deny_patterns at their project-level values (AD-17).
autonomy:
  mode: null                    # null = tier default (A=minimal, B=standard, C=full). Override: minimal, standard, full
  generate_on_init: true        # Run generate-permissions.sh during evaluate scaffold (FR-7)
  deny_patterns: []             # Extra Bash/Read patterns to append to the baseline deny list
  extra_allow: []               # Extra Bash/Read patterns to append to the baseline allow list
```

**Verification of AD-17 semantics**: before finalizing the docstring, grep
`scripts/state/read-config.sh` to see how other blocks (e.g.,
`verification_commands`) resolve `.local` overrides. If the resolution is
replace-instead-of-merge, change the comment to match. Do not invent new
semantics — describe whatever the existing behavior actually is.

### Step 3 — Update `extension.yml`

Open `extension.yml` and make three additions:

**3a. Register the three new scripts under `provides.scripts`.** Add after
the existing `scripts/diagnostics/check-cost-spikes.sh` entry:

```yaml
    - file: scripts/lifecycle/generate-permissions.sh
      executable: true
    - file: scripts/lifecycle/write-permissions.sh
      executable: true
    - file: scripts/diagnostics/check-permissions.sh
      executable: true
```

**3b. Add `autonomy` to the defaults block.** After `session_weight_limit: 15`:

```yaml
  autonomy:
    mode: null
    generate_on_init: true
    deny_patterns: []
    extra_allow: []
```

**3c. Add the `autonomy` property to `config_schema.properties`.** After the
`session_weight_limit` entry:

```yaml
    autonomy:
      type: object
      description: "Autonomy permission generation (P07). Policy defaults live in templates/autonomy-defaults.yaml."
      properties:
        mode:
          type: [string, "null"]
          enum: [minimal, standard, full, null]
          description: "Autonomy mode. null = tier default (A=minimal, B=standard, C=full)."
        generate_on_init:
          type: boolean
          description: "Run generate-permissions.sh during evaluate scaffold (FR-7)."
        deny_patterns:
          type: array
          items:
            type: string
          description: "Extra Bash/Read patterns appended to baseline_deny from autonomy-defaults.yaml."
        extra_allow:
          type: array
          items:
            type: string
          description: "Extra Bash/Read patterns appended to baseline_allow from autonomy-defaults.yaml."
```

### Step 4 — Run the P07 must-have verification

The phase plan's Truth `Check:` commands need helper scripts that will be
created later in this task (the `scripts/verify/p07-*.sh` set below). Create
them now so T01's verification passes standalone.

## Must-Haves

From phase plan, this task addresses:

- **Truths**: "Autonomy defaults file declares the tier→mode mapping",
  "...includes system-temp-directory patterns", "...includes /var/folders",
  "...includes ORCH_*=* bash scripts", "extension.yml registers
  generate-permissions.sh / write-permissions.sh / check-permissions.sh",
  "extension.yml config_schema declares autonomy", "orchestrator-config-default.yml
  surfaces autonomy", "...documents the four keys".

- **Artifacts**: `templates/autonomy-defaults.yaml`, modified
  `templates/orchestrator-config-default.yml`, modified `extension.yml`, plus
  the five P07 verification helpers below (created here so every subsequent
  task can run `check-must-haves.sh` against the evolving plan state).

## Verification

### Create the five phase-plan helper scripts

The P07 phase plan references five standalone verify scripts as Truth
`Check:` commands. They must exist before any task's Tier 1 verification
passes. Create each one now at `scripts/verify/p07-*.sh` — each is a single
grep/test invocation wrapped in a shebang + exit code. Rationale: per AD-19,
task-plan Truth commands must be single-script-file invocations, not inline
compound bash. Each helper is 10–20 lines.

**`scripts/verify/p07-no-gsd.sh`**
```bash
#!/usr/bin/env bash
# Verifies the P07 generator does NOT emit GSD-specific patterns (AD-10).
# Passes when Skill(gsd:*) / .gsd/ markers are absent from the generator
# script. This is a preventive check — if someone adds GSD patterns to
# generate-permissions.sh, this fails and the phase must-haves fail.
set -eu
f="scripts/lifecycle/generate-permissions.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "Skill(gsd" "$f" && { echo "FAIL: $f contains Skill(gsd pattern (AD-10 violation)"; exit 1; }
grep -q "\.gsd/" "$f" && { echo "FAIL: $f contains .gsd/ reference (AD-10 violation)"; exit 1; }
echo "PASS: no GSD patterns in $f"
```

**`scripts/verify/p07-no-bypass.sh`**
```bash
#!/usr/bin/env bash
# Verifies the generator never defaults to bypassPermissions (AD-7).
# Also verifies autonomy-defaults.yaml default_mode values are the closed
# enum {default, acceptEdits} — never bypassPermissions.
set -eu
gen="scripts/lifecycle/generate-permissions.sh"
defaults="templates/autonomy-defaults.yaml"
test -f "$gen" || { echo "FAIL: $gen missing"; exit 1; }
test -f "$defaults" || { echo "FAIL: $defaults missing"; exit 1; }
grep -q "bypassPermissions" "$gen" && { echo "FAIL: $gen references bypassPermissions (AD-7)"; exit 1; }
grep -q "bypassPermissions" "$defaults" && { echo "FAIL: $defaults references bypassPermissions (AD-7)"; exit 1; }
echo "PASS: no bypassPermissions in $gen or $defaults"
```

**`scripts/verify/p07-merge-additive.sh`**
```bash
#!/usr/bin/env bash
# Verifies write-permissions.sh uses additive-only merge semantics (AD-13).
# Passes when the script contains the word "additive" in a comment AND
# references the _generated_by marker (used to detect user-authored files).
set -eu
f="scripts/lifecycle/write-permissions.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "additive" "$f" || { echo "FAIL: $f missing 'additive' comment (AD-13)"; exit 1; }
grep -q "_generated_by" "$f" || { echo "FAIL: $f missing _generated_by check"; exit 1; }
echo "PASS: $f implements additive merge (AD-13)"
```

**`scripts/verify/p07-tier-modes.sh`**
```bash
#!/usr/bin/env bash
# Verifies templates/autonomy-defaults.yaml declares tier_defaults mapping
# with the three canonical modes (minimal, standard, full).
set -eu
f="templates/autonomy-defaults.yaml"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "tier_defaults:" "$f" || { echo "FAIL: $f missing tier_defaults block"; exit 1; }
grep -q "minimal" "$f" || { echo "FAIL: $f missing 'minimal' mode"; exit 1; }
grep -q "standard" "$f" || { echo "FAIL: $f missing 'standard' mode"; exit 1; }
grep -q "full" "$f" || { echo "FAIL: $f missing 'full' mode"; exit 1; }
echo "PASS: $f declares tier_defaults with all three modes"
```

**`scripts/verify/p07-config-keys.sh`**
```bash
#!/usr/bin/env bash
# Verifies templates/orchestrator-config-default.yml documents the four
# autonomy config keys: mode, generate_on_init, deny_patterns, extra_allow.
set -eu
f="templates/orchestrator-config-default.yml"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "autonomy:" "$f" || { echo "FAIL: $f missing autonomy: block"; exit 1; }
grep -q "mode:" "$f" || { echo "FAIL: $f missing mode: key"; exit 1; }
grep -q "generate_on_init:" "$f" || { echo "FAIL: $f missing generate_on_init: key"; exit 1; }
grep -q "deny_patterns:" "$f" || { echo "FAIL: $f missing deny_patterns: key"; exit 1; }
grep -q "extra_allow:" "$f" || { echo "FAIL: $f missing extra_allow: key"; exit 1; }
echo "PASS: $f documents all four autonomy keys"
```

`chmod +x scripts/verify/p07-*.sh` after creating all five.

### Tier 1 Verification

After writing the four files above (yaml, config default, extension.yml) and
the five verify helpers, run:

```bash
bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M005/phases/P07
```

At this point only the T01-scoped Truths will pass; the Truths covered by
T02/T03/T04/T05 will FAIL until those tasks run. That's expected. T01 is
complete when every Truth that references only the files in "Files Touched
By This Task" below passes.

### Files Touched By This Task

- `templates/autonomy-defaults.yaml` (create)
- `templates/orchestrator-config-default.yml` (modify — add `autonomy:` block)
- `extension.yml` (modify — register 3 scripts, add autonomy defaults, add config_schema entry)
- `scripts/verify/p07-no-gsd.sh` (create)
- `scripts/verify/p07-no-bypass.sh` (create)
- `scripts/verify/p07-merge-additive.sh` (create)
- `scripts/verify/p07-tier-modes.sh` (create)
- `scripts/verify/p07-config-keys.sh` (create)

## Inputs

### From Previous Tasks

None — T01 is the phase entry point.

### From Disk (Pre-existing)

- `scripts/state/read-config.sh` — consult this to verify AD-17 `.local`
  override semantics before writing the autonomy block docstring in
  `templates/orchestrator-config-default.yml`. Use the actual behavior, do
  not assume deep-merge if the existing logic is replace.
- `scripts/lib/recipe-parser.sh` — T02 will read `autonomy-defaults.yaml`
  via this parser. T01 must produce YAML compatible with it:
    - Max 2 levels of nesting.
    - 2-space indent.
    - Top-level keys: `schema_version`, `tier_defaults`, `default_mode`,
      `baseline_deny`, `baseline_allow`, `introspection`, `agent_hosts`.
    - Arrays use `- "value"` one-per-line form (parser's proven shape).
    - Strings are double-quoted. No multi-line scalars. No anchors/aliases.
  The parser API T02 will call against this file:
    - `read_recipe_field <file> "tier_defaults.C"` → returns `"full"`.
    - `read_recipe_field <file> "default_mode.full"` → returns `"acceptEdits"`.
    - For array sections (baseline_deny, baseline_allow), T02 reads them as
      line-by-line greps rather than via the parser's nested field reader.
- `templates/claude-settings.json` (commit `50f7098`, with GSD removed) —
  the AD-16 canonical envelope is this file's shape plus provenance markers.
  Use its existing deny/allow lists as the source of truth for the
  `baseline_deny` / `baseline_allow` arrays in `autonomy-defaults.yaml`.
  Do not re-derive the lists from scratch — they have already been audited
  and expanded through M004.
- `extension.yml` — current structure: top-level `schema_version`,
  `extension`, `requires`, `provides.{commands,config,scripts}`, `defaults`,
  `config_schema.properties`, `hooks`, `tags`. New blocks insert into the
  existing sections without restructuring.

## Expected Output

After completing this task:

1. `templates/autonomy-defaults.yaml` exists, is non-empty, and conforms to
   the recipe-parser.sh YAML constraints (jq-free readable).
2. `templates/orchestrator-config-default.yml` has an `autonomy:` block with
   the four keys and accurate `.local` override comment.
3. `extension.yml` has three new script entries, the `autonomy` defaults
   block, and the `autonomy` config_schema entry.
4. Five `scripts/verify/p07-*.sh` helpers exist and are chmod +x.
5. Running `bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M005/phases/P07`
   shows PASS lines for every artifact/truth that references only T01-owned
   files; FAIL lines for T02/T03/T04/T05 items are expected until those
   tasks run.
6. `git status` shows 8 new/modified files (3 modified templates +
   extension.yml, 1 new yaml, 5 new verify scripts). Nothing else touched.
