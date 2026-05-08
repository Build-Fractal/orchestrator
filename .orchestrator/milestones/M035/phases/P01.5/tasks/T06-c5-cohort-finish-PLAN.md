---
schema_version: "1.0"
type: task-plan
task: "T06"
phase: "P01.5"
milestone: "M035"
name: "C5 — Command-cohort finish across 4 remaining operational templates"
depends_on: ["T05"]
---

## Prerequisites

Files that MUST exist on disk at task entry (verified at plan-authoring
time, 2026-05-08, by `grep -nE 'speckit\.orchestrator' …`):

- `templates/claude-settings.json` — line 56 contains
  `"Skill(speckit.orchestrator.*)"` (operational glob in allowed-skills
  list); line 64 contains `"Bash(bash spec-kit-orchestrator/scripts/*)"`
  (Bash glob).
- `templates/autonomy-defaults.yaml` — line 91 contains
  `- "Skill(speckit.orchestrator.*)"` (operational glob).
- `templates/instruction-schema.md` — line 140 contains
  `# speckit.orchestrator.<command>` (prose / schema example).
- `templates/compression-tier3-prompt.md` — lines 14 and 45 contain
  prose narrating the `speckit.orchestrator.*` namespaced alias as a
  legacy form.
- `tests/m035-acceptance/legacy-namespace-allowlist.txt` (from T01) —
  enumerates the 5 historical/migration files SC-7 must skip. These 4
  template files are NOT on the allowlist; T06 finishes them.

Pre-existing decisions consumed:

- D-RN-3 (T01 D0XX block): cohort prefix is `orchestrator:<cmd>`.
- RENAME-PLAN.md § 5 Commit 5 (the namespace-cohort step) — runbook
  source. Specifically: operational identifiers rename to the new
  shape; historical/migration prose reframes the legacy form as a
  documented historical reference.
- M035 roadmap Boundary Map (P01.5 line 33–34): the 4 surfaces this
  task closes are explicitly enumerated.

## Description

Close the residual `speckit.orchestrator.*` cohort references in the
4 operational template surfaces named in the M035 roadmap Boundary Map.
The earlier in-tree rename (M008/M015 era) handled the bulk of
`commands/*.md` and `scripts/*.sh` files; these 4 templates were
deferred and surface the final operational gap that SC-7 enforces.

Two of the four surfaces (`templates/claude-settings.json:56` glob,
`templates/autonomy-defaults.yaml:91` glob) are operational identifiers
in allowed-skills lists — direct rename to the new glob shape. Two
(`templates/instruction-schema.md:140`, `templates/compression-tier3-prompt.md:14,45`)
are prose surfaces — reframe the legacy form as documented historical
reference per the RENAME-PLAN.md C5 process.

Bonus: `templates/claude-settings.json:64` carries
`"Bash(bash spec-kit-orchestrator/scripts/*)"` which is a C1+C5 hybrid
surface (path + skill-glob shape). This task closes it as part of the
template-pass (it lives in the same file as the C5 line 56 fix and
the auto-loop benefits from one-commit-touches-one-file).

## Steps

1. **`templates/claude-settings.json` — two edits in one file**:
   - Line 56: `"Skill(speckit.orchestrator.*)"` →
     `"Skill(orchestrator:*)"`. The Skill-permission shape changes
     from dotted-namespace to colon-prefix per D-RN-3. Verify the JSON
     remains valid (the trailing `,` and surrounding array elements
     are unaffected).
   - Line 64: `"Bash(bash spec-kit-orchestrator/scripts/*)"` →
     `"Bash(bash orchestrator/scripts/*)"`. Path-shape rename per
     D-RN-5; this is a relative-path token in a Bash-permission glob.

2. **`templates/autonomy-defaults.yaml` — one edit**:
   - Line 91: `- "Skill(speckit.orchestrator.*)"` →
     `- "Skill(orchestrator:*)"`. YAML list element; quoting and
     indentation preserved.

3. **`templates/instruction-schema.md` — line 140 prose reframe**.
   Current line per inventory: `# speckit.orchestrator.<command>`
   (a header / schema example showing the legacy form as the active
   command identifier). Per RENAME-PLAN § 5 Commit 5 process for
   prose:
   - Read context lines 130–150 (or whatever frame surrounds line 140
     in the actual file at execution time — line numbers can drift
     after T04/T05 mass edits).
   - Rewrite the section so the active form is `orchestrator:<command>`
     and the legacy `speckit.orchestrator.<command>` form is named as
     a documented historical reference. Example shape:

     ```markdown
     # orchestrator:<command>

     This skill registers under the `orchestrator:<command>` cohort
     prefix. Pre-M035 cohort references used the legacy
     `speckit.orchestrator.<command>` shape; that form is preserved
     in historical / migration documentation only (see
     `commands/migrate.md` AD-15) and is NOT a live registration
     surface post-M035 P01.5.
     ```

4. **`templates/compression-tier3-prompt.md` — lines 14 and 45 prose
   reframe**. Current content (per inventory):
   - Line 14: `"orchestrator command names (slash-prefixed
     /orchestrator-*, colon-form orchestrator:*, or namespaced
     speckit.orchestrator.* aliases) and other slash-command tokens"`
   - Line 45: `   - Orchestrator command names — slash form
     (/orchestrator-auto), colon form (orchestrator:auto), or
     namespaced alias (speckit.orchestrator.dispatch).`

   Both lines describe orchestrator command names in prose enumerating
   their three forms. Reframe to drop the legacy namespaced-alias as a
   live form and call it a documented historical reference. Example
   rewrites:

   - Line 14 rewrite: `"orchestrator command names (slash-prefixed
     /orchestrator-*, colon-form orchestrator:*; the legacy
     speckit.orchestrator.* namespaced-alias form is documented in
     historical migration material only) and other slash-command
     tokens"`.

   - Line 45 rewrite: `   - Orchestrator command names — slash form
     (/orchestrator-auto), colon form (orchestrator:auto). The legacy
     namespaced-alias form (speckit.orchestrator.dispatch) appears
     only in pre-M035 historical/migration documentation.`

   Sentence flow is the priority — agent should reread surrounding
   prose at execution time and adjust if the surrounding paragraph
   reads awkwardly.

5. **Verify the 4 surfaces are converted**. After edits:

   ```bash
   git grep -nE 'speckit\.orchestrator' templates/claude-settings.json \
     templates/autonomy-defaults.yaml \
     templates/instruction-schema.md \
     templates/compression-tier3-prompt.md
   ```

   Expected output: empty, OR matches that are explicitly framed as
   historical references inside surrounding prose context. Operational
   surfaces (the JSON/YAML glob lines) MUST be empty.

6. **Author `tools/verify/m035-p015-c5-cohort-finish.sh`**:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p015-c5-cohort-finish.sh
   set -u
   REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   cd "$REPO_ROOT" || exit 1
   fail=0

   # Operational surfaces: zero matches (no exception).
   for f in \
     "templates/claude-settings.json" \
     "templates/autonomy-defaults.yaml"; do
     if grep -nE 'speckit\.orchestrator' "$REPO_ROOT/$f" > /dev/null 2>&1; then
       echo "FAIL: $f still has operational speckit.orchestrator reference" >&2
       fail=1
     fi
     # Confirm the new form is present.
     if ! grep -qE 'Skill\(orchestrator:' "$REPO_ROOT/$f"; then
       echo "FAIL: $f missing Skill(orchestrator:*) glob" >&2
       fail=1
     fi
   done

   # Prose surfaces: legacy form may appear ONLY inside historical-reference
   # framing. The verifier's contract is weaker — it asserts the new form
   # is present.
   for f in \
     "templates/instruction-schema.md" \
     "templates/compression-tier3-prompt.md"; do
     if ! grep -qE 'orchestrator:' "$REPO_ROOT/$f"; then
       echo "FAIL: $f missing orchestrator:<command> reference" >&2
       fail=1
     fi
   done

   # claude-settings.json line-64 path-shape check.
   if grep -qE 'Bash\(bash spec-kit-orchestrator/scripts/\*\)' "$REPO_ROOT/templates/claude-settings.json"; then
     echo "FAIL: templates/claude-settings.json still has spec-kit-orchestrator path in Bash permission" >&2
     fail=1
   fi

   if [ "$fail" -eq 0 ]; then echo "PASS: m035-p015-c5-cohort-finish"; exit 0; fi
   exit 1
   ```

## Must-Haves

- Operational `speckit.orchestrator.*` glob references in
  `claude-settings.json` + `autonomy-defaults.yaml` are converted to
  the `orchestrator:*` glob shape; prose surfaces in
  `instruction-schema.md` + `compression-tier3-prompt.md` carry the
  new form (legacy form, where retained, is framed as historical)
  - Check: `bash tools/verify/m035-p015-c5-cohort-finish.sh`

## Verification

```bash
bash tools/verify/m035-p015-c5-cohort-finish.sh
```

## Inputs

### From Previous Tasks

- T01..T05: foundation + path/prose sweeps complete. T06's surfaces are
  in 4 specific files; earlier passes did not touch them by design
  (those passes scope to `*.md` / `*.yml` / `*.yaml` and to
  `~/Sites/...` paths; the JSON file and the YAML lines here are
  cohort-specific and need per-line judgment).

### From Disk (Pre-existing)

- The 4 template files named in step 1–4.
- `references/RENAME-PLAN.md` § 5 Commit 5 — runbook source.
- M035 roadmap Boundary Map (P01.5 line 33–34) — file enumeration.

## Constraints

- **CON-3 (AP-009-shape-guard-honored)**: each file edit is a separate
  Edit tool call. No `xargs sed`.
- **AD-19 (single-script-file Check shape)**: verifier is one script.
- **JSON validity**: after editing `templates/claude-settings.json`,
  the file MUST remain valid JSON. The two edits (line 56, line 64)
  are within `"…"` string values — quoting / commas / surrounding array
  syntax unchanged.
- **YAML validity**: after editing `templates/autonomy-defaults.yaml`,
  the file MUST remain valid YAML (list-element shape preserved).
- **Prose-side framing must be unambiguous**: when reframing
  `speckit.orchestrator.*` as a historical reference, the surrounding
  sentence MUST make clear the legacy form is documented for migration
  reasons only and NOT an active surface. Ambiguous framing risks SC-7
  drift in future audits.

## Notes

- **Plan-phase verifier-availability cross-check (rule 2)**: T06
  authors `m035-p015-c5-cohort-finish.sh` in step 6.
- **Plan-phase classifier-shape pre-validation (rule 3)**: pure grep;
  no classifier.
- **Plan-phase real-DB rule (rule 5)**: not applicable.
- **Why T06 is sequenced LAST among the mechanical sweeps**: cohort-
  shape references reach into operational dispatch surfaces (the
  JSON/YAML glob lines control what skills the runtime registers).
  Any post-rename breakage is loudest at the dispatch layer; isolating
  this task in its own commit means a regression revert is cheap.

## Expected Output

After T06 completes:

- `templates/claude-settings.json` line 56 carries
  `"Skill(orchestrator:*)"`; line 64 carries `Bash(bash orchestrator/scripts/*)`.
- `templates/autonomy-defaults.yaml` line 91 carries
  `- "Skill(orchestrator:*)"`.
- `templates/instruction-schema.md` and `templates/compression-tier3-prompt.md`
  reference the new `orchestrator:<command>` form prominently; any
  retained legacy mention is framed as documented historical reference.
- One verifier script exists under `tools/verify/`.
