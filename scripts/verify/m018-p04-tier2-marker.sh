#!/usr/bin/env bash
# scripts/verify/m018-p04-tier2-marker.sh — phase-truth verifier:
# "Tier 2 emits the in-band marker `<!-- compressed:tier2 head_dropped=<N>
# protected_tail_ratio=<R> -->` immediately after the section heading
# line of every section it modifies; the marker's kvpair grammar matches
# the cross-tier `<!-- compressed:tier[0-9]+ [^>]*-->` vocabulary entry
# verbatim."
#
# Approach: same shim as m018-p04-tier2-head-drop.sh — stage fixture,
# stub pres_check_section to 0, source-extract _bc_apply_tier2, run.
# Then assert exactly one tier2 marker line is present, the line
# directly follows the `## Knowledge` heading, and the line matches the
# cross-tier compression-marker regex from preservation-check.sh.
#
# AD-19 single-script-file shape, AP-009 compliant, bash 3.2 (MEM001).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HELPER="$REPO_ROOT/scripts/verify/_helpers/m018-p04-build-fixture.sh"
BC="$REPO_ROOT/scripts/dispatch/build-context.sh"
PRES="$REPO_ROOT/scripts/lib/preservation-check.sh"
FIXTURE="$REPO_ROOT/tests/fixtures/m018-p04-section-overflow/dispatch-payload-fixture.md"

for p in "$HELPER" "$BC" "$PRES" "$FIXTURE"; do
  if [ ! -f "$p" ]; then
    printf 'FAIL: prerequisite missing: %s\n' "$p" >&2
    exit 1
  fi
done

DEST="$(mktemp -d)"
trap 'rm -rf "$DEST"' EXIT INT TERM
bash "$HELPER" "$DEST" section-overflow >/dev/null

PAYLOAD="$DEST/_payload.md"
cp "$FIXTURE" "$PAYLOAD"

SHIM="$DEST/_shim.sh"
cat > "$SHIM" <<'SHIM_EOF'
#!/usr/bin/env bash
set -u
REPO_ROOT="$1"
DEST="$2"
ORCH_ROOT="$DEST"
TMPDIR_BUILD="$(mktemp -d)"
COMPRESSION_ENABLED=true
TIER2_ENABLED=true
TIER2_SECTION_BUDGET_TOKENS=200
TIER2_PROTECTED_TAIL_RATIO=0.3
MILESTONE_ID=M018-fixture
PHASE_ID=P04
TASK_ID=T01
. "$REPO_ROOT/scripts/lib/preservation-check.sh"
pres_check_section() { return 0; }
pres_emit_violation() { return 0; }
SCRATCH="$(mktemp)"
awk '/^_bc_apply_tier2\(\)/,/^}$/' "$REPO_ROOT/scripts/dispatch/build-context.sh" > "$SCRATCH"
. "$SCRATCH"
PAYLOAD="$DEST/_payload.md"
_bc_apply_tier2 "$PAYLOAD"
SHIM_EOF
chmod +x "$SHIM"

if ! bash "$SHIM" "$REPO_ROOT" "$DEST" >"$DEST/_shim.out" 2>"$DEST/_shim.err"; then
  printf 'FAIL: shim invocation of _bc_apply_tier2 nonzero\n' >&2
  cat "$DEST/_shim.err" >&2
  exit 1
fi

# 1. Exactly one tier2 marker line in the post payload.
MARKER_COUNT="$(grep -cE '<!-- compressed:tier2 head_dropped=' "$PAYLOAD" || true)"
if [ "$MARKER_COUNT" -ne 1 ]; then
  printf 'FAIL: expected exactly 1 tier2 marker line, got %d\n' "$MARKER_COUNT" >&2
  exit 1
fi

# 2. The marker line directly follows the `## Knowledge` heading.
NEXT_LINE="$(awk '/^## Knowledge$/{getline; print; exit}' "$PAYLOAD")"
case "$NEXT_LINE" in
  '<!-- compressed:tier2 head_dropped='*' protected_tail_ratio=0.30 -->') : ;;
  *)
    printf 'FAIL: line after ## Knowledge is not the tier2 marker (got: %s)\n' "$NEXT_LINE" >&2
    exit 1
    ;;
esac

# 3. The marker matches the cross-tier compression-marker regex
#    `<!-- compressed:tier[0-9]+ [^>]*-->` verbatim.
if ! printf '%s\n' "$NEXT_LINE" | grep -qE '<!-- compressed:tier[0-9]+ [^>]*-->'; then
  printf 'FAIL: marker line does not match cross-tier compression-marker regex\n' >&2
  exit 1
fi

# 4. The marker carries a positive integer head_dropped and the literal
#    `protected_tail_ratio=0.30`.
if ! printf '%s\n' "$NEXT_LINE" | grep -qE 'head_dropped=[1-9][0-9]*'; then
  printf 'FAIL: marker missing positive head_dropped integer\n' >&2
  exit 1
fi
if ! printf '%s\n' "$NEXT_LINE" | grep -qF 'protected_tail_ratio=0.30'; then
  printf 'FAIL: marker missing literal protected_tail_ratio=0.30\n' >&2
  exit 1
fi

# compressed:tier2 literal in this verifier.
printf 'PASS: m018-p04-tier2-marker (single marker line; immediately after heading; matches cross-tier regex)\n'
exit 0
