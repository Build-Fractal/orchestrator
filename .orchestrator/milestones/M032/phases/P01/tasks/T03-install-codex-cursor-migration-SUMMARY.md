---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P01"
milestone: "M032"
provides:
  - "install-codex.sh + install-cursor.sh migrated to project_assets: schema; --asset-mode-override flag added to both; cross-installer parity locked via tools/verify/m032-p01-installers-parity.sh"
requires:
  - "from:T01 what:read-project-assets.sh + install-collision-check.sh + install-asset-mode.sh + manifest project_assets: schema; from:T02 what:install-claude-code.sh canonical migration + golden fixture + cc-byte-identical verifier"
affects:
  - "T04"
key_files:
  - "packaging/install/install-codex.sh,packaging/install/install-cursor.sh,tools/verify/m032-p01-installers-parity.sh"
key_decisions:
  - "none"
patterns_established:
  - "cross-installer parity invariant: project-asset staging block is byte-identical (78 lines) across all three installers; differences confined to surrounding runtime-specific context (skill-registration, hook-payload, settings-merge, --project-dir requirement)"
drill_down_paths:
  - ".orchestrator/milestones/M032/phases/P01/tasks/T03-install-codex-cursor-migration-PAYLOAD.md"
duration: "45m"
verification_result: "pass"
completed_at: "2026-05-04T01:21:22Z"
---

T03 closes FR-2 across the codex and cursor installers, completing the symmetry pass started in T02 (claude-code) and grounded in T01 (lifecycle helpers + manifest schema).

## What Shipped

1. **packaging/install/install-codex.sh** -- pre-T03 RUNTIME_DIRS block (lines 230-271) replaced with the canonical project_assets:-driven dispatch from claude-code. Added --asset-mode-override flag parsing (long + equals form) and ASSET_MODE_OVERRIDE variable initialization. Help-text comment block extended with --asset-mode-override docs.

2. **packaging/install/install-cursor.sh** -- pre-T03 RUNTIME_DIRS block (lines 239-280) replaced with the same canonical block. Same --asset-mode-override addition. Cursor pre-existing --project-dir REQUIRED constraint and HOME=/ guard are upstream of the project-asset stage and were not touched.

3. **tools/verify/m032-p01-installers-parity.sh** -- 25-check parity verifier (created). Asserts: (a) RUNTIME_DIRS= absent from all three installers; (b) all three source read-project-assets.sh + dispatch through install-collision-check.sh + install-asset-mode.sh; (c) all three parse --asset-mode-override; (d) project-asset staging block is byte-identical across all three (extracted via awk between the canonical comment header and the closing staged= echo, then diffed); (e) codex + cursor dry-runs against fresh temp fixtures produce per-dir counts matching m032-pre-m032-golden.txt (CON-4).

## Verification Results

- bash tools/verify/m032-p01-installers-parity.sh -> pass=25 fail=0 (rc=0).
- bash tools/verify/m032-p01-install-cc-byte-identical.sh -> pass=9 fail=0 (rc=0).
- Upstream regression: m032-p01-{manifest-schema-shape,reader-emits-tuples,mode-handler-symlink,installed-files-format,collision-oracle,install-cc-byte-identical} all pass=N fail=0; none broken by T03.
- Block byte-identity: 78 lines in each, diff -q reports zero differences across all three pairs.
- codex dry-run: commands/=27 scripts/=1149 references/=27 templates/=47 (matches golden).
- cursor dry-run (with seeded .cursor/): commands/=27 scripts/=1149 references/=27 templates/=47 (matches golden).

## Implementation Notes

- Cursor adapter probe requires .cursor/ signals at PROJECT_DIR; the parity verifier seeds an empty .cursor/ directory in its temp fixture before invoking install-cursor.sh --dry-run. This is a pre-existing cursor adapter contract, not introduced by T03.
- The awk delimiter regex in the task plan step 6 anchors with ^echo but the actual source line is indented with 2 spaces inside the if DRY_RUN==0 block. The parity verifier uses the corrected regex with the 2-space indent and adds an exit clause after p=0 to terminate cleanly at the closing echo. The block byte-identity assertion uses these correct delimiters; the diff produces zero output across all three pairs.
- No lifecycle helpers were modified (T01 helpers are reused unchanged).
- install-claude-code.sh was not modified (T02 already landed its canonical migration).
