#!/usr/bin/env bash
# scripts/util/settings-merge.sh -- M025/P01/T02: merge-not-overwrite helper
# for user-scope settings.json files. Preserves non-orchestrator keys
# byte-identically (semantically) and inserts orchestrator hooks via an
# inline "_orchestrator_managed": true tag for reversible uninstall.
#
# CLI:
#   bash scripts/util/settings-merge.sh merge \
#       --target <path> --fragment <json-string> [--dry-run] [--force]
#   bash scripts/util/settings-merge.sh uninstall \
#       --target <path> [--dry-run]
#
# Merge algorithm:
#   1. If target does not exist, write fragment verbatim (new-file path).
#   2. If target exists but is not valid JSON, exit 4 (no write).
#   3. For each top-level key in fragment:
#      - key == "hooks": deep-merge per-event arrays. Append fragment leaves
#        ONLY if an equivalent (event, matcher, command) tuple is not already
#        present in the target's _orchestrator_managed scope. The dedup key
#        is the full (event, matcher, command) tuple within the
#        _orchestrator_managed:true overlay -- M028/P02/T03 promotion of the
#        M025/P01/T02 command-only key. --force bypasses the guard so manual
#        edits stripping the managed tag can be recovered.
#      - any other key: set only if absent in target.
#   4. Every non-orchestrator top-level key in target survives structurally.
#   5. Write via temp-file-then-rename ($target.tmp.$$ -> mv -f).
#   User-authored entries (no _orchestrator_managed tag) are NEVER deduplicated
#   against orchestrator entries -- they pass through untouched.
#
# Uninstall algorithm:
#   1. Parse target as JSON; exit 4 on parse failure.
#   2. Strip objects whose hooks[].command carries "_orchestrator_managed": true.
#   3. Cascade cleanup: empty wrapper -> drop; empty event array -> drop key;
#      empty hooks object -> drop hooks key.
#   4. Write via temp-file-then-rename. Report removed=<N> (outer-wrapper count).
#
# Implementation: python3 baseline (repo-wide gate precedent). The plan's
# original sketch named a jq-with-awk/sed fallback; T02 planner-judgment
# deviation substitutes python3 for the awk/sed branch because implementing
# JSON parse + deep-merge in awk for bash 3.2 is a multi-hundred-line exercise
# that dwarfs the rest of T02, and python3 is already a de-facto baseline in
# this repo's verifier gates (see scripts/verify/m013-p04-*.sh). jq remains
# a supported future optimization via `command -v jq`; current path is
# python3-only. Bash 3.2 compatible -- no associative arrays, mapfile,
# process substitution, &>, or ${var^^}/${var,,}.
#
# Exit codes:
#   0 success
#   1 usage / generic failure
#   2 missing required arg
#   4 target file is not valid JSON (refuse to merge / uninstall)

set -u

SUBCMD="${1:-}"
[ -n "$SUBCMD" ] && shift || true

TARGET=""
FRAGMENT=""
DRY_RUN=0
FORCE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --target)
      shift
      if [ $# -eq 0 ]; then
        echo "FAIL: --target requires a path argument" >&2
        exit 2
      fi
      TARGET="$1"; shift ;;
    --target=*)
      TARGET="${1#--target=}"; shift ;;
    --fragment)
      shift
      if [ $# -eq 0 ]; then
        echo "FAIL: --fragment requires a JSON string argument" >&2
        exit 2
      fi
      FRAGMENT="$1"; shift ;;
    --fragment=*)
      FRAGMENT="${1#--fragment=}"; shift ;;
    --dry-run)
      DRY_RUN=1; shift ;;
    --force)
      FORCE=1; shift ;;
    *)
      echo "FAIL: unknown argument '$1'" >&2
      exit 1 ;;
  esac
done

if [ -z "$SUBCMD" ]; then
  echo "usage: settings-merge.sh {merge|uninstall} --target <path> [--fragment <json>] [--dry-run] [--force]" >&2
  exit 1
fi

if [ -z "$TARGET" ]; then
  echo "FAIL: --target is required" >&2
  exit 2
fi

# Require python3 (baseline invariant per m013-p04-* gate precedent).
if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: python3 not found on PATH" >&2
  exit 1
fi

# --- Merge subcommand ---
if [ "$SUBCMD" = "merge" ]; then
  if [ -z "$FRAGMENT" ]; then
    echo "FAIL: merge requires --fragment <json-string>" >&2
    exit 2
  fi

  # New-file path: target does not exist. Route through the same python
  # serializer as the merge path so sha256 across runs is byte-identical
  # (idempotency invariant: second install reparses+reserializes, so the
  # new-file write must produce the same canonical form).
  if [ ! -e "$TARGET" ]; then
    target_dir="$(dirname "$TARGET")"
    mkdir -p "$target_dir"
    FRAGMENT_ENV="$FRAGMENT" TARGET_PATH="$TARGET" DRY_RUN_FLAG="$DRY_RUN" python3 <<'PYEOF'
import json, os, sys
target_path = os.environ["TARGET_PATH"]
fragment_raw = os.environ["FRAGMENT_ENV"]
dry_run = os.environ.get("DRY_RUN_FLAG", "0") == "1"
try:
    fragment = json.loads(fragment_raw)
except Exception as e:
    sys.stderr.write("FAIL: --fragment is not valid JSON: %s\n" % e)
    sys.exit(1)
out = json.dumps(fragment, indent=2, sort_keys=True)
if dry_run:
    print("would_write=%s" % target_path)
    print(out)
    sys.exit(0)
tmp = "%s.tmp.%d" % (target_path, os.getpid())
with open(tmp, "w") as f:
    f.write(out)
    f.write("\n")
os.replace(tmp, target_path)
print("wrote=%s" % target_path)
PYEOF
    exit $?
  fi

  # Existing-file path: parse + deep-merge via python3.
  FRAGMENT_ENV="$FRAGMENT" TARGET_PATH="$TARGET" FORCE_FLAG="$FORCE" \
  DRY_RUN_FLAG="$DRY_RUN" python3 <<'PYEOF'
import json, os, sys

target_path = os.environ["TARGET_PATH"]
fragment_raw = os.environ["FRAGMENT_ENV"]
force = os.environ.get("FORCE_FLAG", "0") == "1"
dry_run = os.environ.get("DRY_RUN_FLAG", "0") == "1"

# Load target; parse failure is exit 4 (no write).
try:
    with open(target_path, "r") as f:
        target = json.load(f)
except Exception:
    sys.stderr.write("FAIL: %s is not valid JSON; refusing to merge\n" % target_path)
    sys.exit(4)

try:
    fragment = json.loads(fragment_raw)
except Exception as e:
    sys.stderr.write("FAIL: --fragment is not valid JSON: %s\n" % e)
    sys.exit(1)

if not isinstance(target, dict) or not isinstance(fragment, dict):
    sys.stderr.write("FAIL: both target and fragment must be JSON objects at root\n")
    sys.exit(1)

def leaf_is_managed(leaf):
    return isinstance(leaf, dict) and leaf.get("_orchestrator_managed") is True

def collect_managed_keys(target_hooks):
    """Walk target hooks and collect every (event, matcher, command) tuple
    carried by an _orchestrator_managed:true leaf. M028/P02/T03 dedup key."""
    keys = set()
    if not isinstance(target_hooks, dict):
        return keys
    for event_name, wrappers in target_hooks.items():
        if not isinstance(wrappers, list):
            continue
        for wrapper in wrappers:
            if not isinstance(wrapper, dict):
                continue
            matcher = wrapper.get("matcher", "")
            if matcher is None:
                matcher = ""
            for leaf in wrapper.get("hooks", []) or []:
                if leaf_is_managed(leaf):
                    cmd = leaf.get("command", "")
                    if not isinstance(cmd, str):
                        cmd = ""
                    keys.add((event_name, matcher, cmd))
    return keys

# Deep-merge hooks (per-event arrays). Dedup key: (event, matcher, command)
# tuple within the _orchestrator_managed:true overlay (M028/P02/T03).
for key, value in fragment.items():
    if key == "hooks":
        if not isinstance(value, dict):
            continue
        target_hooks = target.get("hooks")
        if not isinstance(target_hooks, dict):
            target_hooks = {}
            target["hooks"] = target_hooks
        target_keys = collect_managed_keys(target_hooks)
        for event_name, frag_wrappers in value.items():
            if not isinstance(frag_wrappers, list):
                continue
            existing = target_hooks.get(event_name)
            if not isinstance(existing, list):
                existing = []
                target_hooks[event_name] = existing
            for fw in frag_wrappers:
                if not isinstance(fw, dict):
                    existing.append(fw)
                    continue
                matcher = fw.get("matcher", "")
                if matcher is None:
                    matcher = ""
                inner = fw.get("hooks", []) or []
                new_leaves = []
                for leaf in inner:
                    if not isinstance(leaf, dict):
                        new_leaves.append(leaf)
                        continue
                    cmd = leaf.get("command", "")
                    if not isinstance(cmd, str):
                        cmd = ""
                    if leaf_is_managed(leaf) and not force:
                        if (event_name, matcher, cmd) in target_keys:
                            # Duplicate tuple in _orchestrator_managed scope -- skip.
                            continue
                        target_keys.add((event_name, matcher, cmd))
                    new_leaves.append(leaf)
                if not new_leaves:
                    # Every leaf in this fragment wrapper was a duplicate; skip.
                    continue
                # Replace fw's leaves with the deduped set, preserving wrapper
                # shape (matcher + any other wrapper-level keys).
                fw_copy = dict(fw)
                fw_copy["hooks"] = new_leaves
                existing.append(fw_copy)
    else:
        # Non-hooks keys: set only if absent. Never overwrite.
        if key not in target:
            target[key] = value

out = json.dumps(target, indent=2, sort_keys=True)

if dry_run:
    print("would_write=%s" % target_path)
    print(out)
    sys.exit(0)

tmp = "%s.tmp.%d" % (target_path, os.getpid())
with open(tmp, "w") as f:
    f.write(out)
    f.write("\n")
os.replace(tmp, target_path)
print("wrote=%s" % target_path)
PYEOF
  rc=$?
  exit $rc
fi

# --- Uninstall subcommand ---
if [ "$SUBCMD" = "uninstall" ]; then
  if [ ! -e "$TARGET" ]; then
    echo "removed=0"
    exit 0
  fi
  TARGET_PATH="$TARGET" DRY_RUN_FLAG="$DRY_RUN" python3 <<'PYEOF'
import json, os, sys

target_path = os.environ["TARGET_PATH"]
dry_run = os.environ.get("DRY_RUN_FLAG", "0") == "1"

try:
    with open(target_path, "r") as f:
        target = json.load(f)
except Exception:
    sys.stderr.write("FAIL: %s is not valid JSON; refusing to merge\n" % target_path)
    sys.exit(4)

if not isinstance(target, dict):
    sys.stderr.write("FAIL: target is not a JSON object at root\n")
    sys.exit(1)

removed = 0
hooks = target.get("hooks")
if isinstance(hooks, dict):
    empty_event_keys = []
    for event_name, wrappers in list(hooks.items()):
        if not isinstance(wrappers, list):
            continue
        kept = []
        for wrapper in wrappers:
            if not isinstance(wrapper, dict):
                kept.append(wrapper)
                continue
            inner = wrapper.get("hooks")
            if not isinstance(inner, list):
                kept.append(wrapper)
                continue
            # Check if any leaf in wrapper is orchestrator-managed.
            any_managed = False
            for leaf in inner:
                if isinstance(leaf, dict) and leaf.get("_orchestrator_managed") is True:
                    any_managed = True
                    break
            if not any_managed:
                kept.append(wrapper)
                continue
            # Strip managed leaves; keep wrapper only if non-managed leaves remain.
            filtered = [leaf for leaf in inner
                        if not (isinstance(leaf, dict) and leaf.get("_orchestrator_managed") is True)]
            if filtered:
                wrapper["hooks"] = filtered
                kept.append(wrapper)
                # Outer wrapper survived -- not counted as a removal.
            else:
                removed += 1
                # Drop wrapper entirely.
        if kept:
            hooks[event_name] = kept
        else:
            empty_event_keys.append(event_name)
    for k in empty_event_keys:
        del hooks[k]
    if not hooks:
        del target["hooks"]

out = json.dumps(target, indent=2, sort_keys=True)

if dry_run:
    print("would_write=%s" % target_path)
    print("removed=%d" % removed)
    sys.exit(0)

tmp = "%s.tmp.%d" % (target_path, os.getpid())
with open(tmp, "w") as f:
    f.write(out)
    f.write("\n")
os.replace(tmp, target_path)
print("removed=%d" % removed)
PYEOF
  rc=$?
  exit $rc
fi

echo "FAIL: unknown subcommand '$SUBCMD' (expected: merge | uninstall)" >&2
exit 1
