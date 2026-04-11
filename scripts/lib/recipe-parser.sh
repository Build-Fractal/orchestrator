#!/usr/bin/env bash
# scripts/lib/recipe-parser.sh — YAML recipe reader (NFR-203 guard below)
# All parsing uses grep/sed/awk only (NFR-202). No external JSON tools.
[ -n "${_RECIPE_PARSER_SOURCED:-}" ] && return 0
_RECIPE_PARSER_SOURCED=1
#
# Functions:
#   read_recipe_field <file> <dotted.path>         — read a single field value
#   parse_recipe_sections <file>                   — list sections with properties
#   parse_recipe_compression <file>                — list compression steps
#   parse_recipe_hooks <file> <lifecycle_point>    — list hooks at a lifecycle point
#   parse_recipe_fallback <file> <tier>            — read fallback chain for a tier
#   resolve_recipe <orch_root> <milestone> <phase> <task> — find most-specific recipe
#
# Bash 3.2 compatible: no assoc arrays, no array builtins (NFR-200).
#
# Constitution: Principle X (Templating Over Inference).

# read_recipe_field <file> <dotted.path>
# Reads a single scalar value from a YAML file using a dotted path.
# Supports up to 3 levels: "key.subkey.subsubkey", "key.subkey", or "key".
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
            current_section=""
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
            current_step=""
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
            current_hook=""
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
