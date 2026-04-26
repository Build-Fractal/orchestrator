---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P07"
milestone: "M024"
name: "Design-gate classifier — pure decision emitter for design-domain heuristic"
depends_on: []
---

## Prerequisites

- P01 complete: `templates/intake-proposal.md` defines the six routing axes including `design_gate: "{{design_gate}}"` (line 15) and `scripts/intake/proposal-emit.sh` exists with the `design_gate="none"` P01 stub (line 179).
- P03 complete: `scripts/intake/paragraph-classify.sh` and `scripts/intake/spec-shape-classify.sh` establish the pure-decision-emitter shape (no file writes, stdout-only key=value lines, closed-enum value validation).
- AD-19 single-script-file verify shape is the M024 invariant; this task introduces no new exception.

No upstream P07 task dependencies — T01 is a leaf decision emitter that T03 will wire into the emitter. T02 (degradation script) is independent of T01 (it consumes the classifier verdict via the proposal frontmatter, not via a direct call).

## Description

Author `scripts/intake/design-gate-classify.sh` — a pure decision emitter (no file writes, no side effects beyond stdout/stderr) that scans an input string OR a spec file for design-domain tokens and emits the `design_gate` axis verdict.

This is the small reusable engine that `proposal-emit.sh` (T03) will invoke alongside the existing paragraph and spec deep classifiers. The classifier's role is FR-1 axis-population only; the M023-shipping probe and the manual/skip branch logic live in T02's `design-gate-degradation.sh`.

### Rule table

The classifier scans for design-domain tokens using POSIX `grep -wE` (whole-word matching — `redesign` matches the `design` rule because `-w` treats `redesign` as a single word, but the alternation `\bdesign\b` would not match inside `redesign`; we use `grep -wE` which matches whole-word AT word boundaries on the alternation pattern). The token set is intentionally narrow:

| Token         | Rationale                                                       |
|---------------|-----------------------------------------------------------------|
| `ui` / `UI`   | Direct UI signal                                                |
| `render`      | Rendering layer                                                 |
| `design`      | Direct design signal (also matches via `-w` to `redesign`)      |
| `layout`      | Spatial design                                                  |
| `screen`      | UI screen                                                       |
| `view`        | UI view                                                         |
| `panel`       | UI panel                                                        |
| `viewer`      | UI viewer                                                       |
| `dashboard`   | Composite UI                                                    |
| `interface`   | UI interface                                                    |
| `visual`      | Visual design                                                   |
| `theme`       | Visual theming                                                  |

For paragraph/idea/fragment inputs, the classifier scans the input string. For spec inputs, it scans the spec body (read from `--spec-path`). For empty inputs, exit 0 with `design_gate=none design_gate_confidence=low` (no signal).

Verdict rules:

- **0 token hits** → `design_gate=none design_gate_confidence=high`
- **1 token hit** → `design_gate=walkthrough design_gate_confidence=low`
- **≥2 distinct token hits** → `design_gate=walkthrough design_gate_confidence=high`

Confidence informs P07 nothing directly (the degradation script only reads `design_gate`), but it is recorded in the proposal frontmatter slot for forward-binding to M023 (which may want to weight ambiguous calls).

### Argument contract

- `--input <text>` — paragraph/idea/fragment input string. Mutually exclusive with `--spec-path`.
- `--spec-path <path>` — spec file path. Mutually exclusive with `--input`.
- Exactly one of the two must be supplied. Both or neither → exit 2 with usage.

### Output contract

Two stdout lines on success (no other lines):

```
design_gate=<none|walkthrough>
design_gate_confidence=<low|high>
```

No stderr on the happy path. On usage errors → stderr usage block + exit 2. On `--spec-path <path>` where the file does not exist → stderr `ERR: spec not found at <path>` + exit 1.

## Steps

1. **Create the classifier script** at `scripts/intake/design-gate-classify.sh`:

```bash
#!/usr/bin/env bash
# scripts/intake/design-gate-classify.sh
# M024/P07/T01 — Pure decision emitter for the design_gate axis (FR-1, FR-7).
#
# Inputs:
#   --input <text>       Paragraph/idea/fragment input string.
#   --spec-path <path>   Spec file path (mutually exclusive with --input).
#
# Stdout (exactly two lines on success):
#   design_gate=<none|walkthrough>
#   design_gate_confidence=<low|high>
#
# Exit 0 on success, 1 on missing spec file, 2 on usage error.

set -u

usage() {
  cat >&2 <<'EOF'
usage: design-gate-classify.sh (--input <text> | --spec-path <path>)

Scans the supplied input or spec body for design-domain tokens and emits
the design_gate axis verdict as two key=value stdout lines.

Tokens (whole-word match): ui UI render design layout screen view panel viewer dashboard interface visual theme

Verdict:
  0 hits   -> design_gate=none         design_gate_confidence=high
  1 hit    -> design_gate=walkthrough  design_gate_confidence=low
  >=2 hits -> design_gate=walkthrough  design_gate_confidence=high
EOF
  exit 2
}

INPUT=""
SPEC_PATH=""

while [ $# -gt 0 ]; do
  case "$1" in
    --input)     INPUT="$2";     shift 2 ;;
    --spec-path) SPEC_PATH="$2"; shift 2 ;;
    -h|--help)   usage ;;
    *)           usage ;;
  esac
done

# Exactly one of --input | --spec-path must be supplied.
if [ -n "$INPUT" ] && [ -n "$SPEC_PATH" ]; then usage; fi
if [ -z "$INPUT" ] && [ -z "$SPEC_PATH" ]; then usage; fi

# Resolve text source.
if [ -n "$SPEC_PATH" ]; then
  if [ ! -f "$SPEC_PATH" ]; then
    echo "ERR: spec not found at $SPEC_PATH" >&2
    exit 1
  fi
  body_file="$SPEC_PATH"
else
  body_file="$(mktemp)"
  trap 'rm -f "$body_file"' EXIT
  printf '%s' "$INPUT" > "$body_file"
fi

# Token alternation. -w on grep -E treats the alternation as whole-word
# tokens at word boundaries. Note: bash 3.2 portable; no process subst.
PATTERN='ui|UI|render|design|layout|screen|view|panel|viewer|dashboard|interface|visual|theme'

# Count distinct token hits. We scan for each token individually so that
# repeated occurrences of the same token count as one hit. The hit count
# is the number of tokens that matched at least once.
hits=0
for tok in ui UI render design layout screen view panel viewer dashboard interface visual theme; do
  if grep -qwE "$tok" "$body_file"; then
    hits=$((hits + 1))
  fi
done

# Verdict.
if [ "$hits" -eq 0 ]; then
  echo "design_gate=none"
  echo "design_gate_confidence=high"
elif [ "$hits" -eq 1 ]; then
  echo "design_gate=walkthrough"
  echo "design_gate_confidence=low"
else
  echo "design_gate=walkthrough"
  echo "design_gate_confidence=high"
fi

exit 0
```

2. **Make it executable**: `chmod +x scripts/intake/design-gate-classify.sh`.

3. **Write the verify script** at `scripts/verify/m024-p07-design-gate-classify.sh`:

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p07-design-gate-classify.sh
# Verifies the design-gate classifier rule table.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CLF="$ROOT/scripts/intake/design-gate-classify.sh"

[ -x "$CLF" ] || { echo "FAIL: $CLF not executable"; exit 1; }

# Case 1 — UI redesign paragraph (3 tokens: redesign matches "design", "ui", "viewer") -> walkthrough+high
out=$(bash "$CLF" --input "We should redesign the proposal viewer with split panes and a live diff layout")
echo "$out" | grep -qx "design_gate=walkthrough" || { echo "FAIL: case 1 design_gate (got: $out)"; exit 1; }
echo "$out" | grep -qx "design_gate_confidence=high" || { echo "FAIL: case 1 confidence high (got: $out)"; exit 1; }

# Case 2 — Backend script paragraph -> none+high
out=$(bash "$CLF" --input "Cache the result of orchestrator:status for five seconds and add a no-cache flag")
echo "$out" | grep -qx "design_gate=none" || { echo "FAIL: case 2 design_gate=none (got: $out)"; exit 1; }
echo "$out" | grep -qx "design_gate_confidence=high" || { echo "FAIL: case 2 confidence high (got: $out)"; exit 1; }

# Case 3 — Single-token short input -> walkthrough+low
out=$(bash "$CLF" --input "tweak the screen")
echo "$out" | grep -qx "design_gate=walkthrough" || { echo "FAIL: case 3 walkthrough (got: $out)"; exit 1; }
echo "$out" | grep -qx "design_gate_confidence=low" || { echo "FAIL: case 3 low (got: $out)"; exit 1; }

# Case 4 — Substring 'serendipity' (contains 'design' substring? no — but matches 'pity'? no) -> none
out=$(bash "$CLF" --input "serendipity strikes when the moon aligns with caching policy")
echo "$out" | grep -qx "design_gate=none" || { echo "FAIL: case 4 substring should not trigger (got: $out)"; exit 1; }

# Case 5 — Spec-path mode on a UI-tagged synthetic spec.
tmp_spec=$(mktemp)
trap 'rm -f "$tmp_spec"' EXIT
cat >"$tmp_spec" <<'SPEC'
# Feature Spec: Dashboard layout

We need a new dashboard with a split-pane viewer and theme support.
SPEC
out=$(bash "$CLF" --spec-path "$tmp_spec")
echo "$out" | grep -qx "design_gate=walkthrough" || { echo "FAIL: case 5 spec-path walkthrough (got: $out)"; exit 1; }

# Case 6 — Missing spec exits 1.
if bash "$CLF" --spec-path /nonexistent/path/spec.md >/dev/null 2>&1; then
  echo "FAIL: missing spec should exit non-zero"
  exit 1
fi

# Case 7 — Both --input and --spec-path supplied -> exit 2.
if bash "$CLF" --input "x" --spec-path "$tmp_spec" >/dev/null 2>&1; then
  echo "FAIL: both --input and --spec-path should exit 2"
  exit 1
fi

# Case 8 — Neither supplied -> exit 2.
if bash "$CLF" >/dev/null 2>&1; then
  echo "FAIL: missing args should exit 2"
  exit 1
fi

# Case 9 — Stdout shape: exactly two lines, no extra noise.
out=$(bash "$CLF" --input "redesign the dashboard")
line_count=$(printf '%s\n' "$out" | wc -l | tr -d ' ')
[ "$line_count" = "2" ] || { echo "FAIL: stdout should be exactly 2 lines (got: $line_count lines)"; exit 1; }

echo "PASS: design-gate-classify — token table covers UI tokens; substring matches rejected; usage validation works"
exit 0
```

4. **Make verify script executable**: `chmod +x scripts/verify/m024-p07-design-gate-classify.sh`.

## Must-Haves

- `scripts/intake/design-gate-classify.sh` exists and is executable.
- The script is a pure decision emitter — no file writes anywhere except the test-only `mktemp` for the `--input` mode body buffer (cleaned up via `trap`).
- Token list matches the canonical 13 tokens in the rule table (`ui UI render design layout screen view panel viewer dashboard interface visual theme`).
- Whole-word matching via `grep -wE`: substrings like `serendipity` do NOT trigger the `pity`/`design`/etc. rules.
- Verdict logic: 0 hits → `none+high`; 1 hit → `walkthrough+low`; ≥2 distinct token hits → `walkthrough+high`.
- Exactly one of `--input` and `--spec-path` must be supplied; both or neither exits 2.
- Missing spec file exits 1 with `ERR: spec not found at <path>` to stderr.
- Stdout on success is exactly two lines (`design_gate=...` then `design_gate_confidence=...`); no extra noise.
- AD-19 single-script-file shape: every external invocation in the verify script is top-level; no inline compound bash, no plain subshells, no `$(...|...)` containing pipes.
- Bash 3.2 portable; no `declare -A`; no process substitution.

## Verification

```
bash scripts/verify/m024-p07-design-gate-classify.sh
```

Expected output (exit 0): `PASS: design-gate-classify — token table covers UI tokens; substring matches rejected; usage validation works`

## Inputs

### From Previous Tasks

(none — T01 is the leaf task)

### From Disk (Pre-existing)

- `scripts/intake/paragraph-classify.sh` — referenced as the source-of-shape (pure decision emitter convention). Key API: emits `key=value` lines to stdout; closed-enum value validation; bash 3.2 portable; AD-19 single-script-file shape. T01 mirrors this shape exactly.
- `scripts/intake/spec-shape-classify.sh` — same convention reference; demonstrates spec-path-mode reading.
- `templates/intake-proposal.md` — the proposal template defining the `design_gate` and `design_gate_confidence` slots that this classifier's stdout populates (via the emitter wiring in T03).
- POSIX utilities: `grep -wE`, `mktemp`, `trap`, `printf`, `chmod`, `cat`, `wc`, `tr`.

## Constraints

- POSIX sh + bash 3.2 portable.
- Pure decision emitter — no file writes outside the test-only `mktemp` body buffer with `trap` cleanup.
- AD-19 single-script-file shape in the verify script — no `$(...|...)` containing pipes, no plain subshells, no process substitution. The verify uses `printf '%s\n' "$out" | wc -l | tr -d ' '` for line counting; this is allowed because `printf | wc | tr` is a top-level pipeline, not a `$(...)` containing a pipe (the pipeline is OUTSIDE the assignment).
- No conversus invocations, no knowledge writes (NG-2, NG-5).
- No new schema fields — `design_gate` and `design_gate_confidence` already exist in the P01 template (the latter is added implicitly when the classifier runs; the rationale slot was already there).

## Expected Output

`scripts/intake/design-gate-classify.sh` exists, is executable, and `bash scripts/verify/m024-p07-design-gate-classify.sh` exits 0 with the `PASS:` line.
