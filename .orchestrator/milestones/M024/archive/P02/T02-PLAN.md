---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P02"
milestone: "M024"
name: "M014 manifest live reader (M014→M024 handshake direction `a`)"
depends_on: []
---

## Prerequisites

- P01 complete: `tests/fixtures/m014-interim-manifest-keys.txt` is the contracted snapshot of M014 manifest keys (six keys: `schema_version`, `type`, `feature_slug`, `created_at`, `status`, `milestone`).
- M014/extended has shipped: `templates/spec-template.md` carries the M014 interim-manifest frontmatter and `scripts/specify/specify.sh` scaffolds new specs from that template.
- The reader is the live AD-4 direction `a` source-of-truth at invoke time. The fixture stays in place as a pinned snapshot — T04 wires the fixture-vs-live equality check.
- Bash 3.2 + POSIX sh portable. AD-19 single-script-file shape — no inline compound bash, no plain subshells, no `$(...)` containing pipes.

## Description

Author `scripts/intake/m014-manifest-read.sh` — given a path to either a feature spec file or a directory containing one, run an invoke-time probe (`test -f templates/spec-template.md`) and either:

(a) emit the six M014 manifest key=value lines on stdout in the canonical order — extracted from the spec's frontmatter, OR
(b) emit a clearly-marked stub message naming `templates/spec-template.md` as the unshipped target and exit non-zero (per spec #DQ-2 option `b`, mirroring P03's `route-to-specify.sh` invoke-time stub pattern).

### CLI surface

```
m014-manifest-read.sh --spec-path <path-to-spec.md>
m014-manifest-read.sh --specs-dir  <path-to-specs/<NNN>-<slug>/>
```

`--spec-path` reads the named file directly. `--specs-dir` resolves to the `spec.md` inside that directory. Exactly one is required; both is a usage error (exit 2).

### Output contract

Six lines on stdout in this exact order (mirrors `tests/fixtures/m014-interim-manifest-keys.txt`):

```
schema_version=<value>
type=<value>
feature_slug=<value>
created_at=<value>
status=<value>
milestone=<value>
```

Each value is the string between the `: ` and the end-of-line in the spec frontmatter, with surrounding `"` quotes stripped. Missing keys emit `<key>=null` rather than the line being omitted — the line count is always six (parseability invariant for downstream consumers).

### Probe failure shape

When `test -f templates/spec-template.md` fails:

```
m014-manifest-read.sh: M014 not yet shipped — templates/spec-template.md missing.
This reader requires the M014 interim-manifest contract source (see AD-4 direction `a`).
Recover: ship M014, OR consume the fixture at tests/fixtures/m014-interim-manifest-keys.txt.
```

Exit code: 3 (distinct from usage=2 and internal=1 so callers can branch).

### Why invoke-time, not plan-phase-time

Per the P03 #DQ-2 precedent (`scripts/intake/route-to-specify.sh` re-runs `test -f scripts/specify/specify.sh` at invoke time): the M014 shipping status can change between plan-phase and invoke time (worktree regeneration, branch flips). Invoke-time gating is more robust than a plan-phase-time check baked into the plan. The plan-phase-time probe in `P02-PLAN.md` is informational only.

## Steps

1. **Create the reader** at `scripts/intake/m014-manifest-read.sh`:

```bash
#!/usr/bin/env bash
# scripts/intake/m014-manifest-read.sh
# M024/P02/T02 — Live M014 interim-manifest reader (AD-4 direction `a`).
#
# Reads the six M014 interim-manifest keys from a feature spec frontmatter,
# emitting them as key=value lines in the canonical fixture order.
#
# Inputs (exactly one of):
#   --spec-path <path>   Path to a spec.md file.
#   --specs-dir  <path>  Path to a specs/<NNN>-<slug>/ directory.
#
# Output (stdout, exactly six lines in this order):
#   schema_version=<value>
#   type=<value>
#   feature_slug=<value>
#   created_at=<value>
#   status=<value>
#   milestone=<value>
#
# Exit codes:
#   0 = success
#   1 = internal error (spec missing / unreadable / not a feature-spec)
#   2 = usage error
#   3 = M014 unshipped (templates/spec-template.md missing — see #DQ-2 stub branch)

set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEMPLATE_GUARD="$ROOT/templates/spec-template.md"

usage() {
  echo "usage: m014-manifest-read.sh (--spec-path <p> | --specs-dir <d>)" >&2
  exit 2
}

SPEC_PATH=""
SPECS_DIR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --spec-path) SPEC_PATH="$2"; shift 2 ;;
    --specs-dir) SPECS_DIR="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) usage ;;
  esac
done

# Exactly-one validation.
if [ -n "$SPEC_PATH" ] && [ -n "$SPECS_DIR" ]; then
  echo "m014-manifest-read.sh: --spec-path and --specs-dir are mutually exclusive" >&2
  exit 2
fi
[ -n "$SPEC_PATH" ] || [ -n "$SPECS_DIR" ] || usage

# Invoke-time M014 shipping probe (#DQ-2).
if [ ! -f "$TEMPLATE_GUARD" ]; then
  echo "m014-manifest-read.sh: M014 not yet shipped — templates/spec-template.md missing." >&2
  echo "This reader requires the M014 interim-manifest contract source (see AD-4 direction \`a\`)." >&2
  echo "Recover: ship M014, OR consume the fixture at tests/fixtures/m014-interim-manifest-keys.txt." >&2
  exit 3
fi

# Resolve spec path from --specs-dir if needed.
if [ -z "$SPEC_PATH" ]; then
  SPEC_PATH="$SPECS_DIR/spec.md"
fi

[ -f "$SPEC_PATH" ] || { echo "m014-manifest-read.sh: spec not found: $SPEC_PATH" >&2; exit 1; }

# Validate frontmatter shape.
if ! head -30 "$SPEC_PATH" | grep -q '^type: feature-spec'; then
  echo "m014-manifest-read.sh: not a feature-spec frontmatter: $SPEC_PATH" >&2
  exit 1
fi

# Helper: extract one frontmatter value (between first `---` and second `---`).
# Strips surrounding quotes. Emits empty string when key absent.
extract() {
  local key="$1"
  awk -v k="$key" '
    BEGIN { in_fm=0 }
    /^---$/ { in_fm++; next }
    in_fm==1 {
      if (match($0, "^" k ":[ \t]*")) {
        v = substr($0, RLENGTH+1)
        gsub(/^"/, "", v); gsub(/"$/, "", v)
        gsub(/^[ \t]+|[ \t]+$/, "", v)
        print v
        exit
      }
    }
  ' "$SPEC_PATH"
}

emit_line() {
  local key="$1"
  local val
  val=$(extract "$key")
  [ -n "$val" ] || val="null"
  echo "$key=$val"
}

emit_line schema_version
emit_line type
emit_line feature_slug
emit_line created_at
emit_line status
emit_line milestone
exit 0
```

2. **Make it executable**: `chmod +x scripts/intake/m014-manifest-read.sh`.

3. **Write the verify script** at `scripts/verify/m024-p02-m014-manifest-read.sh`:

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p02-m014-manifest-read.sh
# Verifies m014-manifest-read.sh emits the six M014 manifest keys in canonical
# order against an in-repo spec.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
READER="$ROOT/scripts/intake/m014-manifest-read.sh"
SPEC="$ROOT/specs/023-github-native-integration/spec.md"

[ -x "$READER" ] || { echo "FAIL: $READER not executable"; exit 1; }
[ -f "$SPEC" ]   || { echo "FAIL: fixture spec missing: $SPEC"; exit 1; }

out=$(bash "$READER" --spec-path "$SPEC")

# Six lines, in canonical order.
line_count=$(echo "$out" | grep -c '^')
[ "$line_count" -eq 6 ] || { echo "FAIL: expected 6 lines, got $line_count — out: $out"; exit 1; }

echo "$out" | sed -n '1p' | grep -q '^schema_version=' || { echo "FAIL: line 1 not schema_version"; exit 1; }
echo "$out" | sed -n '2p' | grep -q '^type='           || { echo "FAIL: line 2 not type"; exit 1; }
echo "$out" | sed -n '3p' | grep -q '^feature_slug='   || { echo "FAIL: line 3 not feature_slug"; exit 1; }
echo "$out" | sed -n '4p' | grep -q '^created_at='     || { echo "FAIL: line 4 not created_at"; exit 1; }
echo "$out" | sed -n '5p' | grep -q '^status='         || { echo "FAIL: line 5 not status"; exit 1; }
echo "$out" | sed -n '6p' | grep -q '^milestone='      || { echo "FAIL: line 6 not milestone"; exit 1; }

# --specs-dir resolution.
out2=$(bash "$READER" --specs-dir "$ROOT/specs/023-github-native-integration")
diff_check=$(echo "$out" | diff - <(echo "$out2") | wc -l | tr -d ' ')
[ "$diff_check" = "0" ] || { echo "FAIL: --spec-path and --specs-dir produced different output"; exit 1; }

echo "PASS: m014-manifest-read.sh — six keys in canonical order, --spec-path / --specs-dir parity"
exit 0
```

Note: the `diff` line uses `< <(...)` process substitution which IS forbidden by AD-19. Replace with a tmp-file shape:

```bash
tmp_a=$(mktemp); tmp_b=$(mktemp)
trap 'rm -f "$tmp_a" "$tmp_b"' EXIT
echo "$out"  > "$tmp_a"
echo "$out2" > "$tmp_b"
diff -q "$tmp_a" "$tmp_b" >/dev/null 2>&1 || { echo "FAIL: --spec-path and --specs-dir produced different output"; exit 1; }
```

Use the tmp-file shape in the actual script — the inline `<(...)` line above is for clarity only and is replaced before commit.

## Must-Haves

- `scripts/intake/m014-manifest-read.sh` exists, is executable, and emits exactly six key=value lines on stdout in the canonical order (`schema_version`, `type`, `feature_slug`, `created_at`, `status`, `milestone`).
- Both `--spec-path <p>` and `--specs-dir <d>` produce byte-identical output for the same target spec.
- The invoke-time M014 probe (`test -f templates/spec-template.md`) is honored: when the template is absent, the reader emits the unshipped-stub message and exits 3.
- Missing frontmatter keys emit `<key>=null` rather than dropping the line — line count is always six.
- The reader writes nothing to disk — pure stdout (SB-3 invariant).
- AD-19 harness shape: every external invocation in the verify script is single-script-file form. No `<(...)` process substitution, no `$(...)` containing pipes.

## Verification

```
bash scripts/verify/m024-p02-m014-manifest-read.sh
```

Expected output (exit 0): `PASS: m014-manifest-read.sh — six keys in canonical order, --spec-path / --specs-dir parity`

## Inputs

### From Previous Tasks

- `tests/fixtures/m014-interim-manifest-keys.txt` (from M024/P01/T05) — contracted snapshot. Defines the canonical six-key order this reader matches. T04's `m024-p02-fixture-vs-live.sh` verify asserts the live reader's keys equal this fixture.

### From Disk (Pre-existing)

- `templates/spec-template.md` — M014 interim-manifest contract source. Read-only.
- `specs/023-github-native-integration/spec.md` — in-repo fixture spec used by the verify script.
- `awk`, `head`, `grep`, `sed -n`, `echo`, `mktemp`, `diff` — POSIX utilities.

## Constraints

- POSIX sh + bash 3.2 portable.
- Pure reader — no disk writes outside `/tmp` (verify script's mktemp scratch only). The reader itself writes nothing.
- AD-19 single-script-file shape: every command in the verify script is a top-level bash invocation; no `<(...)` process substitution, no plain subshells, no `$(...)` containing pipes.
- The reader is idempotent: identical spec input → byte-identical stdout.
- The reader does NOT consume the P01 fixture at runtime — the fixture is the contracted snapshot, not an input. T04's verify cross-checks fixture against live reader, but the reader itself never reads the fixture.

## Expected Output

`scripts/intake/m014-manifest-read.sh` exists and is executable; `scripts/verify/m024-p02-m014-manifest-read.sh` exits 0 with `PASS:`.
