---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T04 (Phase P04, Milestone M004)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge | 19-21 | ~100 | filtered |
| Decisions | 23-25 | ~100 | filtered |
| Scope | 27-55 | ~400 | required |
| Upstream Context | 57-88 | ~600 | required |
| Task Plan | 90-731 | ~5600 | required |
| State Context | 733-739 | ~100 | required |
| Constraints | 741-746 | ~100 | required |
| **Total** | | **~7000** | |

## Knowledge

No knowledge entries in scope.

## Decisions

No decision entries in scope.

## Scope

### Goal


### Demo


### Must-Haves
## Must-Haves

### Truths

- context-recipe.yaml declares exactly 7 sections with name, source, priority, and order fields
  - Check: `test "$(grep -c '^  [a-z_]*:$' templates/context-recipe.yaml)" -ge 7`
- context-recipe.yaml has a compression block with at least 3 graduated steps
  - Check: `grep -q 'compression:' templates/context-recipe.yaml`
- hooks.yaml declares exactly 4 lifecycle points (PRE_DISPATCH, POST_DISPATCH, POST_VERIFY, PRE_ADVANCE)
  - Check: `for p in PRE_DISPATCH POST_DISPATCH POST_VERIFY PRE_ADVANCE; do grep -q "$p" templates/hooks.yaml || exit 1; done && echo PASS`
- hooks.yaml entries have name, script, enabled, and block_on_fail fields
  - Check: `grep -q 'block_on_fail:' templates/hooks.yaml`
- routing.yaml has fallback arrays for each tier (heavy, standard, light)
  - Check: `test "$(grep -c 'fallback:' templates/routing.yaml)" -ge 3`
- recipe-parser.sh has double-sourcing guard
  - Check: `head -5 scripts/lib/recipe-parser.sh | grep -q '_RECIPE_PARSER_SOURCED'`
- recipe-parser.sh exports parse_recipe_sections, parse_recipe_compression, and read_recipe_field functions
  - Check: `grep -q 'parse_recipe_sections' scripts/lib/recipe-parser.sh && grep -q 'parse_recipe_compression' scripts/lib/recipe-parser.sh && grep -q 'read_recipe_field' scripts/lib/recipe-parser.sh`
- All YAML files parseable by grep/sed/awk (no jq required, max 2 levels nesting)
  - Check: `grep -c '^      ' templates/context-recipe.yaml | xargs test 0 -eq`

## Upstream Context


### P01 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P01"
parent: "M004"
milestone: "M004"
provides:
  - "Constitution v2.0.0 with 13 principles (I-XIII), amended Principle II requiring structured events, Sync Impact Report, ANTIPATTERNS.md append-only register with 3 entries (AP-001 through AP-003) referencing M001-M003 incidents"
requires:
  - "from:T01 what:Constitution v2.0.0 with principles VIII-XIII for principle references"
affects:
  - "All M004 phases — new principles govern compliance checks, All future phases — antipatterns serve as permanent warnings for recurring structural failures"
key_files:
  - ".specify/memory/constitution.md, ANTIPATTERNS.md"
key_decisions:
  - "AD-10: MAJOR version bump 1.0.0→2.0.0, AD-11: Antipatterns are permanent with no staleness decay"
patterns_established:
  - "Principle amendment pattern with Sync Impact Report; Roman numeral principle numbering through XIII, Antipattern entry format: AP-NNN with Observed In, Principle Violated, Description, Evidence, Remedy sections; Append-only register pattern"
drill_down_paths:
  - ".specify/orchestrator/milestones/M004/phases/P01/tasks/T01-SUMMARY.md, .specify/orchestrator/milestones/M004/phases/P01/tasks/T02-SUMMARY.md"
duration: "170m"
verification_result: "pass"
completed_at: "2026-04-10T20:11:23Z"
observability_surfaces:
  - "none (governance phase, no runtime metrics)"
---

Phase P01 updated the orchestrator constitution from v1.0.0 to v2.0.0 and established the antipattern register. Constitution v2.0.0 adds 6 new principles: VIII (No Dead Infrastructure), IX (Reproducibility Over Convenience), X (Templating Over Inference), XI (Single Source of Truth), XII (Hook Isolation), XIII (Agent Instruction Schema). Principle II amended to require structured event emission (emit_event/emit_result) from engine-managed scripts. ANTIPATTERNS.md created at orchestrator root with 3 entries from real M001-M003 audit incidents: AP-001 (Bash 3.2 process substitution), AP-002 (sed -i portability), AP-003 (missing double-sourcing guards). All entries reference specific milestones and constitution principles. Sync Impact Report documents version change, added/amended principles, and template impact. All 7 phase must-haves verified passing.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P04"
milestone: "M004"
name: "Recipe Parser Library"
depends_on: [T01, T02, T03]
---

## Description

Implement `scripts/lib/recipe-parser.sh` — a Bash 3.2 compatible library that provides functions for reading YAML recipe files using only grep/sed/awk (no jq dependency). The library exports three main functions: `parse_recipe_sections` (list section names with their properties), `parse_recipe_compression` (read compression steps), and `read_recipe_field` (read any field by dotted path). Includes a double-sourcing guard per NFR-203.

This implements:
- NFR-200 (Bash 3.2 compatible)
- NFR-202 (grep/sed/awk parsing, no jq)
- NFR-203 (double-sourcing guard)
- Supports FR-210 (recipe drives assembly), FR-211 (recipe resolution), FR-212 (compression from recipe), FR-213 (routing parsing), FR-214 (hooks parsing)

## Steps

### Step 1: Create `scripts/lib/` directory if needed

```bash
mkdir -p scripts/lib
```

### Step 2: Create `scripts/lib/recipe-parser.sh`

Write the following content to `scripts/lib/recipe-parser.sh`:

```bash
#!/usr/bin/env bash
# scripts/lib/recipe-parser.sh — YAML recipe reader for context-recipe.yaml,
# hooks.yaml, and routing.yaml.
#
# Functions:
#   read_recipe_field <file> <dotted.path>         — read a single field value
#   parse_recipe_sections <file>                   — list sections with properties
#   parse_recipe_compression <file>                — list compression steps
#   parse_recipe_hooks <file> <lifecycle_point>    — list hooks at a lifecycle point
#   parse_recipe_fallback <file> <tier>            — read fallback chain for a tier
#   resolve_recipe <orch_root> <milestone> <phase> <task> — find most-specific recipe
#
# All parsing uses grep/sed/awk only (NFR-202). No jq dependency.
# Bash 3.2 compatible: no associative arrays, no readarray, no mapfile (NFR-200).
#
# Constitution: Principle X (Templating Over Inference).

# --- Double-sourcing guard (NFR-203) ---
[ -n "${_RECIPE_PARSER_SOURCED:-}" ] && return 0
_RECIPE_PARSER_SOURCED=1

# read_recipe_field <file> <dotted.path>
# Reads a single scalar value from a YAML file using a dotted path.
# Supports up to 2 levels: "key.subkey" or "key" (top-level).
# Prints the value to stdout. Returns 1 if not found.
#
# Examples:
#   read_recipe_field routing.yaml "models.heavy.id"           → claude-opus-4-6
#   read_recipe_field routing.yaml "history_weight"             → 0.3
#   read_recipe_field context-recipe.yaml "compression.enabled" → true
#   read_recipe_field hooks.yaml "hook_defaults.timeout"        → 30
read_recipe_field() {
  local file="$1"
  local path="$2"

  if [ ! -f "$file" ]; then
    echo "recipe-parser: file not found: $file" >&2
    return 1
  fi

  # Split dotted path into segments
  local seg1 seg2 seg3
  seg1="$(echo "$path" | cut -d. -f1)"
  seg2="$(echo "$path" | cut -d. -f2 -s)"
  seg3="$(echo "$path" | cut -d. -f3 -s)"

  if [ -n "$seg3" ]; then
    # 3-segment path: top.mid.leaf (e.g., models.heavy.id)
    # Find the mid-level block under top, then read leaf
    _read_nested_field "$file" "$seg1" "$seg2" "$seg3"
  elif [ -n "$seg2" ]; then
    # 2-segment path: top.leaf (e.g., compression.enabled)
    _read_nested_field_2 "$file" "$seg1" "$seg2"
  else
    # 1-segment path: top-level scalar (e.g., history_weight)
    _read_top_field "$file" "$seg1"
  fi
}

# Internal: read a top-level scalar field
_read_top_field() {
  local file="$1"
  local key="$2"
  local value
  value="$(sed -n "s/^${key}: *\"\{0,1\}\([^\"]*\)\"\{0,1\} *$/\1/p" "$file" | head -1)"
  if [ -z "$value" ]; then
    return 1
  fi
  echo "$value"
}

# Internal: read a 2-level nested field (parent.child)
_read_nested_field_2() {
  local file="$1"
  local parent="$2"
  local child="$3"
  local in_block=0
  local value=""

  while IFS= read -r line; do
    # Skip comments and blank lines
    case "$line" in
      '#'*|'') continue ;;
    esac

    # Check if we're entering the parent block
    if echo "$line" | grep -qE "^${parent}:" ; then
      in_block=1
      continue
    fi

    # If in block, look for child field (2-space indent)
    if [ "$in_block" -eq 1 ]; then
      # Exit block if we hit a non-indented line (new top-level key)
      case "$line" in
        '  '*|'    '*) ;; # still indented, continue
        *) in_block=0; continue ;;
      esac

      # Match the child field at 2-space indent
      value="$(echo "$line" | sed -n "s/^  ${child}: *\"\{0,1\}\([^\"]*\)\"\{0,1\} *$/\1/p")"
      if [ -n "$value" ]; then
        echo "$value"
        return 0
      fi
    fi
  done < "$file"

  return 1
}

# Internal: read a 3-level nested field (grandparent.parent.child)
_read_nested_field() {
  local file="$1"
  local gp="$2"
  local parent="$3"
  local child="$4"
  local in_gp=0
  local in_parent=0
  local value=""

  while IFS= read -r line; do
    case "$line" in
      '#'*|'') continue ;;
    esac

    # Enter grandparent block
    if echo "$line" | grep -qE "^${gp}:" ; then
      in_gp=1
      in_parent=0
      continue
    fi

    if [ "$in_gp" -eq 1 ]; then
      # Exit grandparent if non-indented
      case "$line" in
        '  '*|'    '*) ;; # still indented
        *) in_gp=0; in_parent=0; continue ;;
      esac

      # Enter parent block (2-space indent)
      if echo "$line" | grep -qE "^  ${parent}:$" ; then
        in_parent=1
        continue
      fi

      # If in parent, look for child (4-space indent)
      if [ "$in_parent" -eq 1 ]; then
        # Exit parent if we hit a 2-space key (sibling block)
        if echo "$line" | grep -qE '^  [a-z_]+:' ; then
          in_parent=0
          continue
        fi

        value="$(echo "$line" | sed -n "s/^    ${child}: *\"\{0,1\}\([^\"]*\)\"\{0,1\} *$/\1/p")"
        if [ -n "$value" ]; then
          echo "$value"
          return 0
        fi
      fi
    fi
  done < "$file"

  return 1
}

# parse_recipe_sections <file>
# Parses the sections: block from a context-recipe.yaml file.
# Outputs one line per section in format:
#   <name>|<source>|<priority>|<order>|<filter>|<cache_hint>
# Sections are sorted by order (ascending).
parse_recipe_sections() {
  local file="$1"

  if [ ! -f "$file" ]; then
    echo "recipe-parser: file not found: $file" >&2
    return 1
  fi

  local in_sections=0
  local current_section=""
  local s_source="" s_priority="" s_order="" s_filter="" s_cache=""
  local output_lines=""

  while IFS= read -r line; do
    case "$line" in
      '#'*|'') continue ;;
    esac

    # Enter sections block
    if echo "$line" | grep -qE '^sections:$'; then
      in_sections=1
      continue
    fi

    if [ "$in_sections" -eq 1 ]; then
      # Exit sections block on non-indented line
      case "$line" in
        '  '*|'    '*) ;; # indented, continue
        *) 
          # Flush last section
          if [ -n "$current_section" ]; then
            output_lines="${output_lines}${s_order}|${current_section}|${s_source}|${s_priority}|${s_order}|${s_filter}|${s_cache}
"
          fi
          in_sections=0
          continue
          ;;
      esac

      # New section name (2-space indent, ends with colon)
      local section_name
      section_name="$(echo "$line" | sed -n 's/^  \([a-z_]*\):$/\1/p')"
      if [ -n "$section_name" ]; then
        # Flush previous section
        if [ -n "$current_section" ]; then
          output_lines="${output_lines}${s_order}|${current_section}|${s_source}|${s_priority}|${s_order}|${s_filter}|${s_cache}
"
        fi
        current_section="$section_name"
        s_source="" ; s_priority="" ; s_order="" ; s_filter="" ; s_cache=""
        continue
      fi

      # Section fields (4-space indent)
      if [ -n "$current_section" ]; then
        local field_val
        field_val="$(echo "$line" | sed -n 's/^    source: *"\{0,1\}\([^"]*\)"\{0,1\} *$/\1/p')"
        if [ -n "$field_val" ]; then s_source="$field_val"; continue; fi

        field_val="$(echo "$line" | sed -n 's/^    priority: *\(.*\) *$/\1/p')"
        if [ -n "$field_val" ]; then s_priority="$field_val"; continue; fi

        field_val="$(echo "$line" | sed -n 's/^    order: *\(.*\) *$/\1/p')"
        if [ -n "$field_val" ]; then s_order="$field_val"; continue; fi

        field_val="$(echo "$line" | sed -n 's/^    filter: *\(.*\) *$/\1/p')"
        if [ -n "$field_val" ]; then s_filter="$field_val"; continue; fi

        field_val="$(echo "$line" | sed -n 's/^    cache_hint: *\(.*\) *$/\1/p')"
        if [ -n "$field_val" ]; then s_cache="$field_val"; continue; fi
      fi
    fi
  done < "$file"

  # Flush last section (if file ends inside sections block)
  if [ -n "$current_section" ]; then
    output_lines="${output_lines}${s_order}|${current_section}|${s_source}|${s_priority}|${s_order}|${s_filter}|${s_cache}
"
  fi

  # Sort by order (first field) and strip the sort key
  echo "$output_lines" | grep -v '^$' | sort -t'|' -k1 -n | sed 's/^[^|]*|//'
}

# parse_recipe_compression <file>
# Parses the compression: block from a context-recipe.yaml file.
# Outputs one line per step in format:
#   <step_key>|<type>|<target_sections>|<max_words>|<min_confidence>|<description>
# Fields that don't apply to a step type are empty.
parse_recipe_compression() {
  local file="$1"

  if [ ! -f "$file" ]; then
    echo "recipe-parser: file not found: $file" >&2
    return 1
  fi

  local in_compression=0
  local in_steps=0
  local current_step=""
  local c_type="" c_target="" c_maxw="" c_minc="" c_desc=""

  while IFS= read -r line; do
    case "$line" in
      '#'*|'') continue ;;
    esac

    # Enter compression block
    if echo "$line" | grep -qE '^compression:$'; then
      in_compression=1
      continue
    fi

    if [ "$in_compression" -eq 1 ]; then
      case "$line" in
        '  '*|'    '*) ;; # indented
        *)
          # Flush
          if [ -n "$current_step" ]; then
            echo "${current_step}|${c_type}|${c_target}|${c_maxw}|${c_minc}|${c_desc}"
          fi
          in_compression=0
          continue
          ;;
      esac

      # Enter steps sub-block
      if echo "$line" | grep -qE '^  steps:$'; then
        in_steps=1
        continue
      fi

      # Non-step fields under compression
      if [ "$in_steps" -eq 0 ]; then
        continue
      fi

      # Step key (4-space indent, ends with colon)
      local step_key
      step_key="$(echo "$line" | sed -n 's/^    \([a-z_0-9]*\):$/\1/p')"
      if [ -n "$step_key" ]; then
        # Flush previous step
        if [ -n "$current_step" ]; then
          echo "${current_step}|${c_type}|${c_target}|${c_maxw}|${c_minc}|${c_desc}"
        fi
        current_step="$step_key"
        c_type="" ; c_target="" ; c_maxw="" ; c_minc="" ; c_desc=""
        continue
      fi

      # Step fields (6-space indent)
      if [ -n "$current_step" ]; then
        local fv
        fv="$(echo "$line" | sed -n 's/^      type: *\(.*\) *$/\1/p')"
        if [ -n "$fv" ]; then c_type="$fv"; continue; fi

        fv="$(echo "$line" | sed -n 's/^      target_sections: *"\{0,1\}\([^"]*\)"\{0,1\} *$/\1/p')"
        if [ -n "$fv" ]; then c_target="$fv"; continue; fi

        fv="$(echo "$line" | sed -n 's/^      max_words: *\(.*\) *$/\1/p')"
        if [ -n "$fv" ]; then c_maxw="$fv"; continue; fi

        fv="$(echo "$line" | sed -n 's/^      min_confidence: *\(.*\) *$/\1/p')"
        if [ -n "$fv" ]; then c_minc="$fv"; continue; fi

        fv="$(echo "$line" | sed -n 's/^      description: *"\{0,1\}\([^"]*\)"\{0,1\} *$/\1/p')"
        if [ -n "$fv" ]; then c_desc="$fv"; continue; fi
      fi
    fi
  done < "$file"

  # Flush last step
  if [ -n "$current_step" ]; then
    echo "${current_step}|${c_type}|${c_target}|${c_maxw}|${c_minc}|${c_desc}"
  fi
}

# parse_recipe_hooks <file> <lifecycle_point>
# Parses hooks for a specific lifecycle point from hooks.yaml.
# Outputs one line per hook in format:
#   <hook_key>|<name>|<script>|<enabled>|<block_on_fail>|<description>
parse_recipe_hooks() {
  local file="$1"
  local lifecycle="$2"

  if [ ! -f "$file" ]; then
    echo "recipe-parser: file not found: $file" >&2
    return 1
  fi

  local in_lifecycle=0
  local current_hook=""
  local h_name="" h_script="" h_enabled="" h_block="" h_desc=""

  while IFS= read -r line; do
    case "$line" in
      '#'*|'') continue ;;
    esac

    # Enter lifecycle block
    if echo "$line" | grep -qE "^${lifecycle}:$"; then
      in_lifecycle=1
      continue
    fi

    if [ "$in_lifecycle" -eq 1 ]; then
      case "$line" in
        '  '*|'    '*) ;; # indented
        *)
          # Flush
          if [ -n "$current_hook" ]; then
            echo "${current_hook}|${h_name}|${h_script}|${h_enabled}|${h_block}|${h_desc}"
          fi
          in_lifecycle=0
          continue
          ;;
      esac

      # Hook key (2-space indent, ends with colon)
      local hook_key
      hook_key="$(echo "$line" | sed -n 's/^  \([a-z_]*\):$/\1/p')"
      if [ -n "$hook_key" ]; then
        if [ -n "$current_hook" ]; then
          echo "${current_hook}|${h_name}|${h_script}|${h_enabled}|${h_block}|${h_desc}"
        fi
        current_hook="$hook_key"
        h_name="" ; h_script="" ; h_enabled="" ; h_block="" ; h_desc=""
        continue
      fi

      # Hook fields (4-space indent)
      if [ -n "$current_hook" ]; then
        local fv
        fv="$(echo "$line" | sed -n 's/^    name: *"\{0,1\}\([^"]*\)"\{0,1\} *$/\1/p')"
        if [ -n "$fv" ]; then h_name="$fv"; continue; fi

        fv="$(echo "$line" | sed -n 's/^    script: *"\{0,1\}\([^"]*\)"\{0,1\} *$/\1/p')"
        if [ -n "$fv" ]; then h_script="$fv"; continue; fi

        fv="$(echo "$line" | sed -n 's/^    enabled: *\(.*\) *$/\1/p')"
        if [ -n "$fv" ]; then h_enabled="$fv"; continue; fi

        fv="$(echo "$line" | sed -n 's/^    block_on_fail: *\(.*\) *$/\1/p')"
        if [ -n "$fv" ]; then h_block="$fv"; continue; fi

        fv="$(echo "$line" | sed -n 's/^    description: *"\{0,1\}\([^"]*\)"\{0,1\} *$/\1/p')"
        if [ -n "$fv" ]; then h_desc="$fv"; continue; fi
      fi
    fi
  done < "$file"

  # Flush last hook
  if [ -n "$current_hook" ]; then
    echo "${current_hook}|${h_name}|${h_script}|${h_enabled}|${h_block}|${h_desc}"
  fi
}

# parse_recipe_fallback <file> <tier>
# Reads the fallback chain for a model tier from routing.yaml.
# Outputs comma-separated model IDs (or empty string if no fallback).
parse_recipe_fallback() {
  local file="$1"
  local tier="$2"

  read_recipe_field "$file" "models.${tier}.fallback"
}

# resolve_recipe <orch_root> <milestone> <phase> <task> <filename>
# Finds the most-specific recipe file following FR-211 resolution:
#   task dir > phase dir > milestone dir > templates/ default
# Prints the resolved file path. Returns 1 if no recipe found.
resolve_recipe() {
  local orch_root="$1"
  local milestone="$2"
  local phase="$3"
  local task="$4"
  local filename="${5:-context-recipe.yaml}"

  # Task-level
  local task_path="${orch_root}/milestones/${milestone}/phases/${phase}/tasks/${filename}"
  if [ -f "$task_path" ]; then
    echo "$task_path"
    return 0
  fi

  # Phase-level
  local phase_path="${orch_root}/milestones/${milestone}/phases/${phase}/${filename}"
  if [ -f "$phase_path" ]; then
    echo "$phase_path"
    return 0
  fi

  # Milestone-level
  local ms_path="${orch_root}/milestones/${milestone}/${filename}"
  if [ -f "$ms_path" ]; then
    echo "$ms_path"
    return 0
  fi

  # Default (project root templates/)
  local project_root
  project_root="$(cd "$orch_root/.." 2>/dev/null && pwd)"
  local default_path="${project_root}/templates/${filename}"
  if [ -f "$default_path" ]; then
    echo "$default_path"
    return 0
  fi

  echo "recipe-parser: no ${filename} found in resolution chain" >&2
  return 1
}
```

### Step 3: Make the file executable

```bash
chmod +x scripts/lib/recipe-parser.sh
```

### Step 4: Verify Bash 3.2 compatibility

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# No associative arrays
! grep -qE 'declare -A' scripts/lib/recipe-parser.sh && echo "PASS: no associative arrays" || echo "FAIL"

# No readarray/mapfile
! grep -qE 'readarray|mapfile' scripts/lib/recipe-parser.sh && echo "PASS: no readarray/mapfile" || echo "FAIL"

# No process substitution as redirect target
! grep -qE 'done\s*<\s*<\(' scripts/lib/recipe-parser.sh && echo "PASS: no process substitution" || echo "FAIL"

# Double-sourcing guard
head -5 scripts/lib/recipe-parser.sh | grep -q '_RECIPE_PARSER_SOURCED' && echo "PASS: sourcing guard" || echo "FAIL"

# No jq usage
! grep -q 'jq ' scripts/lib/recipe-parser.sh && echo "PASS: no jq" || echo "FAIL"

# Functions defined
for fn in read_recipe_field parse_recipe_sections parse_recipe_compression parse_recipe_hooks parse_recipe_fallback resolve_recipe; do
  grep -q "^${fn}()" scripts/lib/recipe-parser.sh && echo "PASS: $fn defined" || echo "FAIL: $fn missing"
done
```

## Must-Haves

### Truths

- recipe-parser.sh has double-sourcing guard as first executable line
  - Check: `head -5 scripts/lib/recipe-parser.sh | grep -q '_RECIPE_PARSER_SOURCED'`
- recipe-parser.sh defines read_recipe_field, parse_recipe_sections, and parse_recipe_compression functions
  - Check: `grep -q 'read_recipe_field()' scripts/lib/recipe-parser.sh && grep -q 'parse_recipe_sections()' scripts/lib/recipe-parser.sh && grep -q 'parse_recipe_compression()' scripts/lib/recipe-parser.sh`
- recipe-parser.sh defines parse_recipe_hooks and parse_recipe_fallback functions
  - Check: `grep -q 'parse_recipe_hooks()' scripts/lib/recipe-parser.sh && grep -q 'parse_recipe_fallback()' scripts/lib/recipe-parser.sh`
- recipe-parser.sh defines resolve_recipe function implementing FR-211 resolution
  - Check: `grep -q 'resolve_recipe()' scripts/lib/recipe-parser.sh`
- No associative arrays, readarray, or mapfile (Bash 3.2 compatible)
  - Check: `! grep -qE 'declare -A|readarray|mapfile' scripts/lib/recipe-parser.sh`
- No jq usage (grep/sed/awk only)
  - Check: `! grep -q 'jq ' scripts/lib/recipe-parser.sh`

### Artifacts

- `scripts/lib/recipe-parser.sh` (min 120 lines, contains "_RECIPE_PARSER_SOURCED")

### Key Links

- `scripts/lib/recipe-parser.sh` → `templates/context-recipe.yaml` (parser reads recipe)
- `scripts/lib/recipe-parser.sh` → `templates/hooks.yaml` (parser reads hooks)
- `scripts/lib/recipe-parser.sh` → `templates/routing.yaml` (parser reads routing)

## Verification

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
echo "=== T04 Verification ==="

# File exists and has minimum lines
test -f scripts/lib/recipe-parser.sh && echo "PASS: file exists" || echo "FAIL: file missing"
lines=$(wc -l < scripts/lib/recipe-parser.sh | tr -d ' ')
test "$lines" -ge 120 && echo "PASS: $lines lines (min 120)" || echo "FAIL: only $lines lines"

# Double-sourcing guard
head -5 scripts/lib/recipe-parser.sh | grep -q '_RECIPE_PARSER_SOURCED' && echo "PASS: sourcing guard" || echo "FAIL: no guard"

# Functions
for fn in read_recipe_field parse_recipe_sections parse_recipe_compression parse_recipe_hooks parse_recipe_fallback resolve_recipe; do
  grep -q "^${fn}()" scripts/lib/recipe-parser.sh && echo "PASS: $fn" || echo "FAIL: $fn missing"
done

# Bash 3.2 checks
! grep -qE 'declare -A|readarray|mapfile' scripts/lib/recipe-parser.sh && echo "PASS: Bash 3.2 compat" || echo "FAIL: Bash 3.2 violation"
! grep -q 'jq ' scripts/lib/recipe-parser.sh && echo "PASS: no jq" || echo "FAIL: jq found"

# Executable
test -x scripts/lib/recipe-parser.sh && echo "PASS: executable" || echo "FAIL: not executable"
```

## Inputs

### From Previous Tasks

- `templates/context-recipe.yaml` (from T01)
  - Key API: `sections:` block with 7 sections, each having source/priority/order/filter/cache_hint. `compression:` block with steps sub-block.
  - Key types: Section priorities (required, compressible, optional), step types (drop_optional, summarize, drop_lowest_confidence).
  - Behavioral contract: Parser must extract all 7 sections with their 5 properties, sorted by order. Parser must extract all 3 compression steps with their type-specific fields.

- `templates/hooks.yaml` (from T02)
  - Key API: 4 lifecycle point blocks (PRE_DISPATCH, POST_DISPATCH, POST_VERIFY, PRE_ADVANCE), each containing hook entries with name/script/enabled/block_on_fail/description.
  - Key types: Hook keys are lowercase_underscore identifiers under lifecycle point blocks.
  - Behavioral contract: Parser must list hooks at a given lifecycle point with all their properties.

- `templates/routing.yaml` (from T03)
  - Key API: `models:` block with 3 tiers, each having id/context_budget/fallback. `classification:` block with patterns/confidence per tier. `fallback_config:` block.
  - Key types: Fallback is a comma-separated string of model IDs.
  - Behavioral contract: `parse_recipe_fallback` reads the comma-separated fallback chain for a tier. `read_recipe_field` reads any field by dotted path.

### From Disk (Pre-existing)

- `scripts/knowledge/lib/staleness.sh` — Reference for double-sourcing guard pattern. Uses `[ -n "${_STALENESS_SOURCED:-}" ] && return 0` / `_STALENESS_SOURCED=1`.
- `ANTIPATTERNS.md` — AP-003 documents the missing double-sourcing guard antipattern. This library must include the guard.
- `specs/004-engine-architecture/spec.md` — NFR-200 (Bash 3.2), NFR-202 (grep/sed/awk), NFR-203 (double-sourcing guards), FR-211 (specificity resolution).
- `.specify/memory/constitution.md` — Principle X (Templating Over Inference): scripts implement mechanics, templates declare policy.

## Expected Output

The file `scripts/lib/recipe-parser.sh` containing:
- Double-sourcing guard (`_RECIPE_PARSER_SOURCED`)
- `read_recipe_field` function: reads any scalar by dotted path (1-3 segments)
- `parse_recipe_sections` function: lists all sections with pipe-delimited properties, sorted by order
- `parse_recipe_compression` function: lists compression steps with pipe-delimited properties
- `parse_recipe_hooks` function: lists hooks at a lifecycle point with pipe-delimited properties
- `parse_recipe_fallback` function: reads fallback chain for a model tier
- `resolve_recipe` function: FR-211 specificity resolution (task > phase > milestone > default)
- All parsing via grep/sed/awk, no jq, Bash 3.2 compatible, executable permission

## State Context

- **Current State**: executing
- **Milestone**: M004
- **Phase**: P04
- **Task**: T04
- **Tier**: C

## Constraints

- **Verification Criteria**: See phase plan must-haves
- **Duration Budget**: 2h
- **Dispatch Budget**: 3
- **Budget Enforcement**: warn