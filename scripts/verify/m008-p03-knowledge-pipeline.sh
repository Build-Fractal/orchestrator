#!/usr/bin/env bash
# Verifies intensity-knowledge.sh dispatches the expected subset of
# knowledge scripts at each intensity level, using --dry-run mode so
# we do not need real summary/decision inputs.
set -u

f="scripts/knowledge/intensity-knowledge.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
test -x "$f" || { echo "FAIL: $f not executable"; exit 1; }

# Quick -> write-summary.sh only
out="$(bash "$f" --intensity Quick --dry-run 2>/dev/null)"
echo "$out" | grep -q 'WOULD_RUN:.*write-summary.sh' || { echo "FAIL: Quick did not plan write-summary.sh"; exit 1; }
if echo "$out" | grep -q 'WOULD_RUN:.*append-decision.sh'; then
  echo "FAIL: Quick should NOT plan append-decision.sh"; exit 1
fi
if echo "$out" | grep -q 'WOULD_RUN:.*append-knowledge.sh'; then
  echo "FAIL: Quick should NOT plan append-knowledge.sh"; exit 1
fi
if echo "$out" | grep -q 'WOULD_RUN:.*rebuild-index.sh'; then
  echo "FAIL: Quick should NOT plan rebuild-index.sh"; exit 1
fi

# Standard -> write-summary.sh + append-decision.sh
out="$(bash "$f" --intensity Standard --dry-run 2>/dev/null)"
echo "$out" | grep -q 'WOULD_RUN:.*write-summary.sh' || { echo "FAIL: Standard missing write-summary.sh"; exit 1; }
echo "$out" | grep -q 'WOULD_RUN:.*append-decision.sh' || { echo "FAIL: Standard missing append-decision.sh"; exit 1; }
if echo "$out" | grep -q 'WOULD_RUN:.*append-knowledge.sh'; then
  echo "FAIL: Standard should NOT plan append-knowledge.sh"; exit 1
fi
if echo "$out" | grep -q 'WOULD_RUN:.*rebuild-index.sh'; then
  echo "FAIL: Standard should NOT plan rebuild-index.sh"; exit 1
fi

# Full -> all four
out="$(bash "$f" --intensity Full --dry-run 2>/dev/null)"
echo "$out" | grep -q 'WOULD_RUN:.*write-summary.sh' || { echo "FAIL: Full missing write-summary.sh"; exit 1; }
echo "$out" | grep -q 'WOULD_RUN:.*append-decision.sh' || { echo "FAIL: Full missing append-decision.sh"; exit 1; }
echo "$out" | grep -q 'WOULD_RUN:.*append-knowledge.sh' || { echo "FAIL: Full missing append-knowledge.sh"; exit 1; }
echo "$out" | grep -q 'WOULD_RUN:.*rebuild-index.sh' || { echo "FAIL: Full missing rebuild-index.sh"; exit 1; }

# --intensity-metadata resolves to same plan
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
printf '%s\n' '---' 'intensity: "Full"' '---' > "$tmp/meta.md"
out="$(bash "$f" --intensity-metadata "$tmp/meta.md" --dry-run 2>/dev/null)"
echo "$out" | grep -q 'WOULD_RUN:.*rebuild-index.sh' || { echo "FAIL: metadata-file Full should include rebuild-index.sh"; exit 1; }

# Invalid intensity rejected
err="$(bash "$f" --intensity Medium --dry-run 2>&1 >/dev/null)"
rc=$?
if [[ $rc -eq 0 ]]; then echo "FAIL: invalid intensity did not exit non-zero"; exit 1; fi

echo "PASS: intensity-knowledge.sh dispatches expected subset per level"
