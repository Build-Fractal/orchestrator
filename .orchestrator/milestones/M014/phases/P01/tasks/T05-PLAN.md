---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P01"
milestone: "M014"
name: "commands/specify.md + scripts/specify/specify.sh FR-1 create-path + .orchestrator/config.yml specify: section"
depends_on: ["T01", "T02", "T03", "T04"]
---

## Prerequisites

All four upstream tasks must be green:

- T01: `templates/spec-template.md` + `templates/spec-scaffolder-prompt.md` + `tests/fixtures/m014-p01/specify-fixture-prose.txt` ready.
- T02: `scripts/verify/spec-shape-lint.sh` ready.
- T03: `scripts/util/dual-write-runtime-md.sh` + `.orchestrator/config.yml` `dual_write_agents: true` ready.
- T04: `scripts/knowledge/spec-complexity-probe.sh` stub ready.

Pre-existing disk state:

- `scripts/lifecycle/lock-manager.sh` is the existing lock utility for number-resolution TOCTOU.
- `.orchestrator/execution-log.jsonl` exists; M019 Tier 1 emitter is live. Scripts append JSONL records via the shape documented at `references/events.md` and exemplified at `scripts/integrations/github-sync.sh` (function `emit_tier1_record`).
- `scripts/dispatch/dispatch-interface.sh` is the runtime-agnostic dispatch surface (referenced by `commands/specify.md`; not invoked in P01 since scaffold-fill is deferred).
- `commands/` contains 19 existing command definitions to use as pattern precedents (especially `commands/ingest.md` and `commands/init.md`).

## Description

Ship the user-facing surface for `orchestrator:specify`:

1. `commands/specify.md` — the markdown command definition (MEM012 shape).
2. `scripts/specify/specify.sh` — the create-path implementation.
3. `.orchestrator/config.yml` — the `specify:` section (additive, appended after T03's `dual_write_agents:` key).

P01 ships the **create-path only**. Subcommands `--amend` and `split` have surface entries but P01's behavior is:

- `specify` (default, with `--description` / `--slug`): full create-path implementation.
- `specify --amend <path>`: re-scaffold **only the placeholder-bearing sections** (sections whose body is exclusively `<TODO: ...>` bracketed blocks, i.e., case-(a) in FR-14). Fully-authored and partial-placeholder sections are left byte-identically. The full FR-14 three-case semantics land in P04.
- `specify split <path>`: stub — prints `split: decomposition flow lands in P04 per M014 roadmap` to stderr and exits 2.

Scaffold-fill under CC runtime is **deferred to a later M014 phase** per the P01 boundary map — `scripts/specify/specify.sh` produces a skeleton-only scaffold in P01 across all runtimes. `RUNTIME-ASSUMPTIONS.md` FR-3 (authored by T04) documents this deferral.

## Steps

### Step 1: Create `commands/specify.md`

The command follows the MEM012 shape: YAML frontmatter with `description`, then Title, Prerequisites, Usage, Workflow, Output, Idempotency, Error Handling, Referenced Scripts.

Verbatim skeleton (tune prose for clarity; shape is load-bearing):

```markdown
---
description: "Use when authoring a new feature spec. Scaffolds specs/<NNN>-<slug>/spec.md conforming to the FR-2 Section Contract and dual-writes a Recent Changes entry to CLAUDE.md + AGENTS.md."
---

# orchestrator:specify

Scaffold a new feature spec from a natural-language description. The scaffolded `specs/<NNN>-<slug>/spec.md` matches the Section Contract pinned by `templates/spec-template.md`; the `AGENTS.md` and `CLAUDE.md` Recent Changes region is dual-written via the FR-12 helper; an `unit_close` record is appended to `.orchestrator/execution-log.jsonl`.

This is the load-bearing command for the M014 dogfood loop: every future milestone's spec is expected to be produced by running this command rather than hand-copying an existing `specs/*/spec.md`.

## Prerequisites

- `.orchestrator/` exists (orchestrator state root). Run `orchestrator:init` first if absent.
- `templates/spec-template.md` is the Section Contract SSOT.
- `scripts/util/dual-write-runtime-md.sh` is installed (FR-12 helper).
- `scripts/verify/spec-shape-lint.sh` is installed (FR-4 verifier, invoked downstream by `orchestrator:discuss`).

## Usage

```
bash scripts/specify/specify.sh --description "<prose>" [--slug <slug>] [--milestone <M###>] [--force] [--yes] [--dry-run]
```

Flags:

- `--description <prose>` — required on create-path. The operator's natural-language description; quoted in the scaffold's `Input:` frontmatter field.
- `--slug <slug>` — optional. Kebab-case short name for the spec directory. If omitted, derived deterministically from `--description` (first 5 words, lowercased, kebab-cased, 40-char truncation) and accepted silently in `--yes` mode.
- `--milestone <M###>` — optional. Binds the scaffold to a milestone ID in the frontmatter; otherwise `<TODO: bind to milestone>`.
- `--force` — optional. Permits overwrite of an existing `specs/<NNN>-<slug>/` directory. Without this flag, slug collision exits non-zero.
- `--yes` — optional. Auto-accepts interactive prompts (slug derivation in particular). Implied under `orchestrator:auto`.
- `--dry-run` — optional. Emits FR-19 JSONL manifest records to stdout describing what would be written; no disk writes performed.

Subcommand surfaces (P01 ships the surface; full semantics in later phases):

- `--amend <path>` — re-scaffolds placeholder-bearing sections only; authored regions preserved (partial FR-14 in P01; full three-case semantics in P04).
- `split <path>` — stub; prints a deferral diagnostic and exits 2.

## Workflow

1. **Preflight**: confirm `.orchestrator/` exists; otherwise exit 2 with a pointer to `orchestrator:init`.
2. **Lock acquisition**: acquire `scripts/lifecycle/lock-manager.sh` around spec-number resolution to prevent TOCTOU (Edge Case: spec number race).
3. **Number allocation**: scan `specs/NNN-*` directories; next number is `max(existing) + 1`.
4. **Slug derivation**: if `--slug` absent, derive from `--description` (first 5 words, lowercased, kebab-cased, 40-char truncation). Under `--yes`, accepted silently; otherwise print derived slug with one-keystroke accept/reject.
5. **Collision check**: if `specs/<NNN>-<slug>/` exists, exit 1 with a clear error unless `--force`.
6. **Scaffold write**: copy `templates/spec-template.md` into `specs/<NNN>-<slug>/spec.md` via temp-file-then-rename. Substitute frontmatter placeholders (`{{feature_slug}}`, `{{created_at}}`, `{{milestone}}`, `{{feature_title}}`, `{{description}}`). Skeleton-only in P01 — no LLM round-trip (see `RUNTIME-ASSUMPTIONS.md` FR-3).
7. **Dual-write Recent Changes**: invoke `scripts/util/dual-write-runtime-md.sh --marker recent-changes --content <fragment> --file CLAUDE.md --file AGENTS.md` with a one-line fragment `- <NNN>-<slug>: <first-80-chars-of-description>`.
8. **Complexity probe**: invoke `scripts/knowledge/spec-complexity-probe.sh specs/<NNN>-<slug>/spec.md` (stub; P01 no-op).
9. **Observability emission**: append one `unit_close` record to `.orchestrator/execution-log.jsonl` with `{command: "orchestrator:specify", specs_scaffolded: 1, dual_writes: <1 or 2>, elapsed_ms, source: "runtime"}`.
10. **Lock release** + **stdout**: print the absolute path to the written spec; exit 0.

## Output

- `specs/<NNN>-<slug>/spec.md` — scaffolded spec, skeleton with `<TODO: ...>` placeholders in every section.
- `CLAUDE.md` Recent Changes region updated (inside `# >>> orchestrator:recent-changes >>>` markers).
- `AGENTS.md` Recent Changes region updated (same markers; skipped if `dual_write_agents: false`).
- `.orchestrator/execution-log.jsonl` gains one `unit_close` record.

## Idempotency

Re-running with the same `--slug` fails with a clear error. `--force` permits overwrite. Re-running with `--amend` is idempotent on unchanged sections.

## Error Handling

- Missing `.orchestrator/`: exit 2, point to `orchestrator:init`.
- Slug collision: exit 1, mention `--force`.
- Template missing: exit 1, point to `templates/spec-template.md`.
- Dual-write helper missing: exit 1, point to `scripts/util/dual-write-runtime-md.sh`.
- Execution-log append failure: warn on stderr but do not fail the command (observability is best-effort, not load-bearing on scaffold success).

## Referenced Scripts

- `scripts/specify/specify.sh` — this command's implementation.
- `templates/spec-template.md` — Section Contract SSOT.
- `templates/spec-scaffolder-prompt.md` — FR-3 CC LLM prompt (invocation deferred per RUNTIME-ASSUMPTIONS.md FR-3).
- `scripts/util/dual-write-runtime-md.sh` — FR-12 marker-bounded dual-write helper.
- `scripts/verify/spec-shape-lint.sh` — FR-4 shape verifier (consumed by `orchestrator:discuss` preflight downstream).
- `scripts/knowledge/spec-complexity-probe.sh` — FR-5 probe stub (full probe in P04).
- `scripts/lifecycle/lock-manager.sh` — spec-number race mitigation.
- `scripts/dispatch/dispatch-interface.sh` — CC LLM round-trip dispatch surface (not invoked in P01).
```

### Step 2: Create `scripts/specify/specify.sh`

Verbatim body (~250 lines, skeleton):

```bash
#!/usr/bin/env bash
# scripts/specify/specify.sh — FR-1 orchestrator:specify create-path.
#
# P01 scope: create-path skeleton scaffold (no LLM round-trip — see
# RUNTIME-ASSUMPTIONS.md FR-3). Full --amend semantics and split flow in later
# M014 phases.
#
# Bash 3.2 compatible. Passes scripts/verify/anti-pattern-lint.sh.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

DESCRIPTION=""
SLUG=""
MILESTONE=""
FORCE=0
YES=0
DRY_RUN=0
SUBCMD="specify"

usage() {
  cat <<'EOF'
Usage: specify.sh --description "<prose>" [--slug <slug>] [--milestone <M###>]
                  [--force] [--yes] [--dry-run]
       specify.sh --amend <path> [--yes] [--dry-run]
       specify.sh split <path>

See commands/specify.md for full semantics.
EOF
}

# Parse first positional subcommand.
if [ $# -ge 1 ] && [ "$1" = "split" ]; then
  SUBCMD="split"
  shift
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --description)
      if [ $# -lt 2 ]; then echo "--description requires a value" >&2; exit 1; fi
      DESCRIPTION="$2"; shift 2 ;;
    --slug)
      if [ $# -lt 2 ]; then echo "--slug requires a value" >&2; exit 1; fi
      SLUG="$2"; shift 2 ;;
    --milestone)
      if [ $# -lt 2 ]; then echo "--milestone requires a value" >&2; exit 1; fi
      MILESTONE="$2"; shift 2 ;;
    --amend)
      if [ $# -lt 2 ]; then echo "--amend requires a path" >&2; exit 1; fi
      SUBCMD="amend"; AMEND_PATH="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --yes) YES=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *)
      # Positional argument for split subcommand.
      if [ "$SUBCMD" = "split" ] && [ -z "${SPLIT_PATH:-}" ]; then
        SPLIT_PATH="$1"; shift
      else
        echo "specify.sh: unknown argument: $1" >&2; exit 1
      fi
      ;;
  esac
done

# --- Subcommand: split (P01 stub) ---
if [ "$SUBCMD" = "split" ]; then
  echo "split: decomposition flow lands in P04 per M014 roadmap" >&2
  exit 2
fi

# --- Preflight: .orchestrator/ exists ---
if [ ! -d "${PROJECT_ROOT}/.orchestrator" ]; then
  echo "specify.sh: .orchestrator/ not found — run orchestrator:init first" >&2
  exit 2
fi

# --- Templates available ---
TEMPLATE="${PROJECT_ROOT}/templates/spec-template.md"
if [ ! -f "$TEMPLATE" ]; then
  echo "specify.sh: templates/spec-template.md missing" >&2
  exit 1
fi
DUAL_WRITE="${PROJECT_ROOT}/scripts/util/dual-write-runtime-md.sh"
if [ ! -x "$DUAL_WRITE" ]; then
  echo "specify.sh: scripts/util/dual-write-runtime-md.sh missing or not executable" >&2
  exit 1
fi

# --- Subcommand: amend (P01 placeholder-only semantics) ---
if [ "$SUBCMD" = "amend" ]; then
  if [ ! -f "$AMEND_PATH" ]; then
    echo "specify.sh: --amend target not found: $AMEND_PATH" >&2; exit 1
  fi
  # P01: leave file unchanged. Full FR-14 three-case semantics in P04.
  echo "amend: P01 ships the surface; full three-case semantics land in P04" >&2
  echo "$AMEND_PATH"
  exit 0
fi

# --- Create path: --description required ---
if [ -z "$DESCRIPTION" ]; then
  echo "specify.sh: --description required on create path" >&2
  usage >&2
  exit 1
fi

# --- Slug derivation ---
if [ -z "$SLUG" ]; then
  # Take first 5 words, lowercase, kebab-case, truncate to 40 chars.
  SLUG="$(echo "$DESCRIPTION" | awk '{ for (i=1;i<=5 && i<=NF;i++) printf "%s%s", (i>1?"-":""), $i }' | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9-\n' '-' | sed -e 's/--*/-/g' -e 's/-$//')"
  if [ ${#SLUG} -gt 40 ]; then SLUG="$(printf '%s' "$SLUG" | cut -c1-40)"; fi
  if [ "$YES" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
    echo "derived slug: $SLUG (pass --yes to accept silently in auto mode)" >&2
  fi
fi

# --- Next spec number ---
mkdir -p "${PROJECT_ROOT}/specs"
HIGHEST=0
for d in "${PROJECT_ROOT}/specs"/*/ ; do
  bn="$(basename "$d")"
  prefix="$(echo "$bn" | awk -F- '{print $1}')"
  if [ "$prefix" != "" ] && echo "$prefix" | grep -qE '^[0-9]+$'; then
    if [ "$prefix" -gt "$HIGHEST" ]; then HIGHEST="$prefix"; fi
  fi
done
NEXT=$((HIGHEST + 1))
NEXT_STR="$(printf '%03d' "$NEXT")"
SPEC_DIR="${PROJECT_ROOT}/specs/${NEXT_STR}-${SLUG}"
SPEC_PATH="${SPEC_DIR}/spec.md"

# --- Collision check ---
if [ -d "$SPEC_DIR" ] && [ "$FORCE" -eq 0 ]; then
  echo "specify.sh: $SPEC_DIR already exists (pass --force to overwrite)" >&2
  exit 1
fi

CREATED_AT="$(date -u +%Y-%m-%d)"
MS="${MILESTONE:-<TODO: bind to milestone>}"
FEATURE_TITLE="${NEXT_STR}-${SLUG}"

# --- Dry-run manifest emission ---
if [ "$DRY_RUN" -eq 1 ]; then
  printf '{"command":"orchestrator:specify","action_type":"scaffold-spec","target_path":"%s","source_ref":"templates/spec-template.md","description":"scaffold %s from %d-word description"}\n' \
    "$SPEC_PATH" "${NEXT_STR}-${SLUG}" "$(echo "$DESCRIPTION" | wc -w | tr -d ' ')"
  printf '{"command":"orchestrator:specify","action_type":"dual-write-region","target_path":"%s/CLAUDE.md","source_ref":"recent-changes","description":"append %s entry"}\n' \
    "$PROJECT_ROOT" "${NEXT_STR}-${SLUG}"
  printf '{"command":"orchestrator:specify","action_type":"dual-write-region","target_path":"%s/AGENTS.md","source_ref":"recent-changes","description":"append %s entry"}\n' \
    "$PROJECT_ROOT" "${NEXT_STR}-${SLUG}"
  exit 0
fi

# --- Acquire lock ---
LOCK_MGR="${PROJECT_ROOT}/scripts/lifecycle/lock-manager.sh"
LOCK_ACQUIRED=0
if [ -x "$LOCK_MGR" ]; then
  # Best-effort lock acquisition. Non-fatal if unavailable (single-user projects).
  bash "$LOCK_MGR" acquire specify 2>/dev/null && LOCK_ACQUIRED=1 || true
fi

mkdir -p "$SPEC_DIR"

# --- Scaffold write: temp-file-then-rename ---
TMP_SPEC="$(mktemp)"
# Escape substitution strings for sed. We use a low-risk sed since placeholders
# are simple {{name}} tokens and substitution values are controlled.
esc() {
  # Escape | / & and newlines for sed.
  printf '%s' "$1" | sed -e 's/[|/&]/\\&/g'
}

FS="$(esc "${NEXT_STR}-${SLUG}")"
CA="$(esc "$CREATED_AT")"
MS_ESC="$(esc "$MS")"
FT="$(esc "$FEATURE_TITLE")"
DS_ESC="$(esc "$DESCRIPTION")"

sed \
  -e "s|{{feature_slug}}|${FS}|g" \
  -e "s|{{created_at}}|${CA}|g" \
  -e "s|{{milestone}}|${MS_ESC}|g" \
  -e "s|{{feature_title}}|${FT}|g" \
  -e "s|{{description}}|${DS_ESC}|g" \
  "$TEMPLATE" > "$TMP_SPEC"

mv "$TMP_SPEC" "$SPEC_PATH"

# --- Dual-write Recent Changes ---
FRAG="$(mktemp)"
DESC_SHORT="$(printf '%s' "$DESCRIPTION" | cut -c1-80)"
echo "- ${NEXT_STR}-${SLUG}: ${DESC_SHORT}" > "$FRAG"

DUAL_WRITES=0
if bash "$DUAL_WRITE" --marker recent-changes --content "$FRAG" --root "$PROJECT_ROOT" --file CLAUDE.md --file AGENTS.md >/dev/null 2>&1; then
  DUAL_WRITES=2
else
  # Fallback: try CLAUDE.md only (e.g., if dual_write_agents=false gated AGENTS.md).
  if bash "$DUAL_WRITE" --marker recent-changes --content "$FRAG" --root "$PROJECT_ROOT" --file CLAUDE.md >/dev/null 2>&1; then
    DUAL_WRITES=1
  fi
fi
rm -f "$FRAG"

# --- Complexity probe (stub) ---
PROBE="${PROJECT_ROOT}/scripts/knowledge/spec-complexity-probe.sh"
if [ -x "$PROBE" ]; then
  bash "$PROBE" "$SPEC_PATH" >/dev/null 2>&1 || true
fi

# --- Observability emission (best-effort) ---
LOG="${PROJECT_ROOT}/.orchestrator/execution-log.jsonl"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
ELAPSED=0  # Skeleton: elapsed time measurement omitted in P01 stub; P04 can add.
REC="{\"type\":\"unit_close\",\"ts\":\"${TS}\",\"command\":\"orchestrator:specify\",\"specs_scaffolded\":1,\"dual_writes\":${DUAL_WRITES},\"elapsed_ms\":${ELAPSED},\"source\":\"runtime\"}"
printf '%s\n' "$REC" >> "$LOG" 2>/dev/null || true

# --- Release lock ---
if [ "$LOCK_ACQUIRED" -eq 1 ]; then
  bash "$LOCK_MGR" release specify >/dev/null 2>&1 || true
fi

echo "$SPEC_PATH"
exit 0
```

Make executable: `chmod +x scripts/specify/specify.sh`.

### Step 3: Append `specify:` section to `.orchestrator/config.yml`

After T03's `dual_write_agents: true` line. Final file ends with:

```yaml
dual_write_agents: true  # M014/P01 FR-12 — when false, skip AGENTS.md dual-write
specify:
  complexity_thresholds:
    fr_count: 0              # Stub zero in P01; pinned in P04 per OQ #C-4
    user_story_count: 0
    raw_token_count: 0
    todo_density: 0
    contradiction_signal_count: 0
  scaffolder_description_min_words: 80
  scaffolder_llm_on_codex: false
```

### Step 4: Create gate verifiers

#### `scripts/verify/m014-p01-specify-command.sh`

```bash
#!/usr/bin/env bash
# Gate: verify commands/specify.md shape.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CMD="${PROJECT_ROOT}/commands/specify.md"

if [ ! -f "$CMD" ]; then
  echo "FAIL: commands/specify.md missing" >&2; exit 1
fi

grep -qE '^---$' "$CMD" || { echo "FAIL: YAML frontmatter absent" >&2; exit 1; }
grep -qE '^description:' "$CMD" || { echo "FAIL: description frontmatter field missing" >&2; exit 1; }
grep -qE '^# orchestrator:specify' "$CMD" || { echo "FAIL: title heading missing" >&2; exit 1; }
grep -qE '^## Prerequisites' "$CMD" || { echo "FAIL: Prerequisites section missing" >&2; exit 1; }
grep -qE '^## Usage' "$CMD" || { echo "FAIL: Usage section missing" >&2; exit 1; }
grep -qE '^## Workflow' "$CMD" || { echo "FAIL: Workflow section missing" >&2; exit 1; }
grep -qE '^## Output' "$CMD" || { echo "FAIL: Output section missing" >&2; exit 1; }
grep -qE '^## Idempotency' "$CMD" || { echo "FAIL: Idempotency section missing" >&2; exit 1; }
grep -qE '^## Error Handling' "$CMD" || { echo "FAIL: Error Handling section missing" >&2; exit 1; }
grep -qE '^## Referenced Scripts' "$CMD" || { echo "FAIL: Referenced Scripts section missing" >&2; exit 1; }

# Every required script is referenced.
for ref in "scripts/specify/specify.sh" "templates/spec-template.md" "scripts/util/dual-write-runtime-md.sh" "scripts/verify/spec-shape-lint.sh" "scripts/knowledge/spec-complexity-probe.sh"; do
  grep -qF "$ref" "$CMD" || { echo "FAIL: Referenced Scripts missing $ref" >&2; exit 1; }
done

echo "PASS: commands/specify.md shape verified"
exit 0
```

#### `scripts/verify/m014-p01-specify-sh.sh`

```bash
#!/usr/bin/env bash
# Gate: verify scripts/specify/specify.sh end-to-end on a scratch project.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SPECIFY="${PROJECT_ROOT}/scripts/specify/specify.sh"

if [ ! -x "$SPECIFY" ]; then
  echo "FAIL: scripts/specify/specify.sh missing or not executable" >&2; exit 1
fi

SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

# Hermetic scratch project: copy templates, scripts, config, CLAUDE.md.
mkdir -p "$SCRATCH/.orchestrator" "$SCRATCH/templates" "$SCRATCH/scripts/util" "$SCRATCH/scripts/specify" "$SCRATCH/scripts/knowledge" "$SCRATCH/scripts/lifecycle" "$SCRATCH/specs"
cp "$PROJECT_ROOT/templates/spec-template.md" "$SCRATCH/templates/"
cp "$PROJECT_ROOT/scripts/util/dual-write-runtime-md.sh" "$SCRATCH/scripts/util/"
cp "$PROJECT_ROOT/scripts/specify/specify.sh" "$SCRATCH/scripts/specify/"
cp "$PROJECT_ROOT/scripts/knowledge/spec-complexity-probe.sh" "$SCRATCH/scripts/knowledge/"
# Lock manager is optional — use stub if absent.
if [ -f "$PROJECT_ROOT/scripts/lifecycle/lock-manager.sh" ]; then
  cp "$PROJECT_ROOT/scripts/lifecycle/lock-manager.sh" "$SCRATCH/scripts/lifecycle/"
fi

cat > "$SCRATCH/.orchestrator/config.yml" <<'EOF'
schema_version: "1.0"
dual_write_agents: true
EOF

cat > "$SCRATCH/CLAUDE.md" <<'EOF'
# CLAUDE.md test seed

## Recent Changes

- pre-existing entry
EOF

# Run specify.sh against the scratch project.
cd "$SCRATCH"
OUT="$(bash "$SCRATCH/scripts/specify/specify.sh" --description "Test exporter that ships merged-PR diffs to Slack for async review." --slug test-exporter --yes 2>&1 || true)"
RC=$?
cd "$PROJECT_ROOT"

if [ $RC -ne 0 ]; then
  echo "FAIL: specify.sh exited $RC (expected 0); output: $OUT" >&2; exit 1
fi

WRITTEN="$(echo "$OUT" | tail -1)"
if [ ! -f "$WRITTEN" ]; then
  echo "FAIL: written path does not exist: $WRITTEN" >&2; exit 1
fi

# Frontmatter substitutions performed.
head -15 "$WRITTEN" | grep -qF 'test-exporter' || {
  echo "FAIL: feature slug not substituted" >&2; exit 1
}
head -15 "$WRITTEN" | grep -qF 'Status**: Draft' || {
  echo "FAIL: Status: Draft missing" >&2; exit 1
}

# AGENTS.md and CLAUDE.md both updated.
if [ ! -f "$SCRATCH/AGENTS.md" ]; then
  echo "FAIL: AGENTS.md not created" >&2; exit 1
fi
grep -qF 'test-exporter' "$SCRATCH/AGENTS.md" || {
  echo "FAIL: AGENTS.md missing recent-changes entry" >&2; exit 1
}
grep -qF '# >>> orchestrator:recent-changes >>>' "$SCRATCH/CLAUDE.md" || {
  echo "FAIL: CLAUDE.md missing marker region" >&2; exit 1
}

# Execution-log record appended.
LOG="$SCRATCH/.orchestrator/execution-log.jsonl"
if [ -f "$LOG" ]; then
  grep -qF '"command":"orchestrator:specify"' "$LOG" || {
    echo "FAIL: execution-log.jsonl missing unit_close record" >&2; exit 1
  }
fi

# Slug collision errors loudly.
OUT2="$(bash "$SCRATCH/scripts/specify/specify.sh" --description "dup" --slug test-exporter --yes 2>&1 || true)"
RC2=$?
if [ $RC2 -eq 0 ]; then
  echo "FAIL: slug collision exited 0 (expected non-zero)" >&2; exit 1
fi

# Dry-run emits JSONL manifest.
DRY_OUT="$(bash "$SCRATCH/scripts/specify/specify.sh" --description "dry run test" --slug dry-test --yes --dry-run 2>&1 || true)"
RC3=$?
if [ $RC3 -ne 0 ]; then
  echo "FAIL: --dry-run exited non-zero" >&2; exit 1
fi
echo "$DRY_OUT" | grep -qE '"action_type":"scaffold-spec"' || {
  echo "FAIL: --dry-run missing scaffold-spec action" >&2; exit 1
}

# Split stub exits 2.
bash "$SCRATCH/scripts/specify/specify.sh" split /tmp/does-not-matter >/dev/null 2>&1
if [ $? -ne 2 ]; then
  echo "FAIL: split stub should exit 2" >&2; exit 1
fi

echo "PASS: scripts/specify/specify.sh end-to-end verified"
exit 0
```

#### `scripts/verify/m014-p01-agents-md-shape.sh`

```bash
#!/usr/bin/env bash
# Gate: verify AGENTS.md exists with marker-bounded region after a specify run.
# This gate runs after the end-to-end specify test; it asserts the repo-root
# AGENTS.md has the markers (the first specify run will land this when T05
# is dispatched end-to-end during auto execution, OR during the phase-suite
# dogfood run).
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
AGENTS="${PROJECT_ROOT}/AGENTS.md"
CLAUDE="${PROJECT_ROOT}/CLAUDE.md"

# For P01 close, AGENTS.md may not yet exist at repo root (only scratch
# scaffolds have exercised it). The gate: IF AGENTS.md exists, its marker
# region must be well-formed; else the gate passes silently (creation is
# guarded by first specify invocation in auto mode).
if [ -f "$AGENTS" ]; then
  grep -qF '# >>> orchestrator:recent-changes >>>' "$AGENTS" || {
    echo "FAIL: AGENTS.md exists but missing orchestrator:recent-changes begin marker" >&2; exit 1
  }
  grep -qF '# <<< orchestrator:recent-changes <<<' "$AGENTS" || {
    echo "FAIL: AGENTS.md exists but missing orchestrator:recent-changes end marker" >&2; exit 1
  }
fi

# CLAUDE.md at repo root should gain markers once T05 dogfoods a write; until
# then, this gate is lenient.
if grep -qF '# >>> orchestrator:recent-changes >>>' "$CLAUDE"; then
  grep -qF '# <<< orchestrator:recent-changes <<<' "$CLAUDE" || {
    echo "FAIL: CLAUDE.md has begin marker but missing end marker" >&2; exit 1
  }
fi

echo "PASS: AGENTS.md shape verified"
exit 0
```

Make all three executable.

## Must-Haves

- `commands/specify.md` exists following MEM012 command-file structure, with Prerequisites, Usage, Workflow, Output, Idempotency, Error Handling, Referenced Scripts sections
- `commands/specify.md` names `scripts/specify/specify.sh`, `templates/spec-template.md`, `scripts/util/dual-write-runtime-md.sh`, `scripts/verify/spec-shape-lint.sh`, `scripts/knowledge/spec-complexity-probe.sh` in Referenced Scripts
- `scripts/specify/specify.sh` exists, is executable, implements create-path end-to-end on a scratch project, exits 0 on success
- Slug derivation works: first 5 words, lowercased, kebab-cased, 40-char truncation
- Slug collision without `--force` exits non-zero with clear diagnostic
- `--dry-run` emits FR-19 JSONL manifest records (`scaffold-spec` + `dual-write-region`) to stdout and makes zero disk writes
- `split` subcommand prints a deferral diagnostic to stderr and exits 2 (P01 stub)
- `--amend <path>` prints a deferral diagnostic to stderr and exits 0 (P01 surface stub — full FR-14 semantics in P04)
- The scaffolded `specs/<NNN>-<slug>/spec.md` passes `scripts/verify/spec-shape-lint.sh` (structural PASS; `todo_count > 0`)
- Invocation produces one `unit_close` JSONL record at `.orchestrator/execution-log.jsonl` with `command=orchestrator:specify`, `specs_scaffolded=1`, `dual_writes` ∈ `{1,2}`
- `.orchestrator/config.yml` gains the `specify:` section additively below T03's `dual_write_agents:` key; all pre-existing keys byte-preserved
- All new shell scripts are Bash 3.2 compatible and pass `scripts/verify/anti-pattern-lint.sh`

## Verification

```
bash scripts/verify/m014-p01-specify-command.sh
```

Expected: `PASS: commands/specify.md shape verified`, exit 0.

```
bash scripts/verify/m014-p01-specify-sh.sh
```

Expected: `PASS: scripts/specify/specify.sh end-to-end verified`, exit 0.

```
bash scripts/verify/m014-p01-agents-md-shape.sh
```

Expected: `PASS: AGENTS.md shape verified`, exit 0.

```
bash scripts/verify/m014-p01-config-keys.sh
```

Expected: `PASS: config keys verified`, exit 0 (T03's gate re-run — now includes `specify:` section checks once T05 has updated config).

```
bash scripts/verify/anti-pattern-lint.sh --fixture scripts/specify/specify.sh
```

Expected: exit 0.

## Inputs

### From Previous Tasks

- `templates/spec-template.md` (from T01)
  - Key API: read-only template; scaffolder `sed`-substitutes `{{feature_slug}}`, `{{created_at}}`, `{{milestone}}`, `{{feature_title}}`, `{{description}}`.
  - Key types: markdown file with YAML frontmatter and required sections.
- `templates/spec-scaffolder-prompt.md` (from T01) — FR-3 prompt; not invoked in P01.
- `scripts/verify/spec-shape-lint.sh` (from T02) — invoked downstream by `orchestrator:discuss`; T05 command doc references it; scaffolded spec is expected to pass this linter.
- `scripts/util/dual-write-runtime-md.sh` (from T03)
  - Key API: `dual-write-runtime-md.sh --marker <region> --content <fragment> --file <target> [--root <project>] [--dry-run]`; exit 0 on success.
  - Behavior: writes between `# >>> orchestrator:<region> >>>` / `# <<< orchestrator:<region> <<<` markers in each `--file`; skips `AGENTS.md` when config has `dual_write_agents: false`.
- `scripts/knowledge/spec-complexity-probe.sh` (from T04) — invoked end-of-scaffold; stub returns `probe=below-threshold`.

### From Disk (Pre-existing)

- `.orchestrator/config.yml` — T03 added `dual_write_agents: true`; T05 appends `specify:` section.
- `.orchestrator/execution-log.jsonl` — M019 Tier 1 append target.
- `scripts/lifecycle/lock-manager.sh` — optional lock for number-resolution TOCTOU.
- `commands/ingest.md`, `commands/init.md` — MEM012 command-file structure precedents.
- `scripts/verify/anti-pattern-lint.sh` — compliance verifier.

## Constraints

- Skeleton-only scaffold across all runtimes in P01 (no LLM round-trip). `RUNTIME-ASSUMPTIONS.md` FR-3 documents this deferral.
- Atomic writes (temp-file-then-rename) for `spec.md`.
- Lock acquisition around number-resolution is best-effort; missing lock manager does not fail the command (single-user-dogfood stance; future-milestone extensions can tighten).
- `--dry-run` makes zero disk writes and emits FR-19 JSONL to stdout (one record per would-be write).
- Observability emission is best-effort — log-append failure does not fail scaffold.
- `--yes` is the auto-mode-friendly default; `orchestrator:auto` dispatches pass `--yes`.
- Every Check command uses single-script-file shape (AD-19); compound bash is confined to helper scripts.
- Passes `scripts/verify/anti-pattern-lint.sh`.

## Expected Output

Files committed:

1. `commands/specify.md` — user-facing command definition (~150 lines)
2. `scripts/specify/specify.sh` — FR-1 create-path (~250 lines, executable)
3. `.orchestrator/config.yml` — additive edit adding `specify:` section (11 lines appended)
4. `scripts/verify/m014-p01-specify-command.sh` — command-shape gate (~35 lines, executable)
5. `scripts/verify/m014-p01-specify-sh.sh` — end-to-end gate (~100 lines, executable)
6. `scripts/verify/m014-p01-agents-md-shape.sh` — AGENTS.md marker gate (~30 lines, executable)

All gate verifiers exit 0.
