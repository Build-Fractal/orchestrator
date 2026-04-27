#!/usr/bin/env bash
set -u
rm -rf /tmp/m018-fixture
cp -R /Users/brettkellgren/Sites/spec-kit-orchestrator/tests/fixtures/dispatch-state /tmp/m018-fixture
rm -f /tmp/m018-fixture/execution-log.jsonl
bash /Users/brettkellgren/Sites/spec-kit-orchestrator/scripts/dispatch/build-context.sh /tmp/m018-fixture M001 P02 T01 >/tmp/m018-bc-out.txt 2>/tmp/m018-bc-err.txt
echo "EXIT=$?"
echo "--- log ---"
ls -la /tmp/m018-fixture/execution-log.jsonl 2>/dev/null || echo "no log"
wc -l /tmp/m018-fixture/execution-log.jsonl 2>/dev/null || true
echo "--- log content ---"
cat /tmp/m018-fixture/execution-log.jsonl 2>/dev/null || true
echo "--- stderr ---"
tail -5 /tmp/m018-bc-err.txt 2>/dev/null || true
