---
schema_version: "1.0"
type: task-summary
id: "T06"
parent: "P01"
milestone: "M013"
provides:
  - "references/github-integration.md skeleton; references/README.md index entry; scripts/verify/m013-p01-reference-skeleton.sh gate"
requires:
  - "from:T01,T02,T03,T04,T05 what:sidecar template + github-status script/command + UAT issue template + rebuild-index additive pass + defect schema/ingester all referenced by-path"
affects:
  - "T07 (phase-suite gate will include m013-p01-reference-skeleton.sh); P02 (will fill TODO P02 stubs in-place); P03 (will fill TODO P03 stubs in-place)"
key_files:
  - "references/github-integration.md,references/README.md,scripts/verify/m013-p01-reference-skeleton.sh"
key_decisions:
  - "D007 (projection-not-peer cited in Overview), D013 (M020 promotion cited in Knowledge-Layer Boundary), D014 (conversus pressure-test rulings cited in Knowledge-Layer Boundary + FR-12 scope note)"
patterns_established:
  - "TODO-stub sections for forward phases (P02/P03) placed inline at their final location so later phases fill in place rather than restructuring; Scope Boundary table as authoritative contract for what each phase writes; schema contract references by-path (knowledge/spec/defect/README.md) rather than duplicating field tables"
drill_down_paths:
  - ".orchestrator/milestones/M013/phases/P01/tasks/T06-PLAN.md"
duration: "15m"
verification_result: "pass"
completed_at: "2026-04-21T18:17:08Z"
---

T06 shipped the initial skeleton of references/github-integration.md covering the eight P01-scope sections: Overview, Sidecar Config Schema (top-level FR-6 fields table + per-item cache shape table for P02+ population), Pending-Sentinel Semantics (tri-state STATUS line contract + FR-11 reversibility-by-delete), sync_mode Enum (manual/on-transition/cron with FR-12 Claude-Code-only v1 note per D014), orchestrator-id Marker Format (M###-P##[-T##] + idempotency contract), UAT Ingestion Contract (input fixture shape table, output-by-path reference to knowledge/spec/defect/README.md, four-value status enum, unknown-chunk flagging), Knowledge-Layer Boundary M013 vs [M020](../../../../../milestones/M020/index.md) (D013/D014 citations + chunk_id-pinned-to-existing-SPEC-frontmatter rule), and Scope Boundary P01/P02/P03 table with TODO-stub sections placed inline at their final location for P02/P03 to fill in place. references/README.md updated with one new pipe-table row indexing the doc. scripts/verify/m013-p01-reference-skeleton.sh gate created (Bash 3.2, single-script-file AD-19 shape, 19 assertions + final summary PASS: all section headings + all 8 P01 artifact paths grep-qF + README index entry). All 19 assertions PASS, exit 0. Non-negotiables honored: Bash 3.2 compat (no declare -A, no process substitution); AP-009 compliance (no compound chains, single-invocation checks via assert_ok helper); structured PASS/FAIL prefixes + 0/1 exits; Constitution XIV/XV scope discipline (no P02/P03 material authored — TODO stubs only); MEM009 Documentation-as-Verification (gate checks structural completeness not prose quality); MEM010 Cross-Link Validation (all 8 artifact paths grep-qF verified). Judgment calls: (a) references/README.md pre-existing table only indexed 4 of 15 reference files so alphabetical ordering was ambiguous; added the new row after file-formats.md which preserves the existing reading order and matches the plan's one-line-gloss shape — did not re-sort existing entries. (b) Plan example showed a bullet-list format for the README addition but existing file is a pipe-table; followed the existing pipe-table shape rather than introducing a second format — gate greps for the string 'github-integration.md' so either works. (c) Kept TODO stubs as minimal italicized one-sentence placeholders at final section position rather than as collapsed headers — this means P02/P03 fill in place without restructuring, which fits the Scope Boundary table's 'this table pins what each phase writes' contract. (d) Cited D011-EVALUATION.md path explicitly in Further Reading since it's the mechanical source of M020 promotion, reinforcing the Knowledge-Layer Boundary section's authority claim. (e) Did not modify gitignore, spec files, or any T01-T05 artifacts — only the three T06 Must-Have files touched.
