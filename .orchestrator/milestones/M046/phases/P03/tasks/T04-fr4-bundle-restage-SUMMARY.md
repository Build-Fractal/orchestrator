---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P03"
milestone: "M046"
provides:
  - "orchestrator-do deprecation-shim skill wired into the install bundle: packaging/skills/orchestrator-do.md rewritten to deprecation content, added to manifest.yml skills list (sorted between dispatch and doctor), build-bundle.sh EXPECTED_SKILLS bumped 13->14 with orchestrator-do.md in EXPECTED_SKILL_NAMES, and staged into packaging/bundle/skills/; build-bundle.sh --check green at 14 skills so the orchestrator:update re-stage path re-installs the shim"
requires:
  - "T02 (commands/do.md deprecation doc + scripts/intake/do-entry.sh forwarding shim whose runway/replacement language the skill mirrors)"
affects:
  - "T05 (update-restage verifier), P03 close"
key_files:
  - "packaging/skills/orchestrator-do.md, packaging/bundle/manifest.yml, packaging/bundle/build-bundle.sh, packaging/bundle/skills/orchestrator-do.md"
key_decisions:
  - "Took the spec-literal ship-it reading (shim skill ships so a non-updated consumer gets the deprecation notice, not a missing-command error). Staged the single skill via targeted cp rather than bare build-bundle.sh: cmd_build blanket-copies all 37 packaging/skills/ sources into the bundle (pre-existing latent drift - the curated bundle held only 13 because it predates 24 later source additions), so running bare build would inject 24 out-of-scope files. Surgical single-file staging keeps FR-4 to +1 bundle file and --check green."
patterns_established:
  - "build-bundle.sh --check is a subset presence gate not an exact-match gate; curated single-file bundle staging keeps a bundle change surgical when cmd_build over-copies"
drill_down_paths:
  - ".orchestrator/milestones/M046/phases/P03/"
duration: "780s"
verification_result: "pass"
completed_at: "2026-07-14T04:09:05Z"
---

FR-4 made real by shipping the orchestrator-do deprecation-shim skill into the install bundle: rewrote packaging/skills/orchestrator-do.md to a DEPRECATED banner pointing at orchestrator:auto with the D021 removal runway (target v0.12.0), registered it in packaging/bundle/manifest.yml and build-bundle.sh (EXPECTED_SKILLS 13->14), and curated-staged it into packaging/bundle/skills/; all six plan verification commands pass and build-bundle.sh --check reports 14 skills green; deviated from the plan's step-4 bare build-bundle.sh mechanism (it blanket-copies all 37 source skills, a pre-existing drift that would inject 24 out-of-scope files) in favor of surgical single-file staging that matches how the existing 13 were curated.
