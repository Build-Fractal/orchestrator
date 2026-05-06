#!/usr/bin/env bash
# tests/m032-acceptance/p0X-pbj-b3-top-extra-collision.sh
#
# PBJ-dogfood B3 regression — wiki-scan-sources.sh must fail loud when
# wiki.extra_dirs declares a directory whose dirname-record collides
# with a reserved top-level scanner basename. Under
# use_directory_urls: true (mkdocs default), top:<name> projects to
# wiki/docs/<name>.md and extra:<name> projects to wiki/docs/<name>/,
# both resolving to the same /<name>/ URL — silent unreachability of
# the consolidated top-level page is unacceptable.
#
# Bash 3.2 compatible. Single-script-file. Throwaway fixture.

set -uo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
PROJECT_ROOT="$( cd "$PROJECT_ROOT/.." && pwd )"

FIXTURE="/tmp/m032-pbj-b3-fixture-$$"
trap 'rm -rf "$FIXTURE"' EXIT INT TERM

mkdir -p "$FIXTURE/.orchestrator"
mkdir -p "$FIXTURE/decisions"
printf '# Domain Decision\nbody\n' > "$FIXTURE/decisions/dd-001.md"

# Reserved basename in wiki.extra_dirs.
cat > "$FIXTURE/.orchestrator/config.yml" <<'YAML'
wiki:
  extra_dirs:
    - decisions/
YAML

pass=0
fail=0

OUT_ERR="/tmp/m032-pbj-b3-stderr-$$.txt"
bash "$PROJECT_ROOT/scripts/wiki/wiki-scan-sources.sh" --root "$FIXTURE" \
  >/dev/null 2>"$OUT_ERR"
RC=$?

if [ "$RC" -ne 0 ]; then
  pass=$((pass + 1))
  printf 'PASS: B3 scanner exits non-zero on top:/extra: collision (rc=%d)\n' "$RC"
else
  fail=$((fail + 1))
  printf 'FAIL: B3 scanner accepted reserved basename collision (rc=%d, regression)\n' "$RC" >&2
fi

if grep -q 'collides with reserved top-level' "$OUT_ERR" 2>/dev/null; then
  pass=$((pass + 1))
  printf 'PASS: B3 diagnostic mentions collision\n'
else
  fail=$((fail + 1))
  printf 'FAIL: B3 missing collision diagnostic on stderr\n' >&2
  cat "$OUT_ERR" >&2
fi

if grep -q 'decisions' "$OUT_ERR" 2>/dev/null; then
  pass=$((pass + 1))
  printf 'PASS: B3 diagnostic names the offending dirname\n'
else
  fail=$((fail + 1))
  printf 'FAIL: B3 diagnostic does not name the offending dirname\n' >&2
fi

rm -f "$OUT_ERR"

# Sanity: a non-colliding dirname (e.g., "domain-decisions/") must still
# be accepted — the collision detector must not over-trigger.
mkdir -p "$FIXTURE/domain-decisions"
printf '# Domain Decision\nbody\n' > "$FIXTURE/domain-decisions/dd-002.md"
cat > "$FIXTURE/.orchestrator/config.yml" <<'YAML'
wiki:
  extra_dirs:
    - domain-decisions/
YAML

bash "$PROJECT_ROOT/scripts/wiki/wiki-scan-sources.sh" --root "$FIXTURE" \
  >/dev/null 2>/dev/null
RC2=$?
if [ "$RC2" -eq 0 ]; then
  pass=$((pass + 1))
  printf 'PASS: B3 non-colliding extra_dir still accepted (rc=0)\n'
else
  fail=$((fail + 1))
  printf 'FAIL: B3 over-triggered on non-colliding name (rc=%d, regression)\n' "$RC2" >&2
fi

printf 'SUMMARY: pbj-b3-top-extra-collision pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ] && exit 0 || exit 1
