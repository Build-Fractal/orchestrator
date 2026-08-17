---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P03"
milestone: "M046"
name: "commands/auto.md unified classify-first entry authoring"
depends_on: ["T01"]
---

## Prerequisites

- T01 completed: `scripts/intake/auto-entry.sh` exists with the `AUTO:ROUTE` /
  `AUTO:BLOCK_AMBIGUITY` stdout contract.
- `commands/auto.md` exists (currently opens with the Preflight Summary section;
  the Tier-C loop + M045 self-continue + P04 unattended-envelope sections are all
  present and must be left intact).

## Description

Author the unified classify-first entry into `commands/auto.md`: a new leading
section (placed after the frontmatter/title, BEFORE the existing "Preflight
Summary" section) that documents `orchestrator:auto <arg>` tier routing via
`auto-entry.sh`, the `AUTO:ROUTE` / `AUTO:BLOCK_AMBIGUITY` contract, and the FR-5
`--yes` narrow-semantics boundary (D020). This is the FR-1 authoring deliverable.
Do NOT alter the existing Tier-C loop mechanics, the M045 self-continue section, or
the P04 `### Unattended envelope (--unattended, M046 P04)` section — this task is
purely additive at the top.

## Steps

1. Read `commands/auto.md` frontmatter + the first ~10 lines to find the insertion
   point (after the `# orchestrator:auto` title paragraph, before
   `## Preflight Summary`).

2. Update the frontmatter `description` field to reflect that `orchestrator:auto`
   is now the single classify-first entry — it sizes any argument to a tier
   (Tier A/A+/B one-shot, Tier C loop) or BLOCKs on ambiguity, and absorbs the
   former `orchestrator:do`.

3. Insert a new section titled `## Unified Tier-Sized Entry (M046 / FR-1)`
   containing:
   - A statement that `orchestrator:auto <arg>` classifies the argument's tier via
     the M024 classifier (`scripts/intake/shape-detect.sh`) through the driver
     `scripts/intake/auto-entry.sh` and routes to the tier-sized path.
   - The routing table:
     | arg | driver output | action |
     | empty / existing milestone dir | `AUTO:ROUTE tier=c mode=loop target=<...>` | enter the Tier-C loop documented below (unchanged) |
     | Tier A/A+/B task description | `AUTO:ROUTE tier=<a\|a_plus\|b> mode=one-shot` | one-shot dispatch (former `orchestrator:do` behavior) |
     | below the confidence floor | `AUTO:BLOCK_AMBIGUITY verdict=<v> conf=<c>` | exit 0 without dispatching; operator disambiguates |
   - A single-script invocation example:
     `bash scripts/intake/auto-entry.sh "<task-or-dir-or-empty>"`.
   - A one-line note that the one-shot path reuses `route-to-dispatch.sh` and
     `build-context.sh` byte-unchanged (FR-2 / CON-2), and that the Tier-C branch
     hands to the existing loop flow unchanged (M045 legacy parity, FR-17).
   - A pointer that `orchestrator:do` is now a deprecation shim over the same
     driver (see `commands/do.md`).

4. Insert a short `### --yes vs --unattended (FR-5 / D020)` subsection stating:
   `--yes` skips the single attended confirmation prompt (the Tier-A+ approval
   prompt on the one-shot path, or the M029 preflight confirm on the Tier-C loop
   path) — it keeps its existing narrow meaning and does NOT broaden. Unattended /
   destructive-approval authority is governed exclusively by `--unattended` (P04),
   which carries the FR-13 driver-level fail-closed caps. `--yes` never grants
   unattended authority.

5. Leave every existing section (`## Preflight Summary`, the loop, self-continue,
   the P04 unattended envelope) byte-intact.

## Must-Haves

- `commands/auto.md` contains a "Unified Tier-Sized Entry" section, the literal
  `AUTO:BLOCK_AMBIGUITY`, a reference to `scripts/intake/auto-entry.sh`, and the
  `--yes` / `--unattended` boundary note.

## Verification

```bash
test -f commands/auto.md
grep -qi "classify" commands/auto.md
grep -q "AUTO:BLOCK_AMBIGUITY" commands/auto.md
grep -q "auto-entry.sh" commands/auto.md
grep -q "Unified Tier-Sized Entry" commands/auto.md
grep -q "unattended" commands/auto.md
```

## Inputs

### From Previous Tasks

- `scripts/intake/auto-entry.sh` (from T01)
  - Key API: stdout/stderr contract — `AUTO:ROUTE tier=c mode=loop target=<dir>`
    for dir/empty args; `AUTO:ROUTE tier=<a|a_plus|b> mode=one-shot` for
    descriptions; `AUTO:BLOCK_AMBIGUITY verdict=<v> conf=<c>` below floor. All exit
    0. Six do flags + `--ambiguity-mode` (default block).

### From Disk (Pre-existing)

- `commands/auto.md` — the existing auto command doc. The P04 unattended-envelope
  section (`### Unattended envelope (--unattended, M046 P04)`) documents the
  `--unattended` gate this task's `--yes` boundary note references.

## Constraints

- Additive only at the top; do not modify the existing loop/self-continue/P04
  sections.
- MEM012: preserve the command-file structure (frontmatter → title → sections →
  Referenced Scripts).

## Expected Output

`commands/auto.md` opens (after title) with the Unified Tier-Sized Entry section
documenting the classify-first routing + the `--yes`/`--unattended` boundary, with
all pre-existing sections intact.
