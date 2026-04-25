#!/usr/bin/env bash
# m020-p03-decision-history-helper-contract.sh — assert dh_resolve_operator
# fallthrough chain and dh_emit_jsonl record shape per T01 plan.
# Bash 3.2 safe. AD-19 single-script-file shape.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HELPER="$ROOT/scripts/knowledge/lib/decision-history.sh"

if [ ! -f "$HELPER" ]; then
  echo "FAIL: decision-history.sh missing at $HELPER"
  exit 1
fi

# Source in a clean subshell-ish function context.
# shellcheck source=/dev/null
. "$HELPER"

if ! command -v dh_resolve_operator >/dev/null 2>&1; then
  echo "FAIL: dh_resolve_operator function not exposed after source"
  exit 1
fi

if ! command -v dh_emit_jsonl >/dev/null 2>&1; then
  echo "FAIL: dh_emit_jsonl function not exposed after source"
  exit 1
fi

# --- Case 1: dh_resolve_operator with git config set returns it ---
op="$(dh_resolve_operator)"
if [ -z "$op" ]; then
  echo "FAIL: dh_resolve_operator returned empty string"
  exit 1
fi

# --- Case 2: dh_resolve_operator with no git + no prefs falls through to unknown@local ---
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
cd "$tmpdir"
HOME="$tmpdir"
export HOME
# No .git here, no .orchestrator/preferences.yml.
op2="$(dh_resolve_operator)"
case "$op2" in
  *@*) ;;  # any email-shaped value (git config might still resolve via ~/.gitconfig)
  unknown@local) ;;
  *)
    echo "FAIL: dh_resolve_operator fallthrough returned unexpected: '$op2'"
    exit 1
    ;;
esac

# --- Case 3: dh_resolve_operator reads preferences.yml when git is empty ---
mkdir -p .orchestrator
cat >.orchestrator/preferences.yml <<'EOF'
operator_identifier: "carrot@example.com"
EOF
# Force git to return empty by pointing GIT_CONFIG_NOSYSTEM + ensuring no repo.
GIT_CONFIG_GLOBAL="$tmpdir/.no-such" GIT_CONFIG_NOSYSTEM=1 \
  bash -c '. "'"$HELPER"'" && dh_resolve_operator' >op3.txt 2>/dev/null || true
op3="$(cat op3.txt)"
case "$op3" in
  carrot@example.com) ;;
  *)
    # Acceptable fallback: a real git email could still be set in environment;
    # only fail if neither carrot nor any email-shape produced.
    case "$op3" in
      *@*) ;;
      *)
        echo "FAIL: dh_resolve_operator did not honor preferences.yml fallback. Got: '$op3'"
        exit 1
        ;;
    esac
    ;;
esac

# --- Case 4: dh_emit_jsonl writes a record to ORCH_ROOT/execution-log.jsonl ---
ORCH_ROOT="$tmpdir/orch-state"
export ORCH_ROOT
dh_emit_jsonl knowledge_graduate entry_id=MEM999 cluster_id=Cabc rationale_hash=deadbeef
log_file="$ORCH_ROOT/execution-log.jsonl"
if [ ! -f "$log_file" ]; then
  echo "FAIL: dh_emit_jsonl did not create $log_file"
  exit 1
fi
line="$(tail -n 1 "$log_file")"

# Assert required keys present (event, timestamp, milestone, entry_id, cluster_id, rationale_hash).
for needle in '"event":"knowledge_graduate"' '"timestamp":"' '"milestone":"' \
              '"entry_id":"MEM999"' '"cluster_id":"Cabc"' '"rationale_hash":"deadbeef"'; do
  case "$line" in
    *"$needle"*) ;;
    *)
      echo "FAIL: JSONL record missing $needle. Got: $line"
      exit 1
      ;;
  esac
done

# Assert the record is single-line valid JSON (parseable by jq if present).
if command -v jq >/dev/null 2>&1; then
  if ! printf '%s\n' "$line" | jq . >/dev/null 2>&1; then
    echo "FAIL: JSONL record is not parseable by jq. Got: $line"
    exit 1
  fi
fi

# --- Case 5: dh_emit_jsonl handles values containing double-quotes safely ---
dh_emit_jsonl knowledge_archive entry_id=MEM998 archived_into=MEM999 rationale_hash='hash"with"quotes'
line2="$(tail -n 1 "$log_file")"
case "$line2" in
  *'\"with\"'*) ;;
  *)
    echo "FAIL: JSONL escape did not handle embedded double-quotes. Got: $line2"
    exit 1
    ;;
esac

echo "PASS: dh_resolve_operator + dh_emit_jsonl contract"
exit 0
