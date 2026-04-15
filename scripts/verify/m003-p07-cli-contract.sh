#!/usr/bin/env bash
set -eu
f="scripts/migrate/migrate.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
# --help should exit 0
if ! bash "$f" --help >/dev/null 2>&1; then
  echo "FAIL: migrate.sh --help did not exit 0"
  exit 1
fi
# Without --path, should exit non-zero (usage error)
if bash "$f" >/dev/null 2>&1; then
  echo "FAIL: migrate.sh without --path should exit non-zero"
  exit 1
fi
# Help text must still list the documented flags
help_out="$(bash "$f" --help 2>&1)"
for flag in --path --source --recent-count --output --merge --force --abort; do
  case "$help_out" in
    *"$flag"*) ;;
    *) echo "FAIL: --help missing documented flag $flag"; exit 1 ;;
  esac
done
echo "PASS: migrate.sh CLI contract intact (--help works, --path required, all flags listed)"
