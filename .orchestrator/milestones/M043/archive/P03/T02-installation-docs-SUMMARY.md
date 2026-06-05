---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P03"
milestone: "M043"
provides:
  - "references/installation.md `## Wiki Deploy Targets (GitHub Pages vs. Cloudflare Access)` section (FR-11/SC-7) + tools/verify/m043-p03-installation-anchors.sh grep-anchor verifier"
requires:
  - "from:P01 what:templates/wiki-cloudflare-deploy.yml.tmpl FR-3a pre-deploy health-check workflow (read as disk state only)"
  - "from:P02 what:scripts/wiki/cloudflare-access-setup.sh flags + exit codes (4=Zero-Trust-off, 5=missing-scope) (read as disk state only)"
affects: []
key_files:
  - "references/installation.md,tools/verify/m043-p03-installation-anchors.sh"
key_decisions:
  - "Symmetric THREAT-7 Cloudflare entitlement-lapse mode documented (trial→free downgrade / 50-user free-tier Access limit) with FR-3a pre-deploy health-check failure as the loud-not-silent observable signal; token scopes documented as Pages Edit + Access: Apps and Policies Edit + Account Settings Read with explicit NO extra Access Read scope (FR-3a probe reuses the Edit token per P00 #Q-5-sub)"
patterns_established:
  - "co-authored grep-stable anchor verifier: every byte-for-byte marker phrase the verifier greps is present in the inserted prose; docs reflow must keep anchor phrases on a single line (line-oriented grep)"
drill_down_paths:
  - ".orchestrator/milestones/M043/phases/P03/tasks/T02-installation-docs-PLAN.md"
duration: "docs-authoring"
verification_result: "pass"
completed_at: "2026-06-04T00:00:00Z"
---

Inserted the verbatim `## Wiki Deploy Targets (GitHub Pages vs. Cloudflare Access)` section into references/installation.md between the `--with-<feature>` pattern's `### See also` subsection and `## Installing via Homebrew` — surrounding content undisturbed. Authored tools/verify/m043-p03-installation-anchors.sh (chmod +x) verbatim per plan.

Anchors covered (all 15 grep-asserted, plus the file-exists check): Wiki Deploy Targets section; Enterprise-only private-Pages pitfall; build-green / deploy-422 lapsed-entitlement mode; Recipe: Cloudflare Pages + Access; the three token scopes (Cloudflare Pages › Edit, Access: Apps and Policies › Edit, Account Settings › Read) + the "No additional" Read-scope disclaimer; Zero Trust prerequisite; symmetric Cloudflare entitlement lapse (THREAT-7); 50-user free-tier limit; FR-3a pre-deploy health-check failure signal; self_hosted_domains custom-domain note (THREAT-11); CON-7 allowed_email_domains reprovision caveat; giscus read-but-not-comment caveat.

Verifier final line: SUMMARY: m043-p03-installation-anchors.sh fail=0 (exit 0).

Plan defect corrected: the plan's verbatim prose wrapped "FR-3a" at the end of one line with "pre-deploy health-check" starting the next, but the co-authored verbatim anchor `FR-3a pre-deploy health-check` requires the phrase intact on one line (grep is line-oriented). Reflowed that single line break in the symmetric-failure-mode paragraph so the anchor phrase stays whole — no semantic change, no anchor weakening. Docs-only; no script/template/config or P01/P02/T01 deliverable touched.
