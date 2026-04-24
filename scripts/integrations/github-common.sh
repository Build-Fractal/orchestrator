#!/usr/bin/env bash
# scripts/integrations/github-common.sh — Shared helpers for M013 GitHub integration.
#
# Sourced by scripts/integrations/github-init.sh (P02) and will be sourced
# by scripts/integrations/github-sync.sh (P04) and the P03 re-adoption branch.
# Pure functions only — no side effects at source time.
#
# Bash 3.2 compatible (MEM001, Constitution IX). No jq hard dep.
# No gh subprocess calls from functions documented below unless the caller
# explicitly passes --live (T02 adds that plumbing; T01 ships echo-stubs).
#
# Public functions:
#   orchestrator_id_for, emit_marker, find_marker_in_body,
#   shasum_marker_byte_identity, sidecar_path, sidecar_get_field,
#   sidecar_set_top_field, sidecar_upsert_item, sidecar_item_exists,
#   gh_auth_preflight, gh_subissue_rest_preflight, gh_label_collision_preflight.

set -u

# --- Orchestrator-ID derivation ------------------------------------------------

# orchestrator_id_for <milestone-dir> <phase-id> [<task-id>]
# Prints deterministic id: M###-P##[-T##].
# Milestone id is derived from basename of <milestone-dir> (must match M###).
# Exits 2 on bad input (missing args or malformed ids).
orchestrator_id_for() {
  local milestone_dir="${1:-}"
  local phase_id="${2:-}"
  local task_id="${3:-}"

  if [ -z "$milestone_dir" ] || [ -z "$phase_id" ]; then
    echo "orchestrator_id_for: usage: orchestrator_id_for <milestone-dir> <phase-id> [<task-id>]" >&2
    return 2
  fi

  local milestone_id
  milestone_id="$(basename "$milestone_dir")"

  if ! [[ "$milestone_id" =~ ^M[0-9]{3}$ ]]; then
    echo "orchestrator_id_for: malformed milestone id '$milestone_id' (expected M###)" >&2
    return 2
  fi
  if ! [[ "$phase_id" =~ ^P[0-9]{2}$ ]]; then
    echo "orchestrator_id_for: malformed phase id '$phase_id' (expected P##)" >&2
    return 2
  fi

  if [ -n "$task_id" ]; then
    if ! [[ "$task_id" =~ ^T[0-9]{2}$ ]]; then
      echo "orchestrator_id_for: malformed task id '$task_id' (expected T##)" >&2
      return 2
    fi
    printf '%s-%s-%s\n' "$milestone_id" "$phase_id" "$task_id"
  else
    printf '%s-%s\n' "$milestone_id" "$phase_id"
  fi
  return 0
}

# --- Marker primitives ---------------------------------------------------------

MARKER_PREFIX='<!-- orchestrator-id: '
MARKER_SUFFIX=' -->'

# emit_marker <orchestrator-id>
# Prints the FR-4 marker line (stdout only).
emit_marker() {
  local oid="${1:-}"
  if [ -z "$oid" ]; then
    echo "emit_marker: usage: emit_marker <orchestrator-id>" >&2
    return 2
  fi
  printf '%s%s%s\n' "$MARKER_PREFIX" "$oid" "$MARKER_SUFFIX"
  return 0
}

# find_marker_in_body <body-file-path> <orchestrator-id>
# Exit 0 if file contains exactly one matching marker line.
# Exit 1 if zero matches. Exit 2 if >1 matches (collision).
find_marker_in_body() {
  local body_file="${1:-}"
  local oid="${2:-}"
  if [ -z "$body_file" ] || [ -z "$oid" ]; then
    echo "find_marker_in_body: usage: find_marker_in_body <body-file> <orchestrator-id>" >&2
    return 2
  fi
  if [ ! -f "$body_file" ]; then
    echo "find_marker_in_body: body file not found: $body_file" >&2
    return 1
  fi

  local expected
  expected="${MARKER_PREFIX}${oid}${MARKER_SUFFIX}"

  local count
  count="$(grep -cFx "$expected" "$body_file" 2>/dev/null || true)"
  [ -n "$count" ] || count=0

  if [ "$count" -eq 1 ]; then
    return 0
  fi
  if [ "$count" -eq 0 ]; then
    return 1
  fi
  return 2
}

# shasum_marker_byte_identity <body-file-path> <orchestrator-id>
# For FR-4's byte-identity verification (M012 marker-bounded-atomic-writes):
# computes shasum of the expected marker line and of the line actually present
# in the body, exits 0 if identical, 1 otherwise.
shasum_marker_byte_identity() {
  local body_file="${1:-}"
  local oid="${2:-}"
  if [ -z "$body_file" ] || [ -z "$oid" ]; then
    echo "shasum_marker_byte_identity: usage: shasum_marker_byte_identity <body-file> <orchestrator-id>" >&2
    return 1
  fi
  if [ ! -f "$body_file" ]; then
    echo "shasum_marker_byte_identity: body file not found: $body_file" >&2
    return 1
  fi

  local expected expected_sha actual_line actual_sha
  expected="${MARKER_PREFIX}${oid}${MARKER_SUFFIX}"
  expected_sha="$(printf '%s\n' "$expected" | shasum 2>/dev/null | awk '{print $1}')"
  actual_line="$(grep -Fx "$expected" "$body_file" 2>/dev/null | head -n 1)"
  if [ -z "$actual_line" ]; then
    return 1
  fi
  actual_sha="$(printf '%s\n' "$actual_line" | shasum 2>/dev/null | awk '{print $1}')"

  if [ "$expected_sha" = "$actual_sha" ] && [ -n "$expected_sha" ]; then
    return 0
  fi
  return 1
}

# --- Sidecar field read/write (top-level) --------------------------------------

# sidecar_path [<project-root>]
# Prints the absolute path to .orchestrator/integrations/github.json.
sidecar_path() {
  local root="${1:-}"
  if [ -z "$root" ]; then
    local here
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    root="$(cd "${here}/../.." && pwd)"
  fi
  printf '%s/.orchestrator/integrations/github.json\n' "$root"
  return 0
}

# sidecar_get_field <field-name> [<project-root>]
# Prints the top-level JSON string/integer value (verbatim, unquoted).
# Exits 0 on hit, 1 if field absent, 2 if sidecar absent.
sidecar_get_field() {
  local field="${1:-}"
  local root="${2:-}"
  if [ -z "$field" ]; then
    echo "sidecar_get_field: usage: sidecar_get_field <field> [<root>]" >&2
    return 2
  fi
  local path
  path="$(sidecar_path "$root")"
  if [ ! -f "$path" ]; then
    echo "sidecar_get_field: sidecar not found at $path" >&2
    return 2
  fi

  # Top-level string or integer fields ONLY (not objects/arrays).
  # grep the first matching `"field": <value>` at any indent. Value may be
  # either a quoted string ("pending") or a bare number (1).
  local line
  line="$(grep -E "^[[:space:]]*\"${field}\"[[:space:]]*:[[:space:]]*(\"[^\"]*\"|[0-9]+)" "$path" 2>/dev/null | head -n 1)"
  if [ -z "$line" ]; then
    return 1
  fi

  # Extract value portion after the first colon.
  local value
  value="$(printf '%s\n' "$line" | sed -E 's/^[[:space:]]*"[^"]*"[[:space:]]*:[[:space:]]*//')"
  # Trim trailing comma + whitespace.
  value="$(printf '%s' "$value" | sed -E 's/[[:space:]]*,[[:space:]]*$//')"
  # Strip surrounding quotes if string.
  case "$value" in
    \"*\")
      value="${value#\"}"
      value="${value%\"}"
      ;;
  esac
  printf '%s\n' "$value"
  return 0
}

# sidecar_set_top_field <field-name> <new-value> [<project-root>]
# Updates a top-level JSON string field in place. Bash 3.2 + sed only.
# Exits 0 on success, 2 if sidecar absent, 3 if field absent.
sidecar_set_top_field() {
  local field="${1:-}"
  local new_value="${2:-}"
  local root="${3:-}"
  if [ -z "$field" ]; then
    echo "sidecar_set_top_field: usage: sidecar_set_top_field <field> <value> [<root>]" >&2
    return 3
  fi
  local path
  path="$(sidecar_path "$root")"
  if [ ! -f "$path" ]; then
    echo "sidecar_set_top_field: sidecar not found at $path" >&2
    return 2
  fi

  # Confirm field exists at top level before attempting edit.
  if ! grep -Eq "^[[:space:]]*\"${field}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$path"; then
    echo "sidecar_set_top_field: field '$field' not found as top-level string" >&2
    return 3
  fi

  # Escape the new value for sed replacement (& and / are the dangerous chars).
  local esc
  esc="$(printf '%s' "$new_value" | sed -e 's/[\\/&]/\\&/g')"

  local tmp
  tmp="${path}.tmp.$$"
  sed -E "s/(^[[:space:]]*\"${field}\"[[:space:]]*:[[:space:]]*\")[^\"]*(\")/\1${esc}\2/" \
    "$path" > "$tmp"
  mv "$tmp" "$path"
  return 0
}

# --- Per-item cache upsert -----------------------------------------------------

# sidecar_upsert_item <orchestrator-id> <issue-number> <project-v2-attached> \
#                     <status-field-synced> <last-attempt-iso8601> [<project-root>]
# Inserts or replaces the items.<orchestrator-id> object. AWK-based JSON object
# insertion — no jq dependency.
# Exits 0 on success, 2 if sidecar absent, 3 on malformed args.
sidecar_upsert_item() {
  local oid="${1:-}"
  local issue_num="${2:-}"
  local attached="${3:-}"
  local synced="${4:-}"
  local last_attempt="${5:-}"
  local root="${6:-}"

  if [ -z "$oid" ] || [ -z "$issue_num" ] || [ -z "$attached" ] || [ -z "$synced" ] || [ -z "$last_attempt" ]; then
    echo "sidecar_upsert_item: usage: sidecar_upsert_item <id> <issue_num> <attached> <synced> <last_attempt> [<root>]" >&2
    return 3
  fi

  # Validate booleans.
  case "$attached" in
    true|false) ;;
    *) echo "sidecar_upsert_item: project_v2_attached must be true|false" >&2; return 3 ;;
  esac
  case "$synced" in
    true|false) ;;
    *) echo "sidecar_upsert_item: status_field_synced must be true|false" >&2; return 3 ;;
  esac
  # Validate issue number.
  case "$issue_num" in
    ''|*[!0-9]*) echo "sidecar_upsert_item: issue_number must be numeric" >&2; return 3 ;;
  esac

  local path
  path="$(sidecar_path "$root")"
  if [ ! -f "$path" ]; then
    echo "sidecar_upsert_item: sidecar not found at $path" >&2
    return 2
  fi

  # Build the item object as a compact one-line JSON fragment.
  local item_line
  item_line="\"${oid}\": {\"issue_number\": ${issue_num}, \"project_v2_attached\": ${attached}, \"status_field_synced\": ${synced}, \"last_attempt_at\": \"${last_attempt}\", \"last_error\": null, \"schema_version\": 1}"

  # AWK rewrites the "items": { ... } block to upsert this entry.
  # Strategy: read whole file into memory, locate the "items": { key,
  # capture its body up to the matching closing brace (tracking depth),
  # remove any existing "<oid>": {...} entry inside, append the new entry,
  # and emit the result.
  local tmp
  tmp="${path}.tmp.$$"

  awk -v oid="$oid" -v newline="$item_line" '
    BEGIN { RS="\x00" }
    {
      blob = $0
      # Find start of items value: "items": { ...
      # Match the key literally; accept any whitespace around the colon.
      # We rely on a single occurrence of the top-level "items" key.
      key_re = "\"items\"[[:space:]]*:[[:space:]]*\\{"
      start = match(blob, key_re)
      if (start == 0) { printf "%s", blob; next }
      open_pos = start + RLENGTH - 1   # position of the opening {
      # Walk from open_pos to find the matching closing brace.
      depth = 0
      i = open_pos
      len = length(blob)
      end_pos = 0
      while (i <= len) {
        ch = substr(blob, i, 1)
        if (ch == "{") depth++
        else if (ch == "}") {
          depth--
          if (depth == 0) { end_pos = i; break }
        }
        i++
      }
      if (end_pos == 0) { printf "%s", blob; next }

      prefix = substr(blob, 1, open_pos)         # up to and including the opening {
      body   = substr(blob, open_pos + 1, end_pos - open_pos - 1)
      suffix = substr(blob, end_pos)             # from closing } to EOF

      # Remove any existing entry "oid": { ... } inside body (depth-aware).
      # Walk body to find the oid key at depth 0 relative to the items object.
      quoted = "\"" oid "\""
      body_len = length(body)
      j = 1
      out_body = ""
      skipping = 0
      while (j <= body_len) {
        if (!skipping) {
          # Look for quoted oid followed by optional ws + colon at this position.
          if (substr(body, j, length(quoted)) == quoted) {
            # Peek ahead for the colon.
            k = j + length(quoted)
            while (k <= body_len && (substr(body, k, 1) == " " || substr(body, k, 1) == "\t")) k++
            if (k <= body_len && substr(body, k, 1) == ":") {
              # Start skipping: advance past the value object and optional
              # trailing comma + whitespace.
              m = k + 1
              while (m <= body_len && (substr(body, m, 1) == " " || substr(body, m, 1) == "\t" || substr(body, m, 1) == "\n")) m++
              if (m <= body_len && substr(body, m, 1) == "{") {
                d = 1
                m++
                while (m <= body_len && d > 0) {
                  c = substr(body, m, 1)
                  if (c == "{") d++
                  else if (c == "}") d--
                  m++
                }
                # Skip optional trailing comma + whitespace/newline.
                while (m <= body_len && (substr(body, m, 1) == " " || substr(body, m, 1) == "\t" || substr(body, m, 1) == "\n" || substr(body, m, 1) == ",")) m++
                j = m
                continue
              }
            }
          }
          out_body = out_body substr(body, j, 1)
          j++
        }
      }

      # Trim trailing whitespace/newlines from out_body to decide separator.
      # Determine whether there is any non-whitespace content remaining.
      trimmed = out_body
      gsub(/[[:space:]]+$/, "", trimmed)
      gsub(/^[[:space:]]+/, "", trimmed)
      if (length(trimmed) == 0) {
        # Empty items object — insert new entry with simple formatting.
        final_body = "\n    " newline "\n  "
      } else {
        # Non-empty: ensure trailing comma on prior content, then append.
        # Strip trailing whitespace from out_body.
        rtrim = out_body
        sub(/[[:space:]]+$/, "", rtrim)
        # If last non-ws char is comma, drop it (we re-add uniformly).
        last_ch = substr(rtrim, length(rtrim), 1)
        if (last_ch == ",") {
          rtrim = substr(rtrim, 1, length(rtrim) - 1)
          sub(/[[:space:]]+$/, "", rtrim)
        }
        final_body = rtrim ",\n    " newline "\n  "
      }

      printf "%s%s%s", prefix, final_body, suffix
    }
  ' "$path" > "$tmp"

  mv "$tmp" "$path"
  return 0
}

# sidecar_item_exists <orchestrator-id> [<project-root>]
# Exit 0 if items.<orchestrator-id> has a cache entry, 1 otherwise.
sidecar_item_exists() {
  local oid="${1:-}"
  local root="${2:-}"
  if [ -z "$oid" ]; then
    echo "sidecar_item_exists: usage: sidecar_item_exists <id> [<root>]" >&2
    return 1
  fi
  local path
  path="$(sidecar_path "$root")"
  if [ ! -f "$path" ]; then
    return 1
  fi
  if grep -Eq "\"${oid}\"[[:space:]]*:[[:space:]]*\{" "$path"; then
    return 0
  fi
  return 1
}

# --- gh preflight stubs (T01 ships echo-stubs; T02 fills in live calls) --------

# gh_auth_preflight
# Enumerates `gh auth status` scopes and fails fast on missing required scope.
# Fixture path: when M013_GH_STUB_DIR is set, reads auth-status-green.txt or
# auth-status-missing-scope.txt from that directory instead of invoking gh.
# Required scopes: repo, project (read:org advisory).
# stdout: "AUTH: ok" on pass, nothing on fail. stderr: diagnostic on fail.
# Exit: 0 on pass, 1 on missing session, 2 on missing scope.
gh_auth_preflight() {
  local auth_text=""
  if [ -n "${M013_GH_STUB_DIR:-}" ]; then
    local stub="${M013_GH_STUB_DIR}/auth-status-green.txt"
    # Fixture selector: if M013_GH_STUB_AUTH is set to a filename, prefer it.
    if [ -n "${M013_GH_STUB_AUTH:-}" ]; then
      stub="${M013_GH_STUB_DIR}/${M013_GH_STUB_AUTH}"
    fi
    if [ ! -f "$stub" ]; then
      echo "integration-auth-failed: stub missing at ${stub}" >&2
      return 1
    fi
    auth_text="$(cat "$stub")"
  else
    auth_text="$(gh auth status 2>&1 || true)"
  fi

  # Detect session presence.
  if ! printf '%s\n' "$auth_text" | grep -q "Logged in to"; then
    echo "integration-auth-failed: gh auth status reports no session" >&2
    return 1
  fi

  # Detect required scopes. gh auth status prints a line like:
  #   - Token scopes: 'repo', 'read:org', 'project'
  local scopes_line
  scopes_line="$(printf '%s\n' "$auth_text" | grep -E "[Tt]oken scopes:" | head -n 1)"

  # Check each required scope.
  local needed
  for needed in repo project; do
    if ! printf '%s\n' "$scopes_line" | grep -q "'${needed}'"; then
      echo "integration-auth-failed: missing scope ${needed}" >&2
      return 2
    fi
  done

  echo "AUTH: ok"
  return 0
}

# gh_subissue_rest_preflight <repo-slug>
# Probes the sub-issue REST endpoint to determine mode.
# Fixture path: when M013_GH_STUB_DIR is set, reads subissue-rest-available.json
# (native) or subissue-rest-unavailable.json (labeled-fallback) — selector via
# M013_GH_STUB_SUBISSUE env var (defaults to available).
# stdout: "SUBISSUE_MODE: native" or "SUBISSUE_MODE: labeled-fallback".
# Exit: 0 always (fallback is valid, not an error).
gh_subissue_rest_preflight() {
  local slug="${1:-}"
  if [ -z "$slug" ]; then
    echo "gh_subissue_rest_preflight: usage: gh_subissue_rest_preflight <repo-slug>" >&2
    return 2
  fi

  if [ -n "${M013_GH_STUB_DIR:-}" ]; then
    local subname="${M013_GH_STUB_SUBISSUE:-subissue-rest-available.json}"
    local stub="${M013_GH_STUB_DIR}/${subname}"
    if [ ! -f "$stub" ]; then
      echo "SUBISSUE_MODE: labeled-fallback"
      return 0
    fi
    # If the stub response indicates the endpoint is missing (404 status or
    # "documentation_url" Not Found marker) → labeled-fallback.
    if grep -q '"status"[[:space:]]*:[[:space:]]*404' "$stub" 2>/dev/null; then
      echo "SUBISSUE_MODE: labeled-fallback"
      return 0
    fi
    if grep -q '"message"[[:space:]]*:[[:space:]]*"Not Found"' "$stub" 2>/dev/null; then
      echo "SUBISSUE_MODE: labeled-fallback"
      return 0
    fi
    echo "SUBISSUE_MODE: native"
    return 0
  fi

  # Live probe. gh api -i returns the HTTP response with headers; parse the
  # status line. Using `gh api` with `-i` and head/awk avoids jq dependency.
  local raw status
  raw="$(gh api "/repos/${slug}/issues/1/sub_issues" -i 2>/dev/null || true)"
  status="$(printf '%s\n' "$raw" | head -n 1 | awk '{print $2}')"
  case "$status" in
    404|501) echo "SUBISSUE_MODE: labeled-fallback" ;;
    *)       echo "SUBISSUE_MODE: native" ;;
  esac
  return 0
}

# gh_label_collision_preflight <repo-slug> <strict-mode-flag>
# Enumerates existing labels on the target repo and checks for collisions
# with the orchestrator-required set {phase, task, uat-bug, spec-gap}.
# - Without --strict-labels: adopt existing labels silently. stdout:
#   "LABELS: adopt-existing: <csv>" or "LABELS: no-collision".
# - With --strict-labels: refuse on any collision with non-matching color.
#   stderr: "integration-labels-collision: <label>: color=<remote-color>"
# Fixture path: when M013_GH_STUB_DIR is set, reads labels-collision.json or
# labels-empty.json (selector via M013_GH_STUB_LABELS, defaults to empty).
# Exit: 0 on pass (no collision OR adopt-mode OK), 1 on strict-collision refuse.
gh_label_collision_preflight() {
  local slug="${1:-}"
  local strict="${2:-0}"
  if [ -z "$slug" ]; then
    echo "gh_label_collision_preflight: usage: gh_label_collision_preflight <repo-slug> <strict>" >&2
    return 2
  fi

  local raw=""
  if [ -n "${M013_GH_STUB_DIR:-}" ]; then
    local labname="${M013_GH_STUB_LABELS:-labels-empty.json}"
    local stub="${M013_GH_STUB_DIR}/${labname}"
    if [ -f "$stub" ]; then
      raw="$(cat "$stub")"
    else
      raw="[]"
    fi
  else
    raw="$(gh api "/repos/${slug}/labels?per_page=100" 2>/dev/null || echo "[]")"
  fi

  # Extract label names + colors without jq. The canned JSON is pretty-printed
  # with 2-space indent — a simple grep for "name": and "color": pairs works.
  local names colors
  names="$(printf '%s\n' "$raw" | grep -E '"name"[[:space:]]*:' | sed -E 's/.*"name"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')"
  colors="$(printf '%s\n' "$raw" | grep -E '"color"[[:space:]]*:' | sed -E 's/.*"color"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')"

  local ORCH_COLOR="0e8a16"
  local collision_list=""
  local adopt_list=""
  local i=0
  local OLDIFS="$IFS"
  IFS='
'
  # Walk parallel arrays by line number.
  local n
  n="$(printf '%s\n' "$names" | grep -c .)"
  local idx=1
  while [ "$idx" -le "$n" ]; do
    local lname lcolor
    lname="$(printf '%s\n' "$names" | awk -v r="$idx" 'NR==r {print}')"
    lcolor="$(printf '%s\n' "$colors" | awk -v r="$idx" 'NR==r {print}')"
    # Is this one of the orchestrator-required labels?
    case "$lname" in
      phase|task|uat-bug|spec-gap)
        if [ "$lcolor" != "$ORCH_COLOR" ]; then
          collision_list="${collision_list}${collision_list:+,}${lname}:color=${lcolor}"
        else
          adopt_list="${adopt_list}${adopt_list:+,}${lname}"
        fi
        ;;
    esac
    idx=$((idx + 1))
  done
  IFS="$OLDIFS"

  if [ -n "$collision_list" ]; then
    if [ "$strict" = "1" ]; then
      echo "integration-labels-collision: ${collision_list}" >&2
      return 1
    fi
    echo "LABELS: adopt-existing-with-diverging-colors: ${collision_list}"
    return 0
  fi
  if [ -n "$adopt_list" ]; then
    echo "LABELS: adopt-existing: ${adopt_list}"
    return 0
  fi
  echo "LABELS: no-collision"
  return 0
}

# --- FR-15 dry-run manifest format --------------------------------------------
#
# FORMAT STABILITY CONTRACT (FR-15):
#   - Header line shape fixed: "MANIFEST: <u> <s> <e>" with single spaces.
#   - Body line shape fixed: "UPSERT: <k> <id> <t> <r>" with single spaces.
#   - Footer line shape fixed: "upserts=<N> skipped=<M> errors=<E>" without spaces around '='.
#   - Emit order: header first, then body lines in walker order (milestones,
#     project-v2, labels, phase-issues, task-subissues, project-v2-items),
#     then footer.
#   - P03 re-init adoption and P04 sync MUST reuse these helpers verbatim.
#     Changing this format is a breaking change requiring a spec amendment
#     and a version bump in the sidecar schema.
#
# Format contract (pinned in P02; reused by P03 re-init and P04 sync):
#   Line 1 (header):
#     MANIFEST: <upserts> <skipped> <errors>
#   Line 2..N (one per resource):
#     UPSERT: <resource-kind> <orchestrator-id> <target> <reason>
#   Line N+1 (footer, also printed on live runs):
#     upserts=<N> skipped=<M> errors=<E>
#
# resource-kind: one of {milestone, project-v2, label, phase-issue,
#                        task-subissue, project-v2-item}
# orchestrator-id: M###-P##[-T##] or '-' for repo-level resources (labels, project-v2 root)
# target: GitHub URL, Issue number, Project v2 node id, or '-' for labels
# reason: one of {create, adopt, skip-existing-marker}

manifest_header() {
  # $1=upserts $2=skipped $3=errors
  printf 'MANIFEST: %s %s %s\n' "$1" "$2" "$3"
}

manifest_upsert_line() {
  # $1=kind $2=orchestrator-id $3=target $4=reason
  printf 'UPSERT: %s %s %s %s\n' "$1" "$2" "$3" "$4"
}

manifest_footer() {
  # $1=upserts $2=skipped $3=errors [ $4=adopted ]
  # When $4 is omitted (P02 shape), prints the 3-field footer byte-identical
  # with P02's fixture. When $4 is set (P03 re-init adoption), appends
  # ` adopted=<A>` as an additive suffix — extension preserves fixture
  # compatibility because P02's byte-identity gate and T07 lint consume only
  # the three-number prefix via `grep -E 'upserts=[0-9]+'`.
  local up="${1:-0}" sk="${2:-0}" er="${3:-0}" ad="${4:-}"
  if [ -z "$ad" ]; then
    printf 'upserts=%s skipped=%s errors=%s\n' "$up" "$sk" "$er"
  else
    printf 'upserts=%s skipped=%s errors=%s adopted=%s\n' "$up" "$sk" "$er" "$ad"
  fi
}

# --- Re-init marker search (P03/T01) ----------------------------------------

# gh_marker_search_remote <repo-slug> <orchestrator-id>
# Searches the remote repo for an Issue whose body contains exactly one
# FR-4 marker matching <orchestrator-id>. Returns the Issue number on
# stdout on unique hit (exit 0), empty stdout + exit 1 on zero matches,
# empty stdout + exit 2 on duplicate match.
#
# Fixture-driven: when M013_GH_STUB_DIR is set and a file
# `${M013_GH_STUB_DIR}/issue-list-<oid>.json` exists, the function reads
# that file instead of invoking `gh`. The JSON is an array of
# `{"number": N}` objects; the function uses awk to parse count + first
# number without a jq hard-dep.
#
# Live mode: invokes `gh issue list --state all --search
# "\"<!-- orchestrator-id: <oid> -->\"" --json number` and parses the
# returned JSON array by line count.
#
# Used by: scripts/integrations/github-init.sh P03 re-init adoption branch.
gh_marker_search_remote() {
  local slug="${1:-}"
  local oid="${2:-}"
  if [ -z "$slug" ] || [ -z "$oid" ]; then
    echo "gh_marker_search_remote: missing args (slug, oid)" >&2
    return 3
  fi
  local json_file=""
  local json_content=""
  if [ -n "${M013_GH_STUB_DIR:-}" ]; then
    json_file="${M013_GH_STUB_DIR}/issue-list-${oid}.json"
    if [ -f "$json_file" ]; then
      json_content="$(cat "$json_file")"
    else
      # Absence is equivalent to zero matches.
      json_content="[]"
    fi
  else
    # Live mode; repo-slug passed via -R to scope the search.
    local marker
    marker="$(emit_marker "$oid")"
    json_content="$(gh issue list -R "$slug" --state all \
      --search "\"${marker}\"" --json number 2>/dev/null || echo '[]')"
  fi
  # Count and first-number extraction via awk (no jq hard-dep).
  local count
  count="$(printf '%s\n' "$json_content" | awk '
    BEGIN { n = 0 }
    { for (i = 1; i <= length($0); i++) {
        c = substr($0, i, 1)
        if (c == "{") n++
      }
    }
    END { print n }
  ')"
  if [ "$count" -eq 0 ]; then
    return 1
  fi
  if [ "$count" -gt 1 ]; then
    return 2
  fi
  # Extract the first number from the JSON.
  local num
  num="$(printf '%s\n' "$json_content" | awk '
    /"number"/ {
      n = 0
      for (i = 1; i <= length($0); i++) {
        c = substr($0, i, 1)
        if (c ~ /[0-9]/) {
          num = num c
        } else if (num != "") {
          print num
          exit
        }
      }
    }
  ' | head -n 1)"
  printf '%s\n' "$num"
  return 0
}

# --- HTTP probe (P04/T01) ----------------------------------------------------

# http_probe <rest-path>
# ----------------------------------------------------------------------------
# Wraps `gh api --include <path>`, parses HTTP status line + X-RateLimit-Remaining
# header, emits STATUS=<int>, RATE_LIMIT_REMAINING=<int>, RATE_LIMIT_RESET=<int>
# lines to stdout. Returns 0 on 2xx, 3 on 403 with rate-limited body, 4 on 401,
# 1 on other error / empty response.
#
# Fixture-driven: when M013_GH_STUB_DIR is set and
# `${M013_GH_STUB_DIR}/http-probe-<slug>.txt` exists, reads that file instead
# of invoking `gh`. <slug> is <rest-path> with leading slash stripped and
# remaining slashes replaced by underscores.
#
# Bash 3.2 compatible. jq-optional (awk+sed only).
http_probe() {
  local path="${1:-}"
  if [ -z "$path" ]; then
    echo "http_probe: missing arg (rest-path)" >&2
    return 1
  fi
  local stub="${M013_GH_STUB_DIR:-}"
  local slug
  slug="$(printf '%s' "$path" | sed 's#^/##; s#/#_#g')"
  local raw=""
  if [ -n "$stub" ] && [ -f "${stub}/http-probe-${slug}.txt" ]; then
    raw="$(cat "${stub}/http-probe-${slug}.txt")"
  else
    raw="$(gh api --include "$path" 2>/dev/null || true)"
  fi
  if [ -z "$raw" ]; then
    return 1
  fi
  local status rem reset
  status="$(printf '%s\n' "$raw" | awk '/^HTTP\// { for (i=1;i<=NF;i++) if ($i ~ /^[0-9][0-9][0-9]$/) { print $i; exit } }')"
  rem="$(printf '%s\n' "$raw" | awk '/^X-RateLimit-Remaining:/ { print $2; exit }' | tr -d '\r')"
  reset="$(printf '%s\n' "$raw" | awk '/^X-RateLimit-Reset:/ { print $2; exit }' | tr -d '\r')"
  echo "STATUS=${status:-0}"
  echo "RATE_LIMIT_REMAINING=${rem:-}"
  echo "RATE_LIMIT_RESET=${reset:-}"
  case "${status:-}" in
    2??) return 0 ;;
    401) return 4 ;;
    403)
      if printf '%s\n' "$raw" | grep -q "rate limit"; then
        return 3
      fi
      return 1
      ;;
    *) return 1 ;;
  esac
}

# --- Sidecar per-item cache update (P04/T01) ---------------------------------

# sidecar_update_item_cache <oid> <last-attempt-iso> <last-error-or-null>
#                          <status-field-synced-bool> <project-v2-attached-bool>
#                          [<root>]
# ----------------------------------------------------------------------------
# Updates the four mutable per-item cache fields in
# .orchestrator/integrations/github.json for items.<oid>. Preserves
# issue_number. Atomic write (temp-file + rename).
#
# Exit codes:
#   0 on success
#   2 on sidecar-absent (FR-11 reversibility: no-op cleanly)
#   2 on sidecar holding pending-operator-complete sentinel (FR-11)
#
# Root defaults to ".". Callers pass a fixture root to redirect the write.
# Bash 3.2 compatible. jq-optional (awk + sed only).
sidecar_update_item_cache() {
  local oid="${1:-}"
  local ts="${2:-}"
  local err="${3:-null}"
  local synced="${4:-false}"
  local attached="${5:-false}"
  local root="${6:-.}"
  if [ -z "$oid" ] || [ -z "$ts" ]; then
    echo "sidecar_update_item_cache: missing args (oid, ts)" >&2
    return 2
  fi
  local sc="${root}/.orchestrator/integrations/github.json"
  if [ ! -f "$sc" ]; then
    echo "sidecar-not-configured: ${sc}" >&2
    return 2
  fi
  if grep -q '"pending"' "$sc"; then
    echo "sidecar-pending-operator-complete: ${sc}" >&2
    return 2
  fi
  local tmp
  tmp="$(mktemp -t m013-sc-update.XXXXXX)"
  awk -v oid="$oid" -v ts="$ts" -v err="$err" -v sy="$synced" -v at="$attached" '
    BEGIN { in_oid = 0 }
    {
      line = $0
      if (match(line, "\"" oid "\"[ \t]*:[ \t]*\\{")) { in_oid = 1 }
      if (in_oid == 1) {
        gsub(/"last_attempt_at":[ \t]*"[^"]*"/, "\"last_attempt_at\": \"" ts "\"", line)
        if (err == "null") {
          gsub(/"last_error":[ \t]*(null|"[^"]*")/, "\"last_error\": null", line)
        } else {
          gsub(/"last_error":[ \t]*(null|"[^"]*")/, "\"last_error\": \"" err "\"", line)
        }
        gsub(/"status_field_synced":[ \t]*(true|false)/, "\"status_field_synced\": " sy, line)
        gsub(/"project_v2_attached":[ \t]*(true|false)/, "\"project_v2_attached\": " at, line)
        if (match(line, /\}/)) { in_oid = 0 }
      }
      print line
    }
  ' "$sc" > "$tmp"
  mv "$tmp" "$sc"
  return 0
}

# --- Tier 1 JSONL emitter (P04/T01) ------------------------------------------

# emit_tier1_record <record-type> <key>=<value> [<key>=<value>...]
# ----------------------------------------------------------------------------
# Appends one JSONL record to .orchestrator/execution-log.jsonl in the
# M019 Tier 1 shape: {"ts":"<ISO>","event":"<type>","source":"runtime",<kv>...}
# Values are JSON-escaped (backslash, double-quote). Keys are emitted in the
# order they arrive (callers are responsible for stable ordering). Numeric /
# null / bool values bypass quoting.
#
# Respects ORCHESTRATOR_ROOT env var for state root (M008/M015 4-rule resolver
# convention); defaults to ".orchestrator".
#
# Append-only; never rotates. FR-17: source is hard-coded "runtime".
#
# Bash 3.2 compatible. jq-optional (sed + printf only).
emit_tier1_record() {
  local rtype="${1:-}"
  if [ -z "$rtype" ]; then
    echo "emit_tier1_record: missing record-type arg" >&2
    return 2
  fi
  shift
  local root="${ORCHESTRATOR_ROOT:-.orchestrator}"
  local log="${root}/execution-log.jsonl"
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local out
  out='{"ts":"'"${ts}"'","event":"'"${rtype}"'","source":"runtime"'
  local pair key val esc
  for pair in "$@"; do
    key="${pair%%=*}"
    val="${pair#*=}"
    case "$val" in
      null|true|false)
        out="${out},\"${key}\":${val}"
        ;;
      ''|*[!0-9-]*)
        esc="$(printf '%s' "$val" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"
        out="${out},\"${key}\":\"${esc}\""
        ;;
      *)
        out="${out},\"${key}\":${val}"
        ;;
    esac
  done
  out="${out}}"
  mkdir -p "$root"
  printf '%s\n' "$out" >> "$log"
  return 0
}

# --- FR-16 rc classifier (P04/T03) -------------------------------------------

# classify_gh_rc <rc> <stderr-snapshot-path>
# ----------------------------------------------------------------------------
# Maps a `gh` subprocess rc + stderr content into an FR-16 class string plus a
# return code. Callers invoke via command-substitution of the echoed string and
# also inspect the function's return status:
#
#   rc=0                                                  -> echo "ok";             return 0
#   HTTP 403 + X-RateLimit-Remaining:0 | "rate limit"
#     | GraphQL "RATE_LIMITED"                            -> echo "rate-limit <reset>"; return 3
#   HTTP 401 | authentication required/failed | "gh auth" -> echo "auth-expired";   return 4
#   else                                                  -> echo "other";          return 1
#
# Bash 3.2 + grep/awk/sed only. jq-optional.
classify_gh_rc() {
  local rc="${1:-1}"
  local errfile="${2:-}"
  if [ "$rc" -eq 0 ]; then
    echo "ok"
    return 0
  fi
  if [ -n "$errfile" ] && [ -f "$errfile" ]; then
    if grep -qE '(HTTP 403|403 rate limit|RATE_LIMITED|API rate limit exceeded)' "$errfile"; then
      local reset
      reset="$(grep -E 'X-RateLimit-Reset:' "$errfile" | awk '{print $2}' | tr -d '\r' | head -n 1)"
      echo "rate-limit ${reset:-unknown}"
      return 3
    fi
    if grep -qE '(HTTP 401|authentication (required|failed)|gh auth)' "$errfile"; then
      echo "auth-expired"
      return 4
    fi
  fi
  echo "other"
  return 1
}

# --- FR-17 conversus gate record emitter (P04/T03) ---------------------------

# emit_conversus_gate_record <issue-ref> <timeout-sec> <verdict> <rc> <duration-ms> [<edition>]
# ----------------------------------------------------------------------------
# Thin wrapper around emit_tier1_record for the conversus gate call site.
# Shared between github-sync.sh (if the gate is invoked inline) and the
# standalone github-conversus-gate.sh (T05). Honors source:"runtime" via
# emit_tier1_record and respects ORCHESTRATOR_ROOT for state root resolution.
#
# M026/P02/T02 (FR-4, AD-4): accepts an optional 6th positional `edition`
# argument ∈ {oss, paid, unknown} resolved from the conversus adapter's
# `check` output. Emits `adapter_version` (M019 Tier 1 provenance marker)
# immediately followed by `edition` so the two provenance fields cluster
# adjacently per AD-4. Defaults to "unknown" when the caller omits the
# argument — backward compatible, no caller breakage (AD-4 additive).
emit_conversus_gate_record() {
  local ref="${1:-}"
  local to="${2:-}"
  local verdict="${3:-}"
  local rc="${4:-}"
  local dur="${5:-}"
  local edition="${6:-unknown}"
  emit_tier1_record conversus_gate_invocation \
    "issue_ref=${ref}" \
    "timeout_sec=${to}" \
    "verdict=${verdict}" \
    "adapter_version=m013-p04" \
    "edition=${edition}" \
    "rc=${rc}" \
    "duration_ms=${dur}"
}

# --- Self-check when run directly ---------------------------------------------

# If executed directly (not sourced), print a friendly usage hint and exit 0.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  echo "scripts/integrations/github-common.sh: this is a helper library; source it, don't run it."
  echo "Public functions: orchestrator_id_for, emit_marker, find_marker_in_body, shasum_marker_byte_identity,"
  echo "                  sidecar_path, sidecar_get_field, sidecar_set_top_field,"
  echo "                  sidecar_upsert_item, sidecar_item_exists,"
  echo "                  gh_auth_preflight, gh_subissue_rest_preflight, gh_label_collision_preflight,"
  echo "                  manifest_header, manifest_upsert_line, manifest_footer,"
  echo "                  gh_marker_search_remote,"
  echo "                  http_probe, sidecar_update_item_cache, emit_tier1_record,"
  echo "                  classify_gh_rc, emit_conversus_gate_record."
  exit 0
fi
