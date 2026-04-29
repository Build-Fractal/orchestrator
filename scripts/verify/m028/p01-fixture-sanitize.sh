#!/usr/bin/env bash
# scripts/verify/m028/p01-fixture-sanitize.sh -- M028/P01/T02 deterministic
# fixture sanitizer.
#
# One-shot transformation: reads
#   tests/fixtures/m028-pre-repair-snapshot.json.raw
# (the operator's M018-close ~/.claude/settings.json.bak-m018-cleanup-2026-04-28
# verbatim copy) and writes a sanitized fixture to
#   tests/fixtures/m028-pre-repair-snapshot.json
#
# Sanitization replaces user-specific bytes only -- it does NOT deduplicate
# or simplify entry shape. The Finding F regression pattern (5 unflagged
# Stop duplicates + 7 unflagged PreToolUse Bash duplicates naming
# orchestrator-post-verify / orchestrator-before-commit) round-trips
# byte-equivalent except for path/token replacements.
#
# Substitutions applied (deterministic, idempotent):
#   1. /Users/brettkellgren/         -> /Users/<USER>/
#   2. brettkellgren (word-boundary) -> <USER>
#      (leaves the `Build-Fractal/conversus-oss` repo name alone since
#      `brettkellgren` does not appear there.)
#   3. bkellgren@gmail.com           -> <USER>@<DOMAIN>
#   4. 32+ char hex/base64 token-like sequences -> <REDACTED-TOKEN>
#      Restrictive regex: greedy run of [A-Za-z0-9_-] of length >= 32.
#      `/` is intentionally excluded so filesystem path segments
#      (e.g. `claude/hooks/gsd-context-monitor`) do not get redacted;
#      `+` and `=` are excluded for the same reason. Source file is not
#      known to contain any such token; the rule is defensive insurance
#      for any future-format settings.json that may include API tokens.
#
# After substitution the script appends one M025-flagged hook entry
# (carrying `_orchestrator_managed: true`) to the PreToolUse Bash array
# AND one to the Stop array so the resulting fixture is a partial-flag
# file -- the realistic shape a `--repair` verifier will encounter on
# real downstream user systems where M025-flag-aware installs were
# layered on top of pre-M025 unflagged residue. This satisfies the phase
# artifact must-have (file contains `_orchestrator_managed`) without
# erasing the unflagged-duplicate regression evidence.
#
# Output validation:
#   - python3 -m json.tool parses the sanitized file (exit 1 on parse fail).
#   - The literal substring `_orchestrator_managed` appears at least once.
#
# Bash 3.2 + POSIX-sh-safe. AD-19 single-script-file shape: flat file,
# no nested helpers, no compound chains, no `bash -c '...'` bodies.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
RAW="${REPO_ROOT}/tests/fixtures/m028-pre-repair-snapshot.json.raw"
OUT="${REPO_ROOT}/tests/fixtures/m028-pre-repair-snapshot.json"

if [ ! -f "$RAW" ]; then
  echo "FAIL: raw input missing at ${RAW}" >&2
  exit 1
fi
if [ ! -r "$RAW" ]; then
  echo "FAIL: raw input unreadable at ${RAW}" >&2
  exit 1
fi

# Stage 1: path/token substitutions via sed.
# BSD sed (macOS) and GNU sed both honor -E for extended regex.
# All substitutions are global (`g` flag) and idempotent: running
# the sanitizer twice on already-sanitized output is a no-op.
TMP="${OUT}.tmp.$$"

sed -E \
  -e 's|/Users/brettkellgren/|/Users/<USER>/|g' \
  -e 's|\bbrettkellgren\b|<USER>|g' \
  -e 's|bkellgren@gmail\.com|<USER>@<DOMAIN>|g' \
  -e 's|[A-Za-z0-9_-]{32,}|<REDACTED-TOKEN>|g' \
  "$RAW" > "$TMP"

# Stage 2: inject one M025-flagged Stop entry and one M025-flagged
# PreToolUse Bash entry so the fixture is a partial-flag file. We use
# python3 (constitution-mandated) to mutate the JSON deterministically;
# this avoids brittle text-edit injection.
python3 - "$TMP" "$OUT" <<'PYEOF'
import json
import sys

src = sys.argv[1]
dst = sys.argv[2]

with open(src, "r") as fh:
    data = json.load(fh)

# Defensive: the operator's snapshot has top-level `hooks` with `Stop`
# and `PreToolUse` arrays. If the shape ever shifts, fail loudly.
if "hooks" not in data:
    print("FAIL: sanitized JSON missing top-level `hooks` key", file=sys.stderr)
    sys.exit(1)

hooks = data["hooks"]
if "Stop" not in hooks or not isinstance(hooks["Stop"], list):
    print("FAIL: sanitized JSON missing or malformed hooks.Stop array", file=sys.stderr)
    sys.exit(1)
if "PreToolUse" not in hooks or not isinstance(hooks["PreToolUse"], list):
    print("FAIL: sanitized JSON missing or malformed hooks.PreToolUse array", file=sys.stderr)
    sys.exit(1)

# Append one flagged Stop entry. M025 merge-not-overwrite shape:
# `_orchestrator_managed: true` rides on the inner hook leaf object.
flagged_stop = {
    "_orchestrator_managed": True,
    "hooks": [
        {
            "type": "command",
            "command": "orchestrator-post-verify"
        }
    ]
}
hooks["Stop"].append(flagged_stop)

# Append one flagged PreToolUse Bash entry.
flagged_pretool = {
    "_orchestrator_managed": True,
    "matcher": "Bash",
    "hooks": [
        {
            "type": "command",
            "command": "orchestrator-before-commit"
        }
    ]
}
hooks["PreToolUse"].append(flagged_pretool)

# Pretty-print with 2-space indent matching the source style.
with open(dst, "w") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")
PYEOF

PY_RC=$?
if [ "$PY_RC" -ne 0 ]; then
  echo "FAIL: python3 flag-injection failed (exit ${PY_RC})" >&2
  rm -f "$TMP"
  exit 1
fi

rm -f "$TMP"

# Stage 3: validate output is parseable JSON.
python3 -m json.tool "$OUT" >/dev/null
JSON_RC=$?
if [ "$JSON_RC" -ne 0 ]; then
  echo "FAIL: sanitized output is not valid JSON (python3 -m json.tool exit ${JSON_RC})" >&2
  exit 1
fi

# Stage 4: anchor check -- _orchestrator_managed must appear at least once.
if ! grep -q '_orchestrator_managed' "$OUT"; then
  echo "FAIL: sanitized output missing _orchestrator_managed anchor" >&2
  exit 1
fi

echo "PASS: sanitized ${OUT}"
exit 0
