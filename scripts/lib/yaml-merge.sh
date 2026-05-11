#!/usr/bin/env bash
# scripts/lib/yaml-merge.sh — Shared YAML-merge primitive (M037 P01 T06, FR-10/FR-11).
#
# Merges a framework-default YAML file into an on-disk target YAML file under
# a per-top-level-key namespace classification. Single-script-file shape per
# AD-19. Bash 3.2 + POSIX sh per MEM001. NO yq, NO python — sed/awk only.
#
# Usage:
#   bash scripts/lib/yaml-merge.sh merge \
#     --target <file> --framework-default <file> \
#     --managed-namespaces <comma-separated-list> \
#     [--replace-list-keys <comma-separated-list>] [--dry-run]
#
# Behaviour (per T06 plan):
#   - If target absent → copy framework-default byte-identical, exit 0.
#   - For each top-level key in framework default:
#     - key IS in managed_namespaces → framework wins (replace target's block).
#     - key NOT in managed_namespaces AND present in target → operator wins
#       (target's block byte-identical).
#     - key NOT in managed_namespaces AND absent from target → append framework
#       default's block (new orchestrator-managed default the operator hasn't
#       customized).
#   - Operator-authored top-level keys present in target but absent from
#     framework default → preserve byte-identical, anchored to the last
#     framework-known key that preceded them in target order (preserves
#     relative position).
#   - Header (lines preceding the first top-level key): prefer target's,
#     else framework's.
#   - --dry-run: emit merged content to stdout, no write.
#
# --replace-list-keys (PC-7, paper-cut-sweep-post-M035):
#   Opt-in framework-wins override at sub-key granularity inside managed
#   namespaces. Default behaviour (flag absent or empty) preserves the
#   pre-PC-7 contract: under a managed top-level key present in BOTH framework
#   and target, sub-key values come from target byte-identical (operator wins
#   on value).
#
#   When the flag is set to a comma-separated list of sub-key names, those
#   sub-keys are taken from the framework default instead of the target. This
#   addresses the M037 round-5 list-element preservation gap: framework-side
#   list mutations (additions/removals) do not propagate to existing projects
#   because operator-wins-byte-identical at sub-key level holds the entire
#   list. Callers opt-in per-sub-key via this flag; back-compat preserved for
#   every existing call site that does not pass the flag.
#
# FR-11 fail-closed: if either input cannot be parsed (mismatched indentation,
# syntactically broken top-level key lines, etc.), abort with diagnostic to
# stderr, write nothing, exit 4.
#
# Top-level key detection: regex `^[a-zA-Z_][a-zA-Z0-9_-]*:` — matches the
# convention in templates/orchestrator-config-default.yml and wiki/mkdocs.yml
# (2-space indentation, no flow-style, no anchors).
#
# Exit codes:
#   0  success
#   2  argument error
#   4  fail-closed (YAML parse error)
#   5  I/O error (target dir not writable, etc.)

set -u

SUBCOMMAND="${1:-}"
if [ "$SUBCOMMAND" != "merge" ]; then
  if [ "$SUBCOMMAND" = "--help" ] || [ "$SUBCOMMAND" = "-h" ] || [ -z "$SUBCOMMAND" ]; then
    cat <<'EOF'
yaml-merge.sh — shared YAML-merge primitive (M037 FR-10/FR-11).

Usage:
  bash scripts/lib/yaml-merge.sh merge \
    --target <file> --framework-default <file> \
    --managed-namespaces <comma-list> \
    [--replace-list-keys <comma-list>] [--dry-run]

See script header for full behaviour. managed_namespaces classifies which
top-level keys are owned by the framework (replaced on merge) versus
operator-authored (preserved byte-identical). --replace-list-keys (PC-7)
opt-in flag: under managed top-level keys, sub-keys named in this list use
the framework default instead of the operator's value byte-identical
(addresses the M037 round-5 list-element preservation gap; default behaviour
unchanged when flag absent).
EOF
    exit 0
  fi
  echo "FAIL: yaml-merge: unknown subcommand '$SUBCOMMAND' (try 'merge' or '--help')" >&2
  exit 2
fi
shift

TARGET=""
FRAMEWORK=""
MANAGED=""
REPLACE_LIST_KEYS=""
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="$2"; shift 2;;
    --framework-default) FRAMEWORK="$2"; shift 2;;
    --managed-namespaces) MANAGED="$2"; shift 2;;
    --replace-list-keys) REPLACE_LIST_KEYS="$2"; shift 2;;
    --dry-run) DRY_RUN=1; shift;;
    *) echo "FAIL: yaml-merge: unknown flag '$1'" >&2; exit 2;;
  esac
done

if [ -z "$TARGET" ] || [ -z "$FRAMEWORK" ] || [ -z "$MANAGED" ]; then
  echo "FAIL: yaml-merge: --target, --framework-default, --managed-namespaces all required" >&2
  exit 2
fi

if [ ! -f "$FRAMEWORK" ]; then
  echo "FAIL: yaml-merge: framework-default not found: $FRAMEWORK" >&2
  exit 2
fi

# Target absent: byte-identical copy from framework default. (CON-3 honored —
# no operator content exists yet, so no preservation needed.)
if [ ! -e "$TARGET" ]; then
  if [ "$DRY_RUN" = "1" ]; then
    cat "$FRAMEWORK"
    exit 0
  fi
  target_dir="$(dirname "$TARGET")"
  if [ ! -d "$target_dir" ]; then
    if ! mkdir -p "$target_dir" 2>/dev/null; then
      echo "FAIL: yaml-merge: cannot create target dir $target_dir" >&2
      exit 5
    fi
  fi
  cp "$FRAMEWORK" "$TARGET"
  exit 0
fi

# Workspace for parsed blocks.
WORK="$(mktemp -d -t yaml-merge.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT INT TERM

# parse_blocks <input-file> <out-dir>
#   Splits <input-file> into block files. Top-level keys detected by
#   ^[a-zA-Z_][a-zA-Z0-9_-]*:
#   Emits:
#     <out-dir>/order.txt   ordered list of block IDs (one per line; "__HEADER__" first if non-empty)
#     <out-dir>/key-<key>   block content for top-level key (raw bytes)
#     <out-dir>/__HEADER__  header content (if non-empty)
#   Exit 4 on parse error (e.g., a top-level key line repeated).
parse_blocks() {
  _in="$1"
  _out="$2"
  : > "$_out/order.txt"
  # FR-11 fail-closed pre-check: scan for obvious malformed-YAML signals on any
  # NON-comment line. Catches the canonical "unclosed quote" scenario used by
  # the malformed-yaml-fail-closed verifier, plus a handful of cheap shape
  # mistakes. NOT a full YAML parser; the line-oriented design assumes
  # well-formed top-level structure (per templates/orchestrator-config-default.yml
  # and wiki/mkdocs.yml conventions).
  awk '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    {
      line = $0
      # Strip in-line comments (best-effort: strip from first " #" onwards).
      sub(/[[:space:]]+#.*$/, "", line)
      # Count unescaped double-quote characters.
      count = 0
      i = 1
      n = length(line)
      while (i <= n) {
        c = substr(line, i, 1)
        if (c == "\\" && i < n) { i += 2; continue }
        if (c == "\"") count++
        i++
      }
      if (count % 2 != 0) {
        print "YAML_PARSE_ERROR: line " NR ": odd number of unescaped double-quotes (likely unclosed string)" > "/dev/stderr"
        print line > "/dev/stderr"
        exit 4
      }
    }
  ' "$_in"
  pre_rc=$?
  if [ "$pre_rc" -ne 0 ]; then
    return 4
  fi
  awk -v outdir="$_out" '
    BEGIN {
      current = "__HEADER__"
      block_file = outdir "/__HEADER__"
      header_has_content = 0
      header_emitted = 0
      order_file = outdir "/order.txt"
      printf "" > block_file
    }
    {
      if (match($0, /^[a-zA-Z_][a-zA-Z0-9_-]*:/)) {
        new_key = substr($0, 1, RLENGTH - 1)
        if (seen[new_key] == 1) {
          print "YAML_PARSE_ERROR: duplicate top-level key: " new_key > "/dev/stderr"
          exit 4
        }
        seen[new_key] = 1
        if (header_has_content == 1 && header_emitted == 0) {
          print "__HEADER__" >> order_file
          header_emitted = 1
        }
        current = new_key
        block_file = outdir "/key-" new_key
        print new_key >> order_file
        printf "" > block_file
        print $0 >> block_file
        next
      }
      print $0 >> block_file
      if (current == "__HEADER__") header_has_content = 1
    }
    END {
      if (current == "__HEADER__" && header_has_content == 1 && header_emitted == 0) {
        print "__HEADER__" >> order_file
      }
    }
  ' "$_in"
  awk_rc=$?
  if [ "$awk_rc" -ne 0 ]; then
    return 4
  fi
  # Sanity: every key file must exist for entries in order.txt.
  while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    if [ "$entry" = "__HEADER__" ]; then
      [ -f "$_out/__HEADER__" ] || return 4
    else
      [ -f "$_out/key-$entry" ] || return 4
    fi
  done < "$_out/order.txt"
  return 0
}

mkdir -p "$WORK/fw" "$WORK/tg"

if ! parse_blocks "$FRAMEWORK" "$WORK/fw"; then
  echo "FAIL: yaml-merge: framework-default $FRAMEWORK failed YAML parse" >&2
  exit 4
fi

if ! parse_blocks "$TARGET" "$WORK/tg"; then
  echo "FAIL: yaml-merge: target $TARGET failed YAML parse: malformed top-level key structure" >&2
  exit 4
fi

# Helper: is-managed <key> <managed-list>
is_managed() {
  _k="$1"
  _list="$2"
  case ",$_list," in
    *",$_k,"*) return 0 ;;
  esac
  return 1
}

# Helper: is-in-replace-list <sub-key> <replace-list>
# PC-7: comma-separated membership check; empty list always returns 1.
is_in_replace_list() {
  _k="$1"
  _list="$2"
  [ -z "$_list" ] && return 1
  case ",$_list," in
    *",$_k,"*) return 0 ;;
  esac
  return 1
}

# Helper: target-has-key <key>
target_has_key() {
  [ -f "$WORK/tg/key-$1" ]
}

# Build "insertions": for each target key not in framework, the anchor
# (last framework-known key that preceded it in target order; "__HEADER__"
# if none).
INSERT_DIR="$WORK/insert"
mkdir -p "$INSERT_DIR"
last_anchor="__HEADER__"
while IFS= read -r entry; do
  [ -z "$entry" ] && continue
  [ "$entry" = "__HEADER__" ] && continue
  if [ -f "$WORK/fw/key-$entry" ]; then
    last_anchor="$entry"
  else
    # Append this target-only key under its anchor.
    printf '%s\n' "$entry" >> "$INSERT_DIR/anchor-$last_anchor"
  fi
done < "$WORK/tg/order.txt"

# Compose output.
OUT="$WORK/merged.yml"
: > "$OUT"

# Header: prefer target's if non-empty, else framework's.
if [ -s "$WORK/tg/__HEADER__" ]; then
  cat "$WORK/tg/__HEADER__" >> "$OUT"
elif [ -s "$WORK/fw/__HEADER__" ]; then
  cat "$WORK/fw/__HEADER__" >> "$OUT"
fi

# Emit any target-only keys anchored to __HEADER__.
if [ -f "$INSERT_DIR/anchor-__HEADER__" ]; then
  while IFS= read -r tk; do
    [ -z "$tk" ] && continue
    cat "$WORK/tg/key-$tk" >> "$OUT"
  done < "$INSERT_DIR/anchor-__HEADER__"
fi

# merge_managed_block <fw-block-file> <tg-block-file>
#   For a managed top-level key present in BOTH framework and target, emit a
#   merged block where:
#     - The block-header line (the `^K:` line itself plus any framework
#       trailing comments preceding the first sub-key) comes from the
#       framework default (so framework controls key-level metadata).
#     - For each sub-key in the framework's block (lines matching
#       `^[[:space:]]+[a-zA-Z_][...]:` at the first nesting level): if the
#       target has the same sub-key, keep target's sub-block (operator wins
#       on value); else emit framework's sub-block (new managed default).
#     - Sub-keys present in target but absent from framework are appended at
#       the end (operator-only sub-keys preserved byte-identical).
#   This implements the "managed namespace" semantics from T06 plan §123-145:
#   framework controls which sub-keys EXIST under a managed top-level key;
#   operator's values for those sub-keys survive byte-identical.
merge_managed_block() {
  _fw="$1"
  _tg="$2"
  _scratch="$WORK/scratch-$RANDOM"
  mkdir -p "$_scratch/fw-sub" "$_scratch/tg-sub"
  # Sub-key parser: top-level header line is the FIRST line; sub-keys are
  # lines matching ^<spaces><ident>: at the smallest non-zero indent observed.
  # For both targeted files (orchestrator-config-default.yml and mkdocs.yml)
  # the first nesting level is 2 spaces.
  _split_subkeys() {
    _in="$1"
    _outdir="$2"
    awk -v outdir="$_outdir" '
      BEGIN {
        current = "__HEAD__"
        bf = outdir "/__HEAD__"
        order_file = outdir "/order.txt"
        printf "" > bf
      }
      {
        if (match($0, /^  [a-zA-Z_][a-zA-Z0-9_-]*:/)) {
          line = $0
          sub(/^  /, "", line)
          name = line
          sub(/:.*/, "", name)
          current = name
          bf = outdir "/sub-" name
          if (!(name in seen)) {
            print name >> order_file
            seen[name] = 1
          }
          printf "" > bf
        }
        print $0 >> bf
      }
    ' "$_in"
  }
  : > "$_scratch/fw-sub/order.txt"
  : > "$_scratch/tg-sub/order.txt"
  _split_subkeys "$_fw" "$_scratch/fw-sub"
  _split_subkeys "$_tg" "$_scratch/tg-sub"
  # Header from framework.
  if [ -s "$_scratch/fw-sub/__HEAD__" ]; then
    cat "$_scratch/fw-sub/__HEAD__" >> "$OUT"
  fi
  # Walk framework's sub-key order.
  while IFS= read -r sk; do
    [ -z "$sk" ] && continue
    if is_in_replace_list "$sk" "$REPLACE_LIST_KEYS"; then
      # PC-7 opt-in override: framework wins regardless of target's presence.
      cat "$_scratch/fw-sub/sub-$sk" >> "$OUT"
    elif [ -f "$_scratch/tg-sub/sub-$sk" ]; then
      cat "$_scratch/tg-sub/sub-$sk" >> "$OUT"
    else
      cat "$_scratch/fw-sub/sub-$sk" >> "$OUT"
    fi
  done < "$_scratch/fw-sub/order.txt"
  # Append target-only sub-keys.
  while IFS= read -r sk; do
    [ -z "$sk" ] && continue
    if [ ! -f "$_scratch/fw-sub/sub-$sk" ]; then
      cat "$_scratch/tg-sub/sub-$sk" >> "$OUT"
    fi
  done < "$_scratch/tg-sub/order.txt"
  rm -rf "$_scratch"
}

# Walk framework's key order.
while IFS= read -r entry; do
  [ -z "$entry" ] && continue
  [ "$entry" = "__HEADER__" ] && continue
  if is_managed "$entry" "$MANAGED"; then
    if target_has_key "$entry"; then
      # Sub-key-aware merge: operator's sub-key values survive byte-identical.
      merge_managed_block "$WORK/fw/key-$entry" "$WORK/tg/key-$entry"
    else
      cat "$WORK/fw/key-$entry" >> "$OUT"
    fi
  elif target_has_key "$entry"; then
    cat "$WORK/tg/key-$entry" >> "$OUT"
  else
    cat "$WORK/fw/key-$entry" >> "$OUT"
  fi
  # Emit any target-only keys anchored to this framework key.
  if [ -f "$INSERT_DIR/anchor-$entry" ]; then
    while IFS= read -r tk; do
      [ -z "$tk" ] && continue
      cat "$WORK/tg/key-$tk" >> "$OUT"
    done < "$INSERT_DIR/anchor-$entry"
  fi
done < "$WORK/fw/order.txt"

# Emit.
if [ "$DRY_RUN" = "1" ]; then
  cat "$OUT"
  exit 0
fi

# Write atomically.
target_dir="$(dirname "$TARGET")"
if [ ! -d "$target_dir" ]; then
  if ! mkdir -p "$target_dir" 2>/dev/null; then
    echo "FAIL: yaml-merge: cannot create target dir $target_dir" >&2
    exit 5
  fi
fi
tmpf="$(mktemp -t yaml-merge-write.XXXXXX)"
cat "$OUT" > "$tmpf"
mv "$tmpf" "$TARGET"
exit 0
