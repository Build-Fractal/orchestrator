#!/usr/bin/env bash
# scripts/lib/knowledge-filter.sh
#
# M018/P02/T02 — Knowledge-aware status filter.
#
# Pure library consumed by:
#   - scripts/dispatch/build-context.sh (planning + task-dispatch payloads)
#   - scripts/dispatch/lib/section-handlers.sh (handle_knowledge)
#
# Reads compression.knowledge_filter.drop_list from .orchestrator/config.yml
# and excludes resolved knowledge entries whose YAML frontmatter `status:`
# field matches the drop-list. Missing `status:` field → RETAINED (fail-open
# per spec FR-3 + grammar contract `## Tier: filter` failure semantics).
#
# Pinned to grammar contract: references/compression-grammar.md v1.0.1.
#
# Export surface:
#   - kf_get_compression_enabled <project_root>
#   - kf_get_tier2_enabled <project_root>          (M018/P04/T01)
#   - kf_get_tier2_section_budget_tokens <project_root>
#   - kf_get_tier2_protected_tail_ratio <project_root>
#   - kf_get_tier3_enabled <project_root>          (M018/P06/T01)
#   - kf_get_tier3_intensity_floor <project_root>
#   - kf_get_tier3_section_budget_tokens <project_root>
#   - kf_get_tier3_originals_dir <project_root>
#   - kf_get_tier3_output_max_ratio <project_root>
#   - kf_get_tier3_density_floor <project_root>
#       Echoes 'true' or 'false'. Defaults 'true' when key missing.
#       Honors ORCH_OVERRIDE_COMPRESSION_ENABLED env var (highest precedence).
#   - kf_get_knowledge_filter_enabled <project_root>
#       Echoes 'true' or 'false'. Defaults 'true' when key missing.
#   - kf_read_drop_list <project_root> > <out_file>
#       Writes one drop-list value per line. Defaults to:
#         superseded
#         experimental
#       when the config or compression block is missing.
#   - kf_filter_stream <drop_list_file> <stats_file>
#       Reads a multi-entry knowledge stream on stdin (each entry begins with
#       a YAML frontmatter block delimited by ^---$ ... ^---$ followed by a
#       markdown body). Writes the filtered stream to stdout. Writes a single
#       stats line to <stats_file> of the form:
#         dropped_count=<N> dropped_tokens=<N> dropped_ids=<csv>
#       Bail-safe: any awk/IO failure passes the input through unchanged and
#       writes a zero-stats line.
#
# Shape rules (AP-009 / AD-19):
#   - No compound chains > 2.
#   - No $(...|...) (no pipes inside command substitutions).
#   - No plain subshells `( ... )`.
#   - No process substitution <(...).
#
# Sourceable: NO `set -eu` at file scope.
# Bash 3.2 compatible (MEM001).

# ---------------------------------------------------------------------------
# kf_resolve_config_path <project_root>
# Echoes path to active config.yml or empty when none found.
# ---------------------------------------------------------------------------
kf_resolve_config_path() {
  local project_root="${1:-}"
  local cfg=""
  if [ -n "${ORCH_ROOT:-}" ] && [ -f "$ORCH_ROOT/config.yml" ]; then
    cfg="$ORCH_ROOT/config.yml"
  elif [ -n "$project_root" ] && [ -f "$project_root/.orchestrator/config.yml" ]; then
    cfg="$project_root/.orchestrator/config.yml"
  fi
  printf '%s\n' "$cfg"
}

# ---------------------------------------------------------------------------
# kf_read_compression_scalar <cfg_file> <key>  ->  stdout
# Reads `compression.<key>:` (a top-level scalar inside the compression: block
# OR `compression.knowledge_filter.<key>:` inside the nested block when
# <key> is dotted, e.g. "knowledge_filter.enabled"). Echoes empty string
# when not found.
# Bash 3.2 + AP-009 safe (single awk invocation).
# ---------------------------------------------------------------------------
kf_read_compression_scalar() {
  local cfg="$1"
  local key="$2"
  if [ -z "$cfg" ] || [ ! -f "$cfg" ]; then
    return 0
  fi
  awk -v want="$key" '
    BEGIN {
      in_compression = 0
      in_kf = 0
      in_up = 0
      in_t1 = 0
      in_t2 = 0
      in_ef = 0
      base_indent = -1
      kf_indent = -1
      up_indent = -1
      t1_indent = -1
      t2_indent = -1
      ef_indent = -1
    }
    # Track exit from compression: block when we see a non-indented key.
    /^[A-Za-z_][A-Za-z0-9_-]*:[[:space:]]*/ {
      if ($0 !~ /^compression:/) {
        in_compression = 0
        in_kf = 0
        in_up = 0
        in_t1 = 0
        in_t2 = 0
        in_ef = 0
        base_indent = -1
        kf_indent = -1
        up_indent = -1
        t1_indent = -1
        ef_indent = -1
      }
    }
    /^compression:[[:space:]]*$/ {
      in_compression = 1
      base_indent = -1
      next
    }
    in_compression == 1 {
      # Determine indentation of compression children on first child seen.
      match($0, /^[[:space:]]*/)
      ind = RLENGTH
      # Blank or comment lines do not break the block.
      if ($0 ~ /^[[:space:]]*$/) next
      if ($0 ~ /^[[:space:]]*#/) next
      # If we hit a top-level key (no leading space and a colon), exit block.
      if (ind == 0 && $0 ~ /^[A-Za-z_]/) {
        in_compression = 0
        in_kf = 0
        in_up = 0
        in_t1 = 0
        in_t2 = 0
        in_ef = 0
        next
      }
      if (base_indent < 0) base_indent = ind
      # Direct child key.
      if (ind == base_indent) {
        # k_name : value
        line = $0
        sub(/^[[:space:]]+/, "", line)
        # Extract key portion before colon.
        kpos = index(line, ":")
        if (kpos == 0) next
        kname = substr(line, 1, kpos - 1)
        rest = substr(line, kpos + 1)
        sub(/^[[:space:]]+/, "", rest)
        sub(/[[:space:]]*#.*$/, "", rest)
        sub(/[[:space:]]+$/, "", rest)
        gsub(/^"|"$/, "", rest)
        gsub(/^'\''|'\''$/, "", rest)
        if (kname == "knowledge_filter") {
          in_kf = 1
          in_up = 0
          in_t1 = 0
          in_t2 = 0
          in_ef = 0
          kf_indent = -1
          # value is empty (block header), skip
          next
        } else if (kname == "underperformance") {
          in_up = 1
          in_kf = 0
          in_t1 = 0
          in_t2 = 0
          in_ef = 0
          up_indent = -1
          next
        } else if (kname == "tier1") {
          in_t1 = 1
          in_kf = 0
          in_up = 0
          in_t2 = 0
          in_ef = 0
          t1_indent = -1
          next
        } else if (kname == "tier2") {
          in_t2 = 1
          in_kf = 0
          in_up = 0
          in_t1 = 0
          in_ef = 0
          t2_indent = -1
          next
        } else if (kname == "efficiency_footer") {
          in_ef = 1
          in_kf = 0
          in_up = 0
          in_t1 = 0
          in_t2 = 0
          ef_indent = -1
          next
        } else {
          in_kf = 0
          in_up = 0
          in_t1 = 0
          in_t2 = 0
          in_ef = 0
        }
        if (kname == want) {
          print rest
          exit 0
        }
      } else if (ind > base_indent) {
        if (in_kf == 1) {
          if (kf_indent < 0) kf_indent = ind
          if (ind == kf_indent) {
            line = $0
            sub(/^[[:space:]]+/, "", line)
            kpos = index(line, ":")
            if (kpos == 0) next
            kname = substr(line, 1, kpos - 1)
            rest = substr(line, kpos + 1)
            sub(/^[[:space:]]+/, "", rest)
            sub(/[[:space:]]*#.*$/, "", rest)
            sub(/[[:space:]]+$/, "", rest)
            gsub(/^"|"$/, "", rest)
            gsub(/^'\''|'\''$/, "", rest)
            full = "knowledge_filter." kname
            if (full == want) {
              print rest
              exit 0
            }
          }
        } else if (in_up == 1) {
          if (up_indent < 0) up_indent = ind
          if (ind == up_indent) {
            line = $0
            sub(/^[[:space:]]+/, "", line)
            kpos = index(line, ":")
            if (kpos == 0) next
            kname = substr(line, 1, kpos - 1)
            rest = substr(line, kpos + 1)
            sub(/^[[:space:]]+/, "", rest)
            sub(/[[:space:]]*#.*$/, "", rest)
            sub(/[[:space:]]+$/, "", rest)
            gsub(/^"|"$/, "", rest)
            gsub(/^'\''|'\''$/, "", rest)
            full = "underperformance." kname
            if (full == want) {
              print rest
              exit 0
            }
          }
        } else if (in_t1 == 1) {
          if (t1_indent < 0) t1_indent = ind
          if (ind == t1_indent) {
            line = $0
            sub(/^[[:space:]]+/, "", line)
            kpos = index(line, ":")
            if (kpos == 0) next
            kname = substr(line, 1, kpos - 1)
            rest = substr(line, kpos + 1)
            sub(/^[[:space:]]+/, "", rest)
            sub(/[[:space:]]*#.*$/, "", rest)
            sub(/[[:space:]]+$/, "", rest)
            gsub(/^"|"$/, "", rest)
            gsub(/^'\''|'\''$/, "", rest)
            full = "tier1." kname
            if (full == want) {
              print rest
              exit 0
            }
          }
        } else if (in_t2 == 1) {
          if (t2_indent < 0) t2_indent = ind
          if (ind == t2_indent) {
            line = $0
            sub(/^[[:space:]]+/, "", line)
            kpos = index(line, ":")
            if (kpos == 0) next
            kname = substr(line, 1, kpos - 1)
            rest = substr(line, kpos + 1)
            sub(/^[[:space:]]+/, "", rest)
            sub(/[[:space:]]*#.*$/, "", rest)
            sub(/[[:space:]]+$/, "", rest)
            gsub(/^"|"$/, "", rest)
            gsub(/^'\''|'\''$/, "", rest)
            full = "tier2." kname
            if (full == want) {
              print rest
              exit 0
            }
          }
        } else if (in_ef == 1) {
          if (ef_indent < 0) ef_indent = ind
          if (ind == ef_indent) {
            line = $0
            sub(/^[[:space:]]+/, "", line)
            kpos = index(line, ":")
            if (kpos == 0) next
            kname = substr(line, 1, kpos - 1)
            rest = substr(line, kpos + 1)
            sub(/^[[:space:]]+/, "", rest)
            sub(/[[:space:]]*#.*$/, "", rest)
            sub(/[[:space:]]+$/, "", rest)
            gsub(/^"|"$/, "", rest)
            gsub(/^'\''|'\''$/, "", rest)
            full = "efficiency_footer." kname
            if (full == want) {
              print rest
              exit 0
            }
          }
        }
      } else if (ind < base_indent) {
        # Exited compression: block by dedent.
        in_compression = 0
        in_kf = 0
        in_up = 0
        in_t1 = 0
        in_t2 = 0
        in_ef = 0
      }
    }
  ' "$cfg"
}

# ---------------------------------------------------------------------------
# kf_get_compression_enabled <project_root>  ->  'true'|'false'
# ORCH_OVERRIDE_COMPRESSION_ENABLED env beats config (test seam, FR-15 SC-8).
# ---------------------------------------------------------------------------
kf_get_compression_enabled() {
  local project_root="${1:-}"
  if [ -n "${ORCH_OVERRIDE_COMPRESSION_ENABLED:-}" ]; then
    if [ "$ORCH_OVERRIDE_COMPRESSION_ENABLED" = "false" ]; then
      printf 'false\n'
    else
      printf 'true\n'
    fi
    return 0
  fi
  local cfg val
  cfg="$(kf_resolve_config_path "$project_root")"
  val="$(kf_read_compression_scalar "$cfg" enabled)"
  if [ "$val" = "false" ]; then
    printf 'false\n'
  else
    printf 'true\n'
  fi
}

# ---------------------------------------------------------------------------
# kf_get_knowledge_filter_enabled <project_root>  ->  'true'|'false'
# ---------------------------------------------------------------------------
kf_get_knowledge_filter_enabled() {
  local project_root="${1:-}"
  local cfg val
  cfg="$(kf_resolve_config_path "$project_root")"
  val="$(kf_read_compression_scalar "$cfg" knowledge_filter.enabled)"
  if [ "$val" = "false" ]; then
    printf 'false\n'
  else
    printf 'true\n'
  fi
}

# ---------------------------------------------------------------------------
# kf_get_underperformance_<key> <project_root>  ->  scalar
# M018/P02/T03 (MIT-09): aggregate-savings underperformance self-check
# config accessors. Each returns the scalar value from
# compression.underperformance.<key> or the documented default when absent.
# ---------------------------------------------------------------------------
kf_get_underperformance_enabled() {
  local project_root="${1:-}"
  local cfg val
  cfg="$(kf_resolve_config_path "$project_root")"
  val="$(kf_read_compression_scalar "$cfg" underperformance.enabled)"
  if [ "$val" = "false" ]; then
    printf 'false\n'
  else
    printf 'true\n'
  fi
}

kf_get_underperformance_window_size() {
  local project_root="${1:-}"
  local cfg val
  cfg="$(kf_resolve_config_path "$project_root")"
  val="$(kf_read_compression_scalar "$cfg" underperformance.window_size)"
  if [ -z "$val" ]; then
    printf '30\n'
  else
    printf '%s\n' "$val"
  fi
}

kf_get_underperformance_floor_pct() {
  local project_root="${1:-}"
  local cfg val
  cfg="$(kf_resolve_config_path "$project_root")"
  val="$(kf_read_compression_scalar "$cfg" underperformance.floor_pct)"
  if [ -z "$val" ]; then
    printf '34.7\n'
  else
    printf '%s\n' "$val"
  fi
}

kf_get_underperformance_min_sample_size() {
  local project_root="${1:-}"
  local cfg val
  cfg="$(kf_resolve_config_path "$project_root")"
  val="$(kf_read_compression_scalar "$cfg" underperformance.min_sample_size)"
  if [ -z "$val" ]; then
    printf '10\n'
  else
    printf '%s\n' "$val"
  fi
}

# ---------------------------------------------------------------------------
# kf_get_tier1_<key> <project_root>  ->  scalar
# M018/P03/T01: Tier 1 microcompact config accessors. Each returns the scalar
# value from compression.tier1.<key> or the documented default when absent.
# ---------------------------------------------------------------------------
kf_get_tier1_enabled() {
  local project_root="${1:-}"
  local cfg val
  cfg="$(kf_resolve_config_path "$project_root")"
  val="$(kf_read_compression_scalar "$cfg" tier1.enabled)"
  if [ "$val" = "false" ]; then
    printf 'false\n'
  else
    printf 'true\n'
  fi
}

kf_get_tier1_inline_threshold_tokens() {
  local project_root="${1:-}"
  local cfg val
  cfg="$(kf_resolve_config_path "$project_root")"
  val="$(kf_read_compression_scalar "$cfg" tier1.inline_threshold_tokens)"
  if [ -z "$val" ]; then
    printf '1500\n'
  else
    printf '%s\n' "$val"
  fi
}

kf_get_tier1_preview_lines() {
  local project_root="${1:-}"
  local cfg val
  cfg="$(kf_resolve_config_path "$project_root")"
  val="$(kf_read_compression_scalar "$cfg" tier1.preview_lines)"
  if [ -z "$val" ]; then
    printf '5\n'
  else
    printf '%s\n' "$val"
  fi
}

kf_get_tier1_cache_dir() {
  local project_root="${1:-}"
  local cfg val
  cfg="$(kf_resolve_config_path "$project_root")"
  val="$(kf_read_compression_scalar "$cfg" tier1.cache_dir)"
  if [ -z "$val" ]; then
    printf '.orchestrator/cache/tool-results/\n'
  else
    printf '%s\n' "$val"
  fi
}

# ---------------------------------------------------------------------------
# kf_get_tier2_<key> <project_root>  ->  scalar
# M018/P04/T01: Tier 2 snip config accessors. Each returns the scalar value
# from compression.tier2.<key> or the documented default when absent.
# ---------------------------------------------------------------------------
kf_get_tier2_enabled() {
  local project_root="${1:-}"
  local cfg val
  cfg="$(kf_resolve_config_path "$project_root")"
  val="$(kf_read_compression_scalar "$cfg" tier2.enabled)"
  if [ "$val" = "false" ]; then
    printf 'false\n'
  else
    printf 'true\n'
  fi
}

kf_get_tier2_section_budget_tokens() {
  local project_root="${1:-}"
  local cfg val
  cfg="$(kf_resolve_config_path "$project_root")"
  val="$(kf_read_compression_scalar "$cfg" tier2.section_budget_tokens)"
  if [ -z "$val" ]; then
    printf '1500\n'
  else
    printf '%s\n' "$val"
  fi
}

kf_get_tier2_protected_tail_ratio() {
  local project_root="${1:-}"
  local cfg val
  cfg="$(kf_resolve_config_path "$project_root")"
  val="$(kf_read_compression_scalar "$cfg" tier2.protected_tail_ratio)"
  if [ -z "$val" ]; then
    printf '0.3\n'
  else
    printf '%s\n' "$val"
  fi
}

# ---------------------------------------------------------------------------
# kf_get_tier3_<key> <project_root>  ->  scalar
# M018/P06/T01: Tier 3 auto-compact config accessors. Each returns the scalar
# value from compression.tier3.<key> or the documented default when absent.
# ---------------------------------------------------------------------------
kf_get_tier3_enabled() {
  local project_root="${1:-}"
  local cfg val
  cfg="$(kf_resolve_config_path "$project_root")"
  val="$(kf_read_compression_scalar "$cfg" tier3.enabled)"
  if [ "$val" = "false" ]; then
    printf 'false\n'
  else
    printf 'true\n'
  fi
}

kf_get_tier3_intensity_floor() {
  local project_root="${1:-}"
  local cfg val
  cfg="$(kf_resolve_config_path "$project_root")"
  val="$(kf_read_compression_scalar "$cfg" tier3.intensity_floor)"
  case "$val" in
    quick|standard|full) printf '%s\n' "$val" ;;
    *) printf 'standard\n' ;;
  esac
}

kf_get_tier3_section_budget_tokens() {
  local project_root="${1:-}"
  local cfg val
  cfg="$(kf_resolve_config_path "$project_root")"
  val="$(kf_read_compression_scalar "$cfg" tier3.section_budget_tokens)"
  if [ -z "$val" ]; then
    printf '2500\n'
  else
    printf '%s\n' "$val"
  fi
}

kf_get_tier3_originals_dir() {
  local project_root="${1:-}"
  local cfg val
  cfg="$(kf_resolve_config_path "$project_root")"
  val="$(kf_read_compression_scalar "$cfg" tier3.originals_dir)"
  if [ -z "$val" ]; then
    printf '.orchestrator/cache/tier3-originals/\n'
  else
    printf '%s\n' "$val"
  fi
}

kf_get_tier3_output_max_ratio() {
  local project_root="${1:-}"
  local cfg val
  cfg="$(kf_resolve_config_path "$project_root")"
  val="$(kf_read_compression_scalar "$cfg" tier3.output_max_ratio)"
  if [ -z "$val" ]; then
    printf '0.80\n'
  else
    printf '%s\n' "$val"
  fi
}

kf_get_tier3_density_floor() {
  local project_root="${1:-}"
  local cfg val
  cfg="$(kf_resolve_config_path "$project_root")"
  val="$(kf_read_compression_scalar "$cfg" tier3.density_floor)"
  if [ -z "$val" ]; then
    printf '1.5\n'
  else
    printf '%s\n' "$val"
  fi
}

# ---------------------------------------------------------------------------
# kf_get_efficiency_footer_compression_enabled <project_root> -> 'true'|'false'
# M018/P05/T02: gates the one-line compression tail in efficiency-footer.sh
# (independent of the parent `efficiency_footer` knob — parent suppresses
# the whole footer; this knob suppresses only the compression line).
# Defaults true when key absent. Mirrors the kf_get_*_enabled shape.
# ---------------------------------------------------------------------------
kf_get_efficiency_footer_compression_enabled() {
  local project_root="${1:-}"
  local cfg val
  cfg="$(kf_resolve_config_path "$project_root")"
  val="$(kf_read_compression_scalar "$cfg" efficiency_footer.enabled)"
  if [ "$val" = "false" ]; then
    printf 'false\n'
  else
    printf 'true\n'
  fi
}

# ---------------------------------------------------------------------------
# kf_get_compression_regression_floor <project_root>  ->  scalar
# M018/P05/T02: SC-9 P00-calibrated savings-ratio floor consumed by
# check-anomalies.sh `compression-regression` reason. Defaults 0.347.
# ---------------------------------------------------------------------------
kf_get_compression_regression_floor() {
  local project_root="${1:-}"
  local cfg val
  cfg="$(kf_resolve_config_path "$project_root")"
  val="$(kf_read_compression_scalar "$cfg" regression_floor)"
  if [ -z "$val" ]; then
    printf '0.347\n'
  else
    printf '%s\n' "$val"
  fi
}

# ---------------------------------------------------------------------------
# kf_read_drop_list <project_root>  ->  stdout (one value per line)
# Reads compression.knowledge_filter.drop_list from .orchestrator/config.yml.
# Defaults to "superseded\nexperimental\n" when key absent or config missing.
# ---------------------------------------------------------------------------
kf_read_drop_list() {
  local project_root="${1:-}"
  local cfg
  cfg="$(kf_resolve_config_path "$project_root")"
  if [ -z "$cfg" ] || [ ! -f "$cfg" ]; then
    printf 'superseded\nexperimental\n'
    return 0
  fi
  local out
  out="$(awk '
    BEGIN {
      in_compression = 0
      in_kf = 0
      in_dl = 0
      base_indent = -1
      kf_indent = -1
      dl_indent = -1
    }
    /^compression:[[:space:]]*$/ {
      in_compression = 1
      base_indent = -1
      next
    }
    in_compression == 1 {
      match($0, /^[[:space:]]*/)
      ind = RLENGTH
      if ($0 ~ /^[[:space:]]*$/) next
      if ($0 ~ /^[[:space:]]*#/) next
      if (ind == 0 && $0 ~ /^[A-Za-z_]/) {
        in_compression = 0
        in_kf = 0
        in_dl = 0
        next
      }
      if (base_indent < 0) base_indent = ind
      if (ind == base_indent) {
        in_kf = 0
        in_dl = 0
        line = $0
        sub(/^[[:space:]]+/, "", line)
        if (line ~ /^knowledge_filter:/) {
          in_kf = 1
          kf_indent = -1
        }
      } else if (ind > base_indent && in_kf == 1) {
        if (kf_indent < 0) kf_indent = ind
        if (ind == kf_indent) {
          in_dl = 0
          line = $0
          sub(/^[[:space:]]+/, "", line)
          if (line ~ /^drop_list:/) {
            rest = line
            sub(/^drop_list:[[:space:]]*/, "", rest)
            sub(/[[:space:]]*#.*$/, "", rest)
            sub(/[[:space:]]+$/, "", rest)
            # Inline list shape: drop_list: ["a","b"]  or  drop_list: [a, b]
            if (rest ~ /^\[/) {
              gsub(/^\[|\][[:space:]]*$/, "", rest)
              n = split(rest, arr, ",")
              for (i = 1; i <= n; i++) {
                v = arr[i]
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
                gsub(/^"|"$/, "", v)
                gsub(/^'\''|'\''$/, "", v)
                if (v != "") print v
              }
            } else if (rest == "") {
              # Block-list shape: bullets follow on subsequent lines.
              in_dl = 1
              dl_indent = -1
            }
          }
        } else if (ind > kf_indent && in_dl == 1) {
          if (dl_indent < 0) dl_indent = ind
          if ($0 ~ /^[[:space:]]+-[[:space:]]+/) {
            v = $0
            sub(/^[[:space:]]+-[[:space:]]+/, "", v)
            sub(/[[:space:]]*#.*$/, "", v)
            sub(/[[:space:]]+$/, "", v)
            gsub(/^"|"$/, "", v)
            gsub(/^'\''|'\''$/, "", v)
            if (v != "") print v
          } else if ($0 ~ /^[[:space:]]*[A-Za-z_]/) {
            in_dl = 0
          }
        }
      } else if (ind < base_indent) {
        in_compression = 0
        in_kf = 0
        in_dl = 0
      }
    }
  ' "$cfg")"
  if [ -z "$out" ]; then
    printf 'superseded\nexperimental\n'
    return 0
  fi
  printf '%s\n' "$out"
}

# ---------------------------------------------------------------------------
# kf_filter_stream <drop_list_file> <stats_file>
# stdin: multi-entry knowledge markdown stream (resolve-entries.sh output).
# stdout: filtered stream.
# Side effect: writes "dropped_count=N dropped_tokens=N dropped_ids=csv\n" to
# <stats_file>. On any awk failure, falls back to passthrough + zero stats.
# ---------------------------------------------------------------------------
kf_filter_stream() {
  local drop_list_file="$1"
  local stats_file="$2"
  if [ ! -f "$drop_list_file" ]; then
    printf 'dropped_count=0 dropped_tokens=0 dropped_ids=\n' > "$stats_file"
    cat
    return 0
  fi
  # Stage stdin for two-pass processing.
  local in_file out_file
  in_file="$(mktemp 2>/dev/null || printf '/tmp/kf_in_%d' "$$")"
  out_file="$(mktemp 2>/dev/null || printf '/tmp/kf_out_%d' "$$")"
  cat > "$in_file"
  # Pass: split entries on either (a) the boundary between a closing `---` and
  # the next opening `---` (frontmatter entries, detected by `^---$` lines whose
  # pair-position is 1 (mod 2)), or (b) a top-level `## ` heading (flat
  # `## K###` knowledge entries, which carry no frontmatter — M044/FR-2). A
  # frontmatter entry`s own heading (the first `# ` / `## ` line after its
  # closing fence) stays bound to it so superseded-entry drop covers heading+body.
  awk -v dlf="$drop_list_file" -v stf="$stats_file" '
    BEGIN {
      while ((getline d < dlf) > 0) {
        gsub(/[[:space:]]+/, "", d)
        if (d != "") drop[d] = 1
      }
      close(dlf)
      n = 0
      buf = ""
      in_fm = 0
      fm_seen = 0
      heading_seen = 0
      status_val = ""
      entry_id = ""
      dropped_count = 0
      dropped_tokens = 0
      dropped_ids = ""
    }
    {
      line = $0
      if (line == "---") {
        # Decide whether this is an opening fence (start of a new entry) or
        # closing fence. We use: in_fm == 0 means next "---" opens a new
        # frontmatter; in_fm == 1 means the line closes the current one.
        if (in_fm == 0) {
          # New entry beginning. Flush the previous entry buffer (if any).
          if (buf != "") {
            decide(buf, status_val, entry_id)
          }
          buf = line "\n"
          in_fm = 1
          fm_seen = 1
          heading_seen = 0
          status_val = ""
          entry_id = ""
          next
        } else {
          # Closing fence of current frontmatter.
          buf = buf line "\n"
          in_fm = 0
          next
        }
      }
      # M044/FR-2 (B-5): flat `## K###` entry boundary. A `## ` heading at top
      # level (outside frontmatter) starts a new entry — flush the prior buffer
      # first — EXCEPT the first `## ` heading immediately after a closing `---`
      # fence, which is the current frontmatter entry`s own heading and must stay
      # bound to it (so a superseded frontmatter entry drops heading+body, not
      # just its frontmatter). Flat entries carry no `status:`, so decide() keeps
      # them. Without this, a flat entry trailing a dropped frontmatter entry was
      # glued on and silently dropped with it.
      if (in_fm == 0 && line ~ /^## /) {
        if (fm_seen == 1 && heading_seen == 0) {
          # This frontmatter entry`s own heading — keep it with the entry.
          buf = buf line "\n"
          heading_seen = 1
          next
        }
        # New flat entry boundary.
        if (buf != "") {
          decide(buf, status_val, entry_id)
        }
        buf = line "\n"
        in_fm = 0
        fm_seen = 0
        heading_seen = 1
        status_val = ""
        entry_id = ""
        next
      }
      # Mark a frontmatter entry`s own heading as consumed once we pass it (its
      # title is a single-hash `# MEM###` line right after the closing fence).
      # This lets the next `## ` line be recognized as a NEW flat entry rather
      # than absorbed as this entry`s heading (M044/FR-2 — without it, a flat
      # entry trailing a single-hash-headed frontmatter entry was glued on).
      if (in_fm == 0 && fm_seen == 1 && heading_seen == 0 && line ~ /^# /) {
        heading_seen = 1
      }
      # Append every other line to the current entry buffer.
      buf = buf line "\n"
      if (in_fm == 1) {
        if (line ~ /^status:[[:space:]]/) {
          v = line
          sub(/^status:[[:space:]]*/, "", v)
          sub(/[[:space:]]+$/, "", v)
          gsub(/^"|"$/, "", v)
          gsub(/^'\''|'\''$/, "", v)
          status_val = v
        }
        if (line ~ /^id:[[:space:]]/) {
          v = line
          sub(/^id:[[:space:]]*/, "", v)
          sub(/[[:space:]]+$/, "", v)
          gsub(/^"|"$/, "", v)
          gsub(/^'\''|'\''$/, "", v)
          entry_id = v
        }
      }
    }
    END {
      if (buf != "") decide(buf, status_val, entry_id)
      printf "dropped_count=%d dropped_tokens=%d dropped_ids=%s\n", \
        dropped_count, dropped_tokens, dropped_ids > stf
      close(stf)
    }
    function decide(b, st, eid,    keep, tok) {
      keep = 1
      if (st != "" && (st in drop)) keep = 0
      tok = int(length(b) / 4)
      if (keep == 1) {
        printf "%s", b
      } else {
        dropped_count = dropped_count + 1
        dropped_tokens = dropped_tokens + tok
        if (eid == "") eid = "(unknown)"
        if (dropped_ids == "") dropped_ids = eid
        else dropped_ids = dropped_ids "," eid
      }
    }
  ' "$in_file" > "$out_file" 2>/dev/null
  local rc=$?
  if [ "$rc" -ne 0 ] || [ ! -f "$stats_file" ]; then
    # Bail-safe passthrough.
    printf 'dropped_count=0 dropped_tokens=0 dropped_ids=\n' > "$stats_file"
    cat "$in_file"
    rm -f "$in_file" "$out_file" 2>/dev/null
    return 0
  fi
  cat "$out_file"
  rm -f "$in_file" "$out_file" 2>/dev/null
  return 0
}
